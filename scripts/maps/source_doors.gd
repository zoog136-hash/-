extends RefCounted
## A3 L1DoorInstance.isPassibleDoor and GameSystem/astar/World.isDoorMove.
var flags: Dictionary = {}
var records: Dictionary = {}
var opened: Dictionary = {}
var origin := Vector2i.ZERO
func configure(rows: Array, source_origin: Vector2i) -> void:
	records.clear()
	opened.clear()
	origin = source_origin
	for row: Dictionary in rows:
		records[int(row.id)] = row
		opened[int(row.id)] = int(row.id) in [225,226,227]
	_rebuild()
func set_open(id: int, value: bool) -> void:
	if not records.has(id): return
	opened[id] = value
	_rebuild()
func _rebuild() -> void:
	flags.clear()
	for id: int in records:
		if opened[id]: continue
		var row: Dictionary = records[id]
		var direction: int = int(row.direction)
		var x: int = int(row.locx) - (0 if direction == 0 else 1)
		var y: int = int(row.locy) + (1 if direction == 0 else 0)
		if id in [2010,225,226]: y -= 1
		for edge: int in range(int(row.left_edge_location),int(row.right_edge_location)+1):
			var cell: Vector2i = (Vector2i(edge,y) if direction in [0,4] else Vector2i(x,edge)) - origin
			flags[cell] = int(flags.get(cell,0)) | (64 if direction in [0,4] else 128)
func blocked(a: Vector2i, b: Vector2i) -> bool:
	if a.x > b.x and ((_flag(Vector2i(b.x,a.y)) | _flag(b)) & 128): return true
	if a.x < b.x and ((_flag(a) | _flag(Vector2i(b.x-1,b.y))) & 128): return true
	if a.y < b.y and ((_flag(Vector2i(a.x,b.y)) | _flag(b)) & 64): return true
	if a.y > b.y and ((_flag(a) | _flag(Vector2i(b.x,b.y+1))) & 64): return true
	return false
func _flag(cell: Vector2i) -> int: return int(flags.get(cell,0))
