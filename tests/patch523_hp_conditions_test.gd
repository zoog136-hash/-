extends SceneTree
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PATCH523_HP_FAIL: ",label)
func reject(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
func run() -> void:
	check(D.install_zip(OS.get_environment("TWILIGHT_PATCH523_DROP_ZIP")).get("ok",false),"verified actual source pack")
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false)
	check(QA.enter_game(world),"actual Main source map")
	world.field_population.set_process(false);world.player.set_physics_process(false)
	world._clear_monsters();world._clear_drops()
	world.hp = maxi(1,world._effective_max_hp()-200)
	for id: String in ["126702","150973","164453","173003"]:
		var record: Dictionary = world._catalog_item_from_source_id("m523:item:"+id)
		world.inventory[str(record.name)] = 2
		check(not D.hp_use_problem(record).is_empty(),"all original region/lifetime/additional effects gate use "+id)
		check(D.item_details(record).contains("아이템 보존"),"actual item detail explains pending conditions "+id)
		var hp: int = world.hp;var state: int = world.rng.state
		world._on_inventory_item_activated(str(record.name))
		check(world.hp == hp and int(world.inventory[str(record.name)]) == 2 and world.rng.state == state,"inventory activation cannot partially apply source healing "+id)
		world._use_healing_item(str(record.name),10000)
		check(world.hp == hp and int(world.inventory[str(record.name)]) == 2,"direct/automatic healing shares source condition guard "+id)
	var potion: Dictionary = world._catalog_item_from_source_id("m523:item:236")
	world.inventory[str(potion.name)] = 2
	world.item_use_cooldowns.clear()
	check(D.hp_use_problem(potion).is_empty(),"pure exact HP dice and delay source remains usable")
	check(world._save_game(true) == OK,"durable baseline")
	var before: int = world.hp;var rng_before: int = world.rng.state
	world.equipment_collections.test_save_writer = reject
	world._use_quick_item(str(potion.name))
	world.equipment_collections.test_save_writer = Callable()
	check(world.hp == before and int(world.inventory[str(potion.name)]) == 2 and world.rng.state == rng_before,"failed HP write preserves all debit/HP/RNG state")
	world._use_quick_item(str(potion.name))
	check(world.hp > before and int(world.inventory[str(potion.name)]) == 1,"actual source HP use saves and consumes exactly one")
	var hp: int = world.hp
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	check(world.hp == hp and int(world.inventory[str(potion.name)]) == 1,"source HP debit and healing survive reentry")
	world.queue_free();await process_frame
	print("PATCH523_HP_CONDITIONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
