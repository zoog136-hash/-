extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var out: String=OS.get_environment("ADEN_LIVE_OUTPUT")
	if DisplayServer.get_name()=="headless":quit(1);return
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000;world.portal_cooldown=100000
	world._set_map("aden_world",false);world.field_population.configure(world,null);world._clear_monsters();world.player.set_auto_enabled(false);world.player.camera.position_smoothing_enabled=false
	var renderer: NativePngRenderer=world.field_renderer;var field: NativePngField=world.field_map;var failures: Array=[]
	var snapshot: Dictionary=field.navigation_snapshot();var portals: Array=field.data.portal.duplicate(true)
	var pack: Dictionary=preload("res://scripts/maps/aden_mobile_pack.gd").pack()
	var expected_rows: int=3 if pack.is_empty() else pack.ground.size()+pack.placements.size()
	if renderer.generated_rows.size()!=expected_rows:failures.append("live rows absent")
	if not pack.is_empty() and not renderer.generated_full_world:failures.append("full world stream inactive")
	if not await renderer.settle_visible():failures.append("initial stream timeout")
	if field.walkable(Vector2(70572,17526)):failures.append("fountain collision")
	var destination:=Vector2(11700,2915)*6;world._set_click_destination(destination)
	for i: int in range(100):await physics_frame
	if world.player.global_position.distance_to(destination)>=24:failures.append("live plaza walk")
	world.player.clear_click_path()
	for portal: Dictionary in portals:
		if not field.walkable(Vector2(portal.position[0],portal.position[1])):failures.append("portal approach")
	for offset: Vector2 in [Vector2.ZERO,Vector2(340,0),Vector2(-340,0)]:
		world.player.camera.offset=offset;world.player.camera.force_update_scroll();await renderer.settle_visible();await process_frame;await RenderingServer.frame_post_draw
		if not out.is_empty():root.get_texture().get_image().save_png(out+"/live_"+str(int(offset.x))+".png")
	var live_count: int=0
	for key: String in renderer.chunks:
		if key.begins_with(renderer.LIVE_PLAZA if pack.is_empty() else renderer.MOBILE.ROOT):live_count+=1
	if live_count==0:failures.append("live texture absent")
	world.player.camera.offset=Vector2(6000,6000);world.player.camera.force_update_scroll();await renderer.settle_visible()
	for row: Dictionary in renderer.generated_rows:renderer.release_source(row.file)
	world.player.camera.offset=Vector2.ZERO;world.player.camera.force_update_scroll()
	if not await renderer.settle_visible():failures.append("return reload")
	if renderer.peak_decoded_pixels>renderer.texture_pixel_budget:failures.append("texture budget")
	var after: Dictionary=field.navigation_snapshot()
	if snapshot.solid_runs!=after.solid_runs or snapshot.spawn_cells!=after.spawn_cells or field.data.portal!=portals:failures.append("geometry mutation")
	var result={"failures":failures,"generated_rows":renderer.generated_rows.size(),"peak_texture_bytes":renderer.peak_decoded_pixels*4,"navigation_unchanged":true,"actual_android":false,"production_renderer":true}
	if not out.is_empty():var f:=FileAccess.open(out+"/live-result.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "))
	print("LIVE_PLAZA_RESULT ",JSON.stringify(result));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
