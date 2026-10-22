extends SceneTree

const LANDING = preload("res://tests/monster_capture_landing.gd")
var failures: int = 0
var checks: int = 0

class FixtureField extends RefCounted:
	var data: Dictionary = {"portal": []}
	var allowed: Array[Vector2] = []
	var all_walkable: bool = false
	var clear: bool = true
	var safe: bool = false
	var sight: bool = true
	var reads: int = 0
	func walkable(point: Vector2) -> bool:
		reads += 1
		if all_walkable: return true
		for value: Vector2 in allowed:
			if point.distance_to(value) < 0.01: return true
		return false
	func point_clear(_point: Vector2) -> bool: return clear
	func is_safe(_point: Vector2) -> bool: return safe
	func line_clear(_point: Vector2, _target: Vector2) -> bool: return sight
	func world_to_cell(point: Vector2) -> Vector2i:
		return Vector2i(floori(point.x / 24.0), floori(point.y / 24.0))
	func cell_to_world(cell: Vector2i) -> Vector2: return Vector2(cell) * 24.0

func _initialize() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func old_position(field: FixtureField, target: Vector2) -> Vector2:
	for i: int in range(8):
		var point: Vector2 = target + Vector2.from_angle(float(i) * PI / 4.0) * 170.0
		if field.walkable(point) and field.point_clear(point) and not field.is_safe(point) and field.line_clear(point, target):
			return point
	return Vector2.INF

func _run() -> void:
	var field := FixtureField.new()
	field.all_walkable = true
	check(LANDING.find_position(field, Vector2.ZERO).is_equal_approx(Vector2(170, 0)), "preserve original open-floor framing")
	field.all_walkable = false
	field.allowed = [Vector2(56, 0)]
	check(not old_position(field, Vector2.ZERO).is_finite(), "old eight-point ring misses narrow floor")
	var point: Vector2 = LANDING.find_position(field, Vector2.ZERO)
	check(point.is_equal_approx(Vector2(56, 0)), "refined radius finds narrow floor")
	check(LANDING.fits(field, point, Vector2.ZERO), "selected narrow floor satisfies every predicate")
	var angled: Vector2 = Vector2.from_angle(TAU / 32.0) * 170.0
	field.allowed = [angled]
	check(not old_position(field, Vector2.ZERO).is_finite(), "old angles miss available floor")
	check(LANDING.find_position(field, Vector2.ZERO).is_equal_approx(angled), "refined angle finds available floor")
	field.allowed = [Vector2(72, 24)]
	check(not old_position(field, Vector2.ZERO).is_finite(), "old ring misses a source cell")
	check(LANDING.find_position(field, Vector2.ZERO).is_equal_approx(Vector2(72, 24)), "cell fallback finds actual floor centre")
	check(LANDING.find_position(field, Vector2.ZERO) == LANDING.find_position(field, Vector2.ZERO), "search is deterministic")
	field.clear = false
	check(not LANDING.find_position(field, Vector2.ZERO).is_finite(), "blocked footprint is not accepted")
	field.clear = true
	field.safe = true
	check(not LANDING.find_position(field, Vector2.ZERO).is_finite(), "safe zone is not accepted")
	field.safe = false
	field.sight = false
	check(not LANDING.find_position(field, Vector2.ZERO).is_finite(), "blocked LOS is not accepted")
	field.sight = true
	field.allowed = [Vector2(56, 0)]
	field.data.portal = [{"position": [56, 0], "radius": 18}]
	check(not LANDING.find_position(field, Vector2.ZERO).is_finite(), "portal trigger is not accepted")
	field.data.portal = [{"position": [34, 0], "radius": 18}]
	check(not LANDING.find_position(field, Vector2.ZERO).is_finite(), "portal boundary includes actor foot")
	field.allowed = [Vector2(56, 0), Vector2(-56, 0)]
	check(LANDING.find_position(field, Vector2.ZERO).is_equal_approx(Vector2(-56, 0)), "find alternative outside portal without disabling it")
	field.data.portal = []
	field.allowed = [Vector2.ZERO, Vector2(240, 0)]
	check(not LANDING.find_position(field, Vector2.ZERO).is_finite(), "do not overlap target or exceed camera radius")
	field.allowed.clear()
	field.reads = 0
	check(not LANDING.find_position(field, Vector2.ZERO).is_finite(), "missing floor returns explicit failure")
	check(field.reads <= 824, "finite search bound")
	field.reads = 0
	check(not LANDING.find_position(field, Vector2.INF).is_finite(), "reject nonfinite target")
	check(field.reads == 0, "invalid target does not query map")
	check(not LANDING.find_position(null, Vector2.ZERO).is_finite(), "reject missing map")
	check(not LANDING.fits(field, Vector2.INF, Vector2.ZERO), "reject nonfinite candidate")
	print("MONSTER_CAPTURE_LANDING_OK checks=%d" % checks if failures == 0 else "MONSTER_CAPTURE_LANDING_FAILED checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
