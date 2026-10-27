extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const RENDER=preload("res://scripts/maps/aden_modular_preview_renderer.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("MODULAR_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func shot(out: String,name: String,world: TwilightWorld,renderer: Node=null) -> void:
	world.player.camera.force_update_scroll()
	if renderer!=null:renderer.refresh()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
func actor_pixels(world: TwilightWorld,renderer: Node,at: Vector2) -> int:
	world.player.global_position=at;world.player.camera.force_update_scroll();renderer.refresh();world.player.hide()
	await process_frame;await RenderingServer.frame_post_draw
	var hidden: Image=root.get_texture().get_image();world.player.show()
	await process_frame;await RenderingServer.frame_post_draw
	var shown: Image=root.get_texture().get_image();var count: int=0
	var center: Vector2=world.player.get_global_transform_with_canvas().origin
	for y: int in range(maxi(0,int(center.y)-130),mini(shown.get_height(),int(center.y)+20)):
		for x: int in range(maxi(0,int(center.x)-70),mini(shown.get_width(),int(center.x)+70)):
			if hidden.get_pixel(x,y)!=shown.get_pixel(x,y):count+=1
	return count
func run() -> void:
	var out: String=OS.get_environment("ADEN_MODULAR_OUTPUT")
	if out.is_empty() or DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000;world.portal_cooldown=100000
	world._set_map("aden_world",false);world.field_population.configure(world,null);world._clear_monsters()
	world.player.set_auto_enabled(false);world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE
	var field: NativePngField=world.field_map;var before: Dictionary=field.navigation_snapshot();var portals: Array=field.data.portal.duplicate(true)
	await world.field_renderer.settle_visible();await shot(out,"before-1280",world)
	world.field_renderer.get_parent().remove_child(world.field_renderer);world.field_renderer.free();world.field_renderer=null;world.field_minimap.hide()
	var renderer:=RENDER.new();world.add_child(renderer);renderer.configure(world.player)
	check(renderer.manifest.ground_chunks.size()==24,"24 exact 512px ground chunks")
	check(renderer.manifest.ground_chunk_roundtrip and renderer.manifest.composite_roundtrip,"compiler pixel ownership and seam proofs")
	var fountain: Dictionary={}
	for row: Dictionary in renderer.manifest.foreground:
		if row.id=="plaza_fountain":fountain=row
	var fountain_world: Vector2=renderer.global_position+Vector2(fountain.foot[0],fountain.foot[1])
	check(fountain_world==Vector2(11762,2921)*6,"fountain ground anchor matches existing collision center")
	for portal: Dictionary in portals:check(field.walkable(Vector2(portal.position[0],portal.position[1])),"original portal approach "+str(portal.id))
	for p: Array in field.data.route_checks:check(not field.path(Vector2(field.data.spawn_position[0],field.data.spawn_position[1]),Vector2(p[0],p[1])).is_empty(),"existing plaza path "+str(p))
	var destination:=Vector2(11700,2915)*6;world._set_click_destination(destination)
	for i: int in range(100):await physics_frame
	check(world.player.global_position.distance_to(destination)<24,"real player walks on new paving with existing collision")
	world.player.clear_click_path();world.player.global_position=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	await shot(out,"after-1280",world,renderer)
	root.size=Vector2i(854,480);await shot(out,"after-854",world,renderer)
	root.size=Vector2i(1280,720)
	world.player.camera.offset=Vector2(12013,2896)*6-world.player.global_position
	await shot(out,"garden-1280",world,renderer)
	world.player.camera.offset=Vector2.ZERO;world.player.set_physics_process(false)
	var behind: int=await actor_pixels(world,renderer,fountain_world+Vector2(0,-35))
	await shot(out,"occlusion-behind",world,renderer)
	var front: int=await actor_pixels(world,renderer,fountain_world+Vector2(0,55))
	await shot(out,"occlusion-front",world,renderer)
	check(behind<front,"actual player is occluded behind fountain and visible in front")
	var after: Dictionary=field.navigation_snapshot()
	check(before.solid_runs==after.solid_runs and before.reachable==after.reachable and before.spawn_cells==after.spawn_cells,"navigation and all spawn candidates unchanged")
	check(field.data.portal==portals,"all portal coordinates unchanged")
	check(renderer.peak_ground_bytes+int(renderer.manifest.unique_foreground_rgba_bytes)<=48*1024*1024,"preview textures stay below 48MiB mobile texture policy")
	var report={"checks":checks,"failures":failures,"behind_actor_pixels":behind,"front_actor_pixels":front,"peak_ground_rgba_bytes":renderer.peak_ground_bytes,"unique_foreground_rgba_bytes":renderer.manifest.unique_foreground_rgba_bytes,"actual_android":false,"production_enabled":false}
	var file:=FileAccess.open(out+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print("MODULAR_RESULT ",JSON.stringify(report))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
