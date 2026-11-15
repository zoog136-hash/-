extends SceneTree
## Monster A* searches share one budget per physics step: the first search of
## a step always runs, later ones wait for the next step, nothing is dropped.
##   godot --headless --path <repo> --script res://tests/monster_path_budget_test.gd
const MONSTER = preload("res://scripts/monster.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("MONSTER_PATH_BUDGET_FAIL: " + label)
func run() -> void:
	MONSTER._path_budget_frame = -1
	MONSTER._path_budget_spent = 0
	check(MONSTER._path_budget_open(), "a new physics step opens the budget")
	MONSTER._path_budget_spent = MONSTER.PATH_SEARCH_BUDGET_USEC - 1
	check(MONSTER._path_budget_open(), "a search may start while any budget remains")
	MONSTER._path_budget_spent = MONSTER.PATH_SEARCH_BUDGET_USEC
	check(not MONSTER._path_budget_open(), "a spent step defers further searches")
	await physics_frame
	await physics_frame
	check(MONSTER._path_budget_open() and MONSTER._path_budget_spent == 0, "the next physics step searches again")
	var source: String = FileAccess.get_file_as_string("res://scripts/monster.gd")
	check(source.contains("elif _path_budget_open():") and source.contains("monster.path_deferred"), "deferral keeps the current path without a cooldown")
	print("MONSTER_PATH_BUDGET_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
