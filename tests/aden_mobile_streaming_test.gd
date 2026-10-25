extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
func _initialize() -> void:
	var comparison_pack: String=OS.get_environment("ADEN_COMPARISON_PACK")
	if not comparison_pack.is_empty():
		if not ProjectSettings.load_resource_pack(comparison_pack,true):printerr("Comparison pack missing");quit(1);return
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":printerr("Rendered test required");quit(1);return
	var out: String=OS.get_environment("ADEN_MOBILE_OUTPUT");var failures: Array=[];var views: Array=[]
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,720);var started: int=Time.get_ticks_msec()
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000;world.portal_cooldown=100000
	world._set_map("aden_world",false);world.field_population.configure(world,null);world._clear_monsters();world.player.set_auto_enabled(false);world.player.set_physics_process(false);world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE
	var renderer: NativePngRenderer=world.field_renderer;var field: NativePngField=world.field_map;var nav: Dictionary=field.navigation_snapshot();var portals: Array=field.data.portal.duplicate(true)
	var legacy: bool="--legacy-aden-world-art" in OS.get_cmdline_user_args()
	if renderer.generated_full_world==legacy:failures.append("unexpected deployment mode")
	renderer.texture_pixel_budget=renderer.MAX_MOBILE_PIXELS
	var initial_sync: int=renderer.synchronous_decodes
	var entry_ms: int=Time.get_ticks_msec()-started
	for site: Array in [["residential",11734,2551],["market",12020,2638],["palace",11720,2934],["snow",7780,1140],["volcano",6450,2270],["forest",10290,3395],["desert",7500,5370],["ruins",8240,3130],["temple",10410,4305]]:
		var center:=Vector2(site[1],site[2])*6
		world.player.camera.offset=center-world.player.global_position;world.player.camera.force_update_scroll();var t: int=Time.get_ticks_msec()
		if not await renderer.settle_visible(20000):failures.append("stream timeout "+str(site[0]))
		views.append({"site":site[0],"settle_ms":Time.get_ticks_msec()-t,"resident_texture_bytes":renderer.decoded_pixels*4,"visible_rows":renderer.visible_files.size()})
		await process_frame;await RenderingServer.frame_post_draw
		if not out.is_empty():root.get_texture().get_image().save_png(out+"/mobile_"+str(site[0])+".png")
	world.player.camera.offset=Vector2.ZERO;world.player.camera.force_update_scroll();await renderer.settle_visible()
	root.size=Vector2i(854,480);await process_frame;await renderer.settle_visible();await RenderingServer.frame_post_draw
	if not out.is_empty():root.get_texture().get_image().save_png(out+"/mobile_854.png")
	if renderer.synchronous_decodes!=initial_sync:failures.append("movement decoded on main thread")
	if renderer.peak_decoded_pixels>renderer.MAX_MOBILE_PIXELS:failures.append("48MiB cap exceeded")
	if renderer.decode_errors!=0:failures.append("decode errors")
	if not legacy and renderer.decode_count>=renderer.generated_rows.size():failures.append("all world assets eagerly decoded")
	for portal: Dictionary in portals:
		if not field.walkable(Vector2(portal.position[0],portal.position[1])):failures.append("portal approach blocked")
	var after: Dictionary=field.navigation_snapshot()
	if nav.solid_runs!=after.solid_runs or nav.spawn_cells!=after.spawn_cells or portals!=field.data.portal:failures.append("navigation changed")
	var result={"failures":failures,"views":views,"entry_main_scene_and_field_ms":entry_ms,"peak_texture_bytes":renderer.peak_decoded_pixels*4,"max_worker_decode_usec":renderer.max_decode_usec,"worker_decodes":renderer.decode_count,"moving_main_thread_decodes":renderer.synchronous_decodes-initial_sync,"actual_android":false,"mobile_memory_policy_on_pc":true,"full_world_active":renderer.generated_full_world}
	if not out.is_empty():var f:=FileAccess.open(out+"/streaming.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "))
	print("ADEN_MOBILE_RESULT ",JSON.stringify(result));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
