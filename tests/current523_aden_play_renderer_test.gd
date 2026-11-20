extends SceneTree
## Small synthetic display/profile regressions, not native M behavior evidence.
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const REVIEW = preload("res://scripts/maps/current523_aden_review.gd")
const COORDINATES = preload("res://scripts/maps/source_coordinates.gd")
const FIELD = preload("res://scripts/maps/source_map_runtime_field.gd")
const PLACEMENT = preload("res://scripts/maps/current523_aden_inferred_placement.gd")
var checks: int = 0
var failures: Array[String] = []

class FakeTiles extends RefCounted:
	var loads: Array[int] = []
	var problem: String = ""
	var supported: bool = true
	var image: Texture2D
	func _init() -> void:
		var pixels := Image.create_empty(384, 384, false, Image.FORMAT_RGBA8)
		pixels.fill(Color(1, 0, 0, 1))
		image = ImageTexture.create_from_image(pixels)
	func has_tile(_id: int) -> bool: return supported
	func texture_for(id: int) -> Texture2D:
		loads.append(id)
		return image
	func cache_size() -> int: return 1

class CountedTiles extends FakeTiles:
	var tile_checks: int = 0
	var frame_checks: int = 0
	var blocked_frame: int = 2
	var fail_next_load: bool = false

	func has_tile(id: int) -> bool:
		tile_checks += 1
		return id != 8

	func has_subimage(_id: int, frame: int) -> bool:
		frame_checks += 1
		return frame != blocked_frame

	func texture_for(id: int) -> Texture2D:
		var texture: Texture2D = super.texture_for(id)
		if fail_next_load:
			fail_next_load = false
			return null
		return texture

## S32 sections for the worker chunk read (a floor with a few tiles, covers and objects).
class FakeChunkSources extends RefCounted:
	var problem: String = ""
	var broken: bool = false
	func source_metadata(_member: String) -> Dictionary: return {"core_end": 0}
	func read_member(member: String) -> Dictionary: return read_member_job(member)
	func read_member_job(_member: String) -> Dictionary:
		if broken: return {"_problem": "synthetic failure"}
		var floor_bytes := PackedByteArray(); floor_bytes.resize(8192 * 4)
		for index: int in 8192: floor_bytes.encode_u32(index * 4, 4294967295 if index % 7 else (3 << 8) | (index & 255))
		var covers := PackedByteArray([2, 0, 5, 9, 1, 2, 0, 0, 40, 3, 7, 1, 0, 0])
		var objects := PackedByteArray([1, 0, 0, 0, 0, 0, 2, 0, 10, 12, 0, 9, 2, 0, 0, 11, 30, 1, 5, 4, 0, 0])
		return {"source_sha256": "a".repeat(64), "source_bytes": 1, "sections": {"floor": floor_bytes, "covers": covers, "objects": objects, "tail": PackedByteArray()}}

## Decodes on a "worker": an atlas is ready only after a request and a pump.
class FakeAsyncTiles extends FakeTiles:
	var requested: Dictionary = {}
	var ready: Dictionary = {}
	func prefetch(id: int) -> bool:
		if ready.has(id): return true
		requested[id] = true
		return false
	func pump() -> void:
		for id: int in requested: ready[id] = true
		requested.clear()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func synthetic_field() -> RefCounted:
	var value = FIELD.new()
	value.set_meta("source_map84", true)
	value.definition = {"map_id":"aden_world", "source_map_id":4, "source_sha256":PLAY.GRID_SHA256}
	value.data = {"map_id":"aden_world", "npc_spawn":[], "portal":[]}
	value.coordinates.configure([32448, 32064], [1856, 1536], {"basis_x":[24,-12], "basis_y":[24,12], "translation":[0,768]})
	value.runtime_record = {"source_map_id":4, "target_map_id":"aden_world", "chunks":[]}
	value.raw_grid.source_id = 4
	value.raw_grid.origin = PLAY.GRID_ORIGIN
	value.raw_grid.width = PLAY.GRID_SIZE.x
	value.raw_grid.height = PLAY.GRID_SIZE.y
	value.raw_grid.bytes.resize(PLAY.GRID_SIZE.x * PLAY.GRID_SIZE.y)
	value.raw_grid.bytes.fill(0)
	return value

func run() -> void:
	var coordinates = COORDINATES.new()
	check(coordinates.configure([32448,32064], [1856,1536], {"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,768]}), "existing display coordinates configure")
	for origin: Vector2i in [Vector2i(32448,32064), Vector2i(33408,32768), Vector2i(34048,33152)]:
		for half_x: int in [0,1,126,127,128,255]:
			for row: int in [0,63,64,255]:
				var local: Vector2i = REVIEW.project_half_storage(2 * (origin.x - coordinates.origin.x) + half_x, origin.y - coordinates.origin.y + row)
				var expected: Vector2 = Vector2(local) + coordinates.translation + Vector2(0,-12)
				check(PLAY.project_storage(coordinates, origin, half_x, row) == expected, "canonical existing half-tile parity")
	var base := Vector2i(33408,32768)
	check(PLAY.project_storage(coordinates, base, 128, 0) == PLAY.project_storage(coordinates, base + Vector2i(64,0), 0, 0), "horizontal chunk continuity")
	check(PLAY.project_storage(coordinates, base, 0, 64) == PLAY.project_storage(coordinates, base + Vector2i(0,64), 0, 0), "vertical chunk continuity")
	check(PLAY.project_storage(coordinates,PLACEMENT.ORIGIN,16,64)==PLAY.project_storage(coordinates,PLACEMENT.ORIGIN+Vector2i(0,64),16,0),"inferred slot and actual southern neighbor share projected seam coordinates; no pixel continuity claim")
	for value: Vector2 in [Vector2.ZERO, Vector2(-48,48), Vector2(.5,-12)]:
		check(PLAY.valid_delta(value), "bounded display offset accepted")
	for value: Vector2 in [Vector2(49,0), Vector2(0,-49), Vector2(INF,0), Vector2(NAN,0)]:
		check(not PLAY.valid_delta(value), "unsafe display offset rejected")
	check(not PLAY.profile_problem(null).is_empty(), "missing live field rejects")
	var field = synthetic_field()
	check(PLAY.profile_problem(field).contains("SHA256"), "claimed grid identity cannot replace actual byte hash")
	field.definition.source_map_id = 75
	check(not PLAY.profile_problem(field).is_empty(), "other source map rejects")
	field.definition.source_map_id = 4
	var renderer = PLAY.new()
	root.add_child(renderer)
	var actor := Node2D.new()
	root.add_child(actor)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	renderer._unhandled_input(click)
	check(renderer.field == null, "unconfigured candidate ignores inherited door input safely")
	check(not renderer.try_configure(field, actor, "/missing/raw", "/missing/tiles", Vector2.ZERO), "synthetic untrusted field cannot activate renderer")
	check(field.raw_grid.bytes.count(0) == field.raw_grid.bytes.size(), "profile rejection preserves synthetic navigation bytes")
	# Isolate coverage and cache behavior; production try_configure has no mock hook.
	renderer.field = field
	renderer.player = actor
	renderer.problem = ""
	renderer._legacy_origins = {PLAY.GRID_ORIGIN:true}
	renderer._overlap = {PLAY.GRID_ORIGIN:"synthetic"}
	var point: Vector2 = field.coordinates.cell_to_world(Vector2i(0,0))
	check(renderer.support_world_point(point), "shared artwork coverage admits point without reading movement flags")
	check(not renderer.support_world_point(field.coordinates.cell_to_world(Vector2i(64,0))), "unsupported artwork chunk rejects")
	renderer._visual_delta = Vector2(48,0)
	check(not renderer.support_world_point(point), "display offset participates in painted coverage boundary")
	renderer._visual_delta = Vector2.ZERO
	var lanes: Dictionary = {}
	renderer._append(lanes, PLAY.GRID_ORIGIN, 0, 0, 4294967295, -2)
	renderer._append(lanes, PLAY.GRID_ORIGIN, 1, 0, 2147483903, -2)
	check(lanes[-2][2] == 4294967295 and lanes[-2][5] == 2147483903, "raw packed references stay unsigned32")
	check(lanes[-2].size() == 6, "blocked synthetic navigation does not erase artwork")
	renderer._append(lanes, PLAY.GRID_ORIGIN, 128, 0, 0, -2)
	check(lanes[-2].size() == 6, "painting outside shared supplied coverage is excluded")
	var decorations: Dictionary={}
	renderer._append(decorations,PLAY.GRID_ORIGIN,128,0,123,0)
	check(decorations.is_empty(),"legacy overlay retains its original intersection limit")
	field.set_meta("current523_generic_field",true)
	renderer._append(decorations,PLAY.GRID_ORIGIN,128,0,123,0)
	renderer._append(decorations,PLAY.GRID_ORIGIN,128,0,456,-1)
	renderer._append(decorations,PLAY.GRID_ORIGIN,128,0,789,-2)
	check(decorations[0][2]==123 and decorations[-1][2]==456 and not decorations.has(-2),"source packet decorations span absent floor chunks without inventing floor")
	check(field.raw_grid.bytes.count(0)==field.raw_grid.bytes.size(),"off-floor artwork never changes navigation bytes")
	field.remove_meta("current523_generic_field")
	# The one-pass chunk projection equals the per-record path (lanes and counters).
	var rng := RandomNumberGenerator.new(); rng.seed = 523
	var halves := PackedInt32Array(); var rows := PackedInt32Array(); var kinds := PackedInt32Array(); var raw_refs := PackedInt64Array()
	for index: int in 3000:
		halves.append(rng.randi_range(0, 255)); rows.append(rng.randi_range(0, 255)); kinds.append([-2, -1, 0, 1, 3][rng.randi() % 5]); raw_refs.append(rng.randi())
	for generic: bool in [false, true]:
		if generic: field.set_meta("current523_generic_field", true)
		for origin: Vector2i in [PLAY.GRID_ORIGIN, PLAY.GRID_ORIGIN + Vector2i(64, 0), PLAY.GRID_ORIGIN + Vector2i(-64, 64)]:
			renderer._scope_clipped_records = 0; renderer._off_floor_decoration_records = 0
			var slow: Dictionary = {}
			for index: int in halves.size(): renderer._append(slow, origin, halves[index], rows[index], raw_refs[index], kinds[index])
			var slow_counts: Array = [renderer._scope_clipped_records, renderer._off_floor_decoration_records]
			renderer._scope_clipped_records = 0; renderer._off_floor_decoration_records = 0
			var fast: Dictionary = renderer._project_records(origin, halves, rows, kinds, raw_refs)
			var same: bool = fast.size() == slow.size() and [renderer._scope_clipped_records, renderer._off_floor_decoration_records] == slow_counts
			for layer: int in slow: same = same and fast.has(layer) and fast[layer] == PackedInt64Array(slow[layer])
			check(same, "one-pass chunk projection equals the per-record path (generic=%s origin=%s)" % [generic, origin])
	_check_chunk_bins()
	# A chunk read on a worker installs the same lanes, bins, tail and counters
	# as the main-thread read of the same S32 sections.
	var worker_sources := FakeChunkSources.new()
	var saved_sources: Variant = renderer._raw_sources
	renderer._raw_sources = worker_sources
	renderer._member_origins["worker_a"] = PLAY.GRID_ORIGIN
	renderer._member_origins["worker_b"] = PLAY.GRID_ORIGIN
	renderer._scope_clipped_records = 0; renderer._off_floor_decoration_records = 0
	var direct: Dictionary = renderer._install_chunk("worker_a", PLAY._decode_chunk(renderer._chunk_params("worker_a"), worker_sources.read_member_job("worker_a")))
	var direct_counts: Array = [renderer._scope_clipped_records, renderer._off_floor_decoration_records]
	renderer._scope_clipped_records = 0; renderer._off_floor_decoration_records = 0
	check(not renderer._prefetch_chunk("worker_b") and renderer._chunk_jobs.has("worker_b"), "an unread chunk is read on a worker")
	var waited_chunk: int = 0
	while not renderer._chunk_jobs.is_empty() and waited_chunk < 5000:
		renderer._pump_chunk_jobs(); OS.delay_msec(1); waited_chunk += 1
	check(renderer._raw_chunks.get("worker_b") == direct and renderer._chunk_bins.get("worker_b") == renderer._chunk_bins.get("worker_a") and [renderer._scope_clipped_records, renderer._off_floor_decoration_records] == direct_counts and renderer._static_tails.has("worker_b"), "the worker read equals the main-thread read")
	check(renderer._prefetch_chunk("worker_b"), "a loaded chunk is ready")
	worker_sources.broken = true
	renderer._member_origins["worker_c"] = PLAY.GRID_ORIGIN
	renderer._prefetch_chunk("worker_c")
	waited_chunk = 0
	while not renderer._chunk_jobs.is_empty() and waited_chunk < 5000:
		renderer._pump_chunk_jobs(); OS.delay_msec(1); waited_chunk += 1
	check(renderer._unreadable_chunks.has("worker_c") and not renderer._raw_chunks.has("worker_c"), "a failed worker read becomes an unreadable hole")
	for member: String in ["worker_a", "worker_b", "worker_c"]:
		renderer._raw_chunks.erase(member); renderer._chunk_bins.erase(member); renderer._static_tails.erase(member); renderer._unreadable_chunks.erase(member); renderer._member_origins.erase(member); renderer._raw_recent.erase(member)
	renderer._raw_sources = saved_sources
	field.remove_meta("current523_generic_field")
	renderer._scope_clipped_records = 0; renderer._off_floor_decoration_records = 0
	_check_block_reference_work(renderer)
	var tiles := FakeTiles.new()
	renderer._tile_pack = tiles
	renderer._chunk_rects = {"synthetic":Rect2(-32,-32,64,64)}
	renderer._raw_chunks = {"synthetic":{-2:PackedInt64Array([0,0,2147483903,0,0,4294967295])}}
	check(renderer._build_frame(), "synthetic bounded frame builds")
	check(tiles.loads == [8388608], "upper24 bits are preserved; all-ones word is not an asset lookup")
	check(renderer._build_frame() and tiles.loads.size() == 1, "visible frame textures reused across refreshes")
	check(renderer.frame_metrics().uninterpreted_ffffffff_words == 1 and renderer.frame_metrics().draw_commands == 1, "sentinel and visible drawing metrics separate")
	var first_block: Variant = (renderer._blocks.get(Vector2i.ZERO, {}) as Dictionary).get("viewport")
	check(renderer.frame_metrics().visible_blocks >= 1 and first_block is SubViewport and renderer._visible_blocks.has(Vector2i.ZERO), "ground tiles are baked into a 512 px block image")
	check(renderer._build_frame() and (renderer._blocks[Vector2i.ZERO] as Dictionary).viewport == first_block, "an unchanged block image is reused, not baked again")
	renderer._chunk_rects = {"synthetic":Rect2(480,-32,64,64)}
	renderer._raw_chunks = {"synthetic":{-2:PackedInt64Array([500,0,2147483903])}}
	renderer._chunk_bins.clear(); renderer._clear_blocks()
	check(renderer._build_frame() and renderer.frame_metrics().draw_commands == 1 and renderer.frame_metrics().block_draw_commands == 2, "a tile across a block edge is drawn in both blocks but counted once")
	renderer._chunk_rects = {"synthetic":Rect2(-32,-32,64,64)}
	# Margin blocks wait for their atlases' worker decode; on-screen ones never wait.
	# Shift the screen so its right edge (1500) is just before a block edge (1536).
	var async_tiles := FakeAsyncTiles.new()
	async_tiles.ready[2147483903 >> 8] = true  # the on-screen block's atlas is already decoded
	renderer._tile_pack = async_tiles
	var saved_canvas: Transform2D = root.canvas_transform
	root.canvas_transform = Transform2D(0.0, Vector2(renderer._view_rect().end.x - 1500.0, 0.0)) * saved_canvas
	var view_now: Rect2 = renderer._view_rect()
	var here := Vector2i(view_now.get_center())
	var margin_point := Vector2i(1540, here.y)
	renderer._chunk_rects = {"synthetic":Rect2(Vector2(here) - Vector2(32, 32), Vector2(64, 64)), "margin":Rect2(Vector2(margin_point) - Vector2(32, 32), Vector2(64, 64))}
	renderer._raw_chunks = {"synthetic":{-2:PackedInt64Array([here.x,here.y,2147483903])}, "margin":{-2:PackedInt64Array([margin_point.x,margin_point.y,(7 << 8) | 1])}}
	renderer._chunk_bins.clear(); renderer._clear_blocks()
	var near_cell := Vector2i(here.x >> PLAY.BLOCK_SHIFT, here.y >> PLAY.BLOCK_SHIFT)
	var far_cell := Vector2i(margin_point.x >> PLAY.BLOCK_SHIFT, margin_point.y >> PLAY.BLOCK_SHIFT)
	check(not PLAY._block_rect(far_cell).intersects(view_now) and view_now.grow(PLAY.BUILD_MARGIN).has_point(Vector2(margin_point)), "fixture: the far block is in the margin only")
	check(renderer._build_frame() and renderer._blocks.has(near_cell) and not renderer._blocks.has(far_cell) and async_tiles.requested.has(7) and not renderer._built_view.has_area(), "an on-screen block bakes now; a margin block waits for its decode and the next refresh retries")
	async_tiles.pump()
	check(renderer._build_frame() and renderer._blocks.has(far_cell), "the margin block bakes once its atlas is ready")
	# A new on-screen block waits briefly for its decode, then bakes regardless.
	renderer._raw_chunks["synthetic"] = {-2:PackedInt64Array([here.x,here.y,(8 << 8) | 1])}
	renderer._chunk_bins.clear(); renderer._clear_blocks()
	renderer._refresh_clock = 0.25
	var waited_ok: bool = renderer._build_frame()
	check(waited_ok and not renderer._blocks.has(near_cell) and async_tiles.requested.has(8) and renderer._refresh_clock <= 0.05 and renderer.problem.is_empty(), "an on-screen block waits for its worker decode without failing the map")
	renderer._screen_wait[near_cell] = Time.get_ticks_msec() - PLAY.ON_SCREEN_WAIT_MSEC - 1
	check(renderer._build_frame() and renderer._blocks.has(near_cell), "after the wait limit it bakes with what the pack gives")
	root.canvas_transform = saved_canvas
	renderer._tile_pack = tiles
	renderer._chunk_rects = {"synthetic":Rect2(-32,-32,64,64)}
	renderer._raw_chunks = {"synthetic":{-2:PackedInt64Array([0,0,2147483903,0,0,4294967295])}}
	renderer._chunk_bins.clear(); renderer._clear_blocks()
	var requested: Array[String] = []
	renderer.safe_return_requested.connect(func(reason: String) -> void: requested.append(reason))
	var too_many := PackedInt64Array()
	too_many.resize((PLAY.DRAW_COMMAND_LIMIT + 1) * 3)
	for index: int in range(0, too_many.size(), 3): too_many[index + 2] = 2147483903
	renderer._raw_chunks = {"synthetic":{-2:too_many}}
	# Swapping raw chunks directly bypasses configure, so drop the cached bins and blocks.
	renderer._chunk_bins.clear(); renderer._clear_blocks()
	renderer._configured = true
	check(not renderer._build_frame() and renderer.problem.contains("예산"), "draw budget failure does not keep a partial successful frame")
	await process_frame
	check(requested.size() == 1, "runtime rendering failure requests safe return once")
	check(not renderer._configured and renderer._frame_commands.is_empty() and renderer._blocks.is_empty(), "failed experimental display stops drawing")
	field.local_doors = {"synthetic":[Vector2i(0,0)]}
	field.local_door_states = {"synthetic":false}
	actor.global_position = point
	click.position = renderer.get_canvas_transform() * point
	renderer._unhandled_input(click)
	check(not field.local_door_states.synthetic, "failed candidate cannot toggle existing doors while return is pending")
	renderer.queue_free(); actor.queue_free()
	await process_frame
	print("CURRENT523_ADEN_PLAY_RENDERER_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"scope":"SYNTHETIC_DISPLAY_AND_GUARDS; NO_NATIVE_M_BEHAVIOR_CLAIM"}))
	quit(0 if failures.is_empty() else 1)

func _check_chunk_bins() -> void:
	var floor_lane := PackedInt64Array([-24,-24,1, -23,-23,2, 0,0,3, 489,489,4, 488,488,5, 512,512,6])
	var bins: Dictionary = PLAY._bin_chunk({-2:floor_lane, 7:PackedInt64Array([489,489,7])})
	var expected: Dictionary = {
		Vector2i(-1,-1): {-2:PackedInt32Array([0,3])},
		Vector2i(-1,0): {-2:PackedInt32Array([3])},
		Vector2i(0,-1): {-2:PackedInt32Array([3])},
		Vector2i.ZERO: {-2:PackedInt32Array([3,6,9,12]), 7:PackedInt32Array([0])},
		Vector2i(0,1): {-2:PackedInt32Array([9]), 7:PackedInt32Array([0])},
		Vector2i(1,0): {-2:PackedInt32Array([9]), 7:PackedInt32Array([0])},
		Vector2i(1,1): {-2:PackedInt32Array([9,15]), 7:PackedInt32Array([0])},
	}
	check(bins == expected, "negative and positive seams preserve packed indices, order, and layer separation")
	check(PLAY._bin_chunk({-2:PackedInt64Array()}).is_empty(), "an empty layer creates no block")


func _check_block_reference_work(renderer: Node2D) -> void:
	var tiles := CountedTiles.new()
	renderer._tile_pack = tiles
	var good: int = (7 << 8) | 1
	var bad_frame: int = (7 << 8) | 2
	var absent: int = (8 << 8) | 1
	var first: PackedInt64Array = PackedInt64Array()
	var expected: PackedInt64Array = PackedInt64Array()
	for index: int in 512:
		first.append_array(PackedInt64Array([index, 0, good, index, 1, bad_frame, index, 2, absent]))
		expected.append_array(PackedInt64Array([index, 0, good]))
	# Reverse member insertion order. Command ordering still follows member name.
	renderer._chunk_rects = {"z": Rect2(0, 0, 512, 32), "a": Rect2(0, 0, 512, 32)}
	renderer._raw_chunks = {"z": {-2: PackedInt64Array([0, 3, good, 0, 4, 4294967295])}, "a": {-2: first}}
	renderer._chunk_bins.clear()
	expected.append_array(PackedInt64Array([0, 3, good]))
	var block: Dictionary = renderer._block_commands(Vector2i.ZERO)
	check(block.get("commands", {}).get(-2) == expected, "exact packed commands and member order survive repeated reference validation")
	check(block.get("count") == 513 and block.get("unresolved") == 1024 and block.get("raw_ff") == 1, "memoized invalid references retain per-placement counts")
	check(tiles.tile_checks == 3 and tiles.frame_checks == 2 and tiles.loads == [7], "1537 non-sentinel placements validate only 3 distinct references and request one atlas")
	print("MAP_BLOCK_REF_COUNTS ", JSON.stringify({"placements": 1537, "tile_checks": tiles.tile_checks, "subimage_checks": tiles.frame_checks}))
	tiles.blocked_frame = -1
	tiles.fail_next_load = true
	tiles.loads.clear()
	block = renderer._block_commands(Vector2i.ZERO)
	check(block.get("count") == 1024 and block.get("unresolved") == 513 and tiles.loads == [7, 7], "next build revalidates references and a failed atlas load is retried within the block")
	renderer._chunk_bins.clear()
	renderer._raw_recent.clear()
	renderer._unresolved_logged.clear()
