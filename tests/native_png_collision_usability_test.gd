extends SceneTree
## Regression: accessible click targets respect the real foot and do not edit
## the authoritative navigation/collision raster on PNG maps.
const FIELD=preload("res://scripts/maps/native_png_field.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("NATIVE_COLLISION_USABILITY_FAIL ",label)

func make_field(limited: bool=false) -> NativePngField:
	var polygon: Array=[[[16,16],[80,16],[80,80],[16,80]]] if limited else [[[8,8],[232,8],[232,232],[8,232]]]
	var blockers: Array=[] if limited else [{"id":"real_pillar","shape":"circle","center":[112,112],"radius":21}]
	var spec: Dictionary={
		"name":"collision-foot fixture","spawn":[40,40],
		"walk_polygons":polygon,"collision":blockers,
		"portals":[],"route_checks":[],"blocked_probes":[],
		"collision_scope":"SYNTHETIC_MOVEMENT_TEST_ONLY"}
	var field: NativePngField=FIELD.new()
	field.configure_png("native_collision_usability_fixture",
		{"revision":1,"maps":{"native_collision_usability_fixture":spec}},
		{"bounds":[0,0,256,256]},"")
	return field

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var field: NativePngField=make_field()
	var before: Dictionary=field.navigation_snapshot()
	var open_point:=Vector2(40,40)
	check(field.line_clear(open_point,open_point),"open ground fully clears foot")
	check(field.nearest_safe_click_destination(open_point)==open_point,"valid tap unchanged")
	var blocked:=Vector2(112,112)
	check(not field.line_clear(blocked,blocked),"visible pillar remains solid")
	var projected: Vector2=field.nearest_safe_click_destination(blocked)
	check(projected.is_finite(),"blocked tap finds a nearby safe foot")
	check(projected.is_finite() and field.line_clear(projected,projected),
		"projected foot clears physical obstacle and raster")
	check(projected.is_finite() and projected.distance_to(blocked)<=field.cell_size*6,
		"projection is bounded near the tap")
	check(not field.nearest_safe_click_destination(Vector2(-100,-100)).is_finite(),
		"outside-canvas tap never projects across map")
	check(not field.nearest_safe_click_destination(Vector2.INF).is_finite(),
		"non-finite tap rejected without reading raster")
	var after: Dictionary=field.navigation_snapshot()
	check(before.solid_runs==after.solid_runs and before.reachable==after.reachable,
		"tap projection never opens any collision or reachability cell")
	check(before.spawn_cells==after.spawn_cells,
		"tap projection preserves spawn candidates")
	var sparse: NativePngField=make_field(true)
	check(not sparse.nearest_safe_click_destination(Vector2(224,224),4).is_finite(),
		"unreviewed far floor stays impassable")
	check(sparse.nearest_safe_click_destination(Vector2(40,40))==Vector2(40,40),
		"small verified pocket remains usable")
	print("NATIVE_COLLISION_USABILITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
