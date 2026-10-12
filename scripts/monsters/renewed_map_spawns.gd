extends RefCounted
## A deterministic placement layer over the current authored maps.
## Base species data, map geometry, portals and boss persistence IDs are not edited.
const RULES_PATH = "res://data/monsters/renewed_map_spawn_rules.json"
const GEOMETRY = preload("res://scripts/maps/map_region_geometry.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
static var rules: Dictionary = {}
static var incoming_landings: Dictionary = {}
static var landings_loaded: bool = false

static func _load_rules() -> void:
	if rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		if parsed is Dictionary: rules = parsed

static func revision() -> String:
	_load_rules()
	return str(rules.get("revision", ""))

static func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func _array(value: Vector2) -> Array:
	return [value.x, value.y]

static func _bounds(shape: Dictionary) -> Rect2:
	if shape.has("rect"):
		var r: Array = shape.rect
		return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	if shape.has("polygon"):
		var polygon: PackedVector2Array = GEOMETRY.polygon(shape)
		if polygon.is_empty(): return Rect2()
		var box := Rect2(polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon: box = box.expand(point)
		return box
	var radius: float = float(shape.get("radius", 0.0))
	return Rect2(_vector(shape.get("center", [0, 0])) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

static func _shape(record: Dictionary) -> Dictionary:
	# rect is a broad-phase bound when a polygon is present, not a replacement.
	if record.has("polygon"): return {"polygon": record.polygon.duplicate(true)}
	if record.has("rect"): return {"rect": record.rect.duplicate()}
	return {"center": record.center.duplicate(), "radius": record.radius}

static func _grow(shape: Dictionary, margin: float) -> Array:
	if shape.has("polygon"):
		var result: Array = []
		for polygon: PackedVector2Array in Geometry2D.offset_polygon(GEOMETRY.polygon(shape), margin):
			var points: Array = []
			for point: Vector2 in polygon: points.append(_array(point))
			result.append({"polygon": points})
		return result if not result.is_empty() else [_shape(shape)]
	if shape.has("rect"):
		var box: Rect2 = _bounds(shape).grow(margin)
		return [{"rect": [box.position.x, box.position.y, box.size.x, box.size.y]}]
	return [{"center": shape.center.duplicate(), "radius": float(shape.radius) + margin}]

static func _normal_names(profile: Dictionary, records: Dictionary) -> Array:
	var names: Array = []
	for spawn: Dictionary in profile.get("monster_spawn", []):
		if str(spawn.get("mode", "normal")) == "boss": continue
		for raw: Variant in spawn.get("monster_types", []):
			var name: String = str(raw)
			if records.has(name) and not LOOT.is_boss_record(records[name]) and not names.has(name): names.append(name)
	return names

static func _threat(record: Dictionary) -> float:
	# Ordering heuristic only: does not alter a creature or its rewards.
	var score: float = float(record.get("lv", 1)) + sqrt(maxf(1.0, float(record.get("hp", 100)))) * 0.35
	score += float(record.get("atk", 10)) * 0.6 / maxf(0.2, float(record.get("attack_interval", 1.5)))
	if str(record.get("attack_type", "melee")) != "melee": score *= 1.12
	var ai: Dictionary = record.get("ai", {})
	if bool(ai.get("aggressive", false)): score *= 1.04
	return score * (1.0 + minf(360.0, float(ai.get("social_radius", 0))) / 3600.0)

static func _sort_names(names: Array, records: Dictionary) -> void:
	names.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da: float = _threat(records[str(a)])
		var db: float = _threat(records[str(b)])
		return str(a) < str(b) if is_equal_approx(da, db) else da < db)

static func _load_incoming_landings() -> void:
	if landings_loaded: return
	landings_loaded = true
	var paths: Array = ["res://data/maps/aden_field.json"]
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json"))
	if index is Array:
		for entry: Dictionary in index: paths.append(str(entry.path))
	for path: String in paths:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary: continue
		var definition: Dictionary = parsed
		var exits: Array = definition.get("portal", []).duplicate()
		exits.append_array(definition.get("teleport", []))
		for portal: Dictionary in exits:
			var target: Array = portal.get("target_position", [])
			var id: String = str(portal.get("target_map", ""))
			if target.size() != 2 or id.is_empty(): continue
			if not incoming_landings.has(id): incoming_landings[id] = []
			if not incoming_landings[id].has(target): incoming_landings[id].append(target.duplicate())

static func _protections(definition: Dictionary) -> Array:
	var distances: Dictionary = rules.exclusion_distances
	var result: Array = [{"center": definition.spawn_position.duplicate(), "radius": distances.entry}]
	for region: Dictionary in definition.get("regions", []):
		if str(region.get("type", "")) == "safe": result.append_array(_grow(region, float(distances.safe_margin)))
	var portals: Array = definition.get("portal", []).duplicate()
	portals.append_array(definition.get("teleport", []))
	for portal: Dictionary in portals:
		if portal.has("position"):
			result.append({"center": portal.position.duplicate(), "radius": maxf(float(distances.portal), float(portal.get("radius", 0)) + 160.0)})
		if str(portal.get("target_map", "")) == str(definition.map_id) and portal.get("target_position", []).size() == 2:
			result.append({"center": portal.target_position.duplicate(), "radius": distances.entry})
	for npc: Dictionary in definition.get("npc_spawn", []):
		result.append({"center": npc.position.duplicate(), "radius": distances.npc})
	_load_incoming_landings()
	for position: Array in incoming_landings.get(str(definition.map_id), []):
		result.append({"center": position.duplicate(), "radius": distances.entry})
	# Keep the trunk route open; side hunting lanes still contain monsters.
	var half_width: float = float(distances.road_half_width)
	for road: Dictionary in definition.get("roads", []):
		var points: Array = road.get("points", [])
		for i: int in range(1, points.size()):
			var a: Vector2 = _vector(points[i - 1])
			var b: Vector2 = _vector(points[i])
			if a.is_equal_approx(b): continue
			var normal: Vector2 = (b - a).normalized().orthogonal() * half_width
			result.append({"polygon": [_array(a + normal), _array(b + normal), _array(b - normal), _array(a - normal)]})
			result.append({"center": _array(a), "radius": half_width})
			result.append({"center": _array(b), "radius": half_width})
	return result

static func _attach_exclusions(spawn: Dictionary, protections: Array) -> void:
	var box: Rect2 = _bounds(spawn)
	var exclusions: Array = []
	for shape: Dictionary in protections:
		if box.intersects(_bounds(shape), true): exclusions.append(shape.duplicate(true))
	spawn["exclusions"] = exclusions

static func _set_box(spawn: Dictionary, box: Rect2) -> void:
	spawn["rect"] = [box.position.x, box.position.y, box.size.x, box.size.y]
	spawn.erase("polygon")
	spawn.erase("polygons")
	spawn["spawn_radius"] = 0

static func _allocate_total(spawns: Array, total: int, entry: Vector2) -> void:
	if spawns.is_empty(): return
	spawns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = _bounds(a).get_center().distance_squared_to(entry)
		var db: float = _bounds(b).get_center().distance_squared_to(entry)
		return str(a.id) < str(b.id) if is_equal_approx(da, db) else da < db)
	var low: float = float(rules.progression_weights[0])
	var high: float = float(rules.progression_weights[1])
	var sum_weights: float = float(spawns.size()) * (low + high) * 0.5
	var remaining: int = total
	var fractions: Array = []
	for i: int in range(spawns.size()):
		var fraction: float = float(i) / maxf(1.0, float(spawns.size() - 1))
		var share: float = float(total) * lerpf(low, high, fraction) / sum_weights
		var count: int = int(floor(share))
		spawns[i]["max_count"] = count
		spawns[i]["placement_depth"] = fraction
		remaining -= count
		fractions.append({"index": i, "fraction": share - float(count)})
	fractions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.index) < int(b.index) if is_equal_approx(float(a.fraction), float(b.fraction)) else float(a.fraction) > float(b.fraction))
	for i: int in range(remaining): spawns[int(fractions[i % fractions.size()].index)]["max_count"] += 1

static func apply(definition: Dictionary, profiles: Dictionary, records: Dictionary) -> Dictionary:
	_load_rules()
	var id: String = str(definition.map_id)
	if not rules.get("map_ids", []).has(id): return definition
	if str(definition.get("spawn_layout_revision", "")) == str(rules.revision): return definition
	var result: Dictionary = definition.duplicate(true)
	var policy: Dictionary = rules.maps.get(id, {})
	var spawns: Array = result.monster_spawn
	var total: int = 0
	var normal_pool: Array = _normal_names({"monster_spawn": spawns}, records)
	for source: String in policy.get("roster_sources", []):
		for name: String in _normal_names(profiles.get(source, {}), records):
			if not normal_pool.has(name): normal_pool.append(name)
	_sort_names(normal_pool, records)
	for spawn: Dictionary in spawns:
		if str(spawn.get("mode", "normal")) == "normal": total += int(spawn.max_count)
		if str(spawn.get("mode", "normal")) == "boss" and bool(policy.get("boss_to_hunting", false)):
			spawn["mode"] = "normal"
			spawn["max_count"] = 0
			spawn["respawn_time"] = 25
			spawn["monster_types"] = normal_pool.duplicate()
			for key: String in ["boss_name", "spawn_conditions", "patrol_region", "encounter_region", "spawn_coordinates"]: spawn.erase(key)
		if str(spawn.get("mode", "normal")) != "boss":
			var allowed: Array = []
			var filtered_weights: Array = []
			var old_weights: Array = spawn.get("weights", [])
			for name: String in spawn.monster_types:
				if records.has(name) and not LOOT.is_boss_record(records[name]) and not allowed.has(name):
					allowed.append(name)
					if old_weights.size() == spawn.monster_types.size(): filtered_weights.append(old_weights[spawn.monster_types.find(name)])
			if allowed.is_empty(): allowed = normal_pool.duplicate()
			if allowed.is_empty():
				push_error("No non-boss roster for renewed spawn " + id + "/" + str(spawn.id))
				return definition
			spawn["monster_types"] = allowed
			spawn.erase("weights")
			if str(spawn.get("mode", "normal")) == "dense" and filtered_weights.size() == allowed.size(): spawn["weights"] = filtered_weights
		else:
			spawn["max_count"] = 1
			if policy.has("boss_review_anchor"):
				var anchor: Array = result.get("review_points", {}).get(str(policy.boss_review_anchor), [])
				if anchor.size() != 2:
					push_error("Missing current-map boss anchor: " + id)
					return definition
				var half: Vector2 = _vector(policy.boss_half_size)
				_set_box(spawn, Rect2(_vector(anchor) - half, half * 2.0))
	for boss: Dictionary in policy.get("additional_bosses", []):
		var record: Dictionary = records.get(str(boss.name), {})
		if record.is_empty() or not LOOT.is_boss_record(record):
			push_error("Invalid dedicated boss record: " + str(boss.name))
			return definition
		var habitat: Dictionary = {}
		for spawn: Dictionary in spawns:
			if str(spawn.id) == str(boss.habitat): habitat = spawn; break
		if habitat.is_empty():
			push_error("Missing current habitat for boss: " + str(boss.id))
			return definition
		var box: Rect2 = _bounds(habitat)
		var center: Vector2 = box.position + box.size * _vector(boss.fraction)
		var half: Vector2 = _vector(boss.half_size)
		var spawn: Dictionary = {"id": boss.id, "mode": "boss", "monster_types": [boss.name], "max_count": 1,
			"respawn_time": boss.respawn_time, "roaming_radius": 120, "min_spacing": 64, "boss_name": boss.name,
			"coordinate_evidence": "current_habitat_relative_local_pve_not_original_server"}
		_set_box(spawn, Rect2(center - half, half * 2.0))
		spawns.append(spawn)
	var normal_spawns: Array = []
	for spawn: Dictionary in spawns:
		if str(spawn.get("mode", "normal")) == "normal": normal_spawns.append(spawn)
	_allocate_total(normal_spawns, total, _vector(result.spawn_position))
	var counts: Dictionary = policy.get("normal_counts", {})
	if not counts.is_empty():
		var proposed_total: int = 0
		for spawn: Dictionary in normal_spawns: proposed_total += int(counts.get(str(spawn.id), spawn.max_count))
		if proposed_total == total:
			for spawn: Dictionary in normal_spawns: spawn["max_count"] = int(counts.get(str(spawn.id), spawn.max_count))
	for spawn: Dictionary in normal_spawns:
		var depth: float = float(spawn.get("placement_depth", 0.5))
		var names: Array = spawn.monster_types
		if not bool(policy.get("preserve_habitat_rosters", false)):
			var width: int = mini(3, normal_pool.size())
			var first: int = int(round(depth * float(normal_pool.size() - width)))
			names = normal_pool.slice(first, first + width)
		else: _sort_names(names, records)
		spawn["monster_types"] = names
		var weights: Array = []
		for i: int in range(names.size()):
			var rank: float = float(i) / maxf(1.0, float(names.size() - 1))
			weights.append(snappedf(lerpf(5.0 - rank * 4.0, 1.0 + rank * 4.0, depth), 0.01))
		spawn["weights"] = weights
	# Separate encounters and bursts from normal hunting; never place on a landing.
	var protections: Array = _protections(result)
	var bosses: Array = []
	var dense: Array = []
	for spawn: Dictionary in spawns:
		if str(spawn.get("mode", "normal")) == "boss": bosses.append(spawn)
		if str(spawn.get("mode", "normal")) == "dense": dense.append(spawn)
	for spawn: Dictionary in spawns:
		var local: Array = protections.duplicate()
		var mode: String = str(spawn.get("mode", "normal"))
		if mode != "boss":
			for boss: Dictionary in bosses: local.append_array(_grow(boss, float(rules.exclusion_distances.boss_margin)))
		if mode == "normal":
			for burst: Dictionary in dense: local.append_array(_grow(burst, float(rules.exclusion_distances.dense_margin)))
		_attach_exclusions(spawn, local)
		if mode == "boss":
			var patrol: Dictionary = _shape(spawn)
			patrol["exclusions"] = spawn.exclusions.duplicate(true)
			spawn["patrol_region"] = patrol
			spawn["encounter_region"] = patrol.duplicate(true)
			spawn["spawn_coordinates"] = []
			spawn["placement_policy"] = "current_map_local_encounter"
		spawn["layout_revision"] = str(rules.revision)
	result["boss_zone"] = []
	for region: Dictionary in result.get("regions", []):
		if str(region.get("type", "")) == "boss":
			region["type"] = "combat"
			if bool(policy.get("boss_to_hunting", false)): region["name"] = "혼합 상급 사냥터"
	for boss: Dictionary in bosses:
		var region: Dictionary = {"id": boss.id, "name": str(boss.monster_types[0]), "type": "boss", "color": "c96961"}
		region.merge(_shape(boss), true)
		region["center"] = _array(_bounds(boss).get_center())
		region["radius"] = maxf(_bounds(boss).size.x, _bounds(boss).size.y) * 0.5
		var found: bool = false
		for existing: Dictionary in result.regions:
			if str(existing.id) == str(boss.id):
				for key: String in ["polygon", "polygons", "rect", "center", "radius"]: existing.erase(key)
				existing.merge(region, true)
				found = true
				break
		if not found: result.regions.append(region)
		result.boss_zone.append(str(boss.id))
	result["spawn_layout_revision"] = str(rules.revision)
	result["monster_coordinate_note"] = str(result.get("monster_coordinate_note", "")) + " / 현재 지형 기반 PvE 재배치; 원작 서버 좌표 아님."
	return result
