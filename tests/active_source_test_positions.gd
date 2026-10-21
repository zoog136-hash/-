extends RefCounted
## Test-only positions selected from active source/PNG spawn cells. No map edits.
static func _fits(f: PlayableField, p: Vector2, offsets: Array) -> bool:
	if not p.is_finite() or not f.walkable(p) or not f.point_clear(p) or f.is_safe(p): return false
	if f is NativePngField and not _native_portal_clear(f,p,p): return false
	for value: Variant in offsets:
		if not value is Vector2: return false
		var q: Vector2 = p + value
		if not q.is_finite() or not f.walkable(q) or not f.point_clear(q) or f.is_safe(q): return false
		if not f.line_clear(p,q): return false
		if f is NativePngField and not _native_portal_clear(f,p,q): return false
	return true

static func _native_portal_clear(f: NativePngField, from: Vector2, to: Vector2) -> bool:
	# Gameplay fixtures keep portals live. Avoid their actual trigger area,
	# including the actor foot, instead of suppressing a legitimate transition.
	for portal: Dictionary in f.data.get("portal",[]):
		var position: Array = portal.get("position",[])
		if position.size()!=2: continue
		var point := Vector2(float(position[0]),float(position[1]))
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point,from,to)
		if nearest.distance_to(point)<=float(portal.get("radius",18.0))+4.0: return false
	return true

static func combat(world: Node, offsets: Array = [Vector2(30,0)], motion_distance: float = 0.0) -> Vector2:
	var f: PlayableField = world.get("field_map") as PlayableField
	if f == null: return Vector2.INF
	if f is RemakePlayableField:
		for region: Dictionary in f.data.get("monster_spawn",[]):
			var cells: PackedInt32Array = PackedInt32Array(region.get("source_cells",[]))
			if cells.is_empty(): continue
			var stride: int = maxi(1,ceili(float(cells.size()) / 768.0))
			for i: int in range(0,cells.size(),stride):
				var flat: int = cells[i]
				var p: Vector2 = f.cell_to_world(Vector2i(flat % f.width,flat / f.width))
				if _fits(f,p,offsets): return p
		return Vector2.INF
	if f is NativePngField:
		# The PNG canvas is much larger than its reviewed combat floors. Search
		# the actual reachable population candidates, not stale world coordinates.
		for region: Dictionary in f.data.get("monster_spawn",[]):
			var cells: Array[Vector2i] = f.spawn_cells.get(str(region.id),[])
			var stride: int = maxi(1,ceili(float(cells.size()) / 768.0))
			for i: int in range(0,cells.size(),stride):
				var p: Vector2 = f.cell_to_world(cells[i])
				if _fits(f,p,offsets) and _native_motion_fits(f,p,offsets,motion_distance): return p
		# Clear pixels need not coincide with the 16px navigation-cell centre.
		# Refine the same reachable candidates without changing the requested
		# footprint, safe-zone checks, or each full line-of-sight segment.
		var refined: Vector2 = _native_subcell_combat(f,offsets,motion_distance)
		if refined.is_finite(): return refined
		return Vector2.INF
	var player: Node2D = world.get("player") as Node2D
	for p: Vector2 in [player.global_position if player!=null else Vector2.INF,Vector2(3550,4300)]:
		if _fits(f,p,offsets): return p
	return Vector2.INF

static func _native_motion_fits(f: NativePngField, point: Vector2, offsets: Array, distance: float) -> bool:
	if distance<=0.0: return true
	# Native actors have a circular 4px foot. Centre-cell LOS alone does not
	# prove that foot can pass a neighbouring raster collision rectangle.
	for value: Vector2 in offsets:
		var motion: Vector2 = value.normalized()*minf(value.length(),distance)
		var steps: int = maxi(1,ceili(motion.length()))
		for step: int in range(steps+1):
			var p: Vector2 = point+motion*float(step)/float(steps)
			if not f.point_clear(p,4.0): return false
			for direction: int in range(8):
				if not f.walkable(p+Vector2.from_angle(float(direction)*TAU/8.0)*4.0): return false
	return true

static func _native_subcell_combat(f: NativePngField, offsets: Array, motion_distance: float) -> Vector2:
	var low := Vector2.ZERO
	var high := Vector2.ZERO
	for value: Variant in offsets:
		if not value is Vector2: return Vector2.INF
		low = Vector2(minf(low.x,value.x),minf(low.y,value.y))
		high = Vector2(maxf(high.x,value.x),maxf(high.y,value.y))
	var half_cell: int = ceili(float(f.cell_size)*0.5)
	for region: Dictionary in f.data.get("monster_spawn",[]):
		var box: Array = region.get("rect",[])
		if box.size()!=4: continue
		# Only regions large enough for the requested offsets need refinement.
		var size := Vector2(float(box[2]),float(box[3]))-(high-low)
		if size.x<0.0 or size.y<0.0: continue
		var centres := Rect2(Vector2(float(box[0]),float(box[1]))-low,size).grow(half_cell)
		var cells: Array[Vector2i] = f.spawn_cells.get(str(region.id),[])
		var stride: int = maxi(1,ceili(float(cells.size()) / 768.0))
		for i: int in range(0,cells.size(),stride):
			var centre: Vector2 = f.cell_to_world(cells[i])
			if not centres.has_point(centre): continue
			for dx: int in range(-half_cell,half_cell+1):
				for dy: int in range(-half_cell,half_cell+1):
					var point: Vector2 = centre+Vector2(dx,dy)
					if _fits(f,point,offsets) and _native_motion_fits(f,point,offsets,motion_distance): return point
	return Vector2.INF

static func blocked_edge(world: Node) -> Array[Vector2]:
	var f: PlayableField = world.get("field_map") as PlayableField
	var empty: Array[Vector2] = []
	if not f is RemakePlayableField: return empty
	for region: Dictionary in f.data.get("monster_spawn",[]):
		var cells: PackedInt32Array = PackedInt32Array(region.get("source_cells",[]))
		if cells.is_empty(): continue
		var stride: int = maxi(1,ceili(float(cells.size()) / 768.0))
		for i: int in range(0,cells.size(),stride):
			var flat: int = cells[i]
			var c: Vector2i = Vector2i(flat % f.width,flat / f.width)
			var a: Vector2 = f.cell_to_world(c)
			if not f.point_clear(a): continue
			for delta: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var b: Vector2 = f.cell_to_world(c+delta)
				if f.point_clear(b) and not f.line_clear(a,b):
					var result: Array[Vector2] = [a,b]
					return result
	return empty

## The 2026 A3 4.map sha256 c22aa61e... has 8-neighbour-disconnected
## original source components. Both coordinates are passable, non-safe and
## 259.6 pixels apart; no invented blockers or map changes are permitted.
static func disconnected_pair(world: Node) -> Array[Vector2]:
	var f: PlayableField = world.get("field_map") as PlayableField
	var empty: Array[Vector2] = []
	if not f is RemakePlayableField: return empty
	if str((f as RemakePlayableField).definition.get("source_sha256","")) != "c22aa61ed083a3680230c659202503d7afaef30cb41b86d4655e9f843c81a7c4": return empty
	var p: Vector2 = f.cell_to_world(Vector2i(725,658))
	var q: Vector2 = f.cell_to_world(Vector2i(719,670))
	if not f.point_clear(p) or not f.point_clear(q) or f.is_safe(p) or f.is_safe(q): return empty
	if p.distance_to(q) < 80.0 or p.distance_to(q) > 460.0: return empty
	if not f.path(p,q).is_empty(): return empty
	return [p,q]
