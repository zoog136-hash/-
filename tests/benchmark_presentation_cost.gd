extends SceneTree
## Diagnostic ablation only: hide/restore minimap in one frozen real Main.
## No actors/resources are removed and no product visibility policy changes.
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var world: TwilightWorld

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label);printerr("PRESENTATION_COST_FAIL "+label)

func rss_kib() -> int:
	var file:=FileAccess.open("/proc/self/status",FileAccess.READ)
	if file==null: return -1
	while not file.eof_reached():
		var line: String=file.get_line()
		if line.begins_with("VmRSS:"): return line.trim_prefix("VmRSS:").strip_edges().split(" ",false)[0].to_int()
	return -1

func stats(samples: Array[float]) -> Dictionary:
	samples.sort()
	return {"median":samples[samples.size()/2],"p95":samples[int(samples.size()*.95)],"p99":samples[int(samples.size()*.99)],"max":samples[-1]}

func sample(minimap_visible: bool, phase: int) -> Dictionary:
	world.field_minimap.visible=minimap_visible
	for i: int in range(30): await process_frame
	print("PRESENTATION_COST_BEGIN ",phase," visible=",minimap_visible)
	var frames: Array[float]=[]
	var process_times: Array[float]=[]
	var physics_times: Array[float]=[]
	var calls: Array[float]=[]
	var rss: int=rss_kib()
	var stalls50: int=0
	var stalls100: int=0
	for i: int in range(180):
		var start: int=Time.get_ticks_usec()
		await process_frame
		var ms: float=float(Time.get_ticks_usec()-start)/1000.0
		frames.append(ms)
		if ms>50:stalls50+=1
		if ms>100:stalls100+=1
		process_times.append(1000.0*Performance.get_monitor(Performance.TIME_PROCESS))
		physics_times.append(1000.0*Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if i%60==0:rss=maxi(rss,rss_kib())
	print("PRESENTATION_COST_END ",phase)
	return {"phase":phase,"minimap_visible":minimap_visible,"frames":180,"frame_ms":stats(frames),"process_monitor_ms":stats(process_times),"physics_monitor_ms":stats(physics_times),"draw_calls":stats(calls),"stalls_over50ms":stalls50,"stalls_over100ms":stalls100,"peak_sampled_rss_kib":rss,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}

func run() -> void:
	seed(20261025)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world),"actual Main class entry")
	world.player.set_auto_enabled(false)
	world.save_timer=-100000
	world.rng.seed=20261025
	world._set_map("escaros_world",false)
	check(world.active_map_id=="escaros_world","native Escaros selected")
	if world.active_map_id!="escaros_world":quit(1);return
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.player.camera.position_smoothing_enabled=false
	world.player.camera.force_update_scroll()
	var renderer: NativePngRenderer=world.field_renderer
	renderer.refresh_visible()
	var deadline: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		renderer.pump_stream()
		var ready: bool=true
		for key: String in renderer.wanted_rows:
			if not renderer.chunks.has(key):ready=false;break
		if ready:break
		await process_frame
	check(renderer.visible_ready(),"visible PNG chunks prewarmed")
	for i: int in range(90):await process_frame
	var population: int=world.monsters_root.get_child_count()
	var position: Vector2=world.player.global_position
	var zoom: Vector2=world.player.camera.zoom
	var rng_state: int=world.rng.state
	var samples: Array=[]
	for phase: int in range(4):samples.append(await sample(phase%2==0,phase))
	world.field_minimap.show()
	check(world.monsters_root.get_child_count()==population,"population preserved")
	check(world.player.global_position==position and world.player.camera.zoom==zoom,"coordinate/zoom preserved")
	check(world.rng.state==rng_state,"no game simulation or RNG consumption during samples")
	var output: String=OS.get_environment("TWILIGHT_PERF_OUTPUT")
	if output.is_empty():output="user://presentation-cost.json"
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"map":world.active_map_id,"position":[position.x,position.y],"zoom":[zoom.x,zoom.y],"population":population,"samples":samples,"failures":failures,"scope":"diagnostic minimap hide/restore only; same loaded Main and frozen simulation;180frames each after30warm frames; visible-hidden-visible-hidden; no screenshot readback; no gameplay/production visibility change","gpu_memory":"UNKNOWN","android":"NOT_RUN"},"  "))
	file.close()
	world.queue_free();await process_frame
	print("PRESENTATION_COST_RESULT ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
