extends RefCounted
class_name TwilightL1JSourceNavigation
## Source-only static edge graph, ported from A3 L1V1Map.checkMoveTile.
## Not a substitute for TWILIGHT's live body collision, dynamic objects or doors.
const ATTRIBUTES = preload("res://addons/twilight_l1j/twilight_map_attributes.gd")
const COORDINATES = preload("res://addons/twilight_l1j/twilight_tile_coordinates.gd")
const DIRECTIONS: Array[Vector2i] = [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
var attributes: TwilightL1JMapAttributes = ATTRIBUTES.new()
var coordinates: TwilightL1JTileCoordinates = COORDINATES.new()
var dimensions: Vector2i = Vector2i.ZERO
var loaded: bool = false

func configure(map_id: int, size: Vector2i, origin: Vector2i, projection: Transform2D) -> bool:
	loaded = false
	dimensions = Vector2i.ZERO
	attributes = ATTRIBUTES.new()
	coordinates = COORDINATES.new()
	if not coordinates.configure(size, origin, projection): return false
	if not attributes.load_a3(map_id, size): return false
	dimensions = size
	loaded = true
	return true

func _value(cell: Vector2i) -> int:
	return attributes.attribute_at(cell) if coordinates.in_bounds(cell) else 0

func can_step(cell: Vector2i, heading: int) -> bool:
	if not loaded or heading < 0 or heading >= 8 or not coordinates.in_bounds(cell): return false
	var next: Vector2i = cell + DIRECTIONS[heading]
	if not coordinates.in_bounds(next): return false
	var first: int = _value(cell)
	var second: int = _value(next)
	match heading:
		0: return (first & 2) == 2
		1: return ((first & 2) == 2 and (_value(cell+Vector2i(0,-1)) & 1) == 1) or ((first & 1) == 1 and (_value(cell+Vector2i(1,0)) & 2) == 2)
		2: return (first & 1) == 1
		3: return (_value(cell+Vector2i(0,1)) & 3) == 3 or ((first & 1) == 1 and (second & 2) == 2)
		4: return (second & 2) == 2
		5: return ((second & 1) == 1 and (_value(cell+Vector2i(0,1)) & 2) == 2) or ((second & 2) == 2 and (_value(cell+Vector2i(-1,0)) & 1) == 1)
		6: return (second & 1) == 1
		7: return (_value(cell+Vector2i(-1,0)) & 3) == 3 or ((first & 2) == 2 and (second & 1) == 1)
	return false

func find_path(start: Vector2i, goal: Vector2i, max_nodes: int = 8192) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not loaded or not coordinates.in_bounds(start) or not coordinates.in_bounds(goal) or max_nodes < 1: return result
	max_nodes = mini(max_nodes, 65536)
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start:start}
	var read: int = 0
	while read < queue.size():
		var current: Vector2i = queue[read]
		read += 1
		if current == goal:
			result.append(current)
			while current != start:
				current = previous[current]
				result.append(current)
			result.reverse()
			return result
		for heading: int in range(8):
			if not can_step(current, heading): continue
			var next: Vector2i = current + DIRECTIONS[heading]
			if previous.has(next): continue
			if queue.size() >= max_nodes: return []
			previous[next] = current
			queue.append(next)
	return result
