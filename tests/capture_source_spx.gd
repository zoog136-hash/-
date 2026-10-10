extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var count: int = 0

func _initialize() -> void: call_deferred("_run")

func capture(directory: String, name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(directory + "/" + name_value + ".png")
	if result != OK:
		push_error("SPX capture failed " + name_value)
		quit(1)
	count += 1

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	if not CLASS_QA.enter_game(world):
		quit(1)
		return
	world.hud._close_workspace()
	world.save_timer = -10000
	world._set_map("aden_world", false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550, 4300)))
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	for monster: TwilightMonster in world.monsters_root.get_children(): monster.set_physics_process(false)
	var directory: String = "user://source-spx-review"
	DirAccess.make_dir_recursive_absolute(directory)
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2(1,1), Vector2.DOWN, Vector2(-1,1), Vector2.LEFT, Vector2(-1,-1), Vector2.UP, Vector2(1,-1)]
	for body: String in ["21624", "21653"]:
		if not world.player.select_external_spx_actor(body):
			push_error("Real SPX actor pack absent " + body)
			quit(1)
			return
		world.player.set_source_weapon_visual("한손검")
		for direction: int in range(8):
			world.player.cancel_attack()
			world.player.motion.face(directions[direction])
			for phase: int in range(3):
				world.player.motion.advance(.12, directions[direction].normalized()*180)
				world.player._update_visual(0.0)
				await capture(directory, body + "-walk-" + str(direction) + "-" + str(phase))
			world.player.start_combat_attack(world.player.global_position + directions[direction]*100, .6, "slash")
			for phase: int in range(3):
				world.player.motion.advance(.1, Vector2.ZERO)
				world.player._update_visual(0.0)
				await capture(directory, body + "-attack-" + str(direction) + "-" + str(phase))
	world.queue_free()
	await process_frame
	print("SOURCE_SPX_CAPTURE_OK ", ProjectSettings.globalize_path(directory), " captures=", count)
	quit(0)
