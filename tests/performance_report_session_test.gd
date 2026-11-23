extends SceneTree
const REPORT = preload("res://scripts/boot/performance_report_session.gd")
const DOWNLOADS = preload("res://scripts/boot/performance_report_downloads.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const DIR := "user://performance_report_session_test"
const ACTIVE := "2026-11-23T044501Z-012345678901234567890123"
const PREV := "2026-11-22T181532Z-abcdefabcdefabcdefabcdef"

var checks: int = 0
var failures: Array[String] = []

class FakeValues extends RefCounted:
	var fields: Dictionary = {}
	func put(key: String, value: String) -> void: fields[key] = value
	func ContentValues() -> FakeValues: return FakeValues.new()

class FakeStream extends RefCounted:
	var failed: bool = false
	var output: String
	var closed: bool = false
	func print(payload: String) -> void: output = payload
	func close() -> void: closed = true
	func checkError() -> bool: return failed
	func PrintStream(stream: FakeStream, _auto_flush: bool, _charset: String) -> FakeStream: return stream

class FakeResolver extends RefCounted:
	var stream := FakeStream.new()
	var operations: Array[String] = []
	var published: bool = false
	var wants_pending: bool = false
	var write_before_publish: bool = false
	var has_existing: bool = false
	var update_result: int = 1
	func query(_collection: String, _cols: PackedStringArray, _where: String, _args: PackedStringArray, _order: String) -> Variant:
		return self if has_existing else null
	func moveToFirst() -> bool: return true
	func close() -> void: operations.append("cursor_closed")
	func insert(_collection: String, values: FakeValues) -> String:
		wants_pending = values.fields.get("is_pending") == "1" and values.fields.get("relative_path") == "Download/TWILIGHT" and values.fields.get("mime_type") == "application/json"
		operations.append("insert")
		return "app_report"
	func openOutputStream(_uri: String, _mode: String) -> FakeStream:
		operations.append("open")
		return stream
	func update(_uri: String, visible: FakeValues, _selection: String, _args: PackedStringArray) -> int:
		operations.append("update")
		write_before_publish = stream.closed and not stream.output.is_empty()
		published = visible.fields.get("is_pending") == "0" and update_result == 1
		return update_result
	func delete(_uri: String, _selection: String, _args: PackedStringArray) -> int:
		operations.append("delete")
		return 1

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("PERFORMANCE_REPORT_FAIL ", label)

func _clear_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))

func _publish_policy() -> void:
	var resolver := FakeResolver.new()
	var ok: bool = DOWNLOADS._write_download(resolver, "downloads", FakeValues.new(), FakeStream.new(), "run.json", '{"example":1}')
	check(ok and resolver.published and resolver.write_before_publish and resolver.wants_pending
		and resolver.operations == ["insert", "open", "update"], "pending row becomes visible only after complete stream close")
	resolver = FakeResolver.new()
	resolver.stream.failed = true
	ok = DOWNLOADS._write_download(resolver, "downloads", FakeValues.new(), FakeStream.new(), "run.json", "{}")
	check(not ok and resolver.operations == ["insert", "open", "delete"], "stream I/O failure removes pending row without publishing")
	resolver = FakeResolver.new()
	resolver.update_result = 0
	ok = DOWNLOADS._write_download(resolver, "downloads", FakeValues.new(), FakeStream.new(), "run.json", "{}")
	check(not ok and resolver.operations == ["insert", "open", "update", "delete"], "zero changed rows counts as a failed export")
	resolver = FakeResolver.new()
	resolver.has_existing = true
	ok = DOWNLOADS._write_download(resolver, "downloads", FakeValues.new(), FakeStream.new(), "run.json", "{}")
	check(ok and resolver.operations == ["cursor_closed"], "retry of already committed session produces no duplicate row")
	check(not DOWNLOADS.publish("test.json", "{}"), "non-Android process never tries to use the public writer")

func _spool_and_privacy() -> void:
	check(REPORT.valid_session(ACTIVE) and not REPORT.valid_session(ACTIVE + "f")
		and not REPORT.valid_session("../" + ACTIVE), "session naming bounds and disallows traversals")
	var raw: Dictionary = {
		"session":PREV, "capture":"checkpoint", "account":"secret_user", "token":"secret_token",
		"last_sample":{"fps":30, "vmrss_kb":789, "path":"/data/user/0/private", "tables":25},
		"hitch_log":{"frames":32,"build":{"version_name":"523.813","commit":"56f5843f","token":"secret_build"},
			"worst":[{"ms":11076,"map":"aden_world","private":"/sdcard/secret",
				"sections":[["other",11057],["/data/private",12]],
				"details":[["save.write",193,3,76]], "diagnostics":{
				"logger_usec":27,"private":"/tmp/path","detail_spans":[["save.write",40,900]],
				"next_scene_dispatch":{"signal":"physics","status":"ordered_signal","post_to_dispatch_usec":11063000}}}]}}
	var cleaned: Dictionary = REPORT.clean_snapshot(raw)
	var public_data: String = JSON.stringify(cleaned)
	check(not public_data.contains("secret") and not public_data.contains("/data")
		and cleaned.last_sample == {"fps":30, "vmrss_kb":789, "tables":25}, "public projection excludes account, credentials, and private paths")
	check(cleaned.hitch_log.worst[0].diagnostics.detail_spans[0][0] == "save.write"
		and cleaned.hitch_log.worst[0].diagnostics.next_scene_dispatch.post_to_dispatch_usec == 11063000,
		"public report retains detailed hitch and boundary data")
	check(REPORT.write_private(DIR, cleaned), "valid snapshot writes a private checkpoint")
	var active: Dictionary = cleaned.duplicate(true)
	active.session = ACTIVE
	check(REPORT.write_private(DIR, active), "same-second sessions have separate private files")
	var captured: Array[Dictionary] = []
	REPORT.recover_reports(DIR, ACTIVE, func(_directory: String, report: Dictionary) -> bool:
		captured.append(report)
		return false)
	check(captured.size() == 1 and captured[0].session == PREV and captured[0].capture == "recovered_checkpoint",
		"next-run recovery labels the interrupted report without exporting the current run")
	var previous_path: String = DIR.path_join(REPORT._file_name(PREV))
	check(FileAccess.file_exists(previous_path), "failed public export retains private checkpoint")
	cleaned.capture = "regular_exit"
	check(REPORT.write_private(DIR, cleaned) and not FileAccess.file_exists(previous_path + ".part"), "final checkpoint replaces staged file atomically")
	captured.clear()
	REPORT.recover_reports(DIR, ACTIVE, func(_directory: String, report: Dictionary) -> bool:
		captured.append(report)
		return false)
	check(captured.size() == 1 and captured[0].capture == "regular_exit", "retry preserves a known regular exit")
	for i: int in range(8):
		var another: Dictionary = active.duplicate()
		another.session = "2026-11-%02dT040000Z-abcdefabcdefabcdefabcdef" % (i + 1)
		REPORT.write_private(DIR, another)
	var partial := FileAccess.open(previous_path + ".part", FileAccess.WRITE)
	partial.store_string("interrupted")
	partial.close()
	REPORT.recover_reports(DIR, ACTIVE, func(_directory: String, _report: Dictionary) -> bool: return false)
	check(DirAccess.get_files_at(DIR).size() == REPORT.MAX_PRIVATE_REPORTS and not FileAccess.file_exists(previous_path + ".part"),
		"unexportable recovery files and abandoned temporary files stay bounded")
	var bounds: Dictionary = raw.duplicate(true)
	bounds.hitch_log.worst.resize(100)
	bounds.hitch_log.worst.fill(raw.hitch_log.worst[0])
	check(REPORT.clean_snapshot(bounds).hitch_log.worst.size() == HITCH.KEEP, "public report bounds the number of retained hitches")

func _lifecycle() -> void:
	_clear_dir()
	var session := REPORT.new()
	session._directory = DIR
	root.add_child(session)
	var filename: String = DIR.path_join(REPORT._file_name(session._session))
	check(root.go_back_requested.is_connected(session._on_back_request) and root.close_requested.is_connected(session._on_close_request), "real window lifecycle connects once")
	var previous_quit_on_back: bool = quit_on_go_back
	var previous_accept_quit: bool = auto_accept_quit
	quit_on_go_back = false
	auto_accept_quit = false
	session._on_back_request()
	session._on_close_request()
	check(not session._finished, "Back or Close that keeps the game open does not finalize the session")
	root.remove_child(session)
	check(not root.go_back_requested.is_connected(session._on_back_request)
		and not root.close_requested.is_connected(session._on_close_request), "exit removes both lifecycle listeners")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(filename))
	check(saved is Dictionary and saved.get("capture") == "regular_exit" and session._finished, "tree teardown joins checkpoint worker and finalizes a complete private report")
	session.free()
	quit_on_go_back = previous_quit_on_back
	auto_accept_quit = previous_accept_quit

func _run() -> void:
	_clear_dir()
	HITCH.reset_for_test(DIR)
	_publish_policy()
	_spool_and_privacy()
	_lifecycle()
	_clear_dir()
	print("PERFORMANCE_REPORT_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
