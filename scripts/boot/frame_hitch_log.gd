extends RefCounted
## Frame hitch record for slow devices (the phone cannot be profiled here).
##
## Per-frame systems add their elapsed time to a named section with
## `add(section, now())` (two Time.get_ticks_usec() calls, no allocation once
## the section exists). FrameHitchProbe, the first node processed each frame,
## measures the whole previous frame (scripts + physics + drawing). A frame
## longer than THRESHOLD_USEC keeps its sections; the KEEP slowest frames go to
## user://frame_hitch.json (at most every FLUSH_USEC, and on quit/pause) and to
## logcat as "FRAME_HITCH {...}". The next start moves it to
## frame_hitch.prev.json so the loading screen can name what stalled last time.
const FILE_NAME := "frame_hitch.json"
const PREV_NAME := "frame_hitch.prev.json"
const PREFIX := "FRAME_HITCH "
const THRESHOLD_USEC: int = 100000
const KEEP: int = 12
const FLUSH_USEC: int = 5000000
## Korean labels for the loading screen; unknown sections show their key.
const LABELS: Dictionary = {
	"world":"월드 기타", "quests":"퀘스트", "hud":"HUD 갱신", "auto_hunt":"자동 사냥",
	"skills":"스킬", "loot":"드랍·줍기", "save":"저장", "field_triggers":"맵 이벤트",
	"monsters":"몬스터", "player":"캐릭터", "field_population":"몬스터 배치",
	"map_renderer":"지도 그리기", "map_objects":"맵 오브젝트", "monsterbook":"몬스터북",
	"companion":"동료", "buffs":"버프", "dungeon":"던전", "items":"아이템 자동 사용",
	"hud_main":"원작 HUD", "ui_animation":"UI 애니메이션", "npcs":"NPC",
	"other":"미계측 잔여",
}

static var _dir: String = "user://"
static var _sections: Dictionary = {}
## Inclusive sub-operation timings, separate from the exclusive section totals.
## Each row keeps [total usec, calls, longest call usec] for this frame only.
static var _details: Dictionary = {}
static var _counters: Dictionary = {}
static var _slow_spawn: Dictionary = {}
static var _build: Dictionary = {}
static var _frames: int = 0
static var _hitches: int = 0
static var _worst: Array = []
static var _last_frame: int = 0
static var _dirty: bool = false
static var _last_flush: int = 0
static var _started: bool = false
static var _previous: Dictionary = {}
static var enabled: bool = true:
	set(value):
		if enabled == value: return
		enabled = value
		# Disabled time/callbacks must not leak into the next measured interval.
		_last_frame = 0
		_application_paused = -1
		_application_focused = -1
		_clear_pending()
static var _nested: int = 0
## Callback-delivery boundaries, not GPU timestamps. One fixed-size sample per
## probe interval; separate-thread post callbacks can belong to an earlier draw.
static var _draw_delivery: String = "unknown"
static var _pre_draw_usec: int = 0
static var _post_draw_usec: int = 0
static var _pre_draw_count: int = 0
static var _post_draw_count: int = 0
## Work done by the previous probe/flush belongs to the next raw wall interval.
## It never enters exclusive sections or creates another diagnostic event.
static var _logger_usec: int = 0
static var _inside_probe: bool = false
## A late-priority callback in the probe's process group, not completion of
## all nodes, physics, deferred work, other thread groups or rendering.
static var _process_tail_usec: int = 0
static var _process_tail_count: int = 0
## Notification observations only: -1 means unknown. Preserve state between
## windows, but retain only four counts and first/last timestamps per window.
static var _application_paused: int = -1
static var _application_focused: int = -1
static var _pause_at_start: int = -1
static var _focus_at_start: int = -1
static var _lifecycle_counts: PackedInt64Array = PackedInt64Array([0,0,0,0])
static var _lifecycle_first_usec: int = 0
static var _lifecycle_last_usec: int = 0

static func now() -> int:
	return Time.get_ticks_usec()

## Diagnose a single long spawn/cache miss without double-counting its parent.
static func detail(operation: String, started_usec: int) -> void:
	if not enabled: return
	var elapsed: int = maxi(0, Time.get_ticks_usec() - started_usec)
	if not _details.has(operation): _details[operation] = [0, 0, 0]
	var row: Array = _details[operation]
	row[0] += elapsed
	row[1] += 1
	row[2] = maxi(int(row[2]), elapsed)

static func count(operation: String, amount: int = 1) -> void:
	if not enabled: return
	_counters[operation] = int(_counters.get(operation, 0)) + amount

## One bounded, scalar-only setup sample, not a copy of an actor/source record.
static func slow_spawn(sample: Dictionary) -> void:
	if not enabled or int(sample.get("usec",0)) < THRESHOLD_USEC: return
	if int(sample.usec) > int(_slow_spawn.get("usec",0)):
		_slow_spawn = sample.duplicate(true)

static func add(section: String, started_usec: int) -> void:
	if not enabled: return
	var elapsed: int = Time.get_ticks_usec() - started_usec
	_nested += elapsed
	_sections[section] = int(_sections.get(section, 0)) + elapsed

## Time already given to sections; pass it to add_self() to exclude them.
static func nested() -> int:
	return _nested

## Adds the elapsed time minus whatever add() recorded since `nested_before`.
static func add_self(section: String, started_usec: int, nested_before: int) -> void:
	if not enabled: return
	var elapsed: int = Time.get_ticks_usec() - started_usec - (_nested - nested_before)
	_nested += maxi(0, elapsed)
	_sections[section] = int(_sections.get(section, 0)) + maxi(0, elapsed)

## Called once per frame, before any other node processes.
static func frame(map_id: String = "") -> void:
	if not enabled: return
	var at: int = Time.get_ticks_usec()
	_close_frame(at, map_id)
	_logger_usec += maxi(0, Time.get_ticks_usec() - at)

static func _close_frame(at: int, map_id: String) -> void:
	_inside_probe = true
	if _last_frame > 0:
		_frames += 1
		var total: int = at - _last_frame
		if total >= THRESHOLD_USEC: _record(total, map_id, at)
	_last_frame = at
	_clear_pending()
	if _dirty and at - _last_flush >= FLUSH_USEC: flush()
	_inside_probe = false

static func _clear_pending() -> void:
	_sections.clear()
	_details.clear()
	_counters.clear()
	_slow_spawn = {}
	_logger_usec = 0
	_clear_draw_callbacks()
	_process_tail_usec = 0
	_process_tail_count = 0
	_pause_at_start = _application_paused
	_focus_at_start = _application_focused
	_lifecycle_counts.fill(0)
	_lifecycle_first_usec = 0
	_lifecycle_last_usec = 0

static func process_tail() -> void:
	_mark_process_tail(Time.get_ticks_usec())

static func _mark_process_tail(at: int) -> void:
	if not enabled or _last_frame <= 0: return
	_process_tail_count += 1
	if _process_tail_count == 1: _process_tail_usec = at

static func _process_tail_sample(at: int, draw: Dictionary) -> Dictionary:
	var result: Dictionary = {"usec":_process_tail_usec, "count":_process_tail_count}
	if _process_tail_count == 0: result["status"] = "missing"
	elif _process_tail_count != 1: result["status"] = "multiple"
	elif not (_last_frame <= _process_tail_usec and _process_tail_usec <= at): result["status"] = "out_of_order"
	else:
		result["status"] = "ordered_marker"
		result["wall_usec"] = {"probe_to_tail":_process_tail_usec - _last_frame, "tail_to_probe":at - _process_tail_usec}
		# Only split the pre-draw wall span when both independently validated
		# markers have the required order. These overlap the draw diagnostics.
		if draw.get("status") == "ordered_synchronous_pair" and _process_tail_usec <= _pre_draw_usec:
			result["tail_to_pre_usec"] = _pre_draw_usec - _process_tail_usec
	return result

## Event indices: application pause, resume, focus out, focus in. No elapsed
## time is removed, and no duration is inferred from platform notifications.
static func lifecycle(event: int) -> void:
	_mark_lifecycle(event, Time.get_ticks_usec())

static func _mark_lifecycle(event: int, at: int) -> void:
	if not enabled or event < 0 or event >= 4: return
	if event < 2: _application_paused = 1 if event == 0 else 0
	else: _application_focused = 0 if event == 2 else 1
	if _last_frame <= 0: return
	if _lifecycle_counts[0] + _lifecycle_counts[1] + _lifecycle_counts[2] + _lifecycle_counts[3] == 0:
		_lifecycle_first_usec = at
	_lifecycle_counts[event] += 1
	_lifecycle_last_usec = at

static func _lifecycle_sample() -> Dictionary:
	return {"counts_pause_resume_out_in":_lifecycle_counts.duplicate(),
		"first_usec":_lifecycle_first_usec, "last_usec":_lifecycle_last_usec,
		"paused_start":_pause_at_start, "paused_end":_application_paused,
		"focused_start":_focus_at_start, "focused_end":_application_focused}

static func _clear_draw_callbacks() -> void:
	_pre_draw_usec = 0
	_post_draw_usec = 0
	_pre_draw_count = 0
	_post_draw_count = 0

## Called from the main-thread probe, using the actual RenderingServer thread
## identity instead of a project setting which a command-line flag can override.
static func configure_draw_delivery(synchronous: bool) -> void:
	_draw_delivery = "main_thread" if synchronous else "separate_thread"
	_clear_draw_callbacks()

static func draw_pre() -> void:
	_mark_draw(true, Time.get_ticks_usec())

static func draw_post() -> void:
	_mark_draw(false, Time.get_ticks_usec())

static func _mark_draw(is_pre: bool, at: int) -> void:
	if not enabled or _last_frame <= 0: return
	if is_pre:
		_pre_draw_count += 1
		if _pre_draw_count == 1: _pre_draw_usec = at
	else:
		_post_draw_count += 1
		if _post_draw_count == 1: _post_draw_usec = at

static func _draw_sample(at: int) -> Dictionary:
	var result: Dictionary = {
		"delivery":_draw_delivery, "probe_usec":_last_frame, "next_probe_usec":at,
		"pre_usec":_pre_draw_usec, "post_usec":_post_draw_usec,
		"pre_count":_pre_draw_count, "post_count":_post_draw_count,
	}
	if _pre_draw_count == 0 and _post_draw_count == 0:
		result["status"] = "no_draw_callbacks"
	elif _pre_draw_count > 1 or _post_draw_count > 1:
		result["status"] = "multiple_callbacks"
	elif _pre_draw_count != 1 or _post_draw_count != 1:
		result["status"] = "incomplete_callbacks"
	elif not (_last_frame <= _pre_draw_usec and _pre_draw_usec <= _post_draw_usec and _post_draw_usec <= at):
		result["status"] = "out_of_order"
	elif _draw_delivery != "main_thread":
		result["status"] = "threaded_delivery" if _draw_delivery == "separate_thread" else "unknown_delivery"
	else:
		result["status"] = "ordered_synchronous_pair"
		# Inclusive wall intervals; never add these to the section totals. CPU
		# _draw/deferred work may precede pre_draw. Swap/wait and other callback
		# listeners may lie between the two signals, so this is not GPU time.
		result["wall_usec"] = {
			"probe_to_pre":_pre_draw_usec - _last_frame,
			"pre_to_post":_post_draw_usec - _pre_draw_usec,
			"post_to_probe":at - _post_draw_usec,
		}
	return result

static func _record(total: int, map_id: String, at: int) -> void:
	_hitches += 1
	var parts: Array = []
	var known: int = 0
	for key: String in _sections:
		var value: int = int(_sections[key])
		known += value
		if value >= 1000: parts.append([key, value / 1000])
	parts.append(["other", maxi(0, total - known) / 1000])
	parts.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var entry: Dictionary = {"ms":total / 1000, "sections":parts.slice(0, 6), "map":map_id,
		"at_s":int(Time.get_ticks_msec() / 1000), "frame":_frames}
	var draw: Dictionary = _draw_sample(at)
	entry["diagnostics"] = {"logger_usec":_logger_usec, "draw_callbacks":draw,
		"process_tail":_process_tail_sample(at, draw), "lifecycle":_lifecycle_sample(),
		# Instantaneous record-time counters, not interval peaks or GC evidence.
		"record_snapshot":{"sampled_usec":Time.get_ticks_usec(), "static_memory_bytes":OS.get_static_memory_usage(),
			"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)), "nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}}
	if not _build.is_empty(): entry["build"] = _build.duplicate()
	var details: Array = []
	for operation: String in _details:
		var row: Array = _details[operation]
		if int(row[0]) >= 1000:
			details.append([operation, int(row[0]) / 1000, int(row[1]), int(row[2]) / 1000])
	details.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	if not details.is_empty(): entry["details"] = details
	if not _counters.is_empty(): entry["counters"] = _counters.duplicate()
	if not _slow_spawn.is_empty(): entry["slow_spawn"] = _slow_spawn.duplicate(true)
	print(PREFIX + JSON.stringify(entry))
	var index: int = _worst.size()
	while index > 0 and int(_worst[index - 1].ms) < int(entry.ms): index -= 1
	if index < KEEP:
		_worst.insert(index, entry)
		if _worst.size() > KEEP: _worst.resize(KEEP)
	_dirty = true

static func summary() -> Dictionary:
	return {"schema":1, "build":_build.duplicate(), "frames":_frames, "hitches":_hitches, "threshold_ms":THRESHOLD_USEC / 1000,
		"worst":_worst.duplicate(true)}

static func flush() -> void:
	var at: int = Time.get_ticks_usec()
	_flush_record(at)
	# frame() already measures its whole bookkeeping, including automatic
	# flush. A pause/focus flush outside that call is accounted for separately.
	if enabled and not _inside_probe and _last_frame > 0:
		_logger_usec += maxi(0, Time.get_ticks_usec() - at)

static func _flush_record(at: int) -> void:
	_last_flush = at
	_dirty = false
	var path: String = _dir.path_join(FILE_NAME)
	var temporary: String = path + ".part"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(summary()))
	file.close()
	DirAccess.rename_absolute(temporary, path)

## Once per process start: keep the previous run's record for the loading screen.
static func start() -> void:
	if _started: return
	_started = true
	# Mounted update-pack identity at probe startup, not the next launch's label.
	var info := FileAccess.open("res://build_info.json",FileAccess.READ)
	if info != null and info.get_length() <= 4096:
		var identity: Variant = JSON.parse_string(info.get_as_text())
		if identity is Dictionary:
			for key: String in ["version_name","commit"]:
				if identity.get(key) is String: _build[key] = str(identity[key]).left(80)
	var path: String = _dir.path_join(FILE_NAME)
	if not FileAccess.file_exists(path): return
	var previous: String = _dir.path_join(PREV_NAME)
	DirAccess.remove_absolute(previous)
	DirAccess.rename_absolute(path, previous)
	_previous = read_previous()

static func read_previous() -> Dictionary:
	var path: String = _dir.path_join(PREV_NAME)
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65536: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary and value.get("schema") == 1 else {}

## One line for the loading screen, or "" when the last run had no hitch.
static func previous_line() -> String:
	var value: Dictionary = _previous if not _previous.is_empty() else read_previous()
	var worst: Array = value.get("worst", []) if value.get("worst") is Array else []
	if worst.is_empty() or not worst[0] is Dictionary: return ""
	var top: Dictionary = worst[0]
	var names: PackedStringArray = PackedStringArray()
	for part: Variant in top.get("sections", []):
		if part is Array and part.size() == 2 and int(part[1]) > 0 and names.size() < 3:
			names.append("%s %dms" % [str(LABELS.get(str(part[0]), str(part[0]))), int(part[1])])
	var line: String = "지난 실행 끊김 %d회 · 최대 %dms (%s)" % [int(value.get("hitches", worst.size())), int(top.get("ms", 0)), ", ".join(names)]
	# The current loading header can be a newer APK than this saved hitch.
	var recorded_build: Variant = top.get("build", {})
	if not recorded_build is Dictionary or recorded_build.is_empty(): recorded_build = value.get("build", {})
	var build_label: String = "미상"
	if recorded_build is Dictionary:
		var version: String = str(recorded_build.get("version_name", "")).strip_edges().left(32)
		var commit: String = str(recorded_build.get("commit", "")).strip_edges().left(8)
		if not version.is_empty() or not commit.is_empty(): build_label = version + ("@" + commit if not commit.is_empty() else "")
	line += " · 기록빌드 " + build_label
	# The slowest frame's operation details ([name, total ms, count, max ms]),
	# so a photo of the loading screen names what inside a section stalled.
	var details: PackedStringArray = PackedStringArray()
	for part: Variant in top.get("details", []):
		# The single-setup phases below already show the parent. Use these
		# three slots for its inner operations when the new sample is present.
		if top.has("slow_spawn") and part is Array and not part.is_empty():
			var operation: String = str(part[0])
			if operation.begins_with("setup.") or operation in ["spawn.total","spawn.setup","view.roles"]: continue
		if part is Array and part.size() >= 3 and int(part[1]) > 0 and details.size() < 3:
			details.append("%s %dms×%d" % [str(part[0]), int(part[1]), int(part[2])])
	if not details.is_empty(): line += " · 세부 " + ", ".join(details)
	var spawn: Variant = top.get("slow_spawn",{})
	if spawn is Dictionary and spawn.get("phases_usec") is Dictionary:
		var phases: Array = []
		for key: String in spawn.phases_usec: phases.append([key,int(spawn.phases_usec[key])])
		phases.sort_custom(func(a: Array,b: Array) -> bool: return int(a[1]) > int(b[1]))
		var labels: PackedStringArray = []
		for part: Array in phases.slice(0,2): labels.append("%s %dms" % [part[0],int(part[1])/1000])
		line += " · 단일 NPC %d setup %s" % [int(spawn.get("npc",-1)),", ".join(labels)]
	var diagnostics: Variant = top.get("diagnostics", {})
	if not diagnostics is Dictionary: diagnostics = {}
	var callbacks: Variant = diagnostics.get("draw_callbacks", {})
	if callbacks is Dictionary and callbacks.get("status") == "ordered_synchronous_pair" and callbacks.get("wall_usec") is Dictionary:
		var wall: Dictionary = callbacks.wall_usec
		line += " · 콜백 구간 %d/%d/%dms(전/사이/후)" % [int(wall.get("probe_to_pre",0))/1000,int(wall.get("pre_to_post",0))/1000,int(wall.get("post_to_probe",0))/1000]
	elif callbacks is Dictionary and not callbacks.is_empty():
		var status: String = str({"no_draw_callbacks":"없음", "multiple_callbacks":"중복", "incomplete_callbacks":"누락", "out_of_order":"역순", "threaded_delivery":"별도스레드", "unknown_delivery":"스레드미상"}.get(callbacks.get("status", ""), "미확인"))
		var delivery: String = str({"main_thread":"동기", "separate_thread":"별도", "unknown":"미상"}.get(callbacks.get("delivery", ""), "미상"))
		line += " · 콜백 %s %d/%d(%s)" % [status, clampi(int(callbacks.get("pre_count",0)),0,9999), clampi(int(callbacks.get("post_count",0)),0,9999), delivery]
	else: line += " · 콜백 미기록"
	var tail: Variant = diagnostics.get("process_tail", {})
	if tail is Dictionary and tail.get("status") == "ordered_marker" and tail.get("wall_usec") is Dictionary:
		line += " · 후순위표식 %d/%dms(전/후)" % [int(tail.wall_usec.get("probe_to_tail",0))/1000,int(tail.wall_usec.get("tail_to_probe",0))/1000]
	elif tail is Dictionary and not tail.is_empty():
		var status: String = str({"missing":"없음", "multiple":"중복", "out_of_order":"역순"}.get(tail.get("status", ""), "미확인"))
		line += " · 후순위표식 %s(%d)" % [status, clampi(int(tail.get("count",0)),0,9999)]
	var lifecycle_sample: Variant = diagnostics.get("lifecycle", {})
	if lifecycle_sample is Dictionary and not lifecycle_sample.is_empty():
		var events: Variant = lifecycle_sample.get("counts_pause_resume_out_in", [])
		if (events is Array or events is PackedInt64Array) and events.size() == 4:
			if int(events[0]) > 0 or int(events[1]) > 0 or int(events[2]) > 0 or int(events[3]) > 0:
				line += " · 앱알림 %d/%d/%d/%d(정지/재개/이탈/복귀)" % [clampi(int(events[0]),0,9999),clampi(int(events[1]),0,9999),clampi(int(events[2]),0,9999),clampi(int(events[3]),0,9999)]
			else:
				var states: PackedStringArray = []
				if int(lifecycle_sample.get("paused_start",-1)) == 1 or int(lifecycle_sample.get("paused_end",-1)) == 1: states.append("정지")
				if int(lifecycle_sample.get("focused_start",-1)) == 0 or int(lifecycle_sample.get("focused_end",-1)) == 0: states.append("이탈")
				if not states.is_empty(): line += " · 앱상태 " + "/".join(states)
	return line

static func reset_for_test(directory: String) -> void:
	_dir = directory
	_sections.clear()
	_details.clear()
	_counters.clear()
	_slow_spawn = {}
	_build = {}
	_frames = 0
	_hitches = 0
	_worst.clear()
	_last_frame = 0
	_dirty = false
	_last_flush = 0
	_nested = 0
	_started = false
	_previous = {}
	enabled = true
	_draw_delivery = "unknown"
	_logger_usec = 0
	_inside_probe = false
	_application_paused = -1
	_application_focused = -1
	_clear_pending()

## Test hook: pretend the previous frame started `usec_ago` microseconds ago.
static func backdate_frame_for_test(usec_ago: int) -> void:
	_last_frame = Time.get_ticks_usec() - usec_ago

## Deterministic boundary/overhead fixtures, not benchmark timing. These use
## the production close path without introducing an injected clock hot path.
static func frame_at_for_test(at: int, map_id: String = "", logger_usec: int = 0) -> void:
	if not enabled: return
	_close_frame(at, map_id)
	_logger_usec += maxi(0, logger_usec)

static func draw_at_for_test(is_pre: bool, at: int) -> void:
	_mark_draw(is_pre, at)

static func process_tail_at_for_test(at: int) -> void:
	_mark_process_tail(at)

static func lifecycle_at_for_test(event: int, at: int) -> void:
	_mark_lifecycle(event, at)
