extends SceneTree

const SHOP = preload("res://scripts/shop/shop_catalog.gd")
const SHOP_UI = preload("res://scripts/ui/renewal_shop.gd")
const PACK_ITEMS = preload("res://scripts/card_pack_items.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SHOP_CONSUMABLES_GAMEPLAY_FAIL: " + detail)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.set("source_save_blocked", true)
	var inventory: Dictionary = world.get("inventory") as Dictionary
	inventory.clear()
	world.set("gold", 1000000000)
	# This is the live catalog used by inventory/detail/quickslot, not merely
	# the separate NPC shop listing. It must carry all six physical item icons.
	for item_name: String in PACK_ITEMS.PACKS:
		var inventory_record: Dictionary = world.call("_find_catalog_item_record", item_name)
		var expected: Dictionary = PACK_ITEMS.inventory_record(item_name)
		check(inventory_record.get("image_path", "") == expected.get("image_path", ""), "runtime icon registered: " + item_name)
		check(inventory_record.get("slot", "") == "consumable", "pack displays under consumables: " + item_name)
		var icon: Texture2D = RESOLVER.texture(inventory_record, item_name)
		check(icon != null and not icon.has_meta("item_family"), "runtime renders actual pack image: " + item_name)
	for item_name: String in ["마나 회복 물약", "힘센 한우 스테이크", "귀환 주문서", "화령의 무기 강화 주문서", "엘릭서", "최상급 변신 뽑기권 11회 팩", "화살", "왕실 회복 물약"]:
		var before_gold: int = int(world.get("gold"))
		var before_count: int = int(inventory.get(item_name, 0))
		world.call("_buy_shop_bulk", item_name, 2)
		check(int(inventory.get(item_name, 0)) == before_count + 2, "real inventory purchase: " + item_name)
		check(int(world.get("gold")) == before_gold - SHOP.price_for(item_name) * 2, "real authoritative charge: " + item_name)
	var before_gold: int = int(world.get("gold"))
	world.call("_buy_shop_item", "마녀의 마력 회복제", 1)
	check(int(world.get("gold")) == before_gold - SHOP.price_for("마녀의 마력 회복제"), "forged UI price ignored")
	for item_name: String in ["진명황의 집행검", "철 광석", "해독제", "드래곤의 용옥 (각인)"]:
		before_gold = int(world.get("gold"))
		var snapshot: Dictionary = inventory.duplicate(true)
		world.call("_buy_shop_bulk", item_name, 1)
		check(int(world.get("gold")) == before_gold and inventory == snapshot, "restricted request rejected atomically")
	before_gold = int(world.get("gold"))
	world.call("_buy_shop_bulk", "드래곤의 용옥", 2)
	check(int(world.get("gold")) == before_gold, "orb bulk guard preserved")
	var ain: Object = world.get("ain_service")
	ain.call("register_orb_purchase")
	world.call("_buy_shop_bulk", "드래곤의 용옥", 1)
	check(int(world.get("gold")) == before_gold, "monthly orb guard preserved")
	SHOP_UI.selected_vendor_id = ""
	var panel: Control = SHOP_UI.new()
	root.add_child(panel)
	panel.call("configure", world.get("hud"), true)
	var listing: ItemList = panel.get("listing") as ItemList
	check(listing.item_count == SHOP.GOODS.size(), "NPC shop lists the same authority stock")
	var search: LineEdit = panel.get("search_field") as LineEdit
	search.text = "최상급"
	panel.call("_refresh")
	check(listing.item_count == 6, "all six draw products searchable")
	for row: int in range(listing.item_count):
		check(listing.get_item_icon(row) != null and not listing.get_item_icon(row).has_meta("item_family"), "shop row is an image, not a fallback symbol: " + str(row))
	search.text = "마나 회복 물약"
	panel.call("_refresh")
	check(listing.item_count >= 1, "new potion searchable")
	search.text = ""
	panel.call("_refresh")
	var filter: OptionButton = panel.get("category_filter") as OptionButton
	filter.select(1)
	panel.call("_refresh")
	for entry: Array in panel.get("filtered"):
		check(str(entry[2]) == "물약", "potion filter remains accurate")
	panel.queue_free()
	world.queue_free()
	await process_frame
	if failures == 0: print("SHOP_CONSUMABLES_GAMEPLAY_OK checks=%d" % checks)
	quit(0 if failures == 0 else 1)
