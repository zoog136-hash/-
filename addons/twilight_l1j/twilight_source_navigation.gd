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

func configure(map_id: int, size: Vector2i, origin: Vector2i, projection: Transform2D, raw_directory: String = "res://data/l1j/maps/raw") -> bool:
	loaded = false
	dimensions = Vector2i.ZERO
	attributes = ATTRIBUTES.new()
	coordinates = COORDINATES.new()
	if not coordinates.configure(size, origin, projection): return false
	if not attributes.load_a3(map_id, size, raw_directory): return false
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
	if start == goal: return [start]
	if max_nodes == 1: return result
	# A direct edge needs exactly two stored cells, regardless of neighbor order.
	var direct_heading: int = DIRECTIONS.find(goal-start)
	if direct_heading >= 0 and can_step(start,direct_heading): return [start,goal]
	# Unit-cost A* retains the source's shortest-step semantics. Chebyshev distance
	# is admissible for all eight headings, including blocked corner routes.
	var frontier: Array[Vector3i] = [Vector3i(start.x,start.y,_distance(start,goal))]
	var previous: Dictionary = {start:start}
	var costs: Dictionary = {start:0}
	while not frontier.is_empty():
		var entry: Vector3i = _pop_frontier(frontier,goal)
		var current := Vector2i(entry.x,entry.y)
		if entry.z != int(costs[current]) + _distance(current,goal): continue
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
			var cost: int = int(costs[current])+1
			if costs.has(next) and int(costs[next]) <= cost: continue
			# Once the budget is full, finish searching already stored cells. One
			# unrelated new neighbor must not discard a reachable queued goal.
			if not costs.has(next) and costs.size() >= max_nodes: continue
			previous[next] = current
			costs[next] = cost
			_push_frontier(frontier,Vector3i(next.x,next.y,cost+_distance(next,goal)),goal)
	return result

func _distance(cell: Vector2i, goal: Vector2i) -> int:
	return maxi(absi(cell.x-goal.x),absi(cell.y-goal.y))

func _earlier(left: Vector3i, right: Vector3i, goal: Vector2i) -> bool:
	if left.z != right.z: return left.z < right.z
	return _distance(Vector2i(left.x,left.y),goal) < _distance(Vector2i(right.x,right.y),goal)

func _push_frontier(frontier: Array[Vector3i], entry: Vector3i, goal: Vector2i) -> void:
	frontier.append(entry)
	var index: int = frontier.size()-1
	while index > 0:
		var parent: int = (index-1)/2
		if not _earlier(frontier[index],frontier[parent],goal): break
		var swap: Vector3i = frontier[parent]
		frontier[parent] = frontier[index]
		frontier[index] = swap
		index = parent

func _pop_frontier(frontier: Array[Vector3i], goal: Vector2i) -> Vector3i:
	var result: Vector3i = frontier[0]
	var last: Vector3i = frontier.pop_back()
	if frontier.is_empty(): return result
	frontier[0] = last
	var index: int = 0
	while index*2+1 < frontier.size():
		var child: int = index*2+1
		if child+1 < frontier.size() and _earlier(frontier[child+1],frontier[child],goal): child += 1
		if not _earlier(frontier[child],frontier[index],goal): break
		var swap: Vector3i = frontier[index]
		frontier[index] = frontier[child]
		frontier[child] = swap
		index = child
	return result
