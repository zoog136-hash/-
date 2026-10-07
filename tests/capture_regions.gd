extends SceneTree

# Exact GL screenshots and frame timings of real gameplay, not concept art.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.save_timer=-10000
	var directory: String = "user://world-regions-review"
	DirAccess.make_dir_recursive_absolute(directory)
	var timing: Array[float] = []
	for id: String in ["oman_01","oman_10","domination_summit","escaros_01","escaros_02","escaros_03","escaros_04","escaros_05","albino_01","albino_02","albino_03","albino_04","faith_01","faith_04"]:
		world._set_map(id,false)
		world.field_population.set_process(false)
		for monster: TwilightMonster in world.monsters_root.get_children():
			monster.set_physics_process(false)
		for review: String in ["entrance","central"]:
			var point: Vector2 = Vector2(float(world.field_map.data["review_points"][review][0]),float(world.field_map.data["review_points"][review][1]))
			world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(point))
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			for i: int in range(25):
				var start: int = Time.get_ticks_usec()
				await process_frame
				if i>6:
					timing.append(float(Time.get_ticks_usec()-start)/1000.0)
			await RenderingServer.frame_post_draw
			var screenshot: Image = root.get_texture().get_image()
			# Compact review previews of the real 1280x720 viewport, not mockups.
			screenshot.resize(800,450,Image.INTERPOLATE_LANCZOS)
			screenshot.save_png(directory+"/"+id+"-"+review+".png")
			print("REGION_CAPTURE ",id," ",review," calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," props=",world.field_renderer.visible_props)
	timing.sort()
	print("REGION_RENDER median_ms=",timing[timing.size()/2]," p95_ms=",timing[int(timing.size()*.95)])
	print("REGION_CAPTURE_DIRECTORY ",ProjectSettings.globalize_path(directory))
	world.queue_free()
	await process_frame
	quit()
