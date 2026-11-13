extends SceneTree
const FIXTURE=preload("res://tests/source_bitmap_text_updates_test.gd")
# Independent pre-change renderer from 36a5cd8; only the optional fourth
# argument was added so the current caller can exercise the old implementation.
const OLD_STAGE="""func _stage(font_data: Dictionary, value: String, extent: Vector2, _reuse_owned: bool=false) -> Dictionary:
	var glyphs: Dictionary=font_data.glyphs
	var kernings: Dictionary=font_data.kernings
	var records: Array=[]
	var next_x: float=0.0
	var longest: float=0.0
	var previous: int=-1
	var last_advance: float=0.0
	var last_width: float=0.0
	for index: int in range(value.length()):
		var codepoint: int=value.unicode_at(index)
		if codepoint==0 or codepoint==10 or codepoint==13 or codepoint>65535 or (codepoint>=55296 and codepoint<=57343):return _fail("source_bitmap_singleline_bmp_required")
		if not glyphs.has(codepoint):return {"ok":false,"error":"source_bitmap_glyph_missing","codepoint":codepoint}
		var glyph: Dictionary=glyphs[codepoint]
		if glyph.get("chnl")!=15:return _fail("source_bitmap_glyph_channel_unsupported")
		var kerning: float=float(kernings.get("%d:%d" % [previous,codepoint],0)) if previous>=0 else 0.0
		records.append({"glyph":glyph,"x":next_x+float(glyph.xoffset)+kerning})
		next_x+=float(glyph.xadvance)+kerning
		longest=maxf(longest,next_x)
		last_advance=float(glyph.xadvance)
		last_width=float(glyph.width)
		previous=codepoint
	# Native final-glyph adjustment uses width versus xAdvance, not xoffset.
	var width: float=longest-last_advance+last_width if last_advance<last_width else longest
	var height: float=float(font_data.common.lineHeight)
	var layer:=Node2D.new()
	layer.name="OriginalBitmapGlyphs"
	var origin:=Vector2((extent.x-width)/2.0,-extent.y+(extent.y-height)/2.0)
	for record: Dictionary in records:
		var glyph: Dictionary=record.glyph
		var texture: Variant=font_data.page_textures.get(glyph.page)
		if not texture is Texture2D:
			layer.free()
			return _fail("source_bitmap_glyph_page_missing")
		if int(glyph.width)==0 or int(glyph.height)==0:continue
		var material: ShaderMaterial=SourceMaterial.original_default(texture)
		if material==null:
			layer.free()
			return _fail("source_bitmap_material_unavailable")
		var sprite:=Sprite2D.new()
		sprite.texture=texture
		sprite.centered=false
		sprite.region_enabled=true
		sprite.region_filter_clip_enabled=true
		sprite.region_rect=Rect2(float(glyph.x),float(glyph.y),float(glyph.width),float(glyph.height))
		sprite.position=origin+Vector2(float(record.x),float(glyph.yoffset))
		sprite.material=material
		SourceMaterial.bind_display(sprite,_display_color)
		layer.add_child(sprite)
	return {"ok":true,"layer":layer,"native_size":Vector2(width,height)}
"""
var checks: int=0
var failures: Array[String]=[]
var pixel_comparisons: int=0
var allocation_proof: Dictionary={}
var cpu_benchmark: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("BITMAP_GLYPH_REUSE_FAIL ",label)
func renderer(old: bool,counted: bool=true) -> GDScript:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_bitmap_text.gd")
	if old:
		var first: int=source.find("func _stage(")
		var last: int=source.find("func _layout(",first)
		check(first>=0 and last>first,"old-stage replacement boundaries located")
		source=source.left(first)+OLD_STAGE+"\n"+source.substr(last)
	if not counted:
		var raw:=GDScript.new();raw.source_code=source
		check(raw.reload()==OK,"uninstrumented benchmark renderer compiles")
		return raw
	source=source.replace("extends Node2D\n","extends Node2D\nvar test_sprites: int=0\nvar test_layers: int=0\nvar test_materials: int=0\n")
	source=source.replace("Sprite2D.new()","_test_sprite()").replace("Node2D.new()","_test_layer()")
	source=source.replace("SourceMaterial.bind_display(sprite,_display_color)","_test_bind(sprite)")
	source+="""
func _test_sprite() -> Sprite2D:
	test_sprites+=1
	return Sprite2D.new()
func _test_layer() -> Node2D:
	test_layers+=1
	return Node2D.new()
func _test_bind(sprite: Sprite2D) -> void:
	var previous: Material=sprite.material
	SourceMaterial.bind_display(sprite,_display_color)
	if sprite.material!=previous:test_materials+=1
"""
	var result:=GDScript.new();result.source_code=source
	check(result.reload()==OK,"actual old/new renderer compiles")
	return result
func player(script: Script,f: Dictionary,parent: Node) -> Node2D:
	var p: Node2D=script.new();parent.add_child(p)
	check(p.configure(f,{"text":"AB가"},Vector2(100,24)).ok,"label configures")
	return p
func same(a: Node2D,b: Node2D,fixture: SceneTree,label: String) -> void:
	check(fixture.state(a)==fixture.state(b),label+" full glyph geometry/material state")
	check(a._glyph_layer.get_child_count()==b._glyph_layer.get_child_count(),label+" exact current glyph count")
func run_headless(fixture: SceneTree,old: Script,next: Script) -> void:
	var f: Dictionary=fixture.font(false)
	var a: Node2D=player(next,f,root);var b: Node2D=player(old,f,root)
	var retained_layer: Node2D=a._glyph_layer
	var retained_sprite: Sprite2D=a._glyph_layer.get_child(0)
	var retained_material: Material=retained_sprite.material
	for i: int in 12:
		var value: String=["AB가","BAA","가BA"][i%3]
		check(a.set_source_text(value)==b.set_source_text(value),"update result matches independent old stage")
		same(a,b,fixture,"steady %d"%i)
	check(a._glyph_layer==retained_layer and a._glyph_layer.get_child(0)==retained_sprite and retained_sprite.material==retained_material,"same-sized text retains layer/node/private material")
	allocation_proof={"old_sprites":b.test_sprites,"new_sprites":a.test_sprites,"old_layers":b.test_layers,"new_layers":a.test_layers,"old_materials":b.test_materials,"new_materials":a.test_materials}
	check(b.test_sprites==39 and a.test_sprites==3 and b.test_layers==13 and a.test_layers==1 and b.test_materials==39 and a.test_materials==3,"actual constructor and private material counts include initial three glyphs")
	# Growth, shrink and empty strings retain no unused slots or private materials.
	a.set_source_text("ABABAB");b.set_source_text("ABABAB");same(a,b,fixture,"growth")
	var tail: WeakRef=weakref(a._glyph_layer.get_child(5));var tail_material: WeakRef=weakref(a._glyph_layer.get_child(5).material)
	a.set_source_text("A");b.set_source_text("A");same(a,b,fixture,"shrink")
	check(tail.get_ref()==null and tail_material.get_ref()==null,"surplus node and private material released immediately")
	a.set_source_text("");b.set_source_text("");same(a,b,fixture,"empty")
	check(a._glyph_layer.get_child_count()==0,"no high-water glyph pool")
	a.set_source_text("AB가");b.set_source_text("AB가")
	var kept: Node2D=a._glyph_layer;var kept_sprite: Node=a._glyph_layer.get_child(0)
	for p: Node2D in [a,b]:p._font_data.glyphs[66].page=2
	var failed: Dictionary=a.set_source_text("AB")
	check(failed==b.set_source_text("AB") and not failed.ok,"late page failure remains rejected")
	check(a._glyph_layer==kept and a._glyph_layer.get_child(0)==kept_sprite,"late failure cannot mutate/recycle visible glyphs")
	for p: Node2D in [a,b]:p._font_data.glyphs[66].page=1
	same(a,b,fixture,"failed staging")
	# Node presentation and unknown materials cannot carry into a new text update.
	for p: Node2D in [a,b]:
		var sprite: Sprite2D=p._glyph_layer.get_child(0)
		sprite.scale=Vector2(2,3);sprite.rotation=0.4;sprite.offset=Vector2(7,8);sprite.flip_h=true;sprite.flip_v=true
		sprite.modulate=Color.RED;sprite.self_modulate=Color.BLUE;sprite.visible=false;sprite.z_index=17;sprite.z_as_relative=false
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;sprite.use_parent_material=true;sprite.material=CanvasItemMaterial.new()
	a.set_source_text("BA");b.set_source_text("BA");same(a,b,fixture,"restored defaults")
	var restored: Sprite2D=a._glyph_layer.get_child(0)
	check(restored.scale==Vector2.ONE and restored.rotation==0 and restored.offset==Vector2.ZERO and not restored.flip_h and not restored.flip_v and restored.modulate==Color.WHITE and restored.self_modulate==Color.WHITE and restored.visible and restored.z_index==0 and restored.z_as_relative and not restored.use_parent_material,"fresh defaults restored")
	# Unexpected structure, ownership metadata or styled layer: fresh fallback.
	for kind: int in 3:
		var previous: WeakRef=weakref(a._glyph_layer)
		for p: Node2D in [a,b]:
			if kind==0:p._glyph_layer.add_child(Node2D.new())
			if kind==1:p._glyph_layer.get_child(0).set_meta("foreign_owner",true)
			if kind==2:p._glyph_layer.position=Vector2(5,7)
		a.set_source_text("AB가");b.set_source_text("AB가");same(a,b,fixture,"fresh fallback %d"%kind)
		check(previous.get_ref()==null,"foreign/styled layer released")
	var before_public: WeakRef=weakref(a._glyph_layer)
	check(a.configure(f,{"text":"BA"},Vector2(120,30))==b.configure(f,{"text":"BA"},Vector2(120,30)),"public configure still uses fresh replacement")
	check(before_public.get_ref()==null,"public replacement retires old layer")
	same(a,b,fixture,"public replacement")
	a.free();b.free()
func view(script: Script,f: Dictionary,transparent: bool) -> Dictionary:
	var vp:=SubViewport.new();vp.size=Vector2i(128,64);vp.disable_3d=true;vp.transparent_bg=transparent;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var bg:=ColorRect.new();bg.size=Vector2(128,64);bg.color=Color(0.25,0.43,0.81,0.61);vp.add_child(bg)
	var p: Node2D=player(script,f,vp);p.position=Vector2(8,40)
	return {"vp":vp,"p":p}
func pixels(v: Dictionary) -> PackedByteArray:
	var image: Image=v.vp.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);return image.get_data()
func run_pixels(fixture: SceneTree,old: Script,next: Script) -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility":check(false,"render requires Compatibility GL");return
	for pma: bool in [false,true]:
		for transparent: bool in [false,true]:
			var f: Dictionary=fixture.font(pma);var a: Dictionary=view(next,f,transparent);var b: Dictionary=view(old,f,transparent)
			var values: Array[String]=["AB가","BA가","ABABAB","B","","가AB","가AB","BA","AB가","AB가"]
			for phase: int in values.size():
				for v: Dictionary in [a,b]:
					if phase==1:v.p.set_source_display(Color(0.7,0.9,0.4,0.5))
					if phase==6:
						var glyph: Sprite2D=v.p._glyph_layer.get_child(0)
						glyph.material.set_shader_parameter("source_display_color",Color.RED)
						glyph.material.set_shader_parameter("source_pma",not pma)
					if phase==7:v.p._glyph_layer.modulate=Color(0.5,0.1,1,0.2)
					if phase==8:v.p._font_data.glyphs[66].page=2
					if phase==9:v.p._font_data.glyphs[66].page=1
				check(a.p.set_source_text(values[phase])==b.p.set_source_text(values[phase]),"pixel update/failure result equivalence")
				await process_frame;await RenderingServer.frame_post_draw
				pixel_comparisons+=1;check(pixels(a)==pixels(b),"independent old-stage full RGBA equivalence phase=%d pma=%s transparent=%s"%[phase,pma,transparent])
			a.vp.free();b.vp.free()
func benchmark_updates(fixture: SceneTree) -> void:
	# Synthetic CPU-only loop; render delivery is outside the timed region.
	# Alternating order, no time threshold and no Android/FPS interpretation.
	var a: Node2D=player(renderer(false,false),fixture.font(false,4096),root)
	var b: Node2D=player(renderer(true,false),a._font_data,root)
	var values: Array[String]=["AB가AB가AB","BA가BA가BA","가BA가BA가B"]
	for p: Node2D in [a,b]:
		for i: int in 8:p.set_source_text(values[i%3])
	var old_usec: Array[int]=[];var new_usec: Array[int]=[]
	for round_index: int in 4:
		var players: Array=[b,a] if round_index%2==0 else [a,b]
		for p: Node2D in players:
			var started: int=Time.get_ticks_usec()
			for i: int in 200:p.set_source_text(values[i%3])
			var elapsed: int=Time.get_ticks_usec()-started
			if p==b:old_usec.append(elapsed)
			else:new_usec.append(elapsed)
	cpu_benchmark={"updates_per_sample":200,"glyphs_per_update":8,"old_usec":old_usec,"new_usec":new_usec,"synthetic_cpu_only":true,"render_delivery_excluded":true}
	a.free();b.free()
func run() -> void:
	var fixture: SceneTree=FIXTURE.new()
	var old: Script=renderer(true);var next: Script=renderer(false)
	run_headless(fixture,old,next)
	if "--render" in OS.get_cmdline_user_args():await run_pixels(fixture,old,next)
	if "--benchmark" in OS.get_cmdline_user_args():benchmark_updates(fixture)
	fixture.free()
	print("BITMAP_GLYPH_REUSE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"allocations":allocation_proof,"cpu_benchmark":cpu_benchmark,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
