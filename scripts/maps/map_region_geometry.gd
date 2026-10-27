extends RefCounted
## Shared region geometry for navigation, encounters and both map views.

static func polygon(record: Dictionary, key: String = "polygon") -> PackedVector2Array:
	var points := PackedVector2Array()
	for p: Array in record.get(key, []): points.append(Vector2(float(p[0]),float(p[1])))
	return points

static func contains(record: Dictionary, point: Vector2) -> bool:
	var inside: bool = false
	if record.has("_prepared_polygon"):
		inside = Geometry2D.is_point_in_polygon(point,record["_prepared_polygon"])
	elif record.has("polygon"):
		inside = Geometry2D.is_point_in_polygon(point,polygon(record))
	elif record.has("_prepared_polygons"):
		for item: Dictionary in record._prepared_polygons:
			if (item.bounds as Rect2).has_point(point) and Geometry2D.is_point_in_polygon(point,item.points):
				inside=true
				break
	elif record.has("polygons"):
		for raw: Array in record.polygons:
			if Geometry2D.is_point_in_polygon(point,polygon({"polygon":raw})):
				inside = true
				break
	elif record.has("rect"):
		var a: Array = record.rect
		inside = Rect2(a[0],a[1],a[2],a[3]).has_point(point)
	else:
		inside = point.distance_squared_to(Vector2(record.center[0],record.center[1])) <= pow(float(record.radius),2)
	if not inside: return false
	# Exclusions are holes, not additional allowed areas. Both cached spawn cells
	# and saved boss homes use this same predicate, including prepared geometry.
	for excluded: Dictionary in record.get("_prepared_exclusions", record.get("exclusions", [])):
		if contains(excluded, point): return false
	return true

static func prepare(record: Dictionary) -> Dictionary:
	var prepared: Dictionary = record.duplicate(false)
	if record.has("polygon"): prepared["_prepared_polygon"] = polygon(record)
	elif record.has("polygons"):
		var polygons: Array[Dictionary]=[]
		for raw: Array in record.polygons:
			var points: PackedVector2Array=polygon({"polygon":raw})
			if points.is_empty():continue
			var bounds:=Rect2(points[0],Vector2.ZERO)
			for point: Vector2 in points:bounds=bounds.expand(point)
			# Broad phase only; retain the exact inclusive polygon test at edges.
			polygons.append({"points":points,"bounds":bounds.grow(1.0)})
		prepared["_prepared_polygons"]=polygons
	if record.has("exclusions"):
		var exclusions: Array = []
		for excluded: Dictionary in record.exclusions: exclusions.append(prepare(excluded))
		prepared["_prepared_exclusions"] = exclusions
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
