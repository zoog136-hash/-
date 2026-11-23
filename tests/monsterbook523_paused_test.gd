extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Exact = preload("res://scripts/equipment523/native_catalog.gd")
const Runtime = preload("res://scripts/monsterbook/monsterbook523_runtime.gd")
var checks: int = 0
var failures: Array[String] = []
var credits: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("MONSTERBOOK_PAUSED_FAIL ", label)

func run() -> void:
	check(not Runtime.progression_enabled(), "ships paused without any test override")
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "real Main entry")
	var runtime: RefCounted = world.monsterbook523_runtime
	var seed: Dictionary = {"schema":1,"books":{"6013":{"sequence":7,"current_epoch":"paused-test","epochs":{"paused-test":{"counts":{"16423":999},"kill_count":999,"registered":[],"claimed":[],"effective_levels":[]}}}}}
	check(runtime.catalog.import_state(seed), "existing ledger can still be loaded")
	var before: Dictionary = runtime.catalog.export_state()
	# Isolate the guard with a catalog that matches a real kill even without a private resource pack.
	var original_tables: Dictionary = runtime.catalog._tables
	runtime.catalog._tables = {"MonsterBook":[{"ID":6013,"NpcGroupID":10}],"NpcClassForNpcGroup":[{"NpcClassID":6681,"NpcGroupID":10}]}
	check(runtime.catalog.target_books(6681).size() == 1, "fixture would dispatch a book credit")
	runtime.credit_authority = func(_npc: int, _life: int, _actor: int, _state: Dictionary) -> Dictionary:
		credits += 1
		return {}
	var xp_before: int = int(world.experience)
	var level_before: int = int(world.level)
	var actor: Node = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(actor)
	actor.setup({"name":"monsterbook-pause-check","source_m_npc_id":6681,"hp":1,"xp":10,"gold":0,"drop":[],"lv":1},world.player,world,null)
	actor.set_physics_process(false)
	actor.died.connect(world._on_monster_died)
	actor.take_damage(int(actor.hp) + 1)
	check(actor.dead and (int(world.experience) > xp_before or int(world.level) > level_before), "ordinary kill and XP still work")
	check(credits == 0 and runtime.pending_deaths.is_empty(), "kill skips book credit and queues no book save")
	runtime.catalog._tables = original_tables
	check(world.monsterbook_action_status("register",6013,16423) == Runtime.PAUSED_MESSAGE, "registration reports pause")
	for action: String in ["register","claim","instant","effects","auto_effects"]:
		check(not world.request_monsterbook_action(action,6013,16423).ok, action + " cannot mutate")
	check(not runtime.apply_confirmed({"action":"count"}), "confirmed side entrance is blocked")
	check(not runtime.economy.exchange(1).ok, "do not sell suspended progression currency")
	check(runtime.catalog.export_state() == before, "historical book state is unchanged")
	world.hud.toggle_menu()
	await process_frame
	check(world.hud.find_child("MenuTile_monsterbook523",true,false) == null, "book tile hidden")
	check(world.hud.find_child("MenuTile_아이템",true,false) != null, "item book tile is unaffected")
	var prior_section: String = world.hud.active_section
	world.hud.open_monsterbook523()
	check(world.hud.active_section == prior_section, "direct HUD entry does not mount")
	var native = preload("res://scripts/ui/original_ui/source_main_hud.gd").new()
	check(native.try_open_feature_window("monsterbook").get("code") == "source_monsterbook_progression_paused", "native feature cannot bypass pause")
	native.free()
	check(world._save_game(true) == OK, "ordinary save still works")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(disk is Dictionary and Exact.same(disk.get("monsterbook523"), before), "ordinary save preserves the original ledger")
	world.queue_free()
	await process_frame
	print("MONSTERBOOK_PAUSED_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
