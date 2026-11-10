extends RefCounted
## A new character's starting items, from the original 523 items only
## (user decision 2026-11-10: no pre-November items). Each entry goes through
## the ordinary 523 grant path (patch523_item_inventory.stage), so every stack
## is a physical, receipted original item. Items whose use is not connected
## yet (return/teleport scrolls, enchant scrolls, food) are not granted.
const PATCH523_ITEMS = preload("res://scripts/loot/patch523_item_inventory.gd")
const ORIGIN := {"kind":"twilight_starter_kit","schema":1}
const GRANTS: Array[Dictionary] = [
	{"item_class_id":233, "amount":100}, # 체력 회복제 (각인)
	{"item_class_id":385, "amount":10},  # 마나 회복 물약 (각인)
	{"item_class_id":389, "amount":500}, # 화살 (각인)
	{"item_class_id":75174, "amount":300}, # 은 탄환 (각인)
	{"item_class_id":702, "amount":1},   # 장검
	{"item_class_id":65291, "amount":5}, # 축복 부여 주문서 (각인)
]
## Default item quickslots (after the class skills).
const QUICKSLOT_ITEMS: Array[int] = [233]

static func grants() -> Array:
	var result: Array = []
	for grant: Dictionary in GRANTS:
		result.append({"item_class_id":int(grant.item_class_id),"amount":int(grant.amount),"bless_raw":1,"enchant":0})
	return result

## Stages the kit on `world` (no save): {"ok", "overrides"|"error"}.
## Without the installed 523 pack nothing is granted.
static func stage(world: Node) -> Dictionary:
	return PATCH523_ITEMS.stage(world, grants(), ORIGIN)

## Inventory names of the default quickslot items that `world` holds.
static func quickslot_names(world: Node) -> Array[String]:
	var names: Array[String] = []
	for id: int in QUICKSLOT_ITEMS:
		var record: Dictionary = world._catalog_item_from_source_id("m523:item:%d" % id)
		var name: String = str(record.get("name", ""))
		if not name.is_empty() and int(world.inventory.get(name, 0)) > 0: names.append(name)
	return names
