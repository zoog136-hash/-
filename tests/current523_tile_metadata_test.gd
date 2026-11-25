extends SceneTree
## A verified record file with authored pixels. The reader can hold its first
## worker at the cursor while the real live-map API continues running.
const PACK = preload("res://scripts/maps/current523_tile_pack.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
var checks: int = 0
var failures: Array[String] = []

class DelayedRecords extends RefCounted:
	var records: RefCounted
	var entered := Semaphore.new()
	var release := Semaphore.new()
	var main_reads: int = 0
	var worker_reads: int = 0
	var missing_key: String = ""

	func read(key: String) -> Variant:
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			main_reads += 1
		else:
			worker_reads += 1 # All calls hold the production reader's cursor lock.
			if worker_reads == 1:
				entered.post()
				release.wait()
		return null if key == missing_key else records.read(key)

class CameraProbe extends PLAY:
	var screen: Rect2 = Rect2(0,0,320,240)
	func _view_rect() -> Rect2:
		return _arrival_view if _arrival_view.has_area() else screen

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func store_file(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)

func drain(pack: RefCounted) -> bool:
	for _frame: int in 300:
		pack.pump_gpu()
		if pack.pending_jobs() == 0: return true
		await process_frame
	return false

func camera_probe(pack: RefCounted) -> CameraProbe:
	var renderer := CameraProbe.new()
	root.add_child(renderer)
	renderer.field = PlayableField.new()
	renderer.field.set_meta("current523_source_field",true)
	renderer.player = Node2D.new()
	renderer.add_child(renderer.player)
	renderer._tile_pack = pack
	renderer._background_atlases = true
	renderer._configured = true
	return renderer

func obsolete_atlases(pack: RefCounted, reader: DelayedRecords, colors: Dictionary) -> void:
	pack._cache.clear()
	pack._recent.clear()
	var active := camera_probe(pack)
	var arrival := camera_probe(pack)
	arrival.hide()
	arrival.process_mode = Node.PROCESS_MODE_DISABLED
	var destination := Rect2(4096,0,320,240)
	var old_cell := Vector2i.ZERO
	var new_cell := Vector2i(8,0)
	# Both renderers share a pack. A covered arrival still claims its pages.
	active._prefetch_atlas(7,old_cell)
	active._prefetch_atlas(52,old_cell)
	active._prefetch_atlas(1200,old_cell)
	arrival.begin_arrival_view(destination)
	arrival._prefetch_atlas(52,new_cell)
	pack.prefetch(1200)
	check(pack.pending_jobs() == 3,"block owners and direct requests share existing decode jobs")
	active.screen = Rect2(-4096,0,320,240)
	await process_frame
	var uploads: int = pack.atlas_loads
	check(await drain(pack),"obsolete, shared, and direct worker jobs all retire")
	check(pack.atlas_loads == uploads + 2 and not pack._cache.has(7) and pack._cache.has(52) and pack._cache.has(1200),
		"only the covered arrival and the direct consumer publish")
	active.screen = Rect2(0,0,320,240)
	check(not active._prefetch_atlas(7,old_cell),"return to a previously abandoned block can request its page again")
	check(await drain(pack) and pack.atlas_loads == uploads + 3,"returning uploads one verified page")
	if DisplayServer.get_name() != "headless":
		for id: int in [7,52]:
			var texture: Texture2D = pack.texture_for(id)
			var expected := Image.create_empty(384,384,false,Image.FORMAT_RGBA8)
			expected.fill(colors[id])
			check(texture != null and texture.get_image().get_data() == expected.get_data(),"revisited and shared atlas pixels match exactly")
	reader.missing_key = "t:16777215"
	active._prefetch_atlas(16777215, old_cell)
	active.free()
	await process_frame
	check(await drain(pack) and not pack._prefetch_errors.has(16777215),"a detached owner cannot publish an obsolete error")
	reader.missing_key = ""
	arrival._prefetch_atlas(16777215,new_cell)
	check(await drain(pack) and pack.texture_for(16777215) != null,"another renderer can request a repaired page without resetting the pack")
	arrival.free()

func run() -> void:
	var pack := PACK.new()
	var ids := PackedInt32Array([7,52,1200,16777215])
	var directory := ProjectSettings.globalize_path("user://tile-metadata-worker-test")
	var name := "tile_metadata_worker_test"
	var key := "authored-png-rows".sha256_text()
	var writer := BAKE.record_writer(name,key)
	var meta: Dictionary = {"blocks":{}, "source_ids":ids, "source_sizes":PackedInt32Array(),
		"source_digests":PackedByteArray(), "atlas_storage":"png"}
	var expected: Dictionary = {}
	var colors: Dictionary = {}
	for i: int in ids.size():
		var id: int = ids[i]
		var member: String = "Tile/%d.ti2" % id
		var bytes: PackedByteArray = ("test source %d" % id).to_utf8_buffer()
		var digest: String = PACK._hash(bytes)
		var image := Image.create_empty(384,384,false,Image.FORMAT_RGBA8)
		colors[id] = Color8(40 + i * 40,172,32,128)
		image.fill(colors[id])
		var png: PackedByteArray = image.save_png_to_buffer()
		var original_path: String = "originals/" + member
		var atlas_path: String = "atlases/%d.png" % id
		store_file(directory.path_join(original_path),bytes)
		store_file(directory.path_join(atlas_path),png)
		writer.add("t:%d" % id, {"tile_id":id, "member":member, "original_path":original_path,
			"source_bytes":bytes.size(), "source_sha256":digest, "atlas_path":atlas_path,
			"atlas_bytes":png.size(), "atlas_sha256":PACK._hash(png), "atlas_rgba_sha256":PACK._hash(image.get_data())})
		meta.blocks[id] = 256
		meta.source_sizes.append(bytes.size())
		meta.source_digests.append_array(digest.hex_decode())
		expected[id] = {"member":member, "bytes":bytes.size(), "sha256":digest}
	writer.add("meta",meta)
	check(BAKE.finish_records(writer),"authored record file commits atomically")
	var reader := DelayedRecords.new()
	reader.records = BAKE.open_records(name,key)
	check(reader.records != null,"real record file passes its size and SHA check")
	if reader.records == null:
		quit(1)
		return
	var index: Dictionary = reader.records.read("meta")
	check(PACK._valid_index(index),"sparse literal IDs survive the compact index round trip")
	var invalid: Dictionary = index.duplicate()
	invalid.source_ids = PackedInt32Array([7,1200,52,16777215])
	check(not PACK._valid_index(invalid),"unordered or mismatched index cannot provide evidence")
	invalid.source_ids = ids
	invalid.source_digests = PackedByteArray()
	check(not PACK._valid_index(invalid),"truncated identity table is refused")
	pack._records = reader
	pack._blocks = index.blocks
	pack._source_ids = index.source_ids
	pack._source_sizes = index.source_sizes
	pack._source_digests = index.source_digests
	pack._root = directory
	pack.loaded = true
	pack.background_only = true
	pack.compress_for_gpu = false
	for id: int in ids:
		check(not pack.prefetch(id) and not pack.prefetch(id),"duplicate offers queue only one decode for %d" % id)
	var entered: bool = false
	for _frame: int in 120:
		entered = reader.entered.try_wait()
		if entered: break
		await process_frame
	check(entered and pack.pending_jobs() == ids.size(),"a worker is blocked and all other tickets were submitted")
	for _frame: int in 3:
		pack.pump_gpu()
		check(pack.texture_for(ids[0]) == null and pack.atlas_loads == 0,"foreground pump and acquire return while the metadata cursor is held")
		await process_frame
	var exact: bool = pack.source_usage_identity(1).is_empty()
	for id: int in ids: exact = exact and pack.source_usage_identity(id) == expected[id]
	check(exact and reader.main_reads == 0,"identity lookups use only the verified index while a worker owns the cursor")
	reader.release.post()
	check(await drain(pack),"all delayed rows eventually reach publication")
	check(reader.main_reads == 0 and reader.worker_reads == ids.size() and pack.atlas_loads == ids.size(),"one worker metadata read per distinct atlas")
	var shown: bool = true
	for id: int in ids:
		var texture: Texture2D = pack.texture_for(id)
		if texture == null: shown = false
		elif DisplayServer.get_name() != "headless":
			shown = shown and texture.get_image().get_pixel(3,5).to_rgba32() == (colors[id] as Color).to_rgba32()
	check(shown,"each published texture belongs to its own row, including alpha on a rendering display")
	await obsolete_atlases(pack,reader,colors)
	pack._cache.clear()
	pack._recent.clear()
	reader.missing_key = "t:52"
	pack.prefetch(52)
	check(await drain(pack) and pack.texture_for(52) == null and pack.problem.contains("metadata row"),"missing record becomes a terminal atlas failure")
	reader.missing_key = ""
	pack.release_held()
	pack.prefetch(52)
	check(await drain(pack) and pack.texture_for(52) != null,"a repaired row retries in the next batch")
	pack.background_only = false
	check(pack.texture_for(7) != null and reader.main_reads == 1,"explicit synchronous lookup retains its normal behavior")
	pack.background_only = true
	pack.prefetch(1200)
	check(not pack.load_pack(directory.path_join("absent"),key) and pack.pending_jobs() == 0 and pack.cache_size() == 0,"pack replacement discards outstanding results")
	check(pack.source_usage_identity(1200).is_empty() and pack._source_digests.is_empty(),"a failed replacement cannot expose the old pack's identities")
	pack = null
	reader.records = null
	BAKE.clear(name)
	print("TILE_METADATA_WORK_RESULT ",JSON.stringify({"checks":checks, "failures":failures, "synthetic":true}))
	quit(0 if failures.is_empty() else 1)
