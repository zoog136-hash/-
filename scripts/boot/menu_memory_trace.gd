extends RefCounted
## Main-thread, event-only diagnostics. No frame callback, resource/quest/save
## contents or crash/OOM inference. An unmatched begin is only the last event
## that reached storage; Android termination reasons need platform logs.
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
const FORMAT := "twilight.menu-memory.v1"
const FILE_NAME := "menu_memory_trace.json"
const PREV_NAME := "menu_memory_trace.prev.json"
const PREFIX := "MENU_MEMORY "
const MAX_EVENTS: int = 24
const MAX_BYTES: int = 32768
const MAX_PENDING: int = 8
const MENUS: Array[String] = ["quests", "change", "inventory", "shop", "character"]
const LIFECYCLE: Array[String] = ["focus_in", "focus_out", "paused", "resumed", "close_request"]
const MEMORY_FIELDS: Array[String] = ["static_kb", "static_max_kb", "objects", "physical_kb", "free_kb", "available_kb", "stack_kb", "tex_kb", "buf_kb", "vid_kb", "vmrss_kb", "vmhwm_kb", "rssanon_kb"]

static var _dir: String = "user://"
static var _started: bool = false
static var _run: String = ""
static var _events: Array[Dictionary] = []
static var _counts: Dictionary = {}
static var _pending: Dictionary = {}
static var _next_token: int = 0
static var _seq: int = 0
static var _dropped_spans: int = 0
static var _write_failed: bool = false
static var _write_failures: int = 0
static var _echo: bool = true
static var _memory_reader: Callable = Callable() # Deterministic test injection only.

static func start() -> void:
	if _started or OS.get_thread_caller_id() != OS.get_main_thread_id(): return
	_started = true
	_run = "%d-%d-%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec()]
	var current: String = _dir.path_join(FILE_NAME)
	# Do not read an oversized or partial previous file to decide why it ended.
	# Keep at most one bounded previous snapshot. Rotation is best effort.
	if FileAccess.file_exists(current) and FileAccess.get_size(current) <= MAX_BYTES:
		var previous: String = _dir.path_join(PREV_NAME)
		if FileAccess.file_exists(previous): DirAccess.remove_absolute(previous)
		DirAccess.rename_absolute(current, previous)
	_append({"event":"session_start"})

## Returns a small opaque token. The timer excludes this begin record's IO.
static func begin(menu: String) -> int:
	if menu not in MENUS or OS.get_thread_caller_id() != OS.get_main_thread_id(): return 0
	start()
	_next_token += 1
	var token: int = _next_token
	_counts[menu] = int(_counts.get(menu, 0)) + 1
	if _pending.size() >= MAX_PENDING:
		_pending.erase(_pending.keys()[0])
		_dropped_spans += 1
	_pending[token] = {"menu":menu, "started_usec":0}
	_append({"event":"menu_begin", "menu":menu, "token":token, "call":int(_counts[menu])})
	_pending[token].started_usec = Time.get_ticks_usec()
	return token

## `ok` describes the synchronous handler result, never process health.
## No result Dictionary, Texture, quest id or gameplay state is accepted.
static func end(token: int, ok: bool = true) -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or not _pending.has(token): return
	var elapsed: int = maxi(0, Time.get_ticks_usec() - int(_pending[token].started_usec))
	var menu: String = str(_pending[token].menu)
	_pending.erase(token)
	_append({"event":"menu_end", "menu":menu, "token":token, "ok":ok, "elapsed_usec":elapsed})

## Notifications are observations. Focus loss, pause and close requests are
## not labelled as crashes; a missing notification proves no termination cause.
static func lifecycle(event: String) -> void:
	if event not in LIFECYCLE or OS.get_thread_caller_id() != OS.get_main_thread_id(): return
	start()
	_append({"event":"lifecycle", "state":event})

static func _memory() -> Dictionary:
	var values: Dictionary = {}
	for key: String in MEMORY_FIELDS: values[key] = -1
	# Reuse the existing bounded collector. GPU counters are intentionally absent
	# headless/off-main; /proc and OS memory keys may be unavailable on a device.
	var raw: String = str(_memory_reader.call()) if _memory_reader.is_valid() else BOOT_LOG._memory()
	for part: String in raw.split(" ", false):
		var key: String = part.get_slice("=", 0)
		var value: String = part.get_slice("=", 1)
		if values.has(key) and value.is_valid_int(): values[key] = maxi(-1, int(value))
	return values

static func _append(event: Dictionary) -> void:
	_seq += 1
	event["seq"] = _seq
	event["at_usec"] = Time.get_ticks_usec()
	event["memory"] = _memory()
	var unavailable: Array[String] = []
	for key: String in MEMORY_FIELDS:
		if int(event.memory[key]) < 0: unavailable.append(key)
	event["unavailable"] = unavailable
	_events.append(event)
	while _events.size() > MAX_EVENTS: _events.pop_front()
	_persist()
	if _echo: print(PREFIX + JSON.stringify({"run":_run, "entry":event}))

## Snapshot is copied and contains only bounded diagnostic scalars/arrays.
static func snapshot() -> Dictionary:
	return {"format":FORMAT, "run":_run, "project_version":str(ProjectSettings.get_setting("application/config/version", "")),
		"engine":Engine.get_version_info().string, "os":OS.get_name(), "events":_events.duplicate(true),
		"menu_calls":_counts.duplicate(), "pending_count":_pending.size(), "dropped_spans":_dropped_spans,
		"storage_failed":_write_failed, "write_failures":_write_failures}

static func _persist() -> void:
	if _write_failed: return
	var raw: PackedByteArray = JSON.stringify(snapshot()).to_utf8_buffer()
	while raw.size() > MAX_BYTES and _events.size() > 1:
		_events.pop_front()
		raw = JSON.stringify(snapshot()).to_utf8_buffer()
	if raw.size() > MAX_BYTES:
		_write_failed = true
		_write_failures += 1
		return
	var path: String = _dir.path_join(FILE_NAME)
	var temporary: String = path + ".part"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_write_failed = true
		_write_failures += 1
		return
	var stored: bool = file.store_buffer(raw) and file.get_error() == OK
	file.close()
	if not stored or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		_write_failed = true
		_write_failures += 1

static func read_previous() -> Dictionary:
	var path: String = _dir.path_join(PREV_NAME)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	if file.get_length() <= 0 or file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK: return {}
	var value: Variant = parser.data
	if not value is Dictionary or value.get("format") != FORMAT or not value.get("events") is Array or value.events.size() > MAX_EVENTS: return {}
	return value

static func reset_for_test(directory: String, memory_reader: Callable = Callable(), echo: bool = false) -> void:
	_dir = directory
	_started = false
	_run = ""
	_events.clear()
	_counts.clear()
	_pending.clear()
	_next_token = 0
	_seq = 0
	_dropped_spans = 0
	_write_failed = false
	_write_failures = 0
	_echo = echo
	_memory_reader = memory_reader
