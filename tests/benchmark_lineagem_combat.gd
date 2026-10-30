extends SceneTree
## Run separately in base/current trees with --fixed-fps 60. No image readback
## during measurement. Existing population and combat rules stay enabled.
const QA=preload("res://tests/qa_class_selection.gd")
const METER=preload("res://tests/qa_performance_world.gd")
var strikes: int=0
var incoming: int=0
var failures: Array[String]=[]
var world: TwilightWorld

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label);printerr("COMBAT_PERF_FAIL "+label)
func hit(_m: TwilightMonster,_d: int,_k: String) -> void: incoming+=1
func strike(_sequence: int) -> void: strikes+=1
func rss_kib() -> int:
	var file:=FileAccess.open("/proc/self/status",FileAccess.READ)
	if file==null: return -1
	while not file.eof_reached():
		var line: String=file.get_line()
		if line.begins_with("VmRSS:"): return line.trim_prefix("VmRSS:").strip_edges().split(" ",false)[0].to_int()
	return -1

func measure(count: int) -> Dictionary:
	var times: Array[float]=[]
	var calls: Array[float]=[]
	var nodes: Array[float]=[]
	var memory: int=rss_kib()
	var start_paths: int=world.measured_paths
	var stalls50: int=0
	var stalls100: int=0
	for frame: int in range(count):
		var start: int=Time.get_ticks_usec()
		await process_frame
		var ms: float=float(Time.get_ticks_usec()-start)/1000.0
		times.append(ms)
		if ms>50: stalls50+=1
		if ms>100: stalls100+=1
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if frame%60==0: memory=maxi(memory,rss_kib())
	times.sort();calls.sort();nodes.sort()
	return {"frames":count,"fixed_simulation_seconds":float(count)/60.0,"frame_median_ms":times[count/2],"frame_p95_ms":times[int(count*.95)],"frame_p99_ms":times[int(count*.99)],"frame_max_ms":times[-1],"stalls_over50ms":stalls50,"stalls_over100ms":stalls100,"draw_calls_median":calls[count/2],"draw_calls_max":calls[-1],"node_count_max":nodes[-1],"peak_sampled_rss_kib":memory,"paths":world.measured_paths-start_paths,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"gpu_memory":"UNKNOWN"}

func run() -> void:
	seed(20261025)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate()
	world.set_script(METER)
	root.add_child(world)
	check(QA.enter_game(world),"actual Main character entry")
	world.save_timer=-100000
	world.player.set_auto_enabled(false)
	world.rng.seed=20261025
	world._set_map("escaros_world",false)
	check(world.active_map_id=="escaros_world","native Escaros selected")
	if world.active_map_id!="escaros_world": quit(1);return
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var target: TwilightMonster
	var landing:=Vector2.INF
	for actor: TwilightMonster in world.monsters_root.get_children():
		if actor.dead or actor.is_boss: continue
		for offset: Vector2 in [Vector2(40,0),Vector2(-40,0),Vector2(0,40),Vector2(0,-40)]:
			var point: Vector2=actor.global_position+offset
			if world.field_map.point_clear(point,4) and world.field_map.walkable(point) and not world.field_map.is_safe(point) and world.field_map.line_clear(point,actor.global_position):
				landing=point;target=actor;break
		if target!=null: break
	check(target!=null,"existing reachable normal target")
	if target==null: quit(1);return
	world.player.global_position=landing
	world.player.camera.position_smoothing_enabled=false
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	var renderer: NativePngRenderer=world.field_renderer
	var deadline: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		renderer.pump_stream()
		var ready: bool=true
		for name: String in renderer.wanted_rows:
			if not renderer.chunks.has(name):ready=false;break
		if ready: break
		await process_frame
	check(renderer.visible_ready(),"source chunks prewarmed")
	for i: int in range(90): await process_frame
	var population: int=world.monsters_root.get_child_count()
	var target_name: String=target.monster_name
	var initial_target: Vector2=target.global_position
	# Test-only survival reserve, equal in both builds. No damage, accuracy,
	# speed, attack frames, monster values or population alterations.
	world.hp=999999;world.max_hp=999999
	world.player.attack_strike.connect(strike)
	for actor: TwilightMonster in world.monsters_root.get_children(): actor.player_hit.connect(hit)
	world.rng.seed=20261025
	world.player.set_auto_enabled(true)
	world.process_mode=Node.PROCESS_MODE_INHERIT
	print("COMBAT_PERF_BEGIN ",Time.get_unix_time_from_system())
	var combat: Dictionary=await measure(600)
	check(strikes>0 and incoming>0,"actual outgoing and incoming combat")
	combat["strikes"]=strikes;combat["incoming"]=incoming
	combat["population_after"]=world.monsters_root.get_child_count()
	combat["hp_after"]=world.hp
	combat["position_after"]=[world.player.global_position.x,world.player.global_position.y]
	combat["rng_state_after"]=str(world.rng.state)
	combat["target_hp_after"]=target.hp if is_instance_valid(target) else -1
	print("COMBAT_PERF_END ",Time.get_unix_time_from_system())
	world.player.set_auto_enabled(false)
	world.player.clear_click_path()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world._open_inventory()
	for i: int in range(30): await process_frame
	var menu: Dictionary=await measure(120)
	var output: String=OS.get_environment("TWILIGHT_PERF_OUTPUT")
	if output.is_empty(): output="user://lineagem-combat-performance.json"
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"seed":20261025,"map":world.active_map_id,"population_start":population,"position_start":[landing.x,landing.y],"target":target_name,"target_start":[initial_target.x,initial_target.y],"combat":combat,"inventory_idle":menu,"failures":failures,"conditions":"fixed-fps60;90 frozen render warmup;600 active simulation frames; original133 population, existing first legal normal target; test-only hp reserve999999; no capture readback; inventory separately frozen120frames","android":"NOT_RUN"},"  "))
	file.close()
	world.queue_free();await process_frame
	print("COMBAT_PERF_RESULT ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
