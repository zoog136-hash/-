extends SceneTree

var world: TwilightWorld
var directory: String
var results: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	for i: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path := directory+"/"+label+".png"
	var error := image.save_png(path)
	results.append({"name":label,"path":path,"width":image.get_width(),"height":image.get_height(),"save_error":error,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	if error != OK: push_error("UI capture failed: "+label)

func _run() -> void:
	directory = ProjectSettings.globalize_path("user://ui-renewal-review")
	DirAccess.make_dir_recursive_absolute(directory)
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.save_timer = -10000
	for i: int in range(12): await process_frame
	world.set_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.player.set_physics_process(false)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = extent
		DisplayServer.window_set_size(extent)
		world.hud._close_workspace()
		await _capture("hud-%dx%d" % [extent.x,extent.y])
		world.hud.toggle_inventory()
		await _capture("inventory-%dx%d" % [extent.x,extent.y])
		world.hud.open_character()
		await _capture("character-%dx%d" % [extent.x,extent.y])
		world.hud.open_catalog("변신")
		await _capture("transform-%dx%d" % [extent.x,extent.y])
		world.hud.open_skills()
		await _capture("skills-%dx%d" % [extent.x,extent.y])
		world.hud.toggle_map()
		await _capture("map-%dx%d" % [extent.x,extent.y])
	var file := FileAccess.open(directory+"/render-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_method(),"captures":results},"\t"))
	file.close()
	world.queue_free()
	await process_frame
	print("UI_RENEWAL_CAPTURE_OK ",directory)
	quit()
