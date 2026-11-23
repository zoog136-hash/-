extends Node
## One Android report per game run, independent of loading/world scene changes.
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const DOWNLOADS = preload("res://scripts/boot/performance_report_downloads.gd")
const NODE_NAME := "TwilightPerformanceReport"
const DIRECTORY := "user://performance_reports"
const PREFIX := "TWILIGHT-performance-"
const CHECKPOINT_SECONDS: float = 15.0
const PAUSE_MIN_MSEC: int = 2000
const MAX_PRIVATE_REPORTS: int = 4
const MAX_REPORT_BYTES: int = 65536
const MEMORY := ["vmrss_kb", "vmhwm_kb", "static_kb", "static_max_kb", "available_kb", "memavailable_kb", "tex_kb"]
const METRICS := ["fps", "frame_ms", "max_fps", "nodes", "resources", "objects", "tables", "actors",
	"sp2_parsed_mb", "sp2_parsed_n", "sp2_texture_mb", "sp2_texture_n", "cook_mb", "uipage_mb"]

static var _latest_metrics: Dictionary = {}
var _directory: String = DIRECTORY
var _session: String
var _started_unix: int
var _last_checkpoint_msec: int = -PAUSE_MIN_MSEC
var _worker: Thread
var _finished: bool = false

static func ensure(tree: SceneTree) -> void:
	if not OS.has_feature("android") or tree == null: return
	_attach.call_deferred(tree.root)

static func _attach(root: Window) -> void:
	if not is_instance_valid(root) or root.has_node(NodePath(NODE_NAME)): return
	var session: Node = load("res://scripts/boot/performance_report_session.gd").new()
	session.name = NODE_NAME
	root.add_child(session)

static func sample(fields: Dictionary, memory: String) -> void:
	if not OS.has_feature("android"): return
	var result: Dictionary = {"at_usec":HITCH.now()}
	for key: String in METRICS:
		var value: Variant = fields.get(key)
		if value is int or value is float: result[key] = value
	for item: String in memory.split(" ", false):
		var pair: PackedStringArray = item.split("=", false, 1)
		if pair.size() == 2 and pair[0] in MEMORY and pair[1].is_valid_int():
			result[pair[0]] = int(pair[1])
	_latest_metrics = result

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_unix = int(Time.get_unix_time_from_system())
	var stamp: String = Time.get_datetime_string_from_unix_time(_started_unix).replace(":", "")
	_session = stamp + "Z-" + Crypto.new().generate_random_bytes(12).hex_encode()
	# Loading can begin before the first world probe. Start also restores the
	# legacy previous hitch record exactly once per process.
	HITCH.start()
	get_tree().root.close_requested.connect(_on_close_request)
	get_tree().root.go_back_requested.connect(_on_back_request)
	_checkpoint(true)
	var timer := Timer.new()
	timer.wait_time = CHECKPOINT_SECONDS
	timer.timeout.connect(_checkpoint)
	add_child(timer)
	timer.start()

func _notification(what: int) -> void:
	if _session.is_empty() or _finished: return
	if what == NOTIFICATION_APPLICATION_PAUSED and Time.get_ticks_msec() - _last_checkpoint_msec >= PAUSE_MIN_MSEC:
		_checkpoint()

func _on_close_request() -> void:
	if get_tree().auto_accept_quit: _finish()

func _on_back_request() -> void:
	if get_tree().quit_on_go_back: _finish()

func _exit_tree() -> void:
	var window: Window = get_tree().root
	if window.close_requested.is_connected(_on_close_request): window.close_requested.disconnect(_on_close_request)
	if window.go_back_requested.is_connected(_on_back_request): window.go_back_requested.disconnect(_on_back_request)
	_finish()

func _snapshot(state: String) -> Dictionary:
	return {"schema":1, "session":_session, "started_unix_utc":_started_unix,
		"captured_unix_utc":int(Time.get_unix_time_from_system()), "capture":state,
		"hitch_log":HITCH.summary(), "last_sample":_latest_metrics.duplicate()}

func _checkpoint(recover: bool = false) -> void:
	if _finished: return
	if _worker != null:
		if _worker.is_alive(): return
		_worker.wait_to_finish()
	_worker = Thread.new()
	var snapshot: Dictionary = _snapshot("checkpoint")
	if _worker.start(_checkpoint_job.bind(_directory, snapshot, recover), Thread.PRIORITY_LOW) == OK:
		_last_checkpoint_msec = Time.get_ticks_msec()
	else:
		_worker = null

func _finish() -> void:
	if _finished or _session.is_empty(): return
	_finished = true
	if _worker != null:
		_worker.wait_to_finish()
		_worker = null
	var report: Dictionary = clean_snapshot(_snapshot("regular_exit"))
	var exported: bool = false
	if write_private(_directory, report):
		exported = _publish_checkpoint(_directory, report)
	print("TWILIGHT_PERFORMANCE_REPORT ", "downloads" if exported else "export_failed", " session=", _session)

static func _checkpoint_job(directory: String, snapshot: Dictionary, recover: bool) -> void:
	write_private(directory, clean_snapshot(snapshot))
	if recover:
		# Recovery never publishes this run's live checkpoint.
		recover_reports(directory, str(snapshot.session), _publish_checkpoint)

static func valid_session(value: String) -> bool:
	if value.length() != 43: return false
	if value[4] != "-" or value[7] != "-" or value[10] != "T" or value[17] != "Z" or value[18] != "-": return false
	for i: int in range(value.length()):
		if i in [4, 7, 10, 17, 18]: continue
		var ch: String = value[i]
		if not ch in ("0123456789" if i < 19 else "0123456789abcdef"): return false
	return true

static func _file_name(session: String) -> String:
	return PREFIX + session + ".json"

static func write_private(directory: String, report: Dictionary) -> bool:
	var session: String = str(report.get("session", ""))
	if not valid_session(session): return false
	var bytes: PackedByteArray = JSON.stringify(report).to_utf8_buffer()
	if bytes.size() > MAX_REPORT_BYTES: return false
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	var path: String = directory.path_join(_file_name(session))
	var file := FileAccess.open(path + ".part", FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	var ok: bool = file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path + ".part", path) == OK

static func recover_reports(directory: String, active: String, publisher: Callable) -> void:
	var names: PackedStringArray = DirAccess.get_files_at(directory)
	names.sort()
	names.reverse()
	var retained: int = 0
	for name_value: String in names:
		var is_partial: bool = name_value.ends_with(".part")
		var name_without_partial: String = name_value.trim_suffix(".part")
		if not name_without_partial.begins_with(PREFIX) or not name_without_partial.ends_with(".json"): continue
		var session: String = name_without_partial.trim_prefix(PREFIX).trim_suffix(".json")
		if not valid_session(session) or session == active: continue
		var path: String = directory.path_join(name_value)
		if is_partial:
			DirAccess.remove_absolute(path)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > MAX_REPORT_BYTES:
			DirAccess.remove_absolute(path)
			continue
		var saved: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not saved is Dictionary or saved.get("schema") != 1 or saved.get("session") != session:
			DirAccess.remove_absolute(path)
			continue
		var report: Dictionary = clean_snapshot(saved)
		if report.capture == "checkpoint": report.capture = "recovered_checkpoint"
		if retained >= MAX_PRIVATE_REPORTS - 1:
			DirAccess.remove_absolute(path)
		elif not bool(publisher.call(directory, report)):
			retained += 1

static func _publish_checkpoint(directory: String, report: Dictionary) -> bool:
	var filename: String = _file_name(report.session)
	if not DOWNLOADS.publish(filename, JSON.stringify(report, "\t")): return false
	DirAccess.remove_absolute(directory.path_join(filename))
	return true

## The public file only contains allowlisted performance fields. Reapply this
## projection to recovered files before using a shared-storage destination.
static func clean_snapshot(snapshot: Dictionary) -> Dictionary:
	var raw_log: Variant = snapshot.get("hitch_log", {})
	var raw_sample: Variant = snapshot.get("last_sample", {})
	var capture: String = str(snapshot.get("capture", "checkpoint"))
	var result: Dictionary = {"schema":1, "session":str(snapshot.get("session", "")),
		"started_unix_utc":_number(snapshot.get("started_unix_utc")),
		"captured_unix_utc":_number(snapshot.get("captured_unix_utc")),
		"capture":capture if capture in ["regular_exit", "recovered_checkpoint"] else "checkpoint",
		"hitch_log":{}, "last_sample":{}}
	if raw_sample is Dictionary:
		for key: String in METRICS + MEMORY + ["at_usec"]:
			if raw_sample.has(key): result.last_sample[key] = _number(raw_sample[key])
	if not raw_log is Dictionary: return result
	var log: Dictionary = _numbers(raw_log, ["schema", "frames", "hitches", "threshold_ms", "over_16ms", "over_16667us", "over_33ms", "at_least_4s"])
	log["build"] = _build(raw_log.get("build"))
	var worst: Array = []
	var entries: Variant = raw_log.get("worst", [])
	if entries is Array:
		for entry: Variant in entries.slice(0, HITCH.KEEP):
			if entry is Dictionary: worst.append(_hitch(entry))
	log["worst"] = worst
	result.hitch_log = log
	return result

static func _hitch(entry: Dictionary) -> Dictionary:
	var result: Dictionary = _numbers(entry, ["ms", "at_s", "frame"])
	result["map"] = _label(entry.get("map"))
	result["sections"] = _rows(entry.get("sections"), 6, 2)
	result["details"] = _rows(entry.get("details"), 12, 4)
	result["build"] = _build(entry.get("build"))
	var diagnostics: Variant = entry.get("diagnostics")
	if diagnostics is Dictionary:
		var diag: Dictionary = _numbers(diagnostics, ["logger_usec"])
		for row: Array in [
			["record_snapshot", ["sampled_usec", "static_memory_bytes", "objects", "nodes"]],
			["draw_callbacks", ["probe_usec", "next_probe_usec", "pre_usec", "post_usec", "pre_count", "post_count"]],
			["process_tail", ["usec", "count", "tail_to_pre_usec"]],
			["next_scene_dispatch", ["dispatch_usec", "process_usec", "post_to_dispatch_usec", "dispatch_to_probe_usec", "process_to_probe_usec"]],
			["physics", ["steps", "usec", "max_step_usec", "sections_usec"]],
			["lifecycle", ["first_usec", "last_usec", "paused_start", "paused_end", "focused_start", "focused_end"]],
		]:
			var source: Variant = diagnostics.get(row[0])
			if not source is Dictionary: continue
			var part: Dictionary = _numbers(source, row[1])
			for key: String in ["status", "delivery", "signal"]:
				if source.has(key): part[key] = _label(source[key])
			var wall: Variant = source.get("wall_usec")
			if wall is Dictionary:
				part["wall_usec"] = _numbers(wall, ["probe_to_pre", "pre_to_post", "post_to_probe", "probe_to_tail", "tail_to_probe"])
			var events: Variant = source.get("counts_pause_resume_out_in")
			if (events is Array or events is PackedInt64Array) and events.size() == 4:
				part["counts_pause_resume_out_in"] = [_number(events[0]), _number(events[1]), _number(events[2]), _number(events[3])]
			diag[row[0]] = part
		diag["detail_spans"] = _rows(diagnostics.get("detail_spans"), 6, 3)
		result["diagnostics"] = diag
	var spawn: Variant = entry.get("slow_spawn")
	if spawn is Dictionary:
		var detail: Dictionary = _numbers(spawn, ["usec", "npc", "sprite", "start_offset_usec"])
		detail["accepted"] = spawn.get("accepted") == true
		var phases: Variant = spawn.get("phases_usec")
		if phases is Dictionary:
			var clean: Dictionary = {}
			for key: Variant in phases.keys().slice(0, 12):
				var label: String = _label(key)
				if not label.is_empty(): clean[label] = _number(phases[key])
			detail["phases_usec"] = clean
		result["slow_spawn"] = detail
	return result

static func _rows(value: Variant, limit: int, width: int) -> Array:
	var result: Array = []
	if not value is Array: return result
	for row: Variant in value.slice(0, limit):
		if not row is Array or row.size() < width: continue
		var label: String = _label(row[0])
		if label.is_empty(): continue
		var clean: Array = [label]
		for i: int in range(1, width): clean.append(_number(row[i]))
		result.append(clean)
	return result

static func _build(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	return {"version_name":_label(value.get("version_name")), "commit":_label(value.get("commit"))}

static func _label(value: Variant) -> String:
	if not value is String or value.length() > 48: return ""
	for i: int in range(value.length()):
		if not value[i] in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-": return ""
	return value

static func _numbers(source: Dictionary, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key: String in keys:
		if source.has(key): result[key] = _number(source[key])
	return result

static func _number(value: Variant) -> Variant:
	if value is int or (value is float and is_finite(value)): return value
	return 0
