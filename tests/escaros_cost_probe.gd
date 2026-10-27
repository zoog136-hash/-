extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
func _initialize() -> void:call_deferred("run")
func sample(mode: String) -> Dictionary:
	var times: Array[float]=[];var physics: Array[float]=[];var draws: int=0;var active: int=0;var pairs: int=0
	var field: NativePngField=world.field_map
	field.profile_paths=true;field.profile_path_calls=0;field.profile_path_usec=0
	var begin: int=Time.get_ticks_usec()
	for i: int in range(240):
		var start: int=Time.get_ticks_usec();await process_frame
		times.append((Time.get_ticks_usec()-start)/1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		draws+=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));pairs+=int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
		for actor: Node in world.monsters_root.get_children():
			if actor.is_physics_processing():active+=1
	var elapsed: float=(Time.get_ticks_usec()-begin)/1000000.0
	times.sort();physics.sort()
	return {"mode":mode,"frame_median_ms":times[120],"frame_p95_ms":times[228],"physics_median_ms":physics[120],"physics_p95_ms":physics[228],"active_ai_mean":float(active)/240,"draw_calls_mean":float(draws)/240,"collision_pairs_mean":float(pairs)/240,"path_calls":field.profile_path_calls,"paths_per_second":field.profile_path_calls/elapsed,"path_total_ms":field.profile_path_usec/1000.0}
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000
	world.rng.seed=20261024
	var start: int=Time.get_ticks_usec();world._set_map("escaros_01",false)
	var entry: float=(Time.get_ticks_usec()-start)/1000.0
	world.portal_cooldown=100000;world.player.camera.position_smoothing_enabled=false;world.player.camera.force_update_scroll()
	var renderer: NativePngRenderer=world.field_renderer
	renderer.texture_pixel_budget=renderer.MAX_MOBILE_PIXELS
	await renderer.settle_visible()
	for i: int in range(60):await process_frame
	var rows: Array=[];rows.append(await sample("ordinary"))
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	rows.append(await sample("AI disabled diagnostic"))
	world.monsters_root.hide();rows.append(await sample("AI disabled actors hidden diagnostic"))
	renderer.hide();rows.append(await sample("AI actors terrain disabled diagnostic"))
	var result: Dictionary={"engine":Engine.get_version_info().string,"renderer":"llvmpipe software OpenGL","android_device":"NOT_RUN","entry_ms":entry,"slots":world.field_population.slots.size(),"materialized":world.monsters_root.get_child_count(),"decodes":renderer.decode_count,"uploads":renderer.upload_count,"sync_decodes":renderer.synchronous_decodes,"texture_peak_bytes":renderer.peak_decoded_pixels*4,"mobile_budget_bytes":renderer.texture_pixel_budget*4,"samples":rows}
	print("ESCAROS_COST ",JSON.stringify(result))
	var out:=FileAccess.open(OS.get_environment("COST_OUTPUT"),FileAccess.WRITE);out.store_string(JSON.stringify(result,"  "));out.close()
	world.queue_free();await process_frame;quit()
