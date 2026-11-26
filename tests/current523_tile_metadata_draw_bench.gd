extends "res://tests/map_usage_async_test.gd"
## Optional Linux/OpenGL benchmark. Use the 35-tile runtime_fixture from
## tools/map_restore/test_current523_tile_pack.py, its SHA, and the base
## revision's two scripts from git show. Both sides use the same verified
## rows and a fresh texture cache. Timers end before readback/ledger I/O.
## Add --pan to reveal three overlapping strips and return to a warm strip.

const TILES = preload("res://scripts/maps/current523_tile_pack.gd")
const GROUND = preload("res://scripts/maps/current523_aden_play_renderer.gd")

class CountedRows extends RefCounted:
	var reader: RefCounted
	var main_reads: int = 0
	var worker_reads: int = 0
	func read(key: String) -> Variant:
		if OS.get_thread_caller_id() == OS.get_main_thread_id(): main_reads += 1
		else: worker_reads += 1
		return reader.read(key)

var fixture: String
var pin: String
var iteration: int = 0
var pan: bool = false

func show_strip(left: int) -> void:
	var screen: Rect2 = root.get_visible_rect()
	var zoom: Vector2 = screen.size / Vector2(160, 512)
	root.canvas_transform = Transform2D(Vector2(zoom.x, 0), Vector2(0, zoom.y),
		screen.position - Vector2(left, -4) * zoom)

func sample(pack_script: Script, ground_script: Script, per_atlas: int) -> Dictionary:
	var pack = pack_script.new()
	pack.compress_for_gpu = false
	pack.background_only = true
	if not pack.load_pack(fixture,pin) or pack._records == null:
		check(false,"verified warm row file")
		return {}
	var rows := CountedRows.new()
	rows.reader = pack._records
	pack._records = rows
	var ledger: String = folder.path_join("%d.json" % iteration)
	iteration += 1
	reset(ledger)
	var host := Node2D.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(host)
	host.set_script(DrawWorld)
	host.scene_file_path = "res://Main.tscn"
	var ground = ground_script.new()
	host.set("field_renderer",ground)
	host.set("current523_aden_play_active",true)
	host.add_child(ground)
	ground.field = PlayableField.new()
	ground.field.set_meta("current523_source_field",true)
	var actor := Node2D.new()
	host.add_child(actor)
	ground.player = actor
	ground._tile_pack = pack
	ground._configured = true
	check(USAGE.actual_main(ground),"eligible visible Main draw")
	var lane := PackedInt64Array()
	for frame: int in per_atlas:
		for id: int in 8:
			var pos: int = frame * 8 + id
			lane.append((pos % 18) * 24)
			lane.append((pos / 18 % 18) * 24)
			lane.append((id << 8) | frame)
	var t0: int = Time.get_ticks_usec()
	for id: int in 8: pack.prefetch(id)
	var submit_usec: int = Time.get_ticks_usec() - t0
	for _frame: int in 300:
		pack.pump_gpu()
		if pack.pending_jobs() == 0: break
		await process_frame
	var atlases: Dictionary = {}
	for id: int in 8:
		atlases[id] = pack.texture_for(id)
		if atlases[id] == null:
			check(false,"cold fixture atlas %d reached publication" % id)
			host.free()
			return {}
	var prepared_us: int = Time.get_ticks_usec()-t0
	var built: Dictionary = {"commands":{-2:lane}, "atlases":atlases, "count":per_atlas*8, "draws":per_atlas*8, "raw_ff":0, "unresolved":0}
	var previous_transform: Transform2D = root.canvas_transform
	if pan: show_strip(-4)
	var block: Dictionary = ground._bake_block(Vector2i.ZERO,built)
	ground._blocks[Vector2i.ZERO] = block
	ground._visible_blocks.assign([Vector2i.ZERO])
	var canvas := Node2D.new()
	ground.add_child(canvas)
	var measured: Array[int] = []
	canvas.draw.connect(func() -> void:
		var t: int = Time.get_ticks_usec()
		ground._draw_tiles(canvas)
		measured.append(Time.get_ticks_usec()-t))
	for _frame: int in 10:
		await RenderingServer.frame_post_draw
		if not measured.is_empty() and block.get("presented",false): break
	var first_us: int = Time.get_ticks_usec()-t0
	check(measured.size() == 1 and block.get("presented",false),"one presented ground draw")
	var counts: Array[int] = [USAGE._accepted]
	if pan:
		for left: int in [140, 284, 140]:
			show_strip(left)
			ground._draw_generation += 1
			canvas.queue_redraw()
			await RenderingServer.frame_post_draw
			counts.append(USAGE._accepted)
		root.canvas_transform = previous_transform
		check(measured.size() == 4 and counts[0] > 0 and counts[0] < counts[1] and counts[1] < counts[2] and counts[2] == per_atlas * 8 and counts[2] == counts[3],
			"each newly visible strip admits its units and a return to the warm strip admits none")
	var image: Image = block.viewport.get_texture().get_image()
	if image == null or not image.get_used_rect().has_area():
		check(false,"fixture renders visible ground pixels")
		host.free()
		return {}
	var painted: String = TILES._hash(image.get_data())
	USAGE.finish()
	var members: Dictionary = read(ledger).get("members",{})
	var count: int = 0
	for row: Dictionary in members.values(): count += row.origins.AUTOMATED_ACTUAL_MAIN.units.size()
	check(count == 8 * per_atlas,"all distinct visible source subimages are recorded")
	host.free()
	return {"submit":submit_usec,"prepare":prepared_us,"draw":measured[0] if not measured.is_empty() else -1,
		"first":first_us,"main_reads":rows.main_reads,"worker_reads":rows.worker_reads,"pixels":painted,
		"units":count,"evidence":TILES._hash(var_to_bytes(members)),"pan_draw":measured.slice(1),"units_by_view":counts}

func run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--pan": pan = true
		var pair: PackedStringArray = arg.split("=",true,1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	if DisplayServer.get_name() == "headless" or not args.has_all(["--fixture","--fixture-sha","--baseline-pack","--baseline-renderer"]):
		printerr("Use a rendering display, --fixture, --fixture-sha, --baseline-pack and --baseline-renderer.")
		quit(1)
		return
	fixture = args["--fixture"]
	pin = args["--fixture-sha"]
	var before_tiles: Script = load(args["--baseline-pack"])
	var before_ground: Script = load(args["--baseline-renderer"])
	var prime := TILES.new()
	if before_tiles == null or before_ground == null or not prime.load_pack(fixture,pin):
		printerr("Cannot open the two baseline scripts and the pinned fixture.")
		quit(1)
		return
	for id: int in 8:
		if not prime.has_subimage(id,255):
			printerr("Expected the full 256 subimages of the authored tile fixture.")
			quit(1)
			return
	prime = null
	folder = ProjectSettings.globalize_path("user://tile-metadata-bench-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	for n: int in [32,256]:
		var samples: Array = [[],[]]
		for repeat: int in 10:
			var pairs: Array = [{},{}]
			for j: int in 2:
				var side: int = (repeat + j) % 2
				var row: Dictionary = await sample(before_tiles if side == 0 else TILES, before_ground if side == 0 else GROUND,n)
				if row.is_empty():
					quit(1)
					return
				pairs[side] = row
				if repeat > 0: samples[side].append(row)
			check(pairs[0].pixels == pairs[1].pixels and pairs[0].evidence == pairs[1].evidence and pairs[0].units_by_view == pairs[1].units_by_view,"same block pixels and confirmed units for each view")
		print("TILE_DRAW_PAIRS ",JSON.stringify({"refs":8*n,"samples":samples}))
	print("TILE_DRAW_BENCH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
