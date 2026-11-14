extends SceneTree
## Script/engine errors are recorded once each and named on the next start.
##   godot --headless --path <repo> --script res://tests/error_record_test.gd
const RECORD = preload("res://scripts/boot/error_record.gd")
const DIR := "user://error_record_test"
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ERROR_RECORD_FAIL: " + label)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name: String in [RECORD.FILE_NAME, RECORD.PREV_NAME]: DirAccess.remove_absolute(DIR.path_join(name))
	RECORD.install(DIR)
	_fail_twice.call_deferred()

func _fail_twice() -> void:
	for index: int in 2: _bad_access()
	push_error("second distinct error")
	_finish.call_deferred()

func _bad_access() -> void:
	var value: Dictionary = {}
	var _unused = value.missing_key.next

func _finish() -> void:
	RECORD.uninstall_for_test()
	var text: String = FileAccess.get_file_as_string(DIR.path_join(RECORD.FILE_NAME))
	var lines: PackedStringArray = text.split("\n", false)
	check(lines.size() == 2, "each distinct error is written once (%d lines)" % lines.size())
	check(text.contains("at=error_record_test.gd:") and text.contains("missing_key"), "the script error names file, line and message")
	check(text.contains("second distinct error"), "push_error is recorded")
	# Next start: the record becomes the previous one and is named.
	RECORD.install(DIR)
	RECORD.uninstall_for_test()
	var line: String = RECORD.previous_line(DIR)
	check(line.begins_with("지난 실행 마지막 오류(2종): "), "the loading line counts distinct errors: " + line)
	check(line.contains("second distinct error"), "the loading line names the last error: " + line)
	var first: Dictionary = RECORD.previous_last(DIR)
	check(str(first.get("at", "")).begins_with("error_record_test.gd:") or str(first.get("at", "")).length() > 0, "the last error has a place")
	for name: String in [RECORD.FILE_NAME, RECORD.PREV_NAME]: DirAccess.remove_absolute(DIR.path_join(name))
	check(RECORD.previous_line(DIR).is_empty(), "no record, no line")
	print("ERROR_RECORD_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "line":line}))
	quit(0 if failures.is_empty() else 1)
