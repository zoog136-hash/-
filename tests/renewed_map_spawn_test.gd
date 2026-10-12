extends SceneTree
## Real-map regression. Run after Godot editor import; never substitute fixtures for terrain coverage.
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const RELAYOUT = preload("res://scripts/monsters/renewed_map_spawns.gd")
const GEOMETRY = preload("res://scripts/maps/map_region_geometry.gd")
const FIELD = preload("res://scripts/maps/playable_field.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
var failures: Array[String] = []
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("RENEWED SPAWN FAIL: " + message)

func _initialize() -> void: call_deferred("_run")

func _geometry_cases() -> void:
	var raw: Dictionary = {"rect": [0, 0, 200, 200], "exclusions": [{"center": [100, 100], "radius": 30}]}
	var prepared: Dictionary = GEOMETRY.prepare(raw)
	for shape: Dictionary in [raw, prepared]:
		check(GEOMETRY.contains(shape, Vector2(20, 20)), "outer area remains available")
		check(not GEOMETRY.contains(shape, Vector2(100, 100)), "circle exclusion rejects its center")
		check(not GEOMETRY.contains(shape, Vector2(130, 100)), "circle exclusion includes its boundary")
		check(not GEOMETRY.contains(shape, Vector2(250, 250)), "outside outer area remains rejected")
	var poly: Dictionary = {"polygon": [[0, 0], [200, 0], [200, 200], [0, 200]], "exclusions": [{"rect": [80, 0, 40, 200]}]}
	check(not GEOMETRY.contains(GEOMETRY.prepare(poly), Vector2(100, 50)), "prepared polygon keeps trunk-route hole")
	check(GEOMETRY.contains(GEOMETRY.prepare(poly), Vector2(20, 50)), "side hunting lane stays usable")
	var split: Dictionary = {"polygons": [[[0, 0], [60, 0], [60, 60], [0, 60]], [[100, 0], [160, 0], [160, 60], [100, 60]]], "exclusions": [{"rect": [110, 10, 20, 20]}]}
	check(GEOMETRY.contains(split, Vector2(120, 50)), "multi-polygon support preserved")
	check(not GEOMETRY.contains(split, Vector2(120, 20)), "multi-polygon also honors exclusion")

func _count(definition: Dictionary, mode: String) -> int:
	var total: int = 0
	for spawn: Dictionary in definition.monster_spawn:
		if str(spawn.get("mode", "normal")) == mode: total += int(spawn.max_count)
	return total

func _sample_capacity(field: PlayableField, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var occupied: Array[Vector2] = []
	for spawn: Dictionary in field.data.monster_spawn:
		var radius: float = float(spawn.get("spawn_radius", 0))
		var box := Rect2(float(spawn.rect[0]), float(spawn.rect[1]), float(spawn.rect[2]), float(spawn.rect[3]))
		var spacing: float = float(spawn.get("min_spacing", 28))
		var first := Vector2.INF
		var placed: int = 0
		for slot: int in range(int(spawn.max_count)):
			for attempt: int in range(64):
				var point: Vector2 = field.sample_spawn(str(spawn.id), rng)
				if not point.is_finite(): break
				if radius > 0 and point.distance_to(box.get_center()) > radius: continue
				var clear: bool = true
				for other: Vector2 in occupied:
					if other.distance_squared_to(point) < spacing * spacing: clear = false; break
				if not clear: continue
				check(field.walkable(point) and field.point_clear(point) and not field.is_safe(point), "walkable/clear/non-safe " + str(field.data.map_id) + "/" + str(spawn.id))
				check(field.spawn_contains(spawn, point), "all exclusions enforced " + str(field.data.map_id) + "/" + str(spawn.id))
				occupied.append(point)
				if not first.is_finite(): first = point
				placed += 1
				break
		check(placed == int(spawn.max_count), "full capacity seed %d %s/%s (%d/%d)" % [seed_value, field.data.map_id, spawn.id, placed, spawn.max_count])
		if first.is_finite():
			var entry := Vector2(float(field.data.spawn_position[0]), float(field.data.spawn_position[1]))
			check(not field.path(entry, first).is_empty(), "reachable from current entrance " + str(field.data.map_id) + "/" + str(spawn.id))

func _run() -> void:
	_geometry_cases()
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	CATALOG.expand(base["몬스터"])
	var records_before: String = JSON.stringify(CATALOG.records_by_name)
	var profiles_before: String = JSON.stringify(CATALOG.spawn_profiles)
	var paths: Array = ["res://data/maps/aden_field.json"]
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json"))
	for entry: Dictionary in index: paths.append(str(entry.path))
	var report: Dictionary = {"revision": RELAYOUT.revision(), "maps": {}, "checks": 0, "failures": []}
	var boss_names: Dictionary = {}
	var total_bosses: int = 0
	var total_normal: int = 0
	var total_dense: int = 0
	for path: String in paths:
		var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var before: String = JSON.stringify(original)
		var definition: Dictionary = CATALOG.apply_map(original)
		var id: String = str(definition.map_id)
		check(str(definition.get("spawn_layout_revision", "")) == RELAYOUT.revision(), "rules applied " + id)
		check(JSON.stringify(original) == before, "source map never mutated " + id)
		check(JSON.stringify(CATALOG.apply_map(definition)) == JSON.stringify(definition), "catalog application is idempotent " + id)
		for key: String in ["map_id", "bounds", "layout_revision", "navigable_polygons", "collision", "roads", "surfaces", "water", "bridges", "spawn_position", "npc_spawn", "portal", "teleport"]:
			check(definition.get(key) == original.get(key), "preserved " + id + "/" + key)
		var baseline: Dictionary = CATALOG.spawn_profiles.maps[id]
		check(_count(definition, "normal") == _count(baseline, "normal"), "normal budget preserved " + id)
		check(_count(definition, "dense") == _count(baseline, "dense"), "burst budget preserved " + id)
		for previous: Dictionary in baseline.monster_spawn:
			var current: Dictionary = {}
			for spawn: Dictionary in definition.monster_spawn:
				if str(spawn.id) == str(previous.id): current = spawn; break
			check(not current.is_empty(), "existing spawn ID preserved " + id + "/" + str(previous.id))
			if id != "albino_04" or str(previous.get("mode", "normal")) != "boss":
				check(current.get("respawn_time") == previous.get("respawn_time"), "respawn unchanged " + id + "/" + str(previous.id))
		for spawn: Dictionary in definition.monster_spawn:
			var mode: String = str(spawn.get("mode", "normal"))
			check(int(spawn.max_count) > 0, "positive capacity " + id + "/" + str(spawn.id))
			check(spawn.monster_types.size() > 0, "nonempty roster " + id + "/" + str(spawn.id))
			if spawn.has("weights"):
				check(spawn.weights.size() == spawn.monster_types.size(), "weights match filtered roster " + id + "/" + str(spawn.id))
				for weight: Variant in spawn.weights: check(float(weight) > 0, "positive roster weight")
			for name: String in spawn.monster_types:
				check(CATALOG.records_by_name.has(name), "existing species " + name)
				var record: Dictionary = CATALOG.records_by_name.get(name, {})
				check(LOOT.is_boss_record(record) == (mode == "boss"), "boss and normal classification agree " + id + "/" + name)
			if mode == "boss":
				total_bosses += 1
				check(int(spawn.max_count) == 1, "one boss per encounter")
				check(not boss_names.has(str(spawn.monster_types[0])), "no duplicated boss encounter " + str(spawn.monster_types[0]))
				boss_names[str(spawn.monster_types[0])] = id
				check(spawn.has("patrol_region"), "boss patrol is bounded " + id)
		if id == "albino_04": check(_count(definition, "boss") == 0, "Albino four no longer duplicates the demon")
		if id == "oman_01":
			for spawn: Dictionary in definition.monster_spawn:
				if str(spawn.get("mode", "normal")) != "boss": continue
				var rect := Rect2(float(spawn.rect[0]), float(spawn.rect[1]), float(spawn.rect[2]), float(spawn.rect[3]))
				check(rect.get_area() < 1000000, "Oman one boss is not floor-wide")
				check(rect.get_center().is_equal_approx(Vector2(original.review_points.boss[0], original.review_points.boss[1])), "current boss review anchor used")
		var field: PlayableField = FIELD.new()
		field.configure(definition)
		for spawn: Dictionary in definition.monster_spawn:
			check(field.spawn_cells.get(str(spawn.id), []).size() > 0, "nonempty reachable candidates " + id + "/" + str(spawn.id))
		_sample_capacity(field, 20261012)
		_sample_capacity(field, 20261013)
		total_normal += _count(definition, "normal")
		total_dense += _count(definition, "dense")
		report.maps[id] = {"normal": _count(definition, "normal"), "dense": _count(definition, "dense"), "boss": _count(definition, "boss"), "spawns": definition.monster_spawn}
		print("RENEWED MAP CHECKED: " + id)
	check(paths.size() == 25, "all 25 current authored maps covered")
	check(total_normal == 1072 and total_dense == 96 and total_bosses == 28, "global population budgets 1072/96/28")
	check(boss_names.get("흑장로", "") == "aden_world" and boss_names.get("데스나이트", "") == "aden_world", "dedicated field bosses present")
	check(JSON.stringify(CATALOG.records_by_name) == records_before, "monster stats/AI/drop records not mutated")
	check(JSON.stringify(CATALOG.spawn_profiles) == profiles_before, "historical base profiles not mutated")
	var outside: Dictionary = {"map_id": "l1_4", "monster_spawn": []}
	check(RELAYOUT.apply(outside, {}, {}) == outside, "separate original-map runtime untouched")
	report.checks = checks
	report.failures = failures
	var output: String = "user://renewed-map-spawns.json"
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(arguments.size() - 1):
		if arguments[i] == "--output": output = arguments[i + 1]
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("RENEWED MAP SPAWN TEST: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
