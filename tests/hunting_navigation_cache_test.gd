extends SceneTree
const FIELD = preload("res://scripts/maps/playable_field.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("HUNTING_CACHE_FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var paths: Array[String] = []
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")): paths.append(str(entry.path))
	for path: String in paths:
		var data: Dictionary = CATALOG.apply_map(JSON.parse_string(FileAccess.get_file_as_string(path)))
		var id: String = str(data.map_id)
		FIELD.navigation_snapshots.clear()
		FIELD.navigation_order.clear()
		var cached := FIELD.new()
		cached.configure(data)
		check(cached.navigation_cache_hit,id+" checked source cache loads")
		var expected: Dictionary = cached.navigation_snapshot()
		FIELD.navigation_snapshots.clear()
		FIELD.navigation_order.clear()
		var raw: Dictionary=data.duplicate(true)
		raw.navigation["use_baked_cache"]=false
		var fresh := FIELD.new()
		fresh.configure(raw)
		check(not fresh.navigation_cache_hit,id+" missing file recomputes")
		var actual: Dictionary = fresh.navigation_snapshot()
		check(actual.solid_runs==expected.solid_runs,id+" all solid cells identical")
		check(actual.reachable==expected.reachable,id+" all reachable cells identical")
		check(actual.spawn_cells==expected.spawn_cells,id+" all spawn cells identical")
		var origin := Vector2(data.spawn_position[0],data.spawn_position[1])
		fresh.astar.set_point_solid(fresh.world_to_cell(origin),true)
		fresh.reachable[fresh.world_to_cell(origin).y*fresh.width+fresh.world_to_cell(origin).x]=0
		for cells: Array in fresh.spawn_cells.values(): cells.clear()
		var independent := FIELD.new()
		independent.configure(data)
		check(independent.walkable(origin),id+" instances do not share mutable AStar")
		check(independent.navigation_snapshot().reachable==expected.reachable,id+" reachability is copied")
		check(independent.spawn_cells==expected.spawn_cells,id+" spawn collections are copied")
		var changed: Dictionary=data.duplicate(true)
		changed.collision.append({"kind":"cache_regression_probe","shape":"circle","center":data.spawn_position,"radius":70})
		var invalidated := FIELD.new()
		invalidated.configure(changed)
		check(not invalidated.navigation_cache_hit and not invalidated.walkable(origin),id+" modified geometry invalidates old cache")
	print("HUNTING_NAV_CACHE_OK " if failures.is_empty() else "HUNTING_NAV_CACHE_FAILED ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
