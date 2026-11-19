extends RefCounted
## Progress of the player along a click / auto-pursuit route.
##
## A route searched from where the player stands starts at the centre of the
## player's own cell (A* start cell; source_field.gd keeps it whenever the
## straight line to the next corner is not clear). Auto pursuit searches again
## every 0.65 s, so at the original walk (2.25 cells/s since #642, 1.46 cells
## per search) the player had usually already walked past that centre and
## turned back to it, then forward again: "이동하면서 앞뒤로 왔다갔다".
## A point is passed when the player is already beyond it toward the next
## point and still within that leg's corridor (0.35 of a leg to the side), so
## going straight on to the next point leaves the same cell toward the same
## neighbour the route chose, and only when the field's own line test allows
## that straight walk (no wall or corner is cut; without a field nothing is
## skipped). The final point (the destination) is never skipped.
## Auto pursuit also searches its new route from the point the player is
## already walking to (world.gd _auto_pursuit_path), so a re-search never
## starts behind the player.
const CORRIDOR: float = 0.35
## A walk whose step this frame is under this share of the intended step is
## not progressing (auto pursuit "stuck" clock).
const STALL_SHARE: float = 0.25

## Index of the first point of `points`, from `from_index`, that the actor at
## `here` still has to walk to. With `coordinates` (an original 523 Land's
## source_coordinates.gd) the test runs in square grid cells; the 48x24
## diamond is not orthogonal on screen.
static func first_ahead(here: Vector2, points: PackedVector2Array, from_index: int = 0, coordinates: Object = null, clear: Callable = Callable()) -> int:
	var index: int = maxi(0, from_index)
	var at: Vector2 = _grid(coordinates, here)
	while index + 1 < points.size():
		var a: Vector2 = _grid(coordinates, points[index])
		var leg: Vector2 = _grid(coordinates, points[index + 1]) - a
		var length_squared: float = leg.length_squared()
		if length_squared < 0.000001:
			index += 1
			continue
		var t: float = (at - a).dot(leg) / length_squared
		if t <= 0.0: break
		var side: float = (at - (a + leg * minf(t, 1.0))).length()
		if side > sqrt(length_squared) * CORRIDOR: break
		# The field must allow the straight walk to the next point; otherwise
		# the route's own corner is the way round (walls are never cut).
		if not clear.is_valid() or not bool(clear.call(here, points[index + 1])): break
		index += 1
	return index

static func _grid(coordinates: Object, point: Vector2) -> Vector2:
	if coordinates == null: return point
	var grid: Variant = coordinates.call("world_to_grid", point)
	return grid if grid is Vector2 and (grid as Vector2).is_finite() else point

## `points` without the points already passed (see first_ahead).
static func trim_passed(here: Vector2, points: PackedVector2Array, coordinates: Object = null, clear: Callable = Callable()) -> PackedVector2Array:
	var start: int = first_ahead(here, points, 0, coordinates, clear)
	return points.slice(start) if start > 0 else points

## True when a walk that wants `intended_speed` px/s moved under STALL_SHARE
## of its step this frame. Standing on purpose (attacking, waiting) is not a
## stall. Per expected step, not per pixel: the original vertical walk is
## 54 px/s, under 1 px per 60 Hz frame and 1.8 px at 30 Hz, less when slowed.
static func stalled(moved: Vector2, intended_speed: float, delta: float) -> bool:
	if intended_speed <= 0.0 or delta <= 0.0: return false
	return moved.length() < intended_speed * delta * STALL_SHARE
