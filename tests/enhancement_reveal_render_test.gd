extends SceneTree

const Reveal = preload("res://scripts/ui/enhancement_reveal.gd")
var failed: bool = false
var captures: int = 0

func _initialize() -> void: call_deferred("_run")

func energy(image: Image) -> float:
	var total: float = 0
	for y: int in range(160,380,8):
		for x: int in range(380,620,8):
			var pixel: Color = image.get_pixel(x,y)
			total += pixel.r+pixel.g+pixel.b
	return total

# Contrast the warm success burst with the non-success impact outside the icon.
# It checks a visible spatial light fan, rather than only a brighter central ring.
func warmth(image: Image) -> float:
	var total: float = 0.0
	for y: int in range(120,410,10):
		for x: int in range(240,760,10):
			if x > 425 and x < 575 and y > 195 and y < 355: continue
			var pixel: Color = image.get_pixel(x,y)
			total += maxf(0.0,pixel.r-pixel.b)
	return total

func capture(stage: Control, outcome: String, phase: float, suffix: String) -> Image:
	stage.clock = phase
	stage._process(0)
	stage.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var path: String = "user://enhancement-review/%s-%s.png" % [outcome,suffix]
	if frame.save_png(path) != OK: failed = true
	captures += 1
	return frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://enhancement-review"))
	root.size = Vector2i(1280,720)
	var item: Texture2D = load("res://assets/ui/sword.png") as Texture2D
	var success_fan_warmth: float = 0.0
	for outcome: String in ["success","maintain","decrease","destroy"]:
		var stage: Control = Reveal.new()
		stage.silent = true
		root.add_child(stage)
		stage.set_process(false)
		stage.present(outcome,"황혼의 장검",8,9 if outcome == "success" else 7,item)
		await capture(stage,outcome,1.2,"charge")
		var impact: Image = await capture(stage,outcome,Reveal.REVEAL_AT+0.03,"impact")
		var settled: Image = await capture(stage,outcome,Reveal.SETTLE_AT,"result")
		if outcome == "success":
			success_fan_warmth = warmth(impact)
			if energy(impact) <= energy(settled) or warmth(impact) <= warmth(settled):
				failed = true
				print("FAIL: success impact must be bright and warm outside the item")
		elif outcome == "maintain" and success_fan_warmth <= warmth(impact):
			failed = true
			print("FAIL: success needs a visibly warmer, broader fan than unchanged gear")
		stage.close_reveal()
		await process_frame
	# Same renderer exercises touch-sized wide, high-resolution, and portrait layouts.
	for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(900,1480)]:
		root.size = dimensions
		var stage: Control = Reveal.new()
		stage.silent = true
		stage.low_detail = true
		stage.reduced_motion = true
		root.add_child(stage)
		stage.set_process(false)
		stage.present("success","황혼의 장검",10,13,item)
		await capture(stage,"reduced",Reveal.REVEAL_AT+0.03,str(dimensions))
		stage.skip_to_result()
		stage.close_reveal()
		await process_frame
	if not failed: print("ENHANCEMENT_RENDER_OK captures=%d" % captures)
	quit(1 if failed else 0)
