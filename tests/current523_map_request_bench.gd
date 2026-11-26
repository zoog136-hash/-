extends SceneTree
## Optional Linux/OpenGL A/B. Pass --baseline-renderer and --baseline-field
## pointing to the two scripts extracted from the base commit with git show.
## --fixture and --fixture-sha use the existing 35-tile PNG runtime_fixture
## with a fresh texture cache per arrival instead of resident test textures.
## --baseline-tiles enables the rapid-travel replay with seven finished
## decodes for the abandoned view and a cold destination.
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const FIXTURE = preload("res://tests/current523_aden_play_renderer_test.gd")
const TILES = preload("res://scripts/maps/current523_tile_pack.gd")
const MEMBER = "Map/test/00000000.s32"
const VIEW = Rect2(960,512,448,320)

class Catalog extends "res://scripts/maps/current523_source_pack.gd":
	var payload: Dictionary
	func read_member_job(_member: String) -> Dictionary: return payload

class ResidentTiles extends RefCounted:
	var images: Dictionary = {}
	func has_tile(id: int) -> bool: return images.has(id)
	func prefetch(id: int) -> bool: return has_tile(id)
	func texture_for(id: int) -> Texture2D: return images.get(id)
	func cache_size() -> int: return images.size()

var source := Catalog.new()
var tiles := ResidentTiles.new()
var fixture: String
var fixture_sha: String
var baseline_tiles: Script

func _initialize() -> void: run.call_deferred()

func make_input() -> void:
	source.loaded = true
	source.payload = FIXTURE.FakeChunkSources.new().read_member_job(MEMBER)
	var words: PackedByteArray = source.payload.sections.floor
	# Only subimages 0 and 1 contain painted pixels in the authored PNG fixture.
	var disk_fixture: bool = not fixture.is_empty()
	for i: int in 8192:
		var subimage: int = ((i >> 3) & 1) if disk_fixture else (i & 255)
		words.encode_u32(i * 4, 4294967295 if i % 23 == 0 else ((1 + i % 8) << 8) | subimage)
	source.payload.sections.floor = words
	if not fixture.is_empty(): return
	for id: int in range(1,9):
		var image := Image.create_empty(384,384,false,Image.FORMAT_RGBA8)
		for frame: int in 256:
			image.fill_rect(Rect2i(TILES.source_rect(frame)), Color8((id*23)%256,frame,(frame*7)%256,128 if frame%3==0 else 255))
		tiles.images[id] = ImageTexture.create_from_image(image)

func time_arrival(renderer: Node2D) -> Dictionary:
	# Start both sides at the same display boundary. Let Godot run the
	# normal _process, including its elapsed-time budget, before drawing.
	await RenderingServer.frame_post_draw
	var began: int = Time.get_ticks_usec()
	renderer.begin_arrival_view(VIEW)
	renderer.set_process(true)
	var first: int = -1
	var frames: int = 0
	var previous: int = began
	var max_gap: int = 0
	var uploads: int = -1
	for tick: int in 120:
		await RenderingServer.frame_post_draw
		var presented_at: int = Time.get_ticks_usec()
		# Let all post-draw callbacks mark their blocks before checking. The
		# next process_frame signal fires before the next renderer _process.
		await process_frame
		if first < 0: max_gap = maxi(max_gap,presented_at - previous)
		previous = presented_at
		if first < 0 and renderer.is_ground_ready(VIEW):
			first = presented_at - began
			frames = tick + 1
			if not fixture.is_empty(): uploads = renderer._tile_pack.atlas_loads
		if first >= 0 and renderer._pending_blocks.is_empty():
			renderer.set_process(false)
			return {"usec":first,"frames":frames,"max_gap":max_gap,"uploads":uploads}
	renderer.set_process(false)
	return {}

func painted_ground(renderer: Node2D) -> Dictionary:
	var pixels := HashingContext.new()
	pixels.start(HashingContext.HASH_SHA256)
	var commands: Array = []
	# VIEW crosses the two nonempty destination blocks at row one.
	for x: int in range(1,3):
		var block: Dictionary = renderer._blocks[Vector2i(x,1)]
		var image: Image = block.viewport.get_texture().get_image()
		if not image.get_used_rect().has_area(): return {}
		pixels.update(image.get_data())
		commands.append(block.commands)
	return {"pixels":pixels.finish().hex_encode(),"commands":TILES._hash(var_to_bytes(commands))}

func stage_abandoned_requests(renderer: Node2D) -> void:
	var cell := Vector2i(-20,0)
	renderer._arrival_view = Rect2(Vector2(cell * PLAY.BLOCK),VIEW.size)
	var pack: RefCounted = renderer._tile_pack
	for id: int in range(21,28):
		if renderer.has_method("_prefetch_atlas"): renderer._prefetch_atlas(id,cell)
		else: pack.prefetch(id)
	# Stage completed CPU decodes, without running either renderer or doing
	# any upload, for the same queue contents in each replay.
	for job: Dictionary in pack._jobs.values():
		while not WorkerThreadPool.is_task_completed(int(job.task)):
			await process_frame

func sample(play: Script, field_script: Script, pack_script: Script) -> Dictionary:
	var renderer = play.new()
	root.add_child(renderer)
	renderer.field = field_script.new()
	renderer.field.loaded = true
	renderer.field._raw = source
	renderer.field.availability = {"source_count":source._members.size()}
	renderer.field.set_meta("current523_generic_field",true)
	renderer.field.set_meta("current523_source_field",true)
	renderer.field.coordinates.configure([32448,32064],[1856,1536],{"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,768]})
	renderer.player = Node2D.new()
	renderer.add_child(renderer.player)
	renderer._raw_sources = source
	if fixture.is_empty():
		renderer._tile_pack = tiles
	else:
		var pack: RefCounted = pack_script.new()
		if not pack.load_pack(fixture,fixture_sha):
			printerr(pack.problem)
			renderer.free()
			return {}
		pack.compress_for_gpu = false
		pack.hold_published = true
		pack.background_only = true
		renderer._tile_pack = pack
	renderer._member_origins[MEMBER] = PLAY.GRID_ORIGIN
	renderer._overlap[PLAY.GRID_ORIGIN] = MEMBER
	renderer._chunk_rects[MEMBER] = Rect2(-96,-96,3300,1800)
	renderer._background_atlases = true
	renderer.block_jobs_enabled = true
	renderer._configured = true
	renderer._ensure_ground()
	if baseline_tiles != null: await stage_abandoned_requests(renderer)
	var first: Dictionary = await time_arrival(renderer)
	if first.is_empty():
		renderer.free()
		return {}
	var initial: Dictionary = painted_ground(renderer)
	renderer._clear_blocks()
	var revisit: Dictionary = await time_arrival(renderer)
	if revisit.is_empty() or initial.is_empty() or painted_ground(renderer) != initial:
		renderer.free()
		return {}
	var began: int = Time.get_ticks_usec()
	for repeat: int in 8: renderer._build_frame()
	var rebuild: float = (Time.get_ticks_usec() - began) / 8.0
	var requests: Array = []
	var bins: Dictionary = renderer._chunk_bins[MEMBER]
	var lanes: Dictionary = renderer._raw_chunks[MEMBER]
	if "_chunk_atlas_ids" in renderer: renderer._chunk_atlas_ids.clear()
	began = Time.get_ticks_usec()
	for cell: Vector2i in bins: requests.append(renderer._member_block_tiles(MEMBER,cell,lanes))
	var cold_discovery: int = Time.get_ticks_usec() - began
	began = Time.get_ticks_usec()
	for repeat: int in 8:
		for cell: Vector2i in bins:
			renderer._member_block_tiles(MEMBER,cell,lanes)
	var discovery: float = (Time.get_ticks_usec() - began) / 8.0
	var lists: Dictionary = renderer._chunk_atlas_ids.get(MEMBER,{}) if "_chunk_atlas_ids" in renderer else {}
	var id_bytes: int = 0
	for ids: PackedInt32Array in lists.values(): id_bytes += ids.size() * 4
	var metrics: Dictionary = renderer.frame_metrics()
	var counts: Array = [metrics.registered_sources, metrics.expected_sources]
	renderer.free()
	return {"first_usec":first.usec,"first_frames":first.frames,"revisit_usec":revisit.usec,"revisit_frames":revisit.frames,
		"first_max_gap_usec":first.max_gap,"first_uploads":first.uploads,"revisit_uploads":revisit.uploads,
		"rebuild_usec":rebuild,"cold_discovery_usec":cold_discovery,"discovery_usec":discovery,
		"lists":lists.size(),"id_bytes":id_bytes,"counts":counts,"pixels":initial.pixels,
		"commands":initial.commands,"requests":TILES._hash(var_to_bytes(requests))}

func run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.split("=",true,1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	if DisplayServer.get_name() == "headless" or not args.has_all(["--baseline-renderer","--baseline-field"]):
		printerr("Use a rendering display and the base renderer and field scripts.")
		quit(1)
		return
	var old_play: Script = load(args["--baseline-renderer"])
	var old_field: Script = load(args["--baseline-field"])
	if old_play == null or old_field == null:
		quit(1)
		return
	fixture = args.get("--fixture","")
	fixture_sha = args.get("--fixture-sha","")
	if fixture.is_empty() != fixture_sha.is_empty():
		printerr("The PNG fixture and its manifest pin must be supplied together.")
		quit(1)
		return
	if args.has("--baseline-tiles"):
		baseline_tiles = load(args["--baseline-tiles"])
		if baseline_tiles == null or fixture.is_empty():
			printerr("Rapid-travel replay needs both tile readers and the PNG fixture.")
			quit(1)
			return
	make_input()
	var zoom: Vector2 = root.get_visible_rect().size / VIEW.size
	root.canvas_transform = Transform2D(Vector2(zoom.x,0),Vector2(0,zoom.y),-VIEW.position * zoom)
	for size: int in ([64,1024,4096] if baseline_tiles == null else [1024]):
		source._members.clear()
		for i: int in size: source._members["Map/test/%08x.s32" % i] = {}
		var samples: Array = [[],[]]
		for repeat: int in 10:
			var pair: Array = [{},{}]
			for i: int in 2:
				var side: int = (repeat + i) % 2
				var pack_script: Script = baseline_tiles if side == 0 and baseline_tiles != null else TILES
				pair[side] = await sample(old_play if side == 0 else PLAY, old_field if side == 0 else FIELD, pack_script)
				if repeat > 0: samples[side].append(pair[side])
			if pair[0].is_empty() or pair[1].is_empty() or pair[1].counts != [size,size]:
				printerr("Missing destination or count at size ",size)
				quit(1)
				return
			for key: String in ["counts","pixels","commands","requests"]:
				if pair[0][key] != pair[1][key]:
					printerr("Map request A/B mismatch: ",key)
					quit(1)
					return
		print("MAP_REQUEST_PAIRS ",JSON.stringify({"members":size,"cold_textures":not fixture.is_empty(),
			"superseded":baseline_tiles!=null,"samples":samples}))
	print("MAP_REQUEST_BENCH_OK")
	quit()
