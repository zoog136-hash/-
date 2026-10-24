extends SceneTree
var world
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	for i: int in range(8): await process_frame
	world.hud.complete_class_selection()
	if world.growth.development:
		var fixture: Dictionary = world.growth.state.duplicate(true)
		fixture.emblems["eva"] = {"stage":18,"attempts":12,"spent":100,"guaranteed":false}
		fixture.nodes = ["joe_stat","joe_0","joe_1"]
		fixture.representative = "joe_1"
		world.growth.restore(fixture)
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
	if world.growth.development:
		var activation: Dictionary = world.growth.execute("activate","joe_2",1,int(world.growth.state.revision))
		print("CAPTURE_ACTIVATE ",activation)
		if not activation.ok: quit(1); return
		world.hud.open_growth("guardians")
		for i: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var card_error: Error = root.get_texture().get_image().save_png(directory+"/guardian-cards-854x480.png")
		if card_error != OK: quit(1); return
		var view: Control=world.hud.workspace.find_child("GrowthView",true,false)
		view._prepare("choose","",int(world.growth.state.searches.joe_2.winner))
		for i: int in range(5): await process_frame
		view.scroll.scroll_vertical=0
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/guardian-card-selected-854x480.png")
		view._confirm()
		for i: int in range(5): await process_frame
		view.scroll.scroll_vertical=0
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/guardian-card-success-854x480.png")
		if not world.growth.state.nodes.has("joe_2"): quit(1); return
	world.queue_free()
	await process_frame
	print("GROWTH_CAPTURE_OK ",RenderingServer.get_video_adapter_name())
	quit()
