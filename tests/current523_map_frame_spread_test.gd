extends SceneTree
## User report 2026-11-20 (phone recording, running north-west into new ground
## at the acceleration run): the game stalled about every 0.25 s.
##
## Cause (measured on Linux, 1.8x north-west run into new ground, 4 s): a frame
## build that left margin blocks unbaked cleared the built view, so every
## 0.25 s refresh re-walked the whole screen (map.build_frame 32 times,
## 192 ms), the NPC/portal labels were rebuilt on every refresh (32 times) and
## each map object refresh re-laid out and re-showed every visible placement.
##
## This test keeps the frame spread (synthetic, CI):
## - a partial build keeps its built view; the missing blocks are pending and
##   bake a few per frame within the budget, on-screen ones first;
## - the baked map is the same as an immediate full build (every block, the
##   same draw commands);
## - a pending block that is still decoding asks only its own atlases again;
## - pending blocks that left the built view are dropped;
## - labels refresh after MARKER_REFRESH_DISTANCE of movement, collision when
##   the cell changes;
## - a map object refresh keeps holders of unchanged records (no re-show) and
##   shows only new ones, in the dense source order, the same layout as a full
##   rebuild.
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const FIELD = preload("res://scripts/maps/source_map_runtime_field.gd")
const RENDERER_TEST = preload("res://tests/current523_aden_play_renderer_test.gd")
const REFRESH_TEST = preload("res://tests/current523_bank_object_refresh_test.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class CountingPlay extends PLAY:
	var markers: int = 0
	var collisions: int = 0
	var sync_block_builds: int = 0
	func _block_commands(cell: Vector2i) -> Dictionary:
		sync_block_builds += 1
		return super._block_commands(cell)
	func _refresh_markers() -> void: markers += 1
	func _refresh_collision() -> void: collisions += 1

class CountingAsyncTiles extends RENDERER_TEST.FakeAsyncTiles:
	var prefetch_calls: int = 0
	func prefetch(id: int) -> bool:
		prefetch_calls += 1
		return super.prefetch(id)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("MAP_FRAME_SPREAD_FAIL: ", label)
	return condition

func _initialize() -> void: _run.call_deferred()

func _field() -> RefCounted:
	var value = FIELD.new()
	value.set_meta("source_map84", true)
	value.definition = {"map_id":"aden_world", "source_map_id":4, "source_sha256":PLAY.GRID_SHA256}
	value.data = {"map_id":"aden_world", "npc_spawn":[], "portal":[]}
	value.coordinates.configure([32448, 32064], [1856, 1536], {"basis_x":[24,-12], "basis_y":[24,12], "translation":[0,768]})
	value.runtime_record = {"source_map_id":4, "target_map_id":"aden_world", "chunks":[]}
	return value

## A renderer on a synthetic ground: one tile record near the centre of every
## 512 px block of the screen and its build margin, each with its own atlas.
func _renderer(tiles: RefCounted, center: Vector2) -> CountingPlay:
	var renderer := CountingPlay.new()
	root.add_child(renderer)
	var actor := Node2D.new()
	renderer.add_child(actor)
	actor.global_position = center
	renderer.field = _field()
	renderer.player = actor
	renderer.problem = ""
	renderer._tile_pack = tiles
	return renderer

func _ground(renderer: CountingPlay, view: Rect2) -> Array[Vector2i]:
	var first := Vector2i(floori(view.position.x / PLAY.BLOCK), floori(view.position.y / PLAY.BLOCK))
	var last := Vector2i(floori(view.end.x / PLAY.BLOCK), floori(view.end.y / PLAY.BLOCK))
	var cells: Array[Vector2i] = []
	renderer._chunk_rects = {}
	renderer._raw_chunks = {}
	var atlas: int = 20
	for bx: int in range(first.x, last.x + 1):
		for by: int in range(first.y, last.y + 1):
			var cell := Vector2i(bx, by)
			cells.append(cell)
			var point: Vector2i = cell * PLAY.BLOCK + Vector2i(200, 200)
			var member: String = "c_%d_%d" % [bx, by]
			renderer._chunk_rects[member] = Rect2(Vector2(point) - Vector2(32, 32), Vector2(64, 64))
			renderer._raw_chunks[member] = {-2: PackedInt64Array([point.x, point.y, (atlas << 8) | 1])}
			atlas += 1
	renderer._chunk_bins.clear()
	renderer._clear_blocks()
	return cells

func renderer_spread() -> void:
	# Reference: every atlas ready, one full build bakes the whole view.
	var ready_tiles := CountingAsyncTiles.new()
	var reference := _renderer(ready_tiles, Vector2.ZERO)
	var view: Rect2 = reference._view_rect().grow(PLAY.BUILD_MARGIN)
	var cells: Array[Vector2i] = _ground(reference, view)
	for id: int in range(20, 20 + cells.size()): ready_tiles.ready[id] = true
	check(reference._build_frame(), "reference frame builds")
	while not reference._pending_blocks.is_empty(): reference._bake_pending(-1)
	var expected: Dictionary = {}
	for cell: Vector2i in reference._blocks: expected[cell] = var_to_str((reference._blocks[cell] as Dictionary).commands)
	check(expected.size() == cells.size(), "reference: every block of the view is baked (%d/%d)" % [expected.size(), cells.size()])
	# Spread: no atlas decoded yet.
	var tiles := CountingAsyncTiles.new()
	var renderer := _renderer(tiles, Vector2.ZERO)
	_ground(renderer, view)
	check(renderer._build_frame() and renderer.problem.is_empty(), "a partial build succeeds while atlases decode")
	check(renderer._built_view.has_area(), "a partial build keeps its built view (no full rebuild on every refresh)")
	check(renderer._pending_blocks.size() == cells.size() and renderer._blocks.is_empty(), "every unready block is pending (%d)" % renderer._pending_blocks.size())
	var screen: Rect2 = renderer._view_rect()
	var on_screen: int = 0
	for cell: Vector2i in cells:
		if PLAY._block_rect(cell).intersects(screen): on_screen += 1
	var screen_first: bool = true
	for index: int in renderer._pending_blocks.size():
		var shown: bool = PLAY._block_rect(renderer._pending_blocks[index]).intersects(screen)
		if shown != (index < on_screen): screen_first = false
	check(screen_first, "on-screen blocks come first in the pending blocks")
	# The periodic refresh does not rebuild a frame whose view is still enclosed.
	check(renderer._built_view.encloses(renderer._view_rect()), "the 0.25 s refresh finds the frame built (no rebuild while blocks are pending)")
	# Still decoding: nothing bakes, and the retry asks only the recorded atlases.
	check(renderer._bake_pending(PLAY.PENDING_BAKE_BUDGET_USEC) == 0, "a pending block whose atlases decode is not baked")
	check(renderer._pending_tiles.size() == cells.size(), "each pending block recorded its atlas IDs (%d/%d, retry %d)" % [renderer._pending_tiles.size(), cells.size(), renderer._pending_retry.size()])
	renderer._pending_retry.clear()
	var calls_before: int = tiles.prefetch_calls
	renderer._bake_pending(PLAY.PENDING_BAKE_BUDGET_USEC)
	check(tiles.prefetch_calls - calls_before == cells.size(), "a retry asks one atlas per block, not a record walk (%d)" % (tiles.prefetch_calls - calls_before))
	check(renderer._bake_pending(PLAY.PENDING_BAKE_BUDGET_USEC) == 0 and tiles.prefetch_calls - calls_before == cells.size(), "within PENDING_RETRY_MSEC a decoding block is not asked again")
	# Decoded: an exhausted budget starts no work, the next slice makes progress.
	tiles.pump()
	renderer._pending_retry.clear()
	check(renderer._bake_pending(0) == 0 and renderer._pending_blocks.size() == cells.size(), "a zero budget starts no readiness or bake work")
	check(renderer._bake_pending(1000) > 0, "a positive slice makes progress")
	check(PLAY._block_rect(renderer._blocks.keys()[0]).intersects(screen), "the first baked block is on screen")
	var frames: int = 1
	while not renderer._pending_blocks.is_empty() and frames < 100:
		renderer._bake_pending(PLAY.PENDING_BAKE_BUDGET_USEC)
		frames += 1
	evidence["frames_to_complete"] = frames
	check(renderer._pending_blocks.is_empty(), "the pending blocks complete")
	var same: bool = renderer._blocks.size() == expected.size()
	for cell: Vector2i in expected:
		same = same and renderer._blocks.has(cell) and var_to_str((renderer._blocks[cell] as Dictionary).commands) == expected[cell] and renderer._visible_blocks.has(cell) and renderer._frame_commands.has(cell)
	check(same, "the spread map is the same as a full build: every block, the same draw commands")
	# Pending blocks that left the built view are dropped, not baked.
	renderer._clear_blocks()
	renderer._tile_pack = CountingAsyncTiles.new()
	check(renderer._build_frame() and renderer._pending_blocks.size() == cells.size(), "rebuild with blocks pending")
	var far := Vector2i(1000, 1000)
	renderer._pending_blocks.append(far)
	renderer._bake_pending(-1)
	check(not renderer._blocks.has(far) and not renderer._pending_blocks.has(far), "a pending block outside the built view is dropped")
	# Labels and collision follow movement, not the 0.25 s clock.
	renderer.markers = 0; renderer.collisions = 0
	renderer._markers_at = Vector2.INF
	renderer._refresh_markers_if_moved(false)
	renderer._refresh_markers_if_moved(false)
	renderer._refresh_markers_if_moved(false)
	check(renderer.markers == 1 and renderer.collisions == 1, "standing still: labels and collision once (%d, %d)" % [renderer.markers, renderer.collisions])
	renderer.player.global_position += Vector2(PLAY.MARKER_REFRESH_DISTANCE * 0.5, 0)
	renderer._refresh_markers_if_moved(false)
	check(renderer.markers == 1, "a short move keeps the labels")
	renderer.player.global_position += Vector2(PLAY.MARKER_REFRESH_DISTANCE, 0)
	renderer._refresh_markers_if_moved(false)
	check(renderer.markers == 2 and renderer.collisions >= 2, "a longer move refreshes labels and the new cell's collision")
	renderer._refresh_markers_if_moved(true)
	check(renderer.markers == 3, "a forced refresh (refresh_visible) rebuilds the labels")
	reference.queue_free(); renderer.queue_free()

func multi_atlas_retry() -> void:
	var tiles := CountingAsyncTiles.new()
	var renderer := _renderer(tiles, Vector2.ZERO)
	var cell := Vector2i.ZERO
	renderer._pending_tiles[cell] = PackedInt32Array([21, 22, 23])
	check(not renderer._pending_tiles_ready(cell), "block waits for all its atlases")
	check(tiles.requested.has_all([21, 22, 23]), "one retry offers later atlas IDs even when the first is not ready")
	tiles.pump()
	check(renderer._pending_tiles_ready(cell), "the block is ready when all offered atlases finish")
	renderer.queue_free()

func worker_blocks() -> void:
	var tiles := CountingAsyncTiles.new()
	var renderer := _renderer(tiles, Vector2.ZERO)
	renderer.block_jobs_enabled = true
	var cells: Array[Vector2i] = _ground(renderer, renderer._view_rect().grow(PLAY.BUILD_MARGIN))
	check(renderer._build_frame() and renderer._blocks.is_empty(), "real job branch defers unready blocks")
	renderer._background_atlases = true
	for cell: Vector2i in renderer._screen_wait:
		renderer._screen_wait[cell] = Time.get_ticks_msec() - PLAY.ON_SCREEN_WAIT_MSEC - 1
	check(renderer._bake_pending(-1) == 0 and renderer._blocks.is_empty(), "expired atlas deadline does not force a live-map decode")
	check(not renderer._block_jobs.is_empty(), "CPU draw lists are assembled while atlases still decode")
	tiles.pump()
	renderer._pending_retry.clear()
	renderer._bake_pending(-1)
	check(renderer.sync_block_builds == 0, "ready pending blocks consume or await workers without a synchronous rebuild")
	for _frame: int in 100:
		if renderer._pending_blocks.is_empty(): break
		await create_timer(0.003).timeout
		renderer._bake_pending(-1)
	check(renderer._blocks.size() == cells.size() and renderer._block_jobs.is_empty() and renderer.sync_block_builds == 0, "pending blocks consume all completed jobs without rebuilding their draw lists")
	var same: bool = renderer._blocks.size() == cells.size()
	for cell: Vector2i in renderer._blocks:
		same = same and (renderer._blocks[cell] as Dictionary).commands == renderer._block_commands(cell).commands
	check(same, "worker-produced commands match the synchronous reference in each block")
	renderer.queue_free()
	await process_frame

func worker_layer_order() -> void:
	var tiles := RENDERER_TEST.CountedTiles.new()
	var renderer := _renderer(tiles, Vector2.ZERO)
	var cell := Vector2i(-1,-1)
	var bounds: Rect2 = PLAY._block_rect(cell)
	renderer._chunk_rects = {"second":bounds, "first":bounds}
	renderer._raw_chunks = {
		"first": {-2: PackedInt64Array([-513,-512,257, -512,-512,258, -1,-1,4294967295]),
			3: PackedInt64Array([-20,-20,769]), 4: PackedInt64Array([-10,-10,4294967295])},
		"second": {-2: PackedInt64Array([-511,-511,513, -6,-6,2049, -1,-513,257]),
			3: PackedInt64Array([-9,-9,257])},
	}
	var inputs: Array = []
	for member: String in renderer._block_members(cell):
		var layers: Dictionary = renderer._raw_chunks[member]
		var bins: Dictionary = PLAY._bin_chunk(layers)
		inputs.append([layers,bins[cell]])
	for objects: bool in [true,false]:
		renderer.include_objects = objects
		var reference: Dictionary = renderer._block_commands(cell)
		var job := {"cell":cell,"tiles":tiles,"has_subimage":true,"inputs":inputs,"include_objects":objects}
		PLAY._block_job(job)
		var result: Dictionary = job.result
		check(result.commands == reference.commands and result.commands.keys() == reference.commands.keys(),
			"worker appends shared layers across sorted members and omits empty layers")
		check(result.commands[-2] == PackedInt64Array([-513,-512,257, -511,-511,513, -1,-513,257])
			and result.tile_ids == reference.atlases.keys(), "negative seams retain overlapping draws and first-use atlas order")
		check(result.count == (3 if objects else 1) and result.draws == (5 if objects else 3)
			and result.raw_ff == (2 if objects else 1) and result.unresolved == 2,
			"only the owning block counts a record and rejected atlas/subimages stay unresolved")
	renderer.queue_free()

func _rows(ids: Array, start: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in ids.size(): result.append({"sprite_id":ids[i], "raw_x":float((start + i) * 4), "raw_y":float((start + i) % 3) * 3.0})
	return result

func _layout(owner: Node2D) -> Array:
	var result: Array = []
	for holder: Node2D in owner._nodes:
		var layers: Array = []
		for child: Sprite2D in holder.get_children(): layers.append([child.texture.get_instance_id(), child.position, child.z_index])
		result.append([holder.get_index(), holder.position, holder.get_meta("sprite_id"), layers])
	return result

func objects_spread() -> void:
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.5, 0.7, 1.0))
	var a: Texture2D = ImageTexture.create_from_image(image)
	image.fill(Color(0.8, 0.2, 0.1, 1.0))
	var b: Texture2D = ImageTexture.create_from_image(image)
	var catalog: Dictionary = {
		1:{"ok":true,"static":false,"total":1.0,"frames":[{"duration":0.5,"layers":[{"fixture_texture":a,"offset":[0,0]}]},{"duration":0.5,"layers":[{"fixture_texture":b,"offset":[2,3]}]}]},
		2:{"ok":true,"static":true,"frames":[{"layers":[{"fixture_texture":b,"offset":[1,2]}]}]}}
	var current = REFRESH_TEST.Fixture.new()
	var full = REFRESH_TEST.Baseline.new()
	for owner: Node2D in [current, full]:
		owner.catalog = catalog
		owner.coordinates = REFRESH_TEST.Mapping.new()
		owner._mode = "compatible"
		root.add_child(owner)
		owner.set_process(false)
	var first: Array[Dictionary] = _rows([1, 2, 1, 2])
	current.refresh(first)
	var kept: Array = current._nodes.duplicate()
	var calls: int = current.texture_calls
	# The same records again: nothing is shown again.
	current.refresh(first)
	check(current.texture_calls == calls and current._nodes == kept, "an unchanged refresh keeps every holder and shows nothing again")
	# A new chunk arrives in the middle of the dense order.
	var grown: Array[Dictionary] = first.slice(0, 2)
	grown.append_array(_rows([2, 1], 10))
	grown.append_array(first.slice(2))
	current.refresh(grown)
	full.refresh(grown)
	check(current.texture_calls - calls == 2, "only the two new records are shown (%d texture calls)" % (current.texture_calls - calls))
	check(current._nodes[0] == kept[0] and current._nodes[1] == kept[1] and current._nodes[4] == kept[2] and current._nodes[5] == kept[3], "the holders of unchanged records are kept")
	var ordered: bool = true
	for index: int in current._nodes.size(): ordered = ordered and current._nodes[index].get_index() == index
	check(ordered, "holders follow the dense source order (draw order)")
	await process_frame
	check(_layout(current) == _layout(full), "the same layout as a full rebuild")
	# A chunk leaves: its holders are detached at once, the rest kept.
	current.refresh(first)
	check(current._nodes == kept and current.get_child_count() == kept.size(), "records that left are detached, the others kept")
	# Another mode shows every holder again.
	calls = current.texture_calls
	current._mode = "strict"
	current.refresh(first)
	check(current.texture_calls > calls, "a playback mode change shows the holders again")
	current.queue_free(); full.queue_free()
	await process_frame

func _run() -> void:
	renderer_spread()
	multi_atlas_retry()
	worker_layer_order()
	await worker_blocks()
	await objects_spread()
	var result: Dictionary = {"checks": checks, "failures": failures, "evidence": evidence, "synthetic_only": true}
	print("MAP_FRAME_SPREAD_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
