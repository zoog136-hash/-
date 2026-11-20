extends SceneTree
## Original attr128 ("_mu" sprites) is the multiply kernel
## result = mix(dst, dst * src, src.a) (restored M 1.10.22.0 kernel 2). The
## Android copy-free path used to draw it as MIX alpha 0.5, a translucent white
## film over actors (user report 2026-11-20 "케릭 뿌연건 여전히 있네").
## Checks the policy, the copy-free fallback, the shared materials, the cooker
## capture and the draw-time correction of the installed legacy cooked pack.
## With a real renderer (not --headless) it also checks GPU pixels.
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const STORE = preload("res://scripts/resources/cooked_actor_store.gd")
const COOKER = preload("res://scripts/resources/cooked_actor_cooker.gd")
const PINS = preload("res://scripts/boot/cooked_actor_pins.gd")
var checks: int = 0
var render_checks: int = 0
var failures: Array = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var previous_copy: bool = COMPOSITOR.screen_copy_available
	var previous_cooked: String = PINS.cooked_id
	# Policy: attr128 is multiply at full opacity, attr8 stays additive.
	var mul: Dictionary = POLICY.effect(["128"], "compatible")
	check(mul.get("enabled", false) and int(mul.get("blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MUL and is_equal_approx(float(mul.get("alpha", 0.0)), 1.0), "policy attr128 is multiply alpha1")
	check(int(POLICY.effect(["8"], "compatible").get("blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD, "policy attr8 unchanged")
	check(not POLICY.effect(["128"], "strict").get("enabled", true), "strict mode unchanged")
	# Copy-free fallback (Android).
	COMPOSITOR.screen_copy_available = false
	var own128: Dictionary = COMPOSITOR.fallback_style({"kind":"clothes","source_attributes":["128"]}, [], false, "compatible")
	check(int(own128.get("blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MUL and is_equal_approx(float(own128.get("alpha", 0.0)), 1.0) and int(own128.get("flags", -1)) == 128, "copy-free own128 is multiply")
	var body128: Dictionary = COMPOSITOR.fallback_style({"kind":"body","source_attributes":["128"]}, ["128"], false, "compatible")
	check(int(body128.get("blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MUL, "copy-free body128 is multiply")
	var shadow: Dictionary = COMPOSITOR.fallback_style({"kind":"shadow"}, ["0"], false, "compatible", true)
	check(int(shadow.get("blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MIX and is_equal_approx(float(shadow.get("alpha", 0.0)), 0.5), "shadow average stays MIX alpha0.5")
	var screen: Dictionary = COMPOSITOR.fallback_style({"kind":"shadow"}, ["8"], false, "compatible", true)
	check(int(screen.get("blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD, "shadow9 stays additive")
	check(COMPOSITOR.fallback_style({"kind":"clothes","source_attributes":["128"]}, [], false, "strict").is_empty(), "strict fallback unchanged")
	COMPOSITOR.screen_copy_available = true
	check(COMPOSITOR.fallback_style({"kind":"clothes","source_attributes":["128"]}, [], false, "compatible").is_empty(), "screen-copy path keeps the recovered kernel")
	COMPOSITOR.screen_copy_available = false
	# Shared materials.
	var material: Material = COMPOSITOR.blend_material(CanvasItemMaterial.BLEND_MODE_MUL)
	check(material is ShaderMaterial and material == COMPOSITOR.multiply_material(), "multiply uses the shared multiply material")
	check(COMPOSITOR.material_blend(material) == CanvasItemMaterial.BLEND_MODE_MUL, "multiply material reports BLEND_MODE_MUL")
	var own: ShaderMaterial = COMPOSITOR.new_multiply_material()
	check(own != material and own.shader == (material as ShaderMaterial).shader and COMPOSITOR.material_blend(own) == CanvasItemMaterial.BLEND_MODE_MUL, "per-node multiply materials share the shader")
	var code: String = (material as ShaderMaterial).shader.code
	check("blend_mul" in code and not "hint_screen_texture" in code and not "SCREEN_" in code, "multiply reads no screen copy")
	check(COMPOSITOR.blend_material(CanvasItemMaterial.BLEND_MODE_ADD) is CanvasItemMaterial and COMPOSITOR.material_blend(COMPOSITOR.blend_material(CanvasItemMaterial.BLEND_MODE_ADD)) == CanvasItemMaterial.BLEND_MODE_ADD, "add stays CanvasItemMaterial")
	check(COMPOSITOR.material_blend(null) == CanvasItemMaterial.BLEND_MODE_MIX and COMPOSITOR.material_blend(ShaderMaterial.new()) == -1, "unknown shaders are not a blend")
	# The cooker records the multiply material as BLEND_MODE_MUL.
	var preview := Node2D.new()
	root.add_child(preview)
	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	image.set_pixel(0, 0, Color(0.5, 0.25, 1.0, 1.0))
	image.set_pixel(1, 0, Color(0, 0, 0, 0))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.material = COMPOSITOR.multiply_material()
	sprite.z_index = 1
	preview.add_child(sprite)
	var captured: Dictionary = COOKER.capture(preview)
	check(captured.get("ok", false) and captured.items.size() == 1 and int(captured.items[0].blend) == CanvasItemMaterial.BLEND_MODE_MUL and captured.items[0].color == Color.WHITE, "cooker records multiply as BLEND_MODE_MUL")
	var other := ShaderMaterial.new()
	other.shader = Shader.new()
	other.shader.code = "shader_type canvas_item;\n"
	sprite.material = other
	check(COOKER.capture(preview).get("error", "") == "cooked_capture_shader_material", "other shaders are still rejected by the cooker")
	preview.free()
	# Installed legacy pack: draw-time correction of MIX alpha0.5 attr128 items.
	PINS.cooked_id = STORE.LEGACY_MIX_HALF_COOKED_ID
	var clothes_actor := STORE.CookedActor.new()
	clothes_actor.key = "transform_15631"
	var body_actor := STORE.CookedActor.new()
	body_actor.key = "overlay_13504"
	check(STORE.legacy_multiply_scope(clothes_actor) == 1 and STORE.legacy_multiply_scope(body_actor) == 2, "legacy scopes from the pinned pack")
	var half := Color(1, 1, 1, 0.5)
	var mix := CanvasItemMaterial.BLEND_MODE_MIX
	check(STORE.legacy_multiply_item(1, mix, 1, half), "legacy clothes attr128 item becomes multiply")
	check(not STORE.legacy_multiply_item(1, mix, 0, half) and not STORE.legacy_multiply_item(1, mix, -1, half), "legacy shadow average stays MIX")
	check(STORE.legacy_multiply_item(2, mix, 0, half), "legacy attr128 body item becomes multiply")
	check(not STORE.legacy_multiply_item(1, mix, 1, Color.WHITE) and not STORE.legacy_multiply_item(1, CanvasItemMaterial.BLEND_MODE_ADD, 1, half) and not STORE.legacy_multiply_item(1, mix, 1, Color(0.5, 1, 1, 0.5)), "other items unchanged")
	PINS.cooked_id = "fixture-other-pack"
	var fresh := STORE.CookedActor.new()
	fresh.key = "transform_15631"
	check(STORE.legacy_multiply_scope(fresh) == 0, "another cooked pack is drawn as recorded")
	PINS.cooked_id = previous_cooked
	# GPU pixels (skipped under --headless).
	if DisplayServer.get_name() != "headless":
		await _render()
	COMPOSITOR.screen_copy_available = previous_copy
	print("SOURCE_MULTIPLY_BLEND_RESULT " + JSON.stringify({"checks":checks,"render_checks":render_checks,"failures":failures,"scope":"attr128 multiply policy, copy-free fallback, cooker capture, legacy cooked correction"}))
	quit(0 if failures.is_empty() else 1)

func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 4)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := Color(0.2, 0.6, 0.4, 1.0)
	var bg := ColorRect.new()
	bg.color = background
	bg.size = Vector2(16, 4)
	viewport.add_child(bg)
	var texels: Array[Color] = [Color(0, 0, 0, 0), Color(1, 1, 1, 0), Color(0.5, 0.5, 0.5, 1), Color(0.5, 0.5, 0.5, 0.5), Color(1, 0, 0, 1), Color(1, 1, 1, 1)]
	var image := Image.create_empty(texels.size(), 1, false, Image.FORMAT_RGBA8)
	for x: int in texels.size(): image.set_pixel(x, 0, texels[x])
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = COMPOSITOR.multiply_material()
	viewport.add_child(sprite)
	for i: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var out: Image = viewport.get_texture().get_image()
	for x: int in texels.size():
		var s: Color = texels[x]
		var expected := Color(background.r * lerpf(1.0, s.r, s.a), background.g * lerpf(1.0, s.g, s.a), background.b * lerpf(1.0, s.b, s.a))
		var actual: Color = out.get_pixel(x, 0)
		render_checks += 1
		check(absf(actual.r - expected.r) < 0.012 and absf(actual.g - expected.g) < 0.012 and absf(actual.b - expected.b) < 0.012, "GPU multiply texel %d: %s != %s" % [x, actual, expected])
	viewport.free()
