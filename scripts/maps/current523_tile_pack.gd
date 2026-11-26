extends RefCounted
## Generic caller-pinned current M523 TI2 subset, independent of Land/AssetPath.
## This is stored-pixel coverage only; native M alpha/compositing remain UNKNOWN.
const MANIFEST_NAME = "tilepack523.json"
const MAX_CACHED_ATLASES = 32
const MAX_SOURCE_BYTES = 8 * 1024 * 1024
const MAX_PNG_BYTES = 2 * 1024 * 1024
const MAX_METADATA_BYTES = 64 * 1024 * 1024
const MAX_TILES = 20000
const TI2_DECODER = preload("res://scripts/maps/current523_ti2_decoder.gd")
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
## Atlases are swapped to GPU block compression off the main thread.
const TILE_GPU = preload("res://scripts/maps/current523_tile_gpu.gd")
var gpu := TILE_GPU.new()
## Compress decoded atlases for the GPU (ETC2/S3TC on a worker, then a second
## upload). Off for the 523 play map: it bakes atlases into ground blocks and
## lets go of them, so compressing them was worker CPU (heat) and a main-thread
## re-upload for a texture no longer drawn.
var compress_for_gpu: bool = true
## Keep every published atlas (also past MAX_CACHED_ATLASES) until
## release_held(). The 523 play map asks for all atlases of the blocks it is
## about to bake (~90 on one screen) and bakes once they are decoded; with only
## the 32-atlas cache the first ones were evicted again before the bake and
## decoded a second time on the main thread (523.704: map.block_atlas_acquire
## 1453 ms x90 in one frame).
var hold_published: bool = false
var _held: Dictionary = {}
## The live map polls readiness before taking an atlas. A pending atlas must
## never turn into a blocking worker join or inline decode in that renderer.
var background_only: bool = false
var _prefetch_errors: Dictionary = {}
const SEMANTICS = {"geometry":"CANDIDATE_24X24", "palette":"CANDIDATE_RGB565", "coverage_alpha":"STORED_255_UNSTORED_0", "runtime_alpha":"UNKNOWN", "coordinates":"UNKNOWN", "projection":"UNKNOWN", "layers":"UNKNOWN", "movement":"UNKNOWN", "collision":"UNKNOWN"}
var problem: String = ""
var loaded: bool = false
var atlas_loads: int = 0
var _root: String = ""
var _manifest_sha256: String = ""
var _atlas_storage: String = "png"
var _tiles: Dictionary = {}
## After the first verified load the tile rows live in a device-local record
## bake (keyed by the manifest pin and this script). Keep the subimage counts
## and the small source identities needed by a visible draw in memory.
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
static var bake_enabled: bool = true
var _records: RefCounted
# RecordFile owns one verified open file. Serialize only its seek/get_var;
# worker jobs decode their own rows independently after releasing the cursor.
var _record_cursor := Mutex.new()
var _blocks: Dictionary = {}
# Sorted literal IDs, original byte lengths and 32 digest bytes per ID.
# 40 bytes per manifest tile, independent of travel and texture eviction.
const DIGEST_BYTES := 32
var _source_ids := PackedInt32Array()
var _source_sizes := PackedInt32Array()
var _source_digests := PackedByteArray()
var _cache: Dictionary = {}
var _recent: Array[int] = []
## tile_id -> {task, decode, optional claims}. Claims stay on the main thread.
var _jobs: Dictionary = {}
## Worker decodes in flight at once (each holds ~1.2 MiB while decoding).
const MAX_DECODE_JOBS: int = 8
const MAX_CLAIM_OWNERS: int = 4
const MAX_CLAIM_BLOCKS: int = 64

## Publication is counted by engine process frame, not pump invocation: a
## frame may call pump_gpu, texture_for and pump_jobs many times. Keep the
## first ready result progressing; a single driver upload is not preemptible.
const MAX_PUBLISH_PER_FRAME: int = 2
const PUBLISH_BUDGET_USEC: int = 2000
var _publish_frame: int = -1
var _published_this_frame: int = 0
var _completed_atlases := PackedInt32Array()
var _publish_usec: int = 0
var _publish_sequence: int = 0
var _priority: Dictionary = {} # tile ID -> last visible request frame

## Optional renderer hint; legacy packs need not implement it. Priority lasts
## through the next frame's pump. Every fourth result is oldest-ready so a
## stream of visible requests cannot starve other completed decodes.
func prioritize(tile_id: int) -> void:
	_priority[tile_id] = Engine.get_process_frames()
	var texture: Texture2D = _cache.get(tile_id, _held.get(tile_id))
	if compress_for_gpu and texture is ImageTexture: gpu.prioritize(texture)

func _fail(message: String) -> bool:
	problem = message
	return false

func load_pack(directory: String, expected_manifest_sha256: String) -> bool:
	loaded = false
	_root = ""
	_manifest_sha256 = ""
	_atlas_storage = "png"
	_tiles.clear()
	_blocks.clear()
	_source_ids = PackedInt32Array()
	_source_sizes = PackedInt32Array()
	_source_digests = PackedByteArray()
	_records = null
	_cache.clear()
	_recent.clear()
	_held.clear()
	_prefetch_errors.clear()
	_completed_atlases.clear()
	_priority.clear()
	_drop_jobs()
	problem = ""
	atlas_loads = 0
	if not _sha(expected_manifest_sha256): return _fail("A caller-pinned generic TI2 manifest SHA256 is required")
	var file := FileAccess.open(directory.path_join(MANIFEST_NAME), FileAccess.READ)
	if file == null or file.get_length() < 2 or file.get_length() > MAX_METADATA_BYTES:
		return _fail("Missing or oversized generic TI2 manifest")
	var encoded: PackedByteArray = file.get_buffer(file.get_length())
	if _hash(encoded) != expected_manifest_sha256: return _fail("Generic TI2 manifest differs from caller SHA256 pin")
	var bake_name: String = bake_name_for(expected_manifest_sha256)
	var bake_key: String = bake_key_for(expected_manifest_sha256) if bake_enabled else ""
	var baked: RefCounted = BAKE.open_records(bake_name, bake_key) if not bake_key.is_empty() else null
	if baked != null:
		var meta: Variant = baked.read("meta")
		if meta is Dictionary and _valid_index(meta):
			_root = directory
			_atlas_storage = meta.atlas_storage
			_blocks = meta.blocks
			_source_ids = meta.source_ids
			_source_sizes = meta.source_sizes
			_source_digests = meta.source_digests
			_records = baked
			_manifest_sha256 = expected_manifest_sha256
			loaded = true
			return true
	var parsed: Variant = JSON.parse_string(encoded.get_string_from_utf8())
	encoded = PackedByteArray()
	if not parsed is Dictionary: return _fail("Invalid generic TI2 manifest")
	if not _uint(parsed.get("schema"), 1) or int(parsed.schema) != 1 or parsed.get("kind") != "current523_ti2_subset_pack" or parsed.get("edition") != "LineageM" or not _uint(parsed.get("cumulative_version"), 523) or int(parsed.cumulative_version) != 523 or parsed.get("source_root") != "Tile/":
		return _fail("Generic TI2 pack must be current M cumulative523")
	if parsed.get("status") != "DISPLAY_HYPOTHESIS_COVERAGE_V1" or parsed.get("semantics") != SEMANTICS or parsed.get("raw_decoded_roundtrip") != true or parsed.get("delivery_status") != "PRIVATE_LOCAL_ONLY":
		return _fail("Unsupported generic TI2 coverage or delivery claim")
	var storage: Variant = parsed.get("atlas_storage", "png")
	if not storage is String or storage not in ["png", "runtime_ti2"]: return _fail("Unsupported generic TI2 atlas storage")
	if not _sha(parsed.get("input_inventory_sha256")) or not _sha(parsed.get("input_source_inventory_sha256")) or not _sha(parsed.get("raw_model_inventory_sha256")) or not _uint(parsed.get("input_source_count"), MAX_TILES) or not _uint(parsed.get("source_count"), MAX_TILES) or int(parsed.source_count) < 1 or int(parsed.input_source_count) < int(parsed.source_count):
		return _fail("Invalid generic TI2 source inventory identity")
	var rows: Variant = parsed.get("tiles")
	if not rows is Array or rows.size() != int(parsed.source_count): return _fail("Generic TI2 subset count mismatch")
	var candidate: Dictionary = {}
	var source_lines: Array[String] = []
	var rgba_lines: Array[String] = []
	for value: Variant in rows:
		if not value is Dictionary or not _uint(value.get("tile_id"), 16777215): return _fail("Invalid literal TI2 ID")
		var id: int = int(value.tile_id)
		var member: String = "Tile/" + str(id) + ".ti2"
		if candidate.has(id) or value.get("member") != member or value.get("original_path") != "originals/" + member:
			return _fail("Unsafe or duplicate generic TI2 path")
		for field: String in ["source_sha256", "decoded_sha256", "atlas_rgba_sha256", "palette_u16le_sha256"]:
			if not _sha(value.get(field)): return _fail("Invalid generic TI2 digest")
		if storage == "png":
			if value.get("atlas_path") != "atlases/" + str(id) + ".png" or not _sha(value.get("atlas_sha256")) or not _uint(value.get("atlas_bytes"), MAX_PNG_BYTES) or int(value.atlas_bytes) < 33: return _fail("Unsupported generic TI2 PNG storage")
		else:
			for field: String in ["atlas_path", "atlas_bytes", "atlas_sha256"]:
				if value.has(field): return _fail("Runtime TI2 storage cannot declare a PNG resource")
		if not _uint(value.get("source_bytes"), MAX_SOURCE_BYTES) or int(value.source_bytes) < 1 or not supported_layout(value) or not _raw_evidence(value):
			return _fail("Unsupported generic TI2 raw or atlas layout")
		if not _provenance(value.get("provenance"), value.source_sha256): return _fail("TI2 member lacks exact current523 selection provenance")
		candidate[id] = value.duplicate(true)
		source_lines.append(member + "\t" + str(int(value.source_bytes)) + "\t" + str(value.source_sha256) + "\n")
		rgba_lines.append(member + "\t" + str(value.atlas_rgba_sha256) + "\n")
	source_lines.sort()
	rgba_lines.sort()
	if "".join(source_lines).sha256_text() != parsed.get("source_inventory_sha256"): return _fail("Generic TI2 source inventory mismatch")
	if "".join(rgba_lines).sha256_text() != parsed.get("atlas_rgba_inventory_sha256"): return _fail("Generic TI2 coverage inventory mismatch")
	if int(parsed.input_source_count) == int(parsed.source_count) and parsed.input_source_inventory_sha256 != parsed.source_inventory_sha256: return _fail("Whole input and included source inventories disagree")
	_root = directory
	_atlas_storage = storage
	_tiles = candidate
	_source_ids = PackedInt32Array(candidate.keys())
	_source_ids.sort()
	for id: int in _source_ids:
		var row: Dictionary = candidate[id]
		_blocks[id] = int(row.blocks)
		_source_sizes.append(int(row.source_bytes))
		_source_digests.append_array(str(row.source_sha256).hex_decode())
	_manifest_sha256 = expected_manifest_sha256
	loaded = true
	if not bake_key.is_empty():
		var writer: RefCounted = BAKE.record_writer(bake_name, bake_key)
		if writer != null:
			for id: int in candidate: writer.add("t:%d" % id, candidate[id])
			writer.add("meta", {"atlas_storage":storage, "blocks":_blocks, "source_ids":_source_ids,
				"source_sizes":_source_sizes, "source_digests":_source_digests})
			if BAKE.finish_records(writer):
				var records: RefCounted = BAKE.open_records(bake_name, bake_key)
				if records != null:
					_records = records
					_tiles = {}
	return true

static func bake_name_for(manifest_sha: String) -> String:
	return "current523_tile_pack_" + manifest_sha.left(16)

static func bake_key_for(manifest_sha: String) -> String:
	return BAKE.key(["current523_tile_pack.v1", manifest_sha, BAKE.code_key(["res://scripts/maps/current523_tile_pack.gd"])])

## True when this device already holds the tile rows for this pin.
static func baked(manifest_sha: String) -> bool:
	return BAKE.present(bake_name_for(manifest_sha), bake_key_for(manifest_sha))

static func _valid_index(meta: Dictionary) -> bool:
	if meta.get("atlas_storage") not in ["png", "runtime_ti2"] or not meta.get("blocks") is Dictionary: return false
	if not meta.get("source_ids") is PackedInt32Array or not meta.get("source_sizes") is PackedInt32Array: return false
	if not meta.get("source_digests") is PackedByteArray: return false
	var ids: PackedInt32Array = meta.source_ids
	var sizes: PackedInt32Array = meta.source_sizes
	var blocks: Dictionary = meta.blocks
	if ids.is_empty() or ids.size() > MAX_TILES or ids.size() != blocks.size(): return false
	if sizes.size() != ids.size() or meta.source_digests.size() != ids.size() * DIGEST_BYTES: return false
	var previous: int = -1
	for slot: int in ids.size():
		var id: int = ids[slot]
		if id <= previous or id > 16777215 or not blocks.has(id): return false
		if sizes[slot] <= 0 or sizes[slot] > MAX_SOURCE_BYTES: return false
		previous = id
	return true

func verified_identity() -> Dictionary:
	return {"root":_root,"manifest_sha256":_manifest_sha256} if loaded else {}

func matches_manifest(directory: String, expected_sha256: String) -> bool:
	if not loaded or directory!=_root or expected_sha256!=_manifest_sha256: return false
	var file:=FileAccess.open(directory.path_join(MANIFEST_NAME),FileAccess.READ)
	if file==null or file.get_length()<2 or file.get_length()>MAX_METADATA_BYTES: return false
	return _hash(file.get_buffer(file.get_length()))==expected_sha256

func has_tile(tile_id: int) -> bool:
	return loaded and _blocks.has(tile_id)

func source_usage_identity(tile_id: int) -> Dictionary:
	if not has_tile(tile_id):return {}
	var slot: int = _source_ids.bsearch(tile_id)
	if slot >= _source_ids.size() or _source_ids[slot] != tile_id: return {}
	var offset: int = slot * DIGEST_BYTES
	# The pinned manifest validates the exact literal member name at load.
	return {"member":"Tile/%d.ti2" % tile_id, "bytes":_source_sizes[slot],
		"sha256":_source_digests.slice(offset,offset + DIGEST_BYTES).hex_encode()}

func has_subimage(tile_id: int, frame8bit: int) -> bool:
	return has_tile(tile_id) and frame8bit>=0 and frame8bit<int(_blocks[tile_id])

func texture_for(tile_id: int) -> Texture2D:
	problem = ""
	gpu.pump()
	if not has_tile(tile_id):
		_fail("Unresolved original Tile/" + str(tile_id) + ".ti2")
		return null
	if _cache.has(tile_id):
		_recent.erase(tile_id)
		_recent.append(tile_id)
		return _cache[tile_id]
	if _held.has(tile_id): return _held[tile_id]
	if background_only:
		_fail(str(_prefetch_errors.get(tile_id, "Original atlas is still pending")))
		return null
	var pending: Dictionary = _jobs.get(tile_id, {})
	var job: Dictionary
	if pending.is_empty():
		job = _new_job(tile_id)
		_decode_job(job)
	else:
		# Already decoding on a worker: wait for that one result.
		WorkerThreadPool.wait_for_task_completion(int(pending.task))
		job = pending.decode
		_jobs.erase(tile_id)
	return _publish(tile_id, job)

## Starts reading and decoding `tile_id` on a worker thread when it is not
## cached yet; true when its texture is ready now. Reading, the SHA-256 pins
## and the TI2/PNG decode are the same as texture_for; only the texture is
## made on the main thread (pump_jobs). A miss used to stall the frame for
## the whole decode (about 15 ms per atlas on a PC, ~60 ms on the phone).
func prefetch(tile_id: int) -> bool:
	return _offer_atlas(tile_id, 0, Vector2i.ZERO)

## A shared pack may service the active map and a covered arrival at once.
## Attach each block's demand to the existing decode, without owning the node.
func prefetch_for_block(tile_id: int, renderer: Node, cell: Vector2i) -> bool:
	return _offer_atlas(tile_id, renderer.get_instance_id(), cell)

func _offer_atlas(tile_id: int, owner: int, cell: Vector2i) -> bool:
	if _cache.has(tile_id) or _held.has(tile_id): return true
	# Ready means the request finished, including a verified read failure.
	# The block assembler can then report it and skip only the failed tiles.
	if background_only and _prefetch_errors.has(tile_id): return true
	if not _jobs.has(tile_id):
		if not has_tile(tile_id) or _jobs.size() >= MAX_DECODE_JOBS: return false
		var decode: Dictionary = _new_job(tile_id)
		var task: int = WorkerThreadPool.add_task(_decode_job.bind(decode), false, "TI2 atlas decode")
		_jobs[tile_id] = {"task": task, "decode": decode}
		if owner != 0: _jobs[tile_id].claims = {}
	var pending: Dictionary = _jobs[tile_id]
	if pending.has("claims"):
		var claims: Dictionary = pending.claims
		var cells: Variant = claims.get(owner)
		# An ordinary/tool request or unusually large view keeps its result.
		if owner == 0 or (cells == null and claims.size() >= MAX_CLAIM_OWNERS) \
			or (cells != null and cells.size() >= MAX_CLAIM_BLOCKS and not cells.has(cell)):
			pending.erase("claims")
		elif cells == null:
			claims[owner] = {cell: true}
		else:
			cells[cell] = true
	return false

func _still_requested(pending: Dictionary, views: Dictionary) -> bool:
	if not pending.has("claims"): return true
	for owner: int in pending.claims:
		if not views.has(owner):
			var renderer: Object = instance_from_id(owner)
			views[owner] = renderer.atlas_request_bounds() if is_instance_valid(renderer) else Rect2i()
		var bounds: Rect2i = views[owner]
		for cell: Vector2i in pending.claims[owner]:
			if bounds.has_point(cell): return true
	return false

## Publishes completed decodes within a shared per-frame allowance. Returns
## completed results (including diagnosed failures); never waits for a decode.
func pump_jobs() -> int:
	var frame: int = Engine.get_process_frames()
	if _publish_frame != frame:
		_publish_frame = frame
		_published_this_frame = 0
		_completed_atlases.clear()
		_publish_usec = 0
		for tile_id: int in _priority.keys():
			if int(_priority[tile_id]) < frame - 1: _priority.erase(tile_id)
	var done: int = 0
	if _jobs.is_empty(): return done
	var views: Dictionary = {}
	while not _jobs.is_empty() and _published_this_frame < MAX_PUBLISH_PER_FRAME and (_published_this_frame == 0 or _publish_usec < PUBLISH_BUDGET_USEC):
		var selected: int = -1
		for tile_id: int in _jobs.keys():
			var job: Dictionary = _jobs[tile_id]
			if not WorkerThreadPool.is_task_completed(int(job.task)): continue
			if not _still_requested(job, views):
				# This slot is released without a texture, failure, or upload
				# budget charge. A later request can read the same pinned bytes.
				WorkerThreadPool.wait_for_task_completion(int(job.task))
				_jobs.erase(tile_id)
				FRAME_HITCH.count("map.atlas_obsolete")
				continue
			if selected < 0: selected = tile_id
			if _publish_sequence % 4 == 3: break
			if int(_priority.get(tile_id, -2)) >= frame - 1:
				selected = tile_id
				break
		if selected < 0: break
		var started: int = Time.get_ticks_usec()
		var pending: Dictionary = _jobs[selected]
		WorkerThreadPool.wait_for_task_completion(int(pending.task))
		_jobs.erase(selected)
		var saved: String = problem
		var texture: Texture2D = _publish(selected, pending.decode)
		if background_only and texture == null: _prefetch_errors[selected] = problem
		problem = saved
		_publish_usec += Time.get_ticks_usec() - started
		_published_this_frame += 1
		_completed_atlases.append(selected)
		_publish_sequence += 1
		done += 1
	return done

## Includes terminal failures. Read-only and frame-scoped so a candidate
## and active renderer can both react without changing the upload allowance.
func completed_atlases_this_frame() -> PackedInt32Array:
	return _completed_atlases if _publish_frame == Engine.get_process_frames() else PackedInt32Array()


## Waits for and discards every worker decode (a new pack or teardown).
func _drop_jobs() -> void:
	for job: Dictionary in _jobs.values(): WorkerThreadPool.wait_for_task_completion(int(job.task))
	_jobs.clear()

func _notification(what: int) -> void:
	# No method calls while this object is being deleted.
	if what == NOTIFICATION_PREDELETE:
		for job: Dictionary in _jobs.values(): WorkerThreadPool.wait_for_task_completion(int(job.task))
		_jobs.clear()

func pending_jobs() -> int:
	return _jobs.size()

func _new_job(tile_id: int) -> Dictionary:
	var job: Dictionary = {"tile_id": tile_id, "root": _root, "storage": _atlas_storage, "image": null, "problem": ""}
	if _records == null:
		job.row = _tiles[tile_id]
	else:
		job.records = _records
		job.cursor = _record_cursor
	return job

## The live map only enqueues this work. Direct synchronous tools use the
## same verified reader and byte checks. Never reopen an unverified path
## to the bake or share the file cursor without the lock.
static func _decode_job(job: Dictionary) -> void:
	var row: Dictionary
	if job.has("records"):
		var cursor: Mutex = job.cursor
		cursor.lock()
		var value: Variant = job.records.read("t:%d" % int(job.tile_id))
		cursor.unlock()
		if not value is Dictionary or value.get("tile_id") != job.tile_id:
			job.problem = "Missing or mismatched verified TI2 metadata row"
			return
		row = value
	else:
		row = job.row
	var source := FileAccess.open(str(job.root).path_join(str(row.original_path)), FileAccess.READ)
	if source == null or source.get_length() != int(row.source_bytes):
		job.problem = "Missing or wrong-sized original TI2"; return
	var compressed: PackedByteArray = source.get_buffer(int(row.source_bytes))
	if _hash(compressed) != row.source_sha256:
		job.problem = "Original TI2 digest mismatch"; return
	if job.storage == "runtime_ti2":
		var decoder = TI2_DECODER.new()
		# Coverage is checked against its pin first; the drawn atlas then
		# carries the TI2 block flags' display alpha.
		var rgba: PackedByteArray = decoder.decode_rgba(compressed, row, true)
		if rgba.size() != 384 * 384 * 4:
			job.problem = decoder.problem; return
		job.image = Image.create_from_data(384, 384, false, Image.FORMAT_RGBA8, rgba)
		return
	var png := FileAccess.open(str(job.root).path_join(str(row.atlas_path)), FileAccess.READ)
	if png == null or png.get_length() != int(row.atlas_bytes):
		job.problem = "Missing or wrong-sized generic coverage atlas"; return
	var encoded: PackedByteArray = png.get_buffer(int(row.atlas_bytes))
	if _hash(encoded) != row.atlas_sha256:
		job.problem = "Generic coverage PNG digest mismatch"; return
	if not bounded_png_header(encoded):
		job.problem = "Generic coverage PNG header exceeds supported layout"; return
	var image := Image.new()
	if image.load_png_from_buffer(encoded) != OK or image.get_size() != Vector2i(384, 384):
		job.problem = "Invalid generic coverage atlas image"; return
	image.convert(Image.FORMAT_RGBA8)
	if _hash(image.get_data()) != row.atlas_rgba_sha256:
		job.problem = "Generic coverage decoded RGBA digest mismatch"; return
	job.image = image

func _publish(tile_id: int, job: Dictionary) -> Texture2D:
	if job.image == null:
		_fail(str(job.problem))
		return null
	var image: Image = job.image
	var texture := ImageTexture.create_from_image(image)
	# The decoded image is not used after this; the worker may change it.
	if compress_for_gpu:
		gpu.queue(texture, image, false)
		if int(_priority.get(tile_id, -2)) >= Engine.get_process_frames() - 1: gpu.prioritize(texture)
		gpu.pump()
	atlas_loads += 1
	_cache[tile_id] = texture
	_recent.append(tile_id)
	if hold_published: _held[tile_id] = texture
	while _recent.size() > MAX_CACHED_ATLASES:
		_cache.erase(_recent.pop_front())
	return texture

func cache_size() -> int:
	return _cache.size()

## Lets go of the atlases kept by hold_published.
func release_held() -> void:
	_held.clear()
	# Failed files can be tried again in the next set of block requests.
	_prefetch_errors.clear()

func held_size() -> int:
	return _held.size()

## Called every frame by the map renderer: applies finished compressions.
func pump_gpu() -> void:
	gpu.pump()
	pump_jobs()

static func source_rect(frame8bit: int) -> Rect2:
	if frame8bit < 0 or frame8bit > 255: return Rect2()
	return Rect2((frame8bit % 16) * 24, floori(float(frame8bit) / 16.0) * 24, 24, 24)

static func supported_layout(row: Dictionary) -> bool:
	var size: Variant = row.get("atlas_size")
	return _uint(row.get("blocks"), 256) and int(row.blocks) >= 1 and size is Array and size.size() == 2 and _uint(size[0], 384) and _uint(size[1], 384) and int(size[0]) == 384 and int(size[1]) == 384

static func bounded_png_header(encoded: PackedByteArray) -> bool:
	if encoded.size() < 33 or encoded.size() > MAX_PNG_BYTES or encoded.slice(0, 16) != PackedByteArray([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82]): return false
	var width: int = (int(encoded[16]) << 24) | (int(encoded[17]) << 16) | (int(encoded[18]) << 8) | int(encoded[19])
	var height: int = (int(encoded[20]) << 24) | (int(encoded[21]) << 16) | (int(encoded[22]) << 8) | int(encoded[23])
	return width == 384 and height == 384 and encoded[24] == 8 and encoded[25] == 6 and encoded[26] == 0 and encoded[27] == 0 and encoded[28] == 0

static func _raw_evidence(row: Dictionary) -> bool:
	if not _uint(row.get("decoded_bytes"), MAX_SOURCE_BYTES) or int(row.decoded_bytes) < 4 or not _uint(row.get("raw_header_u32"), 4294967295) or (int(row.raw_header_u32) & 4095) != int(row.get("blocks",0)) or (int(row.raw_header_u32) & 4096) == 0 or row.get("raw_decoded_roundtrip") != true:
		return false
	if not _uint(row.get("stored_pixels"), 256 * 576) or not _uint(row.get("palette_colors"), 256) or int(row.palette_colors) < 1: return false
	var sections: Variant = row.get("raw_sections")
	if not sections is Dictionary or sections.size() != 5: return false
	var end: int = 0
	for name: String in ["header", "palette", "flags", "descriptors", "indices"]:
		var section: Variant = sections.get(name)
		if not section is Dictionary or not _uint(section.get("offset"), MAX_SOURCE_BYTES) or int(section.offset) != end or not _uint(section.get("bytes"), MAX_SOURCE_BYTES) or not _sha(section.get("sha256")): return false
		end += int(section.bytes)
	return end == int(row.decoded_bytes) and int(sections.header.bytes) == 4 and int(sections.palette.bytes) == 1 + 2 * int(row.palette_colors) and int(sections.flags.bytes) == int(row.blocks) and int(sections.indices.bytes) == int(row.stored_pixels)

static func _provenance(value: Variant, source_sha256: String) -> bool:
	if not value is Dictionary or value.get("edition") != "LineageM" or not _uint(value.get("snapshot_version"), 523) or int(value.snapshot_version) != 523 or value.get("current_selection_verified") != true or not _uint(value.get("selection_version"), 523) or int(value.selection_version) < 1: return false
	if value.get("expected_member_sha256") != source_sha256 or not _sha(value.get("source_dat_sha256")) or not _sha(value.get("current_selected_dat_sha256")): return false
	if value.source_dat_sha256 != value.current_selected_dat_sha256:
		var proof: Variant = value.get("current_member_identity_proof")
		if not proof is Dictionary or proof.get("kind") != "EXACT_CURRENT523_MEMBER_SHA256" or proof.get("member_sha256") != source_sha256 or not _sha(proof.get("current_index_sha256")) or proof.current_index_sha256 == "0".repeat(64): return false
	var container: Variant = value.get("container")
	var evidence: Variant = value.get("evidence_level")
	if not container is String or not evidence is String or evidence.is_empty() or evidence.length() > 256: return false
	if not container.begins_with("Client/Data/Tile") or not container.ends_with(".dat"): return false
	var number: String = container.trim_prefix("Client/Data/Tile").trim_suffix(".dat")
	return not number.is_empty() and number[0] != "0" and number.is_valid_int() and str(number.to_int()) == number and number.to_int() > 0

static func _uint(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= float(maximum) and float(value) == floor(float(value))

static func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if not "0123456789abcdef".contains(character): return false
	return true

static func _hash(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
