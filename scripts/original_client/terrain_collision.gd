extends RefCounted
## C13 / P3. DESIGN_NOT_RECOVERED_API. Half-cell direction steps and terrain rejection.
## A reject value of true means BLOCKED. TI2 picture flags are not collision.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const STRIDE := 256
const ATTR_LIMIT := 32768
const DIRECTION_DELTAS := [Vector2i(0, -1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 1), Vector2i(-2, 1), Vector2i(-2, 0), Vector2i(-2, -1)]
const OFFSET_A0 := [0, 0, 1, 1, 256, 256, -1, -1]
const OFFSET_A1 := [0, -255, 0, 258, 0, 255, 0, -2]
const OFFSET_A2 := [0, 1, 0, 256, 0, -1, 0, -257]
const OFFSET_A3 := [0, 2, 0, 257, 0, 254, 0, 0]

static func direction_step(point: Vector2i, direction: int) -> Vector2i:
	return point + DIRECTION_DELTAS[direction & 7]

## reject = (attr & 0x0001 != 0) AND (NOT allow40 OR (attr & 0x0040) == 0).
static func reject_attr(attr: int, allow40: bool) -> bool:
	return ((attr & 0x0001) != 0) and ((not allow40) or ((attr & 0x0040) == 0))

## Odd directions read four cells: (r0 OR r1) AND (r2 OR r3).
static func odd_direction_pair(rejects: Array) -> bool:
	return (bool(rejects[0]) or bool(rejects[1])) and (bool(rejects[2]) or bool(rejects[3]))

static func base_index(point: Vector2i, origin: Vector2i) -> int:
	return (point.y - origin.y) * STRIDE + point.x - origin.x

static func cell_indices(point: Vector2i, origin: Vector2i, direction: int) -> Array:
	var d: int = direction & 7
	var base: int = base_index(point, origin)
	if d % 2 == 0:
		return [base + OFFSET_A0[d]]
	return [base + OFFSET_A0[d], base + OFFSET_A1[d], base + OFFSET_A2[d], base + OFFSET_A3[d]]

## An unsigned index >= 32768 (including any negative index) reads as attribute 1.
static func attribute_at(attributes: Array, index: int) -> int:
	if VOCAB.u32(index) >= ATTR_LIMIT or index >= attributes.size():
		return 1
	return int(attributes[index])

## CollisionResult: the reject bool together with its cause and source branch.
static func check_step(attributes: Array, point: Vector2i, origin: Vector2i, direction: int, allow40: bool) -> Dictionary:
	var indices: Array = cell_indices(point, origin, direction)
	var rejects: Array = []
	for index: int in indices:
		rejects.append(reject_attr(attribute_at(attributes, index), allow40))
	var odd: bool = (direction & 1) == 1
	var blocked: bool = odd_direction_pair(rejects) if odd else bool(rejects[0])
	return {"reject": blocked, "branch": "odd_pair_of_four" if odd else "even_single_cell", "indices": indices, "rejects": rejects,
		"cause": "attribute_bit0" if blocked else ""}

## DESIGN nearest-path search over half-cells (breadth first, bounded). The original path
## core is not recovered; this only produces a usable path for offline intent tests. Start ==
## target is success with an empty output, which is not a failure.
static func plan_path(start: Vector2i, target: Vector2i, attributes: Array, origin: Vector2i, allow40: bool, node_limit: int = 4096) -> Dictionary:
	if start == target:
		return {"status": "OK", "points": [], "design_pathfinder": true}
	var came: Dictionary = {start: start}
	var queue: Array = [start]
	var head: int = 0
	while head < queue.size() and came.size() <= node_limit:
		var current: Vector2i = queue[head]
		head += 1
		for direction: int in 8:
			var next: Vector2i = direction_step(current, direction)
			if came.has(next):
				continue
			if check_step(attributes, current, origin, direction, allow40).reject:
				continue
			came[next] = current
			if next == target:
				var path: Array = [next]
				var at: Vector2i = next
				while at != start:
					at = came[at]
					path.push_front(at)
				return {"status": "OK", "points": path, "design_pathfinder": true}
			queue.append(next)
	return {"status": "NO_PATH_WITHIN_LIMIT", "points": [], "design_pathfinder": true}
