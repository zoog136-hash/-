extends SceneTree
## Synthetic (no original pack): the bounded Sprite copy must address the
## render target, not the screen. On a phone the root Window letterboxes the
## 1280x720 base (stretch aspect keep), so its final transform carries the
## margin as origin, e.g. scale 1.25 and (200, 0) on a 2000x900 screen. A copy
## shifted by that margin left every transparent original-UI pixel (item icons
## in the quickslot/inventory, AUTO/SELF, currency icons) blending with a black
## or unrelated destination, while opaque skill icons still looked right.
const COPY = preload("res://scripts/ui/original_ui/source_sprite_back_buffer.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_SPRITE_COPY_LETTERBOX_FAIL: ", label)

func run() -> void:
	var local := Rect2(Vector2.ZERO, Vector2(64, 64))
	var at := Transform2D(0.0, Vector2(100, 600))
	# Phone: 2000x900 screen, base 1280x720, keep aspect -> x1.25, margin (200,0).
	var phone := Transform2D(0.0, Vector2(1.25, 1.25), 0.0, Vector2(200, 0))
	var bounds: Rect2 = COPY.render_target_bounds(phone, phone, at, local)
	check(bounds.position.is_equal_approx(Vector2(125, 750)) and bounds.size.is_equal_approx(Vector2(80, 80)), "letterbox margin is not part of the render-target copy rect: %s" % bounds)
	var old_rect: Rect2 = (phone * at) * local
	check(not old_rect.position.is_equal_approx(bounds.position), "the screen-space rect (old formula) is %s, 200px off" % old_rect)
	# A tall screen letterboxes vertically.
	var tall := Transform2D(0.0, Vector2(0.8, 0.8), 0.0, Vector2(0, 66))
	bounds = COPY.render_target_bounds(tall, tall, at, local)
	check(bounds.position.is_equal_approx(Vector2(80, 480)), "vertical margin is removed as well: %s" % bounds)
	# A CanvasLayer/camera transform stays in: only the final (screen) origin goes.
	var layer := Transform2D(0.0, Vector2(30, -12))
	bounds = COPY.render_target_bounds(phone * layer, phone, at, local)
	check(bounds.position.is_equal_approx(Vector2(162.5, 735)), "canvas layer offset is kept, scaled by the stretch: %s" % bounds)
	# SubViewports (and a 16:9 window) have no margin: same rect as before.
	var sub := Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2.ZERO)
	check(COPY.render_target_bounds(sub, sub, at, local) == (sub * at) * local, "no margin -> unchanged rect")
	# Wiring: the live copy node uses the helper with its own viewport.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.position = Vector2(40, 30)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	sprite.texture = ImageTexture.create_from_image(image)
	var copy: BackBufferCopy = COPY.new()
	viewport.add_child(copy)
	viewport.add_child(sprite)
	copy._runtime_supported = true
	copy.track(sprite)
	copy._sync_copy()
	var expected: Rect2 = COPY.render_target_bounds(sprite.get_viewport_transform(), viewport.get_final_transform(), sprite.get_global_transform(), sprite.get_rect())
	var first: Vector2 = expected.position.floor() - Vector2.ONE
	check(copy.copy_mode == BackBufferCopy.COPY_MODE_RECT and copy.rect.position == first, "copy node rect follows render_target_bounds: %s vs %s" % [copy.rect, expected])
	viewport.free()
	print("ORIGINAL_UI_SPRITE_COPY_LETTERBOX_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
