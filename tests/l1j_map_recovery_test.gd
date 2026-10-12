extends SceneTree
## Coordinate failures and reachable routes that used to exhaust the BFS budget.
const NAV = preload("res://addons/twilight_l1j/twilight_source_navigation.gd")
const COORD = preload("res://addons/twilight_l1j/twilight_tile_coordinates.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("L1J_MAP_RECOVERY_FAIL: ", message)

func open_grid(size: Vector2i) -> TwilightL1JSourceNavigation:
	var nav: TwilightL1JSourceNavigation = NAV.new()
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y)
	bytes.fill(3)
	nav.attributes._raw = bytes
	nav.attributes._dimensions = size
	nav.attributes._source_id = 99998
	nav.coordinates.configure(size, Vector2i.ZERO, Transform2D.IDENTITY)
	nav.dimensions = size
	nav.loaded = true
	return nav

func _run() -> void:
	var nav := open_grid(Vector2i(3,3))
	for heading: int in range(8):
		var goal: Vector2i = Vector2i.ONE + nav.DIRECTIONS[heading]
		var path: Array[Vector2i] = nav.find_path(Vector2i.ONE, goal, 2)
		check(path == [Vector2i.ONE, goal], "two-node budget reaches neighbor in heading " + str(heading))
	check(nav.find_path(Vector2i.ONE,Vector2i(2,1),1).is_empty(), "one-node budget cannot hold an edge")
	check(nav.find_path(Vector2i.ONE,Vector2i.ONE,1) == [Vector2i.ONE], "same-cell path within one node")
	check(nav.find_path(Vector2i.ONE,Vector2i.ONE,0).is_empty(), "zero-node budget rejected")
	nav = open_grid(Vector2i(129,129))
	var start := Vector2i(64,64)
	var goal := Vector2i(120,64)
	var route: Array[Vector2i] = nav.find_path(start, goal)
	check(route.size() == 57, "56-cell open route stays within the default budget")
	if not route.is_empty():
		check(route[0] == start and route[-1] == goal, "route has requested endpoints")
		for i: int in range(1,route.size()):
			check(nav.can_step(route[i-1],nav.DIRECTIONS.find(route[i]-route[i-1])), "every returned source edge is legal")
	# A wall with a single opening requires a detour rather than a straight line.
	nav = open_grid(Vector2i(11,11))
	for y: int in range(10):
		nav.attributes._raw[y*11+5] = 0
	route = nav.find_path(Vector2i(2,2),Vector2i(8,2),121)
	check(not route.is_empty() and route.size() > 7, "wall is routed through its opening")
	if not route.is_empty():
		for i: int in range(1,route.size()):
			check(nav.can_step(route[i-1],nav.DIRECTIONS.find(route[i]-route[i-1])), "detour obeys source corner rules")
	nav.attributes._raw.fill(0)
	check(nav.find_path(Vector2i(2,2),Vector2i(8,2)).is_empty(), "disconnected source still has no path")
	var coord: TwilightL1JTileCoordinates = COORD.new()
	for bad: Transform2D in [
		Transform2D(Vector2(NAN,0),Vector2(0,32),Vector2.ZERO),
		Transform2D(Vector2(INF,0),Vector2(0,32),Vector2.ZERO),
		Transform2D(Vector2(32,0),Vector2(0,32),Vector2(NAN,0)),
		Transform2D(Vector2(32,0),Vector2(0,32),Vector2(INF,0))]:
		check(not coord.configure(Vector2i(20,20),Vector2i.ZERO,bad), "nonfinite projection rejected")
		check(not coord.is_configured(), "invalid projection clears configured state")
	var origin := Vector2i(32704,32704)
	var iso := Transform2D(Vector2(24,-12),Vector2(24,12),Vector2(-48*32704,0))
	check(coord.configure(Vector2i(192,192),origin,iso), "explicit isometric projection accepted")
	for cell: Vector2i in [Vector2i.ZERO,Vector2i(191,191),Vector2i(73,115)]:
		check(coord.world_to_cell(coord.cell_to_world(cell)) == cell, "isometric source coordinate roundtrip")
	for invalid: Vector2 in [Vector2.INF,Vector2(NAN,0),Vector2(1e30,1e30)]:
		check(coord.world_to_cell(invalid) == Vector2i(-1,-1), "invalid world point rejected before integer conversion")
	print("L1J_MAP_RECOVERY_OK " if failures.is_empty() else "L1J_MAP_RECOVERY_FAIL ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
