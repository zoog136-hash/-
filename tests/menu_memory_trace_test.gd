extends SceneTree
## Standalone diagnostics test: no Main, original pack, APK, or game save.
const TRACE = preload("res://scripts/boot/menu_memory_trace.gd")
var checks: int = 0
var failures: Array[String] = []
var memory_reads: int = 0
var directory: String

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func fixture_memory() -> String:
	memory_reads += 1
	return "static_kb=12 static_max_kb=24 objects=99 tex_kb=0 vmrss_kb=123 vmhwm_kb=234 unsupported=8"

func read_current() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(TRACE.FILE_NAME)))
	return value if value is Dictionary else {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = "user://menu_memory_trace_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	TRACE.reset_for_test(directory, Callable(self, "fixture_memory"))
	var token: int = TRACE.begin("quests")
	var first: Dictionary = read_current()
	check(token > 0 and first.events.size() == 2, "session and begin are persisted before handler work")
	var begun: Dictionary = first.events.back()
	check(begun.event == "menu_begin" and begun.menu == "quests" and begun.token == token and begun.call == 1, "exact accepted menu and token recorded")
	check(begun.memory.tex_kb == 0 and "tex_kb" not in begun.unavailable, "valid zero GPU counter remains available")
	check(begun.memory.available_kb == -1 and "available_kb" in begun.unavailable and begun.memory.physical_kb == -1, "unsupported metrics explicitly unavailable")
	check(begun.memory.vmrss_kb == 123 and begun.memory.vmhwm_kb == 234, "process RSS/HWM remain distinct")
	check(not begun.memory.has("unsupported"), "collector output cannot add arbitrary fields")
	TRACE.end(token, false)
	var ended: Dictionary = read_current().events.back()
	check(ended.event == "menu_end" and ended.ok == false and ended.elapsed_usec >= 0 and ended.token == token, "handler result and nonnegative elapsed time recorded")
	var count_before: int = TRACE.snapshot().events.size()
	TRACE.end(token)
	TRACE.end(0)
	check(TRACE.snapshot().events.size() == count_before, "duplicate and unknown completions do not write events")
	check(TRACE.begin("quest:private-id") == 0, "arbitrary identifiers cannot become menu labels")
	TRACE.lifecycle("unknown")
	check(TRACE.snapshot().events.size() == count_before, "unknown lifecycle values do not write events")
	for state: String in TRACE.LIFECYCLE: TRACE.lifecycle(state)
	check(TRACE.snapshot().events.back().state == "close_request", "ordinary lifecycle is recorded by its notification name")
	var encoded: String = JSON.stringify(TRACE.snapshot())
	check(not encoded.contains("crash") and not encoded.contains("oom"), "records make no crash or OOM classification")
	var before_reads: int = memory_reads
	var before_hash: String = FileAccess.get_sha256(directory.path_join(TRACE.FILE_NAME))
	TRACE.snapshot()
	TRACE.read_previous()
	check(memory_reads == before_reads and FileAccess.get_sha256(directory.path_join(TRACE.FILE_NAME)) == before_hash, "read-only inspection performs no memory sample or disk write")
	var external: Dictionary = TRACE.snapshot()
	external.events[0].memory.static_kb = 999
	check(TRACE.snapshot().events[0].memory.static_kb == 12, "snapshot cannot mutate recorder state")
	for index: int in 100:
		var repeated: int = TRACE.begin("inventory")
		TRACE.end(repeated)
	var bounded: Dictionary = read_current()
	check(bounded.events.size() == TRACE.MAX_EVENTS and FileAccess.get_size(directory.path_join(TRACE.FILE_NAME)) <= TRACE.MAX_BYTES, "persistent snapshot stays within event and byte limits")
	check(bounded.menu_calls.inventory == 100 and bounded.pending_count == 0, "menu counts and completed spans survive ring eviction")
	check(not FileAccess.file_exists(directory.path_join(TRACE.FILE_NAME) + ".part"), "successful atomic writes leave no temporary file")
	for index: int in 20: TRACE.begin("shop")
	check(TRACE.snapshot().pending_count == TRACE.MAX_PENDING and TRACE.snapshot().dropped_spans == 12, "unmatched spans remain bounded")
	# Simulate a new process seeing a last begin. No claim about why it ended.
	var previous_run: String = TRACE.snapshot().run
	TRACE.reset_for_test(directory, Callable(self, "fixture_memory"))
	TRACE.start()
	var previous: Dictionary = TRACE.read_previous()
	check(previous.run == previous_run and previous.events.back().event == "menu_begin", "previous last event is preserved without a synthetic completion")
	check(read_current().events.size() == 1 and read_current().events[0].event == "session_start", "new session has its own trace")
	TRACE.start()
	check(read_current().events.size() == 1, "start is idempotent within a session")
	# A diagnostic write failure must not reject a menu or repeatedly retry IO.
	TRACE.reset_for_test(directory.path_join("missing/deeper"), Callable(self, "fixture_memory"))
	token = TRACE.begin("character")
	TRACE.end(token)
	TRACE.lifecycle("paused")
	var failed: Dictionary = TRACE.snapshot()
	check(token > 0 and failed.menu_calls.character == 1 and failed.pending_count == 0, "unwritable diagnostics do not block the handler contract")
	check(failed.storage_failed and failed.write_failures == 1 and failed.events.back().state == "paused", "storage failure is bounded while in-memory events continue")
	# The default collector is reused; absent headless GPU counters stay unknown.
	TRACE.reset_for_test(directory)
	var memory: Dictionary = TRACE._memory()
	check(memory.size() == TRACE.MEMORY_FIELDS.size() and memory.static_kb >= 0 and memory.objects >= 0, "real collector supplies engine metrics")
	if DisplayServer.get_name() == "headless":
		check(memory.tex_kb == -1 and memory.buf_kb == -1 and memory.vid_kb == -1, "headless GPU metrics are unavailable, not false zeros")
	var invalid := FileAccess.open(directory.path_join(TRACE.PREV_NAME), FileAccess.WRITE)
	invalid.store_buffer("{".to_utf8_buffer())
	invalid.close()
	check(TRACE.read_previous().is_empty(), "truncated previous trace is ignored")
	invalid = FileAccess.open(directory.path_join(TRACE.PREV_NAME), FileAccess.WRITE)
	var oversized := PackedByteArray()
	oversized.resize(TRACE.MAX_BYTES + 1)
	invalid.store_buffer(oversized)
	invalid.close()
	check(TRACE.read_previous().is_empty(), "oversized previous trace is not parsed")
	print("MENU_MEMORY_TRACE_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "scope":"standalone recorder only; no APK termination diagnosis"}))
	quit(0 if failures.is_empty() else 1)
