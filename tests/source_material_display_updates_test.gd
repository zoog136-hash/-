extends SceneTree
## Display colour on shared per-colour material variants, and an optional GL
## differential against the previous private-material binding.
const MATERIAL=preload("res://scripts/ui/original_ui/source_material.gd")
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
## Oracle: the previous binding (a private duplicated material per node).
## The candidate (one shared variant per base material and colour) must draw
## the same pixels.
func original_bind(item: CanvasItem, color: Color) -> void:
	if not item.material is ShaderMaterial:return
	var current: ShaderMaterial=item.material
	if not bool(current.get_meta("oracle_private_display",false)):
		var shader:=Shader.new()
		shader.code=current.shader.code
		var copy:=ShaderMaterial.new();copy.shader=shader
		copy.set_shader_parameter("source_pma",current.get_shader_parameter("source_pma"))
		copy.set_shader_parameter("source_gray",current.get_shader_parameter("source_gray"))
		copy.set_meta("oracle_private_display",true);item.material=copy;current=copy
	current.set_shader_parameter("source_display_bound",true)
	current.set_shader_parameter("source_display_color",color)
func state(item: CanvasItem, color: Color, label: String) -> void:
	var material: ShaderMaterial=item.material as ShaderMaterial
	check(material!=null and material.get_shader_parameter("source_display_bound")==true,label+" bound")
	check(material!=null and material.get_shader_parameter("source_display_color")==color,label+" color")
func unbound(material: ShaderMaterial) -> bool:
	var bound: Variant=material.get_shader_parameter("source_display_bound")
	return bound==null or bound==false
func crowd_color(i: int) -> Color:
	return Color(float(i%256)/255.0,float(i/256)/255.0,0.5,1.0)
func headless_checks() -> void:
	var tex:=texture()
	var prototype:=MATERIAL.original_default(tex)
	var item:=Sprite2D.new()
	var sibling:=Sprite2D.new()
	var same_color:=Sprite2D.new()
	item.material=prototype;sibling.material=prototype;same_color.material=prototype
	MATERIAL.bind_display(item,FIRST)
	check(sibling.material==prototype and unbound(prototype),"the shared prototype itself is never bound; other nodes are untouched")
	check(item.material!=prototype and MATERIAL.display_base(item.material)==prototype,"display colour uses a variant of the prototype")
	check(not prototype.shader.code.contains("instance uniform"),"no per-instance shader parameters (phone GLES3 global buffer overflow)")
	state(item,FIRST,"first binding")
	var first_variant: Material=item.material
	MATERIAL.bind_display(same_color,FIRST)
	check(same_color.material==first_variant,"nodes with the same base and colour share one material")
	for i: int in 100:MATERIAL.bind_display(item,FIRST)
	check(item.material==first_variant,"repeated binding keeps the shared variant")
	state(item,FIRST,"unchanged binding")
	MATERIAL.bind_display(item,NEXT);state(item,NEXT,"color update")
	check(item.material!=first_variant and MATERIAL.display_base(item.material)==prototype,"a different colour is a different variant of the same base")
	state(same_color,FIRST,"other colour's node unchanged")
	var variant: ShaderMaterial=item.material
	variant.set_shader_parameter("source_display_bound",false)
	variant.set_shader_parameter("source_display_color",FIRST)
	MATERIAL.bind_display(item,NEXT);state(item,NEXT,"external mutations corrected")
	variant.set_shader_parameter("source_display_color",Vector4(NEXT.r,NEXT.g,NEXT.b,NEXT.a))
	variant.set_shader_parameter("source_display_bound",1)
	MATERIAL.bind_display(item,NEXT)
	check(typeof(variant.get_shader_parameter("source_display_color"))==TYPE_COLOR,"actual color variant type restored")
	check(typeof(variant.get_shader_parameter("source_display_bound"))==TYPE_BOOL,"actual bool variant type restored")
	variant.set_shader_parameter("source_display_bound",null)
	variant.set_shader_parameter("source_display_color",null)
	MATERIAL.bind_display(item,NEXT);state(item,NEXT,"cleared parameters restored")
	var replacement:=MATERIAL.original_default(texture(true))
	item.material=replacement
	MATERIAL.bind_display(item,FIRST)
	check(MATERIAL.display_base(item.material)==replacement and unbound(replacement),"a replacement material gets its own shared variant")
	state(item,FIRST,"replacement material")
	var shader:=Shader.new();shader.code=(item.material as ShaderMaterial).shader.code
	var custom:=ShaderMaterial.new();custom.shader=shader
	item.material=custom
	MATERIAL.bind_display(item,NEXT);check(MATERIAL.display_base(item.material)==custom and unbound(custom),"a custom shader material is used as the base, never bound itself")
	state(item,NEXT,"custom material")
	var particle:=Sprite2D.new();particle.material=prototype
	MATERIAL.bind_display(particle,FIRST,true)
	var private_material: Material=particle.material
	check(private_material!=first_variant and MATERIAL.display_base(private_material)==prototype,"private binding (particles) gets its own copy")
	MATERIAL.bind_display(particle,NEXT,true)
	check(particle.material==private_material,"private copy is reused for colour changes");state(particle,NEXT,"private copy")
	state(same_color,FIRST,"shared variant unaffected by a private copy")
	var crowd: Array[Sprite2D]=[]
	for i: int in MATERIAL.VARIANTS_PER_BASE+4:
		var node:=Sprite2D.new();node.material=custom;crowd.append(node)
		MATERIAL.bind_display(node,crowd_color(i))
	var last: Sprite2D=crowd[-1]
	check(bool(last.material.get_meta("source_private_display",false)) and MATERIAL.display_base(last.material)==custom,"variant cache is bounded; extra colours fall back to a private copy")
	state(last,crowd_color(MATERIAL.VARIANTS_PER_BASE+3),"fallback copy")
	for node: Sprite2D in crowd:node.free()
	var foreign:=ShaderMaterial.new();var foreign_shader:=Shader.new()
	foreign_shader.code="shader_type canvas_item;\nvoid fragment(){ COLOR = texture(TEXTURE, UV); }\n"
	foreign.shader=foreign_shader;item.material=foreign
	MATERIAL.bind_display(item,NEXT)
	check(not MATERIAL.takes_display(foreign) and item.material==foreign,"a shader without the display parameters is left alone")
	var plain:=CanvasItemMaterial.new();item.material=plain
	MATERIAL.bind_display(item,NEXT);check(item.material==plain,"nonshader material unchanged")
	item.material=null;MATERIAL.bind_display(item,NEXT);check(item.material==null,"null material unchanged")
	item.free();sibling.free();same_color.free();particle.free()
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
						view.sprite.material.set_shader_parameter("source_display_bound",false)
						view.sprite.material.set_shader_parameter("source_display_color",FIRST)
					if phase==4:view.sprite.material=MATERIAL.original_default(tex)
					if phase==5:
						var shader:=Shader.new();shader.code=(view.sprite.material as ShaderMaterial).shader.code
						(view.sprite.material as ShaderMaterial).shader=shader
				MATERIAL.bind_display(candidate.sprite,color);original_bind(oracle.sprite,color)
				await process_frame
				await RenderingServer.frame_post_draw
				render_checks+=1
				check(pixels(candidate)==pixels(oracle),"full RGBA equal to unconditional setter oracle phase=%d pma=%s transparent=%s"%[phase,pma,transparent])
			candidate.viewport.free();oracle.viewport.free()
func run() -> void:
	headless_checks()
	if "--render" in OS.get_cmdline_user_args():await render_comparisons()
	print("SOURCE_MATERIAL_DISPLAY_UPDATES_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"render_checks":render_checks,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
