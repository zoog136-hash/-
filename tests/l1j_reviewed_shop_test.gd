extends SceneTree
## Real HUD signals, world transactions, gear instances and save/load.
const SHOPS = preload("res://addons/twilight_l1j/twilight_reviewed_shops.gd")
const SHOP = preload("res://scripts/shop/shop_catalog.gd")
const SHOP_UI = preload("res://scripts/ui/renewal_shop.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
# Freeze the legacy contract independently of the live shop constants.
# PR141 expands GOODS; it must not reprice or remove these original rows.
const EXPECTED_LEGACY_GOODS = [
	["HP 물약", 50, "물약"],
	["강력 HP 물약", 180, "물약"],
	["축복받은 HP 물약", 450, "물약"],
	["초록 잎", 100, "소모품"],
	["드래곤의 루비", 15000, "소모품"],
	["드래곤의 사파이어", 25000, "소모품"],
	["드래곤의 다이아몬드", 50000, "소모품"],
	["드래곤의 고급 다이아몬드", 250000, "소모품"],
	["드래곤의 성수", 600000, "소모품"],
	["드래곤의 용옥", 1000000, "소모품"],
	["무기 마법 주문서 (각인)", 25000, "강화 주문서"],
	["갑옷 마법 주문서 (각인)", 18000, "강화 주문서"],
	["장신구 마법 주문서 (각인)", 35000, "강화 주문서"],
	["축복 부여 주문서 (각인)", 250000, "강화 주문서"],
	["축복받은 무기 마법 주문서 (각인)", 120000, "강화 주문서"],
	["축복받은 갑옷 마법 주문서 (각인)", 90000, "강화 주문서"],
	["장인의 무기 마법 주문서 (각인)", 350000, "강화 주문서"],
	["장인의 갑옷 마법 주문서 (각인)", 300000, "강화 주문서"],
	["오림의 장신구 마법 주문서 (각인)", 150000, "강화 주문서"],
	["축복받은 오림의 장신구 마법 주문서 (각인)", 450000, "강화 주문서"]
]
var failures: Array[String] = []
var checks: int = 0
var world: TwilightWorld

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("L1J_REVIEWED_SHOP_FAIL: ", message)

func _snapshot() -> Dictionary:
	return {"gold":world.gold, "inventory":world.inventory.duplicate(true), "instances":world.item_instances.duplicate(true), "equipped":world.equipped_items.duplicate(true)}

func _check_general_stock(expected: Array, context: String) -> void:
	check(SHOP.GOODS == expected, context + ": complete general stock unchanged")
	check(SHOP.LEGACY_GOODS == EXPECTED_LEGACY_GOODS, context + ": legacy rows unchanged")

func _run() -> void:
	# Snapshot before vendor setup, not after a UI operation could mutate it.
	var original_stock: Array = SHOP.GOODS.duplicate(true)
	SHOPS.set_enabled(true)
	SHOP_UI.selected_vendor_id = ""
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	check(CLASS_QA.enter_game(world), "class confirmed")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -10000
	var catalog: Array = world.catalog_db.get("아이템", [])
	var original_catalog: Array = catalog.duplicate(true)
	var profiles: Array = SHOPS.profiles(catalog)
	check(profiles.size() == 4, "four audited source merchant profiles")
	check(SHOP.LEGACY_GOODS == EXPECTED_LEGACY_GOODS, "legacy names, prices and categories preserved")
	check(SHOP.GOODS.size() > EXPECTED_LEGACY_GOODS.size(), "expanded consumables remain available")
	check(SHOP.GOODS.slice(0, EXPECTED_LEGACY_GOODS.size()) == EXPECTED_LEGACY_GOODS, "legacy stock prefix preserved")
	for entry: Array in EXPECTED_LEGACY_GOODS:
		check(SHOP.price_for(str(entry[0])) == int(entry[1]), "authoritative legacy price preserved: " + str(entry[0]))
	_check_general_stock(original_stock, "vendor setup")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHOPS.PATH))
	var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHOPS.VISUAL_PATH))
	for field: String in ["price", "quantity", "enchant", "game_source_id"]:
		var bad: Dictionary = payload.duplicate(true)
		bad.profiles[0].goods[0][field] = "unknown" if field == "game_source_id" else -1
		check(SHOPS.validate(bad,catalog,visuals).size() == 3, "invalid offer rejected: " + field)
	var bad_pack: Dictionary = payload.duplicate(true)
	bad_pack.profiles[0].goods[0].source_shop_row.pack_count = 2
	check(SHOPS.validate(bad_pack,catalog,visuals).size() == 3, "unreviewed pack policy rejected")
	var bad_npc: Dictionary = payload.duplicate(true)
	bad_npc.profiles[0].source_npc_row.npcid = 70047
	check(SHOPS.validate(bad_npc,catalog,visuals).size() == 3, "NPC identity mismatch rejected")
	var duplicate: Dictionary = payload.duplicate(true)
	duplicate.profiles.append(duplicate.profiles[0].duplicate(true))
	check(SHOPS.validate(duplicate,catalog,visuals).size() == 3, "duplicate vendor identity rejected")
	var ambiguous: Array = catalog.duplicate(true)
	var other: Dictionary = world._catalog_item_from_source_id("6391").duplicate(true)
	other.sourceId = "other-source"
	ambiguous.append(other)
	check(SHOPS.validate(payload,ambiguous,visuals).is_empty(), "same-name inventory collision cannot sell an ambiguous record")
	var bad_sql: Dictionary = payload.duplicate(true)
	bad_sql.source_sql_sha256 = "unreviewed"
	check(SHOPS.validate(bad_sql,catalog,visuals).is_empty(), "unreviewed source snapshot rejected")

	world.gold = 500000
	world.hud.open_npc_shop()
	var default_vendor: OptionButton = world.hud.workspace.find_child("ShopVendor",true,false)
	check(default_vendor != null and default_vendor.item_count == 5, "default plus four vendors visible")
	var default_shop: Node = default_vendor.get_parent()
	default_shop.call("_refresh")
	default_shop.call("_select",1)
	default_shop.call("_refresh")
	check(default_shop.filtered == original_stock, "refresh retains every expanded offer, price and category")
	_check_general_stock(original_stock, "general shop refresh")
	# The UI must receive a deep copy, including its nested price rows.
	var detached_goods: Array = default_shop.call("_goods")
	check(detached_goods == original_stock, "UI receives complete authoritative stock")
	if not detached_goods.is_empty():
		detached_goods[0][1] = -777
		detached_goods.clear()
	_check_general_stock(original_stock, "mutating detached UI copy")
	check(default_shop.filtered == original_stock, "detached copy cannot mutate displayed stock")
	var potion_before: int = int(world.inventory.get("HP 물약",0))
	world._buy_shop_item("HP 물약", -100000)
	check(world.gold == 499950 and int(world.inventory.get("HP 물약",0)) == potion_before+1, "forged UI price ignored")
	world._grant_playtest_catalog_variant("6391",1)
	var old_id: String = world._chosen_instance("은장검")
	check(not old_id.is_empty(), "existing physical weapon")
	world.item_instances[old_id].level = 6
	world._equip_or_acquire_item(world._catalog_item_from_source_id("6391"),false,old_id)
	var old_weapon: Dictionary = world.item_instances[old_id].duplicate(true)
	var purchases: int = 0
	for profile: Dictionary in profiles:
		world.hud.open_npc_shop()
		var selector: OptionButton = world.hud.workspace.find_child("ShopVendor",true,false)
		var shop: Node = selector.get_parent()
		var index: int = -1
		for i: int in range(selector.item_count):
			if str(selector.get_item_metadata(i)) == str(profile.source_npc_id): index = i
		check(index > 0, "source vendor listed " + str(profile.name))
		if index <= 0: continue
		selector.select(index)
		selector.item_selected.emit(index)
		check(shop.filtered.size() == 1 and str(shop.selected[0]) == "은장검", "reviewed source item selected")
		check(shop.purchase_quantity.max_value == SHOP.MAX_QUANTITY and shop.purchase_quantity.editable, "source pack of one means one weapon per unit, not one unit per order")
		for supported_count: int in [1, 10, 100, 1000]:
			shop.call("_set_purchase_quantity", supported_count)
			check(int(shop.purchase_quantity.value) == supported_count, "reviewed vendor quantity selector: " + str(supported_count))
		shop.call("_set_purchase_quantity", 1)
		var before: Dictionary = _snapshot()
		shop.call("_buy")
		check(world.gold == int(before.gold),"source shop awaits purchase confirmation")
		var confirmation: Control = world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
		check(confirmation != null,"reviewed purchase confirmation exists")
		if confirmation != null: confirmation._accept()
		var price: int = int(profile.goods[0].price)
		check(world.gold == int(before.gold)-price, "authoritative vendor base price " + str(profile.name))
		check(int(world.inventory.get("은장검",0)) == int(before.inventory.get("은장검",0))+1, "one weapon acquired")
		var new_ids: Array = []
		for key: Variant in world.item_instances:
			if not before.instances.has(key): new_ids.append(key)
		check(new_ids.size() == 1, "one new physical ID")
		if new_ids.size() == 1:
			var entry: Dictionary = world.item_instances[new_ids[0]]
			check(int(entry.level) == 0 and str(entry.get("sourceId","")) == "6391" and str(entry.record.get("sourceId","")) == "6391", "new source weapon remains +0 with existing game ID")
		check(world.item_instances[old_id] == old_weapon and str(world.equipped_items.weapon.get("instance_id","")) == old_id, "prior +6 instance and equipment selection unchanged")
		check(SHOP_UI.selected_vendor_id == str(profile.source_npc_id), "vendor survives post-purchase refresh")
		_check_general_stock(original_stock, "reviewed purchase " + str(profile.name))
		purchases += 1

	var guard: Dictionary = _snapshot()
	# Quantities 2..1000 are legitimate if funds and weight allow; only
	# malformed/out-of-range quantities may be used in this no-mutation guard.
	for bad_quantity: int in [-1,0,1001,1000000]:
		world._buy_reviewed_shop_item("ext:a3:npc:70039","은장검",bad_quantity)
	world._buy_reviewed_shop_item("unknown-vendor","은장검",1)
	world._buy_reviewed_shop_item("ext:a3:npc:70039","진명황의 집행검",1)
	world._buy_shop_item("은장검",1)
	check(_snapshot() == guard, "unknown vendor/product, wrong quantity and legacy bypass cannot mutate wallet or gear")
	world.gold = 0
	guard = _snapshot()
	world._buy_reviewed_shop_item("ext:a3:npc:70039","은장검",1)
	check(_snapshot() == guard, "insufficient funds is atomic")
	world.gold = 200000
	var weight: int = int(world.item_weight_index.get("은장검",3))
	world.item_weight_index["은장검"] = world._carrying_capacity()+1
	guard = _snapshot()
	world._buy_reviewed_shop_item("ext:a3:npc:70039","은장검",1)
	check(_snapshot() == guard, "weight capacity is rechecked")
	world.item_weight_index["은장검"] = weight

	SHOPS.set_enabled(false)
	guard = _snapshot()
	world._buy_reviewed_shop_item("ext:a3:npc:70039","은장검",1)
	world.hud.open_npc_shop()
	var rolled_back: OptionButton = world.hud.workspace.find_child("ShopVendor",true,false)
	check(_snapshot() == guard and rolled_back.item_count == 1 and SHOP_UI.selected_vendor_id == "", "rollback hides vendors and preserves owned weapons")
	var rolled_back_shop: Node = rolled_back.get_parent()
	check(rolled_back_shop.filtered == original_stock, "vendor rollback restores full expanded stock")
	_check_general_stock(original_stock, "vendor rollback")
	world._buy_shop_bulk("HP 물약",3)
	check(world.gold == 199850, "legacy bulk price survives rollback")
	SHOPS.set_enabled(true)
	check(catalog == original_catalog, "source shop lookup never changes game item stats or grades")
	world._save_game(true)
	var saved: Dictionary = _snapshot()
	world.item_instances.clear()
	world.gold = 1
	world._load_game(true)
	check(world.gold == int(saved.gold), "wallet survives save/load")
	check(world.inventory.size() == saved.inventory.size(), "inventory keys survive save/load")
	for item_name: String in saved.inventory:
		check(int(world.inventory.get(item_name,-1)) == int(saved.inventory[item_name]), "inventory count survives save/load " + item_name)
	for key: Variant in saved.instances:
		check(world.item_instances.has(key), "physical ID survives save/load " + str(key))
		if world.item_instances.has(key):
			check(int(world.item_instances[key].level) == int(saved.instances[key].level), "enhancement survives save/load " + str(key))
	check(str(world.equipped_items.weapon.get("instance_id","")) == old_id, "equipped physical ID survives save/load")
	_check_general_stock(original_stock, "save/load")
	print("L1J_REVIEWED_SHOP_OK " if failures.is_empty() else "L1J_REVIEWED_SHOP_FAIL ", JSON.stringify({"checks":checks,"profiles":profiles.size(),"real_hud_purchases":purchases,"distinct_game_items":1,"legacy_goods":EXPECTED_LEGACY_GOODS.size(),"general_goods":original_stock.size(),"failures":failures,"engine":Engine.get_version_info().string}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
