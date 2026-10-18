extends RefCounted
## Explicit manually traced ground footprints in PNG review sessions.
## No image is read here; original grid bytes and ordinary gameplay stay intact.
var polygons: Array[PackedVector2Array] = []
var bounds: Array[Rect2] = []

func configure(rows: Array) -> bool:
	polygons.clear();bounds.clear()
	if rows.size() > 32: return false
	for row: Variant in rows:
		if not row is Dictionary or not row.get("polygon_world") is Array or row.polygon_world.size() < 3 or row.polygon_world.size() > 64: return false
		var polygon := PackedVector2Array()
		for p: Variant in row.polygon_world:
			if not p is Array or p.size() != 2: return false
			for n: Variant in p:
				if not (n is int or n is float) or not is_finite(float(n)): return false
			polygon.append(Vector2(p[0],p[1]))
		if Geometry2D.triangulate_polygon(polygon).is_empty(): return false
		var rect := Rect2(polygon[0],Vector2.ZERO)
		for p: Vector2 in polygon: rect = rect.expand(p)
		if rect.size.x > 2048 or rect.size.y > 2048: return false
		polygons.append(polygon);bounds.append(rect)
	return true

func point_clear(p: Vector2, radius: float) -> bool:
	for i: int in range(polygons.size()):
		if not bounds[i].grow(radius+.01).has_point(p): continue
		var polygon: PackedVector2Array = polygons[i]
		if Geometry2D.is_point_in_polygon(p,polygon): return false
		for j: int in range(polygon.size()):
			if Geometry2D.get_closest_point_to_segment(p,polygon[j],polygon[(j+1)%polygon.size()]).distance_to(p) < radius: return false
	return true

func line_clear(a: Vector2, b: Vector2, radius: float) -> bool:
	if not point_clear(a,radius) or not point_clear(b,radius): return false
	var query := Rect2(a,Vector2.ZERO).expand(b).grow(radius+.01)
	for i: int in range(polygons.size()):
		if not bounds[i].grow(.01).intersects(query,true): continue
		var polygon: PackedVector2Array = polygons[i]
		for j: int in range(polygon.size()):
			var c: Vector2 = polygon[j]
			var d: Vector2 = polygon[(j+1)%polygon.size()]
			if Geometry2D.segment_intersects_segment(a,b,c,d) != null: return false
			# Endpoints of both segments cover the minimum separation when no
			# intersection exists, so a 4px foot cannot clip polygon corners.
			for p: Vector2 in [a,b]:
				if Geometry2D.get_closest_point_to_segment(p,c,d).distance_to(p) < radius: return false
			for p: Vector2 in [c,d]:
				if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p) < radius: return false
	return true
