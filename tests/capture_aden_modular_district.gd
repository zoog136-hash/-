extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const RENDER=preload("res://scripts/maps/aden_modular_preview_renderer.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var out: String=OS.get_environment("ADEN_MODULAR_OUTPUT")
	if out.is_empty() or DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000;world.portal_cooldown=100000
	world._set_map("aden_world",false);world.field_population.configure(world,null);world._clear_monsters()
	world.player.set_auto_enabled(false);world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE
	var field: NativePngField=world.field_map;var before: Dictionary=field.navigation_snapshot();var portals: Array=field.data.portal.duplicate(true)
	world.field_renderer.get_parent().remove_child(world.field_renderer);world.field_renderer.free();world.field_renderer=null;world.field_minimap.hide()
	var renderer:=RENDER.new();world.add_child(renderer);renderer.configure(world.player,"res://assets/maps/aden_modular_district_01/compiled/")
	var failures: Array=[];var reachable: int=0
	for portal: Dictionary in portals:
		if field.walkable(Vector2(portal.position[0],portal.position[1])):reachable+=1
	if reachable!=portals.size():failures.append("portal approaches")
	var destination:=Vector2(11700,2915)*6;world._set_click_destination(destination)
	for i: int in range(100):await physics_frame
	if world.player.global_position.distance_to(destination)>=24:failures.append("plaza movement")
	world.player.clear_click_path();world.player.set_physics_process(false)
	for view: Array in [["plaza",11762,2921],["central_garden",12135,2994],["south_street",11937,3259],["east_residences",12492,3107]]:
		world.player.camera.offset=Vector2(view[1],view[2])*6-world.player.global_position
		world.player.camera.force_update_scroll();renderer.refresh();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/"+view[0]+".png")
	var after: Dictionary=field.navigation_snapshot()
	if before.solid_runs!=after.solid_runs or before.spawn_cells!=after.spawn_cells or field.data.portal!=portals:failures.append("geometry changed")
	if renderer.manifest.ground_chunks.size()!=96:failures.append("chunk count")
	var result={"failures":failures,"portal_approaches":reachable,"ground_chunks":renderer.manifest.ground_chunks.size(),"peak_ground_rgba_bytes":renderer.peak_ground_bytes,"foreground_rgba_bytes":renderer.manifest.unique_foreground_rgba_bytes,"actual_android":false,"production_enabled":false,"camera_only_residential_views":true}
	var file:=FileAccess.open(out+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close();print("DISTRICT_RESULT ",JSON.stringify(result));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
