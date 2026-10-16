extends RefCounted
## Preserve the old exact-footprint contract through spatial streaming. Count
## every original shape once, and inspect the actual loaded Godot shapes too.
static func intact(world: Node) -> bool:
	var field: PlayableField=world.field_map
	if not field is AuthoredRemakeField:
		return world.field_physics.get_child_count()==field.blockers.size()
	var stream: StaticBody2D=field.collision_stream
	var expected: Dictionary={};var actual: Dictionary={}
	for shape: Dictionary in field.blockers:
		var key: String=JSON.stringify(shape,"",true,true)
		expected[key]=int(expected.get(key,0))+1
	for bucket: Array in stream.buckets.values():
		for shape: Dictionary in bucket:
			var key: String=JSON.stringify(shape,"",true,true)
			actual[key]=int(actual.get(key,0))+1
	if expected!=actual or stream.total_shape_count!=field.blockers.size(): return false
	var loaded: int=0
	for key: Vector2i in stream.buckets:
		var needed: bool=(stream.bucket_bounds[key] as Rect2).intersects(stream.required_bounds(),true)
		if needed!=stream.chunks.has(key): return false
		if not needed: continue
		var body: StaticBody2D=stream.chunks[key]
		if body.collision_layer!=4 or body.collision_mask!=0: return false
		var originals: Array=stream.buckets[key]
		if body.get_child_count()!=originals.size(): return false
		for i: int in range(originals.size()):
			var shape: Dictionary=originals[i];var node: Node2D=body.get_child(i)
			if str(shape.shape)=="polygon":
				if not node is CollisionPolygon2D or node.polygon!=shape.polygon: return false
			elif str(shape.shape)=="circle":
				if not node is CollisionShape2D or not node.shape is CircleShape2D: return false
				# Godot shape properties store real_t; JSON numbers retain double
				# precision. Compare their normal engine roundoff, not raw decimals.
				if not is_equal_approx(node.shape.radius,float(shape.radius)) or node.position!=shape.vcenter: return false
			else:
				if not node is CollisionShape2D or not node.shape is RectangleShape2D: return false
				if node.shape.size!=(shape.vrect as Rect2).size or node.position!=(shape.vrect as Rect2).get_center(): return false
		loaded+=originals.size()
	return loaded==stream.active_shape_count
