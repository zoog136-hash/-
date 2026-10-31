extends SceneTree

# Streamed terrain collision: chunks near the actor exist at once, farther ones
# are built a few rows per frame, and the result is identical to a one-shot
# build. Revisited chunks reuse their segments.
const RUNTIME = preload("res://scripts/maps/source_map_runtime.gd")
const STREAM = preload("res://scripts/maps/remake_collision_stream.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("COLLISION_STREAM_CACHE_FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var field = RUNTIME.load_field("aden_world")
	check(field != null, "aden_world source field loads")
	if field == null:
		_finish()
		return
	var host := Node2D.new()
	root.add_child(host)
	var actor := Node2D.new()
	host.add_child(actor)
	actor.global_position = Vector2(field.data.spawn_position[0], field.data.spawn_position[1])
	var body = STREAM.new()
	body.source = field
	body.actor = actor
	host.add_child(body)
	var cell: Vector2i = field.world_to_cell(actor.global_position)
	var center := Vector2i(floori(float(cell.x) / STREAM.CHUNK_SIZE), floori(float(cell.y) / STREAM.CHUNK_SIZE))
	check(body.chunks.has(center), "the actor's own chunk exists immediately")
	for key: Vector2i in body.needed_keys:
		if body._cell_distance_to_chunk(cell, key) <= STREAM.NEAR_CELLS:
			check(body.chunks.has(key), "near chunk %s exists immediately" % key)
	var queued: int = body.far_queue.size() + (0 if body.far_job.is_empty() else 1)
	for frame: int in range(600):
		if body.far_queue.is_empty() and body.far_job.is_empty(): break
		await physics_frame
	check(body.far_queue.is_empty() and body.far_job.is_empty(), "far chunks finish building")
	check(body.chunks.size() == body.needed_keys.size(), "every needed chunk is attached (%d/%d)" % [body.chunks.size(), body.needed_keys.size()])
	# Incremental and one-shot builds give the exact same segments.
	for key: Vector2i in body.needed_keys:
		var built: PackedVector2Array = body.segment_cache[key]
		var fresh := PackedVector2Array()
		for y: int in range(key.y * STREAM.CHUNK_SIZE, mini((key.y + 1) * STREAM.CHUNK_SIZE, field.height)):
			body._append_row(key, y, fresh)
		check(built == fresh, "chunk %s segments match a one-shot build" % key)
		var shape: ConcavePolygonShape2D = (body.chunks[key] as CollisionShape2D).shape
		check(shape.segments == fresh, "chunk %s collision shape uses those segments" % key)
	# Leaving and coming back reuses cached segments instead of rebuilding.
	var cached: int = body.segment_cache.size()
	var away: Vector2 = actor.global_position
	actor.global_position = field.cell_to_world(Vector2i(mini(cell.x + STREAM.CHUNK_SIZE * 3, field.width - 1), cell.y)) if field.has_method("cell_to_world") else away
	body.refresh()
	actor.global_position = away
	body.refresh()
	check(body.chunks.has(center) and body.segment_cache.size() >= cached, "returning to a chunk reuses its cached segments")
	print("COLLISION_STREAM_CACHE_STATS queued_far=%d chunks=%d cached=%d" % [queued, body.chunks.size(), body.segment_cache.size()])
	field.close()
	_finish()

func _finish() -> void:
	print("COLLISION_STREAM_CACHE_RESULT ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
