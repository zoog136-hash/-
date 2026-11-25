extends SceneTree

const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const FIXTURE = preload("res://tests/current523_aden_play_renderer_test.gd")

var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class Tiles extends FIXTURE.FakeTiles:
	var requested: Array[int] = []
	var ready: bool = true
	var extra_id: int = -1
	func has_tile(id: int) -> bool: return id in [1,2,3] or id == extra_id
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

class CountingCatalog extends "res://scripts/maps/current523_source_pack.gd":
	var enumerations: int = 0
	func source_members() -> Array:
		enumerations += 1
		return super.source_members()

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
		renderer._chunk_atlas_ids.clear()
		renderer._pending_tiles_ready(cell)
	var repeat_usec: int = Time.get_ticks_usec()-began
	var repeat_walks: int = renderer.walks
	renderer.walks=0
	renderer._pending_tile_members.clear()
	renderer._chunk_atlas_ids.clear()
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

func resident_atlas_lists() -> void:
	var floor_lane := PackedInt64Array()
	for i: int in 96:
		# Touch four bins across the negative seam. The invalid source and
		# several frames of each real atlas are interleaved in file order.
		var ref: int = [4294967295, 2 << 8 | i, 9 << 8, 1 << 8 | i][i % 4]
		floor_lane.append_array(PackedInt64Array([-1,-1,ref]))
	for i: int in 64: floor_lane.append_array(PackedInt64Array([1024,0,i << 8]))
	for i: int in 64: floor_lane.append_array(PackedInt64Array([1536,0,4294967295]))
	floor_lane.append_array(PackedInt64Array([2048,0,256]))
	var layers: Dictionary = {-2: floor_lane, -1: PackedInt64Array([0,0,256]), 0: PackedInt64Array([0,0,768])}
	var renderer := Probe.new()
	var tiles := Tiles.new()
	renderer._tile_pack = tiles
	var bins: Dictionary = RENDERER._bin_chunk(layers)
	renderer._chunk_bins["first"] = bins
	renderer._raw_chunks["first"] = layers
	check(renderer._chunk_atlas_ids.is_empty(), "a newly installed floor costs no extra texture-discovery pass")
	for objects: bool in [true,false]:
		renderer.include_objects = objects
		var reference: Dictionary = {}
		for cell: Vector2i in bins: reference[cell] = renderer._member_block_tiles("first",cell,layers)
		renderer._clear_blocks()
		var same: bool = true
		for cell: Vector2i in bins:
			if renderer._member_block_tiles("first",cell,layers) != reference[cell]: same = false
		check(same and reference[Vector2i.ZERO] == (PackedInt32Array([2,1,3]) if objects else PackedInt32Array([2,1])), "new and retired viewports request identical valid atlases in layer/record order")
		var lists: Dictionary = renderer._chunk_atlas_ids.first
		var mode: int = int(objects)
		check(lists[Vector3i(-1,-1,mode)] == PackedInt32Array([2,9,1]) and lists[Vector3i(-1,0,mode)] == lists[Vector3i(0,-1,mode)], "crossing tile contributes the same ordered IDs to neighbouring bins")
		check(not lists.has(Vector3i(2,0,mode)) and not lists.has(Vector3i(4,0,mode)), "diverse and short lanes keep the normal scan")
		check(lists.has(Vector3i(3,0,mode)) and lists[Vector3i(3,0,mode)].is_empty(), "sentinel-only floor has no texture dependency")
	tiles.extra_id = 9
	check(renderer._member_block_tiles("first",Vector2i.ZERO,layers) == PackedInt32Array([2,9,1]), "a cached request still checks the current atlas table")
	renderer._raw_recent.append("first")
	var empty: Dictionary = {"tail":{},"packed":{},"bins":{},"clipped":0,"off_floor":0}
	for i: int in RENDERER.RAW_CHUNK_LIMIT: renderer._install_chunk(str(i),empty)
	check(not renderer._raw_chunks.has("first") and not renderer._chunk_atlas_ids.has("first"), "texture discovery data leaves with its S32 chunk")
	renderer.free()

func resident_atlas_bound() -> void:
	var renderer := Probe.new()
	renderer._tile_pack = Tiles.new()
	var lane := PackedInt64Array()
	for cell: int in RENDERER.MAX_ATLAS_LISTS_PER_CHUNK + 1:
		for record: int in RENDERER.MIN_ATLAS_CACHE_RECORDS: lane.append_array(PackedInt64Array([cell * 512,0,256 | record]))
	var layers: Dictionary = {-2:lane}
	renderer._raw_chunks["slots"] = layers
	var matches: bool = true
	for cell: int in RENDERER.MAX_ATLAS_LISTS_PER_CHUNK + 1:
		if renderer._member_block_tiles("slots",Vector2i(cell,0),layers) != PackedInt32Array([1]): matches = false
	check(matches and renderer._chunk_atlas_ids.slots.size() == RENDERER.MAX_ATLAS_LISTS_PER_CHUNK, "a full per-member cache returns the complete result for later requests")
	renderer._install_chunk("slots",{"tail":{},"packed":{},"bins":{},"clipped":0,"off_floor":0})
	check(not renderer._chunk_atlas_ids.has("slots"), "replacement cannot use a prior selection's atlas list")
	renderer.free()

func catalog_counts() -> void:
	var pack := CountingCatalog.new()
	pack._members = {"third":{}, "first":{}, "second":{}}
	pack._supported = {"first":true}
	pack.loaded = true
	var renderer := Probe.new()
	var field := preload("res://scripts/maps/current523_source_field.gd").new()
	field.loaded = true
	field._raw = pack
	field.availability = {"source_count": 3, "runtime_ready_count": 1}
	field.set_meta("current523_source_field",true)
	field.set_meta("current523_generic_field",true)
	field.inferred_placements = {"first":{"test":true}}
	renderer.field = field
	renderer._raw_sources = pack
	renderer._tile_pack = Tiles.new()
	renderer._chunk_rects = {"first":Rect2(0,0,512,512)}
	for x: int in range(-1,2):
		for y: int in range(-1,2):
			renderer._blocks[Vector2i(x,y)] = {"commands":{},"count":1,"draws":1,"raw_ff":0,"unresolved":0,"atlas_ids":[]}
	for step: int in 2:
		check(renderer._build_frame(), "warm ground frame rebuilds")
		var metrics: Dictionary = renderer.frame_metrics()
		check(metrics.registered_sources == 3 and metrics.expected_sources == 3 and metrics.inferred_placements == field.inferred_placements, "frame and field count all registered members including unavailable ones")
		metrics.inferred_placements.first.test = false
	check(pack.enumerations == 0 and field.inferred_placements.first.test, "warm frames never sort the selected catalog or expose the field's placement data")
	check(pack.source_members() == ["first","second","third"], "enumeration still returns sorted names when explicitly requested")
	field.availability.erase("source_count")
	check(field.scope_metrics().expected_sources == 3, "fields without a stored asset count retain the enumeration fallback")
	field.loaded = false
	check(field.scope_metrics().expected_sources == 0, "closed field exposes no members")
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
	resident_atlas_lists()
	resident_atlas_bound()
	catalog_counts()
	await wake_dependencies()
	print("MAP_STREAMING_WORK_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"synthetic":true,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
