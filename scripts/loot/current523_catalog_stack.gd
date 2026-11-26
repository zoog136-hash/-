extends RefCounted
## Old catalog and cash-package suppliers wrote a quantity under their own
## inventory key. Resolve that exact registered key before using a 523 rule.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const LABEL = preload("res://scripts/ui/source523_item_identity.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ENCHANT = preload("res://scripts/crafting/patch523_enhance_source_book.gd")
const RETIRED = preload("res://scripts/loot/retired_enhancement_items523.gd")
static var _name_generation := -1
static var _stock_ids: Dictionary = {}

## Old suppliers keyed balances by either Korean descriptor. Two ItemClasses
## can share both the visible title and the icon. Neither identifies a debit.
static func unique_stock_name(key: String, id: int) -> bool:
	var generation := SOURCE.cache_generation()
	if _name_generation != generation:
		_stock_ids.clear()
		_name_generation = generation
		var ids: Variant = SOURCE.column("ItemClass","ID")
		var tests: Variant = SOURCE.column("ItemClass","TestItem")
		var descriptions: Variant = SOURCE.column("DescData_Korean","Description")
		var text_ids: Variant = SOURCE.column("DescData_Korean","ID")
		if tests.size() != ids.size() or descriptions.size() != text_ids.size(): return false
		# DescData_Korean in the pinned archive is ordered by unique ID. Use
		# its compact columns without allocating a row for each descriptor.
		for field: String in ["DescID","IdentifiedDescID"]:
			var references: Variant = SOURCE.column("ItemClass",field)
			if references.size() != ids.size(): _stock_ids.clear(); return false
			for i: int in ids.size():
				if tests[i] != false or references[i] <= 0: continue
				var pos: int = text_ids.bsearch(references[i])
				if pos >= text_ids.size() or text_ids[pos] != references[i]: continue
				var name: String = str(descriptions[pos]).strip_edges()
				var owner: int = int(ids[i])
				_stock_ids[name] = owner if _stock_ids.get(name,owner) == owner else -1
	return _stock_ids.get(key,-1) == id and id > 0

static func native_record(world: Node, old: Dictionary) -> Dictionary:
	var source: Variant = old.get("source")
	if source not in ["inven","twilight-cash-package-item"] or old.get("source_m_native_item",false): return {}
	if not is_instance_valid(world) or not world.has_method("_catalog_item_from_source_id"): return {}
	var key: String = str(old.get("name",""))
	var sid: String = str(old.get("sourceId",""))
	var digits: String = sid.trim_prefix("cash523:") if source == "twilight-cash-package-item" else sid
	if not digits.is_valid_int() or int(digits) <= 0 or digits != str(int(digits)): return {}
	var id: int = int(digits)
	if RETIRED.item(id) or not world.get("catalog_item_variant_count") is Dictionary or int(world.catalog_item_variant_count.get(key,0)) != 1: return {}
	var registered: Dictionary = world._catalog_item_from_source_id(sid)
	if registered.get("name") != key or registered.get("source") != source or registered.get("slot") != old.get("slot"): return {}
	if source == "inven":
		var url := "https://lineagem.inven.co.kr/db/item/" + digits
		if registered.get("sourceUrl") != url or old.get("sourceUrl") != url: return {}
	else:
		if sid != "cash523:"+digits or registered.get("source_item_class_id") != id or old.get("source_item_class_id") != id: return {}
	var label: String = LABEL.original_name(id)
	if label.is_empty() or (key != label and not (source == "twilight-cash-package-item" and key == label+" · 상점#"+digits)): return {}
	var native: Dictionary = world._catalog_item_from_source_id("m523:item:"+digits)
	if native.get("source_item_class_id") != id or native.get("source_bless_raw") != 1 or not native.get("source_m_native_item",false): return {}
	return native if not D.item_definition(native).is_empty() else {}

static func action_record(world: Node, old: Dictionary) -> Dictionary:
	if old.get("slot") != "material" or old.get("source_bless_raw",1) != 1 or old.get("bless_state","normal") not in ["normal",""]: return {}
	var native: Dictionary = native_record(world,old)
	if native.is_empty(): return {}
	var owner: Script = load("res://scripts/loot/current523_native_stack.gd")
	var kind: String = str(owner.profile(native).get("kind",""))
	if kind not in ["bag","teleport","teleport_location"] and not ENCHANT.declares_scroll(native): return {}
	var id: int = int(native.source_item_class_id)
	if not str(old.name).ends_with(" · 상점#"+str(id)) and not unique_stock_name(old.name,id): return {}
	# A name balance does not carry a per-instance acquisition timestamp.
	if not world.get("item_life523") is RefCounted or world.item_life523.has_life_row(native): return {}
	return native

static func holds_plain(world: Node, key: String) -> bool:
	var amount: Variant = world.inventory.get(key,0)
	if not D._source_integer(amount) or int(amount) < 1 or int(amount) > 9007199254740991: return false
	for entry: Variant in world.item_instances.values():
		if entry is Dictionary and entry.get("name") == key: return false
	return true
