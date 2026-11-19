extends RefCounted
## The original 523 제작 window's 메인 / 한정 / 서버한정 tabs over the existing
## recipe registry (world.crafting.recipes; a 523 recipe keeps its
## source_craft_id). Nothing here crafts, limits or grants: the recipes and
## their rules stay with their owners (patch523_rules_projection: other-server
## rows are already left out, count / period limits follow the user policy).
##
## 한정 (LimitedAccount) and 서버한정 (LimitedServer) are ItemCraftView
## MainCategoryID 41 / 51 (ItemCraftMainCategory). 메인 is the original
## recommendation list (ItemCraftRecommend, IsEnabled rows, Priority order):
##   Fixed (1)                - always;
##   CharacterClass (31)      - Param1 = the character's ClassID;
##   EquippedItemGrade (41)   - an equipped item in EquipSlot Param1
##                              (ItemEquipSlot) has GradeID Param2, and
##                              Param3 is the character's ClassID (0 = any);
##   InventoryItemAmount (51) - the bag holds Param2 of ItemClass Param1.
## CraftHistory / CraftFailHistory (11 / 21) have no rows in 523.
const COMMON_SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const BASE508 = preload("res://scripts/lineagem_base508.gd")
const LIMITED_ACCOUNT: int = 41
const LIMITED_SERVER: int = 51
const FIXED: int = 1
const CHARACTER_CLASS: int = 31
const EQUIPPED_GRADE: int = 41
const INVENTORY_AMOUNT: int = 51

class CommonReader extends RefCounted:
	func rows(table: String) -> Array:
		return COMMON_SOURCE.rows(table)
	func row(table: String, id: int) -> Dictionary:
		return COMMON_SOURCE.row(table, id)
	func related(table: String, field: String, id: int) -> Array:
		return COMMON_SOURCE.related(table, field, id)

static func _reader(reader: RefCounted) -> RefCounted:
	return reader if reader != null else CommonReader.new()

## source_craft_id -> registry recipe id, in registry order.
static func registry_ids(registry: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	for raw: Variant in registry:
		var value: Variant = (registry[raw] as Dictionary).get("source_craft_id") if registry[raw] is Dictionary else null
		if (value is int or value is float) and int(value) > 0 and not ids.has(int(value)): ids[int(value)] = str(raw)
	return ids

## Registry recipes whose ItemCraftView MainCategoryID is `main_category`.
static func by_main_category(registry: Dictionary, main_category: int, reader: RefCounted = null) -> Array[String]:
	var source: RefCounted = _reader(reader)
	var found: Array[String] = []
	var ids: Dictionary = registry_ids(registry)
	for craft_id: int in ids:
		var views: Array = source.related("ItemCraftView", "ItemCraftID", craft_id)
		if not views.is_empty() and int(views[0].get("MainCategoryID", 0)) == main_category: found.append(str(ids[craft_id]))
	return found

## The character facts the 메인 rules read: {class_id, equipped: [[slot, grade]], held: {item_class_id: amount}}.
static func context(world: Node, reader: RefCounted = null) -> Dictionary:
	var source: RefCounted = _reader(reader)
	var class_id: int = BASE508.source_class_id(str(world.get("job_class")))
	var equipped: Array = []
	for slot: Variant in world.equipped_items:
		var value: Variant = world.equipped_items[slot]
		if not value is Dictionary: continue
		var entry: Variant = world.item_instances.get(str(value.get("instance_id", "")))
		if not entry is Dictionary or not entry.get("record") is Dictionary: continue
		var item_id: int = int(entry.record.get("source_item_class_id", 0))
		if item_id <= 0: continue
		var grade: int = int(source.row("ItemClass", item_id).get("GradeID", -1))
		for equip: Dictionary in source.related("ItemEquipSlot", "ItemClassID", item_id): equipped.append([int(equip.EquipSlotID), grade])
	var held: Dictionary = {}
	for uid: Variant in world.item_instances:
		var entry: Variant = world.item_instances[uid]
		if not entry is Dictionary or not entry.get("record") is Dictionary: continue
		var item_id: int = int(entry.record.get("source_item_class_id", 0))
		if item_id <= 0: continue
		var amount: int = int(entry.get(STACK.QUANTITY, 1)) if entry.has(STACK.RECEIPT) else 1
		held[item_id] = int(held.get(item_id, 0)) + amount
	return {"class_id":class_id,"equipped":equipped,"held":held}

static func recommendation_applies(row: Dictionary, facts: Dictionary) -> bool:
	if row.get("IsEnabled") != true: return false
	var p1: int = int(row.get("Param1Value", 0))
	var p2: int = int(row.get("Param2Value", 0))
	var p3: int = int(row.get("Param3Value", 0))
	match int(row.get("ItemCraftRecommendTypeID", 0)):
		FIXED: return true
		CHARACTER_CLASS: return p1 == int(facts.class_id)
		EQUIPPED_GRADE:
			if p3 != 0 and p3 != int(facts.class_id): return false
			for pair: Array in facts.equipped:
				if int(pair[0]) == p1 and int(pair[1]) == p2: return true
			return false
		INVENTORY_AMOUNT: return int(facts.held.get(p1, 0)) >= maxi(1, p2)
	return false

## 메인: registry recipes the original recommends for this character now.
static func recommended(registry: Dictionary, facts: Dictionary, reader: RefCounted = null) -> Array[String]:
	var source: RefCounted = _reader(reader)
	var ids: Dictionary = registry_ids(registry)
	var picked: Array = []
	var index: int = 0
	for row: Dictionary in source.rows("ItemCraftRecommend"):
		index += 1
		var craft_id: int = int(row.get("ItemCraftID", 0))
		if not ids.has(craft_id) or not recommendation_applies(row, facts): continue
		picked.append([int(row.get("Priority", 0)), index, str(ids[craft_id])])
	picked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var found: Array[String] = []
	for entry: Array in picked:
		if not found.has(entry[2]): found.append(entry[2])
	return found
