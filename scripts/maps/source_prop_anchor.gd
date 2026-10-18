extends RefCounted
## Place a reviewed tree's trunk on its existing source obstacle, without
## changing any original passability byte, actor scale, or animation resource.
static func tree_foot(field: OriginalPlayableField, box: Array, authored: Vector2) -> Vector2:
	if box.size() != 4 or not authored.is_finite(): return authored
	if field.value_at(field.world_to_cell(authored),true) == 0: return authored
	for value: Variant in box:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return authored
	var rect := Rect2i(int(box[0]),int(box[1]),int(box[2]),int(box[3]))
	if rect.size.x <= 0 or rect.size.y <= 0 or rect.size.x > 32 or rect.size.y > 32: return authored
	var result: Vector2 = authored
	var distance: float = INF
	for y: int in range(rect.position.y,rect.end.y):
		for x: int in range(rect.position.x,rect.end.x):
			var cell := Vector2i(x,y)
			if not field.in_bounds(cell) or field.value_at(cell,true) != 0: continue
			var point: Vector2 = field.cell_to_world(cell)
			var candidate: float = point.distance_squared_to(authored)
			if candidate < distance:
				distance = candidate
				result = point
	return result
