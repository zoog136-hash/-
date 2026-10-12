extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("PR93_LANDING FAIL: " + message)

func _grid(region: Rect2i, solid: bool) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = region
	grid.cell_size = Vector2(32,32)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	grid.fill_solid_region(region, solid)
	return grid

func _run() -> void:
	# Exercise the real methods without running a scene, AUTO, or user saves.
	var world: Node = load("res://scripts/world.gd").new()
	world.field_map = null
	world.tile_size = 32
	world.rng.seed = 98765
	# Deliberately unrelated display dimensions must never define grid queries.
	world.active_map = {"width": 10000, "height": 10000}
	for offset: Vector2i in [Vector2i(10,20), Vector2i(-12,-9), Vector2i.ZERO]:
		var region := Rect2i(offset, Vector2i(5,4))
		world.astar = _grid(region, true)
		var allowed: Vector2i = offset + Vector2i(2,2)
		world.astar.set_point_solid(allowed, false)
		var expected: Vector2 = world._cell_to_world(allowed)
		check(world._spawn_position_fallback() == expected, "fallback respects grid origin " + str(offset))
		var inside: bool = true
		for i: int in range(64):
			var point: Vector2 = world._random_walkable_position(Vector2.ZERO, 0, 999999)
			inside = inside and point == expected and world._is_walkable_world(point)
		check(inside, "all 64 random landings use actual sparse grid " + str(offset))

	world.astar = _grid(Rect2i(10,20,64,64), false)
	var origin: Vector2 = world._cell_to_world(Vector2i(42,52))
	var nearby: bool = true
	for i: int in range(64):
		var point: Vector2 = world._random_walkable_position(origin, 30, 72)
		nearby = nearby and world._is_walkable_world(point) and point.distance_to(origin) <= 72.001
	check(nearby, "near-owner landing respects requested radius on a large grid")

	world.astar = _grid(Rect2i(10,20,20,20), false)
	world.astar.fill_solid_region(Rect2i(20,20,1,20), true)
	origin = world._cell_to_world(Vector2i(15,25))
	var reachable: bool = true
	for i: int in range(32):
		var point: Vector2 = world._random_walkable_position(origin, 0, 600)
		var cell: Vector2i = world._world_to_cell(point)
		reachable = reachable and world.astar.is_in_boundsv(cell)
		if world.astar.is_in_boundsv(cell):
			reachable = reachable and not world.astar.get_id_path(Vector2i(15,25), cell).is_empty()
	check(reachable, "near-owner landing never crosses a disconnected barrier")
	world.astar = null
	check(world._random_walkable_position(Vector2.ZERO, 0, 100) == Vector2(64,64), "null grid returns existing terminal fallback without querying AStar")
	world.free()
	if failures.is_empty():
		print("PR93_LANDING_OK: %d checks" % checks)
		quit(0)
	else:
		print("PR93_LANDING_FAILED: " + JSON.stringify(failures))
		quit(1)
