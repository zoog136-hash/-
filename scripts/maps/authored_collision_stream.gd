extends StaticBody2D
## Exact existing shapes, spatially streamed. Shape indices on a live bucket
## body never change: assemble it before registration, retire the whole body.
var field: PlayableField
var actor: Node2D
var buckets: Dictionary = {}
var bucket_bounds: Dictionary = {}
var chunks: Dictionary = {}
var active_shape_count: int = 0
var total_shape_count: int = 0
var freed_chunks: int = 0
var clock: float = 0.0
var chunk_size: float = 1024.0

func configure(value: PlayableField, player: Node2D) -> void:
	field=value;actor=player
	collision_layer=0;collision_mask=0
	chunk_size=float(field.data.streaming.chunk_size)
	for shape: Dictionary in field.blockers:
		var box: Rect2=shape.box
		var key:=Vector2i((box.get_center()/chunk_size).floor())
		if not buckets.has(key): buckets[key]=[];bucket_bounds[key]=box
		buckets[key].append(shape)
		bucket_bounds[key]=(bucket_bounds[key] as Rect2).merge(box)
		total_shape_count+=1

func _ready() -> void:
	name="AuthoredCollisionStream"
	refresh()

func _physics_process(delta: float) -> void:
	clock-=delta
	if clock<=0.0: clock=0.1;refresh()

func required_bounds() -> Rect2:
	# Include all awake actors and movement between refreshes, not just the
	# player's viewport. Large shapes retain their complete original extent.
	var radius: float=float(field.data.streaming.monster_sleep_distance)+maxf(128,field.clearance*2)
	return Rect2(actor.global_position-Vector2.ONE*radius,Vector2.ONE*radius*2)

func refresh() -> void:
	if field==null or not is_instance_valid(actor): return
	var area: Rect2=required_bounds()
	var needed: Dictionary={}
	for key: Vector2i in buckets:
		if not (bucket_bounds[key] as Rect2).intersects(area,true): continue
		needed[key]=true
		if chunks.has(key): continue
		var body:=StaticBody2D.new()
		body.name="CollisionBucket_%d_%d" % [key.x,key.y]
		body.collision_layer=4;body.collision_mask=0
		for shape: Dictionary in buckets[key]:
			if str(shape.shape)=="polygon":
				var polygon:=CollisionPolygon2D.new()
				polygon.polygon=shape.polygon
				body.add_child(polygon)
			else:
				var node:=CollisionShape2D.new()
				if str(shape.shape)=="circle":
					var circle:=CircleShape2D.new();circle.radius=float(shape.radius)
					node.shape=circle;node.position=shape.vcenter
				else:
					var rect:=RectangleShape2D.new();var box: Rect2=shape.vrect
					rect.size=box.size;node.shape=rect;node.position=box.get_center()
				body.add_child(node)
		add_child(body);chunks[key]=body
	for key: Vector2i in chunks.keys():
		if needed.has(key): continue
		var body: StaticBody2D=chunks[key]
		remove_child(body);body.queue_free();chunks.erase(key);freed_chunks+=1
	active_shape_count=0
	for key: Vector2i in chunks: active_shape_count+=buckets[key].size()

func chunk_signature(key: Vector2i) -> String:
	var rows: Array=[]
	for shape: Dictionary in buckets.get(key,[]):
		rows.append([shape.shape,shape.get("points",[]),shape.get("rect",[]),shape.get("center",[]),shape.get("radius",0)])
	return JSON.stringify(rows,"",true,true).sha256_text()
