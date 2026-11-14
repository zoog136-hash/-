extends SceneTree
## Used-table list and loading-time preparation of outdated stored tables.
##   godot --headless --path <repo> --script res://tests/definition_used_tables_test.gd
## The conversion part runs only with the 523 definition archive installed
## ("original":"not_installed" otherwise; that is not counted as a pass).
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("DEFINITION_USED_TABLES_FAIL: " + label)

func _initialize() -> void:
	var saved_list: String = FileAccess.get_file_as_string(ROWS.USED_LIST) if FileAccess.file_exists(ROWS.USED_LIST) else ""
	DirAccess.remove_absolute(ROWS.USED_LIST)
	ROWS._used_saved = {}
	ROWS._used_loaded = false
	check(ROWS.used_tables().is_empty(), "no list: no used tables")
	ROWS._tables["SpellClass"] = {"count": 0, "columns": PackedStringArray(), "data": []}
	ROWS._tables["Bonus"] = {"count": 0, "columns": PackedStringArray(), "data": []}
	check(ROWS.remember_used_tables() == 2 and ROWS.remember_used_tables() == 0, "opened tables are added once")
	ROWS._used_saved = {}
	ROWS._used_loaded = false
	check(ROWS.used_tables() == PackedStringArray(["Bonus", "SpellClass"]), "the list survives a restart, sorted")
	var file := FileAccess.open(ROWS.USED_LIST, FileAccess.WRITE)
	file.store_string(JSON.stringify(["Bonus", "../x", 7, "SpellClass"]))
	file.close()
	ROWS._used_saved = {}
	ROWS._used_loaded = false
	check(ROWS.used_tables() == PackedStringArray(["Bonus", "SpellClass"]), "only table names are read from the list")
	ROWS.reset()
	var evidence: Dictionary = {"original": "not_installed"}
	if not ROWS.identity().is_empty():
		evidence.original = "installed"
		for table: String in ["TargetKind", "SpellClass"]:
			check(ROWS.prepare_table(table) and ROWS.stored_current(table), "%s is stored for the current original and format" % table)
		check(not ROWS.tables_to_prepare().has("SpellClass"), "a current stored table is not prepared again")
		ROWS.release_caches()
		var started: int = Time.get_ticks_usec()
		check(not ROWS.row("SpellClass", int(ROWS.rows("SpellClass")[0].ID)).is_empty(), "a prepared table opens from its stored form")
		evidence["reopen_ms"] = (Time.get_ticks_usec() - started) / 1000
	if saved_list.is_empty(): DirAccess.remove_absolute(ROWS.USED_LIST)
	else:
		file = FileAccess.open(ROWS.USED_LIST, FileAccess.WRITE)
		file.store_string(saved_list)
		file.close()
	print("DEFINITION_USED_TABLES_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
