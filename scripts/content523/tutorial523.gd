extends RefCounted
## 사용자 결정 2026-11-16: "튜토리얼 관련은 전부 삭제" (docs/TUTORIAL523_REMOVAL.md).
## Original 523 tutorial content is cut from the game; the original rows and
## resources stay untouched. The sets below are derived from the original
## definition tables (tests/tutorial523_removal_test.gd re-derives them):
##   LAND_IDS   Land rows whose Name contains "[튜토리얼]" (46).
##   QUEST_IDS  QuestView rows whose TeleportTerritoriesID is a Territories
##              row of one of those Lands (108, all Main quests).
##   ITEM_IDS   ItemClass rows whose Name contains "[튜토리얼]" (2) and the
##              "이동 주문서" items that only tutorial quests reward (48).
## A tutorial quest named as a prerequisite counts as done (the class chain's
## class still applies), so each class's first quest after the tutorial is
## its start quest. Characters saved in a tutorial Land move to Giran town
## (start village, 사용자 결정 2026-11-17);
## tutorial items in a save are removed with their amounts recorded.
const MARKER := "[튜토리얼]"
const DECISION := "사용자 결정 2026-11-16 · 튜토리얼 삭제"
const KEY := "tutorial523"
const ADEN_LAND_ID := 4
const START_VILLAGE := preload("res://scripts/maps/current523_start_village.gd")
const RETIRED_ITEMS := preload("res://scripts/loot/retired_enhancement_items523.gd")
const LAND_IDS: Array[int] = [
	12177,43192,43212,43222,43622,43632,43642,43652,44492,44502,44512,44522,44532,44542,46511,46521,46531,46541,46551,
	46561,46571,46581,47041,47051,47061,47071,47081,47091,47101,47141,47974,47984,47994,48004,48014,48024,48034,48044,
	48511,48531,48541,48551,48561,48571,48581,48611]
const QUEST_IDS: Array[int] = [
	73522,73532,73542,73552,73562,73572,73582,73592,73602,73612,73622,73632,73642,73652,73672,74482,74492,74502,74512,
	74682,74692,74702,74712,74722,74732,74742,74752,74762,74772,74782,74792,76731,76741,76751,76761,76781,76791,76801,
	76811,76831,76841,76861,76871,76891,76911,76921,76941,76961,77301,77311,77321,77331,77341,77351,77361,77371,77381,
	78401,78411,78421,78431,78441,78451,78461,78471,78481,78491,78501,78511,78521,78531,78541,78551,78561,79584,79594,
	79604,79614,79624,79634,79644,79654,79664,79674,79684,79694,79704,79714,79724,79734,79744,81711,81721,81731,81741,
	81751,81761,81771,81781,81791,81801,81811,81821,81831,81841,81851,81861,81871]
const ITEM_IDS: Array[int] = [
	6171,139581,113532,113542,113802,123212,123222,123232,123542,124212,124222,138531,138541,138551,138561,138571,138591,
	138601,138611,138621,138631,141203,155701,155711,155721,155731,155741,155761,155771,155781,155791,155801,188454,188464,
	188484,188514,188524,188534,188544,188554,189944,189964,189994,221921,221931,221951,221961,222811,222821,222831]
## Later user decision: only the Dragon Diamond returns. The 39 scrolls
## stay inactive under the exact retirement owner, which keeps old records
## instead of passing their holdings through the old destructive migration.
const RESTORED_ITEM_IDS := {139581:true}
## Last tutorial quest of each class chain -> that chain's class (Class
## prerequisite of the chain's first quest). The quest after it keeps the
## class condition when the tutorial prerequisite is dropped.
const CHAIN_END_CLASS := {73652:5,74792:52,76961:81,78561:7,79744:94,81871:111}
## Class skill books that only the deleted tutorial quests gave and no
## original shop (MerchantGoods) sells: TWILIGHT 근사 — granted once to every
## character of that class (docs/TUTORIAL523_REMOVAL.md).
const CLASS_START_ITEMS := {52:[124882,124892,124902],81:[137831,137841]}

static var _lands: Dictionary = {}
static var _quests: Dictionary = {}
static var _items: Dictionary = {}

static func _lookup(values: Array[int], cache: Dictionary) -> Dictionary:
	if cache.is_empty():
		for id: int in values: cache[id] = true
	return cache

static func land(id: Variant) -> bool:
	return typeof(id) in [TYPE_INT,TYPE_FLOAT] and _lookup(LAND_IDS,_lands).has(int(id))

## A Land declaration (or row) from the original tables or the map pack.
static func land_declaration(declaration: Dictionary) -> bool:
	return land(declaration.get("ID",-1)) or str(declaration.get("Name","")).contains(MARKER)

static func quest(id: Variant) -> bool:
	return typeof(id) in [TYPE_INT,TYPE_FLOAT] and _lookup(QUEST_IDS,_quests).has(int(id))

## "m523:quest:N" (quest service row id) -> N, or -1.
static func quest_row_id(row: Dictionary) -> int:
	var raw: String = str(row.get("id",""))
	if not raw.begins_with("m523:quest:"): return -1
	var tail: String = raw.trim_prefix("m523:quest:")
	return int(tail) if tail.is_valid_int() else -1

static func item(id: Variant) -> bool:
	return typeof(id) in [TYPE_INT,TYPE_FLOAT] and not RESTORED_ITEM_IDS.has(int(id)) and not RETIRED_ITEMS.AUDIT_SCROLL_IDS.has(int(id)) and _lookup(ITEM_IDS,_items).has(int(id))

## The gate result of a quest prerequisite naming a tutorial quest: "" when
## met (it counts as done; the chain's class still applies).
static func prerequisite_gate(quest_id: int, context: Dictionary) -> String:
	var chain_class: int = int(CHAIN_END_CLASS.get(quest_id,0))
	if chain_class > 0 and int(context.get("class_id",-1)) != chain_class: return "직업 조건 미충족"
	return ""

static func _item_id_of_name(name: String) -> int:
	var at: int = name.rfind("원본#")
	if at < 0: return -1
	var tail: String = name.substr(at+3)
	return int(tail) if tail.is_valid_int() else -1

static func _instance_item_id(entry: Variant) -> int:
	if not entry is Dictionary: return -1
	var record: Variant = entry.get("record",{})
	if record is Dictionary and typeof(record.get("source_item_class_id")) in [TYPE_INT,TYPE_FLOAT]: return int(record.source_item_class_id)
	for raw: Variant in [entry.get("sourceId",""), record.get("sourceId","") if record is Dictionary else ""]:
		var text: String = str(raw)
		if text.begins_with("m523:item:") and text.trim_prefix("m523:item:").is_valid_int(): return int(text.trim_prefix("m523:item:"))
	return _item_id_of_name(str(entry.get("name","")))

## True when a parsed save needs migrate_save().
static func needed(data: Dictionary) -> bool:
	var cursor: Variant = data.get("character_source_cursor",{})
	if cursor is Dictionary and land(cursor.get("native_land_id",-1)): return true
	var inventory: Variant = data.get("inventory",{})
	if inventory is Dictionary:
		for name: Variant in inventory:
			if item(_item_id_of_name(str(name))): return true
	var instances: Variant = data.get("item_instances",{})
	if instances is Dictionary:
		for entry: Variant in instances.values():
			if item(_instance_item_id(entry)): return true
	return false

## A copy of `data` with the character moved out of a tutorial Land to the
## start village (Giran town, current523_start_village) and tutorial items (stacks and instances; all are scrolls/currency,
## never equipment) removed. What was
## done is recorded under KEY, added to any earlier record.
static func migrate_save(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var record: Dictionary = result.get(KEY,{}).duplicate(true) if result.get(KEY,{}) is Dictionary else {}
	record.decision = DECISION
	var cursor: Variant = result.get("character_source_cursor",{})
	if cursor is Dictionary and land(cursor.get("native_land_id",-1)):
		record.relocated = {"from_native_land_id":int(cursor.native_land_id),"from_source_position":cursor.get("source_position",[]),"to_native_land_id":ADEN_LAND_ID,"to_source_position":START_VILLAGE.source_position(),"to_village":START_VILLAGE.NAME}
		result.character_source_cursor = START_VILLAGE.cursor()
	var removed: Dictionary = record.get("removed_items",{}).duplicate(true) if record.get("removed_items",{}) is Dictionary else {}
	var inventory: Variant = result.get("inventory",{})
	if inventory is Dictionary:
		for name: Variant in inventory.keys():
			var id: int = _item_id_of_name(str(name))
			if not item(id): continue
			var amount: int = int(inventory[name]) if typeof(inventory[name]) in [TYPE_INT,TYPE_FLOAT] else 0
			removed[str(id)] = int(removed.get(str(id),0)) + amount
			inventory.erase(name)
	var instances: Variant = result.get("item_instances",{})
	if instances is Dictionary:
		for key: Variant in instances.keys():
			var id: int = _instance_item_id(instances[key])
			if not item(id): continue
			instances.erase(key)
	if not removed.is_empty(): record.removed_items = removed
	result[KEY] = record
	return result

## Class skill books owed to a character of `class_id` that has not had its
## one-time grant yet: [{item_class_id, amount, bless_raw, enchant}].
static func start_grants(class_id: int, record: Dictionary) -> Array:
	if record.get("start_grant") is Dictionary: return []
	var grants: Array = []
	for id: int in CLASS_START_ITEMS.get(class_id,[]):
		grants.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	return grants

## The previous migration counted quantity in its saved removed_items ledger.
## Restore only that exact quantity, do not invent a starting grant or infer
## anything from names, absent instances, or an unverified ledger value.
static func restored_grants(record: Dictionary) -> Dictionary:
	var removed: Variant=record.get("removed_items")
	var applied: Variant=record.get("restored_items",{})
	if not removed is Dictionary or not applied is Dictionary:return {}
	var grants: Array=[];var published: Dictionary={}
	for id: int in RESTORED_ITEM_IDS:
		var key: String=str(id)
		var before: Variant=removed.get(key,0)
		var after: Variant=applied.get(key,0)
		if not _quantity(before) or not _quantity(after) or int(before)<=int(after):continue
		if grants.is_empty():published=applied.duplicate(true)
		grants.append({"item_class_id":id,"amount":int(before)-int(after),"bless_raw":1,"enchant":0})
		published[key]=int(before)
	return {"grants":grants,"ledger":published} if not grants.is_empty() else {}

static func _quantity(value: Variant) -> bool:
	return value is int and value>=0 and value<=9007199254740991 or value is float and is_finite(value) and value>=0.0 and value<=9007199254740991.0 and value==floorf(value)
