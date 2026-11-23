extends SceneTree
## Synthetic scheduling and command equivalence, not original-art/device proof.
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const FIXTURE = preload("res://tests/current523_aden_play_renderer_test.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class Probe extends PLAY:
	var sync_calls: int = 0
	var attempts: Array[Vector2i] = []
	var slow_ready: bool = false
	func _block_commands(cell: Vector2i) -> Dictionary:
		sync_calls += 1
		return super._block_commands(cell)
	func _pending_tiles_ready(cell: Vector2i) -> bool:
		attempts.append(cell)
		if slow_ready:
			OS.delay_msec(6)
			return false
		return super._pending_tiles_ready(cell)

class DelayedSources extends FIXTURE.FakeChunkSources:
	func read_member_job(member: String) -> Dictionary:
		OS.delay_msec(80)
		return super.read_member_job(member)

class LegacySources extends RefCounted:
	var problem: String = ""
	var source := FIXTURE.FakeChunkSources.new()
	func source_metadata(member: String) -> Dictionary: return source.source_metadata(member)
	func read_member(member: String) -> Dictionary: return source.read_member(member)

class Tiles extends FIXTURE.FakeAsyncTiles:
	var failed: Dictionary = {}
	func prefetch(id: int) -> bool:
		return true if failed.has(id) else super.prefetch(id)
	func texture_for(id: int) -> Texture2D:
		if failed.has(id):
			problem = "synthetic failed atlas"
			return null
		return super.texture_for(id) if ready.has(id) else null

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("MAP_FOREGROUND_FAIL: ", label)

func _initialize() -> void: _run.call_deferred()

func display() -> Probe:
	var renderer := Probe.new()
	root.add_child(renderer)
	renderer.field = FIXTURE.FIELD.new()
	renderer.field.coordinates.configure([32448, 32064], [1856, 1536], {"basis_x":[24,-12], "basis_y":[24,12], "translation":[0,768]})
	renderer.player = Node2D.new()
	renderer.add_child(renderer.player)
	renderer._tile_pack = Tiles.new()
	return renderer

func chunk_reads() -> void:
	var renderer := display()
	renderer._raw_sources = DelayedSources.new()
	renderer._member_origins["slow"] = PLAY.GRID_ORIGIN
	renderer._overlap[PLAY.GRID_ORIGIN] = "slow"
	renderer._chunk_rects["slow"] = Rect2(-32, -32, 64, 64)
	renderer._prefetch_chunk("slow")
	var start: int = Time.get_ticks_usec()
	var cold: Dictionary = renderer._read_chunk("slow")
	evidence["cold_read_usec"] = Time.get_ticks_usec() - start
	check(cold.is_empty() and renderer._chunk_jobs.has("slow"), "an in-flight chunk is deferred without joining its worker")
	check(renderer._block_commands(Vector2i.ZERO).is_empty(), "pending chunks cannot become a cached partial block")
	for _step: int in 200:
		renderer._pump_chunk_jobs()
		if renderer._raw_chunks.has("slow"): break
		await create_timer(0.002).timeout
	start = Time.get_ticks_usec()
	var warm: Dictionary = renderer._read_chunk("slow")
	evidence["warm_read_usec"] = Time.get_ticks_usec() - start
	check(not warm.is_empty() and renderer._chunk_jobs.is_empty(), "the delayed chunk is installed and reused")
	var expected: Dictionary = PLAY._decode_chunk(renderer._chunk_params("slow"), FIXTURE.FakeChunkSources.new().read_member("slow"))
	check(warm == expected.packed and renderer._chunk_bins.slow == expected.bins, "worker lanes and bins match synchronous source projection")
	renderer._raw_sources = LegacySources.new()
	renderer._member_origins["legacy"] = PLAY.GRID_ORIGIN
	check(renderer._read_chunk("legacy") == expected.packed, "a pack without read_member_job still reads synchronously")
	renderer.free()

func block_arrivals() -> void:
	var renderer := display()
	var tiles: Tiles = renderer._tile_pack
	renderer._background_atlases = true
	renderer.block_jobs_enabled = true
	var cell := Vector2i.ZERO
	var lane := PackedInt64Array([0,0,257, 24,0,513, 500,0,513, 48,0,257])
	renderer._raw_chunks["a"] = {-2: lane, 0: PackedInt64Array([48,24,513, 72,24,257])}
	renderer._chunk_rects["a"] = Rect2(-32,-32,600,100)
	check(renderer._ready_block_commands(cell, true, true).is_empty() and renderer.sync_calls == 0, "an expired foreground deadline still dispatches the worker")
	for _step: int in 100:
		if WorkerThreadPool.is_task_completed(int(renderer._block_jobs[cell].task)): break
		await create_timer(0.002).timeout
	check(renderer._ready_block_commands(cell, true, true).is_empty() and renderer._block_jobs.has(cell), "completed commands remain queued while an atlas is pending")
	check(renderer._ready_block_commands(cell, true, true).is_empty() and renderer.sync_calls == 0, "repeated acquisition does not join again or re-enter the synchronous assembler")
	tiles.ready[1] = true
	tiles.failed[2] = true
	var built: Dictionary = renderer._ready_block_commands(cell, true, true)
	check(not built.is_empty() and not built.has("sync") and renderer.sync_calls == 0, "terminal atlas failure filters completed commands without a synchronous rebuild")
	var reference: Dictionary = renderer._block_commands(cell)
	check(built.commands == reference.commands and built.count == reference.count and built.draws == reference.draws and built.unresolved == reference.unresolved, "failed atlas holes, accounting and layer/record order match the synchronous path")
	check(renderer._unresolved_logged.has(2), "failed atlas remains diagnosed")
	# Ready results must make it to the draw list, even without a camera move.
	renderer._pending_blocks.assign([cell])
	renderer._built_view = Rect2(0,0,512,512)
	for _step: int in 100:
		renderer._bake_pending(-1)
		if renderer._blocks.has(cell): break
		await create_timer(0.002).timeout
	check(renderer._blocks.has(cell) and renderer._visible_blocks.has(cell) and renderer._frame_commands.get(cell) == reference.commands, "ready blocks eventually enter the visible draw list")
	renderer._clear_blocks()
	renderer._raw_chunks.clear()
	renderer._chunk_bins.clear()
	renderer._unreadable_chunks["a"] = "synthetic unreadable source"
	check(renderer._start_block_job(cell, true), "a diagnosed unreadable chunk cannot permanently prevent a block job")
	renderer.free()

func readiness_budget() -> void:
	var renderer := display()
	renderer.slow_ready = true
	renderer._background_atlases = true
	var screen: Rect2 = renderer._view_rect()
	var visible := Vector2i(floori(screen.get_center().x / PLAY.BLOCK), floori(screen.get_center().y / PLAY.BLOCK))
	var margin := visible + Vector2i(20, 0)
	renderer._pending_blocks.assign([margin, visible, visible + Vector2i(0,1)])
	check(renderer._bake_pending(0) == 0 and renderer.attempts.is_empty(), "zero budget performs no readiness checks")
	var started: int = Time.get_ticks_usec()
	renderer._bake_pending(PLAY.PENDING_BAKE_BUDGET_USEC)
	evidence["slow_readiness_slice_usec"] = Time.get_ticks_usec() - started
	check(renderer.attempts == [visible] and renderer._pending_blocks.size() == 3, "one slow readiness check exhausts the slice before any bake; visible work goes first")
	renderer.attempts.clear()
	renderer._chunk_rects["visible"] = screen
	check(renderer._build_frame() and renderer.attempts.size() == 1 and PLAY._block_rect(renderer.attempts[0]).intersects(screen), "frame construction also yields after the first expensive visible readiness check")
	renderer.free()

func _run() -> void:
	await chunk_reads()
	if not "--chunk-only" in OS.get_cmdline_user_args():
		await block_arrivals()
		readiness_budget()
	print("MAP_FOREGROUND_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
