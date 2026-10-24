extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000
	var output: String=OS.get_environment("MAP_CAPTURE_OUTPUT")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=dimensions
		for mid: String in ["aden_world","faith_01","faith_04","escaros_01"]:
			world.rng.seed=20261024;world._set_map(mid,false);world.portal_cooldown=100000
			world.player.camera.position_smoothing_enabled=false;world.player.camera.force_update_scroll()
			var renderer: NativePngRenderer=world.field_renderer;renderer.texture_pixel_budget=renderer.MAX_MOBILE_PIXELS
			await renderer.settle_visible();await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/"+mid+"-"+str(dimensions.x)+".png")
	print("MAP_CAPTURE_OK PC llvmpipe mobile budget, not Android hardware")
	world.queue_free();await process_frame;quit()
