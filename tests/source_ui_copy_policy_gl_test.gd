extends SceneTree
## Synthetic Compatibility GL differential. Forced original copies are the
## pixel oracle; no original art, native-client or Android timing claim.
const COPY = preload("res://scripts/ui/original_ui/source_sprite_back_buffer.gd")
const BLEND = preload("res://scripts/ui/original_ui/source_blend.gd")
const MATERIAL = preload("res://scripts/ui/original_ui/source_material.gd")
const PARTICLE = preload("res://scripts/ui/original_ui/source_particle.gd")
const PANEL = preload("res://scripts/ui/original_ui/source_panel.gd")
var checks: int = 0
var failures: Array[String] = []
var pixel_comparisons: int = 0
var reference_copies: Array[BackBufferCopy] = []

class FakePack extends RefCounted:
	var image: Texture2D
	func particle(_options: Dictionary) -> Dictionary:
		return {"ok":true,"member":"synthetic.plist","texture_member":"synthetic.png","texture":image,"values":{"maxParticles":2,"emitterType":0,"particleLifespan":1,"duration":-1}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("COPY_POLICY_GL_FAIL: ",label)

func synthetic_texture(pma: bool) -> Texture2D:
	var image := Image.create_empty(16,16,false,Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 16:
			var a: float = float((x*23+y*11)%256)/255.0
			var color := Color(float(x)/15.0,float(y)/15.0,float((x+y)%16)/15.0,a)
			if pma: color = Color(color.r*a,color.g*a,color.b*a,a)
			image.set_pixel(x,y,color)
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta("cocos_premultiplied",pma)
	return texture

func collect_copies(node: Node, found: Array[BackBufferCopy]) -> void:
	if node is BackBufferCopy: found.append(node)
	for child: Node in node.get_children(): collect_copies(child,found)

func make_view(texture: Texture2D, pair: String, transparent: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96,80)
	viewport.transparent_bg = transparent
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(96,80)
	background.color = Color(0.17,0.39,0.63,0.57)
	var background_shader := Shader.new()
	background_shader.code = "shader_type canvas_item;render_mode unshaded,blend_disabled;void fragment(){COLOR=COLOR;}"
	var background_material := ShaderMaterial.new()
	background_material.shader = background_shader
	background.material = background_material
	viewport.add_child(background)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(15.25,19.5)
	sprite.scale = Vector2(2.0,1.8)
	sprite.rotation = 0.11
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = BLEND.material(texture,pair)
	MATERIAL.bind_display(sprite,Color(0.83,0.67,0.91,0.73))
	var copy := COPY.new()
	viewport.add_child(copy)
	viewport.add_child(sprite)
	copy.track(sprite)
	var pack := FakePack.new()
	pack.image = texture
	var emitter := PARTICLE.new()
	emitter.position = Vector2(47.0,37.0)
	var factors: PackedStringArray = pair.split(":")
	check(emitter.configure(pack,{"fileNameData":{},"blendFunc":[int(factors[0]),int(factors[1])]}).ok,"actual synthetic particle configures")
	viewport.add_child(emitter)
	emitter.set_process(false)
	# Fixed simulation snapshot: test submission/copies without RNG or cadence.
	emitter.state.particles.assign([
		{"position":Vector2(-4.5,1.5),"rotation":13.0,"size":28.0,"color":Color(0.82,0.36,0.92,0.61)},
		{"position":Vector2(6.0,-7.0),"rotation":-17.0,"size":22.0,"color":Color(0.41,0.91,0.58,0.77)}])
	emitter._sync_quads()
	var panel := PANEL.new()
	panel.position = Vector2(29.5,67.25)
	var options: Dictionary = {"colorType":1,"bgColorOpacity":173,"bgColor":[255,79,126,234],"backGroundImageData":{"path":""}}
	check(panel.configure(pack,options,Vector2(40,29)).ok,"actual synthetic panel configures")
	viewport.add_child(panel)
	panel.set_source_display(Color(0.91,0.78,0.62,0.81))
	var copies: Array[BackBufferCopy] = []
	collect_copies(viewport,copies)
	check(copies.size()==4,"one sprite, two particles and one panel retain their ordered copy nodes")
	return {"viewport":viewport,"sprite":sprite,"emitter":emitter,"panel":panel,"copies":copies}

func set_materials(view: Dictionary, texture: Texture2D, pair: String) -> void:
	view.sprite.material = BLEND.material(texture,pair)
	MATERIAL.bind_display(view.sprite,Color(0.83,0.67,0.91,0.73))
	for quad: Sprite2D in view.emitter._quads:
		quad.material = BLEND.material(texture,view.emitter.blend_pair,true)
	view.emitter._sync_quads()
	view.panel._color.material = PANEL.layer_material()
	view.panel.set_source_display(Color(0.91,0.78,0.62,0.81))

func force_reference_copies() -> void:
	for copy: BackBufferCopy in reference_copies:
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT

func enabled_copies(view: Dictionary) -> int:
	var result: int = 0
	for copy: BackBufferCopy in view.copies:
		if copy.copy_mode != BackBufferCopy.COPY_MODE_DISABLED: result += 1
	return result

func pixels(view: Dictionary) -> PackedByteArray:
	var image: Image = view.viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image.get_data()

func compare_frame(candidate: Dictionary, reference: Dictionary, expected_copies: int, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	pixel_comparisons += 1
	check(pixels(candidate)==pixels(reference),label+" RGBA bytes equal forced-copy oracle")
	check(enabled_copies(reference)==4,label+" oracle still submits four copies")
	check(enabled_copies(candidate)==expected_copies,label+" active material determines copy count")

func run() -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility":
		printerr("SOURCE_UI_COPY_POLICY_REQUIRES_COMPATIBILITY_GL")
		quit(2);return
	var original_policy: bool = BLEND.screen_copy_available
	for transparent: bool in [false,true]:
		for pair_index: int in BLEND.PAIRS.size():
			var pair: String = BLEND.PAIRS[pair_index]
			var texture: Texture2D = synthetic_texture(pair_index%2==1)
			BLEND.screen_copy_available = false
			PANEL._layer_material = null
			var candidate: Dictionary = make_view(texture,pair,transparent)
			var reference: Dictionary = make_view(texture,pair,transparent)
			reference_copies.assign(reference.copies)
			# Last connection overrides production copy sync only in the oracle.
			RenderingServer.frame_pre_draw.connect(force_reference_copies)
			for exact: bool in [false,true,false]:
				BLEND.screen_copy_available = exact
				PANEL._layer_material = null
				set_materials(candidate,texture,pair)
				set_materials(reference,texture,pair)
				# A later policy flip cannot misclassify already-bound materials.
				BLEND.screen_copy_available = not exact
				await compare_frame(candidate,reference,4 if exact else 0,"pair=%s alpha=%s exact=%s" % [pair,transparent,exact])
			# Unknown deep-copied shaders retain conservative copies, still identical.
			for view: Dictionary in [candidate,reference]:
				view.sprite.material = view.sprite.material.duplicate(true)
			await compare_frame(candidate,reference,1,"deep copied fixed shader pair="+pair)
			RenderingServer.frame_pre_draw.disconnect(force_reference_copies)
			reference_copies.clear()
			candidate.viewport.free()
			reference.viewport.free()
	BLEND.screen_copy_available = original_policy
	PANEL._layer_material = null
	print("SOURCE_UI_COPY_POLICY_GL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
