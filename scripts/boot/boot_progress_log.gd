extends RefCounted
## Small, kill-safe boot progress record (Android "정리 중" investigation).
##
## Each event is one short `key=value` line appended to user://boot_progress.log
## and flushed at once, so after the OS kills the process the last line still
## names the stage that was running (`cur=`) and the memory seen at that
## boundary. The same line is printed with PREFIX for logcat / headless logs.
##
## Files (all in user://, i.e. on Android the app's own data dir
## /data/data/<package>/files, or the editor's app_userdata dir):
##   boot_progress.log       this run
##   boot_progress.over.log  earlier part of this run once the cap was reached
##   boot_progress.prev.log  the previous run (moved aside when a run starts)
## Each file stays under CAP_BYTES. Nothing is buffered beyond one line.
##
## The recorder never stops boot: a file that cannot be opened or written only
## turns file output off (print output continues). It holds no game data.
## Static only; no autoload, no node, safe to call from any script.

const PREFIX := "BOOT_PROGRESS "
const FILE_NAME := "boot_progress.log"
const OVER_NAME := "boot_progress.over.log"
const PREV_NAME := "boot_progress.prev.log"
const CAP_BYTES: int = 262144
## Coarse row counter step for the big loops (progress() logs every ROW_STEP rows).
const ROW_STEP: int = 5000
## Cache/IO outcome vocabulary. Anything else is recorded as "other".
const REASONS: PackedStringArray = ["hit", "ok", "missing", "no_key", "key_changed", "schema_changed",
	"corrupt", "verify_fail", "write_fail", "open_fail", "rename_fail", "meta_fail", "other"]

static var _mutex: Mutex = Mutex.new()
static var _dir: String = "user://"
static var _cap: int = CAP_BYTES
static var _echo: bool = true
static var _started: bool = false
static var _file: FileAccess = null
static var _file_failed: bool = false
static var _written: int = 0
static var _seq: int = 0
static var _run: String = ""
static var _stack: PackedStringArray = PackedStringArray()
static var _previous_unfinished: String = ""
static var _proc_readable: bool = true

## Starts a stage; returns the start time for end().
static func begin(stage: String, fields: Dictionary = {}) -> int:
	_mutex.lock()
	_stack.append(_clean(stage))
	_mutex.unlock()
	_emit("begin", stage, fields, true)
	return Time.get_ticks_msec()

## Ends the innermost open stage named `stage` (ms = since begin()).
static func end(stage: String, started_msec: int, fields: Dictionary = {}) -> void:
	_mutex.lock()
	var name: String = _clean(stage)
	for position: int in range(_stack.size() - 1, -1, -1):
		if _stack[position] == name:
			_stack.remove_at(position)
			break
	_mutex.unlock()
	var with_time: Dictionary = fields.duplicate()
	with_time["ms"] = Time.get_ticks_msec() - started_msec
	_emit("end", stage, with_time, true)

## A bake lookup outcome: reason "hit" or a miss reason from REASONS.
static func cache(name: String, reason: String, fields: Dictionary = {}) -> void:
	var with_reason: Dictionary = fields.duplicate()
	var normalized: String = normalize_reason(reason)
	with_reason["result"] = "hit" if normalized == "hit" else "miss"
	with_reason["reason"] = normalized
	_emit("cache", name, with_reason, true)

## A bake write/commit/rename/verify outcome ("ok" or a failure reason).
static func io(name: String, op: String, reason: String, fields: Dictionary = {}) -> void:
	var with_reason: Dictionary = fields.duplicate()
	with_reason["op"] = op
	with_reason["reason"] = normalize_reason(reason)
	_emit("io", name, with_reason, true)

## Coarse row counter: records only every ROW_STEP rows (cheap to call per row).
static func progress(stage: String, rows: int, fields: Dictionary = {}) -> void:
	if rows <= 0 or rows % ROW_STEP != 0: return
	var with_rows: Dictionary = fields.duplicate()
	with_rows["rows"] = rows
	_emit("rows", stage, with_rows, true)

## Sequential steps of one long function: ends the previous step (if any)
## and begins `name`; step("") only ends the previous one.
static var _step_name: String = ""
static var _step_started: int = 0
static func step(name: String, fields: Dictionary = {}) -> void:
	if not _step_name.is_empty(): end(_step_name, _step_started)
	_step_name = name
	if not name.is_empty(): _step_started = begin(name, fields)

## A one-off event (e.g. "boot_done").
static func mark(event: String, fields: Dictionary = {}) -> void:
	_emit(event, "-", fields, true)

static func normalize_reason(reason: String) -> String:
	return reason if REASONS.has(reason) else "other"

## Innermost running stage ("" when none).
static func current_stage() -> String:
	_mutex.lock()
	var name: String = _stack[_stack.size() - 1] if not _stack.is_empty() else ""
	_mutex.unlock()
	return name

## The stage the previous run was inside when its record stopped ("" when it
## had none open, e.g. it finished booting or there is no previous record).
static func previous_unfinished() -> String:
	_mutex.lock()
	_start()
	var value: String = _previous_unfinished
	_mutex.unlock()
	return value

## Fields of the previous run's last complete record line ({} when none).
## Gameplay writes an "alive" line every few seconds and one per touch
## (frame_hitch_probe.gd), so after the app is closed by the system this is
## what it was doing and how much memory it held just before.
static func previous_last_fields() -> Dictionary:
	_mutex.lock()
	_start()
	_mutex.unlock()
	var file := FileAccess.open(_dir.path_join(PREV_NAME), FileAccess.READ)
	if file == null: return {}
	var length: int = file.get_length()
	var start: int = maxi(0, length - 4096)
	file.seek(start)
	var tail: String = file.get_buffer(length - start).get_string_from_utf8()
	file.close()
	var lines: PackedStringArray = tail.split("\n", false)
	for position: int in range(lines.size() - 1, -1, -1):
		var fields: Dictionary = parse_line(lines[position])
		if fields.has("ev") and fields.has("t"): return fields
	return {}

static func parse_line(line: String) -> Dictionary:
	var fields: Dictionary = {}
	for part: String in line.split(" ", false):
		var at: int = part.find("=")
		if at > 0: fields[part.left(at)] = part.substr(at + 1)
	return fields

## One loading-screen line for previous_last_fields(), or "".
static func previous_end_line() -> String:
	var fields: Dictionary = previous_last_fields()
	if fields.is_empty(): return ""
	var event: String = str(fields.get("ev", "-"))
	var what: String
	match event:
		"alive": what = "게임 중(%s)" % str(fields.get("map", "-"))
		"touch": what = "터치 %s" % str(fields.get("at", "-"))
		"begin": what = "시작 %s" % str(fields.get("stage", "-"))
		"end": what = "완료 %s" % str(fields.get("stage", "-"))
		_: what = event if str(fields.get("stage", "-")) == "-" else event + " " + str(fields.stage)
	var line: String = "지난 실행 마지막 기록 %d초: %s" % [int(fields.get("t", "0")) / 1000, what]
	var rss: int = int(fields.get("vmrss_kb", "-1"))
	if rss > 0: line += " · 앱 메모리 %dMB(최대 %dMB)" % [rss / 1024, int(fields.get("vmhwm_kb", "0")) / 1024]
	var available: int = int(fields.get("available_kb", "-1"))
	if available >= 0: line += " · 기기 여유 %dMB" % (available / 1024)
	return line

static func log_path() -> String: return _dir.path_join(FILE_NAME)
static func previous_path() -> String: return _dir.path_join(PREV_NAME)

## Tests only: point the recorder at another directory/cap and start a new run.
static func reset_for_test(directory: String, cap: int = CAP_BYTES, echo: bool = false) -> void:
	_mutex.lock()
	if _file != null: _file.close()
	_file = null
	_dir = directory
	_cap = maxi(cap, 1024)
	_echo = echo
	_started = false
	_file_failed = false
	_written = 0
	_seq = 0
	_stack = PackedStringArray()
	_step_name = ""
	_previous_unfinished = ""
	_mutex.unlock()

# --- internals ---------------------------------------------------------------

static func _emit(event: String, stage: String, fields: Dictionary, memory: bool) -> void:
	_mutex.lock()
	_start()
	_seq += 1
	var parts: PackedStringArray = ["run=" + _run, "seq=" + str(_seq), "t=" + str(Time.get_ticks_msec()),
		"ev=" + _clean(event), "stage=" + _clean(stage)]
	for key: Variant in fields: parts.append(_clean(str(key)) + "=" + _clean(str(fields[key])))
	parts.append("cur=" + (_stack[_stack.size() - 1] if not _stack.is_empty() else "-"))
	if memory: parts.append(_memory())
	var line: String = " ".join(parts)
	_store(line)
	_mutex.unlock()
	if _echo: print(PREFIX + line)

## Values never carry spaces, '=' or ':' (keeps lines parseable and keeps the
## CI log scanner's error patterns out of them).
static func _clean(value: String) -> String:
	if value.is_empty(): return "-"
	var result: String = value.replace(" ", "_").replace("\t", "_").replace("\n", "_").replace("\r", "_").replace("=", "-").replace(":", ".")
	return result.substr(0, 120)

static func _start() -> void:
	if _started: return
	_started = true
	_run = "%d-%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
	var current: String = _dir.path_join(FILE_NAME)
	if FileAccess.file_exists(current):
		_previous_unfinished = _last_open_stage(current)
		var previous: String = _dir.path_join(PREV_NAME)
		if FileAccess.file_exists(previous): DirAccess.remove_absolute(previous)
		DirAccess.rename_absolute(current, previous)
	var over: String = _dir.path_join(OVER_NAME)
	if FileAccess.file_exists(over): DirAccess.remove_absolute(over)
	_open_new()

static func _open_new() -> void:
	_written = 0
	_file = FileAccess.open(_dir.path_join(FILE_NAME), FileAccess.WRITE)
	if _file == null: _file_failed = true

static func _store(line: String) -> void:
	if _file_failed or _file == null: return
	var size: int = line.to_utf8_buffer().size() + 1
	if _written + size > _cap:
		# Keep the earlier part of this run once, then continue in a fresh file.
		_file.close()
		_file = null
		var current: String = _dir.path_join(FILE_NAME)
		var over: String = _dir.path_join(OVER_NAME)
		if FileAccess.file_exists(over): DirAccess.remove_absolute(over)
		DirAccess.rename_absolute(current, over)
		_open_new()
		if _file == null: return
	_file.store_line(line)
	_file.flush()
	if _file.get_error() != OK:
		_file.close()
		_file = null
		_file_failed = true
		return
	_written += size

## `cur=` of the last complete line of a previous record ("" when none open).
static func _last_open_stage(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var length: int = file.get_length()
	var start: int = maxi(0, length - 4096)
	file.seek(start)
	var tail: String = file.get_buffer(length - start).get_string_from_utf8()
	file.close()
	var lines: PackedStringArray = tail.split("\n", false)
	for position: int in range(lines.size() - 1, -1, -1):
		var marker: int = lines[position].find(" cur=")
		if marker < 0: continue
		var value: String = lines[position].substr(marker + 5).get_slice(" ", 0)
		return "" if value == "-" else value
	return ""

static func _memory() -> String:
	var parts: PackedStringArray = []
	parts.append("static_kb=" + str(int(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1024))
	parts.append("static_max_kb=" + str(int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) / 1024))
	var info: Dictionary = OS.get_memory_info()
	for key: String in ["physical", "free", "available", "stack"]:
		var value: int = int(info.get(key, -1))
		parts.append(key + "_kb=" + (str(value / 1024) if value >= 0 else "-1"))
	parts.append("objects=" + str(int(Performance.get_monitor(Performance.OBJECT_COUNT))))
	# Renderer counters only on the main thread of a real (non-headless) display.
	if OS.get_thread_caller_id() == OS.get_main_thread_id() and DisplayServer.get_name() != "headless":
		parts.append("tex_kb=" + str(int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1024))
		parts.append("buf_kb=" + str(int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)) / 1024))
		parts.append("vid_kb=" + str(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1024))
	if _proc_readable and OS.get_name() in ["Linux", "Android"]:
		var status := FileAccess.open("/proc/self/status", FileAccess.READ)
		if status == null:
			_proc_readable = false
		else:
			var lines: int = 0
			while not status.eof_reached() and lines < 80:
				lines += 1
				var row: String = status.get_line()
				for field: String in ["VmRSS:", "VmHWM:", "RssAnon:"]:
					if row.begins_with(field):
						parts.append(field.trim_suffix(":").to_lower() + "_kb=" + row.trim_prefix(field).strip_edges().get_slice(" ", 0))
			status.close()
	return " ".join(parts)
