extends RefCounted
## C17 / P4. DESIGN_NOT_RECOVERED_API. Curved projectile path maths and its cache. Walking
## paths do not use this generator.
const SEGMENT_STEPS := 32
const CACHE_CAPACITY := 500

static func f32(value: float) -> float:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_float(0, value)
	return raw.decode_float(0)

## lroundf: round half away from zero (not banker's rounding, not truncation).
static func lroundf(value: float) -> int:
	var magnitude: float = absf(value)
	var rounded: int = int(floor(magnitude + 0.5))
	return -rounded if value < 0.0 else rounded

## Coordinates enter as float32 and are halved: x -> f32(x) * 0.5.
static func half_x(x: int) -> float:
	return f32(float(x)) * 0.5

## Distance in this coordinate system is L-infinity.
static func linf(a: Vector2, b: Vector2) -> float:
	return maxf(absf(a.x - b.x), absf(a.y - b.y))

## Knot spacing: squared distance to the 0.25 power.
static func knot_delta(a: Vector2, b: Vector2) -> float:
	var d: float = linf(a, b)
	return pow(d * d, 0.25)

## Non-uniform nested cubic interpolation (Barry-Goldman form) at parameter t in [t1, t2].
static func nested_cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t0: float, t1: float, t2: float, t3: float, t: float) -> Vector2:
	var a1: Vector2 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
	var a2: Vector2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
	var a3: Vector2 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
	var b1: Vector2 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
	var b2: Vector2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
	return b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1))

## Original-compatible cache: the key is the four source/destination coordinates only, so
## land, direction and terrain are not part of it, and a hit never re-checks the geometry.
class PathCache extends RefCounted:
	var entries: Dictionary = {}
	var design_invalidations: int = 0

	static func key(sx: int, sy: int, dx: int, dy: int) -> String:
		return "%d,%d,%d,%d" % [sx, sy, dx, dy]

	func lookup(sx: int, sy: int, dx: int, dy: int) -> Variant:
		return entries.get(key(sx, sy, dx, dy))

	func store(sx: int, sy: int, dx: int, dy: int, path: Variant) -> Dictionary:
		if entries.size() >= 500 and not entries.has(key(sx, sy, dx, dy)):
			return {"stored": false, "status": "CAPACITY_500_REACHED_REPLACEMENT_POLICY_UNVERIFIED"}
		entries[key(sx, sy, dx, dy)] = path
		return {"stored": true, "status": "OK"}

	## Safe invalidation is a DESIGN addition, never original behaviour.
	func design_invalidate_all() -> Dictionary:
		entries.clear()
		design_invalidations += 1
		return {"design_addition": "cache_invalidation_not_in_original", "count": design_invalidations}
