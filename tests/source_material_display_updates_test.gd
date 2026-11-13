extends SceneTree
## Synthetic actual ShaderMaterial state and optional GL differential.
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
func original_bind(item: CanvasItem, color: Color) -> void:
	if not item.material is ShaderMaterial:return
	var current: ShaderMaterial=item.material
	if not bool(current.get_meta("source_private_display",false)):
		current=current.duplicate();current.set_meta("source_private_display",true);item.material=current
	current.set_shader_parameter("source_display_bound",true)
	current.set_shader_parameter("source_display_color",color)
func state(item: CanvasItem, color: Color, label: String) -> void:
	check(item.material.get_shader_parameter("source_display_bound")==true,label+" bound")
	check(item.material.get_shader_parameter("source_display_color")==color,label+" color")
func headless_checks() -> void:
	var tex:=texture()
	var prototype:=MATERIAL.original_default(tex)
	var item:=Sprite2D.new()
	var sibling:=Sprite2D.new()
	item.material=prototype;sibling.material=prototype
	MATERIAL.bind_display(item,FIRST)
	check(item.material!=prototype and sibling.material==prototype,"private material isolates shared prototype")
	# Real GL can populate default parameter cache while duplicate() enumerates
	# shader properties; that is not a binding to this item's display color.
	var prototype_bound: Variant=prototype.get_shader_parameter("source_display_bound")
	var prototype_color: Variant=prototype.get_shader_parameter("source_display_color")
	var unbound: bool=prototype_bound==null or (typeof(prototype_bound)==TYPE_BOOL and prototype_bound==false)
	var white: bool=prototype_color==null or (typeof(prototype_color)==TYPE_COLOR and prototype_color==Color.WHITE) or (typeof(prototype_color)==TYPE_VECTOR4 and prototype_color==Vector4.ONE)
	check(unbound and white,"prototype retains unbound default display")
	state(item,FIRST,"first binding")
	var private_material: Material=item.material
	for i: int in 100:MATERIAL.bind_display(item,FIRST)
	check(item.material==private_material,"unchanged binding retains private identity")
	state(item,FIRST,"unchanged binding")
	MATERIAL.bind_display(item,NEXT);state(item,NEXT,"color update")
	item.material.set_shader_parameter("source_display_bound",false)
	item.material.set_shader_parameter("source_display_color",FIRST)
	MATERIAL.bind_display(item,NEXT);state(item,NEXT,"external mutations corrected")
	item.material.set_shader_parameter("source_display_color",Vector4(NEXT.r,NEXT.g,NEXT.b,NEXT.a))
	item.material.set_shader_parameter("source_display_bound",1)
	MATERIAL.bind_display(item,NEXT)
	check(typeof(item.material.get_shader_parameter("source_display_color"))==TYPE_COLOR,"actual color variant type restored")
	check(typeof(item.material.get_shader_parameter("source_display_bound"))==TYPE_BOOL,"actual bool variant type restored")
	item.material.set_shader_parameter("source_display_bound",null)
	item.material.set_shader_parameter("source_display_color",null)
	MATERIAL.bind_display(item,NEXT);state(item,NEXT,"cleared parameters restored")
	item.material=prototype
	MATERIAL.bind_display(item,FIRST)
	check(item.material!=prototype and item.material!=private_material,"replacement prototype privately rebound")
	state(item,FIRST,"replacement material")
	var shader:=Shader.new();shader.code=(item.material as ShaderMaterial).shader.code
	(item.material as ShaderMaterial).shader=shader
	MATERIAL.bind_display(item,FIRST);state(item,FIRST,"shader replacement preserves cached parameters")
	item.material.set_shader_parameter("source_display_color",NEXT)
	MATERIAL.bind_display(item,FIRST);state(item,FIRST,"new shader external write corrected")
	var unknown:=ShaderMaterial.new();unknown.shader=shader
	item.material=unknown;MATERIAL.bind_display(item,NEXT)
	check(item.material!=unknown,"unmarked custom material privately cloned")
	state(item,NEXT,"custom material")
	var plain:=CanvasItemMaterial.new();item.material=plain
	MATERIAL.bind_display(item,NEXT);check(item.material==plain,"nonshader material unchanged")
	item.material=null;MATERIAL.bind_display(item,NEXT);check(item.material==null,"null material unchanged")
	item.free();sibling.free()
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
