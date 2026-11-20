extends SceneTree
## Display colour on shared per-colour materials (no instance uniforms), and
## an optional GL differential against the private-material binding.
const MATERIAL=preload("res://scripts/ui/original_ui/source_material.gd")
const BLEND=preload("res://scripts/ui/original_ui/source_blend.gd")
var checks: int=0
var failures: Array[String]=[]
var render_checks: int=0
const FIRST=Color(0.8,0.4,0.6,0.7)
const NEXT=Color(0.2,0.9,0.3,0.4)
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_MATERIAL_DISPLAY_UPDATES_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func texture(pma: bool=false) -> Texture2D:
	var image:=Image.create_empty(8,8,false,Image.FORMAT_RGBA8)
	for y: int in 8:
		for x: int in 8:
			var a: float=float(16+x*19+y*11)/255.0
			var c:=Color(float(x)/7.0,float(y)/7.0,0.8,a)
			if pma:c=Color(c.r*a,c.g*a,c.b*a,a)
			image.set_pixel(x,y,c)
	var result:=ImageTexture.create_from_image(image)
	result.set_meta("cocos_premultiplied",pma)
	return result
## Oracle: the original binding (a private duplicated material with ordinary
## uniforms). The candidate (shared per-colour material) must draw the same.
func original_bind(item: CanvasItem, color: Color) -> void:
	if not item.material is ShaderMaterial:return
	var current: ShaderMaterial=item.material
	if not bool(current.get_meta("oracle_private_display",false)):
		current=current.duplicate();current.set_meta("oracle_private_display",true);item.material=current
	current.set_shader_parameter("source_display_bound",true)
	current.set_shader_parameter("source_display_color",color)
func state(item: CanvasItem, color: Color, label: String) -> void:
	var current: ShaderMaterial=item.material
	check(current.get_shader_parameter("source_display_bound")==true,label+" bound")
	check(current.get_shader_parameter("source_display_color")==color,label+" color")
func headless_checks() -> void:
	var tex:=texture()
	var prototype:=MATERIAL.original_default(tex)
	# Instance uniforms live in the global shader buffer, which phones clamp
	# to 1,024-4,096 slots: past that nodes read other slots (colour blocks).
	for code: String in [prototype.shader.code,MATERIAL.original_default(texture(true)).shader.code]:
		check(not code.contains("instance uniform"),"factory shader has no instance uniform")
	var was: bool=BLEND.screen_copy_available
	for copy: bool in [true,false]:
		BLEND.screen_copy_available=copy;BLEND._cache.clear()
		for pair: String in BLEND.PAIRS:
			var blended: ShaderMaterial=BLEND.material(tex,pair)
			check(blended!=null and not blended.shader.code.contains("instance uniform"),"blend %s copy=%s has no instance uniform"%[pair,copy])
	BLEND.screen_copy_available=was;BLEND._cache.clear()
	var item:=Sprite2D.new()
	var sibling:=Sprite2D.new()
	item.material=prototype;sibling.material=prototype
	MATERIAL.bind_display(item,FIRST)
	check(item.material!=prototype and sibling.material==prototype,"bound node gets a display variant; sibling keeps the prototype")
	check(MATERIAL.display_base(item.material)==prototype,"variant remembers its base")
	check(prototype.get_shader_parameter("source_display_bound")!=true,"prototype itself is never bound")
	state(item,FIRST,"first binding")
	var first_variant: Material=item.material
	MATERIAL.bind_display(sibling,FIRST)
	check(sibling.material==first_variant,"same base + same colour share one material")
	for i: int in 100:MATERIAL.bind_display(item,FIRST)
	check(item.material==first_variant,"repeated binding keeps the shared variant")
	MATERIAL.bind_display(item,NEXT);state(item,NEXT,"color update")
	check(sibling.material==first_variant,"updating one node leaves the other's colour")
	state(sibling,FIRST,"sibling unchanged")
	(item.material as ShaderMaterial).set_shader_parameter("source_display_bound",false)
	(item.material as ShaderMaterial).set_shader_parameter("source_display_color",FIRST)
	MATERIAL.bind_display(item,NEXT);state(item,NEXT,"external mutations corrected")
	var replacement:=MATERIAL.original_default(texture(true))
	item.material=replacement
	MATERIAL.bind_display(item,FIRST)
	check(MATERIAL.display_base(item.material)==replacement,"a replacement material gets its own variant")
	state(item,FIRST,"replacement material")
	var shader:=Shader.new();shader.code=prototype.shader.code
	var custom:=ShaderMaterial.new();custom.shader=shader
	item.material=custom
	MATERIAL.bind_display(item,NEXT);check(MATERIAL.display_base(item.material)==custom,"a custom shader material is the variant base")
	state(item,NEXT,"custom material")
	var foreign:=ShaderMaterial.new();var foreign_shader:=Shader.new()
	foreign_shader.code="shader_type canvas_item;\nvoid fragment(){ COLOR = texture(TEXTURE, UV); }\n"
	foreign.shader=foreign_shader;item.material=foreign
	MATERIAL.bind_display(item,NEXT)
	check(not MATERIAL.takes_display(foreign) and item.material==foreign and foreign.get_shader_parameter("source_display_bound")==null,"a shader without the display parameters is left alone")
	var plain:=CanvasItemMaterial.new();item.material=plain
	MATERIAL.bind_display(item,NEXT);check(item.material==plain,"nonshader material unchanged")
	item.material=null;MATERIAL.bind_display(item,NEXT);check(item.material==null,"null material unchanged")
	# Thousands of nodes in a few colours hold only a few materials.
	var many: Array[Sprite2D]=[]
	var distinct: Dictionary={}
	for i: int in 6000:
		var node:=Sprite2D.new();node.material=prototype
		MATERIAL.bind_display(node,[Color.WHITE,FIRST,NEXT][i%3])
		distinct[node.material.get_instance_id()]=true
		many.append(node)
	check(distinct.size()==3,"6000 nodes in 3 colours share 3 materials (got %d)"%distinct.size())
	for node: Sprite2D in many:node.free()
	item.free();sibling.free()
func check_cache_capacity() -> void:
	MATERIAL._display_variants.clear()
	MATERIAL._display_variant_count=0
	var bases: Array[ShaderMaterial]=[MATERIAL.original_default(texture()),MATERIAL.original_default(texture(true))]
	var item:=Sprite2D.new()
	var keeper:=Sprite2D.new()
	keeper.material=bases[0]
	MATERIAL.bind_display(keeper,Color.BLACK)
	var retained: Material=keeper.material
	for index: int in range(1,MATERIAL.DISPLAY_CACHE_LIMIT):
		item.material=bases[index&1]
		MATERIAL.bind_display(item,Color(float(index)/MATERIAL.DISPLAY_CACHE_LIMIT,0.0,0.0))
	check(MATERIAL._display_variant_count==MATERIAL.DISPLAY_CACHE_LIMIT and MATERIAL._display_variants.size()==2,"the total bound counts colours across both base materials")
	MATERIAL.bind_display(keeper,Color.BLACK)
	check(keeper.material==retained and MATERIAL._display_variant_count==MATERIAL.DISPLAY_CACHE_LIMIT,"a hit at capacity preserves the shared material")
	MATERIAL.bind_display(item,Color.WHITE)
	check(MATERIAL._display_variant_count==1 and MATERIAL._display_variants.size()==1,"a miss clears both buckets at the same global limit")
	check(keeper.material==retained,"an evicted but live sprite keeps its material")
	state(keeper,Color.BLACK,"evicted display")
	item.free();keeper.free()
func make_view(tex: Texture2D, transparent: bool) -> Dictionary:
	var viewport:=SubViewport.new();viewport.size=Vector2i(24,20);viewport.disable_3d=true
	viewport.transparent_bg=transparent;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite:=Sprite2D.new();sprite.texture=tex;sprite.centered=false
	sprite.position=Vector2(3,2);sprite.scale=Vector2(2,2);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material=MATERIAL.original_default(tex);viewport.add_child(sprite)
	return {"viewport":viewport,"sprite":sprite}
func pixels(view: Dictionary) -> PackedByteArray:
	var image: Image=view.viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);return image.get_data()
func render_comparisons() -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility":
		check(false,"--render requires Compatibility GL");return
	for pma: bool in [false,true]:
		for transparent: bool in [false,true]:
			var tex:=texture(pma)
			var candidate:=make_view(tex,transparent)
			var oracle:=make_view(tex,transparent)
			for phase: int in 6:
				var color: Color=FIRST if phase<2 else NEXT
				for view: Dictionary in [candidate,oracle]:
					if phase==3:
						(view.sprite.material as ShaderMaterial).set_shader_parameter("source_display_bound",false)
						(view.sprite.material as ShaderMaterial).set_shader_parameter("source_display_color",FIRST)
					if phase==4:view.sprite.material=MATERIAL.original_default(tex)
					if phase==5:
						var shader:=Shader.new();shader.code=(view.sprite.material as ShaderMaterial).shader.code
						var fresh:=ShaderMaterial.new();fresh.shader=shader
						fresh.set_shader_parameter("source_pma",(view.sprite.material as ShaderMaterial).get_shader_parameter("source_pma"))
						view.sprite.material=fresh
				MATERIAL.bind_display(candidate.sprite,color);original_bind(oracle.sprite,color)
				await process_frame
				await RenderingServer.frame_post_draw
				render_checks+=1
				check(pixels(candidate)==pixels(oracle),"full RGBA equal to private material oracle phase=%d pma=%s transparent=%s"%[phase,pma,transparent])
			candidate.viewport.free();oracle.viewport.free()
	await many_nodes_render()
## More bound nodes than a desktop GL uniform block can hold as instance
## uniforms (65,536 bytes = 4,096 slots = 2,048 nodes; phones less): every
## node must still draw its own colour.
func many_nodes_render() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(100,60);viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var image:=Image.create_empty(1,1,false,Image.FORMAT_RGBA8);image.set_pixel(0,0,Color.WHITE)
	var white:=ImageTexture.create_from_image(image)
	var colors: Array[Color]=[Color(1,0,0,1),Color(0,1,0,1),Color(0,0,1,1)]
	var count: int=0
	for y: int in 60:
		for x: int in 100:
			var sprite:=Sprite2D.new();sprite.texture=white;sprite.centered=false;sprite.position=Vector2(x,y)
			sprite.material=MATERIAL.original_default(white)
			viewport.add_child(sprite)
			MATERIAL.bind_display(sprite,colors[(x+y)%3])
			count+=1
	for frame: int in 3:await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image=viewport.get_texture().get_image();shot.convert(Image.FORMAT_RGBA8)
	var wrong: int=0
	for y: int in 60:
		for x: int in 100:
			var expected: Color=colors[(x+y)%3]
			var got: Color=shot.get_pixel(x,y)
			if absf(got.r-expected.r)>0.02 or absf(got.g-expected.g)>0.02 or absf(got.b-expected.b)>0.02:wrong+=1
	render_checks+=1
	check(wrong==0,"%d bound nodes draw their own colour (wrong pixels %d)"%[count,wrong])
	viewport.free()
func run() -> void:
	headless_checks()
	check_cache_capacity()
	if "--render" in OS.get_cmdline_user_args():await render_comparisons()
	print("SOURCE_MATERIAL_DISPLAY_UPDATES_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"render_checks":render_checks,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
