extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
func _initialize() -> void:call_deferred("run")
func actor_pixels(world: TwilightWorld,renderer: Node,at: Vector2) -> int:
	world.player.global_position=at;world.player.camera.force_update_scroll();await renderer.settle_visible();world.player.hide()
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
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000;world.portal_cooldown=100000
	world._set_map("aden_world",false);world.field_population.configure(world,null);world._clear_monsters();world.player.set_auto_enabled(false);world.player.set_physics_process(false);world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE
	var renderer: NativePngRenderer=world.field_renderer
	var rows: Array=renderer.MOBILE.pack().placements
	var tree_row: Dictionary={}
	for row: Dictionary in rows:
		if row.id=="decor_4138_1478" and row.asset=="oak":tree_row=row;break
	assert(not tree_row.is_empty(),"registered isolated forest oak exists")
	var targets: Array=[["fountain",Vector2(11762,2921)*6],["house",Vector2(70404,15306)],["oak",Vector2(tree_row.foot[0],tree_row.foot[1])]]
	var ok: bool=renderer.generated_full_world;var reports: Array=[];var out: String=OS.get_environment("ADEN_OBJECT_OUTPUT")
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	for target: Array in targets:
		var anchor: Vector2=target[1]
		var behind: int=await actor_pixels(world,renderer,anchor+Vector2(0,-35))
		if not out.is_empty():root.get_texture().get_image().save_png(out+"/"+target[0]+"-behind.png")
		var front: int=await actor_pixels(world,renderer,anchor+Vector2(0,55))
		if not out.is_empty():root.get_texture().get_image().save_png(out+"/"+target[0]+"-front.png")
		reports.append({"object":target[0],"behind_actor_pixels":behind,"front_actor_pixels":front,"pass":behind<front});ok=ok and behind<front
	print("MOBILE_OCCLUSION_OK " if ok else "MOBILE_OCCLUSION_FAILED ",JSON.stringify({"checks":5,"full_world":renderer.generated_full_world,"rows":reports,"pass":ok}))
	world.queue_free();await process_frame;quit(0 if ok else 1)
