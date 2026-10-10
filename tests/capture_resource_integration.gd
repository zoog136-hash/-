extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var captures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _capture(directory: String, name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(directory + "/" + name_value + ".png") != OK:
		push_error("Failed real resource capture " + name_value)
		quit(1)
		return
	captures.append(name_value)

func _run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	if not CLASS_QA.enter_game(world):
		push_error("Resource review class confirmation failed")
		quit(1)
		return
	world.hud._close_workspace()
	world.save_timer = -10000
	var directory: String = "user://resource-integration-review"
	DirAccess.make_dir_recursive_absolute(directory)
	for id: String in ["aden_world", "oman_01", "oman_10", "albino_04", "faith_04"]:
		world.rng.seed = 20261010
		world._set_map(id, false)
		var review: Variant = world.field_map.data.get("review_points", {}).get("central", [3550, 4300])
		var point := Vector2(float(review[0]), float(review[1]))
		world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(point))
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.player.set_physics_process(false)
		world.field_population.set_process(false)
		for actor: TwilightMonster in world.monsters_root.get_children(): actor.set_physics_process(false)
		world.field_renderer.refresh_visible()
		for i: int in range(15): await process_frame
		await _capture(directory, id)
	# Real equip APIs preserve effects and use the production follower renderer.
	world._set_map("aden_world", false)
	world.player.set_physics_process(false)
	world.hud._close_workspace()
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550, 4300)))
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	for category: String in ["변신", "마법인형", "성물"]:
		world._equip_catalog(category, world.catalog_db[category][0])
	for actor: TwilightMonster in world.monsters_root.get_children(): actor.set_physics_process(false)
	for i: int in range(15): await process_frame
	for phase: int in range(6):
		world.player.motion.gait = float(phase)
		world.player.motion.state = "walk"
		world.player.motion.move_ratio = 1.0
		world.player.motion.face(Vector2.DOWN)
		world.player.motion.apply(world.player.transform_sprite, world.player.transform_sprite.get_meta("base_scale", Vector2.ONE))
		await _capture(directory, "catalog-walk-" + str(phase))
	world.player.start_combat_attack(world.player.global_position + Vector2.RIGHT * 100, .6, "slash")
	for phase: int in range(6):
		world.player.motion.advance(.1, Vector2.ZERO)
		world.player.motion.apply(world.player.transform_sprite, world.player.transform_sprite.get_meta("base_scale", Vector2.ONE))
		await _capture(directory, "catalog-attack-" + str(phase))
	var f := FileAccess.open(directory + "/capture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"captures":captures, "engine":Engine.get_version_info().string,
		"adapter":RenderingServer.get_video_adapter_name(), "same_position_seed":20261010}, "\t"))
	print("RESOURCE_CAPTURE_OK ", ProjectSettings.globalize_path(directory), " captures=", captures.size())
	world.queue_free()
	await process_frame
	quit(0)
