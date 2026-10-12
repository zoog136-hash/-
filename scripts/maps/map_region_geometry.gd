extends RefCounted
## Shared region geometry for navigation, encounters and both map views.

static func polygon(record: Dictionary, key: String = "polygon") -> PackedVector2Array:
	var points := PackedVector2Array()
	for p: Array in record.get(key, []): points.append(Vector2(float(p[0]),float(p[1])))
	return points

static func contains(record: Dictionary, point: Vector2) -> bool:
	if record.has("_prepared_polygon"):
		return Geometry2D.is_point_in_polygon(point,record["_prepared_polygon"])
	if record.has("polygon"):
		return Geometry2D.is_point_in_polygon(point,polygon(record))
	if record.has("polygons"):
		for raw: Array in record.polygons:
			if Geometry2D.is_point_in_polygon(point,polygon({"polygon":raw})): return true
		return false
	if record.has("rect"):
		var a: Array = record.rect
		return Rect2(a[0],a[1],a[2],a[3]).has_point(point)
	return point.distance_squared_to(Vector2(record.center[0],record.center[1])) <= pow(float(record.radius),2)

static func prepare(record: Dictionary) -> Dictionary:
	var prepared: Dictionary = record.duplicate(false)
	if record.has("polygon"): prepared["_prepared_polygon"] = polygon(record)
	return prepared

static func reference_to_world(point: Vector2, definition: Dictionary) -> Vector2:
	var reference: Dictionary = definition.get("structure_reference",{})
	var scale: Array = reference.get("image_to_world_scale",[1,1])
	var offset: Array = reference.get("image_to_world_offset",[0,0])
	return point*Vector2(scale[0],scale[1])+Vector2(offset[0],offset[1])

static func world_to_reference(point: Vector2, definition: Dictionary) -> Vector2:
	var reference: Dictionary = definition.get("structure_reference",{})
	var scale: Array = reference.get("image_to_world_scale",[1,1])
	var offset: Array = reference.get("image_to_world_offset",[0,0])
	return (point-Vector2(offset[0],offset[1]))/Vector2(scale[0],scale[1])
