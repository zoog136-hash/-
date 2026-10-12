extends SceneTree
## Real viewport input and GL screenshots. Run with tools/run_visual_capture.py.
const OUTPUT = "user://original-world-review"
var failures: Array[String] = []
var results: Array = []
var world: TwilightWorld

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("ORIGINAL_RENDER_FAIL: "+message)

func frames(count: int) -> void:
	for i: int in range(count): await physics_frame

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=pressed
	root.push_input(event,true)

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	check(image!=null and image.get_width()>=960,"real viewport image "+name_value)
	if image!=null:
		check(image.save_png(OUTPUT+"/"+name_value+".png")==OK,"save screenshot "+name_value)

func _run() -> void:
	check(DisplayServer.get_name()!="headless","OpenGL display is required")
	if not failures.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(4)
	world.hud.complete_class_selection(); world.hud._close_workspace()
	world.save_timer=-10000; world.level=100; world.hp=1000000; world.max_hp=1000000
	for id: int in [4,101,111,12852,12862]:
		var start_time: int=Time.get_ticks_msec()
		world._set_map("l1_%d" % id,false)
		world.portal_cooldown=1000
		world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
		await frames(5)
		var field: OriginalPlayableField=world.field_map
		var start: Vector2=world.player.global_position
		var cell: Vector2i=field.world_to_cell(start)
		var goal: Vector2=start
		for direction: Vector2i in field.DIRECTIONS:
			var candidate: Vector2=field.cell_to_world(cell+direction*3)
			if field.line_clear(start,candidate): goal=candidate; break
		check(goal!=start,"click target "+str(id))
		var screen: Vector2=world.get_viewport().get_canvas_transform()*goal
		mouse(screen,true); mouse(screen,false)
		await frames(60)
		check(world.player.global_position.distance_to(goal)<16,"viewport click reaches source tile "+str(id))
		world.player.clear_click_path(); world.player.velocity=Vector2.ZERO
		var samples: Array[float]=[]
		for i: int in range(30):
			var tick: int=Time.get_ticks_usec()
			await process_frame
			samples.append(float(Time.get_ticks_usec()-tick)/1000.0)
		samples.sort()
		await capture("map_%d" % id)
		results.append({"map":id,"original_art":false,"viewport_click":world.player.global_position.distance_to(goal)<16,
			"elapsed_ms":Time.get_ticks_msec()-start_time,"median_frame_ms":samples[15],"p95_frame_ms":samples[28],
			"navigation_cache_chunks":field.nav_cache.size(),"draw_chunks":world.field_renderer.chunks.size()})
	world.hud.toggle_map()
	await frames(5)
	await capture("priority_map_menu")
	var report={"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),
		"maps":results,"failures":failures,"visual_source_comparison":"UNAVAILABLE: no source tile art"}
	var file=FileAccess.open(OUTPUT+"/render_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ORIGINAL_WORLD_RENDER_RESULTS "+JSON.stringify(report))
	world.queue_free(); await frames(2)
	if failures.is_empty(): print("ORIGINAL_WORLD_RENDER_OK five maps and priority menu")
	quit(0 if failures.is_empty() else 1)
