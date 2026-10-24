extends StaticBody2D
## One batched concave segment shape per nearby chunk, never one body per tile.
const CHUNK_SIZE: int = 32
var source: RemakePlayableField
var actor: Node2D
var chunks: Dictionary = {}
var last_cell := Vector2i(-999,-999)
var last_doors: Dictionary = {}
var clock: float = 0.0

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

func refresh() -> void:
	if not is_instance_valid(actor) or source == null: return
	var c: Vector2i = source.world_to_cell(actor.global_position)
	var center := Vector2i(floori(float(c.x)/CHUNK_SIZE),floori(float(c.y)/CHUNK_SIZE))
	var doors_changed: bool = last_doors != source.source_doors.opened
	if center == last_cell and not doors_changed: return
	last_cell = center
	last_doors = source.source_doors.opened.duplicate()
	var needed: Dictionary = {}
	for dy: int in range(-1,2):
		for dx: int in range(-1,2):
			var key: Vector2i = center+Vector2i(dx,dy)
			if key.x < 0 or key.y < 0 or key.x*CHUNK_SIZE >= source.width or key.y*CHUNK_SIZE >= source.height: continue
			needed[key] = true
			if chunks.has(key) and not doors_changed: continue
			if chunks.has(key): remove_child(chunks[key]); chunks[key].queue_free(); chunks.erase(key)
			var segments := PackedVector2Array()
			for y: int in range(key.y*CHUNK_SIZE,mini((key.y+1)*CHUNK_SIZE,source.height)):
				for x: int in range(key.x*CHUNK_SIZE,mini((key.x+1)*CHUNK_SIZE,source.width)):
					var cell := Vector2i(x,y)
					if source.value_at(cell,true)==0: continue
					for heading: int in [0,2,4,6]:
						if source.source_can_step(cell,heading): continue
						var next: Vector2i = cell+source.DIRECTIONS[heading]
						if source.value_at(next,true)!=0 and (next.y<y or (next.y==y and next.x<x)): continue
						segments.append_array(source.coordinates.edge_points(cell,heading))
			var node := CollisionShape2D.new()
			var shape := ConcavePolygonShape2D.new()
			shape.segments = segments
			node.shape = shape
			add_child(node)
			chunks[key] = node
	for key: Vector2i in chunks.keys():
		if not needed.has(key): remove_child(chunks[key]); chunks[key].queue_free(); chunks.erase(key)
