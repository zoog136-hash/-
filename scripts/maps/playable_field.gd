extends RefCounted
class_name PlayableField

const COORD = preload("res://scripts/maps/world_coordinates.gd")
var data: Dictionary
var bounds: Rect2
var cell_size: int = 32
var clearance: float = 47.0
var astar: AStarGrid2D
var blockers: Array = []
var spawn_cells: Dictionary = {}
var reachable: PackedByteArray
var width: int
var height: int

func configure(definition: Dictionary) -> void:
	data = definition
	var b: Array = data["bounds"]
	bounds = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
	cell_size = int(data["navigation"]["cell_size"])
	clearance = float(data["navigation"]["clearance"])
	width = ceili(bounds.size.x / cell_size)
	height = ceili(bounds.size.y / cell_size)
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2.ONE * cell_size
	astar.offset = bounds.position + Vector2.ONE * cell_size * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	blockers.clear()
	for raw: Dictionary in data["collision"]:
		var shape: Dictionary = raw.duplicate(true)
		var box: Rect2
		match str(shape["shape"]):
			"circle":
				shape["vcenter"] = COORD.array_vector(shape["center"])
				var r: float = float(shape["radius"])
				box = Rect2(shape["vcenter"] - Vector2.ONE * r, Vector2.ONE * r * 2.0)
			"rect":
				var a: Array = shape["rect"]
				box = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
				shape["vrect"] = box
			"polygon":
				var poly: PackedVector2Array = PackedVector2Array()
				for p: Array in shape["points"]:
					poly.append(COORD.array_vector(p))
				shape["polygon"] = poly
				box = Rect2(poly[0], Vector2.ZERO)
				for p: Vector2 in poly:
					box = box.expand(p)
		shape["box"] = box
		blockers.append(shape)
		var lo: Vector2i = world_to_cell(box.position - Vector2.ONE * clearance)
		var hi: Vector2i = world_to_cell(box.end + Vector2.ONE * clearance)
		for y: int in range(maxi(0, lo.y), mini(height - 1, hi.y) + 1):
			for x: int in range(maxi(0, lo.x), mini(width - 1, hi.x) + 1):
				var cell := Vector2i(x, y)
				if _inside_shape(cell_to_world(cell), shape, clearance):
					astar.set_point_solid(cell)
	_build_reachability()
	spawn_cells.clear()
	for region: Dictionary in data.get("monster_spawn", []):
		var a: Array = region["rect"]
		var box := Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
		var cells: Array[Vector2i] = []
		var lo: Vector2i = world_to_cell(box.position)
		var hi: Vector2i = world_to_cell(box.end)
		for y: int in range(maxi(0, lo.y), mini(height, hi.y)):
			for x: int in range(maxi(0, lo.x), mini(width, hi.x)):
				var cell := Vector2i(x, y)
				if reachable[y * width + x] != 0 and not is_safe(cell_to_world(cell)):
					cells.append(cell)
		spawn_cells[str(region["id"])] = cells

func _inside_shape(p: Vector2, shape: Dictionary, padding: float) -> bool:
	if not (shape["box"] as Rect2).grow(padding).has_point(p):
		return false
	match str(shape["shape"]):
		"circle":
			return p.distance_squared_to(shape["vcenter"]) <= pow(float(shape["radius"]) + padding, 2)
		"rect":
			return (shape["vrect"] as Rect2).grow(padding).has_point(p)
		"polygon":
			var poly: PackedVector2Array = shape["polygon"]
			if Geometry2D.is_point_in_polygon(p, poly):
				return true
			for i: int in range(poly.size()):
				if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_squared_to(p) <= padding * padding:
					return true
	return false

func point_clear(p: Vector2, padding: float = 24.0) -> bool:
	if not bounds.grow(-padding).has_point(p):
		return false
	for shape: Dictionary in blockers:
		if _inside_shape(p, shape, padding):
			return false
	return true

func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(((p - bounds.position) / cell_size).floor())

func cell_to_world(cell: Vector2i) -> Vector2:
	return bounds.position + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size

func walkable(p: Vector2) -> bool:
	var cell: Vector2i = world_to_cell(p)
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)

func nearest_cell(p: Vector2) -> Vector2i:
	var c: Vector2i = world_to_cell(p)
	if not astar.is_in_boundsv(c):
		return Vector2i(-1, -1)
	if not astar.is_point_solid(c):
		return c
	for r: int in range(1, 18):
		var best := Vector2i(-1, -1)
		var distance: float = INF
		for y: int in range(c.y - r, c.y + r + 1):
			for x: int in range(c.x - r, c.x + r + 1):
				if absi(x - c.x) != r and absi(y - c.y) != r:
					continue
				var candidate := Vector2i(x, y)
				if astar.is_in_boundsv(candidate) and not astar.is_point_solid(candidate):
					var d: float = cell_to_world(candidate).distance_squared_to(p)
					if d < distance:
						best = candidate
						distance = d
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start: Vector2i = nearest_cell(from)
	var goal: Vector2i = nearest_cell(to)
	if start.x < 0 or goal.x < 0:
		return PackedVector2Array()
	if reachable[start.y * width + start.x] == 0 or reachable[goal.y * width + goal.x] == 0:
		return PackedVector2Array()
	var cells: Array[Vector2i] = astar.get_id_path(start, goal)
	var points := PackedVector2Array()
	# Keep turns, remove only collinear interior points. Never cut an obstacle corner.
	for i: int in range(cells.size()):
		if i > 0 and i < cells.size() - 1 and cells[i] - cells[i - 1] == cells[i + 1] - cells[i]:
			continue
		points.append(cell_to_world(cells[i]))
	# Replanning a moving target must not pull an actor back to its cell center.
	if points.size() > 1 and line_clear(from,points[1]):
		points.remove_at(0)
	if not points.is_empty() and walkable(to):
		points.append(to)
	return points

func line_clear(from: Vector2, to: Vector2) -> bool:
	var steps: int = maxi(1, ceili(from.distance_to(to) / 10.0))
	var last: Vector2i = world_to_cell(from)
	for i: int in range(steps + 1):
		var p: Vector2 = from.lerp(to, float(i) / steps)
		if not walkable(p):
			return false
		var c: Vector2i = world_to_cell(p)
		if c.x != last.x and c.y != last.y:
			if astar.is_point_solid(Vector2i(c.x, last.y)) or astar.is_point_solid(Vector2i(last.x, c.y)):
				return false
		last = c
	return true

func _build_reachability() -> void:
	reachable = PackedByteArray()
	reachable.resize(width * height)
	var start: Vector2i = nearest_cell(COORD.array_vector(data["spawn_position"]))
	if start.x < 0:
		return
	var queue: Array[Vector2i] = [start]
	reachable[start.y * width + start.x] = 1
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if not astar.is_in_boundsv(next) or astar.is_point_solid(next):
				continue
			var key: int = next.y * width + next.x
			if reachable[key] == 0:
				reachable[key] = 1
				queue.append(next)

func sample_spawn(region_id: String, random: RandomNumberGenerator) -> Vector2:
	var cells: Array = spawn_cells.get(region_id, [])
	if cells.is_empty():
		return Vector2.INF
	return cell_to_world(cells[random.randi_range(0, cells.size() - 1)])

func region_at(p: Vector2) -> Dictionary:
	for region: Dictionary in data.get("regions", []):
		if p.distance_to(COORD.array_vector(region["center"])) <= float(region["radius"]):
			return region
	return {"id":"frontier", "name":"아덴 변경", "type":"combat"}

func is_safe(p: Vector2) -> bool:
	return str(region_at(p).get("type", "")) == "safe"

func build_physics(parent: Node2D) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "FieldCollision"
	body.collision_layer = 4
	body.collision_mask = 0
	parent.add_child(body)
	for shape: Dictionary in blockers:
		if str(shape["shape"]) == "polygon":
			var polygon := CollisionPolygon2D.new()
			polygon.polygon = shape["polygon"]
			body.add_child(polygon)
		else:
			var node := CollisionShape2D.new()
			if str(shape["shape"]) == "circle":
				var circle := CircleShape2D.new()
				circle.radius = float(shape["radius"])
				node.shape = circle
				node.position = shape["vcenter"]
			else:
				var rectangle := RectangleShape2D.new()
				var box: Rect2 = shape["vrect"]
				rectangle.size = box.size
				node.shape = rectangle
				node.position = box.get_center()
			body.add_child(node)
	return body
