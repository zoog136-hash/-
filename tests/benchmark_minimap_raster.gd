extends SceneTree
## Compare direct/static-raster drawing in one real Main with prebuilt nodes.
## No actor or minimap is hidden. Frozen phases isolate rendering; active phases
## use 120-frame blocks and an explicit test-only player survival reserve.
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var world: TwilightWorld
var strikes: int=0
var incoming: int=0
func strike(_sequence: int) -> void: strikes+=1
func hit(_actor: TwilightMonster,_damage: int,_kind: String) -> void: incoming+=1

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label);printerr("MINIMAP_RASTER_FAIL "+label)

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

func sample(raster_enabled: bool, phase: int) -> Dictionary:
	world.field_minimap.set_static_cache_enabled(raster_enabled)
	for i: int in range(30): await process_frame
	print("MINIMAP_RASTER_BEGIN ",phase," raster_enabled=",raster_enabled)
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
	print("MINIMAP_RASTER_END ",phase)
	return {"phase":phase,"raster_enabled":raster_enabled,"frames":180,"frame_ms":stats(frames),"process_monitor_ms":stats(process_times),"physics_monitor_ms":stats(physics_times),"draw_calls":stats(calls),"stalls_over50ms":stalls50,"stalls_over100ms":stalls100,"peak_sampled_rss_kib":rss,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}

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
	# Complete the normal HUD first-process minimap mounting before caching.
	world.hud._process(0.0)
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
	world.field_minimap.raster_cache.prepare(world.field_minimap)
	await RenderingServer.frame_post_draw
	for i: int in range(90):await process_frame
	check(world.field_minimap.raster_cache.ready,"raster prebuilt")
	var population: int=world.monsters_root.get_child_count()
	var position: Vector2=world.player.global_position
	var zoom: Vector2=world.player.camera.zoom
	var rng_state: int=world.rng.state
	var samples: Array=[]
	var parity_only: bool="--parity-only" in OS.get_cmdline_user_args()
	if not parity_only:
		for phase: int in range(4):samples.append(await sample(phase%2==1,phase))
	world.field_minimap.set_static_cache_enabled(true)
	check(world.monsters_root.get_child_count()==population,"population preserved")
	check(world.player.global_position==position and world.player.camera.zoom==zoom,"coordinate/zoom preserved")
	check(world.rng.state==rng_state,"no game simulation or RNG consumption during samples")
	var visual: Dictionary=await capture_equivalence()
	var scale_checks: Array=[]
	for requested: Vector2i in [Vector2i(854,480),Vector2i(1920,1080)]:
		var prior_builds: int=world.field_minimap.raster_cache.builds
		root.size=requested
		for i: int in range(3):await process_frame
		world.hud._fit_hud()
		world.field_minimap.raster_cache.prepare(world.field_minimap)
		await RenderingServer.frame_post_draw
		check(world.field_minimap.raster_cache.ready and world.field_minimap.raster_cache.builds>prior_builds,"scale invalidates and rebuilds "+str(requested))
		scale_checks.append(await capture_equivalence("-"+str(requested.x)))
	root.size=Vector2i(1280,720)
	for i: int in range(3):await process_frame
	world.hud._fit_hud()
	world.field_minimap.raster_cache.prepare(world.field_minimap)
	await RenderingServer.frame_post_draw
	var active: Dictionary={} if parity_only else await active_sample()
	var lifecycle: Dictionary=await lifecycle_checks()
	var output: String=OS.get_environment("TWILIGHT_PERF_OUTPUT")
	if output.is_empty():output="user://minimap-raster.json"
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"map":world.active_map_id,"position":[position.x,position.y],"zoom":[zoom.x,zoom.y],"population":population,"samples":samples,"visual":visual,"scale_checks":scale_checks,"active":active,"lifecycle":lifecycle,"parity_only":parity_only,"failures":failures,"scope":"same loaded Main; frozen180frame direct/cache/direct/cache; then continuous960activeframes alternating120frameblocks direct/cache; all cachednodes prebuilt; no screenshot readback during measurements; no AI phase normalization","gpu_memory":"UNKNOWN","android":"NOT_RUN"},"  "))
	file.close()
	world.queue_free();await process_frame
	print("MINIMAP_RASTER_RESULT ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func capture_equivalence(suffix: String="") -> Dictionary:
	var folder: String="res://docs/presentation-20261025/performance/"
	world.field_minimap.set_static_cache_enabled(false)
	for i: int in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var before: Image=root.get_texture().get_image()
	before.save_png(folder+"raster-direct"+suffix+".png")
	world.field_minimap.set_static_cache_enabled(true)
	for i: int in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var after: Image=root.get_texture().get_image()
	after.save_png(folder+"raster-cached"+suffix+".png")
	var same: bool=before.get_data()==after.get_data()
	return {"byte_identical":same,"direct":"raster-direct"+suffix+".png","cached":"raster-cached"+suffix+".png","size":[before.get_width(),before.get_height()],"builds":world.field_minimap.raster_cache.builds,"raster_size":str(world.field_minimap.raster_cache.viewport.size)}

func active_sample() -> Dictionary:
	var landing:=Vector2.INF
	var target: TwilightMonster
	for actor: TwilightMonster in world.monsters_root.get_children():
		if actor.dead or actor.is_boss:continue
		for offset: Vector2 in [Vector2(40,0),Vector2(-40,0),Vector2(0,40),Vector2(0,-40)]:
			var point: Vector2=actor.global_position+offset
			if world.field_map.point_clear(point,4) and world.field_map.walkable(point) and not world.field_map.is_safe(point) and world.field_map.line_clear(point,actor.global_position):
				landing=point;target=actor;break
		if target!=null:break
	check(target!=null,"existing legal active-combat target")
	if target==null:return {}
	world.player.global_position=landing
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	var deadline: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		world.field_renderer.pump_stream()
		if world.field_renderer.visible_ready():break
		await process_frame
	for i: int in range(60):await process_frame
	world.hp=999999;world.max_hp=999999
	world.player.attack_strike.connect(strike)
	for actor: TwilightMonster in world.monsters_root.get_children():actor.player_hit.connect(hit)
	var builds: int=world.field_minimap.raster_cache.builds
	var start_population: int=world.monsters_root.get_child_count()
	world.rng.seed=20261025
	world.player.set_auto_enabled(true)
	world.process_mode=Node.PROCESS_MODE_INHERIT
	var values: Array=[[],[]]
	var draws: Array=[[],[]]
	var processes: Array=[[],[]]
	var physics: Array=[[],[]]
	var rss: Array=[rss_kib(),rss_kib()]
	print("MINIMAP_RASTER_ACTIVE_BEGIN")
	for frame: int in range(960):
		var block: int=frame/120
		var mode: int=[0,1,1,0,1,0,0,1][block]
		if frame%120==0:world.field_minimap.set_static_cache_enabled(mode==1)
		var start: int=Time.get_ticks_usec()
		await process_frame
		if frame%120<8:continue
		values[mode].append(float(Time.get_ticks_usec()-start)/1000.0)
		draws[mode].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		processes[mode].append(1000.0*Performance.get_monitor(Performance.TIME_PROCESS))
		physics[mode].append(1000.0*Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		if frame%30<2:rss[mode]=maxi(rss[mode],rss_kib())
	var phases: Array=[]
	for mode: int in range(2):
		var times: Array[float]=[];times.assign(values[mode])
		var draw_values: Array[float]=[];draw_values.assign(draws[mode])
		var process_values: Array[float]=[];process_values.assign(processes[mode])
		var physics_values: Array[float]=[];physics_values.assign(physics[mode])
		var stalls50: int=0;var stalls100: int=0
		for value: float in times:
			if value>50:stalls50+=1
			if value>100:stalls100+=1
		phases.append({"raster_enabled":mode==1,"frames":448,"frame_ms":stats(times),"draw_calls":stats(draw_values),"process_monitor_ms":stats(process_values),"physics_monitor_ms":stats(physics_values),"stalls_over50ms":stalls50,"stalls_over100ms":stalls100,"peak_sampled_rss_kib":rss[mode]})
	world.player.set_auto_enabled(false)
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.field_minimap.set_static_cache_enabled(true)
	check(strikes>0 and incoming>0,"real outgoing/incoming combat during continuous sample")
	check(builds==world.field_minimap.raster_cache.builds,"no cache rebuild/allocation during active alternation")
	print("MINIMAP_RASTER_ACTIVE_END")
	return {"samples":phases,"strikes":strikes,"incoming":incoming,"population_start":start_population,"population_end":world.monsters_root.get_child_count(),"position_start":[landing.x,landing.y],"rng_final":str(world.rng.state),"cache_builds_start":builds,"cache_builds_end":world.field_minimap.raster_cache.builds,"interpretation":"one continuous960frame16second combat;120frame blocks ABBA BAAB with first8frames discarded; unchanged0.12s minimap cadence; different combat moments not identical replay trajectories; original AI/node identities unchanged"}

func lifecycle_checks() -> Dictionary:
	var minimap: FieldMinimap=world.field_minimap
	var cache=minimap.raster_cache
	var before: int=cache.builds
	cache.invalidate()
	check(not cache.ready and cache.painter.field==null and cache.painter.source_overview==null,"invalidation releases old field/overview")
	cache.prepare(minimap)
	await RenderingServer.frame_post_draw
	check(cache.ready and cache.builds==before+1,"invalidation rebuilds exactly once")
	var stable: int=cache.builds
	var draws: Array[int]=[0]
	minimap.draw.connect(func()->void:draws[0]+=1)
	var position: Vector2=world.player.global_position
	var offset: Vector2=world.player.camera.offset
	var old_point: Vector2=minimap._point(position)
	world.player.global_position+=Vector2(400,0)
	world.player.camera.offset+=Vector2(128,0)
	world.player.camera.force_update_scroll()
	minimap.queue_redraw();cache.prepare(minimap)
	await RenderingServer.frame_post_draw
	check(cache.builds==stable and draws[0]>0 and minimap._point(world.player.global_position)!=old_point,"dynamic actor/camera redraw without static rebuild")
	world.player.global_position=position;world.player.camera.offset=offset
	world.player.camera.force_update_scroll()
	for enabled: bool in [false,true]:
		minimap.set_static_cache_enabled(enabled);cache.prepare(minimap)
		await RenderingServer.frame_post_draw
	check(cache.builds==stable,"mode switches retain raster allocation")
	return {"builds_before":before,"builds_after":cache.builds,"draw_notifications":draws[0],"field_restored":cache.painter.field==world.field_map}
