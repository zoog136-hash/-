extends RefCounted
## Test-only camera landing. Never move a monster, change collision, or disable portals.
const MIN_DISTANCE: float = 24.0
const MAX_DISTANCE: float = 220.0
const RADII: Array[float] = [170.0, 144.0, 112.0, 80.0, 56.0, 32.0]
const CELL_RADIUS: int = 12

static func fits(field: Object, point: Vector2, target: Vector2) -> bool:
	if field == null or not point.is_finite() or not target.is_finite(): return false
	var distance: float = point.distance_to(target)
	if distance < MIN_DISTANCE or distance > MAX_DISTANCE: return false
	if not field.walkable(point) or not field.point_clear(point) or field.is_safe(point): return false
	if not field.line_clear(point, target): return false
	# Keep real map transitions live; do not land inside a portal's trigger.
	for portal: Dictionary in field.data.get("portal", []):
		var position: Array = portal.get("position", [])
		if position.size() != 2: continue
		var center := Vector2(float(position[0]), float(position[1]))
		if point.distance_to(center) <= float(portal.get("radius", 18.0)) + 4.0: return false
	return true

static func find_position(field: Object, target: Vector2) -> Vector2:
	if field == null or not target.is_finite(): return Vector2.INF
	# Preserve the former framing whenever its original eight candidates work.
	for direction: int in range(8):
		var point: Vector2 = target + Vector2.from_angle(float(direction) * TAU / 8.0) * 170.0
		if fits(field, point, target): return point
	# A single 170px ring can miss every floor in a narrow source-map corridor.
	for radius: float in RADII:
		for direction: int in range(32):
			var point: Vector2 = target + Vector2.from_angle(float(direction) * TAU / 32.0) * radius
			if fits(field, point, target): return point
	# Check actual nearby navigation-cell centres as well. This is bounded and
	# deterministic, with the same walkability, safe-zone and LOS requirements.
	var cell: Vector2i = field.world_to_cell(target)
	for radius: int in range(1, CELL_RADIUS + 1):
		for y: int in range(-radius, radius + 1):
			for x: int in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius: continue
				var point: Vector2 = field.cell_to_world(cell + Vector2i(x, y))
				if fits(field, point, target): return point
	# The caller must fail explicitly; never silently keep the map entry point.
	return Vector2.INF
