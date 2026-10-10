extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const SAVE_PATH := "user://twilight_v20_save.json"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("SKILL_WAREHOUSE FAIL: ", message)

func same_json_values(actual: Variant, expected: Variant) -> bool:
	# JSON has one numeric type: 5 is parsed as 5.0. Compare the persistence
	# values without requiring an in-memory int tag that JSON cannot retain.
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))

func write_save(text: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	check(file != null, "temporary save can be written")
	if file != null:
		file.store_string(text)
		file.close()

func run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual game")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world.level = 90
	world._on_job_class_selected("마법사")
	var catalog := world.original_skills.catalog
	var turn := catalog.record_for("턴 언데드")
	world.inventory[str(turn.book_name)] = 1
	check(catalog.learn(str(turn.id)), "learn actual book before the joint save")
	world._on_quickslot_assignment_requested(0, "skill_auto", str(turn.id))
	world.mp = world._effective_max_mp()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	check(world._cast_job_skill("실드"), "actual paid buff before the joint save")
	world.skill_cooldowns[str(turn.name)] = 3.0
	var stored: Dictionary = {"stacks":{"수정 단검":1,"HP 물약":4},"instances":{"9001":{"name":"수정 단검","level":5,"element":"water","element_level":2,"record":{"grade":"고급","sourceId":"migration-fixture"}}}}
	var history: Array = [{"recipe_id":"save-fixture","name":"수정 단검","quantity":1}]
	world.warehouse.restore(stored)
	world.crafting_log.assign(history)
	world.gold = 54321
	world._save_game(true)
	var current_text := FileAccess.get_file_as_string(SAVE_PATH)
	var current: Dictionary = JSON.parse_string(current_text)
	check(current.has("original_skill_state") and current.has("warehouse") and current.has("crafting_log"), "one actual save contains all three systems")
	world.warehouse.restore({})
	world.crafting_log.clear()
	catalog.learned.clear()
	world.active_skill_buffs.clear()
	world.skill_cooldowns.clear()
	world.quickslots.clear()
	world.gold = 0
	world._load_game(true)
	check(same_json_values(world.warehouse.snapshot(), stored), "current save restores exact stored physical ID, enchant and element")
	check(same_json_values(world.crafting_log, history) and world.gold == 54321, "current save restores crafting history and gold")
	check(int(catalog.learned.get(str(turn.id), 0)) == 1, "current save preserves the original learned skill ID")
	check(str(world.quickslots[0].get("skill_id", "")) == str(turn.id) and bool(world.quickslots[0].get("auto", false)), "current save preserves stable AUTO slot")
	check(is_equal_approx(float(world.skill_cooldowns.get(str(turn.name), 0)), 3.0), "current save preserves skill cooldown")
	check(world.active_skill_buffs.has("실드"), "current save restores the actual skill buff")
	var legacy := current.duplicate(true)
	legacy.erase("original_skill_state")
	var legacy_text := JSON.stringify(legacy)
	var backup_path := ProjectSettings.globalize_path(SAVE_PATH + ".pre-original-skills")
	if FileAccess.file_exists(backup_path): DirAccess.remove_absolute(backup_path)
	write_save(legacy_text)
	world.warehouse.restore({})
	world.crafting_log.clear()
	world.gold = 0
	world._load_game(true)
	check(FileAccess.file_exists(backup_path) and FileAccess.get_file_as_string(backup_path) == legacy_text, "legacy migration first creates an exact unmodified backup")
	check(same_json_values(world.warehouse.snapshot(), stored) and same_json_values(world.crafting_log, history), "legacy migration also restores warehouse and crafting rather than choosing one conflict side")
	check(world.gold == 54321, "legacy migration restores normal character state")
	legacy["gold"] = 76543
	write_save(JSON.stringify(legacy))
	world._load_game(true)
	check(FileAccess.get_file_as_string(backup_path) == legacy_text, "a second load cannot overwrite the first legacy backup")
	check(world.gold == 76543 and same_json_values(world.warehouse.snapshot(), stored), "later legacy load still restores current data")
	# An unwritable backup destination must abort BEFORE mutating any restored
	# system. This is a private test directory, never an existing player's save.
	check(DirAccess.remove_absolute(backup_path) == OK, "remove this fixture's backup before the controlled failure")
	check(DirAccess.make_dir_absolute(backup_path) == OK, "directory fixture prevents copying to the backup filename")
	var untouched_storage: Dictionary = {"stacks":{"HP 물약":9},"instances":{}}
	world.warehouse.restore(untouched_storage)
	world.crafting_log.assign([{"name":"must survive backup failure"}])
	world.gold = 2121
	var saved_error_output := Engine.print_error_messages
	Engine.print_error_messages = false # Suppress only the expected native copy error.
	world._load_game(true)
	Engine.print_error_messages = saved_error_output
	check(world.warehouse.snapshot() == untouched_storage, "failed old-save backup cannot clear or replace warehouse")
	check(world.crafting_log == [{"name":"must survive backup failure"}] and world.gold == 2121, "failed backup leaves crafting and character state untouched")
	check(FileAccess.get_file_as_string(SAVE_PATH) == JSON.stringify(legacy), "failed migration leaves the source save untouched")
	check(DirAccess.remove_absolute(backup_path) == OK, "remove only the fixture's empty directory")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_WAREHOUSE_MIGRATION_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
