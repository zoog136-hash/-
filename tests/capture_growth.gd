extends SceneTree
var world
var motion_frames: Dictionary={}
func tap(button: Control) -> void:
	var position: Vector2=button.get_global_transform_with_canvas()*(button.size/2)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=96; event.position=position; event.pressed=pressed
		root.push_input(event,true)
func motion(directory: String, section: String) -> void:
	if OS.get_environment("GROWTH_CAPTURE_MOTION")!="1":
		await create_timer(1.4).timeout
		return
	DirAccess.make_dir_recursive_absolute(directory+"/"+section)
	for i: int in range(45):
		await process_frame
		await RenderingServer.frame_post_draw
		var index: int=int(motion_frames.get(section,0))
		var error: Error=root.get_texture().get_image().save_png(directory+"/%s/%04d.png" % [section,index])
		if error!=OK: quit(1); return
		motion_frames[section]=index+1
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
		world.hud.open_growth("emblems")
		for i: int in range(5): await process_frame
		var emblem_view: Control=world.hud.workspace.find_child("GrowthView",true,false)
		emblem_view._prepare("enhance","eva",1)
		emblem_view._confirm()
		emblem_view.scroll.scroll_vertical=0
		await motion(directory,"emblem-frames")
		if emblem_view.card_faces.size()!=0: quit(1); return
		var activation: Dictionary=world.growth.execute("activate","joe_2",1,int(world.growth.state.revision))
		print("CAPTURE_ACTIVATE ",activation)
		if not activation.ok: quit(1); return
		world.hud.open_growth("guardians")
		for i: int in range(8): await process_frame
		var view: Control=world.hud.workspace.find_child("GrowthView",true,false)
		var revision: int=int(world.growth.state.revision)
		await motion(directory,"guardian-frames")
		if int(world.growth.state.revision)!=revision or world.growth.state.pending.is_empty(): quit(1); return
		root.get_texture().get_image().save_png(directory+"/guardian-cards-waiting.png")
		var loser: int=(int(world.growth.state.searches.joe_2.winner)+1)%3
		tap(view.find_child("GuardianCard_"+str(loser),true,false))
		await motion(directory,"guardian-frames")
		root.get_texture().get_image().save_png(directory+"/guardian-card-failed.png")
		if not world.growth.state.searches.joe_2.failed.has(loser): quit(1); return
		# A new paid attempt resumes remaining choices after a full reload.
		view._prepare("activate","joe_2",1)
		view._confirm()
		world._load_game(true)
		world.hud.open_growth("guardians")
		for i: int in range(8): await process_frame
		view=world.hud.workspace.find_child("GrowthView",true,false)
		view.scroll.scroll_vertical=0
		await motion(directory,"guardian-frames")
		root.get_texture().get_image().save_png(directory+"/guardian-cards-restored.png")
		var winner: int=int(world.growth.state.searches.joe_2.winner)
		tap(view.find_child("GuardianCard_"+str(winner),true,false))
		await motion(directory,"guardian-frames")
		root.get_texture().get_image().save_png(directory+"/guardian-card-success.png")
		if not world.growth.state.nodes.has("joe_2"): quit(1); return
	world.queue_free()
	await process_frame
	print("GROWTH_CAPTURE_OK ",RenderingServer.get_video_adapter_name())
	quit()
