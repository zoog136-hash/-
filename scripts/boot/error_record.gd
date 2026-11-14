extends Logger
## Records engine and script errors to user://error_record.log so the next
## loading screen can name the last error before the app was closed (the
## phone cannot be attached to a debugger here). Each distinct error
## (file:line + message) is written once with its first time; repeats are
## only counted. The previous run's file is kept as error_record.prev.log.
const FILE_NAME := "error_record.log"
const PREV_NAME := "error_record.prev.log"
const MAX_DISTINCT: int = 64
const MAX_TEXT: int = 240

static var _instance: Logger
static var _dir: String = "user://"
static var _mutex := Mutex.new()
static var _file: FileAccess
static var _seen: Dictionary = {}
static var _total: int = 0
static var _busy: bool = false

## Once per process: rotate the previous record and start capturing.
static func install(directory: String = "user://") -> void:
	if _instance != null: return
	_dir = directory
	var current: String = _dir.path_join(FILE_NAME)
	if FileAccess.file_exists(current):
		var previous: String = _dir.path_join(PREV_NAME)
		if FileAccess.file_exists(previous): DirAccess.remove_absolute(previous)
		DirAccess.rename_absolute(current, previous)
	_seen = {}
	_total = 0
	_file = FileAccess.open(current, FileAccess.WRITE)
	_instance = (load("res://scripts/boot/error_record.gd") as GDScript).new()
	OS.add_logger(_instance)

## Test hook: stop capturing and forget state.
static func uninstall_for_test() -> void:
	if _instance != null: OS.remove_logger(_instance)
	_instance = null
	if _file != null: _file.close()
	_file = null
	_seen = {}
	_total = 0

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var message: String = rationale if not rationale.is_empty() else code
	var where: String = "%s:%d" % [file.get_file(), line]
	var trace: String = ""
	if not script_backtraces.is_empty() and script_backtraces[0] != null:
		var frames: PackedStringArray = []
		var backtrace: ScriptBacktrace = script_backtraces[0]
		for index: int in mini(backtrace.get_frame_count(), 4):
			frames.append("%s:%d" % [backtrace.get_frame_file(index).get_file(), backtrace.get_frame_line(index)])
		trace = " < ".join(frames)
	_record(error_type, where, function, message, trace)

func _log_message(_message: String, _error: bool) -> void:
	pass

static func _record(error_type: int, where: String, function: String, message: String, trace: String) -> void:
	_mutex.lock()
	if _busy:
		_mutex.unlock()
		return
	_busy = true
	_total += 1
	var key: String = where + "|" + message
	if _seen.has(key):
		_seen[key] = int(_seen[key]) + 1
	elif _seen.size() < MAX_DISTINCT and _file != null:
		_seen[key] = 1
		var text: String = ("t=%d type=%d at=%s fn=%s msg=%s trace=%s" % [Time.get_ticks_msec(), error_type, where, function, message, trace]).replace("\n", " ").substr(0, MAX_TEXT * 2)
		_file.store_line(text)
		_file.flush()
	_busy = false
	_mutex.unlock()

## Last distinct error of the previous run as {at, fn, msg, trace, distinct}, or {}.
static func previous_last(directory: String = "") -> Dictionary:
	var path: String = (directory if not directory.is_empty() else _dir).path_join(PREV_NAME)
	if not FileAccess.file_exists(path): return {}
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n", false)
	if lines.is_empty(): return {}
	var last: String = lines[lines.size() - 1]
	var result: Dictionary = {"distinct": lines.size()}
	# Fields are written in this fixed order (see _record).
	var names: PackedStringArray = ["at", "fn", "msg", "trace"]
	for index: int in names.size():
		var start: int = last.find(" " + names[index] + "=")
		if start < 0: continue
		start += names[index].length() + 2
		var end: int = last.length()
		if index + 1 < names.size():
			var next: int = last.find(" " + names[index + 1] + "=", start)
			if next >= 0: end = next
		result[names[index]] = last.substr(start, end - start)
	return result

## One loading-screen line, or "".
static func previous_line(directory: String = "") -> String:
	var last: Dictionary = previous_last(directory)
	if last.is_empty(): return ""
	var line: String = "지난 실행 마지막 오류(%s종): %s %s" % [last.get("distinct", 1), last.get("at", "-"), str(last.get("msg", "")).substr(0, MAX_TEXT)]
	if not str(last.get("trace", "")).is_empty(): line += " ← " + str(last.trace)
	return line
