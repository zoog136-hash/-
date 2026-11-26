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

class PathSearch extends RefCounted:
	var start: Vector2i
	var goal: Vector2i
	var max_nodes: int
	var frontier: Array[Vector4i] = []
	var visited: Dictionary[Vector2i, Vector3i] = {}
	var result: Array[Vector2i] = []
	var done: bool = false

func find_path(start: Vector2i, goal: Vector2i, max_nodes: int = 8192) -> Array[Vector2i]:
	var search := begin_search(start,goal,max_nodes)
	advance_search(search)
	return search.result

func begin_search(start: Vector2i, goal: Vector2i, max_nodes: int) -> PathSearch:
	var search := PathSearch.new()
	search.start = start
	search.goal = goal
	search.max_nodes = mini(max_nodes,65536)
	search.done = true
	if not loaded or not coordinates.in_bounds(start) or not coordinates.in_bounds(goal) or max_nodes < 1: return search
	if start == goal:
		search.result = [start]
		return search
	if max_nodes == 1: return search
	var direct_heading: int = DIRECTIONS.find(goal-start)
	if direct_heading >= 0 and can_step(start,direct_heading):
		search.result = [start,goal]
		return search
	# Preserve the production heap's exact cached (f,h) ordering and store.
	var h: int = _distance(start,goal)
	search.frontier.append(Vector4i(start.x,start.y,h,h))
	search.visited[start] = Vector3i(start.x,start.y,0)
	search.done = false
	return search

## One heap pop is indivisible. With no deadline/cap this is the original
## synchronous search used by manual routes and all other callers.
func advance_search(search: PathSearch, deadline_usec: int = -1, max_pops: int = -1) -> bool:
	if search.done: return true
	var start: Vector2i = search.start
	var goal: Vector2i = search.goal
	var max_nodes: int = search.max_nodes
	var frontier: Array[Vector4i] = search.frontier
	var visited: Dictionary[Vector2i, Vector3i] = search.visited
	var result: Array[Vector2i] = search.result
	var pops: int = 0
	while not frontier.is_empty():
		if pops > 0 and ((deadline_usec >= 0 and Time.get_ticks_usec() >= deadline_usec) or (max_pops >= 0 and pops >= max_pops)): return false
		pops += 1
		var entry: Vector4i = _pop_frontier(frontier)
		var current := Vector2i(entry.x,entry.y)
		var record: Vector3i = visited[current]
		if entry.z != record.z + entry.w: continue
		if current == goal:
			result.append(current)
			while current != start:
				var parent: Vector3i = visited[current]
				current = Vector2i(parent.x,parent.y)
				result.append(current)
			result.reverse()
			break
		var cost: int = record.z + 1
		for heading: int in range(8):
			var next: Vector2i = current + DIRECTIONS[heading]
			var existing: Vector3i = visited.get(next, Vector3i(0,0,-1))
			var known_cost: int = existing.z
			if known_cost >= 0 and known_cost <= cost: continue
			# A full budget can still reach a goal already queued. Skip terrain
			# lookups for edges that cannot add or improve any stored route.
			if known_cost < 0 and visited.size() >= max_nodes: continue
			if not can_step(current, heading): continue
			visited[next] = Vector3i(current.x,current.y,cost)
			var h: int = _distance(next,goal)
			_push_frontier(frontier,Vector4i(next.x,next.y,cost+h,h))
	search.done = true
	return true

func _distance(cell: Vector2i, goal: Vector2i) -> int:
	return maxi(absi(cell.x-goal.x),absi(cell.y-goal.y))

func _push_frontier(frontier: Array[Vector4i], entry: Vector4i) -> void:
	frontier.append(entry)
	var index: int = frontier.size()-1
	while index > 0:
		var parent: int = (index-1)/2
		var above: Vector4i = frontier[parent]
		if entry.z > above.z or (entry.z == above.z and entry.w >= above.w): break
		frontier[index] = above
		index = parent
	frontier[index] = entry

func _pop_frontier(frontier: Array[Vector4i]) -> Vector4i:
	var result: Vector4i = frontier[0]
	var last: Vector4i = frontier.pop_back()
	if frontier.is_empty(): return result
	var index: int = 0
	var count: int = frontier.size()
	while index*2+1 < count:
		var child: int = index*2+1
		var below: Vector4i = frontier[child]
		if child+1 < count:
			var right: Vector4i = frontier[child+1]
			if right.z < below.z or (right.z == below.z and right.w < below.w):
				below = right
				child += 1
		if below.z > last.z or (below.z == last.z and below.w >= last.w): break
		frontier[index] = below
		index = child
	frontier[index] = last
	return result
