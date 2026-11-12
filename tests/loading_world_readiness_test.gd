extends SceneTree
## Fresh recovery test, not an exact reconstruction of the lost old SHA.
## Instantiate production Main without adding it to the tree: its startup and
## save writes do not run. These are readiness-state tests, not original-map
## integration or Android rendering evidence. Run with isolated user data.
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const FIELD = preload("res://scripts/maps/playable_field.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if FileAccess.file_exists(OPTIONS.PATH):
		printerr("LOADING_WORLD_TEST_REQUIRES_ISOLATED_USER_DATA")
		quit(1)
		return
	var world = (load("res://Main.tscn") as PackedScene).instantiate()
	world.call_deferred("_finish_boot_loading")
	var state: Dictionary = world.loading_readiness()
	check(not state.ready and not state.failed, "Main remains pending before its explicit deferred completion marker")
	await process_frame
	await process_frame
	world.map_bootstrap_blocked = true
	state = world.loading_readiness()
	check(state.failed and not state.ready and not str(state.reason).is_empty(), "blocked map bootstrap cannot become ready")
	world.map_bootstrap_blocked = false
	world.source_save_blocked = true
	state = world.loading_readiness()
	check(state.failed and not state.ready and str(state.reason).contains("저장"), "preserved but blocked source save reports failed readiness")
	world.source_save_blocked = false
	state = world.loading_readiness()
	check(state.failed and not state.ready and str(state.reason).contains("지도"), "deferred marker alone cannot make an absent original map ready")
	world.field_map = FIELD.new()
	world.active_map_id = "synthetic_readiness_state_only"
	state = world.loading_readiness()
	check(state.ready and not state.failed, "completed state with a field and no requested source restoration is ready")
	var selected: Dictionary = OPTIONS.defaults()
	selected.merge({"enabled":true, "navigation_profile":OPTIONS.SOURCE, "raw_root":"user://absent_synthetic_source", "tile_root":"user://absent_synthetic_tiles"}, true)
	if OPTIONS.write(selected) != OK:
		world.free()
		printerr("LOADING_WORLD_TEST_OPTIONS_WRITE_FAILED")
		quit(1)
		return
	world.active_map_id = "aden_world"
	world.current523_aden_play_problem = "synthetic_source_restore_incomplete"
	state = world.loading_readiness()
	check(state.failed and not state.ready and state.reason == "synthetic_source_restore_incomplete", "partial map flags do not hide configured but incomplete source restoration")
	world.current523_aden_play_active = true
	state = world.loading_readiness()
	check(state.ready and not state.failed, "source restoration active flag completes the explicit readiness contract")
	DirAccess.remove_absolute(OPTIONS.PATH)
	world.field_map = null
	world.free()
	print("LOADING_WORLD_READINESS_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "fixture":"production_Main_readiness_states_only"}))
	quit(0 if failures.is_empty() else 1)
