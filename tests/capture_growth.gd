extends SceneTree
var world
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	for i: int in range(8): await process_frame
	world.hud.complete_class_selection()
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	var directory: String = OS.get_environment("GROWTH_CAPTURE_DIR")
	if directory.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent
		DisplayServer.window_set_size(extent)
		for mode: String in ["emblems","guardians"]:
			world.hud.open_growth(mode)
			for i: int in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var error: Error = root.get_texture().get_image().save_png(directory+"/%s-%dx%d.png" % [mode,extent.x,extent.y])
			if error != OK: quit(1); return
	world.queue_free()
	await process_frame
	print("GROWTH_CAPTURE_OK ",RenderingServer.get_video_adapter_name())
	quit()
