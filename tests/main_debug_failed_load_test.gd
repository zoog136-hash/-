extends SceneTree

const WORLD = preload("res://scripts/world.gd")
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Only the existing test_project.py runner's isolated Linux/Windows home is
	# accepted. Never rename, overwrite or delete an existing player's save.
	var platform: String = OS.get_name()
	var isolated_home: String = OS.get_environment("APPDATA") if platform == "Windows" else OS.get_environment("XDG_DATA_HOME")
	if platform not in ["Linux", "Windows"] or not isolated_home.get_file().begins_with("twilight-test-"):
		print("MAIN_DEBUG_FAILED_LOAD_SKIP: use tools/test_project.py with isolated test homes")
		quit(0)
		return
	if FileAccess.file_exists(WORLD.SAVE_PATH):
		print("MAIN_DEBUG_FAILED_LOAD_SKIP: existing save is protected")
		quit(0)
		return
	# Do not add the world to the tree: this exercises the real early-load code
	# without starting a game, autosaving, spawning monsters or touching UI.
	var world = WORLD.new()
	var expected_attack: Dictionary = {"probe": true, "id": 911}
	world.pending_attack = expected_attack.duplicate(true)
	var generation_before: int = world.combat_generation
	world._load_game(true)
	check(world.combat_generation == generation_before, "missing save preserves combat generation")
	check(world.pending_attack == expected_attack, "missing save preserves pending attack")
	world.pending_attack = expected_attack.duplicate(true)
	generation_before = world.combat_generation
	var file := FileAccess.open(WORLD.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		check(false, "test could not create its own isolated invalid JSON")
	else:
		file.store_string("{invalid_json")
		file.close()
		world._load_game(true)
		check(world.combat_generation == generation_before, "invalid JSON preserves combat generation")
		check(world.pending_attack == expected_attack, "invalid JSON preserves pending attack")
		check(DirAccess.remove_absolute(WORLD.SAVE_PATH) == OK, "remove only the test-created save")
	world.free()
	if failures.is_empty():
		print("MAIN_DEBUG_FAILED_LOAD_OK")
	else:
		for failure: String in failures:
			print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
