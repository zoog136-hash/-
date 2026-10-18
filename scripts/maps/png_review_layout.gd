extends RefCounted
## Source-cell placements in a non-saving PNG review session only.
## Never modifies definitions, navigation bytes or ordinary game placements.

static func point(field: RemakePlayableField, value: Variant) -> Vector2:
	if not value is Array or value.size() != 2: return Vector2.INF
	for n: Variant in value:
		if not (n is int or n is float) or not is_finite(float(n)) or float(n) != floorf(float(n)): return Vector2.INF
	var cell := Vector2i(int(value[0]),int(value[1]))
	if not field.in_bounds(cell): return Vector2.INF
	var at: Vector2 = field.cell_to_world(cell)
	return at if field.point_clear(at) else Vector2.INF

static func prepare(field: RemakePlayableField, spawn: Vector2, overrides: Dictionary) -> Dictionary:
	var result: Dictionary = {"npc_spawn":field.data.npc_spawn.duplicate(true),"portal":field.data.portal.duplicate(true)}
	for category: Variant in overrides:
		if not category in ["npc_spawn","portal"] or not overrides[category] is Array: return {}
		var seen: Dictionary = {}
		for change: Variant in overrides[category]:
			if not change is Dictionary or not change.get("id") is String or seen.has(change.id): return {}
			seen[change.id] = true
			var found: Dictionary = {}
			for record: Dictionary in result[category]:
				if record.id == change.id: found = record;break
			if found.is_empty(): return {}
			var at: Vector2 = point(field,change.get("source_cell"))
			if not at.is_finite() or field.path(spawn,at).is_empty(): return {}
			found.position = [at.x,at.y]
			found.source_cell = change.source_cell.duplicate()
			found.placement_status = "PNG_REVIEW_MANUAL_CONNECTED_CELL"
			if change.has("target_cell"):
				if category != "portal" or found.get("target_map") != field.data.map_id: return {}
				var target: Vector2 = point(field,change.target_cell)
				if not target.is_finite() or field.path(spawn,target).is_empty(): return {}
				found.target_position = [target.x,target.y]
	return result

static func apply(field: RemakePlayableField, spawn: Vector2, prepared: Dictionary) -> void:
	field.data.npc_spawn = prepared.npc_spawn
	field.data.portal = prepared.portal
	field.data.spawn_position = [spawn.x,spawn.y]
	var entry: Dictionary = field.definition.remake_gameplay.entry_exclusion.duplicate(true)
	entry.center = [spawn.x,spawn.y]
	field.reservations.clear();field.reservations.append(entry)
	for category: String in ["npc_spawn","portal"]:
		for record: Dictionary in field.data[category]: field.reservations.append({"center":record.position,"radius":64.0})
