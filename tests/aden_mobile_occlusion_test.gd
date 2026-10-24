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
	var anchor:=Vector2(11762,2921)*6
	var behind: int=await actor_pixels(world,renderer,anchor+Vector2(0,-35))
	var front: int=await actor_pixels(world,renderer,anchor+Vector2(0,55))
	var ok: bool=behind<front and renderer.generated_full_world
	# Report the unchanged real-render predicate using the runner's terminal contract.
	print("MOBILE_OCCLUSION_OK " if ok else "MOBILE_OCCLUSION_FAILED ",JSON.stringify({"checks":2,"behind_actor_pixels":behind,"front_actor_pixels":front,"full_world":renderer.generated_full_world,"pass":ok}))
	world.queue_free();await process_frame;quit(0 if ok else 1)
