extends RefCounted
## Player walk speed on original 523 Land fields, from the original table.
##
## Original 523 `ListSprAction` row 0 "Walk" (and every weapon Walk row):
## PlayerFrameRate 36, PlayerDelay 16. One walk action is one cell step, so
## a step takes PlayerDelay / PlayerFrameRate = 16 / 36 = 0.444 s and the
## base walk is 36 / 16 = 2.25 cells per second. (The same body action in the
## Lineage PC client is 16 ticks at 24 per second = 0.667 s per cell; M plays
## its player walk at 36 per second.) Speed bonuses (BonusType
## MoveSpeedBonus, value / 1,000,000) stay the existing multipliers.
##
## Cell metric: a diagonal cell step takes as long as a straight one
## (Chebyshev, as in Lineage), so on the 48x24 diamond grid the screen speed
## depends on direction: 108 px/s sideways (one grid diagonal = 48 px),
## 54 px/s up/down (24 px) and 60.4 px/s along a grid axis (26.8 px).
## Before this, every direction used a flat 210 px/s: 4.4 cells/s sideways and
## 8.75 cells/s up/down, 2-3.9 times the original.
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const WALK_ACTION_ID: int = 0
## Values of the original row, used when the definition archive is not
## installed (same numbers; the table is the authority when present).
const ORIGINAL_FRAME_RATE: float = 36.0
const ORIGINAL_DELAY: float = 16.0
const POLICY: String = "ORIGINAL_LISTSPRACTION_WALK_CELL_STEP_CHEBYSHEV_V1"
static var _cells_per_second: float = -1.0
static var _source: Dictionary = {}

static func cells_per_second() -> float:
	if _cells_per_second > 0.0: return _cells_per_second
	var rate: float = ORIGINAL_FRAME_RATE
	var delay: float = ORIGINAL_DELAY
	var origin: String = "constant_copy_of_ListSprAction_0"
	var row: Dictionary = {}
	if not DEF.not_installed(): row = DEF.row("ListSprAction", WALK_ACTION_ID)
	if row.get("Name") == "Walk" and float(row.get("PlayerFrameRate", 0)) > 0.0 and float(row.get("PlayerDelay", 0)) > 0.0:
		rate = float(row.PlayerFrameRate)
		delay = float(row.PlayerDelay)
		origin = "ListSprAction"
	_cells_per_second = rate / delay
	_source = {"table": "ListSprAction", "id": WALK_ACTION_ID, "PlayerFrameRate": rate, "PlayerDelay": delay, "origin": origin, "policy": POLICY}
	return _cells_per_second

## Seconds one cell step takes at `multiplier` (1.0 = base walk).
static func step_seconds(multiplier: float = 1.0) -> float:
	return 1.0 / maxf(0.0001, cells_per_second() * maxf(0.01, multiplier))

static func source() -> Dictionary:
	cells_per_second()
	return _source.duplicate(true)

static func reset() -> void:
	_cells_per_second = -1.0
	_source = {}

## The field's cell coordinates when it is an original 523 Land field, else null.
static func coordinates_of(field: Variant) -> Variant:
	if not field is Object or not is_instance_valid(field) or not (field as Object).get_meta("current523_source_field", false): return null
	var coordinates: Variant = (field as Object).get("coordinates")
	if not coordinates is Object or not bool(coordinates.get("valid")): return null
	return coordinates

## Screen velocity along `direction` that covers `cells` cells per second in
## the Chebyshev metric of the field's cell basis.
static func velocity(coordinates: Object, direction: Vector2, cells: float) -> Vector2:
	if direction.length_squared() < 0.000001: return Vector2.ZERO
	var unit: Vector2 = direction.normalized()
	var bx: Vector2 = coordinates.get("basis_x")
	var by: Vector2 = coordinates.get("basis_y")
	var determinant: float = bx.x * by.y - bx.y * by.x
	if absf(determinant) < 0.000001: return Vector2.ZERO
	# Grid components of one screen pixel along `unit`.
	var gx: float = (unit.x * by.y - unit.y * by.x) / determinant
	var gy: float = (unit.y * bx.x - unit.x * bx.y) / determinant
	var per_pixel: float = maxf(absf(gx), absf(gy))
	if per_pixel <= 0.0: return Vector2.ZERO
	return unit * (cells / per_pixel)

## The eight one-cell screen steps of the field's cell basis (a Chebyshev cell
## step: along either grid axis or both). One original walk/run loop travels
## exactly one of these (523 elf 15282/15284: 48.8/46.8 px sideways, 24.9/23.9
## px up), so the walk root-motion cancel can use the exact step.
static func cell_steps(coordinates: Object) -> Array[Vector2]:
	var steps: Array[Vector2] = []
	if coordinates == null: return steps
	var bx: Vector2 = coordinates.get("basis_x")
	var by: Vector2 = coordinates.get("basis_y")
	for step: Vector2 in [bx, by, bx + by, bx - by]:
		if step.length_squared() < 0.000001: continue
		steps.append(step)
		steps.append(-step)
	return steps
