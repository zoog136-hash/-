extends SceneTree
## TWILIGHT 근사 2026-11-17: an explicit allow list of TestItem craft results
## (current523_definition_rows.APPROX_TEST_ITEMS) is read as ordinary items; every
## other test item stays refused. With the original ZIP, in actual Main: the rows read
## TestItem=false, the items are registered, a card item gives its original card, a box
## opens through its own LuckyBag rows, and the crafts that give them are admitted.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("TEST_ITEM_ALLOWLIST523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func record(id: int) -> Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func runtime() -> void:
	check(SOURCE.row("ItemClass",1067).get("TestItem") == false and SOURCE.row("ItemClass",125502).get("TestItem") == false, "allow-listed rows read TestItem=false")
	check(SOURCE.row("ItemClass",962).get("TestItem") == true and SOURCE.row("ItemClass",328371).get("TestItem") == true, "other test items stay TestItem=true")
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for frame: int in 10: await process_frame
	var registered: Array = []; var profiles: Dictionary = {}
	for id: int in SOURCE.APPROX_TEST_ITEMS:
		var value: Dictionary = record(id)
		if not value.is_empty(): registered.append(id)
		profiles[str(id)] = STACK.profile(value).get("kind","") if not value.is_empty() else ""
	evidence["registered"] = registered.size(); evidence["profiles"] = profiles
	check(registered.size() == SOURCE.APPROX_TEST_ITEMS.size(), "all %d allow-listed items registered (%d)" % [SOURCE.APPROX_TEST_ITEMS.size(),registered.size()])
	check(str(profiles.get("1067","")) == "card" and str(profiles.get("125502","")) in ["bag","selection"], "card / box use owners "+str(profiles))
	check(record(962).is_empty(), "a test item outside the list is not registered")
	# Card: 아크 나이트 (BuffCardID 140).
	world.inventory = {}; world.item_instances = {}
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":1067,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if check(staged.get("ok",false), "grant 아크 나이트 card item: "+str(staged.get("error",""))):
		world._save_game(true,staged.overrides)
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		world.item_use_cooldowns.clear()
		var used: Dictionary = STACK.try_use(world,str(record(1067).name))
		evidence["card_use"] = {"ok":used.get("ok"),"reason":used.get("reason",""),"message":used.get("message","")}
		check(used.get("ok",false), "the card item gives its original card "+str(evidence.card_use))
	# Crafts giving them.
	var book: Object = world.patch523_equipment
	var crafts: Array = []
	for id: String in book.recipes:
		if int(str(book.recipes[id].result.source_id)) in SOURCE.APPROX_TEST_ITEMS: crafts.append(id)
	evidence["crafts"] = crafts
	evidence["rejected"] = book.data.get("recipe_summary",{}).get("rejected",{})
	check(crafts.size() >= 10, "crafts with an allow-listed result are admitted (%d)" % crafts.size())
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	check(SOURCE.APPROX_TEST_ITEMS.size() == 25, "allow list")
	if not SOURCE.not_installed(): await runtime()
	print("TEST_ITEM_ALLOWLIST523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
