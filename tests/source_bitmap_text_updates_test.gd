extends SceneTree
## Compare the actual internal update with the unchanged public configure path
## used by the previous setter. Synthetic glyph pages, never original art.
const BITMAP=preload("res://scripts/ui/original_ui/source_bitmap_text.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
var checks: int=0
var failures: Array[String]=[]
var pixel_comparisons: int=0
var snapshot_replacements: Array[int]=[0,0]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_BITMAP_TEXT_UPDATES_FAIL ",label)
func page(pma: bool,seed: int) -> Image:
	var result:=Image.create_empty(32,16,false,Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 32:
			var alpha: float=float((x*17+y*13+seed*7)%256)/255.0
			var color:=Color(float((x+seed)%32)/31.0,float(y)/15.0,0.7,alpha)
			if pma:color=Color(color.r*alpha,color.g*alpha,color.b*alpha,alpha)
			result.set_pixel(x,y,color)
	return result
func glyph(x: int,width: int,advance: int,page_id: int=0) -> Dictionary:
	return {"x":x,"y":1,"width":width,"height":8,"xoffset":1,"yoffset":1,"xadvance":advance,"page":page_id,"chnl":15}
func font(pma: bool=false,extra: int=0) -> Dictionary:
	var textures: Dictionary={}
	for id: int in 2:
		var texture:=ImageTexture.create_from_image(page(pma,id));texture.set_meta("cocos_premultiplied",pma);textures[id]=texture
	var result: Dictionary={"common":{"lineHeight":12,"scaleW":32,"scaleH":16,"packed":0},"pages":{0:"page0",1:"page1"},"page_textures":textures,"glyphs":{65:glyph(0,7,8),66:glyph(8,8,6,1),44032:glyph(16,8,9),32:glyph(0,0,4)},"kernings":{"65:66":-2,"66:65":1}}
	for i: int in extra:
		result.glyphs[1000+i]=glyph(0,1,1)
		result.kernings["%d:%d"%[1000+i,1001+i]]=i%3-1
	return result
func legacy_text(p: Node2D,value: String) -> Dictionary:
	if p._font_data.is_empty():return {"ok":false,"error":"source_bitmap_not_configured"}
	var next: Dictionary=p._options.duplicate(true);next.text=value
	return p.configure(p._font_data,next,p._extent)
func state(p: Node2D) -> Dictionary:
	var rows: Array=[]
	for item: Sprite2D in p._glyph_layer.get_children():
		rows.append([item.texture,item.centered,item.region_enabled,item.region_filter_clip_enabled,item.region_rect,item.position,item.material.shader.code,item.material.get_shader_parameter("source_display_bound"),item.material.get_shader_parameter("source_display_color")])
	return {"rows":rows,"size":p.native_size,"options":p._options,"extent":p._extent,"font":p._font_data}
func headless_checks() -> void:
	HITCH.reset_for_test("user://bitmap_update_test")
	var caller: Dictionary=font(false,4096)
	var a:=BITMAP.new();var b:=BITMAP.new()
	check(a.set_source_text("A")==legacy_text(b,"A"),"unconfigured error unchanged")
	for p: Node2D in [a,b]:check(p.configure(caller,{"text":"AB가"},Vector2(80,20)).ok,"initial snapshot configures")
	check(not is_same(a._font_data,caller) and not is_same(a._font_data.glyphs,caller.glyphs),"public configure isolates caller descriptors")
	caller.glyphs[65].xadvance=99
	check(a._font_data.glyphs[65].xadvance==8,"caller mutation does not alter owned descriptor")
	for value: String in ["AB가","BA","AB AB","","가A","BA","AB가","A","AB","BA","","AB가"]:
		var previous_a: Dictionary=a._font_data;var previous_b: Dictionary=b._font_data
		check(a.set_source_text(value)==legacy_text(b,value),"update return value unchanged")
		check(state(a)==state(b),"glyph order/geometry/kerning/material and descriptor equivalent")
		if not is_same(previous_a,a._font_data):snapshot_replacements[1]+=1
		if not is_same(previous_b,b._font_data):snapshot_replacements[0]+=1
	check(snapshot_replacements==[12,0],"twelve updates no longer recopy 4100 glyph and 4098 kerning rows")
	for value: String in ["Z","A\nB",String.chr(0x1f600)]:
		var prior_a: Node2D=a._glyph_layer;var prior_b: Node2D=b._glyph_layer
		var old_a: Dictionary=a._font_data;var old_b: Dictionary=b._font_data
		var answer: Dictionary=a.set_source_text(value)
		check(answer==legacy_text(b,value) and not answer.ok,"unsupported text remains rejected")
		check(a._glyph_layer==prior_a and b._glyph_layer==prior_b,"failure retains old visible layer")
		check(is_same(a._font_data,old_a) and is_same(b._font_data,old_b),"failure retains owned descriptor")
	# Revalidation cannot be skipped even when the text is unchanged.
	for p: Node2D in [a,b]:p._font_data.glyphs[65].chnl=0
	check(a.set_source_text("AB가")==legacy_text(b,"AB가") and not a.set_source_text("AB가").ok,"same text revalidates live owned glyph data")
	for p: Node2D in [a,b]:p._font_data.glyphs[65].chnl=15
	for p: Node2D in [a,b]:p._font_data.page_textures.erase(1)
	check(a.set_source_text("AB가")==legacy_text(b,"AB가") and not a.set_source_text("AB가").ok,"same text revalidates page availability")
	# Explicit replacement remains a fresh caller snapshot and fixes prior errors.
	for p: Node2D in [a,b]:check(p.configure(caller,{"text":"BA"},Vector2(92,24)).ok,"public font replacement remains supported")
	check(a._font_data.glyphs[65].xadvance==99 and not is_same(a._font_data,caller),"public replacement takes changed caller values without alias")
	caller.glyphs[65].xadvance=17
	check(a.set_source_text("BA")==legacy_text(b,"BA") and a._font_data.glyphs[65].xadvance==99,"subsequent text update keeps independent replacement")
	check(state(a)==state(b),"final replacement output equivalent")
	check(HITCH._details.has("ui.bitmap_configure") and HITCH._details.has("ui.bitmap_update"),"configure and update have separate bounded detail names")
	check(HITCH._sections.is_empty(),"inclusive diagnostics do not duplicate caller top-level sections")
	a.free();b.free()
func view(f: Dictionary,transparent: bool) -> Dictionary:
	var vp:=SubViewport.new();vp.size=Vector2i(120,52);vp.transparent_bg=transparent;vp.disable_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var background:=ColorRect.new();background.size=Vector2(120,52);background.color=Color(0.2,0.6,0.3,0.7);vp.add_child(background)
	var p:=BITMAP.new();p.position=Vector2(7,36);vp.add_child(p);check(p.configure(f,{"text":"AB가"},Vector2(100,24)).ok,"pixel player configures")
	return {"vp":vp,"p":p}
func pixels(v: Dictionary) -> PackedByteArray:
	var image: Image=v.vp.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);return image.get_data()
func render_checks() -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility":check(false,"render requires Compatibility GL");return
	for pma: bool in [false,true]:
		for transparent: bool in [false,true]:
			var f: Dictionary=font(pma);var a: Dictionary=view(f,transparent);var b: Dictionary=view(f,transparent)
			var values: Array[String]=["AB가","AB가","BA","AB AB","","가A","가A","AB"]
			for i: int in values.size():
				if i==2:
					for v: Dictionary in [a,b]:v.p.set_source_display(Color(0.8,0.5,0.9,0.6))
				if i==6:f.page_textures[1].update(page(pma,8))
				if i==7:
					f.glyphs[65].xadvance=13
					for v: Dictionary in [a,b]:check(v.p.configure(f,{"text":values[i]},Vector2(100,24)).ok,"explicit replacement pixels")
				else:check(a.p.set_source_text(values[i])==legacy_text(b.p,values[i]),"pixel update results equal")
				await process_frame;await RenderingServer.frame_post_draw
				pixel_comparisons+=1;check(pixels(a)==pixels(b),"full RGBA equals old setter pma=%s transparent=%s phase=%d"%[pma,transparent,i])
			a.vp.free();b.vp.free()
func run() -> void:
	headless_checks()
	if "--render" in OS.get_cmdline_user_args():await render_checks()
	print("SOURCE_BITMAP_TEXT_UPDATES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"font_snapshot_replacements_old_new":snapshot_replacements,"glyph_rows":4100,"kerning_rows":4098,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
