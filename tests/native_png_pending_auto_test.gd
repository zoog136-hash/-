extends SceneTree

const FIELD=preload("res://scripts/maps/native_png_field.gd")

func _field(full_barrier: bool=false) -> NativePngField:
	var field: NativePngField=FIELD.new()
	var barrier: Array=[31,0,3,160] if full_barrier else [31,48,3,64]
	field.configure({"map_id":"pending_route_fixture","map_name":"Pending route fixture",
		"bounds":[0,0,160,160],"spawn_position":[24,80],"npc_spawn":[],
		"navigation":{"cell_size":16,"clearance":4,"use_baked_cache":false},
		"collision":[{"shape":"rect","rect":barrier}],
		"monster_spawn":[],"regions":[],"navigable_polygons":[]})
	field.png_manifest={"sha256":"pending-fixture","alpha_guard_cell_size":16,"alpha_solid_runs":[]}
	field.route_graph_key=field.final_route_key()
	return field

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.clear_click_path()
	for child: Node in world.monsters_root.get_children():
		world.monsters_root.remove_child(child)
		child.queue_free()
	var field: NativePngField=_field()
	world.field_map=field
	world.active_map_id="pending_route_fixture"
	world.player.global_position=Vector2(24,80)
	var target: TwilightMonster=(load("res://scenes/Monster.tscn") as PackedScene).instantiate() as TwilightMonster
	world.monsters_root.add_child(target)
	target.setup({"name":"pending target","lv":1,"hp":1000,"atk":1},world.player,world,null)
	target.set_process(false)
	target.set_physics_process(false)
	target.global_position=Vector2(136,80)
	if world._nearest_reachable_monster(1000.0)!=null or not field.route_pending:
		failures.append("AUTO treated unprepared exact route as reachable")
	if world.auto_target_failed_paths.has(world._auto_target_failure_key(target)):
		failures.append("pending route entered negative AUTO cache")
	world.auto_target_next_search_ms=Time.get_ticks_msec()+10000
	var slices: int=0
	while field.precise_routes!=null and not field.precise_routes.ready() and slices<200:
		world._advance_native_route_preparation()
		slices+=1
	if field.precise_routes==null or not field.precise_routes.ready() or world.auto_target_next_search_ms!=0:
		failures.append("bounded preparation did not release AUTO retry")
	if world._nearest_reachable_monster(1000.0)!=target:
		failures.append("AUTO lost reachable target after preparation")
	var next_field: NativePngField=_field()
	world.field_map=next_field
	world.player.clear_click_path()
	world._set_click_destination(Vector2(136,80))
	if not next_field.route_pending or not world.manual_route_pending_target.is_finite():
		failures.append("manual destination lost while route prepares")
	var manual_slices: int=0
	while next_field.precise_routes!=null and not next_field.precise_routes.ready() and manual_slices<200:
		world._advance_native_route_preparation()
		manual_slices+=1
	if world.player.click_path.is_empty() or world.manual_route_pending_target.is_finite():
		failures.append("manual destination did not resume after preparation")
	if slices==0 or manual_slices==0:
		failures.append("early route did not wait for bounded preparation")
	var blocked_field: NativePngField=_field(true)
	world.field_map=blocked_field
	world.auto_target_failed_paths.clear()
	world.player.clear_click_path()
	if world._nearest_reachable_monster(1000.0)!=null or not blocked_field.route_pending:
		failures.append("blocked route did not wait for exact proof")
	if world.auto_target_failed_paths.has(world._auto_target_failure_key(target)):
		failures.append("unproven blocked route entered negative cache")
	var blocked_slices: int=0
	while blocked_field.precise_routes!=null and not blocked_field.precise_routes.ready() and blocked_slices<200:
		world._advance_native_route_preparation()
		blocked_slices+=1
	if world._nearest_reachable_monster(1000.0)!=null or not world.auto_target_failed_paths.has(world._auto_target_failure_key(target)):
		failures.append("proven unreachable route did not use bounded negative cache")
	print("NATIVE_PENDING_AUTO_RESULT ",JSON.stringify({"failures":failures,"auto_slices":slices,"manual_slices":manual_slices,"blocked_slices":blocked_slices,"deferred":field.deferred_route_requests+next_field.deferred_route_requests+blocked_field.deferred_route_requests}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
