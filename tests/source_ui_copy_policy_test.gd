extends SceneTree
## Synthetic ownership/mode checks. GL framebuffer equality is tested separately.
const COPY = preload("res://scripts/ui/original_ui/source_destination_copy.gd")
const SPRITE_COPY = preload("res://scripts/ui/original_ui/source_sprite_back_buffer.gd")
const BLEND = preload("res://scripts/ui/original_ui/source_blend.gd")
const MATERIAL = preload("res://scripts/ui/original_ui/source_material.gd")
const PANEL = preload("res://scripts/ui/original_ui/source_panel.gd")
const PARTICLE = preload("res://scripts/ui/original_ui/source_particle.gd")
var checks: int = 0
var failures: Array[String] = []

class FakePack extends RefCounted:
	var image: Texture2D
	func particle(_options: Dictionary) -> Dictionary:
		return {"ok":true,"texture":image,"member":"synthetic.plist","texture_member":"synthetic.png","values":{"maxParticles":4,"emitterType":0,"particleLifespan":3.0,"duration":-1.0,"startParticleSize":8.0,"finishParticleSize":-1.0,"startColorRed":1.0,"startColorGreen":1.0,"startColorBlue":1.0,"startColorAlpha":0.5,"finishColorRed":1.0,"finishColorGreen":1.0,"finishColorBlue":1.0,"finishColorAlpha":0.5}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("COPY_POLICY_FAIL: "+label)

func material(texture: Texture2D, exact: bool, pair: String = "770:771") -> ShaderMaterial:
	BLEND.screen_copy_available = exact
	return BLEND.material(texture,pair)

func sync(copies: Array) -> int:
	var enabled: int = 0
	for copy: BackBufferCopy in copies:
		copy.call("_sync_copy")
		if copy.copy_mode != BackBufferCopy.COPY_MODE_DISABLED: enabled += 1
	return enabled

func run() -> void:
	var was: bool = BLEND.screen_copy_available
	var connections_before: int = RenderingServer.frame_pre_draw.get_connections().size()
	BLEND._cache.clear()
	var picture := Image.create_empty(8,8,false,Image.FORMAT_RGBA8)
	picture.fill(Color(0.8,0.3,0.6,0.5))
	var texture := ImageTexture.create_from_image(picture)
	var container := Node2D.new()
	root.add_child(container)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	var copy := SPRITE_COPY.new()
	container.add_child(copy)
	container.add_child(sprite)
	copy.track(sprite)
	check(COPY.requires_copy(sprite) and sync([copy]) == 1,"unknown/null material retains conservative copy")
	for exact: bool in [false,true]:
		for pair: String in BLEND.PAIRS:
			sprite.material = material(texture,exact,pair)
			check(COPY.requires_copy(sprite) == exact and sync([copy]) == int(exact),"active shader owns copy decision "+pair+" exact="+str(exact))
			var shader: Shader = (sprite.material as ShaderMaterial).shader
			MATERIAL.bind_display(sprite,Color(0.7,0.8,0.9,0.6))
			check((sprite.material as ShaderMaterial).shader == shader and COPY.requires_copy(sprite) == exact,"display material duplication preserves classification")
	var fixed: ShaderMaterial = material(texture,false)
	var exact: ShaderMaterial = material(texture,true)
	sprite.material = fixed
	check(sync([copy]) == 0,"fixed shader stays copy-free when global policy later changes")
	BLEND.screen_copy_available = false
	sprite.material = exact
	check(sync([copy]) == 1,"exact cached shader retains copy with fixed global policy")
	sprite.material = fixed
	check(sync([copy]) == 0,"material swap immediately returns to no-copy path")
	sprite.use_parent_material = true
	check(sync([copy]) == 1,"inherited material is conservative even with fixed local shader")
	sprite.use_parent_material = false
	var unknown := ShaderMaterial.new()
	unknown.shader = Shader.new()
	unknown.shader.code = "shader_type canvas_item; void fragment() { COLOR=texture(TEXTURE,UV); }"
	sprite.material = unknown
	check(sync([copy]) == 1,"unmarked shader is not inferred copy-free from text")
	var clone: ShaderMaterial = fixed.duplicate()
	clone.shader = fixed.shader.duplicate()
	sprite.material = clone
	check(sync([copy]) == 1,"deep-cloned shader marker cannot impersonate original shader")
	sprite.material = fixed
	fixed.shader.code += "\n// changed generated shader is no longer verified\n"
	check(sync([copy]) == 1,"shader edits invalidate copy-free classification")
	BLEND._cache.clear()
	sprite.material = material(texture,false)
	copy._runtime_supported = false
	check(sync([copy]) == 0,"known fixed shader skips copies even without rect-copy runtime support")
	sprite.material = material(texture,true)
	check(sync([copy]) == 1 and copy.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT,"unknown runtime retains full exact copy")
	sprite.hide()
	check(sync([copy]) == 0,"hidden exact sprite remains copy-disabled")
	sprite.show()
	# Real emitter quad creation and per-particle private display materials.
	var pack := FakePack.new()
	pack.image = texture
	var before_emitter: int = RenderingServer.frame_pre_draw.get_connections().size()
	var emitter := PARTICLE.new()
	BLEND.screen_copy_available = false
	check(emitter.configure(pack,{"fileNameData":{},"blendFunc":[770,771]},func() -> float: return 0.0).ok,"synthetic source emitter configures")
	container.add_child(emitter)
	emitter.set_process(false)
	emitter.advance(1.6)
	var particles: PackedByteArray = var_to_bytes(emitter.state.particles)
	var children: Array = emitter.get_children()
	check(emitter._quads.size() == 2 and emitter._copies.size() == 2 and sync(emitter._copies) == 0,"two emitted quads preserve their nodes but disable two fixed copies")
	check(RenderingServer.frame_pre_draw.get_connections().size() == before_emitter+1,"particle copy checks use one draw hook per emitter")
	for index: int in emitter._quads.size():
		check(children[index*2] == emitter._copies[index] and children[index*2+1] == emitter._quads[index],"particle copy/quad order unchanged")
		emitter._quads[index].material = exact
	check(sync(emitter._copies) == 2,"direct particle material switches reenable copies before draw")
	for quad: Sprite2D in emitter._quads: quad.material = material(texture,false)
	check(sync(emitter._copies) == 0 and var_to_bytes(emitter.state.particles) == particles,"copy policy leaves particle state and count untouched")
	emitter.hide()
	for quad: Sprite2D in emitter._quads: quad.material = exact
	check(sync(emitter._copies) == 0,"hidden emitter copies stay disabled")
	emitter.show()
	check(sync(emitter._copies) == 2,"shown exact emitter reenables the same copies")
	# Real panel construction; its cached active shader wins over global policy.
	PANEL._layer_material = null
	BLEND.screen_copy_available = false
	var panel := PANEL.new()
	check(panel.configure(pack,{"colorType":1,"bgColorOpacity":128,"bgColor":[255,90,150,210],"backGroundImageData":{"path":""}},Vector2(24,18)).ok,"synthetic source panel configures")
	container.add_child(panel)
	var vertices: PackedColorArray = panel._color.vertex_colors
	check(panel.get_child(0) == panel._color_copy and panel.get_child(1) == panel._color and sync([panel._color_copy]) == 0,"panel preserves source child order with fixed copy disabled")
	BLEND.screen_copy_available = true
	check(sync([panel._color_copy]) == 0,"cached fixed panel does not follow unrelated global toggle")
	PANEL._layer_material = null
	panel._color.material = PANEL.layer_material()
	check(sync([panel._color_copy]) == 1,"panel material switch restores exact full copy")
	panel._color.material = unknown
	check(sync([panel._color_copy]) == 1,"unknown panel shader retains full copy")
	panel.set_source_display(Color(1,1,1,0))
	check(sync([panel._color_copy]) == 0,"transparent panel visibility disables copy")
	panel.set_source_display(Color.WHITE)
	check(sync([panel._color_copy]) == 1 and panel._color.vertex_colors == vertices,"panel color/alpha survive disable and reenable")
	container.free()
	check(RenderingServer.frame_pre_draw.get_connections().size() == connections_before,"retiring copies and emitter disconnects every draw hook")
	PANEL._layer_material = null
	BLEND._cache.clear()
	BLEND.screen_copy_available = was
	print("SOURCE_UI_COPY_POLICY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
