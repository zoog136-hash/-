extends "res://tests/pr122_published_boss_approval_main.gd"

func finish(code: int) -> void:
	print("PR158_DEFAULT_SCAN_EXIT ", code)
	quit(code)

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.save_timer = -10000.0
	if bool(world.hud.get("class_picker_initial")): world.hud.complete_class_selection()
	var targets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json")).actors
	var count := 0
	for record: Dictionary in world.catalog_db.get("변신", []):
		var key := "transform:" + str(record.get("sourceId", ""))
		if key not in targets and key != "transform:258": continue
		if key in targets and targets[key].grade != "신화" and key != "transform:267": continue
		world._apply_transform_visual(record)
		var sprite: AnimatedSprite2D = world.player.transform_sprite
		var missing: Array = []
		for d in range(8):
			for role in ["idle", "run", "attack", "hit", "death"]:
				if not sprite.sprite_frames.has_animation(role + "_" + str(d)): missing.append(role + "_" + str(d))
		print("PR158_DEFAULT ", key, " frames=", sprite.sprite_frames.resource_path, " missing=", JSON.stringify(missing))
		count += 1
	print("PR158_DEFAULT_ACTORS ", count)
	world.queue_free()
	await process_frame
	finish(0)
