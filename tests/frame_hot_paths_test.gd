extends SceneTree
## Standalone synthetic check of the per-frame hot paths that made play stutter
## (no Main, no original data, no files). Run:
##   godot --headless --path <repo> --script res://tests/frame_hot_paths_test.gd
## 1. catalog_item_lookup remembers a miss instead of rescanning the catalogs.
## 2. quest_auto_runner.held_record: ordinary names never invalidate its index.
## 3. quest_auto_runner.tick (automatic claim): a batch whose staging fails is
##    not restaged on every frame while the world state is unchanged, and is
##    retried after a state change; a successful batch still chains next frame.
## 5. current523_identity_pack verified-file checks (see the last section).
## 4. Ready mode (the game default): conditions met -> marked ready only, no
##    reward transaction; [보상 받기]/[모두 받기] run complete(); the scan is
##    time-sliced and does not rerun while the state is unchanged.
const LOOKUP = preload("res://scripts/catalog_item_lookup.gd")
const RUNNER = preload("res://scripts/quests/quest_auto_runner.gd")
const IDENTITY = preload("res://scripts/resources/current523_identity_pack.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FRAME_HOT_PATHS_FAIL: " + label)

class FakeSource extends RefCounted:
	var quests: Array = []
	func gate(_quest: Dictionary, _context: Dictionary, _offered: Dictionary, _now: int) -> String: return ""
	func reward_plan(_quest: Dictionary, _context: Dictionary) -> Dictionary: return {"ok":true}

class FakeService extends RefCounted:
	var source := FakeSource.new()
	var claimed: Dictionary = {}
	var day_key: int = 1
	var save_blocked: bool = false

class FakeHud extends Node:
	var logs: Array = []
	var messages: Array = []
	var refreshes: int = 0
	func append_log(text: String) -> void: logs.append(text)
	func show_message(text: String) -> void: messages.append(text)
	func refresh_quests() -> void: refreshes += 1

class FakeCollections extends RefCounted:
	var save_blocked: bool = false

class FakeWorld extends Node:
	var quest_service := FakeService.new()
	var equipment_collections := FakeCollections.new()
	var level: int = 10
	var job_class: String = "knight"
	var source_save_blocked: bool = false
	var pending_map_save_record: Dictionary = {}
	var inventory: Dictionary = {"화살":100}
	var item_instances: Dictionary = {}
	var next_item_instance_id: int = 1
	var hud: Node = null

class CountingRunner extends "res://scripts/quests/quest_auto_runner.gd":
	var completes: int = 0
	var refreshes: int = 0
	var succeed: bool = false
	var batches: Array = []
	func refresh_context(_world: Node) -> void: refreshes += 1
	func complete(world: Node, ids: Array[String]) -> bool:
		completes += 1
		batches.append(ids.duplicate())
		if succeed:
			for id: String in ids: world.quest_service.claimed[id] = true
			return true
		for id: String in ids: failures[id] = "원본 공급 준비 실패"
		return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_catalog_misses()
	_held_record_index()
	_tick_backoff()
	_ready_mode()
	_identity_file_checks()
	print("FRAME_HOT_PATHS_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _rows(count: int) -> Array:
	var rows: Array = []
	for index: int in count: rows.append({"name":"item %d" % index, "n":index})
	return rows

func _catalog_misses() -> void:
	var rows: Array = _rows(500)
	var base: Array = _rows(20)
	var instances: Dictionary = {"7":{"name":"화살","record":{"name":"화살","ammo":true}}}
	var scans: int = LOOKUP.miss_scans
	var first: Dictionary = LOOKUP.find_one([rows, base], instances, "화살")
	check(first.get("ammo") == true, "an instance-only name is still found after the catalog misses")
	var after_first: int = LOOKUP.miss_scans
	check(after_first - scans == 2, "the first miss scans each catalog once")
	for repeat: int in 20: LOOKUP.find_one([rows, base], instances, "화살")
	check(LOOKUP.miss_scans == after_first, "repeated misses do not rescan the catalogs")
	check(LOOKUP.find_one([rows, base], instances, "없는 이름").is_empty(), "an absent name is still {}")
	# Appending the missed name makes it visible at once.
	var appended: Dictionary = {"name":"화살", "catalog":true}
	rows.append(appended)
	check(is_same(LOOKUP.find_one([rows, base], instances, "화살"), appended), "an appended record replaces a remembered miss")
	# A replaced (not same) array has its own entry and no remembered misses.
	var fresh: Array = _rows(500)
	var fresh_hit: Dictionary = {"name":"새 이름"}
	fresh.append(fresh_hit)
	check(is_same(LOOKUP.first_by_name(fresh, "새 이름"), fresh_hit), "a replaced array is searched again")
	# Shrinking the array rebuilds its entry.
	check(LOOKUP.first_by_name(rows, "늦은 이름").is_empty(), "late name misses before it exists")
	rows.remove_at(0)
	rows[3] = {"name":"늦은 이름"}
	check(is_same(LOOKUP.first_by_name(rows, "늦은 이름"), rows[3]), "a resized array forgets remembered misses")
	# Same-size in-place rename to a remembered miss: documented contract.
	check(LOOKUP.first_by_name(rows, "제자리 이름").is_empty(), "in-place target misses first")
	rows[10] = {"name":"제자리 이름"}
	LOOKUP.forget_misses()
	check(is_same(LOOKUP.first_by_name(rows, "제자리 이름"), rows[10]), "forget_misses() makes an in-place rename visible")
	# Same-name in-place replacement (what catalog merges do) stays exact.
	var merged: Dictionary = (rows[20] as Dictionary).duplicate(true)
	merged["grade"] = "merged"
	rows[20] = merged
	check(is_same(LOOKUP.first_by_name(rows, str(merged.name)), merged), "same-name in-place merge returns the live record")
	var metrics: Dictionary = LOOKUP.index_metrics()
	check(metrics.has("misses") and int(metrics.misses) >= 0, "index metrics report remembered misses")

func _held_record_index() -> void:
	var runner = RUNNER.new()
	var record: Dictionary = {"name":"[원본 보상] 상자", "source_pending_use":true}
	var instances: Dictionary = {"1":{"name":"[원본 보상] 상자","record":record}, "2":{"name":"화살","record":{}}}
	var held: Dictionary = runner.held_record("[원본 보상] 상자", instances)
	check(held == record and not is_same(held, record), "a held reward record is returned as a copy")
	var size_before: int = runner.indexed_size
	check(size_before == instances.size(), "the held index is built for the instances")
	for repeat: int in 10: check(runner.held_record("화살", instances).is_empty(), "an ordinary name is not a held reward")
	check(runner.indexed_size == size_before, "ordinary names do not invalidate the held index")
	check(runner.held_record("[원본 보상] 없음", instances).is_empty() and runner.indexed_size == -1, "a missing reward name still forces a re-index")
	instances["3"] = {"name":"[원본 보상] 새 상자","record":{"name":"[원본 보상] 새 상자","source_pending_use":true}}
	check(runner.held_record("[원본 보상] 새 상자", instances).get("name") == "[원본 보상] 새 상자", "a newly held reward is found after re-index")
	check(runner.held_record("[원본 보상] 상자", {"1":{"name":"[원본 보상] 상자","record":{"source_pending_use":false}}}).is_empty(), "a used reward returns {}")

func _tick_backoff() -> void:
	var world := FakeWorld.new()
	for index: int in 3: world.quest_service.source.quests.append({"id":"q%d" % index})
	var runner := CountingRunner.new()
	check(not runner.auto_claim, "the game default is click-to-claim")
	runner.auto_claim = true
	runner.tick(world)
	check(runner.completes == 1, "the first scan stages the batch once")
	check(runner.next_scan > 0.0, "a failed batch keeps the normal scan cadence")
	for frame: int in 30:
		runner.next_scan = 0.0
		runner.tick(world)
	check(runner.completes == 1, "an unchanged state does not restage the failed batch")
	check(runner.blocked.size() == 3, "failed quests are remembered for this state")
	check(runner.failures.size() == 3, "the failure reason stays visible to the quest UI")
	world.inventory["새 재료"] = 1
	runner.next_scan = 0.0
	runner.tick(world)
	check(runner.completes == 2, "an inventory change retries the batch")
	world.level = 11
	runner.tick(world)
	check(runner.completes == 3, "a level change retries the batch immediately")
	# A save failure keeps its own 30 s retry and is not blocked.
	var saving := CountingRunner.new()
	saving.auto_claim = true
	saving.retry_at = Time.get_unix_time_from_system() + 30.0
	saving.next_scan = 0.0
	saving.tick(world)
	check(saving.completes == 0, "a pending save retry still waits")
	# Success still continues prerequisite chains on the next frame.
	var ok_world := FakeWorld.new()
	ok_world.quest_service.source.quests.append({"id":"a"})
	var ok_runner := CountingRunner.new()
	ok_runner.auto_claim = true
	ok_runner.succeed = true
	ok_runner.tick(ok_world)
	check(ok_runner.completes == 1 and ok_runner.next_scan == 0.0, "a completed batch rescans on the next frame")
	check(ok_runner.blocked.is_empty(), "completed quests are not blocked")
	world.free()
	ok_world.free()

func _scan_all(runner, world) -> void:
	for frame: int in 200:
		runner.tick(world)
		if runner._scan_cursor < 0 and not runner._scanned_state.is_empty(): return

func _ready_mode() -> void:
	var world := FakeWorld.new()
	var hud := FakeHud.new()
	world.hud = hud
	for index: int in 40: world.quest_service.source.quests.append({"id":"r%02d" % index})
	var runner := CountingRunner.new()
	runner.succeed = true
	_scan_all(runner, world)
	check(runner.completes == 0, "ready mode never grants rewards by itself")
	check(runner.ready.size() == 40 and world.quest_service.claimed.is_empty(), "every met quest is ready, none received")
	check(hud.logs.size() == 1 and str(hud.logs[0]).contains("보상 받기"), "the player is told once to claim from the quest window")
	var refreshes: int = runner.refreshes
	for frame: int in 50: runner.tick(world)
	check(runner.refreshes == refreshes and runner._scan_cursor < 0, "an unchanged state does not rescan")
	check(hud.logs.size() == 1, "no repeated notice for the same ready quests")
	check(runner.claim(world, "r05") and world.quest_service.claimed.has("r05") and not runner.ready.has("r05"), "[보상 받기] receives one quest")
	check(runner.batches.size() == 1 and runner.batches[0] == ["r05"], "a single claim is one atomic transaction")
	var result: Dictionary = runner.claim_all(world)
	check(int(result.claimed) == 39 and int(result.failed) == 0, "[모두 받기] receives every ready quest")
	check(runner.batches.size() == 3 and (runner.batches[1] as Array).size() == 32 and (runner.batches[2] as Array).size() == 7, "모두 받기 writes 32 quests per transaction in quest order")
	check(runner.batches[1][0] == "r00" and runner.ready.is_empty(), "claim order follows the quest list")
	# Failure: the reason is shown and the quest stays ready.
	var failing := CountingRunner.new()
	world.quest_service.claimed.clear()
	_scan_all(failing, world)
	check(not failing.claim(world, "r01") and failing.ready.has("r01"), "a failed claim keeps the quest ready")
	check(not hud.messages.is_empty() and str(hud.messages[-1]).contains("원본 공급 준비 실패"), "a failed claim shows its reason")
	var none: Dictionary = failing.claim_all(world)
	check(int(none.claimed) == 0 and int(none.failed) == 40, "모두 받기 reports what could not be received")
	# One unsuppliable quest must not block the rest of its batch.
	var mixed := MixedRunner.new()
	world.quest_service.claimed.clear()
	_scan_all(mixed, world)
	var mixed_result: Dictionary = mixed.claim_all(world)
	check(int(mixed_result.claimed) == 39 and int(mixed_result.failed) == 1 and mixed.ready.keys() == ["r03"], "모두 받기 receives the rest when one quest fails")
	# Time slicing: a slow gate spreads the pass over several frames.
	var slow_world := FakeWorld.new()
	slow_world.quest_service.source = SlowSource.new()
	for index: int in 30: slow_world.quest_service.source.quests.append({"id":"s%d" % index})
	var slow := CountingRunner.new()
	slow.tick(slow_world)
	check(slow._scan_cursor > 0 and slow._scan_cursor < 30, "a pass is split across frames within its budget")
	_scan_all(slow, slow_world)
	check(slow.ready.size() == 30, "the sliced pass still marks every ready quest")
	# A state change starts a new pass (e.g. a level up opens more quests).
	slow_world.level = 99
	slow._scanned_state = slow._scanned_state + "x"
	slow.next_scan = 0.0
	slow.tick(slow_world)
	check(slow._scan_cursor >= 0 or slow._scanned_state.begins_with("99"), "a changed state rescans")
	world.free()
	hud.free()
	slow_world.free()

class SlowSource extends FakeSource:
	func gate(_quest: Dictionary, _context: Dictionary, _offered: Dictionary, _now: int) -> String:
		OS.delay_usec(400)
		return ""

class MixedRunner extends "res://scripts/quests/quest_auto_runner.gd":
	func refresh_context(_world: Node) -> void: pass
	func complete(world: Node, ids: Array[String]) -> bool:
		if ids.has("r03"):
			failures["r03"] = "원본 공급 준비 실패"
			return false
		for id: String in ids: world.quest_service.claimed[id] = true
		return true

## 5. current523_identity_pack: a verified file is not re-hashed until its
##    modification time or size changes; a changed or missing file still fails.
func _identity_file_checks() -> void:
	var path: String = "user://frame_hot_paths_identity.bin"
	var bytes := PackedByteArray()
	bytes.resize(4 * 1024 * 1024)
	for index: int in range(0, bytes.size(), 4096): bytes[index] = index % 251
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var sha: String = FileAccess.get_sha256(path)
	check(IDENTITY._file_matches(path, sha), "an intact file matches")
	check(not IDENTITY._file_matches(path, "0".repeat(64)), "a different expected hash fails")
	var started: int = Time.get_ticks_usec()
	for repeat: int in 2000: IDENTITY._file_matches(path, sha)
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	check(elapsed_ms < 200.0, "2000 checks of a verified 4 MiB file do not re-hash it (%.1f ms)" % elapsed_ms)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0, 1, 2]))
	file.close()
	check(not IDENTITY._file_matches(path, sha), "a rewritten (corrupted) file fails at once")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	check(IDENTITY._file_matches(path, sha), "the restored file matches again")
	DirAccess.remove_absolute(path)
	check(not IDENTITY._file_matches(path, sha), "a missing file fails")
