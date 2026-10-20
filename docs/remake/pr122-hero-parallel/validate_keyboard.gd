extends SceneTree
## Compare real Player physics/input in actual Main against the unmodified donor.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

func _initialize() -> void:
	call_deferred("_run")

func _trace(player: Node, start: Vector2, aim: Vector2, profile: Resource, reference: String) -> Array:
	player.position = start
	player.velocity = Vector2.ZERO
	player.set_transform_visual(reference, 1.0, profile)
	if not player.transform_active or player.transform_profile != profile or player.transform_sprite.sprite_frames.resource_path != profile.frames_path:
		push_error("HERO_KEYBOARD_RESOURCE_FAIL real resource must load without portrait fallback")
		return []
	for action: String in ACTIONS: Input.action_release(action)
	if aim.x < -.1: Input.action_press("move_left")
	if aim.x > .1: Input.action_press("move_right")
	if aim.y < -.1: Input.action_press("move_up")
	if aim.y > .1: Input.action_press("move_down")
	var result: Array = []
	for tick: int in range(6):
		await physics_frame
		player._physics_process(1.0 / 60.0)
		result.append([player.position.x, player.position.y, player.velocity.x, player.velocity.y])
	for action: String in ACTIONS: Input.action_release(action)
	return result

func _run() -> void:
	assert(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"))
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	assert(CLASS_QA.enter_game(world), "confirm the real Main starting class")
	world.hud._close_workspace()
	await process_frame
	# PROCESS_MODE_DISABLED removes CollisionObject2D bodies from the physics
	# space. Keep the actual Main space and stop callbacks individually instead.
	world.set_process(false)
	world.set_physics_process(false)
	for child: Node in world.find_children("*", "", true, false):
		child.set_process(false)
		child.set_physics_process(false)
	world.save_timer = -10000.0
	var player: Node = world.player
	var start: Vector2 = player.position
	var checked := 0
	var moved := 0
	var failures: Array = []
	var target_ids := OS.get_environment("TWILIGHT_HERO_TEST_IDS").split(",", false)
	if target_ids.is_empty(): target_ids = PackedStringArray(["179", "182"])
	for sid: String in target_ids:
		var record: Dictionary = {}
		for row: Dictionary in world.catalog_db["변신"]:
			if str(row.sourceId) == sid: record = row
		assert(not record.is_empty())
		var prior: Resource = CATALOG.for_record("transform", record, record.image_path)
		var candidate: Resource = load(staging.actors["transform:" + sid].native_profile)
		for direction: int in range(8):
			var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
			var before: Array = await _trace(player, start, aim, prior, record.image_path)
			var after: Array = await _trace(player, start, aim, candidate, record.image_path)
			if before.size() != 6 or after.size() != 6:
				failures.append({"id": sid, "direction": direction, "reason": "REAL_RESOURCE_OR_TRACE_UNAVAILABLE"})
				continue
			for tick: int in range(6):
				for field: int in range(4):
					if absf(before[tick][field] - after[tick][field]) > .002:
						failures.append({"id": sid, "direction": direction, "tick": tick, "field": field})
				checked += 1
			if Vector2(after[-1][0], after[-1][1]).distance_to(start) > .01: moved += 1
	player.position = start
	player.clear_transform_visual()
	world.queue_free()
	await process_frame
	var success := failures.is_empty() and moved == target_ids.size() * 8
	var actor: Dictionary = staging.actors["transform:" + target_ids[0]]
	var folder: String = actor.frames.get_base_dir().get_file()
	var group: String = actor.frames.get_base_dir().get_base_dir().get_file()
	var evidence_suffix := OS.get_environment("TWILIGHT_HERO_EVIDENCE_SUFFIX")
	assert(evidence_suffix.is_empty() or evidence_suffix.is_valid_identifier())
	var evidence := "res://docs/remake/pr122-hero-parallel/evidence/" + group + "-" + folder + "-visible-main" + ("-" + evidence_suffix if not evidence_suffix.is_empty() else "") + "/"
	DirAccess.make_dir_recursive_absolute(evidence)
	var result := {"schema": "hero-parallel-real-keyboard-physics-v1", "engine": Engine.get_version_info().string, "status": "PASS" if success else "FAIL", "cases": target_ids.size() * 8, "compared_physics_ticks": checked, "cases_with_actual_displacement": moved, "fields": ["position_x", "position_y", "velocity_x", "velocity_y"], "failures": failures, "new_approvals": 0, "frames_sha256": FileAccess.get_sha256(actor.frames), "run_png_sha256": FileAccess.get_sha256(actor.frames.get_base_dir() + "/run.png")}
	var file := FileAccess.open(evidence + "keyboard-physics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ") + "\n")
	print("HERO_KEYBOARD_PHYSICS_%s cases=%d compared_ticks=%d moving_cases=%d approvals=0" % ["PASS" if success else "FAIL", target_ids.size() * 8, checked, moved])
	quit(0 if success else 1)
