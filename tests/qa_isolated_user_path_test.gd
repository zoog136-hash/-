extends SceneTree

const PATH_QA = preload("res://tests/qa_isolated_user_path.gd")
var failures: Array[String] = []
var checks := 0

func expect(actual: String, declared: String, windows_path: bool, expected: bool) -> void:
	checks += 1
	if PATH_QA.contains_user_directory(actual, declared, windows_path) != expected:
		failures.append(str(checks))
		printerr("ISOLATED_USER_PATH_FAIL ", checks)

func _initialize() -> void:
	expect("C:/Temp/case/Godot/app_userdata/game", "C:\\Temp\\case", true, true)
	expect("c:/temp/CASE/Godot/app_userdata/game", "C:/Temp/case/", true, true)
	expect("C:/Temp/case-other/Godot", "C:\\Temp\\case", true, false)
	expect("C:/Temp/other/Godot", "C:\\Temp\\case", true, false)
	expect("C:/Temp/case/../other/Godot", "C:\\Temp\\case", true, false)
	expect("/tmp/case/godot/app_userdata/game", "/tmp/case", false, true)
	expect("/tmp/case/godot/app_userdata/game", "/tmp/case/", false, true)
	expect("/tmp/case-other/godot", "/tmp/case", false, false)
	expect("/tmp/Case/godot", "/tmp/case", false, false)
	expect("/tmp/case/../other/godot", "/tmp/case", false, false)
	expect("/tmp/case/godot", "case", false, false)
	expect("/tmp/case/godot", "", false, false)
	expect("", "/tmp/case", false, false)
	print("ISOLATED_USER_PATH_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("ISOLATED_USER_PATH_OK")
	quit(0 if failures.is_empty() else 1)
