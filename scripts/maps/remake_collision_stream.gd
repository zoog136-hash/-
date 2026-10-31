extends StaticBody2D
## One batched concave segment shape per nearby chunk, never one body per tile.
const CHUNK_SIZE: int = 32
var source: RemakePlayableField
var actor: Node2D
var chunks: Dictionary = {}
var last_cell := Vector2i(-999,-999)
var last_doors: Dictionary = {}
var clock: float = 0.0
const NEAR_CELLS: int = 8
const FAR_ROWS_PER_FRAME: int = 2
var segment_cache: Dictionary = {}
var stale_chunks: Dictionary = {}
var needed_keys: Dictionary = {}
var far_queue: Array[Vector2i] = []
var far_job: Dictionary = {}

func add_png_review_footprints(footprints: RefCounted) -> void:
	# A small, explicitly reviewed set reuses this real terrain body. It never
	# overwrites streamed original segments or installs in an ordinary game.
	for polygon: PackedVector2Array in footprints.polygons:
		var shape := CollisionPolygon2D.new()
		shape.name = "ManualPngFootprint"
		shape.polygon = polygon
		add_child(shape)

func _ready() -> void:
	name = "SourceCollisionStream"
	collision_layer = 4
	collision_mask = 0
	refresh()

func _physics_process(delta: float) -> void:
	clock -= delta
	if clock <= 0:
		clock = 0.1
		refresh()
	_continue_far_build()

# Building one 32x32 chunk walks ~1,000 cells in GDScript (~70 ms on a desktop
# CPU) and crossing a chunk boundary needed 3-5 at once: a 150-300 ms hitch
# while walking or fighting. Built segments are now kept per chunk until a door
# changes; chunks within NEAR_CELLS of the actor are still built immediately,
# and farther ones are built a few rows per physics frame, then attached.
func refresh() -> void:
	if not is_instance_valid(actor) or source == null: return
	var c: Vector2i = source.world_to_cell(actor.global_position)
	var center := Vector2i(floori(float(c.x)/CHUNK_SIZE),floori(float(c.y)/CHUNK_SIZE))
	var doors_changed: bool = last_doors != source.source_doors.opened
	if center == last_cell and not doors_changed and not _near_chunk_missing(c): return
	last_cell = center
	last_doors = source.source_doors.opened.duplicate()
	if doors_changed:
		segment_cache.clear()
		far_queue.clear()
		far_job.clear()
		for key: Vector2i in chunks: stale_chunks[key] = true
	needed_keys.clear()
	for dy: int in range(-1,2):
		for dx: int in range(-1,2):
			var key: Vector2i = center+Vector2i(dx,dy)
			if key.x < 0 or key.y < 0 or key.x*CHUNK_SIZE >= source.width or key.y*CHUNK_SIZE >= source.height: continue
			needed_keys[key] = true
			if chunks.has(key) and not stale_chunks.has(key): continue
			if segment_cache.has(key) or _cell_distance_to_chunk(c,key) <= NEAR_CELLS:
				_attach(key,_chunk_segments(key))
			elif not far_queue.has(key) and far_job.get("key") != key:
				far_queue.append(key)
	for key: Vector2i in chunks.keys():
		if not needed_keys.has(key): remove_child(chunks[key]); chunks[key].queue_free(); chunks.erase(key); stale_chunks.erase(key)

func _near_chunk_missing(cell: Vector2i) -> bool:
	for key: Vector2i in needed_keys:
		if (not chunks.has(key) or stale_chunks.has(key)) and _cell_distance_to_chunk(cell,key) <= NEAR_CELLS: return true
	return false

func _attach(key: Vector2i, segments: PackedVector2Array) -> void:
	if chunks.has(key): remove_child(chunks[key]); chunks[key].queue_free(); chunks.erase(key)
	stale_chunks.erase(key)
	var node := CollisionShape2D.new()
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	node.shape = shape
	add_child(node)
	chunks[key] = node

func _continue_far_build() -> void:
	if far_job.is_empty():
		while not far_queue.is_empty():
			var next: Vector2i = far_queue.pop_front()
			if needed_keys.has(next) and (not chunks.has(next) or stale_chunks.has(next)):
				far_job = {"key":next,"y":next.y*CHUNK_SIZE,"segments":PackedVector2Array()}
				break
		if far_job.is_empty(): return
	var key: Vector2i = far_job.key
	var stop: int = mini(int(far_job.y)+FAR_ROWS_PER_FRAME,mini((key.y+1)*CHUNK_SIZE,source.height))
	var segments: PackedVector2Array = far_job.segments
	for y: int in range(int(far_job.y),stop): _append_row(key,y,segments)
	far_job.segments = segments
	far_job.y = stop
	if stop >= mini((key.y+1)*CHUNK_SIZE,source.height):
		_remember(key,segments)
		far_job.clear()
		if needed_keys.has(key) and (not chunks.has(key) or stale_chunks.has(key)): _attach(key,segments)

func _cell_distance_to_chunk(cell: Vector2i, key: Vector2i) -> int:
	var lo := key*CHUNK_SIZE
	var hi := lo+Vector2i(CHUNK_SIZE-1,CHUNK_SIZE-1)
	return maxi(maxi(lo.x-cell.x,cell.x-hi.x),maxi(lo.y-cell.y,cell.y-hi.y))

func _chunk_segments(key: Vector2i) -> PackedVector2Array:
	if segment_cache.has(key): return segment_cache[key]
	var segments := PackedVector2Array()
	for y: int in range(key.y*CHUNK_SIZE,mini((key.y+1)*CHUNK_SIZE,source.height)): _append_row(key,y,segments)
	_remember(key,segments)
	return segments

func _remember(key: Vector2i, segments: PackedVector2Array) -> void:
	if segment_cache.size() >= 64: segment_cache.clear()
	segment_cache[key] = segments

## Same cell/heading walk as before, one row of one chunk.
func _append_row(key: Vector2i, y: int, segments: PackedVector2Array) -> void:
	for x: int in range(key.x*CHUNK_SIZE,mini((key.x+1)*CHUNK_SIZE,source.width)):
		var cell := Vector2i(x,y)
		if source.value_at(cell,true)==0: continue
		for heading: int in [0,2,4,6]:
			if source.source_can_step(cell,heading): continue
			var next: Vector2i = cell+source.DIRECTIONS[heading]
			if source.value_at(next,true)!=0 and (next.y<y or (next.y==y and next.x<x)): continue
			segments.append_array(source.coordinates.edge_points(cell,heading))
