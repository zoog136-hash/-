extends RefCounted
## C14 / P3. DESIGN_NOT_RECOVERED_API. Touch point -> view integer -> normalised -> handler
## -> world half-cell, with every stage returned. float32 steps are explicit.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const VIEW_MAX_X := 1200
const VIEW_MAX_Y := 675
const DESIGN_WIDTH := 800.0
const DESIGN_HEIGHT := 450.0
const CONTAINER_CORRECTION := Vector2i(32, 12)
const HELPER_OFFSET := 48
const MAX_DIRECTIONS := 50

static func f32(value: float) -> float:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_float(0, value)
	return raw.decode_float(0)

## CVTTSS2SI: float32, truncation toward zero.
static func view_to_int(value: float) -> int:
	return int(f32(value))

static func input_point(view_x: float, view_y: float, visible_w: float, visible_h: float) -> Dictionary:
	var ix: int = view_to_int(view_x)
	var iy: int = view_to_int(view_y)
	var gate: bool = ix >= 0 and ix <= VIEW_MAX_X and iy >= 0 and iy <= VIEW_MAX_Y
	var out := {"record": "InputPoint", "design_status": VOCAB.EVIDENCE_DESIGN, "view_float": Vector2(view_x, view_y),
		"view_i32": Vector2i(ix, iy), "gate_passed": gate, "normalized_i32": null, "handler_i32": null, "world_half": null}
	if not gate or visible_w <= 0.0 or visible_h <= 0.0:
		return out
	var scale_x: float = f32(DESIGN_WIDTH / visible_w)
	var scale_y: float = f32(DESIGN_HEIGHT / visible_h)
	var nx: int = int(f32(scale_x * float(ix)))
	var ny: int = int(f32(scale_y * float(iy)))
	out["normalized_i32"] = Vector2i(nx, ny)
	out["handler_i32"] = Vector2i(nx, ny) + CONTAINER_CORRECTION
	return out

## Forward projection: even = dX & ~1, parity = dX & 1.
static func world_to_screen(world: Vector2i, origin: Vector2i) -> Vector2i:
	var dx: int = world.x - origin.x
	var dy: int = world.y - origin.y
	var even: int = dx & ~1
	var parity: int = dx & 1
	return Vector2i(12 * even + 24 * dy + 24 * parity - 24, 12 * dy - 6 * even)

## Reverse projection for the normal range; every division truncates toward zero. This is
## not a matrix inverse and int32 overflow is not generalised.
@warning_ignore("integer_division")
static func screen_to_world(handler: Vector2i, origin: Vector2i) -> Vector2i:
	var a: int = handler.x + HELPER_OFFSET
	var b: int = handler.y + HELPER_OFFSET
	var q: int = (b + 1 + a / 2) / 24
	var k: int = (((a - 2 * b) & ~1) + 4846) / 48
	var side: int = 1 if a >= 24 * (q - 100 + k) else 0
	return Vector2i((origin.x + 2 * k - 200 + side) & ~1, origin.y + q)

## Move request from a path: at least two points, at most 50 directions (wire 96h). The
## target coordinate is never added to the request and nothing here is a server decision.
static func directions_from_path(points: Array) -> Dictionary:
	if points.size() < 2:
		return {"status": "TOO_SHORT", "directions": []}
	var deltas: Array = []
	for i: int in range(points.size() - 1):
		var step: Vector2i = (points[i + 1] as Vector2i) - (points[i] as Vector2i)
		var found: int = -1
		for d: int in 8:
			if step == preload("res://scripts/original_client/terrain_collision.gd").DIRECTION_DELTAS[d]:
				found = d
		if found < 0:
			return {"status": "NON_ADJACENT_STEP", "directions": [], "at_index": i}
		deltas.append(found)
	var truncated: bool = deltas.size() > MAX_DIRECTIONS
	return {"status": "OK", "directions": deltas.slice(0, MAX_DIRECTIONS), "truncated_to_50": truncated, "target_field_added": false}
