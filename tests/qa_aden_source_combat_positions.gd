extends RefCounted
# Use the original A3 source-edge topology to choose a REAL combat probe.
# The old fixed viewport point (3550,4300) is outside Aden's isometric
# source grid, so nearest_cell returned (-1,-1) and both attack counters
# stayed at zero even with AUTO enabled. Never fabricate damage or bypass
# blocked edges to make the benchmark pass.
const HEADINGS: Array[Vector2i] = [
	Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1),
	Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]

static func find_source_combat_pair(field: RemakePlayableField, rng: RandomNumberGenerator) -> Dictionary:
	if field == null or str(field.data.get("map_id", "")) != "aden_world":
		return {}
	# Use live configured monster regions with actual source navigation bytes.
	# Both the actor and its target must be walkable, non-safe and have an
	# unblocked source edge between them. No gameplay object is modified.
	for region: Dictionary in field.data.get("monster_spawn", []):
		var region_id: String = str(region.get("id", ""))
		if region_id.is_empty(): continue
		for attempt: int in range(64):
			var player_point: Vector2 = field.sample_spawn(region_id, rng)
			if not player_point.is_finite(): break
			if not field.point_clear(player_point, 4.0) or field.is_safe(player_point): continue
			var cell: Vector2i = field.world_to_cell(player_point)
			if not field.in_bounds(cell): continue
			for heading: int in [2, 6, 4, 0, 1, 3, 5, 7]:
				if not field.can_step(cell, heading): continue
				var target_cell: Vector2i = cell + HEADINGS[heading]
				if not field.in_bounds(target_cell): continue
				var target_point: Vector2 = field.cell_to_world(target_cell)
				if not field.point_clear(target_point, 4.0) or field.is_safe(target_point): continue
				if not field.line_clear(player_point, target_point): continue
				return {
					"player": player_point, "monster": target_point,
					"region": region_id, "source_cell": [cell.x, cell.y],
					"target_cell": [target_cell.x, target_cell.y],
					"source_edge_verified": true,
					"safe_zone_excluded": true,
					"original_navigation_unchanged": true
				}
	return {}
