extends SceneTree

const VFX = preload("res://scripts/animation/combat_vfx.gd")
const STYLES: Array[String] = ["slash", "thrust", "heavy", "bow", "gun", "magic", "poison", "bleed"]
var fx: TwilightCombatVFX
var failures: int = 0

class Backdrop extends Node2D:
	const LABELS: Array[String] = ["slash", "thrust", "heavy", "bow", "gun", "magic", "poison", "bleed"]
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color(.09, .105, .12))
		var font: Font = preload("res://assets/fonts/NotoSansKR.ttf")
		draw_string(font, Vector2(24, 38), "TWILIGHT / HIT FEEDBACK / ORIGINAL PROCEDURAL VFX", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(.82, .85, .90))
		draw_string(font, Vector2(24, 76), "Normal contact  /  Critical contact     (isolated renderer test, not gameplay footage)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(.6, .65, .72))
		for i: int in range(8):
			var x: float = float(i) * 160.0 + 80.0
			draw_string(font, Vector2(x - 44, 125), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(.8, .83, .88))
			for y: float in [275.0, 495.0]:
				draw_circle(Vector2(x, y), 22.0, Color(.16, .18, .21))
				draw_arc(Vector2(x, y), 30.0, 0.0, TAU, 32, Color(.3, .32, .36), 1.0, true)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.add_child(Backdrop.new())
	fx = VFX.new()
	root.add_child(fx)
	await process_frame
	var directory: String = "user://hit-feedback-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for age: float in [0.0, .04, .12, .24]:
		fx.clear()
		for i: int in range(STYLES.size()):
			for critical: bool in [false, true]:
				var point: Vector2 = Vector2(float(i) * 160.0 + 80.0, 495.0 if critical else 275.0)
				fx.impact(point, Vector2.RIGHT.rotated(float(i) * PI / 4.0), STYLES[i], critical)
				fx.number(point + Vector2(0, -52), "CRIT 640" if critical else "320", Color(1.0, .85, .48), critical)
		for entry: Dictionary in fx.active: entry.age = minf(age, float(entry.duration) - .001)
		fx.set_process(false)
		fx.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = directory + "/contact-%03dms.png" % int(round(age * 1000.0))
		if image.is_empty() or image.save_png(path) != OK: failures += 1
		print("HIT_FEEDBACK_CAPTURE " + path)
		if fx.detailed_draws > 32: failures += 1
	fx.clear()
	for i: int in range(160):
		fx.impact(Vector2(50 + (i % 16) * 76, 150 + (i / 16) * 45), Vector2.RIGHT, "heavy", i % 3 == 0)
	fx.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	if fx.detailed_draws != 32 or fx.active.size() != 160: failures += 1
	var overflow: Image = root.get_texture().get_image()
	if overflow.save_png(directory + "/bounded-crowd.png") != OK: failures += 1
	fx._process(2.0)
	if not fx.active.is_empty() or fx.available.size() != 160: failures += 1
	print("HIT_FEEDBACK_RENDER_%s captures=5 detail_limit=32" % ("OK" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)
