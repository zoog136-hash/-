extends SceneTree
const PREF = preload("res://scripts/maps/current523_aden_preferences.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	# Use an isolated XDG_DATA_HOME, as with the other direct runtime tests.
	if FileAccess.file_exists(PREF.PATH):
		push_error("Preferences test requires an empty isolated user profile")
		quit(1)
		return
	var sentinel_path: String = "user://current523-test-game-save.bin"
	var sentinel := FileAccess.open(sentinel_path, FileAccess.WRITE)
	sentinel.store_buffer(PackedByteArray([0, 255, 23, 41, 89]))
	sentinel.close()
	var save_sha: String = FileAccess.get_sha256(sentinel_path)
	check(PREF.selection() == {"raw":"", "tiles":""}, "missing preferences start empty")
	check(PREF.activate("/first/raw", "/first/tiles").ok, "first selection is atomically saved")
	check(PREF.selection() == {"raw":"/first/raw", "tiles":"/first/tiles"}, "two paths become active together")
	check(PREF.selection(true).raw == "", "first activation invents no previous pack")
	var config := ConfigFile.new()
	config.load(PREF.PATH)
	config.set_value("other", "retained", 927)
	config.save(PREF.PATH)
	check(PREF.activate("/second/raw", "/second/tiles").ok, "second selection activates")
	check(PREF.selection(true) == {"raw":"/first/raw", "tiles":"/first/tiles"}, "prior pair is retained together")
	check(PREF.activate("/second/raw", "/second/tiles").ok and PREF.selection(true).raw == "/first/raw", "reopening the same pack preserves rollback history")
	config.load(PREF.PATH)
	check(config.get_value("other", "retained", 0) == 927, "unrelated preference fields survive")
	var before: String = FileAccess.get_sha256(PREF.PATH)
	var result: Dictionary = PREF.rollback()
	check(not result.ok and not str(result.problem).is_empty(), "missing previous resource files reject rollback")
	check(FileAccess.get_sha256(PREF.PATH) == before, "failed rollback preserves all preference bytes")
	var pending: Array[String] = []
	for file: String in DirAccess.get_files_at("user://"):
		if file.contains(".pending-"): pending.append(file)
	check(pending.is_empty(), "atomic preference writes leave no pending file")
	check(FileAccess.get_sha256(sentinel_path) == save_sha, "selection changes preserve separate save bytes")
	print("CURRENT523_ADEN_PREFERENCES_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "fixture_only": true}))
	quit(0 if failures.is_empty() else 1)
