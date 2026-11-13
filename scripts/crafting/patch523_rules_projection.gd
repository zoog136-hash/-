extends RefCounted
## UNVERIFIED: in-memory input port of tools/equipment/build_patch523_rules.py.
## Existing public policies only; no item registration, alias, grant, or save.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const POLICY_PATH = "res://data/crafting/patch523_crafting_policy.json"
const EQUIPMENT_PATH = "res://scripts/crafting/patch523_enchantment_projection.gd"
const TABLES = ["SpecialResistanceType","InvokeOption","InvokeOptionType","BonusApplicationType","AttackType","ItemBlessBonus","Material","Unit","UIUnit","Class","LuckyBagClass","LuckyBagEntityView","LuckyBagEntityType","LuckyBagEntityClassLimit","DescData_Korean","ItemCraftInput","ItemCraftOutputView","ItemCraftView","ItemCraftRestriction","ItemClass","ItemCategory","ItemClassLimit","ItemBonus","Bonus","BonusType","ItemEnchantBonus","ItemEnchantProbabilityGroup","ItemEnchantEquipGroupMapping","ItemEnchantScrollGroup","ItemEnchantScrollGroupMapping","BmItemEnchantProView","ItemEnchantCostView","ItemEnchantProbabilityView","ItemBlessEnchantProbability","DateTimes_Korean","ItemBlessCode","EquipSlotConfig","ItemEquipSlot"]
## Compile-time only helpers (cold bake): packed catalog identities and Bonus
## rows, and the boot progress sub-stages of the compile.
const PACKED = preload("res://scripts/crafting/patch523_packed_records.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
## Tables that are never read as whole row arrays: only the rows a join needs
## are read, by position (see _values/_positions/Keyed). Their row arrays were
## ~3.3 of the ~3.7 million row cells the compile used to hold at once.
const SELECTIVE = ["DescData_Korean","Bonus","ItemClass","ItemBonus","ItemCraftInput","ItemCraftOutputView","ItemCraftRestriction",
	"LuckyBagClass","LuckyBagEntityView","LuckyBagEntityClassLimit","DateTimes_Korean"]
var problem: String = ""
## The original definition reader (tests supply a double with the same API).
var source: Variant = SOURCE
var _tables: Dictionary = {}
var _evidence: Dictionary = {}
var _descriptions: Dictionary = {}
var _items: Keyed = Keyed.new()
var _categories: Dictionary = {}
var _classes: Dictionary = {}
var _limits: Dictionary = {}
var _equip_links: Dictionary = {}
## int ItemClassID -> ItemBonus row positions (table order), and the BonusID
## of every ItemBonus row by position.
var _item_bonuses: Dictionary = {}
var _link_bonus: Variant = []
## Catalog identities: every record lives in _records and is named by its
## handle. sourceId -> [handles], name -> number of catalog records.
var _records = PACKED.new()
var _record_cache: Dictionary = {}
var _supplement: int = 0
var _by_id: Dictionary = {}
var _by_name: Dictionary = {}
var _variants: Dictionary = {}
var _currency_keys: Dictionary = {}
var _host_materials: Dictionary = {}
var _use_conditions: Dictionary = {}
var _policy: Dictionary = {}
var _dates: Keyed = Keyed.new()
var _full_native: bool = false
var _exclusions: Dictionary = {}
## Selected Bonus rows (last row per referenced ID), packed; sorted IDs.
var _bonus_ids := PackedInt64Array()
var _bonus_rows = PACKED.new()
var _bonus_cache: Dictionary = {}
## Items the model holds, in the order the compiler binds them: sourceId ->
## record handle; the Bonus IDs they use (in use order); declared exclusions.
var _plan: Dictionary = {}
var _used: Dictionary = {}
var _excluded: Dictionary = {}
var _enchant: Dictionary = {}
var _category_keys: Dictionary = {}
var _physical_cache: Dictionary = {}
var _equipment: Variant = null
var _stage_name: String = ""
var _stage_started: int = 0

## Last row per int(row.ID) of a table that is not held as rows: positions by
## ID in first-occurrence order (the key order of _index()), rows read one at
## a time. Keys are the same strings _index() used (str(int(row.ID))).
class Keyed extends RefCounted:
	var reader: Variant
	var table: String = ""
	var positions: Dictionary = {}
	var cache: Dictionary = {}
	func has(key: String) -> bool:
		return key.is_valid_int() and str(key.to_int()) == key and positions.has(key.to_int())
	func row(key: String) -> Dictionary:
		if not has(key): return {}
		if cache.has(key): return cache[key]
		if cache.size() >= 1024: cache.clear()
		var value: Dictionary = reader.row_at(table,int(positions[key.to_int()]))
		cache[key] = value
		return value

## A Dictionary-valued part of the model that is produced one entry at a time
## while the model is serialized (stream_round_trip), so its entries never all
## exist at once. make(key) returns the entry, SKIP (no such entry) or FAIL
## (problem set; the stream stops). take(key, parsed entry) returns what the
## parsed model keeps for the key (SKIP: nothing); finish(parsed part) returns
## the parsed part. Without take/finish the parsed part is the whole part.
class Part extends RefCounted:
	var name: String = ""
	var keys: Array = []
	var make: Callable
	var take: Callable
	var finish: Callable
	var count: int = 0
const SKIP := &"twilight.patch523.part.skip"
const FAIL := &"twilight.patch523.part.fail"

static func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	return hash.finish().hex_encode()

## Table numbers arrive as floats (1.0); `1.0 in [1,2]` is false in Godot,
## so membership is compared on whole-number values.
static func _in_ints(value: Variant, allowed: Array) -> bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floorf(float(value)): return false
	for candidate: Variant in allowed:
		if typeof(candidate) in [TYPE_INT,TYPE_FLOAT] and float(candidate) == float(value): return true
	return false

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value))

static func _truthy(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return value != 0
	if value is String or value is Array or value is Dictionary: return not value.is_empty()
	return true

func _declared_exclusion(table: String, row: Dictionary) -> Dictionary:
	var evidence: Dictionary = source.declared_exclusion(table,row)
	if not evidence.is_empty(): _exclusions[table+":"+str(row.get("ID",row.get("ItemCraftID","")))] = evidence
	return evidence

static func _index(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows: result[str(int(row.ID))] = row
	return result

static func _group(rows: Array, field: String) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var key: String = str(int(row[field]))
		if not result.has(key): result[key] = []
		result[key].append(row)
	return result

static func _ids(rows: Array, field: String, distinct: bool = false) -> Array:
	var result: Array = []
	for row: Dictionary in rows:
		var id: int = int(row[field])
		if not distinct or not result.has(id): result.append(id)
	result.sort()
	return result

## Record ID lists come from table JSON (1.0); _ids() yields ints and Array
## equality is type-strict, so integral numbers are compared as ints (#411):
## otherwise no native equipment (slot/class IDs) binds to the rules model.
static func _sorted_ids(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values: result.append(int(value) if typeof(value) == TYPE_FLOAT and _integer(value) else value)
	result.sort(); return result

static func _identity(record: Dictionary) -> String:
	return JSON.stringify([record.get("source"),str(record.get("sourceId")),record.get("name")])

func _description(id: int, fallback: Variant = null) -> Variant:
	if not _descriptions.has(id):
		var matches: Array[Dictionary] = source.related("DescData_Korean","ID",id)
		_descriptions[id] = null if matches.is_empty() else str(matches[-1].get("Description","")).strip_edges()
	return fallback if _descriptions[id] == null else _descriptions[id]

func _read_source() -> bool:
	if source.identity().get("source_sha256") != SOURCE.SOURCE_SHA:
		problem = "보유 원본523 정의 ZIP이 필요합니다"; return false
	for name: String in TABLES:
		var meta: Dictionary = source.table_metadata(name)
		if meta.is_empty(): problem = "제작 원본 메타데이터가 없습니다: "+name; return false
		_evidence[name] = {"sha256":meta.get("sha256"),"bytes":meta.get("bytes"),"rows":meta.get("row_count")}
		# Only support descriptions selected by the original compiler's joins.
		# Bonus (~218,000 rows) is indexed later only for the IDs that
		# ItemBonus/ItemEnchantBonus reference; no other join reads it. The
		# other SELECTIVE tables are read by position where a join needs them.
		var selective: bool = name in SELECTIVE
		_tables[name] = [] if selective else source.rows(name)
		var count: int = source.row_count(name) if selective else (_tables[name] as Array).size()
		if name != "DescData_Korean" and count != int(meta.get("row_count",-1)):
			problem = "제작 원본 표를 읽을 수 없습니다: "+name; return false
	_items = _keyed("ItemClass"); _categories = _index(_tables.ItemCategory)
	_classes = _index(_tables.Class); _dates = _keyed("DateTimes_Korean")
	_limits = _group(_tables.ItemClassLimit,"ItemClassID")
	_equip_links = _group(_tables.ItemEquipSlot,"ItemClassID")
	_item_bonuses = _positions("ItemBonus","ItemClassID")
	_link_bonus = _values("ItemBonus","BonusID")
	return true

## row[field] of every row of `table` in table order: the packed column when
## every row has the field, otherwise read one row at a time (a row without
## the field is the same error the whole-table loop raised).
func _values(table: String, field: String) -> Variant:
	var count: int = source.row_count(table)
	var column: Variant = source.column(table,field)
	if column.size() == count: return column
	var values: Array = []
	for index: int in count: values.append(source.row_at(table,index)[field])
	return values

## _index() of a table without its rows (see Keyed).
func _keyed(table: String) -> Keyed:
	var keyed := Keyed.new()
	keyed.reader = source
	keyed.table = table
	var values: Variant = _values(table,"ID")
	for index: int in values.size(): keyed.positions[int(values[index])] = index
	return keyed

## _group() of a table without its rows: int(row[field]) -> row positions in
## table order; groups in first-occurrence order.
func _positions(table: String, field: String) -> Dictionary:
	var groups: Dictionary = {}
	var values: Variant = _values(table,field)
	for index: int in values.size():
		var id: int = int(values[index])
		if not groups.has(id): groups[id] = []
		(groups[id] as Array).append(index)
	for id: int in groups: groups[id] = PackedInt32Array(groups[id])
	return groups

func _rows(table: String, positions: PackedInt32Array) -> Array:
	var result: Array = []
	for position: int in positions: result.append(source.row_at(table,position))
	return result

## The catalog record of a handle. Shared while cached: callers only read it.
func _rec(handle: int) -> Dictionary:
	if _record_cache.has(handle): return _record_cache[handle]
	if _record_cache.size() >= 4096: _record_cache.clear()
	var value: Dictionary = _records.fetch(handle)
	_record_cache[handle] = value
	return value

func _identity_of(handle: int) -> String:
	return JSON.stringify([_records.field(handle,"source"),str(_records.field(handle,"sourceId")),_records.field(handle,"name")])

func _links(key: String) -> PackedInt32Array:
	return _item_bonuses.get(key.to_int(),PackedInt32Array()) if key.is_valid_int() and str(key.to_int()) == key else PackedInt32Array()

## int(link.BonusID) of the item's ItemBonus rows, in table order.
func _link_bonus_ids(key: String) -> PackedInt64Array:
	var result := PackedInt64Array()
	for position: int in _links(key): result.append(int(_link_bonus[position]))
	return result

func _category_key(key: String) -> String:
	if not _category_keys.has(key): _category_keys[key] = str(int(_items.row(key).CategoryID))
	return _category_keys[key]

func _stage(name: String) -> void:
	if not _stage_name.is_empty(): BOOT_LOG.end(_stage_name,_stage_started)
	_stage_name = name
	if not name.is_empty(): _stage_started = BOOT_LOG.begin(name)

## Handles of the catalog records the compiler binds: the catalog_v19 records
## that are registered (same identity as a binding record), then every
## registered native record that is not one of them. The binding records are
## handles 0.._supplement-1; catalog_v19 records are added as they are.
func _catalog(catalog: Array, binding: Dictionary) -> PackedInt32Array:
	var result := PackedInt32Array()
	if binding.is_empty():
		for record: Variant in catalog: result.append(_records.add(record,false))
		return result
	var contract: Dictionary = binding.get("patch523_crafting_catalog_contract",{})
	_full_native = contract.get("mode") == "full_native_supplement" and contract.get("source_bin_sha256") == "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27" and contract.get("normal_ids") == 30398
	var live: Dictionary = {}
	for handle: int in _supplement: live[_identity_of(handle)] = true
	var initial: Dictionary = {}
	for record: Dictionary in catalog:
		var identity: String = _identity(record)
		if live.has(identity): result.append(_records.add(record,false)); initial[identity] = true
	# Keep duplicates visible, exactly as the compiler's comprehension does.
	for handle: int in _supplement:
		if _records.field(handle,"source") == "lineagem_patch523" and _records.field(handle,"source_m_native_item") == true and not initial.has(_identity_of(handle)): result.append(handle)
	return result

func _bind_catalog(catalog: PackedInt32Array, wallet_records: PackedInt32Array) -> bool:
	for handle: int in catalog:
		var name: String = str(_records.field(handle,"name")) if _records.has_field(handle,"name") else str(_rec(handle).name)
		_by_name[name] = int(_by_name.get(name,0))+1
		# Pre-November inven catalog rows are not bound to original IDs (user
		# decision 2026-11-10): an inven "장검" #702 took the original 523 장검
		# #702's place, so 523 enchant scrolls refused the real 523 sword.
	for handle: int in catalog:
		var value: Variant = _records.field(handle,"source_item_class_id")
		if not _integer(value) or int(value) <= 0: continue
		var record: Dictionary = _rec(handle)
		var key: String = str(int(value))
		var native: Dictionary = _items.row(key)
		if native.is_empty() or record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or record.get("source_m_native_item") != true or record.get("sourceId") != "m523:item:"+key or record.get("source_bless_raw",1) != 1: continue
		if record.get("source_display_name") not in [_description(int(native.DescID)),_description(int(native.IdentifiedDescID))] or record.get("name") != str(record.get("source_display_name"))+" · 원본#"+key: continue
		if record.get("source_test_item") != native.TestItem or record.get("source_is_stackable") != _categories[str(int(native.CategoryID))].IsStackable or record.get("source_level_limit_min") != native.LevelLimitMin or record.get("source_level_limit_max") != native.LevelLimitMax: continue
		if _sorted_ids(record.get("source_class_ids",[])) != _ids(_limits.get(key,[]),"ClassID",true) or _sorted_ids(record.get("source_equip_slot_ids",[])) != _ids(_equip_links.get(key,[]),"EquipSlotID"): continue
		var previous: Array = _by_id.get(key,[])
		if not _full_native and previous.size() == 1 and _by_name[_rec(previous[0]).name] == 1 and not (record.get("source_projection")=="current523_original_typed_game_dto_v1" and record.get("source_definition_archive")==source.identity() and _same_original(record,native)): continue
		if _by_name[record.name] == 1: _by_id[key] = [handle]
	for handle: int in catalog:
		var raw_id: Variant = _records.field(handle,"source_item_class_id",0)
		if not _integer(raw_id): continue
		var key: String = str(int(raw_id))
		var state: Variant = _records.field(handle,"source_bless_raw",1)
		if not _in_ints(state,[2,3]) or _by_id.get(key,[]).size() != 1: continue
		var entry: Dictionary = _rec(handle)
		var base: Dictionary = _rec(_by_id[key][0])
		if not base.get("source_m_native_item",false) or not base.get("source_is_stackable",false) or entry.get("source") != "lineagem_patch523" or entry.get("sourceId") != str(base.sourceId)+":bless:"+str(int(state)) or entry.get("name") != str(base.name)+(" · 축복" if state == 2 else " · 저주"): continue
		var same: bool = true
		for field: String in ["source_snapshot","source_item_class_id","source_display_name","source_test_item","source_is_stackable","source_level_limit_min","source_level_limit_max","source_class_ids","source_equip_slot_ids","slot"]:
			if entry.get(field) != base.get(field): same = false
		if same and _by_name[entry.name] == 1:
			if not _variants.has(key): _variants[key] = {}
			_variants[key][str(int(state))] = handle
	var wallet_names: Dictionary = {}
	for handle: int in wallet_records:
		if _records.field(handle,"slot") == "currency": wallet_names[_rec(handle).name] = true
	for key: String in _policy.get("source_currency_bindings",{}):
		var binding: Dictionary = _policy.source_currency_bindings[key]
		var matches: Array = _by_id.get(key,[])
		if matches.size() == 1 and _rec(matches[0]).get("source_m_native_item") == true and _categories[str(int(_items.row(key).CategoryID))].Name == "Currency" and _rec(matches[0]).get("source_display_name") in binding.source_names and wallet_names.has(binding.inventory_key): _currency_keys[key] = binding.inventory_key
	for id: int in _items.positions:
		var key: String = str(id)
		var item: Dictionary = _items.row(key)
		var class_ids: Array = _ids(_limits.get(key,[]),"ClassID",true)
		var minimum: int = maxi(int(item.LevelLimitMin),int(item.get("MaxLevelLimitMin",0)))
		var maximum: int = 0
		for value: Variant in [item.LevelLimitMax,item.get("MaxLevelLimitMax",0)]:
			if int(value) > 0: maximum = int(value) if maximum == 0 else mini(maximum,int(value))
		if minimum != 0 or maximum != 0 or not class_ids.is_empty():
			var names: Array = []
			for class_id: int in class_ids: names.append(_description(int(_classes.get(str(class_id),{}).get("DescID",0)),str(class_id)))
			_use_conditions[key] = {"schema":"patch523-item-use-v1","source_id":key,"min_level":minimum,"max_level":maximum,"class_ids":class_ids,"class_names":names}
	for key: String in _policy.get("host_material_bindings",{}):
		if not _items.has(key): continue
		if _by_id.get(key,[]).size() == 1 and _rec(_by_id[key][0]).get("source_m_native_item") == true: continue
		var binding: Dictionary = _policy.host_material_bindings[key]
		if not _by_id.get(key,[]).is_empty() or _by_name.has(binding.item): problem = "기존 제작 host binding 정체가 충돌합니다"; return false
		var original: Dictionary = _items.row(key)
		if _description(int(original.DescID)) != binding.item or not _categories[str(int(original.CategoryID))].IsStackable: problem = "기존 제작 host binding의 원본 재료가 다릅니다"; return false
		var record: Dictionary = {"name":binding.item,"source":"twilight_host_binding","sourceId":key,"slot":"consumable","host_kind":binding.kind,"host_amount":binding.amount,"binding_origin":binding.origin}
		_by_id[key] = [_records.add(record,false)]; _by_name[binding.item] = 1; _host_materials[key] = record
	return true

func _native_non_equipment(key: String) -> bool:
	if not _policy.get("native_non_equipment_holding",{}).get("enabled",false) or _by_id.get(key,[]).size() != 1: return false
	var entry: Dictionary = _rec(_by_id[key][0])
	return entry.get("source") == "lineagem_patch523" and entry.get("source_m_native_item") == true and entry.get("slot") in ["material","consumable","currency",""] and entry.get("source_equipment_status") == "no_source_equip_slot" and entry.get("source_equip_slot_ids") == [] and _equip_links.get(key,[]).is_empty()

func _physical(key: String) -> bool:
	# Fixed once the catalog is bound (only recipes ask), so answered once per item.
	if not _physical_cache.has(key): _physical_cache[key] = not _categories[_category_key(key)].IsStackable and not _native_non_equipment(key)
	return _physical_cache[key]

func _record(original: Dictionary) -> Dictionary:
	var key: String = str(int(original.ItemClassID))
	if original.ItemBlessCodeID != 1 and _categories[_category_key(key)].IsStackable:
		var variant: Variant = _variants.get(key,{}).get(str(int(original.ItemBlessCodeID)))
		return _rec(variant) if variant != null else {}
	var matches: Array = _by_id.get(key,[])
	return _rec(matches[0]) if not matches.is_empty() else {}

static func _empty_output(row: Dictionary) -> bool:
	return row.get("ItemCraftOutputTypeID") == 0 and row.get("ItemClassID") == 0 and row.get("Amount") == 0 and row.get("Enchant") == 0 and row.get("ItemBlessCodeID") == 1 and int(row.get("ItemHoningEpithetID",0)) == 0 and int(row.get("ClanItemClassID",0)) == 0 and int(row.get("ClanAmount",0)) == 0

func _calendar_time(row: Dictionary, offset: int) -> int:
	var parts: Dictionary = {"year":int(row.get("Year",0)),"month":int(row.get("Month",0)),"day":int(row.get("Day",0)),"hour":int(row.get("Hour",0)),"minute":int(row.get("Minute",0)),"second":0}
	if parts.year < 1 or parts.year > 9999 or parts.month < 1 or parts.month > 12 or parts.day < 1 or parts.day > 31 or parts.hour < 0 or parts.hour > 23 or parts.minute < 0 or parts.minute > 59: return -1
	var raw: int = Time.get_unix_time_from_datetime_dict(parts)
	var back: Dictionary = Time.get_datetime_dict_from_unix_time(raw)
	for key: String in parts:
		if back.get(key) != parts[key]: return -1
	return raw-offset*60

func _calendar_window(view: Dictionary) -> Variant:
	if view.EffectiveFrom == 1 and view.EffectiveTo == 3: return {}
	var clock: Dictionary = _policy.get("source_calendar_clock",{})
	var offset: Variant = clock.get("utc_offset_minutes")
	if view.CraftTimeTypeID != 1 or not _integer(offset) or int(offset) < -840 or int(offset) > 840 or clock.get("boundary") != "start_inclusive_end_exclusive": return null
	var first: Dictionary = _dates.row(str(int(view.EffectiveFrom)))
	var last: Dictionary = _dates.row(str(int(view.EffectiveTo)))
	if first.is_empty() or last.is_empty(): return null
	var begin: int = _calendar_time(first,int(offset)); var end: int = _calendar_time(last,int(offset))
	if begin < 0 or begin >= end or end > 4102444800: return null
	return {"start_unix":begin,"end_unix":end,"source_start":first,"source_end":last,"utc_offset_minutes":offset,"boundary":clock.boundary,"clock_origin":clock.get("origin","")}

static func _same_result(left: Dictionary, right: Dictionary) -> bool:
	for key: String in ["ItemClassID","Amount","Enchant","ItemBlessCodeID"]:
		if left.get(key) != right.get(key): return false
	return true

static func _result_identity(row: Dictionary) -> String:
	return JSON.stringify([row.ItemClassID,row.Amount,row.Enchant,row.ItemBlessCodeID])

func _item_reason(ins: Array, outs: Array) -> Dictionary:
	for row: Dictionary in ins+outs:
		if _empty_output(row): continue
		var key: String = str(int(row.ItemClassID))
		if row.Amount < 1 or row.Amount > (1000000000 if key == "26" else 100000000) or row.Enchant < 0 or row.Enchant > 21 or not _in_ints(row.ItemBlessCodeID,[1,2]) or int(row.get("ItemHoningEpithetID",0)) != 0: return {"reason":"unresolved_item_state","item_id":row.ItemClassID}
		var item: Dictionary = _items.row(key)
		if item.is_empty(): return {"reason":"unresolved_item_condition","item_id":row.ItemClassID}
		var exclusion: Dictionary = _declared_exclusion("ItemClass",item)
		if not exclusion.is_empty(): return {"reason":"source_declared_exclusion","item_id":row.ItemClassID,"source_exclusion":exclusion}
		var category: Dictionary = _categories[str(int(item.CategoryID))]
		var invalid_classes: bool = false
		for link: Dictionary in _limits.get(key,[]):
			if int(link.ClassID) <= 0 or not _classes.has(str(int(link.ClassID))): invalid_classes = true
		var allowance: Dictionary = _policy.get("nonactivating_material_class_references",{}).get(key,{})
		var source_input: bool = ins.has(row) and category.get("IsStackable") == true and category.get("IsActivatable") == false and _links(key).is_empty() and allowance.get("scope") == "source_input_only" and _ids(_limits.get(key,[]),"ClassID",true) == allowance.get("class_ids")
		if item.TestItem or _truthy(item.ServiceRegionCode) or item.LevelLimitMin < 0 or item.LevelLimitMin > 1000 or item.LevelLimitMax < 0 or item.LevelLimitMax > 1000 or (item.LevelLimitMax != 0 and item.LevelLimitMax < item.LevelLimitMin) or (invalid_classes and not source_input): return {"reason":"unresolved_item_condition","item_id":row.ItemClassID}
		if key == "26":
			if row.Enchant != 0 or row.ItemBlessCodeID != 1 or _description(int(item.DescID)) != "아데나": return {"reason":"unsupported_currency_state","item_id":row.ItemClassID}
			continue
		var matches: Array = _by_id.get(key,[])
		if matches.size() != 1 or _by_name[_rec(matches[0]).name] != 1: return {"reason":"missing_or_ambiguous_catalog_identity","item_id":row.ItemClassID}
		if _rec(matches[0]).get("source") == "inven" and _rec(matches[0]).name not in [_description(int(item.DescID)),_description(int(item.IdentifiedDescID))]: return {"reason":"source_identity_name_disagreement","item_id":row.ItemClassID}
		if _native_non_equipment(key) and not category.IsStackable and (row.Enchant != 0 or row.ItemBlessCodeID != 1): return {"reason":"non_equipment_state_unrepresented","item_id":row.ItemClassID}
		var stack: bool = not _physical(key)
		if stack and (row.Enchant != 0 or _record(row).is_empty()): return {"reason":"stack_state_cannot_be_represented","item_id":row.ItemClassID}
		if not stack and _rec(matches[0]).get("slot","") not in ["weapon","helmet","armor","cloak","gloves","boots","shield","gaiters","shirt","belt","ring","earring","necklace","seal","rune","shoulder","insignia","body","offhand","tshirt","bracelet","badge","crystal","catalyst"]: return {"reason":"unmapped_physical_slot","item_id":row.ItemClassID}
	return {}

static func _view_contract(views: Array, outs: Array, complete: bool) -> bool:
	if views.size() == 1: return true
	if not complete: return false
	var displayed: Dictionary = {}; var successes: Dictionary = {}; var success_count: int = 0
	var metadata: Dictionary = views[0].duplicate()
	var display_fields: Array[String] = ["ItemClassID","Amount","Enchant","ItemBlessCodeID","ItemCategoryID","WeaponType","EquipSlot"]
	for field: String in display_fields: metadata.erase(field)
	for row: Dictionary in views:
		displayed[_result_identity(row)] = true
		var other: Dictionary = row.duplicate()
		for field: String in display_fields: other.erase(field)
		if other != metadata: return false
	for row: Dictionary in outs:
		if row.ItemCraftOutputTypeID == 1: successes[_result_identity(row)] = true; success_count += 1
	return displayed.size() == views.size() and views.size() == success_count and displayed == successes

static func _currency_record() -> Dictionary:
	return {"name":"아데나","source":"lineagem_patch523","sourceId":"26","slot":"currency","weight":0}

func _project_material(row: Dictionary, slot: int) -> Dictionary:
	var key: String = str(int(row.ItemClassID))
	var record: Dictionary = _currency_record() if key == "26" else _record(row)
	if record.is_empty(): problem = "기존 제작 재료의 카탈로그 정체가 없습니다"; return {}
	var result: Dictionary = {"item":record.name,"quantity":row.Amount,"source_id":key,
		"level":row.Enchant,"bless_code":row.ItemBlessCodeID,"row_id":row.ID,"slot_index":slot,
		"physical":false if key == "26" else _physical(key),"wallet":key == "26"}
	if _currency_keys.has(key): result.inventory_key = _currency_keys[key]
	return result

func _project_outcome(row: Dictionary) -> Dictionary:
	var label: String = str(_policy.output_type_labels[str(int(row.ItemCraftOutputTypeID))])
	if _empty_output(row):
		var empty: Dictionary = {"item":"지급 없음","source_id":"0","quantity":0,"level":0,"bless_code":1,"physical":false,"empty_result":true,"probability":row.Probability,"label":label}
		if row.get("twilight_missing_failure",false): empty.twilight_missing_failure = true
		return empty
	var key: String = str(int(row.ItemClassID))
	var item: Dictionary = _record(row)
	if item.is_empty(): problem = "기존 제작 결과의 카탈로그 정체가 없습니다"; return {}
	var result: Dictionary = {"item":item.name,"source_id":key,"quantity":row.Amount,"level":row.Enchant,
		"bless_code":row.ItemBlessCodeID,"physical":_physical(key),"probability":row.Probability,"label":label}
	if _currency_keys.has(key): result.inventory_key = _currency_keys[key]
	return result

func _recipe(craft_id: String, views: Array, ins: Array, outs: Array, restrictions: Array) -> Dictionary:
	for pair: Array in [["ItemCraftView",views],["ItemCraftInput",ins],["ItemCraftOutputView",outs]]:
		for row: Dictionary in pair[1]:
			var exclusion: Dictionary = _declared_exclusion(pair[0],row)
			if not exclusion.is_empty(): return {"reason":"source_declared_exclusion","source_exclusion":exclusion}
	var view: Dictionary = views[0]
	var calendar: Variant = _calendar_window(view)
	var total: int = 0; var valid_outs: bool = true
	for row: Dictionary in outs:
		if not _in_ints(row.ItemCraftOutputTypeID,[0,1,2]) or row.Probability <= 0 or row.Probability > 1000000: valid_outs = false
		total += int(row.Probability)
	var complete: bool = bool(_policy.get("allow_complete_source_outcome_contracts",false)) and outs.size() > 1 and valid_outs and total == 1000000
	var missing: Dictionary = _policy.get("missing_failure_contracts",{}).get(craft_id,{})
	var partial: bool = missing.get("enabled") == true and outs.size() == 1 and views.size() == 1 and view.AlwaysSuccess == 0 and outs[0].ItemCraftOutputTypeID == 1 and outs[0].Probability > 0 and outs[0].Probability < 1000000 and outs[0].Probability == missing.get("source_success_weight") and missing.get("consume_materials_on_failure") is bool and missing.get("consume_fee_on_failure") is bool
	var verified_random: bool = false
	for id: Variant in _policy.verified_source_craft_ids:
		if str(int(id)) == craft_id: verified_random = true
	var probabilistic: bool = verified_random or complete or partial
	var execution_outs: Array = outs.duplicate()
	if partial: execution_outs.append({"ItemCraftOutputTypeID":0,"ItemClassID":0,"Amount":0,"Enchant":0,"ItemBlessCodeID":1,"Probability":1000000-int(outs[0].Probability),"twilight_missing_failure":true})
	var constraint: Dictionary = _policy.get("verified_craft_constraints",{}).get(craft_id,{})
	var quota: Dictionary = constraint.get("quota",{})
	var expected: Variant = constraint.get("source_restriction")
	var known_restriction: bool = expected is Dictionary and not expected.is_empty() and restrictions == [expected]
	var primary: Dictionary = {}
	for row: Dictionary in outs:
		if row.ItemCraftOutputTypeID == 1 and _same_result(view,row): primary = row; break
	var reason: String = ""
	if probabilistic and (not _view_contract(views,outs,complete) or primary.is_empty() or outs.is_empty() or not valid_outs or (total != 1000000 and not partial)): reason = "unverified_random_result_contract"
	elif not probabilistic and (views.size() != 1 or view.AlwaysSuccess != 1 or outs.size() != 1): reason = "non_single_guaranteed_result"
	elif not probabilistic and (outs[0].Probability != 1000000 or outs[0].ItemCraftOutputTypeID != 1): reason = "unresolved_probability_or_output_type"
	elif (not restrictions.is_empty() and not known_restriction) or view.ServerLimitSetID != 0 or view.IsCoalitionItem or view.NoRepeat or view.IsBelowLevelLimit or view.LevelLimitValue < 0 or view.LevelLimitValue > 1000: reason = "unresolved_player_or_server_condition"
	elif view.CraftTimeTypeID != 1 or calendar == null: reason = "limited_calendar_or_time_type"
	elif _in_ints(craft_id,_policy.get("delegated_protection_recipe_ids",[])): reason = "delegated_protection_owner"
	elif ins.is_empty(): reason = "candidate_selection_required"
	elif not probabilistic and not _same_result(view,outs[0]): reason = "view_output_disagreement"
	else:
		for row: Dictionary in outs:
			if row.ClanItemClassID != 0 or row.ClanAmount != 0: reason = "clan_output"; break
	if not reason.is_empty(): return {"reason":reason}
	var item_reason: Dictionary = _item_reason(ins,outs)
	if not item_reason.is_empty(): return item_reason
	var out: Dictionary = primary if probabilistic else outs[0]
	var key: String = str(int(out.ItemClassID))
	var result: Dictionary = _currency_record() if key == "26" else _record(out)
	var materials: Array = []; var slots: Array = []; var adena: int = 0
	var input_slots: Dictionary = _group(ins,"SlotIndex")
	for slot: String in input_slots:
		var candidates: Array = []
		var slot_rows: Array = input_slots[slot]
		for row: Dictionary in slot_rows:
			if row.ItemClassID == 26 and slot_rows.size() == 1: adena += int(row.Amount); continue
			candidates.append(_project_material(row,int(slot)))
		if not candidates.is_empty(): slots.append({"slot_index":int(slot),"candidates":candidates}); materials.append(candidates[0])
	if materials.is_empty(): return {"reason":"currency_only_input"}
	var slot_type: String = str(result.get("slot",""))
	var category: String = "장신구" if slot_type in ["ring","earring","seal","necklace","belt","rune","insignia"] else "무기" if slot_type == "weapon" else "재료" if slot_type in ["material","consumable","currency",""] else "방어구"
	var output: Dictionary = {"item":result.name,"quantity":out.Amount,"level":out.Enchant,"bless_code":out.ItemBlessCodeID,"source_id":key,"physical":false if key == "26" else _physical(key),"wallet_currency":key == "26"}
	if _currency_keys.has(key): output.inventory_key = _currency_keys[key]
	var selection: bool = false
	for slot: Dictionary in slots:
		if slot.candidates.size() > 1: selection = true
	var recipe: Dictionary = {"id":"patch523:"+craft_id,"name":"원본523 · "+str(result.name)+" +"+str(int(out.Enchant)),"category":category,
		"source_snapshot":"patch523","source_craft_id":int(craft_id),"result":output,"adena":adena,"materials":materials,"material_slots":slots,"requires_material_selection":selection,"popup_text_id":view.PopupText}
	if view.LevelLimitValue != 0 or known_restriction or not calendar.is_empty():
		var condition: Dictionary = {"schema":"patch523-craft-conditions-v1","min_level":view.LevelLimitValue,"max_level":0,"source_level_fields":{"IsBelowLevelLimit":view.IsBelowLevelLimit,"LevelLimitValue":view.LevelLimitValue}}
		if not calendar.is_empty(): condition.active_window = calendar
		if known_restriction:
			var weekly: bool = quota.get("period_seconds") == 604800 and expected.RefreshUnitID == 71 and expected.isMultiCount == true
			var bounded: bool = quota.get("mode") == "bounded_lifetime" and quota.get("period_seconds") == 0 and expected.ServiceTypeID == 13 and expected.RefreshUnitID == 111 and expected.isMultiCount == false
			if quota.get("limit") != expected.Value or not (weekly or bounded): problem = "기존 제작 quota 정책의 원본 수량·참조가 다릅니다"; return {}
			var projected_quota: Dictionary = quota.duplicate(true); projected_quota.source_restriction = expected
			condition.quota = projected_quota; condition.origin = constraint.origin
		recipe.craft_conditions = condition
	var host: Array = []
	for row: Dictionary in ins:
		if _host_materials.has(str(int(row.ItemClassID))): host.append(_host_materials[str(int(row.ItemClassID))])
	recipe.host_material_bindings = host
	if probabilistic:
		var outcomes: Array = []
		for row: Dictionary in execution_outs: outcomes.append(_project_outcome(row))
		recipe.outcomes = outcomes
		if views.size() > 1: recipe.source_success_view_count = views.size(); recipe.name = "원본523 · "+str(result.name)+" 확률 제작"
		recipe.probability_origin = "원본 확률 · NC 공식 재료/결과 대조" if verified_random else "원본523 완전 결과표 · 개별 공개 표 미대조"
		if partial: recipe.missing_failure_policy = missing; recipe.probability_origin = missing.origin
		recipe.preserve_refund_instance = bool(_policy.preserve_matching_refund_instance)
	return {"recipe":recipe}

## The Bonus rows the item joins read: the last row per ID among the IDs that
## ItemBonus/ItemEnchantBonus reference (the former _index(rows_matching())),
## packed instead of ~100,000 row Dictionaries.
func _prepare_bonuses() -> void:
	var referenced: Dictionary = {}
	var link_ids: Variant = source.column("ItemBonus","BonusID")
	if link_ids.size() == source.row_count("ItemBonus"):
		for value: Variant in link_ids:
			if _integer(value): referenced[int(value)] = true
	else:
		for index: int in source.row_count("ItemBonus"):
			var value: Variant = source.row_at("ItemBonus",index).get("BonusID")
			if _integer(value): referenced[int(value)] = true
	for row: Dictionary in _tables.ItemEnchantBonus:
		if _integer(row.get("BonusID")): referenced[int(row.BonusID)] = true
	_bonus_rows = PACKED.new()
	_bonus_cache.clear()
	var ids: Variant = source.column("Bonus","ID")
	if ids.size() == source.row_count("Bonus"):
		# Same rows as rows_matching(): integer IDs that are referenced.
		var last: Dictionary = {}
		for index: int in ids.size():
			var value: Variant = ids[index]
			if SOURCE._integer(value) and referenced.has(int(value)): last[int(value)] = index
		_bonus_ids = PackedInt64Array(last.keys())
		_bonus_ids.sort()
		for id: int in _bonus_ids: _bonus_rows.add(source.row_at("Bonus",int(last[id])))
		return
	var rows: Dictionary = {}
	for row: Dictionary in source.rows_matching("Bonus","ID",referenced): rows[int(row.ID)] = row
	_bonus_ids = PackedInt64Array(rows.keys())
	_bonus_ids.sort()
	for id: int in _bonus_ids: _bonus_rows.add(rows[id])

## One selected Bonus row by ID string (null when it was not selected). Shared
## while cached: callers only read it.
func bonus(id: String) -> Variant:
	if _bonus_cache.has(id): return _bonus_cache[id]
	var value: Variant = null
	if id.is_valid_int() and str(id.to_int()) == id:
		var position: int = _bonus_ids.bsearch(id.to_int())
		if position < _bonus_ids.size() and _bonus_ids[position] == id.to_int(): value = _bonus_rows.fetch(position)
	if _bonus_cache.size() >= 4096: _bonus_cache.clear()
	_bonus_cache[id] = value
	return value

## The ItemEnchantBonus rows of the item's BonusTypeID 71 bonuses (table order).
func _effects(key: String) -> Array:
	var effects: Array = []
	for bonus_id: int in _link_bonus_ids(key):
		var row: Dictionary = bonus(str(bonus_id))
		if row.BonusTypeID == 71: effects.append_array(_enchant.get(str(int(row.Value)),[]))
	return effects

## Which items the model holds (_plan, in the order the compiler binds them),
## which Bonus IDs they use (_used, in use order: the model's bonus ID list)
## and their declared exclusions. No item entry is built here: _item_entry()
## and _item_runtime() produce one at a time while the model is serialized.
func _plan_items() -> void:
	var inspectable: Dictionary = _by_id.duplicate()
	if _items.has("26") and _description(int(_items.row("26").DescID)) == "아데나": inspectable["26"] = [_records.add(_currency_record(),false)]
	for id: int in _item_bonuses:
		var key: String = str(id)
		if inspectable.has(key) or not _items.has(key): continue
		for bonus_id: int in _link_bonus_ids(key):
			var linked: Variant = bonus(str(bonus_id))
			if not linked is Dictionary: problem = "제작 원본 Bonus 참조가 없습니다: "+str(bonus_id); return
			if _in_ints(linked.BonusTypeID,[2022,8352]):
				var item: Dictionary = _items.row(key)
				inspectable[key] = [_records.add({"name":_description(int(item.DescID),item.Name),"source":"lineagem_patch523","sourceId":key,"slot":"consumable"},false)]
				break
	_enchant = _group(_tables.ItemEnchantBonus,"ItemEnchantBonusGroupID")
	for key: String in inspectable:
		var handles: Array = inspectable[key]
		if not _items.has(key) or handles.size() != 1: continue
		var effects: Array = []
		for bonus_id: int in _link_bonus_ids(key):
			var text: String = str(bonus_id)
			var row: Variant = bonus(text)
			if not row is Dictionary: problem = "제작 원본 Bonus 참조가 없습니다: "+text; return
			_used[text] = true
			if row.BonusTypeID == 71: effects.append_array(_enchant.get(str(int(row.Value)),[]))
		for row: Dictionary in effects: _used[str(int(row.BonusID))] = true
		_plan[key] = int(handles[0])
		var exclusion: Dictionary = _declared_exclusion("ItemClass",_items.row(key))
		if not exclusion.is_empty(): _excluded[key] = exclusion
	# Every used Bonus must be a selected row: the former whole build stopped
	# on a missing one (an engine error); here it is a reported problem.
	for text: String in _used:
		if bonus(text) == null: problem = "제작 원본 Bonus 참조가 없습니다: "+text; return

## One item entry of the model, as the compiler stored it after replacing its
## original rows (item_class/item_bonuses/enchant_effects) by the lazy marker.
func _item_entry(key: String) -> Variant:
	var record: Dictionary = _rec(_plan[key])
	var item: Dictionary = _items.row(key)
	var genuine: bool = record.get("source") == "inven" and record.name in [_description(int(item.DescID)),_description(int(item.IdentifiedDescID))]
	var entry: Dictionary = {"catalog_record":record,"use_conditions":_use_conditions.get(key,{}) if genuine or record.get("source_m_native_item",false) else {}}
	if _excluded.has(key): entry.source_exclusion = _excluded[key]
	if _variants.has(key):
		var variants: Dictionary = {}
		for state: String in _variants[key]: variants[state] = _rec(_variants[key][state])
		entry.stack_variants = variants
	if _currency_keys.has(key): entry.currency_inventory_key = _currency_keys[key]
	var references: Dictionary = _policy.get("nonactivating_material_class_references",{})
	if references.has(key) and _categories[str(int(item.CategoryID))].get("IsActivatable") == false and _links(key).is_empty(): entry.craft_material_only_class_references = references[key]
	# item_class/item_bonuses/enchant_effects are verbatim original rows; the
	# model keeps a lazy marker and patch523_rules.item_entry() reads the same
	# rows back from the shared reader (source_fields) instead of ~0.6 GB of copies.
	entry["twilight_source_lazy"] = true
	return entry

## The equipment runtime of one item: SKIP when it has none, FAIL (problem
## set) when its rows are unusable.
func _item_runtime(key: String) -> Variant:
	if _excluded.has(key): return SKIP
	var item: Dictionary = _items.row(key)
	if item.get("TestItem") == true: return SKIP
	var value: Variant = _equipment.item_runtime({"catalog_record":_rec(_plan[key]),"item_class":item,"enchant_effects":_effects(key)},self)
	if not str(_equipment.problem).is_empty():
		problem = str(_equipment.problem)
		return FAIL
	return SKIP if value == null else value

func _boxes() -> Dictionary:
	var result: Dictionary = {}
	var classes: Keyed = _keyed("LuckyBagClass")
	var types: Dictionary = _index(_tables.LuckyBagEntityType)
	var limits: Dictionary = {}
	var limited: Variant = _values("LuckyBagEntityClassLimit","LuckyBagEntityID")
	for index: int in limited.size(): limits[int(limited[index])] = true
	var entities: Dictionary = _positions("LuckyBagEntityView","LuckyBagClassID")
	for target: Array in [[30701,12741,30671],[130611,22871,130551]]:
		var rewards: Array = _rows("LuckyBagEntityView",entities.get(int(target[1]),PackedInt32Array()))
		if rewards.is_empty(): continue
		var expected: Dictionary = {str(target[2])+":1":true,"320802:8":true}
		var found: Dictionary = {}
		var supported: bool = types.get("1",{}).get("Name") == "IsGiven" and classes.has(str(target[1])) and rewards.size() == 2
		for row: Dictionary in rewards:
			found[str(int(row.ItemClassID))+":"+str(int(row.ItemAmount))] = true
			if row.LuckyBagEntityTypeID != 1 or row.Probability != 10000000 or row.ItemBlessCodeID != 1 or row.ItemEnchant != 0 or row.LimitClass != 10000 or limits.has(int(row.ID)): supported = false
		if not supported or found != expected: problem = "기존 확정 상자의 원본 계약이 다릅니다"; return {}
		result[str(target[0])] = {"bag_class":classes.row(str(target[1])),"rewards":rewards}
	return result

## The registered catalog inputs exactly as JSON.parse_string(JSON.stringify(
## {"아이템":items,"patch523_crafting_catalog_contract":contract},"",true,true))
## would return them, plus the SHA256 of those JSON bytes. Each item is
## serialized and parsed on its own, so the whole document text (hundreds of MB
## as a Godot String with every native item registered) is never built.
## Registered native records are compiled from these fields only. The rules
## model keeps this slim identity (marked twilight_binding_slim) instead of a
## copy of every native record; patch523_rules.record() returns the live
## catalog record for it. Non-native binding records only identify registered
## names and wallets; their full records come from catalog_v19.
const BINDING_FIELDS: Array[String] = ["name","source","sourceId","slot","grade","weight","source_snapshot",
	"source_item_class_id","source_m_native_item","source_bless_raw","source_display_name","source_test_item",
	"source_is_stackable","source_level_limit_min","source_level_limit_max","source_class_ids","source_equip_slot_ids",
	"source_projection","source_definition_archive","source_original_item","source_equipment_status"]

static func slim_binding_record(record: Variant) -> Variant:
	if not record is Dictionary: return record
	var result: Dictionary = {}
	for field: String in BINDING_FIELDS:
		if (record as Dictionary).has(field): result[field] = record[field]
	# The compiler only compares the full original row with the definition
	# row; that comparison is kept as the digest of the row's JSON round trip.
	if result.has("source_original_item"):
		result["twilight_source_original_item_sha256"] = original_digest(JSON.parse_string(JSON.stringify(result.source_original_item,"",true,true)))
		result.erase("source_original_item")
	if record.get("source") == "lineagem_patch523" and record.get("source_m_native_item") == true: result["twilight_binding_slim"] = true
	return result

const SOURCE_FIELDS: Array[String] = ["item_class","item_bonuses","enchant_effects"]

## The original rows _bound_items() stores for one ItemClass ID: the ItemClass
## row (last row per ID), its ItemBonus rows in table order, and the
## ItemEnchantBonus groups referenced by its BonusTypeID 71 bonuses.
static func source_fields(key: String) -> Dictionary:
	if not key.is_valid_int(): return {}
	var items: Array[Dictionary] = SOURCE.related("ItemClass","ID",int(key))
	if items.is_empty(): return {}
	var links: Array = SOURCE.related("ItemBonus","ItemClassID",int(key))
	var effects: Array = []
	for link: Dictionary in links:
		var bonuses: Array[Dictionary] = SOURCE.related("Bonus","ID",int(link.BonusID))
		if not bonuses.is_empty() and bonuses[-1].BonusTypeID == 71: effects.append_array(SOURCE.related("ItemEnchantBonus","ItemEnchantBonusGroupID",int(bonuses[-1].Value)))
	return {"item_class":items[-1],"item_bonuses":links,"enchant_effects":effects}

static func original_digest(row: Variant) -> String:
	return JSON.stringify(row,"",true,true).sha256_text()

func _same_original(record: Dictionary, native: Dictionary) -> bool:
	if record.has("twilight_source_original_item_sha256"): return record.twilight_source_original_item_sha256 == original_digest(native)
	return record.get("source_original_item") == native

## SHA256 of the binding JSON bytes only (binding_document() without copies).
static func binding_sha256(items: Array, contract: Dictionary) -> String:
	return binding_document(items,contract,false).sha256

## With `packed`, the "아이템" copies are a PACKED store (handle = item index)
## instead of an Array of Dictionaries: the same records, ~1/7 of the memory.
static func binding_document(items: Array, contract: Dictionary, parse: bool = true, packed: bool = false) -> Dictionary:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	var document: Dictionary = {"아이템":items,"patch523_crafting_catalog_contract":contract}
	var keys: Array = document.keys()
	keys.sort()
	var parsed: Dictionary = {}
	var size: int = 0
	for key_index: int in keys.size():
		var key: String = keys[key_index]
		size += _hash_text(hash,("{" if key_index == 0 else ",")+JSON.stringify(key)+":")
		if key != "아이템":
			var text: String = JSON.stringify(document[key],"",true,true)
			size += _hash_text(hash,text)
			if parse: parsed[key] = JSON.parse_string(text)
			continue
		var copies: Variant = PACKED.new() if packed else []
		if parse and not packed: copies.resize(items.size())
		size += _hash_text(hash,"[")
		for index: int in items.size():
			# Registered records are identified by their full form (template
			# fields included), exactly as registration produced them.
			# The real template store can construct the same full record in a
			# single merge; generic/cached/unusable inputs keep full(). The
			# complete JSON hash and parsed slim binding are unchanged.
			var item: Variant = NATIVE_FIELDS._full_for_binding(items[index])
			var text: String = JSON.stringify(item,"",true,true)
			size += _hash_text(hash,("" if index == 0 else ",")+text)
			# Same values a whole-document parse gives for these fields.
			if parse:
				var copy: Variant = JSON.parse_string(JSON.stringify(slim_binding_record(item),"",true,true))
				if packed: copies.add(copy)
				else: copies[index] = copy
		size += _hash_text(hash,"]")
		parsed[key] = copies
	size += _hash_text(hash,"}")
	return {"binding":parsed,"sha256":hash.finish().hex_encode(),"bytes":size}

## JSON.parse_string(JSON.stringify(value,"",true,true)) and the SHA256 input
## of that text, produced container by container to `depth` levels so the
## whole text never exists at once. hash.update() receives the exact bytes.
static func stream_round_trip(value: Variant, hash: HashingContext, depth: int, size: Array) -> Variant:
	if value is Part: return _stream_part(value,hash,depth,size)
	if depth <= 0 or not (value is Dictionary or value is Array) or value.is_empty():
		var text: String = JSON.stringify(value,"",true,true)
		size[0] += _hash_text(hash,text)
		return JSON.parse_string(text)
	if value is Array:
		var copies: Array = []
		copies.resize(value.size())
		size[0] += _hash_text(hash,"[")
		for index: int in value.size():
			if index > 0: size[0] += _hash_text(hash,",")
			copies[index] = stream_round_trip(value[index],hash,depth-1,size)
			if int(size[0]) < 0: return null
		size[0] += _hash_text(hash,"]")
		return copies
	var keys: Array = value.keys()
	keys.sort_custom(_key_order)
	var result: Dictionary = {}
	size[0] += _hash_text(hash,"{")
	for index: int in keys.size():
		var name: String = str(keys[index])
		size[0] += _hash_text(hash,("" if index == 0 else ",")+JSON.stringify(name)+":")
		result[name] = stream_round_trip(value[keys[index]],hash,depth-1,size)
		if int(size[0]) < 0: return null
	size[0] += _hash_text(hash,"}")
	return result

## Same order as Godot's JSON key sort: String and StringName compare as
## text, other types by type first.
static func _key_order(a: Variant, b: Variant) -> bool:
	if (a is String or a is StringName) and (b is String or b is StringName): return str(a) < str(b)
	return typeof(a) < typeof(b) if typeof(a) != typeof(b) else a < b

## A Part is serialized as the Dictionary of its entries (same bytes), one
## entry at a time: made, serialized, parsed, handed to take() and dropped.
## size[0] becomes -1 when an entry fails (the caller reads the problem).
static func _stream_part(part: Part, hash: HashingContext, depth: int, size: Array) -> Variant:
	var keys: Array = part.keys.duplicate()
	keys.sort_custom(_key_order)
	var started: int = BOOT_LOG.begin("rules_stream",{"part":part.name,"keys":keys.size()})
	var result: Dictionary = {}
	part.count = 0
	size[0] += _hash_text(hash,"{")
	for key: Variant in keys:
		var name: String = str(key)
		var made: Variant = part.make.call(name)
		if made is StringName:
			if made == SKIP: continue
			size[0] = -1
			BOOT_LOG.end("rules_stream",started,{"part":part.name,"ok":false})
			return null
		size[0] += _hash_text(hash,("" if part.count == 0 else ",")+JSON.stringify(name)+":")
		var copy: Variant = stream_round_trip(made,hash,depth-1,size)
		made = null
		part.count += 1
		var kept: Variant = part.take.call(name,copy) if part.take.is_valid() else copy
		if not (kept is StringName and kept == SKIP): result[name] = kept
	size[0] += _hash_text(hash,"}")
	BOOT_LOG.end("rules_stream",started,{"part":part.name,"entries":part.count,"kept":result.size()})
	return part.finish.call(result) if part.finish.is_valid() else result

## Drops the source tables and indexes once the model is built.
func release() -> void:
	_tables.clear(); _evidence.clear(); _descriptions.clear(); _by_id.clear(); _by_name.clear(); _variants.clear(); _currency_keys.clear(); _host_materials.clear(); _use_conditions.clear(); _exclusions.clear()
	_items = Keyed.new(); _categories = {}; _classes = {}; _dates = Keyed.new(); _limits = {}; _equip_links = {}; _item_bonuses = {}; _link_bonus = []
	_records = PACKED.new(); _record_cache.clear(); _supplement = 0
	_bonus_ids = PackedInt64Array(); _bonus_rows = PACKED.new(); _bonus_cache.clear()
	_plan = {}; _used = {}; _excluded = {}; _enchant = {}; _category_keys.clear(); _physical_cache.clear(); _equipment = null

static func _hash_text(hash: HashingContext, text: String) -> int:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	hash.update(bytes)
	return bytes.size()

func build(catalog_bytes: PackedByteArray, binding_catalog_bytes: PackedByteArray = PackedByteArray()) -> Dictionary:
	var binding: Dictionary = {}
	if not binding_catalog_bytes.is_empty():
		var parsed: Variant = JSON.parse_string(binding_catalog_bytes.get_string_from_utf8())
		if not parsed is Dictionary or not parsed.get("아이템") is Array: problem = "실제 등록된 제작 카탈로그 정체가 필요합니다"; return {}
		binding = parsed
		var slim = PACKED.new()
		for record: Variant in binding["아이템"]: slim.add(slim_binding_record(record))
		binding["아이템"] = slim
	return build_bound(catalog_bytes,binding,_sha(binding_catalog_bytes) if not binding_catalog_bytes.is_empty() else "")

## Same as build() with the binding catalog already parsed (binding_document()).
func build_bound(catalog_bytes: PackedByteArray, binding: Dictionary, binding_sha256: String) -> Dictionary:
	var result: Dictionary = _build_bound(catalog_bytes,binding,binding_sha256)
	_stage("")
	return result

## The model, with its two per-item parts ("items", "equipment_runtime") as
## Parts: their entries are produced while the model is serialized
## (stream_round_trip), so neither every item entry nor every runtime exists
## at once. Serialized, it is byte for byte the model the whole build made.
## `binding["아이템"]` is an Array of records or a PACKED store of them.
func _build_bound(catalog_bytes: PackedByteArray, binding: Dictionary, binding_sha256: String) -> Dictionary:
	problem = ""
	release()
	_full_native = false
	_stage("rules_tables")
	var original: Variant = JSON.parse_string(catalog_bytes.get_string_from_utf8())
	if not original is Dictionary or not original.get("아이템") is Array: problem = "기존 제작 카탈로그 입력이 필요합니다"; return {}
	var supplied: Variant = binding.get("아이템")
	if not binding.is_empty() and not (supplied is Array or supplied is PACKED): problem = "실제 등록된 제작 카탈로그 정체가 필요합니다"; return {}
	if supplied is PACKED: _records = supplied
	elif supplied is Array:
		for record: Variant in supplied: _records.add(record)
	_supplement = _records.size()
	supplied = null
	var parsed_policy: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
	if not parsed_policy is Dictionary or parsed_policy.is_empty(): problem = "기존 공개 제작 정책을 읽을 수 없습니다"; return {}
	_policy = parsed_policy
	if not _read_source(): return {}
	_stage("rules_bind_catalog")
	var catalog: PackedInt32Array = _catalog(original["아이템"],binding)
	var wallets: PackedInt32Array = catalog if binding.is_empty() else PackedInt32Array(range(_supplement))
	# Unregistered catalog_v19 records are not needed past this point.
	original = null
	if not _bind_catalog(catalog,wallets): return {}
	_stage("rules_recipes")
	var inputs: Dictionary = _positions("ItemCraftInput","ItemCraftID")
	var outputs: Dictionary = _positions("ItemCraftOutputView","ItemCraftID")
	var views: Dictionary = _group(_tables.ItemCraftView,"ItemCraftID")
	var restrictions: Dictionary = _positions("ItemCraftRestriction","ItemCraftID")
	var recipes: Dictionary = {}; var rejected: Dictionary = {}; var admission: Dictionary = {}
	var none := PackedInt32Array()
	for craft_id: String in views:
		# Only this craft's rows are read (its ItemCraftID group, table order).
		var craft: int = craft_id.to_int()
		var compiled: Dictionary = _recipe(craft_id,views[craft_id],_rows("ItemCraftInput",inputs.get(craft,none)),_rows("ItemCraftOutputView",outputs.get(craft,none)),_rows("ItemCraftRestriction",restrictions.get(craft,none)))
		if not problem.is_empty(): return {}
		if compiled.has("recipe"): recipes["patch523:"+craft_id] = compiled.recipe; continue
		var reason: String = str(compiled.get("reason",""))
		rejected[reason] = int(rejected.get(reason,0))+1
		admission[craft_id] = {"reason":reason}
		if compiled.has("source_exclusion"): admission[craft_id].source_exclusion = compiled.source_exclusion
		if reason in ["missing_or_ambiguous_catalog_identity","unresolved_item_condition","unmapped_physical_slot","unresolved_item_state","source_identity_name_disagreement","stack_state_cannot_be_represented"]: admission[craft_id].first_blocking_item_class_id = compiled.get("item_id")
	inputs = {}; outputs = {}; restrictions = {}
	_stage("rules_bonus_index")
	_prepare_bonuses()
	_stage("rules_item_plan")
	_plan_items()
	if not problem.is_empty(): return {}
	var boxes: Dictionary = _boxes()
	if not problem.is_empty(): return {}
	var enchantment: Dictionary = {}
	for table: String in ["ItemEnchantProbabilityGroup","ItemEnchantEquipGroupMapping","ItemEnchantScrollGroup","ItemEnchantScrollGroupMapping","BmItemEnchantProView","ItemEnchantCostView","ItemEnchantProbabilityView","ItemBlessEnchantProbability","ItemBlessCode","EquipSlotConfig","ItemEquipSlot"]: enchantment[table] = _tables[table]
	var items_part := Part.new()
	items_part.name = "items"
	items_part.keys = _plan.keys()
	items_part.make = _item_entry
	var runtime_part := Part.new()
	runtime_part.name = "equipment_runtime"
	runtime_part.keys = _plan.keys()
	runtime_part.make = _item_runtime
	# The grouped craft rows are the verbatim ItemCraftID groups;
	# patch523_rules.recipe_evidence() reads them from the shared reader.
	# The selected Bonus rows are verbatim original rows: the model keeps their
	# IDs and patch523_rules.bonus() reads the row from the shared reader.
	# "source_files" and "source_exclusions" are empty in the accepted model:
	# the compiler's release() always cleared both shared Dictionaries before
	# the model was serialized. Kept so (the model and its digest are unchanged);
	# the exclusions themselves still act through recipe_admission and the items.
	var result: Dictionary = {"schema":"twilight-patch523-equipment-v1","snapshot":"patch523","catalog_sha256":_sha(catalog_bytes),"source_files":{},
		"source_archive_sha256":SOURCE.SOURCE_SHA,"recipes":recipes,"recipe_summary":{"active":recipes.size(),"rejected":rejected},"recipe_admission":admission,
		"raw_recipes":{"twilight_source_lazy":true},"guaranteed_boxes":boxes,
		"items":items_part,"bonuses":{"twilight_source_lazy":true,"ids":_used.keys()},"bonus_types":_index(_tables.BonusType),"enchantment":enchantment,"source_exclusions":{},
		"equipment_runtime":runtime_part}
	if not binding_sha256.is_empty(): result.binding_catalog_sha256 = binding_sha256
	if not ResourceLoader.exists(EQUIPMENT_PATH): problem = "제작 장비 projection 모듈이 아직 없습니다 · 미완료"; return {}
	var equipment_script: Script = load(EQUIPMENT_PATH)
	if equipment_script == null: problem = "제작 장비 projection 모듈을 읽을 수 없습니다 · 미완료"; return {}
	_equipment = equipment_script.new()
	if not _equipment.prepare(_tables):
		problem = str(_equipment.problem); return {}
	for table: String in ["ItemBlessBonus","Material","Unit","UIUnit","InvokeOption","InvokeOptionType","BonusApplicationType","AttackType","SpecialResistanceType"]: result.enchantment[table] = _tables[table]
	return result

