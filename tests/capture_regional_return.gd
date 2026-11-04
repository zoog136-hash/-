extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("TWILIGHT_REGIONAL_RETURN_TEST") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		printerr("REGIONAL_RETURN_TEST_REQUIRES_ISOLATED_XDG_PROFILE")
		quit(2)
		return
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	if not QA.enter_game(world): quit(1);return
	world.player.set_physics_process(false)
	world.inventory["귀환 주문서"] = 10
	world.inventory["잊혀진 귀환 주문서 (각인)"] = 3
	world._on_quickslot_assignment_requested(0,"item","귀환 주문서")
	world.set_regional_return_enabled(true)
	world._set_map("source_70",false)
	if world.active_map_id != "source_70": quit(1);return
	world.hud.open_settings_info()
	var settings = world.hud.find_child("RegionalReturnSettings",true,false)
	var scroll = world.hud.find_child("SettingsScroll",true,false)
	for i in range(3): await process_frame
	if settings == null or scroll == null: quit(1);return
	scroll.ensure_control_visible(settings.status)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("REGIONAL_CAPTURE_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("user://regional-return-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory+"/settings.png")
	world.hud._navigate("settings")
	world.hud._park_shared_panels()
	world.hud.workspace.hide()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/island-regional-slot.png")
	world._on_quickslot_pressed(0)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/island-return-used.png")
	root.size = Vector2i(854,480)
	world.hud.open_settings_info()
	for i in range(3): await process_frame
	settings = world.hud.find_child("RegionalReturnSettings",true,false)
	scroll = world.hud.find_child("SettingsScroll",true,false)
	scroll.ensure_control_visible(settings.status)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/settings-854.png")
	world.hud.workspace.hide()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/island-return-used-854.png")
	print("REGIONAL_CAPTURE_RESULT ", JSON.stringify({"map":world.active_map_id,"slot":world.hud.quickslot_entries[0],"base_count":world.inventory["귀환 주문서"],"regional_count":world.inventory.get("잊혀진 귀환 주문서 (각인)",0)}))
	world.queue_free()
	await process_frame
	quit(0)
