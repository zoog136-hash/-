extends SceneTree
const Core = preload("res://scripts/mastery/mastery523.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MASTERY_INSTALL_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main class confirmation")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	var runtime = world.weapon_mastery
	# No manual configure/load_pack call: production CLI installation must work.
	check(runtime.enabled and runtime.problem.is_empty(),"production CLI automatically loads private mastery pack")
	check(runtime.core.levels.size() == 15 and runtime.core.options.size() == 36 and runtime.core.tables.get("MasteryGradeMatchingBonus",[]).size() == 60,"actual installed source graph is complete")
	world.hud._navigate("weapon_mastery")
	check(is_instance_valid(runtime.view) and runtime.view.visible,"installed feature opens through actual game menu")
	check(runtime.save_fields().has(Core.SAVE_KEY),"installed feature exports native save namespace")
	check(world._save_game(true) == OK,"actual Main writes installed feature")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved.get(Core.SAVE_KEY,{}).get("version") == 1,"durable namespace has expected schema")
	world._load_game(true)
	check(runtime.enabled and runtime.core.validate_state(runtime.state).is_empty() and not world.equipment_collections.save_blocked,"actual reload accepts installed feature without protection bypass")
	print("MASTERY_INSTALLED_PACK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_CLI_INSTALLED_PACK_MENU_SAVE_RELOAD"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
