extends SceneTree
## A save re-reads the previous save file only when it is not the file this
## session last wrote with the shop state in it.
##   godot --headless --path <repo> --script res://tests/previous_save_check_test.gd
const CHECK = preload("res://scripts/save/previous_save_check.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("PREVIOUS_SAVE_CHECK_FAIL: " + label)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text); file.flush(); file.close()

func _initialize() -> void:
	var path: String = "user://previous_save_check_test.json"
	_write(path, JSON.stringify({"source_shop": {"orders": {}}, "gold": 1}))
	var written: String = FileAccess.get_sha256(path)
	check(CHECK.needs_reading(path, ""), "nothing written this session: read the previous file")
	check(not CHECK.needs_reading(path, written), "the file this session wrote with the shop state is not read again")
	_write(path, JSON.stringify({"gold": 1}))
	check(CHECK.needs_reading(path, written), "an externally changed file is read again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(CHECK.needs_reading(path, written), "a missing file reads as needing a check")
	var world: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world.contains("needs_reading(save_path(),_shop_key_saved_sha)") and world.contains('_shop_key_saved_sha=str(equipment_collections.get("_disk_hash"))'), "world uses the check and records the written SHA")
	print("PREVIOUS_SAVE_CHECK_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
