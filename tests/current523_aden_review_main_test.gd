extends SceneTree
var checks: int = 0
var failures: Array[String] = []
var screenshots: Array[String] = []
var views: Array[Dictionary] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func ready_frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func capture(tag: String) -> void:
	var directory: String = OS.get_environment("ADEN523_CAPTURE_DIR")
	if directory.is_empty(): return
	var screenshot := root.get_texture().get_image()
	check(screenshot != null and not screenshot.is_empty(), "actual rendered viewport image is available")
	if screenshot == null or screenshot.is_empty(): return
	var path: String = directory.path_join(tag + ".png")
	check(screenshot.save_png(path) == OK, "actual viewport capture saved")
	screenshots.append(path)

func run() -> void:
	check("--aden523-review" in OS.get_cmdline_user_args(), "explicit review mode required")
	var save_path: String = "user://twilight_v20_save.json"
	if not FileAccess.file_exists(save_path):
		var seed := FileAccess.open(save_path, FileAccess.WRITE)
		seed.store_string("{\"preserve_original_save\":523,\"gold\":7357123}")
		seed.close()
	var save_sha: String = FileAccess.get_sha256(save_path)
	var scene: PackedScene = load("res://Main.tscn")
	var world = scene.instantiate()
	root.add_child(world)
	await ready_frame()
	var review = world.current523_aden_review
	check(review != null and review.problem.is_empty(), "actual Main current523 review boots: " + (str(review.problem) if review != null else "no review"))
	if review == null or not review.problem.is_empty():
		print("CURRENT523_ADEN_REVIEW_MAIN_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
		world.queue_free(); quit(1); return
	check(world.field_map == null and world.maps.is_empty(), "review starts before the previous map/data bootstrap")
	check(world.process_mode == Node.PROCESS_MODE_DISABLED, "normal game simulation stays disabled in review")
	check(world._save_game(true) == ERR_UNAVAILABLE, "review cannot write a game save")
	world._load_game(true)
	check(FileAccess.get_sha256(save_path) == save_sha, "review startup and explicit save/load preserve original bytes")
	var original_player_position: Vector2 = world.player.global_position
	for member: String in ["Map/Aden/80138007.s32", "Map/Aden/800a8000.s32", "Map/Aden/800f7ff3e.s32"]:
		check(review.center_on_member(member), "select exact original source: " + member)
		review.call("_rebuild")
		await ready_frame()
		var metrics: Dictionary = review.frame_metrics()
		check(metrics.get("draw_commands", 0) > 0 and review.problem.is_empty(), "original M tile commands exist: " + member)
		check(metrics.get("cached_chunks", 1000) <= 48 and metrics.get("cached_atlases", 1000) <= 32 and metrics.get("visible_atlases", 1000) <= 256, "review caches remain bounded")
		check(metrics.get("unresolved_refs", -1) == 0, "consumed view has no substituted or missing tile references")
		check(metrics.get("budget_skips", -1) == 0 and metrics.get("skipped_chunks", -1) == 0, "tested viewport fits complete candidate draw budget")
		check(not metrics.get("M_projection_verified", true) and not metrics.get("movement_implemented", true), "display does not upgrade semantic status")
		if member.ends_with("800f7ff3e.s32"):
			check(metrics.local_only and metrics.visible_chunks == 1 and metrics.unplaced_sources == 1, "nonstandard original remains an unplaced single-source view")
		else: check(not metrics.local_only and metrics.candidate_placed_sources == 676, "standard candidate view is separately identified")
		views.append(metrics)
		capture(member.get_file().trim_suffix(".s32"))
	check(review.center_on_member("Map/Aden/800a8000.s32"), "return to changed523 member")
	var before: Dictionary = review.camera_state()
	review.pan_pixels(Vector2(900, 300))
	review.call("_rebuild")
	await ready_frame()
	check(review.camera_state().center != before.center, "review camera pans across candidate chunk space")
	var zoom_before: float = float(review.camera_state().zoom)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(900, 400)
	wheel.global_position = wheel.position
	root.push_input(wheel)
	await ready_frame()
	check(float(review.camera_state().zoom) > zoom_before, "actual viewport wheel input changes review zoom")
	var drag_before: Vector2 = review.camera_state().center
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(900, 400)
	press.global_position = press.position
	root.push_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(960, 420)
	motion.global_position = motion.position
	motion.relative = Vector2(60, 20)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	press.pressed = false
	root.push_input(press)
	await ready_frame()
	check(review.camera_state().center != drag_before, "actual viewport drag input pans inspection without actor movement")
	check(world.player.global_position == original_player_position, "review camera does not move the actor")
	check(FileAccess.get_sha256(save_path) == save_sha, "all displays and camera movement preserve save bytes")
	print("CURRENT523_ADEN_REVIEW_MAIN_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "views":views, "screenshots":screenshots, "scope":"ACTUAL_MAIN_OPENGL_SOURCE_DISPLAY_HYPOTHESIS; M_SPATIAL_AND_MOVEMENT_SEMANTICS_UNVERIFIED"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
