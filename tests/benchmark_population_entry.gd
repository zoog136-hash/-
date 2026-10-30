# First 120 active frames after map-texture warmup; no frame exclusion.
# Profiling subclasses call unchanged production services; HP is a survival fixture.
extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const METER=preload("res://tests/qa_population_entry_world.gd")
const GRAPH=preload("res://scripts/maps/native_png_route_graph.gd")
var route_profile: bool=OS.get_environment("TWILIGHT_FIRST_ROUTE_PROFILE")=="1"
var stage_profile: bool=OS.get_environment("TWILIGHT_FRAME_STAGE_PROFILE")=="1"
var render_begin: int=0
var render_us: int=0
var render_count: int=0
func before_draw() -> void:render_begin=Time.get_ticks_usec()
func after_draw() -> void:
	render_us+=Time.get_ticks_usec()-render_begin
	render_count+=1
var world: TwilightWorld
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);printerr("ENTRY_COST_FAIL "+label)
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();world.set_script(METER);root.add_child(world)
	check(QA.enter_game(world),"Main class entry")
	world.player.set_auto_enabled(false);world.save_timer=-100000
	world.rng.seed=20261025;world._set_map("escaros_world",false)
	check(world.active_map_id=="escaros_world","Escaros active")
	if world.active_map_id!="escaros_world":world.queue_free();quit(1);return
	world.process_mode=Node.PROCESS_MODE_DISABLED;world.hud._process(0)
	var field: NativePngField=world.field_map
	if route_profile:install_route_profile(field)
	if OS.get_environment("TWILIGHT_PHYSICS_PROFILE")=="1":world.install_physics_profile()
	var population=world.field_population
	var entry_spawns: Array=population.spawn_costs.duplicate(true)
	population.spawn_costs.clear();population.process_costs.clear();world.texture_costs.clear()
	var target: TwilightMonster
	var landing:=Vector2.INF
	for actor: TwilightMonster in world.monsters_root.get_children():
		if actor.dead or actor.is_boss:continue
		for offset: Vector2 in [Vector2(40,0),Vector2(-40,0),Vector2(0,40),Vector2(0,-40)]:
			var p: Vector2=actor.global_position+offset
			if field.point_clear(p,4) and field.walkable(p) and not field.is_safe(p) and field.line_clear(p,actor.global_position):landing=p;target=actor;break
		if target!=null:break
	check(target!=null,"existing clear combat point")
	if target==null:quit(1);return
	world.player.global_position=landing;world.player.camera.position_smoothing_enabled=false;world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	var deadline: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		world.field_renderer.pump_stream()
		if world.field_renderer.visible_ready():break
		await process_frame
	world.field_minimap.raster_cache.prepare(world.field_minimap)
	for i: int in range(90):await process_frame
	world.hp=999999;world.max_hp=999999;world.rng.seed=20261025
	var initial_count: int=world.monsters_root.get_child_count()
	var graph_before: bool=field.precise_routes!=null
	var samples: Array=[]
	world.player.set_auto_enabled(true);world.process_mode=Node.PROCESS_MODE_INHERIT
	if stage_profile:
		RenderingServer.frame_pre_draw.connect(before_draw)
		RenderingServer.frame_post_draw.connect(after_draw)
	print("ENTRY_COST_ACTIVE_BEGIN")
	for i: int in range(120):
		var start: int=Time.get_ticks_usec()
		var pop_index: int=population.process_costs.size()
		var draw_before: int=render_us
		var draw_count_before: int=render_count
		var process_before: int=world.world_process_us
		var physics_before: Dictionary=world.physics_profile_totals() if world.physics_profile_script!=null else {}
		var constrain_index: int=world.constrain_costs.size()
		var world_path_index: int=world.path_costs.size()
		var path_index: int=field.profile_paths.size() if route_profile else 0
		var graph_was: bool=field.precise_routes!=null
		await process_frame
		var pop_us: int=0
		for j: int in range(pop_index,population.process_costs.size()):pop_us+=int(population.process_costs[j].us)
		samples.append({"frame":i,"frame_us":Time.get_ticks_usec()-start,"population_us":pop_us,"graph_created":not graph_was and field.precise_routes!=null,"actors":world.monsters_root.get_child_count(),"physics_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
		if stage_profile:
			samples[-1]["stages"]={"draw_signal_interval_us":render_us-draw_before,"draws":render_count-draw_count_before,"world_process_us":world.world_process_us-process_before}
		if world.physics_profile_script!=null:
			var physics_after: Dictionary=world.physics_profile_totals()
			for key: String in physics_after:physics_after[key]-=physics_before[key]
			physics_after["constrain_us"]=0;physics_after["constrain_calls"]=0
			for entry: Dictionary in world.constrain_costs.slice(constrain_index):
				if entry.monster:physics_after.constrain_us+=entry.us;physics_after.constrain_calls+=1
			samples[-1]["monster_physics"]=physics_after
		if world.profile_world_paths:
			var entries: Array=world.path_costs.slice(world_path_index)
			var total: int=0;var maximum: int=0
			for entry: Dictionary in entries:total+=entry.us;maximum=maxi(maximum,entry.us)
			samples[-1]["world_paths"]={"count":entries.size(),"total_us":total,"max_us":maximum,"remainder_us":samples[-1].frame_us-total,"entries":entries}
		if route_profile:
			var entries: Array=field.profile_paths.slice(path_index)
			var total: int=0;var maximum: int=0
			for entry: Dictionary in entries:total+=entry.us;maximum=maxi(maximum,entry.us)
			samples[-1]["paths"]={"count":entries.size(),"total_us":total,"max_us":maximum,"entries":entries}
	world.process_mode=Node.PROCESS_MODE_DISABLED
	print("ENTRY_COST_ACTIVE_END")
	if stage_profile:
		RenderingServer.frame_pre_draw.disconnect(before_draw)
		RenderingServer.frame_post_draw.disconnect(after_draw)
	var graph:=GRAPH.new();var started: int=Time.get_ticks_usec();graph.configure(field)
	var graph_build_us: int=Time.get_ticks_usec()-started
	var graph_equivalence: Dictionary={}
	var baseline_path: String=OS.get_environment("TWILIGHT_ROUTE_BASELINE")
	if not baseline_path.is_empty():
		var baseline_script: Script=load(baseline_path)
		var baseline=baseline_script.new()
		started=Time.get_ticks_usec();baseline.configure(field)
		var baseline_us: int=Time.get_ticks_usec()-started
		var same_ids: bool=baseline.get_point_ids()==graph.get_point_ids()
		var same_positions: bool=true
		var same_connections: bool=true
		for id: int in graph.get_point_ids():
			if not baseline.has_point(id):same_positions=false;same_connections=false;break
			if baseline.get_point_position(id)!=graph.get_point_position(id):same_positions=false
			if baseline.get_point_connections(id)!=graph.get_point_connections(id):same_connections=false
		check(same_ids and same_positions and same_connections,"graph point IDs, positions and ordered connections unchanged")
		graph_equivalence={"baseline_build_us":baseline_us,"current_build_us":graph_build_us,"same_ids":same_ids,"same_positions":same_positions,"same_ordered_connections":same_connections}
	var route_details: Dictionary=replay_routes(field) if route_profile else {}
	check(world.physics_profile_mismatches.is_empty(),"physics observer preserved all actor script properties")
	var out: String=OS.get_environment("TWILIGHT_PERF_OUTPUT")
	if out.is_empty():out="user://population-entry.json"
	var file:=FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"map":world.active_map_id,"position":[landing.x,landing.y],"map_costs":world.map_costs,"entry_spawns":entry_spawns,"activation_spawns":population.spawn_costs,"activation_textures":world.texture_costs,"frames":samples,"initial_count":initial_count,"graph_before":graph_before,"graph_after":field.precise_routes!=null,"graph_independent_build_us":graph_build_us,"graph_equivalence":graph_equivalence,"graph_points":graph.get_point_count(),"grid_cells":field.width*field.height,"route_profile":route_details,"physics_observer_installed":world.physics_profile_installed,"physics_observer_mismatches":world.physics_profile_mismatches,"failures":failures,"scope":"first120activeframes after frozen map-texture warmup, no frame exclusion; survivalHPfixture999999; process and physics observer boundaries may overlap monitor cadence"},"  "));file.close()
	world.queue_free();await process_frame;print("ENTRY_COST_RESULT ",JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)

func install_route_profile(field: NativePngField) -> void:
	var source: String=FileAccess.get_file_as_string("res://scripts/maps/native_png_field.gd")
	var body: String=source.substr(source.find("func path("),source.find("\nconst FLOOR_BUCKET")-source.find("func path("))
	check(body.count("precise_routes=PRECISE_ROUTE_GRAPH.new()")==1,"exact graph creation replacement")
	body=body.replace("func path(","func _source_path(").replace("precise_routes=PRECISE_ROUTE_GRAPH.new()",'precise_routes=preload("res://tests/qa_first_route_graph.gd").new()')
	# Preserve the original superclass call when copying the native body into a subclass.
	var base_source: String=FileAccess.get_file_as_string("res://scripts/maps/playable_field.gd")
	var coarse: String=base_source.substr(base_source.find("func path("),base_source.find("\nfunc line_clear(")-base_source.find("func path("))
	coarse=coarse.replace("func path(","func _coarse_path(")
	body=body.replace("super.path(from,to)","_coarse_path(from,to)")
	var wrapper: String='extends "res://scripts/maps/native_png_field.gd"\nvar profile_paths: Array=[]\nfunc path(from: Vector2,to: Vector2) -> PackedVector2Array:\n\tvar begin: int=Time.get_ticks_usec()\n\tvar graph_before: bool=precise_routes!=null\n\tvar route_index: int=precise_routes.routes.size() if graph_before else 0\n\tvar failed_hit: bool=precise_routes.has_failed_route(from,to) if graph_before else false\n\tvar result: PackedVector2Array=_source_path(from,to)\n\tprofile_paths.append({"from":[from.x,from.y],"to":[to.x,to.y],"us":Time.get_ticks_usec()-begin,"points":result.size(),"exact_failure_cache_hit":failed_hit,"created_graph":not graph_before and precise_routes!=null,"graph_configure_us":precise_routes.costs.configure_us if not graph_before and precise_routes!=null else 0,"graph_routes":precise_routes.routes.slice(route_index) if precise_routes!=null else []})\n\treturn result\n'
	wrapper+='var profile_line_us: int=0\nvar profile_line_calls: int=0\nvar profile_point_us: int=0\nvar profile_point_calls: int=0\nfunc line_clear(from: Vector2,to: Vector2) -> bool:\n\tvar begin: int=Time.get_ticks_usec()\n\tvar result: bool=super.line_clear(from,to)\n\tprofile_line_us+=Time.get_ticks_usec()-begin;profile_line_calls+=1\n\treturn result\nfunc point_clear(p: Vector2,padding: float=24.0) -> bool:\n\tvar begin: int=Time.get_ticks_usec()\n\tvar result: bool=super.point_clear(p,padding)\n\tprofile_point_us+=Time.get_ticks_usec()-begin;profile_point_calls+=1\n\treturn result\n'
	if field.has_method("cached_line_clear"):
		wrapper+='func cached_line_clear(from: Vector2,to: Vector2,samples: RefCounted) -> bool:\n\tvar begin: int=Time.get_ticks_usec()\n\tvar result: bool=super.cached_line_clear(from,to,samples)\n\tprofile_line_us+=Time.get_ticks_usec()-begin;profile_line_calls+=1\n\treturn result\n'
	var file:=FileAccess.open("user://first-route-field.gd",FileAccess.WRITE);file.store_string(wrapper+body+"\n"+coarse);file.close()
	var saved: Dictionary={}
	for property: Dictionary in field.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:saved[property.name]=field.get(property.name)
	field.set_script(load("user://first-route-field.gd"))
	for key: String in saved:field.set(key,saved[key])
	check(field.precise_routes==null,"profile installed before first graph")
func replay_routes(field: NativePngField) -> Dictionary:
	var active_field_counts: Dictionary={"line_calls":field.profile_line_calls,"line_us":field.profile_line_us,"point_calls":field.profile_point_calls,"point_us":field.profile_point_us}
	var trace: Array=field.precise_routes.routes.duplicate(true)
	var first_graph=preload("res://tests/qa_first_route_graph.gd").new();first_graph.configure(field)
	var replay: Array=[];var equal: bool=true
	for row: Dictionary in trace:
		var result: PackedVector2Array=first_graph.route(Vector2(row.from[0],row.from[1]),Vector2(row.to[0],row.to[1]))
		equal=equal and result==row.result
		replay.append(first_graph.routes[-1].duplicate(true))
	check(equal,"same field ordered cold route replay exact outputs")
	var warm_start: int=Time.get_ticks_usec()
	for row: Dictionary in trace:first_graph.route(Vector2(row.from[0],row.from[1]),Vector2(row.to[0],row.to[1]))
	return {"production_field_sha256":FileAccess.get_file_as_string("res://scripts/maps/native_png_field.gd").sha256_text(),"original_costs":field.precise_routes.costs,"field_counts_before_replay":active_field_counts,"ordered_replay_equal":equal,"replay_cold":replay,"warm_replay_us":Time.get_ticks_usec()-warm_start,"scope":"diagnostic timers add overhead; field identity and all properties preserved, script/resource IDs can shift later actor scheduling; exact same field endpoint replay uses fresh graph"}
