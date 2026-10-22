extends RefCounted

# Read-only stock expansion from the same local data used by TwilightWorld.
# These are TWILIGHT prices, not official Lineage M shop prices.
const RULES = preload("res://scripts/consumable_rules.gd")
const PACK_ITEMS = preload("res://scripts/card_pack_items.gd")
const BUYBACK = preload("res://scripts/shop/buyback_rates.gd")
const SOURCE_PATHS: Array[String] = ["res://data/catalog_v19.json", "res://data/game_db_v17.json"]
const KIND_PRICES: Dictionary = {
	"regen":1500, "instant_mp":8000, "food":2500, "buff":3000,
	"return":100, "teleport":300, "equipment_bless":250000,
	"element":30000, "element_change":60000, "element_reset":5000,
	"elixir":1000000, "half_elixir":500000
}

static func records() -> Array:
	var by_name: Dictionary = {}
	# The catalog wins name collisions with base items, matching world.gd.
	for path: String in SOURCE_PATHS:
		if not FileAccess.file_exists(path):
			push_error("SHOP_STOCK: missing catalog " + path)
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary) or not ((parsed as Dictionary).get("아이템") is Array):
			push_error("SHOP_STOCK: invalid item catalog " + path)
			continue
		for raw: Variant in (parsed as Dictionary)["아이템"]:
			if not (raw is Dictionary): continue
			var record: Dictionary = raw as Dictionary
			var item_name: String = str(record.get("name", ""))
			if not item_name.is_empty() and not by_name.has(item_name):
				by_name[item_name] = record.duplicate(true)
	for rule: Dictionary in RULES.records():
		var item_name: String = str(rule["name"])
		var record: Dictionary = (by_name.get(item_name, {}) as Dictionary).duplicate(true)
		record.merge(rule, true)
		by_name[item_name] = record
	# These are already implemented inventory items, not new use definitions.
	for item_name: String in PACK_ITEMS.PACKS:
		by_name[item_name] = {"name":item_name, "slot":"consumable", "type":"뽑기권", "grade":"희귀"}
	for item_name: String in ["화살", "총알"]:
		by_name[item_name] = {"name":item_name, "slot":"consumable", "type":"탄약", "grade":"일반"}
	return by_name.values()

static func category_for(record: Dictionary) -> String:
	var item_name: String = str(record.get("name", ""))
	if item_name.is_empty() or RULES.is_removed_item(item_name): return ""
	if bool(record.get("crafting_material", false)) or bool(record.get("crafting_scroll", false)) or bool(record.get("quest_item", false)): return ""
	var slot: String = str(record.get("slot", ""))
	if slot not in ["", "consumable"]: return ""
	if str(record.get("type", "")) in ["제작재료", "재료", "퀘스트", "스킬북", "마법서"]: return ""
	var spec: Dictionary = RULES.definition(item_name)
	var kind: String = str(spec.get("kind", ""))
	# Never create an engraved/alias route around the exact-name monthly gate.
	if kind == "ain_orb": return "소모품" if item_name == "드래곤의 용옥" else ""
	if kind in ["equipment_bless", "element", "element_change", "element_reset"]: return "강화 주문서"
	if kind in ["regen", "instant_mp"]: return "물약"
	if not spec.is_empty() or PACK_ITEMS.is_pack(item_name) or item_name in ["화살", "총알"]: return "소모품"
	if slot == "consumable" and int(record.get("heal", 0)) > 0: return "물약"
	# Existing duration-based consumables are handled by world.gd. Equipment,
	# ingredients and unimplemented instant-use descriptions are not stocked.
	if slot == "consumable" and _has_duration(str(record.get("desc", ""))):
		return "물약" if "물약" in item_name or "회복제" in item_name else "소모품"
	return ""

static func _has_duration(description: String) -> bool:
	for segment: String in description.split("·"):
		var text: String = segment.strip_edges()
		if not text.begins_with("지속 시간"): continue
		var digits: String = ""
		var tail: String = text.trim_prefix("지속 시간").strip_edges()
		for index: int in range(tail.length()):
			var ch: String = tail.substr(index, 1)
			if ch >= "0" and ch <= "9": digits += ch
			elif not digits.is_empty(): break
		return int(digits) > 0
	return false

static func new_price(record: Dictionary) -> int:
	var item_name: String = str(record.get("name", ""))
	var spec: Dictionary = RULES.definition(item_name)
	var price: int = int(KIND_PRICES.get(str(spec.get("kind", "")), 3000))
	if PACK_ITEMS.is_pack(item_name):
		price = 100000 * int(PACK_ITEMS.definition(item_name).get("count", 1))
	elif item_name in ["화살", "총알"]:
		price = 100
	elif int(record.get("heal", 0)) > 0:
		price = maxi(50, int(record["heal"]) * 2)
	# Prevent a new buy -> sell profit loop without changing legacy prices or
	# buyback policy. The old shop rows are never repriced by this function.
	var buyback: int = int(BUYBACK.GRADE_BUYBACK.get(str(record.get("grade", "일반")), 0))
	return maxi(price, buyback * 2)

static func build(legacy: Array) -> Array:
	return build_from_records(legacy, records())

static func build_from_records(legacy: Array, source: Array) -> Array:
	var result: Array = legacy.duplicate(true)
	var seen: Dictionary = {}
	for entry: Array in result: seen[str(entry[0])] = true
	var additions: Dictionary = {}
	for raw: Variant in source:
		if not (raw is Dictionary): continue
		var record: Dictionary = raw as Dictionary
		var item_name: String = str(record.get("name", ""))
		if seen.has(item_name) or additions.has(item_name): continue
		var category: String = category_for(record)
		if not category.is_empty(): additions[item_name] = [item_name, new_price(record), category]
	var names: Array = additions.keys()
	names.sort()
	for item_name: String in names: result.append(additions[item_name])
	return result
