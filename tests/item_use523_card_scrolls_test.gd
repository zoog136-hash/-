extends SceneTree
## 카드 주문서 (item-use audit 2026-11-21): original ScrollBuffCardRetry /
## ScrollBuffCardAwakenRetry items were refused in the bag as storage items.
## - 미스터리 카드 ("[미스터리 변신 카드] 영웅" …: BuffDeckID + GradeID) give
##   one card of that deck and grade (TWILIGHT 근사: equal draw over the deck's
##   catalog cards of the grade without date/server/test/exclusion), through
##   the fixed card owner;
## TJ 쿠폰 rows (PlayerValueReturn) of these categories are not part of this
## test (TJ coupon owner); they stay as before.
## Without the pinned 523 tables only the routing runs. With them every such
## item is classified; with --runtime each one is used from the bag in Main.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## ItemCategory ScrollBuffCardRetry / ScrollBuffCardAwakenRetry.
const CATEGORIES = ["ScrollBuffCardRetry","ScrollBuffCardAwakenRetry"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/loot/current523_native_stack.gd")
	var storage: int = text.find('supply_profile(record).get("kind")=="storage":return _failure(')
	check(text.find("return use_mystery_card(world,uid,owned,record)") in range(0, storage), "mystery cards run before the storage refusal")
	check(STACK.mystery_card_rule({}).is_empty(), "a non-original record is no mystery card")

var baseline: Dictionary = {}
func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var save_path: String = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	baseline = world.consumable_service.export_state()
	var categories: Dictionary = {}
	for row: Dictionary in SOURCE.rows("ItemCategory"):
		if str(row.get("Name","")) in CATEGORIES: categories[int(row.ID)] = true
	var mystery: Dictionary = {"used":0,"empty_pool":0,"refused":{}}
	var tj: Dictionary = {"window":0,"refused":{}}
	var other: int = 0
	for row: Dictionary in SOURCE.rows("ItemClass"):
		if row.get("TestItem", true) != false or not categories.has(int(row.get("CategoryID", 0))): continue
		var id: int = int(row.ID)
		var record: Dictionary = D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1)
		if record.is_empty(): continue
		var is_mystery: bool = not STACK.mystery_card_rule(record).is_empty()
		var is_tj: bool = false
		if not is_mystery and not is_tj: other += 1; continue
		world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
		world.consumable_service.import_state(baseline.duplicate(true))
		world.hud.set("card_reveal_stage", null)
		for child: Node in world.hud.get_children():
			if str(child.name).begins_with("CardRevealLayer"): world.hud.remove_child(child); child.free()
		var staged: Dictionary = INV.stage(world, [{"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if not staged.get("ok", false) or world._save_game(true, staged.overrides) != OK:
			var bucket: Dictionary = mystery if is_mystery else tj
			bucket.refused[str(id)] = "stage:" + str(staged.get("error",""))
			continue
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var name: String = str(record.name)
		var cards_before: String = JSON.stringify(world.card_draw_fusion.export_state())
		world.hud.message_label.text = ""
		if world.hud.workspace != null: world.hud.workspace.hide()
		world.hud.active_section = ""
		world._on_inventory_item_activated(name)
		var message: String = world.hud.message_label.text
		if is_mystery:
			var pool: Array = STACK.mystery_card_pool(world, STACK.mystery_card_rule(record))
			if pool.is_empty():
				mystery.empty_pool += 1
				if int(world.inventory.get(name, 0)) != 2: mystery.refused[str(id)] = "consumed without a pool"
			elif int(world.inventory.get(name, 0)) == 1 and JSON.stringify(world.card_draw_fusion.export_state()) != cards_before: mystery.used += 1
			else: mystery.refused[str(id)] = message
		else:
			if int(world.inventory.get(name, 0)) == 2 and str(world.hud.active_section) == "tj_coupons": tj.window += 1
			else: tj.refused[str(id)] = message + " / " + str(world.hud.active_section)
		world.patch523_owner_state_problem = ""
	check(mystery.refused.is_empty(), "every mystery card with a pool gives one card: " + JSON.stringify(mystery.refused).left(800))
	check(tj.refused.is_empty(), "every TJ coupon opens the TJ coupon window and is kept: " + JSON.stringify(tj.refused).left(800))
	check(int(mystery.used) > 0, "mystery cards were used")
	evidence["mystery"] = {"used":mystery.used,"empty_pool":mystery.empty_pool,"refused":mystery.refused.size()}
	evidence["tj"] = {"window":tj.window,"refused":tj.refused.size()}
	evidence["other"] = other
	world.queue_free()
	await process_frame
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)

func run() -> void:
	rules()
	if not SOURCE.not_installed() and "--runtime" in OS.get_cmdline_user_args(): await runtime()
	print("ITEM_USE523_CARD_SCROLLS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
