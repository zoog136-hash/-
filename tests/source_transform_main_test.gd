extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(value: bool, detail: String) -> void:
	if not value:
		failures.append(detail)
		print("SOURCE_MAIN_FAIL " + detail)

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.auto_enabled = true
	if world.field_population != null: world.field_population.set_process(false)
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/source_transform_visuals.json"))
	var player: TwilightPlayer = world.player
	var position_before: Vector2 = player.position
	var collision_before: int = player.collision_layer
	var mask_before: int = player.collision_mask
	var count: int = 0
	for record: Dictionary in db["변신"]:
		var key := "transform:" + str(record.sourceId)
		if not manifest.entries.has(key): continue
		player.start_combat_attack(player.position + Vector2(100,0), 0.72, "slash")
		var sequence: int = player.motion.sequence
		var elapsed: float = player.motion.attack_elapsed
		world._apply_transform_visual(record)
		check(player.transform_profile.frames_path == manifest.entries[key].frames_path, key + " real Main source path")
		check(player.position == position_before and player.auto_enabled, key + " position/AUTO")
		check(player.collision_layer == collision_before and player.collision_mask == mask_before, key + " collision")
		check(player.motion.active and player.motion.sequence == sequence and player.motion.attack_duration == 0.72 and player.motion.attack_elapsed == elapsed, key + " in-flight attack preserved")
		check(player.transform_sprite.visible and not player.class_sprite.visible, key + " only source visible")
		for direction: int in range(8):
			player.motion.facing8 = direction
			for role: String in ["idle","walk","attack","hit","death","cast"]:
				player.motion.state = role
				player.motion.apply_frames(player.transform_sprite)
				check(player.transform_sprite.animation == role+"_"+str(direction), key + " live SpriteFrames " + role + str(direction))
		count += 1
	check(count == 8, "eight Main source switches")
	print("SOURCE_TRANSFORM_MAIN_RESULT entries="+str(count)+" failures="+str(failures.size()))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
