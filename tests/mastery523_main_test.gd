extends SceneTree
const Fixtures = preload("res://tests/mastery523_test.gd")
const Core = preload("res://scripts/mastery/mastery523.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("MASTERY_MAIN_FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main class confirmation")
	world.player.set_physics_process(false)
	for item: Dictionary in world.catalog_db.get("아이템",[]):
		if item.get("type") == "한손검" and item.get("slot") == "weapon":
			world._equip_or_acquire_item(item)
			break
	world.hud._navigate("weapon_mastery")
	check(is_instance_valid(world.weapon_mastery.view) and world.weapon_mastery.view.visible,"HUD menu opens actual mastery screen")
	check(not world.weapon_mastery.enabled,"default boot needs no private source pack")
	var runtime = world.weapon_mastery
	var path: String = OS.get_environment("TWILIGHT_MASTERY523_PACK")
	check(runtime.core.configure(Fixtures.fixture()) if path.is_empty() else runtime.core.load_pack(path,FileAccess.get_sha256(path)),"configure selected test source")
	runtime.enabled = true
	var weapon: int = int(runtime.core.levels.keys()[0])
	var grade: int = int(runtime.core.tables.MasteryGradeView[0].GradeID)
	var group: int = int(runtime.core.options.keys()[0])
	var old_hp: int = world._effective_max_hp()
	var old_melee: int = world._melee_damage_stat()
	var old_hit: int = world._melee_accuracy_stat()
	runtime.state.weapons[str(weapon)] = {"points":str(int(runtime.core.levels[weapon][0].CumulativePoint)),"options":[{"group_id":group}],"colors":{"1":[grade,grade,grade,grade]},"locks":{}}
	runtime.view.selected_weapon = weapon
	runtime.view.refresh()
	var active_bonus: Dictionary = runtime.core.active_options(runtime.state,weapon)[0]
	check(world._mastery_actual_weapon_type() == weapon,"actual equipped weapon resolves source mastery context")
	if active_bonus.type_name == "HPPlus":
		check(world._effective_max_hp()-old_hp == int(active_bonus.Value),"original HP option reaches actual maximum HP consumer")
	elif active_bonus.type_name == "MeleeHit":
		check(world._melee_accuracy_stat()-old_hit == int(active_bonus.Value),"original hit option reaches actual melee accuracy consumer")
	else:
		check(active_bonus.type_name == "MeleeDamage" and world._melee_damage_stat()-old_melee == int(active_bonus.Value),"fixture damage option reaches actual melee damage consumer")
	check(runtime.view.find_child("MasteryWeaponSelect",true,false) != null,"weapon selection is rendered in actual HUD")
	var snapshot: Dictionary = {"gold":world.gold,"inventory":world.inventory.duplicate(true),"equipment":world.item_instances.duplicate(true)}
	check(world._save_game(true) == OK,"real atomic save includes mastery state")
	var old_sha: String = FileAccess.get_sha256(world.save_path())
	var lock_button = runtime.view.find_child("MasteryLock_1_0",true,false)
	check(lock_button != null,"actual four-slot lock UI exists")
	if lock_button != null: lock_button.toggled.emit(true)
	check(runtime.core.record(runtime.state,weapon).locks.get("1",[false])[0] == true,"actual UI event updates owned color lock")
	check(FileAccess.get_sha256(world.save_path()) != old_sha,"UI action writes existing game save")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved[Core.SAVE_KEY].weapons[str(weapon)].locks["1"][0],"lock persisted in real save namespace")
	check(world.gold == snapshot.gold and world.inventory == snapshot.inventory and world.item_instances == snapshot.equipment,"mastery lock preserves money inventory physical equipment")
	var before: Dictionary = runtime.state.duplicate(true)
	var disk_sha: String = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_path: String,_payload: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not runtime.set_color_lock(weapon,1,0,false).ok,"save failure rejects UI state transition")
	check(runtime.state == before and FileAccess.get_sha256(world.save_path()) == disk_sha,"failed write rolls mastery and bytes back")
	world.equipment_collections.test_save_writer = Callable()
	var stale: Dictionary = runtime.core.plan_points(before,weapon,"1","stale-test")
	check(runtime.credit_confirmed_points(weapon,"1","accepted-test").ok,"confirmed point award commits through actual Main")
	check(not runtime.commit_plan(stale).ok,"old point plan rejected after another commit")
	var server: Dictionary = runtime.core.plan_server_import(runtime.state,runtime.state,{str(weapon):0},"server-test")
	check(server.ok and not runtime.commit_plan(server).ok,"local Main refuses a two-server settlement")
	var active: Dictionary = runtime.state.duplicate(true)
	runtime.state = Core.fresh()
	world._load_game(true)
	check(normalized(runtime.state) == normalized(active),"actual Main reload restores source mastery state")
	runtime.enabled = false
	world._load_game(true)
	check(world._save_game(true) == OK,"save without private pack remains available")
	var no_pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(normalized(no_pack.get(Core.SAVE_KEY)) == normalized(active),"missing private pack preserves opaque original namespace")
	runtime.enabled = true
	var corrupt: Dictionary = no_pack.duplicate(true)
	corrupt[Core.SAVE_KEY].weapons[str(weapon)].points = "-1"
	check(preload("res://scripts/skills/save_writer.gd").write(world.save_path(),corrupt) == OK,"malformed test fixture written to isolated save")
	var corrupt_sha: String = FileAccess.get_sha256(world.save_path())
	world._load_game(true)
	check(world.equipment_collections.save_blocked and normalized(runtime.state) == normalized(active),"malformed mastery rejects before replacing live state")
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == corrupt_sha,"rejected save bytes protected")
	print("MASTERY_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":"synthetic" if path.is_empty() else "actual523"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
