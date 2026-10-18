extends RefCounted
## Frozen historical main has no RemakePlayableField or A3 source bytes.
## Select an actual clear old-map arena for the otherwise identical 32/96/192
## crowd simulation; keep original AI, damage counters and render assertions.
static func find_source_combat_pair(field: PlayableField, _rng: RandomNumberGenerator) -> Dictionary:
	if field == null: return {}
	var candidates: Array[Vector2] = []
	var reviews: Dictionary = field.data.get("review_points",{})
	if reviews.has("central"):
		var a: Array = reviews["central"]
		if a.size()==2: candidates.append(Vector2(float(a[0]),float(a[1])))
	var spawn: Array = field.data.get("spawn_position",[])
	if spawn.size()==2: candidates.append(Vector2(float(spawn[0]),float(spawn[1])))
	candidates.append(Vector2(3550,4300))
	for near: Vector2 in candidates:
		for offset: Vector2 in [Vector2.ZERO,Vector2(160,0),Vector2(-160,0),Vector2(0,160)]:
			var cell: Vector2i = field.nearest_cell(near+offset)
			var point: Vector2 = field.cell_to_world(cell)
			if not field.walkable(point) or not field.point_clear(point) or field.is_safe(point): continue
			for heading: Vector2 in [Vector2(30,0),Vector2(-30,0),Vector2(0,30),Vector2(0,-30)]:
				var enemy: Vector2 = point+heading
				if field.walkable(enemy) and field.point_clear(enemy) and not field.is_safe(enemy) and field.line_clear(point,enemy):
					return {"player":point,"monster":enemy,"baseline_native_geometry":true}
	return {}
