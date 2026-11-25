extends SceneTree

const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const FIXTURE = preload("res://tests/current523_aden_play_renderer_test.gd")

var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class Tiles extends FIXTURE.FakeTiles:
	var requested: Array[int] = []
	var ready: bool = true
	func has_tile(id: int) -> bool: return id in [1,2,3]
	func prefetch(id: int) -> bool:
		requested.append(id)
		return ready

class Probe extends RENDERER:
	var stalled_member: String = ""
	var walks: int = 0
	func _view_rect() -> Rect2: return Rect2(0,0,512,512)
	func _prefetch_chunk(member: String) -> bool:
		return member != stalled_member and super._prefetch_chunk(member)
	func _member_block_tiles(member: String, cell: Vector2i, layers: Dictionary) -> PackedInt32Array:
		walks += 1
		return super._member_block_tiles(member,cell,layers)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("MAP_STREAMING_WORK_FAIL: ",description)

func query_bounds() -> void:
	var renderer := RENDERER.new()
	for x: int in range(64,0,-1):
		for y: int in range(64,0,-1):
			var point := Vector2((x-y)*1536,(x+y-64)*768)
			renderer._chunk_rects["%02d/%02d" % [x,y]] = Rect2(point,Vector2(3072,1536))
	var queries: Array[Rect2] = []
	for step: int in 384:
		var x: float = float(step%48)*578.0 - 12000.0
		var y: float = float(step%57)*761.0 - 16000.0
		queries.append(Rect2(Vector2(x,y),Vector2(896,896)))
	queries.append(Rect2(-2048,-2048,2048,2048))
	queries.append(Rect2(0,0,0,0))
	queries.append(Rect2(-4096,-4096,8192,8192))
	queries.append(Rect2(-130000,-130000,260000,260000))
	var expected: Array = []
	var began: int = Time.get_ticks_usec()
	for query: Rect2 in queries: expected.append(renderer._members_in(query))
	var linear_usec: int = Time.get_ticks_usec()-began
	began = Time.get_ticks_usec()
	renderer._index_chunk_rects()
	var index_usec: int = Time.get_ticks_usec()-began
	var matches: bool = true
	began = Time.get_ticks_usec()
	for index: int in queries.size():
		if renderer._members_in(queries[index]) != expected[index]: matches = false
	var indexed_usec: int = Time.get_ticks_usec()-began
	check(matches,"indexed bounds agree in catalog order, including negative, touching and wide queries")
	check(renderer._indexed_members.size()==4096 and not renderer._chunk_buckets.is_empty(),"large map uses coarse index")
	var sample: Rect2 = queries[25]
	var block := Vector2i(-2,-2)
	var ordered: Array[String] = renderer._members_in(RENDERER._block_rect(block).grow(RENDERER.BUILD_MARGIN))
	ordered.sort()
	check(not ordered.is_empty() and renderer._block_members(block)==ordered,"command assembly still sorts member names")
	renderer._chunk_rects = {"replacement":sample}
	renderer._index_chunk_rects()
	check(renderer._chunk_buckets.is_empty() and renderer._members_in(sample)==["replacement"],"small replacement catalog clears the prior index")
	for index: int in 80: renderer._chunk_rects[str(index)] = sample
	renderer._chunk_rects["wide"] = Rect2(-200000,-200000,400000,400000)
	renderer._index_chunk_rects()
	check(renderer._chunk_buckets.is_empty() and renderer._members_in(sample).has("wide"),"oversize geometry uses exact scan")
	evidence["chunk_queries"]={"members":4096,"queries":queries.size(),"linear_usec":linear_usec,"indexed_usec":indexed_usec,"index_build_usec":index_usec}
	renderer.free()

func atlas_discovery() -> void:
	var renderer := Probe.new()
	var tiles := Tiles.new()
	renderer._tile_pack=tiles
	var cell := Vector2i.ZERO
	renderer._chunk_rects = {"resident":Rect2(0,0,512,512),"late":Rect2(0,0,512,512)}
	var data := PackedInt64Array()
	for i: int in 8192:
		data.append(i%256)
		data.append(i%240)
		data.append((1+(i%2))<<8)
	renderer._raw_chunks["resident"] = {-2:data,-1:PackedInt64Array([0,0,4294967295,10,10,255<<8])}
	renderer._chunk_bins["resident"] = RENDERER._bin_chunk(renderer._raw_chunks.resident)
	renderer.stalled_member = "late"
	var retry_count: int = 40
	var began: int = Time.get_ticks_usec()
	for _retry: int in retry_count:
		renderer._pending_tile_members.clear()
		renderer._pending_tiles_ready(cell)
	var repeat_usec: int = Time.get_ticks_usec()-began
	var repeat_walks: int = renderer.walks
	renderer.walks=0
	renderer._pending_tile_members.clear()
	var unchanged: bool = true
	began = Time.get_ticks_usec()
	for _retry: int in retry_count:
		tiles.requested.clear()
		unchanged = not renderer._pending_tiles_ready(cell) and tiles.requested==[1,2] and unchanged
	var retained_usec: int = Time.get_ticks_usec()-began
	check(unchanged,"missing member remains incomplete and requests only known atlases in stable order")
	check(repeat_walks==retry_count and renderer.walks==1,"slow neighbour no longer repeats the resident record scan")
	evidence["partial_block_retries"]={"retries":retry_count,"resident_records":8192,"repeat_walks":repeat_walks,"retained_walks":renderer.walks,"repeat_usec":repeat_usec,"retained_usec":retained_usec}
	renderer.stalled_member=""
	renderer._raw_chunks["late"] = {0:PackedInt64Array([0,0,512,20,20,768])}
	tiles.requested.clear()
	check(renderer._pending_tiles_ready(cell) and renderer.walks==2 and tiles.requested==[1,2,3],"late member is walked once and merged without a duplicate atlas request")
	check(renderer._pending_tile_members.is_empty() and renderer._pending_tiles[cell]==PackedInt32Array([1,2,3]),"complete block keeps one compact list")
	renderer._clear_blocks()
	renderer.include_objects=false
	check(renderer._pending_tiles_ready(cell) and renderer._pending_tiles[cell]==PackedInt32Array([1,2]),"object policy clears prior hints")
	renderer.free()

static func finished() -> void: pass

func wake_dependencies() -> void:
	var renderer := Probe.new()
	var tiles := Tiles.new()
	renderer._tile_pack=tiles
	var start := Vector2i.ZERO
	var next := Vector2i(1,0)
	var distant := Vector2i(20,0)
	var freeze: int = Time.get_ticks_msec()+10000
	renderer._pending_tiles = {start:PackedInt32Array([1,2]),next:PackedInt32Array([3]),distant:PackedInt32Array([2])}
	renderer._pending_retry = {start:freeze,next:freeze,distant:freeze}
	renderer._pending_blocks.assign([start])
	renderer._chunk_rects = {"near":Rect2(0,0,90,90)}
	renderer._raw_chunks["near"] = {-2:PackedInt64Array([4,4,256,20,20,512])}
	check(renderer._bake_pending(-1)==0 and renderer._blocks.is_empty(),"an unexpired retry still holds with no completion")
	renderer._wake_blocks_for_atlases(PackedInt32Array([2]),Rect2(0,0,1024,512))
	check(not renderer._pending_retry.has(start) and renderer._pending_retry.has(next) and renderer._pending_retry.has(distant),"atlas completion wakes only related visible or approaching blocks")
	check(renderer._bake_pending(-1)==1 and renderer._blocks.has(start),"matching atlas produces a block in the same budget slice")
	renderer._pending_retry[start]=freeze
	var task: int = WorkerThreadPool.add_task(finished)
	for _frame: int in 30:
		if WorkerThreadPool.is_task_completed(task): break
		await process_frame
	renderer._chunk_jobs["near"]={"task":task,"problem":"synthetic terminal read"}
	renderer._pump_chunk_jobs()
	check(not renderer._pending_retry.has(start) and renderer._pending_retry.has(next) and renderer._pending_retry.has(distant),"terminal chunk read wakes only intersecting blocks and keeps diagnostics")
	renderer.free()

func run() -> void:
	query_bounds()
	atlas_discovery()
	await wake_dependencies()
	print("MAP_STREAMING_WORK_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"synthetic":true,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
