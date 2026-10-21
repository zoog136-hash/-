extends SceneTree

const FX = preload("res://scripts/animation/potion_feedback.gd")
var failures: int = 0
class TestWorld extends Node:
	var hp: int = 100
	var combat_generation: int = 0
	var presentation_settings: Dictionary = {"impact_intensity":0.85, "reduced_motion":false, "effect_detail":"full"}

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		print("POTION_RENDER FAIL: " + detail)

func lit_pixels(image: Image) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if color.r + color.g + color.b > 0.20: count += 1
	return count

func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(240, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.03, 0.03, 0.03)
	background.size = Vector2(240, 180)
	viewport.add_child(background)
	var world: TestWorld = TestWorld.new()
	viewport.add_child(world)
	var actor: Node2D = Node2D.new()
	actor.position = Vector2(120, 145)
	world.add_child(actor)
	var fx: TwilightPotionFeedback = FX.new()
	actor.add_child(fx)
	fx.setup(world, actor)
	DirAccess.make_dir_recursive_absolute("user://potion-feedback-review")
	var previous: PackedByteArray = PackedByteArray()
	for channel: String in FX.COLORS:
		fx.clear()
		fx.play(channel)
		fx.set_process(false)
		fx._process(0.08)
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		check(lit_pixels(image) > 20, "visible rendered light: " + channel)
		check(previous.is_empty() or previous != image.get_data(), "distinct rendered palette: " + channel)
		check(image.save_png("user://potion-feedback-review/%s.png" % channel) == OK, "capture written")
		previous = image.get_data()
	world.presentation_settings["impact_intensity"] = 0.0
	fx.queue_redraw()
	await RenderingServer.frame_post_draw
	check(lit_pixels(viewport.get_texture().get_image()) == 0, "zero intensity hides all light")
	world.presentation_settings["impact_intensity"] = 0.85
	world.presentation_settings["reduced_motion"] = true
	fx.clear()
	fx.play("health")
	fx.set_process(false)
	fx._process(0.08)
	await RenderingServer.frame_post_draw
	check(lit_pixels(viewport.get_texture().get_image()) > 20, "reduced-motion aura remains visible")
	fx._process(FX.LIFETIME)
	await RenderingServer.frame_post_draw
	check(lit_pixels(viewport.get_texture().get_image()) == 0, "expired light leaves no pixels")
	viewport.queue_free()
	await process_frame
	if failures == 0: print("POTION_FEEDBACK_RENDER_OK palettes=7 settings=2 lifetime=verified")
	quit(0 if failures == 0 else 1)
