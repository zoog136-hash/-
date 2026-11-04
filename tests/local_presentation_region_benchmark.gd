extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	if not QA.enter_game(world) or not bool(world.load_source_optimization(OS.get_environment("TWILIGHT_PATCH523_CONTENT")).ok): quit(1);return
	world.player.set_physics_process(false)
	var origin: Vector2 = world.player.global_position
	var results: Dictionary = {}
	for state: String in ["off","inside","outside"]:
		if state!="off": world.set_local_presentation_region(world.active_map_id,{"enabled":true,"center":origin,"radius":64.0,"row_id":53942,"branch":"condition"})
		if state=="outside": world.player.global_position = origin+Vector2(65,0)
		world._update_source_optimization()
		var times: Array[int] = []
		for sample: int in range(5):
			var start: int = Time.get_ticks_usec()
			for i: int in range(10000): world._update_source_optimization()
			times.append(Time.get_ticks_usec()-start)
		times.sort()
		results[state] = {"median_us_per_10000":times[2],"samples_us":times,"impact_budget":world.combat_vfx.impact_visual_limit}
	world.queue_free()
	await process_frame
	print("LOCAL_PRESENTATION_MEASUREMENT ",JSON.stringify({"results":results,"scope":"actual Main steady-state update cost; no device FPS or native M geometry claim"}))
	quit()
