extends SceneTree
## Real pool callbacks with synthetic S32 and tile lookups. No original art.
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const FIXTURE = preload("res://tests/current523_aden_play_renderer_test.gd")
const RETIRED = preload("res://scripts/maps/current523_retired_map_jobs.gd")
var checks := 0
var failures: Array[String] = []

class Sources extends FIXTURE.FakeChunkSources:
	var hold: Semaphore
	func read_member_job(member: String) -> Dictionary:
		hold.wait()
		return super.read_member_job(member)

class Tiles extends RefCounted:
	var hold: Semaphore
	func has_tile(_id: int) -> bool:
		hold.wait()
		return true

static func delayed_release(gate: Semaphore) -> void:
	OS.delay_msec(300)
	gate.post(2)

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("MAP_RETIREMENT_FAIL: ", label)

func _run() -> void:
	var old := PLAY.new()
	root.add_child(old)
	var field := FIXTURE.FIELD.new()
	field.coordinates.configure([32448, 32064], [1856, 1536], {"basis_x":[24,-12], "basis_y":[24,12], "translation":[0,768]})
	old.field = field
	var gate := Semaphore.new()
	var sources := Sources.new()
	sources.hold = gate
	var tiles := Tiles.new()
	tiles.hold = gate
	old._raw_sources = sources
	old._tile_pack = tiles
	old._member_origins["slow"] = PLAY.GRID_ORIGIN
	old._overlap[PLAY.GRID_ORIGIN] = "slow"
	old._chunk_rects["ready"] = Rect2(0, 0, 1, 1)
	old._raw_chunks["ready"] = {-2: PackedInt64Array([0, 0, 256])}
	old._chunk_bins["ready"] = {Vector2i.ZERO: {-2: PackedInt32Array([0])}}
	check(not old._prefetch_chunk("slow") and old._chunk_jobs.has("slow"), "real chunk task scheduled")
	check(old._start_block_job(Vector2i.ZERO, true) and old._block_jobs.has(Vector2i.ZERO), "real draw-list task scheduled")
	var chunk: Dictionary = old._chunk_jobs["slow"]
	var block: Dictionary = old._block_jobs[Vector2i.ZERO]
	check(not WorkerThreadPool.is_task_completed(chunk.task) and not WorkerThreadPool.is_task_completed(block.task), "both tasks held before teardown")
	var release := Thread.new()
	var start: int = Time.get_ticks_usec()
	check(release.start(delayed_release.bind(gate)) == OK, "timeout-safe release thread runs")
	root.remove_child(old)
	var exit_us: int = Time.get_ticks_usec() - start
	check(exit_us < 150_000, "map detaches before the 300 ms worker release")
	check(old._chunk_jobs.is_empty() and old._block_jobs.is_empty(), "old renderer has no publication handles")
	old.free()
	check(RETIRED.pending_count() == 2, "two task handles transferred across renderer lifetime")
	var next_map := PLAY.new()
	root.add_child(next_map)
	next_map._raw_chunks["sentinel"] = {2: 55}
	RETIRED.pump()
	check(RETIRED.pending_count() == 2, "live tasks are not joined by pump")
	release.wait_to_finish()
	var stop: int = Time.get_ticks_msec() + 3000
	while RETIRED.pending_count() > 0 and Time.get_ticks_msec() < stop:
		await process_frame
	check(RETIRED.pending_count() == 0, "normal root pump reaps both finished jobs")
	check(chunk.has("tail") and block.has("result"), "both real worker callbacks finish after old renderer is freed")
	check(next_map._raw_chunks == {"sentinel": {2: 55}} and next_map._block_jobs.is_empty(), "new map never receives retired output")
	root.remove_child(next_map)
	next_map.free()
	print("MAP_RETIREMENT_RESULT ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "map_detach_usec": exit_us, "worker_release_msec": 300, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
