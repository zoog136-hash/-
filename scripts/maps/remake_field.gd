extends "res://scripts/maps/source_field.gd"
class_name RemakePlayableField
## The original bytes stay immutable. Gameplay zones are TWILIGHT adaptations.
var region_cells: Dictionary = {}
var collision_stream: StaticBody2D
var reservations: Array[Dictionary] = []

func uses_original_gameplay_rules() -> bool:
	# Only the terrain comes from A3. Current TWILIGHT travel/NPC services
	# remain current gameplay, rather than inheriting unrelated PC server rules.
	return false

func configure_source(value: Dictionary) -> bool:
	if not value.get("remake_gameplay") is Dictionary or not super.configure_source(value): return false
	var gameplay: Dictionary = value.remake_gameplay
	for key: String in ["npc_spawn","monster_spawn","portal"]:
		if not gameplay.get(key) is Array: return false
		data[key] = gameplay[key].duplicate(true)
	data.short_name = str(value.map_name)
	reservations.clear()
	region_cells.clear()
	reservations.append(gameplay.entry_exclusion)
	for npc: Dictionary in data.npc_spawn: reservations.append({"center":npc.position,"radius":64.0})
	for portal: Dictionary in data.portal: reservations.append({"center":portal.position,"radius":64.0})
	for region: Dictionary in data.monster_spawn:
		var cells := PackedInt32Array(region.get("source_cells",[]))
		if cells.is_empty(): return false
		region_cells[str(region.id)] = cells
		region["layout_revision"] = int(value.layout_revision)
	return true

func can_step(c: Vector2i, heading: int) -> bool:
	if not super.can_step(c,heading): return false
	if heading % 2 == 0: return true
	var offset: Vector2i = DIRECTIONS[heading]
	var hx: int = 2 if offset.x > 0 else 6
	var hy: int = 4 if offset.y > 0 else 0
	return super.can_step(c,hx) and super.can_step(c,hy) and super.can_step(c+Vector2i(offset.x,0),hy) and super.can_step(c+Vector2i(0,offset.y),hx)

func remake_region_contains(id: String, point: Vector2) -> bool:
	if not point.is_finite() or not region_cells.has(id): return false
	var cell: Vector2i = world_to_cell(point)
	if not in_bounds(cell): return false
	var cells: PackedInt32Array = region_cells[id]
	var flat: int = cell.y*width+cell.x
	var at: int = cells.bsearch(flat)
	return at < cells.size() and cells[at] == flat

func sample_spawn(id: String, random: RandomNumberGenerator) -> Vector2:
	var cells: PackedInt32Array = region_cells.get(id,PackedInt32Array())
	if cells.is_empty(): return Vector2.INF
	for attempt: int in range(96):
		var flat: int = cells[random.randi_range(0,cells.size()-1)]
		var p: Vector2 = cell_to_world(Vector2i(flat%width,flat/width))
		if walkable(p) and point_clear(p,4.0) and not is_safe(p): return p
	return Vector2.INF

func spawn_contains(region: Dictionary, p: Vector2) -> bool:
	return remake_region_contains(str(region.id),p)

func navigation_search_limit() -> int:
	# The winding 5F corridors legitimately exceed the old 8192 visited-cell
	# budget. Search the finite floor graph, preserving every blocked edge.
	return mini(width*height,65536)

func is_safe(p: Vector2) -> bool:
	if super.is_safe(p): return true
	for reservation: Dictionary in reservations:
		var center := Vector2(reservation.center[0],reservation.center[1])
		if p.distance_squared_to(center) < pow(float(reservation.radius),2): return true
	return false

func point_clear(p: Vector2, padding: float = 4.0) -> bool:
	if not walkable(p): return false
	# The feet use a small circle in this 48x24 source grid; character art and
	# animation anchors are unchanged. Match the exact physical radius.
	var radius: float = minf(padding,4.0)
	var cell: Vector2i = world_to_cell(p)
	for dy: int in range(-1,2):
		for dx: int in range(-1,2):
			var c: Vector2i = cell+Vector2i(dx,dy)
			if value_at(c,true)==0: continue
			for heading: int in [0,2,4,6]:
				if can_step(c,heading): continue
				var edge: PackedVector2Array = coordinates.edge_points(c,heading)
				if Geometry2D.get_closest_point_to_segment(p,edge[0],edge[1]).distance_to(p) < radius: return false
	return true

func build_physics(parent: Node2D) -> StaticBody2D:
	var body := preload("res://scripts/maps/remake_collision_stream.gd").new()
	body.source = self
	body.actor = parent.get_node("Player")
	parent.add_child(body)
	collision_stream = body
	return body

func close() -> void:
	region_cells.clear()
	super.close()
