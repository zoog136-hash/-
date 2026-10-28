extends SceneTree

const FIELD=preload("res://scripts/maps/native_png_field.gd")
const GRAPH=preload("res://scripts/maps/native_png_route_graph.gd")

func _field(scale: float=1.0, extra_collision: bool=false, alpha_tag: int=0) -> NativePngField:
	var collision: Array=[{"shape":"rect","rect":[31,48,3,64]}]
	if extra_collision:collision.append({"shape":"circle","center":[112,112],"radius":8})
	var data: Dictionary={"map_id":"route_fixture","map_name":"Route fixture",
		"bounds":[0,0,160,160],"spawn_position":[24,24],
		"navigation":{"cell_size":16,"clearance":4,"use_baked_cache":false},
		"collision":collision,"monster_spawn":[],"regions":[],"navigable_polygons":[]}
	var field: NativePngField=FIELD.new()
	field.configure(data)
	field.artwork_scale=scale
	field.png_manifest={"sha256":"source-a","alpha_guard_cell_size":16,"alpha_solid_runs":[alpha_tag]}
	field.route_graph_key=field.final_route_key()
	return field

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var field: NativePngField=_field()
	var key: String=field.route_graph_key
	if field.prepare_precise_routes_step(3,1000000):failures.append("first small batch completed full graph")
	var batches: int=1
	while not field.precise_routes.ready() and batches<200:
		field.prepare_precise_routes_step(7,1000000)
		batches+=1
	if not field.precise_routes.ready() or batches<=1:failures.append("graph did not prepare in bounded batches")
	if int(field.route_graph_stats().build_calls)!=batches:failures.append("build instrumentation lost batch count")
	var original: AStar2D=field.precise_routes
	var cold: AStar2D=GRAPH.new()
	cold.configure(field)
	if original.get_point_count()!=cold.get_point_count():failures.append("incremental graph changed physical points")
	var from:=Vector2(24,80)
	var to:=Vector2(136,80)
	var route: PackedVector2Array=original.route(from,to)
	if route.is_empty():failures.append("prepared graph did not find fixture route")
	var previous: Vector2=from
	for point: Vector2 in route:
		if not field.line_clear(previous,point):failures.append("prepared route crosses a physical wall")
		previous=point
	var early: NativePngField=_field()
	early.prepare_precise_routes_step(1,1000000)
	var early_route: PackedVector2Array=early.path(from,to)
	if not early_route.is_empty() or not early.route_pending or early.precise_routes.ready():failures.append("early blocked route did not defer without synchronous completion")
	var early_slices: int=0
	while not early.precise_routes.ready() and early_slices<200:
		early.prepare_precise_routes_step(7,1000000)
		early_slices+=1
	early_route=early.path(from,to)
	if early_route.is_empty() or not early_route[-1].is_equal_approx(to) or early.route_pending:failures.append("deferred route did not reach exact destination")
	previous=from
	for point: Vector2 in early_route:
		if not early.line_clear(previous,point):failures.append("early route crosses a physical wall")
		previous=point
	var revised: NativePngField=_field(1.0,true)
	if revised.route_graph_key==key:failures.append("corrected collision did not invalidate graph")
	var scaled: NativePngField=_field(0.85)
	if scaled.route_graph_key==key:failures.append("map scale did not invalidate graph")
	var alpha: NativePngField=_field(1.0,false,1)
	if alpha.route_graph_key==key:failures.append("alpha collision identity did not invalidate graph")
	alpha.astar.set_point_solid(Vector2i(8,8),true)
	alpha._build_reachability()
	if alpha.final_route_key()==alpha.route_graph_key:failures.append("final solid raster did not invalidate graph")
	field.park_precise_routes()
	var returned: NativePngField=_field()
	returned.prepare_precise_routes_step(1,1000000)
	if not is_same(returned.precise_routes,original) or not returned.precise_routes.ready():failures.append("same final geometry did not reuse idle graph")
	var cached_route: PackedVector2Array=returned.precise_routes.route(from,to)
	if cached_route.is_empty():failures.append("reused graph lost route")
	previous=from
	for point: Vector2 in cached_route:
		if not returned.line_clear(previous,point):failures.append("reused graph crosses a physical wall")
		previous=point
	returned.park_precise_routes()
	alpha.prepare_precise_routes_step(1,1000000)
	if is_same(alpha.precise_routes,original):failures.append("different geometry reused stale graph")
	print("NATIVE_ROUTE_PREWARM_RESULT ",JSON.stringify({"failures":failures,"batches":batches,"early_slices":early_slices,"points":original.get_point_count(),"route_points":route.size(),"build_usec":int(original.build_usec),"deferred_requests":early.deferred_route_requests}))
	quit(0 if failures.is_empty() else 1)
