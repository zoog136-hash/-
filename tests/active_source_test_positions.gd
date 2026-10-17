extends RefCounted
## Test-only positions selected from verified A3 spawn cells. No source edits.
static func _fits(f: PlayableField, p: Vector2, offsets: Array) -> bool:
	if not p.is_finite() or not f.walkable(p) or not f.point_clear(p) or f.is_safe(p): return false
	for value: Variant in offsets:
		if not value is Vector2: return false
		var q: Vector2 = p + value
		if not q.is_finite() or not f.walkable(q) or not f.point_clear(q) or f.is_safe(q): return false
		if not f.line_clear(p,q): return false
	return true

static func combat(world: Node, offsets: Array = [Vector2(30,0)]) -> Vector2:
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
	var player: Node2D = world.get("player") as Node2D
	for p: Vector2 in [player.global_position if player!=null else Vector2.INF,Vector2(3550,4300)]:
		if _fits(f,p,offsets): return p
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
