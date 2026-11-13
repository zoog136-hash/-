extends SceneTree
## Synthetic callback-delivery boundaries, never a device/GPU timing benchmark.
## Run headless; actual signal connections are inspected without awaiting draws.
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const PROBE = preload("res://scripts/boot/frame_hitch_probe.gd")
const DIR := "user://frame_hitch_draw_phases_test"
const ORIGIN: int = 1000000
var checks: int = 0
var failures: Array[String] = []

class FakeHost extends Node:
	var active_map_id: String = "paused_menu_fixture"
	var processes: int = 0
	var saw_probe_before: bool = false
	var saw_tail_before: bool = false
	func _process(_delta: float) -> void:
		processes += 1
		saw_probe_before = HITCH._last_frame > 0
		saw_tail_before = HITCH._process_tail_count > 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FRAME_HITCH_DRAW_PHASES_FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name: String in [HITCH.FILE_NAME, HITCH.PREV_NAME, HITCH.FILE_NAME + ".part"]:
		DirAccess.remove_absolute(DIR.path_join(name))

func _reset(delivery: int = 1) -> void:
	HITCH.reset_for_test(DIR)
	if delivery >= 0: HITCH.configure_draw_delivery(delivery == 1)

func _latest() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in HITCH.summary().worst:
		if int(entry.frame) > int(result.get("frame", -1)): result = entry
	check(not result.is_empty(), "fixture produced a recorded hitch")
	return result

func _callbacks(entry: Dictionary) -> Dictionary:
	return entry.get("diagnostics", {}).get("draw_callbacks", {})

func _pair(pre: int, post: int) -> void:
	HITCH.draw_at_for_test(true, pre)
	HITCH.draw_at_for_test(false, post)

func _check_wall(sample: Dictionary, expected: Dictionary, label: String) -> void:
	check(sample.get("status") == "ordered_synchronous_pair", label + " has an ordered synchronous pair")
	check(sample.get("delivery") == "main_thread", label + " identifies synchronous delivery")
	var wall: Dictionary = sample.get("wall_usec", {})
	check(wall.size() == 3, label + " has exactly three wall intervals")
	var total: int = 0
	for key: String in expected:
		var value: int = int(wall.get(key, -1))
		check(value == int(expected[key]), label + " exact " + key)
		total += value
	check(total == int(sample.get("next_probe_usec", 0)) - int(sample.get("probe_usec", 0)), label + " intervals partition the raw probe span")

func _ordered_boundaries() -> void:
	_reset()
	HITCH.frame_at_for_test(ORIGIN, "start")
	_pair(ORIGIN + 20000, ORIGIN + 150000)
	HITCH.frame_at_for_test(ORIGIN + 200000, "draw_interval")
	var entry: Dictionary = _latest()
	check(int(entry.get("ms", 0)) == 200 and HITCH.summary().frames == 1, "one exact 200 ms probe span is retained")
	_check_wall(_callbacks(entry), {"probe_to_pre":20000, "pre_to_post":130000, "post_to_probe":50000}, "draw interval")
	_pair(ORIGIN + 210000, ORIGIN + 220000)
	HITCH.frame_at_for_test(ORIGIN + 400000, "after_draw_interval")
	_check_wall(_callbacks(_latest()), {"probe_to_pre":10000, "pre_to_post":10000, "post_to_probe":180000}, "after-draw interval")
	# Equal boundaries are valid zero-duration intervals, not missing callbacks.
	_pair(ORIGIN + 400000, ORIGIN + 600000)
	HITCH.frame_at_for_test(ORIGIN + 600000, "equal_boundaries")
	_check_wall(_callbacks(_latest()), {"probe_to_pre":0, "pre_to_post":200000, "post_to_probe":0}, "equal boundaries")

func _invalid_boundaries() -> void:
	var cases: Array = [
		{"label":"no callbacks", "events":[], "status":"no_draw_callbacks"},
		{"label":"pre only", "events":[[true, 20000]], "status":"incomplete_callbacks"},
		{"label":"post only", "events":[[false, 150000]], "status":"incomplete_callbacks"},
		{"label":"post before pre", "events":[[false, 20000], [true, 150000]], "status":"out_of_order"},
		{"label":"duplicate pre", "events":[[true, 20000], [true, 30000], [false, 150000]], "status":"multiple_callbacks"},
		{"label":"duplicate post", "events":[[true, 20000], [false, 150000], [false, 160000]], "status":"multiple_callbacks"},
		{"label":"pre older than probe", "events":[[true, -1], [false, 150000]], "status":"out_of_order"},
		{"label":"negative pre timestamp", "events":[[true, -ORIGIN - 1], [false, 150000]], "status":"out_of_order"},
		{"label":"post beyond next probe", "events":[[true, 20000], [false, 200001]], "status":"out_of_order"},
	]
	for row: Dictionary in cases:
		_reset()
		HITCH.frame_at_for_test(ORIGIN)
		for event: Array in row.events: HITCH.draw_at_for_test(bool(event[0]), ORIGIN + int(event[1]))
		HITCH.frame_at_for_test(ORIGIN + 200000, str(row.label))
		var sample: Dictionary = _callbacks(_latest())
		check(sample.get("status") == row.status, str(row.label) + " reports its invalid sequence")
		check(not sample.has("wall_usec"), str(row.label) + " does not fabricate a wall partition")
		_pair(ORIGIN + 220000, ORIGIN + 250000)
		HITCH.frame_at_for_test(ORIGIN + 400000, "recovered")
		check(_callbacks(_latest()).get("status") == "ordered_synchronous_pair", str(row.label) + " cannot contaminate the following interval")
	_reset()
	_pair(ORIGIN - 20000, ORIGIN - 10000)
	HITCH.frame_at_for_test(ORIGIN)
	HITCH.frame_at_for_test(ORIGIN + 200000)
	check(_callbacks(_latest()).get("status") == "no_draw_callbacks", "callbacks before the first probe are discarded")
	# A delayed delivery from the preceding interval cannot become a valid pair.
	_pair(ORIGIN + 150000, ORIGIN + 250000)
	HITCH.frame_at_for_test(ORIGIN + 400000)
	check(_callbacks(_latest()).get("status") == "out_of_order", "stale prior-interval callback remains invalid")
	for mode: int in [-1, 0]:
		_reset(mode)
		HITCH.frame_at_for_test(ORIGIN)
		_pair(ORIGIN + 20000, ORIGIN + 150000)
		HITCH.frame_at_for_test(ORIGIN + 200000)
		var sample: Dictionary = _callbacks(_latest())
		check(sample.get("status") == ("unknown_delivery" if mode == -1 else "threaded_delivery"), "unverified or separate-thread delivery is explicit")
		check(sample.get("delivery") == ("unknown" if mode == -1 else "separate_thread") and not sample.has("wall_usec"), "delivery uncertainty suppresses inferred wall intervals")

func _accounting_and_logger() -> void:
	_reset()
	HITCH.frame_at_for_test(ORIGIN, "start", 140000)
	var before: int = HITCH.nested()
	var started: int = HITCH.now() - 100000
	HITCH.add("quests", HITCH.now() - 60000)
	HITCH.add_self("world", started, before)
	HITCH.detail("spawn.setup", HITCH.now() - 120000)
	HITCH.count("fixture.cache_miss", 2)
	var sections: Dictionary = HITCH._sections.duplicate()
	var nested: int = HITCH.nested()
	var details: Dictionary = HITCH._details.duplicate(true)
	_pair(ORIGIN + 20000, ORIGIN + 150000)
	check(HITCH._sections == sections and HITCH.nested() == nested and HITCH._details == details, "draw callbacks do not alter nested/exclusive/inclusive accounting")
	HITCH.frame_at_for_test(ORIGIN + 200000, "logger_raw", 30000)
	var entry: Dictionary = _latest()
	check(int(entry.get("ms", 0)) == 200 and HITCH.summary().hitches == 1, "logger overhead does not lower raw frame duration or hitch eligibility")
	check(int(entry.get("diagnostics", {}).get("logger_usec", -1)) == 140000, "prior probe logger duration is attributed to the next raw interval")
	var recorded: Dictionary = {}
	for part: Array in entry.get("sections", []): recorded[part[0]] = int(part[1])
	for key: String in sections:
		check(int(recorded.get(key, -1)) == int(sections[key]) / 1000, "draw attribution leaves exclusive section unchanged: " + key)
	check(entry.get("counters", {}) == {"fixture.cache_miss":2} and entry.get("details", []).size() == 1, "logger overhead is not recursively instrumented as a section/detail/counter")
	HITCH.frame_at_for_test(ORIGIN + 400000, "logger_next")
	check(int(_latest().get("diagnostics", {}).get("logger_usec", -1)) == 30000, "each interval retains only its preceding probe's logger duration")
	HITCH.frame_at_for_test(ORIGIN + 600000, "logger_reset")
	check(int(_latest().get("diagnostics", {}).get("logger_usec", -1)) == 0, "synthetic logger overhead resets instead of accumulating")
	_reset()
	HITCH.frame_at_for_test(ORIGIN, "threshold", 90000)
	HITCH.frame_at_for_test(ORIGIN + HITCH.THRESHOLD_USEC - 1)
	check(HITCH.summary().hitches == 0, "raw interval below threshold remains unrecorded")
	HITCH.frame_at_for_test(ORIGIN + 2 * HITCH.THRESHOLD_USEC - 1)
	check(HITCH.summary().hitches == 1 and int(_latest().get("ms", 0)) == 100, "raw interval exactly at threshold remains a hitch")
	# Automatic flush is already part of the enclosing probe measurement.
	_reset()
	HITCH.frame_at_for_test(6000000)
	HITCH._last_flush = 0
	HITCH.frame_at_for_test(6200000, "automatic_flush", 17)
	check(FileAccess.file_exists(DIR.path_join(HITCH.FILE_NAME)), "automatic flush exercised the real write path")
	check(HITCH._logger_usec == 17 and not HITCH._inside_probe, "automatic flush cannot recursively add another logger measurement")
	_reset()
	var real_started: int = HITCH.now()
	HITCH.frame("real_probe")
	var real_elapsed: int = HITCH.now() - real_started
	check(HITCH._logger_usec >= 0 and HITCH._logger_usec <= real_elapsed, "real probe logger scalar is bounded by its enclosing wall interval")
	var logger_before: int = HITCH._logger_usec
	real_started = HITCH.now()
	HITCH.flush()
	real_elapsed = HITCH.now() - real_started
	var flush_elapsed: int = HITCH._logger_usec - logger_before
	check(flush_elapsed >= 0 and flush_elapsed <= real_elapsed, "external flush adds only its bounded elapsed duration")
	check(HITCH.summary().frames == 0 and HITCH._sections.is_empty() and HITCH._details.is_empty() and HITCH._counters.is_empty(), "real logger work creates no recursive frame, section or operation diagnostics")

func _disabled_reset_and_bounds() -> void:
	_reset()
	HITCH.frame_at_for_test(ORIGIN, "discard", 77)
	_pair(ORIGIN + 20000, ORIGIN + 150000)
	HITCH.add("discard", HITCH.now() - 1000)
	HITCH.detail("discard", HITCH.now() - 1000)
	HITCH.count("discard")
	HITCH.slow_spawn({"usec":150000, "npc":1})
	HITCH.enabled = false
	_pair(ORIGIN + 220000, ORIGIN + 250000)
	HITCH.frame_at_for_test(ORIGIN + 400000, "off", 999)
	check(HITCH.summary().frames == 0 and HITCH.summary().hitches == 0, "disabled probe and callbacks record nothing")
	HITCH.enabled = true
	HITCH.frame_at_for_test(ORIGIN + 600000)
	HITCH.frame_at_for_test(ORIGIN + 800000)
	var entry: Dictionary = _latest()
	check(_callbacks(entry).get("status") == "no_draw_callbacks" and int(entry.get("diagnostics", {}).get("logger_usec", -1)) == 0, "re-enable discards prior anchor, callbacks and logger duration")
	check(entry.get("sections", []) == [["other", 200]] and not entry.has("details") and not entry.has("counters") and not entry.has("slow_spawn"), "re-enable discards all pending gameplay diagnostics")
	HITCH.frame_at_for_test(ORIGIN + 1000000, "before_reset", 88)
	_pair(ORIGIN + 1020000, ORIGIN + 1050000)
	_reset(-1)
	HITCH.frame_at_for_test(ORIGIN)
	_pair(ORIGIN + 20000, ORIGIN + 150000)
	HITCH.frame_at_for_test(ORIGIN + 200000)
	entry = _latest()
	check(_callbacks(entry).get("status") == "unknown_delivery" and int(entry.get("diagnostics", {}).get("logger_usec", -1)) == 0 and HITCH.summary().frames == 1, "reset clears delivery verification, pending duration, callbacks and frame history")
	_reset()
	HITCH.frame_at_for_test(ORIGIN)
	for index: int in 5000: _pair(ORIGIN + 20000 + index, ORIGIN + 150000 + index)
	HITCH.frame_at_for_test(ORIGIN + 200000)
	var crowded: Dictionary = _callbacks(_latest())
	check(crowded.get("status") == "multiple_callbacks" and int(crowded.get("pre_count", 0)) == 5000 and int(crowded.get("post_count", 0)) == 5000, "many callbacks are represented by scalar counts")
	check(crowded.size() == 8 and not crowded.has("wall_usec"), "many callbacks keep a fixed-size diagnostic sample")
	for index: int in 20:
		var at: int = ORIGIN + 200000 * (index + 1)
		_pair(at + 20000, at + 150000)
		HITCH.frame_at_for_test(at + 200000)
	var summary: Dictionary = HITCH.summary()
	check(summary.worst.size() == HITCH.KEEP and summary.hitches == 21, "callback diagnostics preserve bounded worst-frame retention and total hitch count")
	for kept: Dictionary in summary.worst:
		var diag: Dictionary = kept.get("diagnostics", {})
		check(diag.size() == 5 and _callbacks(kept).size() <= 9 and diag.process_tail.size() <= 5 and diag.lifecycle.size() == 7 and diag.record_snapshot.size() == 4, "retained diagnostics have fixed-size callback, lifecycle, tail and record-time fields")
	check(JSON.stringify(summary).length() < 65536, "bounded callback fixture remains readable under the previous-record size limit")

func _persistence() -> void:
	_clean()
	_reset()
	HITCH.frame_at_for_test(ORIGIN, "start", 321)
	HITCH.process_tail_at_for_test(ORIGIN + 10000)
	HITCH.lifecycle_at_for_test(0, ORIGIN + 80000)
	_pair(ORIGIN + 20000, ORIGIN + 150000)
	HITCH.frame_at_for_test(ORIGIN + 200000, "persisted")
	HITCH.flush()
	_reset()
	HITCH.start()
	var previous: Dictionary = HITCH.read_previous()
	var rows: Array = previous.get("worst", [])
	check(rows.size() == 1, "phase record survives atomic write and next-start rotation")
	if not rows.is_empty():
		check(int(rows[0].get("diagnostics", {}).get("logger_usec", -1)) == 321, "persisted logger scalar preserves the original interval attribution")
		_check_wall(_callbacks(rows[0]), {"probe_to_pre":20000, "pre_to_post":130000, "post_to_probe":50000}, "persisted boundaries")
		var saved_tail: Dictionary = rows[0].diagnostics.process_tail.wall_usec
		var saved_events: Array = rows[0].diagnostics.lifecycle.counts_pause_resume_out_in
		check(int(saved_tail.probe_to_tail) == 10000 and int(saved_tail.tail_to_probe) == 190000 and PackedInt64Array(saved_events) == PackedInt64Array([1,0,0,0]), "tail partition and lifecycle counts survive JSON rotation")
	check(HITCH.previous_line().contains("20/130/50ms"), "loading line identifies the three measured callback intervals")
	check(HITCH.previous_line().contains("후순위표식 10/190ms") and HITCH.previous_line().contains("앱알림 1/0/0/0(정지/재개/이탈/복귀)"), "loading line exposes persisted tail and lifecycle context")
	_clean()
	var file := FileAccess.open(DIR.path_join(HITCH.FILE_NAME), FileAccess.WRITE)
	check(file != null, "legacy fixture file opens")
	if file != null:
		file.store_string(JSON.stringify({"schema":1, "frames":3, "hitches":2, "worst":[{"ms":200, "sections":[["quests",180],["other",20]], "map":"legacy", "frame":1}]}))
		file.close()
	_reset()
	HITCH.start()
	check(int(HITCH.read_previous().get("schema", 0)) == 1, "legacy schema-1 records without diagnostics remain readable")
	var line: String = HITCH.previous_line()
	check(line.begins_with("지난 실행 끊김 2회 · 최대 200ms") and line.contains("퀘스트 180ms"), "legacy loading line preserves count, duration and section attribution")
	check(not line.contains("콜백 구간"), "legacy record does not invent missing callback intervals")
	check(line.contains("콜백 미기록") and line.contains("기록빌드 미상"), "legacy record explicitly identifies missing draw diagnostics and build")

func _tail_and_lifecycle() -> void:
	_reset()
	# Startup notifications establish state but cannot become interval events.
	HITCH.lifecycle_at_for_test(3, ORIGIN - 10)
	HITCH.frame_at_for_test(ORIGIN)
	HITCH.process_tail_at_for_test(ORIGIN + 30000)
	_pair(ORIGIN + 50000, ORIGIN + 150000)
	for event: int in 4: HITCH.lifecycle_at_for_test(event, ORIGIN + 60000 + event * 10000)
	var snapshot_before: int = HITCH.now()
	HITCH.frame_at_for_test(ORIGIN + 200000)
	var snapshot_after: int = HITCH.now()
	var entry: Dictionary = _latest()
	var diag: Dictionary = entry.diagnostics
	check(entry.ms == 200 and entry.sections == [["other",200]], "lifecycle context never excludes background/focus time from raw hitch or residual")
	check(diag.process_tail.status == "ordered_marker" and diag.process_tail.wall_usec == {"probe_to_tail":30000,"tail_to_probe":170000} and diag.process_tail.tail_to_pre_usec == 20000, "ordered tail partitions raw span and safely subdivides the validated pre-draw span")
	check(diag.lifecycle.counts_pause_resume_out_in == PackedInt64Array([1,1,1,1]) and diag.lifecycle.first_usec == ORIGIN + 60000 and diag.lifecycle.last_usec == ORIGIN + 90000, "all four lifecycle event types retain fixed counts and first/last times")
	check(diag.lifecycle.paused_start == -1 and diag.lifecycle.paused_end == 0 and diag.lifecycle.focused_start == 1 and diag.lifecycle.focused_end == 1, "lifecycle captures observed state at both window boundaries")
	check(diag.record_snapshot.sampled_usec >= snapshot_before and diag.record_snapshot.sampled_usec <= snapshot_after and diag.record_snapshot.static_memory_bytes >= 0 and diag.record_snapshot.nodes >= 0 and diag.record_snapshot.objects >= 0, "memory/node/object snapshot is sampled during record creation, not invented interval peaks")
	HITCH.frame_at_for_test(ORIGIN + 400000)
	var next: Dictionary = _latest().diagnostics
	check(next.lifecycle.counts_pause_resume_out_in == PackedInt64Array([0,0,0,0]) and next.lifecycle.paused_start == 0 and next.lifecycle.focused_start == 1, "next window carries state but resets event counts")
	check(diag.lifecycle.counts_pause_resume_out_in == PackedInt64Array([1,1,1,1]), "retained lifecycle counts do not alias mutable pending state")
	check(next.process_tail.status == "missing" and not next.process_tail.has("wall_usec"), "next window cannot reuse an earlier tail marker")
	for row: Dictionary in [
		{"times":[],"status":"missing"},
		{"times":[ORIGIN+10000,ORIGIN+20000],"status":"multiple"},
		{"times":[ORIGIN-1],"status":"out_of_order"},
		{"times":[ORIGIN+200001],"status":"out_of_order"}]:
		_reset()
		HITCH.frame_at_for_test(ORIGIN)
		for at: int in row.times: HITCH.process_tail_at_for_test(at)
		HITCH.frame_at_for_test(ORIGIN + 200000)
		var tail: Dictionary = _latest().diagnostics.process_tail
		check(tail.status == row.status and not tail.has("wall_usec") and not tail.has("tail_to_pre_usec"), "invalid tail retains raw markers without derived durations: " + row.status)
	for mode: int in [-1,0,1]:
		_reset(mode)
		HITCH.frame_at_for_test(ORIGIN)
		HITCH.process_tail_at_for_test(ORIGIN + 60000)
		_pair(ORIGIN + 50000, ORIGIN + 150000)
		HITCH.frame_at_for_test(ORIGIN + 200000)
		var tail: Dictionary = _latest().diagnostics.process_tail
		check(tail.status == "ordered_marker" and not tail.has("tail_to_pre_usec"), "tail after pre or uncertain delivery cannot produce a tail-to-pre duration")
	_reset()
	HITCH.frame_at_for_test(ORIGIN)
	for index: int in 5000:
		HITCH.lifecycle_at_for_test(index % 4, ORIGIN + index)
		HITCH.process_tail_at_for_test(ORIGIN + index)
	HITCH.frame_at_for_test(ORIGIN + 200000)
	diag = _latest().diagnostics
	check(diag.lifecycle.size() == 7 and diag.lifecycle.counts_pause_resume_out_in == PackedInt64Array([1250,1250,1250,1250]) and diag.process_tail.count == 5000, "many lifecycle/tail callbacks remain fixed-size")
	HITCH.enabled = false
	HITCH.lifecycle_at_for_test(0, ORIGIN + 250000)
	HITCH.process_tail_at_for_test(ORIGIN + 260000)
	HITCH.enabled = true
	HITCH.frame_at_for_test(ORIGIN + 400000)
	HITCH.frame_at_for_test(ORIGIN + 600000)
	diag = _latest().diagnostics
	check(diag.lifecycle.paused_start == -1 and diag.lifecycle.focused_start == -1 and diag.lifecycle.counts_pause_resume_out_in == PackedInt64Array([0,0,0,0]) and diag.process_tail.count == 0, "enable/disable resets lifecycle state and pending tail markers")
	_reset()
	check(HITCH._process_tail_count == 0 and HITCH._application_paused == -1 and HITCH._application_focused == -1, "test reset clears all new state")

func _previous_diagnostic_labels() -> void:
	_reset()
	HITCH._build = {"version_name":"current-header-must-not-appear"}
	var top: Dictionary = {"ms":200,"sections":[["other",200]],"build":{"version_name":"523.434","commit":"1234567890abcdef"}}
	HITCH._previous = {"schema":1,"build":{"version_name":"summary-build"},"worst":[top]}
	var line: String = HITCH.previous_line()
	check(line.contains("기록빌드 523.434@12345678") and not line.contains("current-header") and not line.contains("summary-build"), "saved hitch build wins over both current APK and summary")
	top.erase("build")
	check(HITCH.previous_line().contains("기록빌드 summary-build"), "saved summary build is fallback for old entries")
	for row: Array in [["no_draw_callbacks","없음"],["multiple_callbacks","중복"],["incomplete_callbacks","누락"],["out_of_order","역순"],["threaded_delivery","별도스레드"],["unknown_delivery","스레드미상"]]:
		top["diagnostics"] = {"draw_callbacks":{"status":row[0],"delivery":"separate_thread","pre_count":1,"post_count":0}}
		line = HITCH.previous_line()
		check(line.contains("콜백 " + row[1] + " 1/0(별도)") and not line.contains("콜백 구간"), "non-partition draw status is visible: " + row[0])
	top["diagnostics"] = {"draw_callbacks":{"status":"unrecognized","pre_count":50000,"post_count":-1}}
	check(HITCH.previous_line().contains("콜백 미확인 9999/0(미상)"), "unexpected draw statuses and huge counts have bounded display")
	top["diagnostics"] = "invalid"
	check(HITCH.previous_line().contains("콜백 미기록"), "malformed diagnostics remain readable as missing")
	for row: Array in [["missing","없음"],["multiple","중복"],["out_of_order","역순"]]:
		top["diagnostics"] = {"process_tail":{"status":row[0],"count":2}}
		check(HITCH.previous_line().contains("후순위표식 " + row[1] + "(2)"), "invalid tail status has a short visible label: " + row[0])
	for state: int in [-1,0]:
		top["diagnostics"] = {"lifecycle":{"counts_pause_resume_out_in":[0,0,0,0],"paused_start":state,"paused_end":state,"focused_start":-1 if state == -1 else 1,"focused_end":-1 if state == -1 else 1}}
		line = HITCH.previous_line()
		check(not line.contains("앱알림") and not line.contains("앱상태"), "unknown or foreground state without events does not crowd loading line")
	top["diagnostics"] = {"lifecycle":{"counts_pause_resume_out_in":[0,0,0,0],"paused_start":1,"paused_end":1,"focused_start":0,"focused_end":0}}
	check(HITCH.previous_line().contains("앱상태 정지/이탈"), "persisted background state remains visible without new events")
	top.diagnostics.lifecycle.counts_pause_resume_out_in = [0,1,0,1]
	check(HITCH.previous_line().contains("앱알림 0/1/0/1(정지/재개/이탈/복귀)"), "resume and focus-return events have understandable compact labels")

func _connections(signal_name: StringName, callback: Callable) -> int:
	var count: int = 0
	for connection: Dictionary in RenderingServer.get_signal_connection_list(signal_name):
		if connection.get("callable") == callback: count += 1
	return count

func _probe_lifecycle() -> void:
	_clean()
	_reset()
	var host := FakeHost.new()
	root.add_child(host)
	var probe := PROBE.new()
	host.add_child(probe)
	var pre := Callable(probe, "_on_pre_draw")
	var post := Callable(probe, "_on_post_draw")
	check(probe.process_priority == -2147483647 and probe.process_mode == Node.PROCESS_MODE_ALWAYS, "actual probe remains first-priority and active while paused")
	check(_connections("frame_pre_draw", pre) == 1 and _connections("frame_post_draw", post) == 1, "probe connects each callback once on tree entry")
	var tail: Node = probe._tail
	check(tail != null and tail.process_priority == 2147483647 and tail.process_mode == Node.PROCESS_MODE_ALWAYS, "probe owns one late-priority always-processing tail child")
	await process_frame
	await process_frame
	check(host.saw_probe_before and not host.saw_tail_before and HITCH._process_tail_count == 1 and HITCH._process_tail_usec >= HITCH._last_frame, "actual main-group order is probe then ordinary host then tail")
	var pre_before: int = HITCH._pre_draw_count
	var post_before: int = HITCH._post_draw_count
	pre.call()
	post.call()
	check(HITCH._pre_draw_count == pre_before + 1 and HITCH._post_draw_count == post_before + 1, "actual probe callbacks forward exactly one marker each")
	var frames_before: int = int(HITCH.summary().frames)
	var host_before: int = host.processes
	paused = true
	await process_frame
	await process_frame
	check(probe.can_process() and int(HITCH.summary().frames) > frames_before, "actual probe continues closing intervals for a paused menu")
	check(host.processes == host_before, "paused fixture parent actually stops gameplay processing")
	check(tail.can_process() and HITCH._process_tail_count == 1, "tail keeps recording while gameplay tree is paused")
	paused = false
	var lifecycle_before: PackedInt64Array = HITCH._lifecycle_counts.duplicate()
	for notification_id: int in [Node.NOTIFICATION_APPLICATION_PAUSED,Node.NOTIFICATION_APPLICATION_RESUMED,Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_FOCUS_IN]: probe.notification(notification_id)
	for event: int in 4: check(HITCH._lifecycle_counts[event] == lifecycle_before[event] + 1, "actual probe forwards lifecycle notification " + str(event))
	for notification_id: int in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		DirAccess.remove_absolute(DIR.path_join(HITCH.FILE_NAME))
		probe.notification(notification_id)
		check(FileAccess.file_exists(DIR.path_join(HITCH.FILE_NAME)), "probe notification flushes current record: " + str(notification_id))
	host.remove_child(probe)
	check(_connections("frame_pre_draw", pre) == 0 and _connections("frame_post_draw", post) == 0, "probe disconnects both callbacks on tree exit")
	host.add_child(probe)
	check(_connections("frame_pre_draw", pre) == 1 and _connections("frame_post_draw", post) == 1, "probe reconnects once on re-entry without another ready call")
	check(probe._tail == tail and probe.get_child_count() == 1, "probe re-entry preserves exactly one tail child")
	DirAccess.remove_absolute(DIR.path_join(HITCH.FILE_NAME))
	probe.free()
	check(not is_instance_valid(tail), "probe deletion also frees tail child")
	check(FileAccess.file_exists(DIR.path_join(HITCH.FILE_NAME)), "probe deletion still flushes the current record")
	host.free()

func _run() -> void:
	_clean()
	_ordered_boundaries()
	_invalid_boundaries()
	_accounting_and_logger()
	_disabled_reset_and_bounds()
	_persistence()
	_tail_and_lifecycle()
	_previous_diagnostic_labels()
	await _probe_lifecycle()
	_clean()
	HITCH.reset_for_test(DIR)
	print("FRAME_HITCH_DRAW_PHASES_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
