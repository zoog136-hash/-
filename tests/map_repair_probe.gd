extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var output: String=OS.get_environment("MAP_PROBE_OUTPUT")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world);QA.enter_game(world)
	world.save_timer=-100000;world.set_process(false);world.rng.seed=20261024
	var results: Array=[]
	for mid: String in ["aden_world","faith_01","faith_04","escaros_01"]:
		var started: int=Time.get_ticks_usec()
		world._set_map(mid,false);world.portal_cooldown=100000
		var entry_ms: float=(Time.get_ticks_usec()-started)/1000.0
		world.player.camera.position_smoothing_enabled=false
		world.player.camera.force_update_scroll()
		var renderer: NativePngRenderer=world.field_renderer
		await renderer.settle_visible()
		for i: int in range(60):await process_frame
		(world.field_map as NativePngField).profile_paths=true
		var samples: Array[float]=[]
		var physics: Array[float]=[]
		var active_sum: int=0
		var draw_sum: int=0
		var pairs_sum: int=0
		for i: int in range(180):
			var tick: int=Time.get_ticks_usec()
			await process_frame
			samples.append((Time.get_ticks_usec()-tick)/1000.0)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			draw_sum+=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			pairs_sum+=int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
			for m: Node in world.monsters_root.get_children():
				if m.is_physics_processing():active_sum+=1
		samples.sort();physics.sort()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+mid+".png")
		results.append({"path_calls":(world.field_map as NativePngField).profile_path_calls,"path_usec":(world.field_map as NativePngField).profile_path_usec,"map":mid,"entry_ms":entry_ms,"slots":world.field_population.slots.size(),"materialized":world.monsters_root.get_child_count(),"active_ai_mean":float(active_sum)/180,"frame_median_ms":samples[90],"frame_p95_ms":samples[171],"physics_median_ms":physics[90],"physics_p95_ms":physics[171],"draw_calls_mean":float(draw_sum)/180,"collision_pairs_mean":float(pairs_sum)/180,"decodes":renderer.decode_count,"uploads":renderer.upload_count,"sync_decodes":renderer.synchronous_decodes,"peak_texture_bytes":renderer.peak_decoded_pixels*4,"bounds":str(world.field_map.bounds),"scale":(world.field_map as NativePngField).artwork_scale})
		print("MAP_PROBE ",JSON.stringify(results.back()))
	var file:=FileAccess.open(output+"/metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
	world.queue_free();await process_frame;quit()
