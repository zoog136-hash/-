extends SceneTree
const USAGE = preload("res://scripts/maps/current523_map_usage.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const SHA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var checks: int = 0
var failures: Array[String] = []
var evidence: Array = []
var maximum_pump_usec: int = 0
var folder: String

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MAP_USAGE_ASYNC_FAIL: ",label)

func reset(path: String) -> void:
	USAGE.finish()
	USAGE._worker = USAGE.LedgerWorker.new(path)
	USAGE._recorded.clear()
	USAGE._pending = []
	USAGE._pending_bytes = 0
	USAGE._result = []
	USAGE._task = -1
	USAGE._force = false
	USAGE._dirty = false
	USAGE._disabled = false
	USAGE._last_flush = Time.get_ticks_msec()
	USAGE._accepted = 0
	USAGE._committed = 0
	USAGE._rejected = 0
	USAGE._conflicts = 0
	USAGE.problem = ""

func offer(unit: String, origin: String = "USER_MAIN", bytes: int = 1000, offset: int = 4, length: int = 8) -> bool:
	return USAGE._enqueue("Map/test.s32",bytes,SHA,unit,offset,length,origin)

func settle() -> void:
	USAGE.flush(true)
	for _i: int in 1000:
		var started: int = Time.get_ticks_usec()
		USAGE.pump()
		maximum_pump_usec = maxi(maximum_pump_usec, Time.get_ticks_usec()-started)
		if USAGE._task < 0 and (USAGE._disabled or (USAGE._pending.is_empty() and not USAGE._dirty)): return
		await process_frame
	check(false,"worker finishes within fixture frame limit")

func read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func contract() -> void:
	var path: String = folder.path_join("contract.json")
	reset(path)
	check(not USAGE.observe(null,"Map/test.s32",1000,SHA,"fixture"),"non-Main/headless renderer cannot supply evidence")
	check(offer("first") and offer("first") and USAGE._pending.size() == 1,"duplicate ingress is one immutable observation")
	check(USAGE._pending[0].is_read_only(),"worker receives read-only scalar event")
	check(offer("first","AUTOMATED_ACTUAL_MAIN"),"QA origin remains separate")
	check(offer("outside","USER_MAIN",1000,999,8),"invalid byte range does not discard the valid unit")
	USAGE.flush()
	check(not FileAccess.file_exists(path) and USAGE._task == -1,"observe and draw flush do not read/write or submit work")
	await settle()
	var value: Dictionary = read(path)
	var row: Dictionary = value.members["Map/test.s32|"+SHA]
	check(value.schema == 1 and value.inventory_JSONL_SHA256 == USAGE.INVENTORY_SHA and int(value.fixed_Map_Tile_denominator.Map.files) == 8311 and int(value.fixed_Map_Tile_denominator.Tile.files) == 8514 and int(value.fixed_Map_Tile_denominator.Map.original_member_bytes) == 994755558 and int(value.fixed_Map_Tile_denominator.Tile.original_member_bytes) == 297767184,"v1 identity and denominator unchanged")
	check(not value.usage95_verified and not row.whole_file_used and row.original_member_bytes_fully_used_proven == 0,"partial observations never claim full source byte use")
	check(row.origins.USER_MAIN.units.size() == 2 and row.origins.AUTOMATED_ACTUAL_MAIN.units.size() == 1,"origins and units exact")
	check(row.origins.USER_MAIN.source_ranges == {"4:8":true},"only valid source range retained")
	check(USAGE.status().committed_observations == 3 and not USAGE.status().uncommitted,"acknowledged only after atomic save")
	reset(path)
	offer("after-restart")
	await settle()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.has("first"),"restart loads and merges old v1 ledger on worker")
	var old: String = FileAccess.get_file_as_string(path)
	offer("wrong-bytes","USER_MAIN",2000)
	await settle()
	check(FileAccess.get_file_as_string(path) == old and USAGE.status().rejected_observation_attempts == 1,"identity conflict is rejected without changing old evidence")

class SlowWorker extends USAGE.LedgerWorker:
	var gate := Semaphore.new()
	func run(batch: USAGE.Batch, result: Array) -> void:
		gate.wait()
		super.run(batch,result)

func bounded_and_lifetime() -> void:
	var path: String = folder.path_join("bounded.json")
	reset(path)
	var slow := SlowWorker.new(path)
	USAGE._worker = slow
	offer("inflight")
	USAGE.flush(true); USAGE.pump()
	var start: int = Time.get_ticks_usec()
	for i: int in 100: USAGE.flush(true); USAGE.pump()
	var returned: int = Time.get_ticks_usec()-start
	check(USAGE._task >= 0 and not WorkerThreadPool.is_task_completed(USAGE._task),"repeated pump never joins a blocked worker")
	for i: int in USAGE.MAX_PENDING: offer("pending%d" % i)
	check(USAGE._pending.size() <= USAGE.MAX_PENDING and USAGE._pending_bytes <= USAGE.MAX_PENDING_BYTES and USAGE._recorded.size() <= USAGE.MAX_RECENT,"inbox, byte reservation and dedup memory bounded")
	check(not offer("overflow") and USAGE.status().rejected_observation_attempts == 1,"overload is reported, never falsely marked accepted")
	# A scene's exit flush only signals; process-owned worker and inbox survive.
	USAGE.flush(true)
	check(USAGE._pending.size() == USAGE.MAX_PENDING,"scene flush keeps pending evidence alive")
	slow.gate.post()
	# One signal for the in-flight batch and another for the queued batch.
	slow.gate.post()
	await settle()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.size() == USAGE.MAX_PENDING+1,"both bounded batches survive scene change and commit")
	check(offer("overflow"),"rejected observation can be retried after capacity returns")
	slow.gate.post()
	USAGE.finish()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.has("overflow"),"normal teardown drains final observations")
	evidence.append({"blocked_worker_100_pumps_usec":returned})

class MissingResultWorker extends USAGE.LedgerWorker:
	func run(envelope: USAGE.Batch, _result: Array) -> void:
		envelope.events = []

func missing_result() -> void:
	var path: String = folder.path_join("missing-result.json")
	reset(path)
	USAGE._worker = MissingResultWorker.new(path)
	offer("unknown")
	await settle()
	check(USAGE._disabled and USAGE.status().uncommitted and not USAGE.problem.is_empty() and not FileAccess.file_exists(path),"missing worker result cannot crash gameplay or falsely acknowledge storage")

func payload_bound() -> void:
	var path: String = folder.path_join("payload-bound.json")
	reset(path)
	var accepted: int = 0
	var member: String = "Map/" + "p".repeat(1020)
	for i: int in 1000:
		if USAGE._enqueue(member,1000,SHA,("u%04d" % i)+"x".repeat(250),0,1,"USER_MAIN"): accepted += 1
	check(accepted > 0 and accepted < 1000 and USAGE._pending_bytes <= USAGE.MAX_PENDING_BYTES,"byte cap applies independently of event-count cap")
	check(USAGE._pending.size() == accepted and USAGE.status().rejected_observation_attempts == 1000-accepted,"saturated byte queue never claims rejected events")
	await settle()
	check(read(path).members[member+"|"+SHA].origins.USER_MAIN.units.size() == accepted,"all accepted byte-bound events survive persistence")

func failures_and_recovery() -> void:
	var path: String = folder.path_join("recover.json")
	reset(path); offer("old"); await settle()
	var old: String = FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(path+".tmp")
	offer("new"); USAGE.flush(true); USAGE.pump()
	while USAGE._task >= 0:
		USAGE.pump(); await process_frame
	check(USAGE._dirty and not USAGE.problem.is_empty() and FileAccess.get_file_as_string(path) == old,"failed atomic write retains old file and uncommitted worker state")
	USAGE.finish()
	check(USAGE._task < 0 and USAGE._dirty and USAGE.status().uncommitted,"failed shutdown has bounded retries and never claims durability")
	DirAccess.remove_absolute(path+".tmp")
	await settle()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.has("new") and not USAGE.status().uncommitted,"retry commits retained delta after storage recovers")
	# Orphan temp is never mistaken for committed evidence after restart.
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE); file.store_string("partial"); file.close()
	reset(path); offer("restart"); await settle()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.has("old"),"restart ignores incomplete temp and preserves committed observations")
	for content: String in ["{broken", '{"schema":2}', '{"schema":1,"inventory_JSONL_SHA256":"wrong","members":{}}']:
		path = folder.path_join("corrupt%d.json" % checks)
		file = FileAccess.open(path,FileAccess.WRITE); file.store_string(content); file.close()
		reset(path); offer("must-not-overwrite"); await settle()
		check(USAGE._disabled and FileAccess.get_file_as_string(path) == content and USAGE.status().uncommitted,"corrupt/incompatible ledger is retained byte-for-byte with explicit uncommitted status")
	# No save writer state/path is shared with game saves.
	var save_path: String = folder.path_join("player-save.json")
	WRITER.write(save_path,{"progress":42,"items":[7,8],"boss":12345})
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	reset(folder.path_join("separate-ledger.json")); offer("separate"); await settle()
	check(FileAccess.get_file_as_bytes(save_path) == save_bytes,"game-save sentinel remains byte-identical")

func benchmark(target_bytes: int) -> void:
	var path: String = folder.path_join("bench%d.json" % target_bytes)
	var units: Dictionary = {}
	for i: int in int(target_bytes / 196): units[("u%08d" % i) + "x".repeat(180)] = true
	var key: String = "Map/test.s32|"+SHA
	var value: Dictionary = {"schema":1,"inventory_JSONL_SHA256":USAGE.INVENTORY_SHA,"members":{key:{"member":"Map/test.s32","sha256":SHA,"original_member_bytes":1000,"usage":"PARTIAL_OBSERVATION","whole_file_used":false,"original_member_bytes_fully_used_proven":0,"origins":{"USER_MAIN":{"units":units,"source_ranges":{"4:8":true}}}}}}
	WRITER.write(path,value)
	var original: String = FileAccess.get_file_as_string(path)
	var started: int = Time.get_ticks_usec()
	var parsed: Dictionary = read(path)
	var parse_usec: int = Time.get_ticks_usec()-started
	parsed.members[key].origins.USER_MAIN.units["bench-new"] = true
	started = Time.get_ticks_usec()
	WRITER.write(path,parsed)
	var write_usec: int = Time.get_ticks_usec()-started
	var expected: Dictionary = read(path).members
	WRITER.write_text(path,original)
	reset(path)
	var memory: int = OS.get_static_memory_usage()
	started = Time.get_ticks_usec()
	offer("bench-new"); USAGE.flush(true)
	var ingress_usec: int = Time.get_ticks_usec()-started
	var ingress_memory: int = OS.get_static_memory_usage()-memory
	started = Time.get_ticks_usec()
	await settle()
	var wall_usec: int = Time.get_ticks_usec()-started
	check(read(path).members == expected,"benchmark exact committed units/ranges match synchronous v1 at %d bytes" % original.length())
	evidence.append({"ledger_bytes":original.to_utf8_buffer().size(),"sync_first_parse_usec":parse_usec,"sync_write_usec":write_usec,"render_ingress_and_flush_usec":ingress_usec,"worker_read_merge_write_usec":USAGE._last_worker_usec,"ready_wall_usec":wall_usec,"ingress_static_bytes_delta":ingress_memory,"process_static_bytes_delta_during_worker":OS.get_static_memory_usage()-memory,"process_static_peak_bytes":OS.get_static_memory_peak_usage()})

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--crash-fixture="):
			reset(arg.trim_prefix("--crash-fixture="))
			USAGE._worker = SlowWorker.new(arg.trim_prefix("--crash-fixture="))
			offer("crash-uncommitted")
			USAGE.flush(true); USAGE.pump()
			print("CRASH_FIXTURE_PENDING ", JSON.stringify(USAGE.status()))
			return
		if arg.begins_with("--exit-fixture="):
			reset(arg.trim_prefix("--exit-fixture="))
			offer("exit-unflushed")
			quit() # Autoload teardown, not an explicit test drain.
			return
	root.get_node("MapUsagePump").set_process(false)
	folder = ProjectSettings.globalize_path("user://map-usage-async-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	await contract()
	await bounded_and_lifetime()
	await missing_result()
	await payload_bound()
	await failures_and_recovery()
	for size: int in [800000,3000000,5600000]: await benchmark(size)
	USAGE.finish()
	print("MAP_USAGE_ASYNC_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"maximum_poll_submit_usec":maximum_pump_usec,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
