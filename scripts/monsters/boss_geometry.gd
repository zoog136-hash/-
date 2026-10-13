extends RefCounted
class_name TwilightBossGeometry

## The existing TWILIGHT hit geometry, shared by presentation and resolution.
## Existing species records retain their ranges and damage multipliers.
## Degenerate aims use one direction for both the warning and the hit test.
const HALF_WIDTH: float = 55.0
const HALF_ANGLE: float = 0.55

static func direction(aim: Vector2, fallback: Vector2 = Vector2.RIGHT) -> Vector2:
	if aim.length_squared() > 0.000001: return aim.normalized()
	return fallback.normalized() if fallback.length_squared() > 0.000001 else Vector2.RIGHT

static func contains(kind: String, radius: float, relative: Vector2, aim: Vector2) -> bool:
	aim = direction(aim)
	radius = maxf(0.0, radius)
	if kind == "cone":
		return relative.length() <= radius * 2.0 and (relative.is_zero_approx() or relative.normalized().dot(aim) >= cos(HALF_ANGLE))
	if kind in ["beam", "charge"]:
		var projection: float = relative.dot(aim)
		return projection >= 0.0 and projection <= radius * 2.0 and absf(relative.cross(aim)) <= HALF_WIDTH
	if kind in ["summon", "volley"]: return false # no area damage in these patterns
	return relative.length() <= radius

static func outline(kind: String, radius: float, aim: Vector2) -> PackedVector2Array:
	aim = direction(aim)
	radius = maxf(0.0, radius)
	if kind in ["beam", "charge"]:
		var side: Vector2 = aim.orthogonal() * HALF_WIDTH
		return PackedVector2Array([-side, side, aim * radius * 2.0 + side, aim * radius * 2.0 - side])
	var points := PackedVector2Array()
	if kind == "cone":
		points.append(Vector2.ZERO)
		for i: int in range(33): points.append(aim.rotated(-HALF_ANGLE + float(i) * HALF_ANGLE / 16.0) * radius * 2.0)
	elif kind not in ["summon", "volley"]:
		for i: int in range(64): points.append(Vector2.from_angle(TAU * float(i) / 64.0) * radius)
	return points
