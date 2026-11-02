extends SceneTree
var output: String = "/workspace/original-deliverables/game-captures"
var observations: Array = []
var failures: int = 0
func _initialize() -> void:
	call_deferred("capture_game")
func shot(world: Node, label: String) -> void:
	await RenderingServer.frame_post_draw
	var expected: String = "walk" if "-walk-" in label else ("run" if "-run-" in label else ("attack" if "-attack-" in label else "idle"))
	if world.player.original_source_preview._role != expected:
		failures += 1
		push_error(label + ": actual source role is " + world.player.original_source_preview._role)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	observations.append({"label":label,"state":world.player.motion.state,"source_role":world.player.original_source_preview._role,"native_frame":world.player.original_source_preview.last_source_frame,"facing":world.player.motion.facing8,"fps":Engine.get_frames_per_second(),"position":str(world.player.global_position)})
func capture_game() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var world = load("res://Main.tscn").instantiate()
	world.active_map_id = "albino_01" # Explicit authored-map validation fixture; default Aden requires a separate map pack.
	root.add_child(world)
	current_scene = world
	for frame: int in range(12): await process_frame
	if world.hud.class_picker_initial:
		world._on_job_class_selected("기사")
		world.hud.complete_class_selection()
		for frame: int in range(3): await process_frame
	if world.map_bootstrap_blocked:
		push_error("Map bootstrap blocked; cannot claim an actual game capture.")
		quit(1)
		return
	for id: int in [267,393]:
		var selected: Dictionary = {}
		for record: Dictionary in world.catalog_db.get("변신", []):
			if str(record.get("sourceId", "")) == str(id): selected = record
		if selected.is_empty():
			push_error("Missing actual catalog record " + str(id))
			quit(1)
			return
		world._apply_transform_visual(selected)
		world.player.motion.face(Vector2.DOWN)
		for frame: int in range(24): await process_frame
		await shot(world, str(id) + "-idle-front")
		var prior_speed: float = world.player.move_speed
		world.player.move_speed = 90.0 # Exercise the existing Walk state in this isolated capture.
		world.player.touch_vector = Vector2.DOWN
		for frame: int in range(8): await process_frame
		await shot(world, str(id) + "-walk-front")
		world.player.touch_vector = Vector2.ZERO
		world.player.move_speed = prior_speed
		for frame: int in range(3): await process_frame
		world.player.touch_vector = Vector2.DOWN
		for frame: int in range(8): await process_frame
		await shot(world, str(id) + "-run-front")
		world.player.touch_vector = Vector2.ZERO
		for frame: int in range(3): await process_frame
		world.player.start_combat_attack(world.player.global_position + Vector2(0,100),0.4,"slash",0.5)
		for frame: int in range(6): await process_frame
		await shot(world, str(id) + "-attack-front")
		for frame: int in range(30): await process_frame
		await shot(world, str(id) + "-return-idle")
	var file: FileAccess = FileAccess.open(output.path_join("observations.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"observations":observations,"limits":["Main scene with explicit historical map validation fixture","Literal body/shadow only; sc/mu composition unresolved","Linux software rendering, not Android 30FPS validation","Walk exercised at isolated test speed90; normal game speed restored"]},"\t"))
	file.close()
	print("ORIGINAL_SOURCE_GAME_CAPTURES: ", observations.size())
	quit(1 if failures else 0)
