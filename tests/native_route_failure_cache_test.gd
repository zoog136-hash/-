extends SceneTree
const FIXTURE=preload("res://tests/qa_route_failure_field.gd")
const GRAPH=preload("res://scripts/maps/native_png_route_graph.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("ROUTE_FAILURE_CACHE_FAIL "+label)
func run() -> void:
	var field: NativePngField=FIXTURE.create()
	var graph=GRAPH.new();graph.configure(field)
	var source: Vector2=field.cell_to_world(Vector2i(12,12))
	var target: Vector2=field.cell_to_world(Vector2i(44,12))
	check(graph.route(source,target).is_empty(),"disconnected native islands remain unreachable")
	check(graph.failed_routes.size()==1,"one exact failed endpoint pair retained")
	field.precise_routes=graph
	check(field.path(source,target).is_empty(),"native AUTO path hook retains the exact failure")
	check(not field.path(source,source+Vector2(16,0)).is_empty(),"native hook immediately accepts a moved reachable target")
	for repeat: int in range(12):check(graph.route(source,target).is_empty(),"same failed query stays empty")
	check(graph.failed_routes.size()==1,"repeat does not allocate more keys")
	var near: Vector2=field.cell_to_world(Vector2i(13,12))
	check(not graph.route(source,near).is_empty(),"target movement immediately selects reachable same-island position")
	check(not graph.route(target,target+Vector2(16,0)).is_empty(),"player movement immediately considers new island")
	graph.route(source+Vector2(.25,0),target)
	graph.route(source,target+Vector2(.25,0))
	check(graph.failed_routes.size()==3,"sub-cell endpoint movement uses exact new key")
	for i: int in range(140):graph.route(source+Vector2(float(i)/1024,0),target)
	check(graph.failed_routes.size()<=128 and graph.failed_order.size()<=128,"failed result storage is bounded")
	# Reconfiguration is the existing immutable geometry lifetime boundary.
	field.astar.fill_solid_region(Rect2i(23,12,18,2),false)
	for y: int in range(12,14):
		for x: int in range(23,41):field.reachable[y*field.width+x]=1
	graph.configure(field)
	check(graph.failed_routes.is_empty(),"reconfiguration drops all old failure decisions")
	check(not graph.route(source,target).is_empty(),"opened corridor is reconsidered after geometry reconfiguration")
	check(graph.get_point_count()>512,"newly configured geometry adds corridor points")
	print("ROUTE_FAILURE_CACHE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
