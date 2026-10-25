# First 120 active frames after map-texture warmup; no frame exclusion.
# Profiling subclasses call unchanged production services; HP is a survival fixture.
extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const METER=preload("res://tests/qa_population_entry_world.gd")
const GRAPH=preload("res://scripts/maps/native_png_route_graph.gd")
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
	world.process_mode=Node.PROCESS_MODE_DISABLED;world.hud._process(0)
	var field: NativePngField=world.field_map
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
	print("ENTRY_COST_ACTIVE_BEGIN")
	for i: int in range(120):
		var start: int=Time.get_ticks_usec()
		var pop_index: int=population.process_costs.size()
		var graph_was: bool=field.precise_routes!=null
		await process_frame
		var pop_us: int=0
		for j: int in range(pop_index,population.process_costs.size()):pop_us+=int(population.process_costs[j].us)
		samples.append({"frame":i,"frame_us":Time.get_ticks_usec()-start,"population_us":pop_us,"graph_created":not graph_was and field.precise_routes!=null,"actors":world.monsters_root.get_child_count(),"physics_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
	world.process_mode=Node.PROCESS_MODE_DISABLED
	print("ENTRY_COST_ACTIVE_END")
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
	var out: String=OS.get_environment("TWILIGHT_PERF_OUTPUT")
	if out.is_empty():out="user://population-entry.json"
	var file:=FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"map":world.active_map_id,"position":[landing.x,landing.y],"map_costs":world.map_costs,"entry_spawns":entry_spawns,"activation_spawns":population.spawn_costs,"activation_textures":world.texture_costs,"frames":samples,"initial_count":initial_count,"graph_before":graph_before,"graph_after":field.precise_routes!=null,"graph_independent_build_us":graph_build_us,"graph_equivalence":graph_equivalence,"graph_points":graph.get_point_count(),"grid_cells":field.width*field.height,"failures":failures,"scope":"first120activeframes after frozen map-texture warmup, no frame exclusion; survivalHPfixture999999; process and physics observer boundaries may overlap monitor cadence"},"  "));file.close()
	world.queue_free();await process_frame;print("ENTRY_COST_RESULT ",JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
