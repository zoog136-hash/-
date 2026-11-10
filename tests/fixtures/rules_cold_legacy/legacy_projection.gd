extends RefCounted
## FROZEN COPY (rules cold bake test reference) of scripts/crafting/patch523_rules_projection.gd as it was
## before the bounded cold compile. Only seams: `source` (injectable reader) and the legacy enchantment path.
## UNVERIFIED: in-memory input port of tools/equipment/build_patch523_rules.py.
## Existing public policies only; no item registration, alias, grant, or save.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const POLICY_PATH = "res://data/crafting/patch523_crafting_policy.json"
const EQUIPMENT_PATH = "res://tests/fixtures/rules_cold_legacy/legacy_enchantment.gd"
const TABLES = ["SpecialResistanceType","InvokeOption","InvokeOptionType","BonusApplicationType","AttackType","ItemBlessBonus","Material","Unit","UIUnit","Class","LuckyBagClass","LuckyBagEntityView","LuckyBagEntityType","LuckyBagEntityClassLimit","DescData_Korean","ItemCraftInput","ItemCraftOutputView","ItemCraftView","ItemCraftRestriction","ItemClass","ItemCategory","ItemClassLimit","ItemBonus","Bonus","BonusType","ItemEnchantBonus","ItemEnchantProbabilityGroup","ItemEnchantEquipGroupMapping","ItemEnchantScrollGroup","ItemEnchantScrollGroupMapping","BmItemEnchantProView","ItemEnchantCostView","ItemEnchantProbabilityView","ItemBlessEnchantProbability","DateTimes_Korean","ItemBlessCode","EquipSlotConfig","ItemEquipSlot"]
var problem: String = ""
var source: Variant = SOURCE
var _tables: Dictionary = {}
var _evidence: Dictionary = {}
var _descriptions: Dictionary = {}
var _items: Dictionary = {}
var _categories: Dictionary = {}
var _classes: Dictionary = {}
var _limits: Dictionary = {}
var _equip_links: Dictionary = {}
var _item_bonuses: Dictionary = {}
var _by_id: Dictionary = {}
var _by_name: Dictionary = {}
var _variants: Dictionary = {}
var _currency_keys: Dictionary = {}
var _host_materials: Dictionary = {}
var _use_conditions: Dictionary = {}
var _policy: Dictionary = {}
var _dates: Dictionary = {}
var _full_native: bool = false
var _exclusions: Dictionary = {}

static func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	return hash.finish().hex_encode()

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

static func _sorted_ids(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values: result.append(value)
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
		# ItemBonus/ItemEnchantBonus reference; no other join reads it.
		_tables[name] = [] if name in ["DescData_Korean","Bonus"] else source.rows(name)
		if name == "Bonus" and source.row_count(name) != int(meta.get("row_count",-1)):
			problem = "제작 원본 표를 읽을 수 없습니다: "+name; return false
		if name not in ["DescData_Korean","Bonus"] and _tables[name].size() != int(meta.get("row_count",-1)):
			problem = "제작 원본 표를 읽을 수 없습니다: "+name; return false
	_items = _index(_tables.ItemClass); _categories = _index(_tables.ItemCategory)
	_classes = _index(_tables.Class); _dates = _index(_tables.DateTimes_Korean)
	_limits = _group(_tables.ItemClassLimit,"ItemClassID")
	_equip_links = _group(_tables.ItemEquipSlot,"ItemClassID")
	_item_bonuses = _group(_tables.ItemBonus,"ItemClassID")
	return true

func _catalog(catalog: Array, binding: Dictionary) -> Array:
	if binding.is_empty(): return catalog.duplicate()
	var supplement: Array = binding.get("아이템",[])
	var contract: Dictionary = binding.get("patch523_crafting_catalog_contract",{})
	_full_native = contract.get("mode") == "full_native_supplement" and contract.get("source_bin_sha256") == "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27" and contract.get("normal_ids") == 30398
	var live: Dictionary = {}
	for record: Dictionary in supplement: live[_identity(record)] = true
	var result: Array = []
	var initial: Dictionary = {}
	for record: Dictionary in catalog:
		if live.has(_identity(record)): result.append(record); initial[_identity(record)] = true
	# Keep duplicates visible, exactly as the compiler's comprehension does.
	for record: Dictionary in supplement:
		if record.get("source") == "lineagem_patch523" and record.get("source_m_native_item") == true and not initial.has(_identity(record)): result.append(record)
	return result

func _bind_catalog(catalog: Array, wallet_records: Array) -> bool:
	for record: Dictionary in catalog:
		var name: String = str(record.name)
		if not _by_name.has(name): _by_name[name] = []
		_by_name[name].append(record)
		# Same as the current projection: pre-November inven rows are not
		# bound to original IDs (user decision 2026-11-10).
	for record: Dictionary in catalog:
		var value: Variant = record.get("source_item_class_id")
		if not _integer(value) or int(value) <= 0: continue
		var key: String = str(int(value))
		var native: Dictionary = _items.get(key,{})
		if native.is_empty() or record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or record.get("source_m_native_item") != true or record.get("sourceId") != "m523:item:"+key or record.get("source_bless_raw",1) != 1: continue
		if record.get("source_display_name") not in [_description(int(native.DescID)),_description(int(native.IdentifiedDescID))] or record.get("name") != str(record.get("source_display_name"))+" · 원본#"+key: continue
		if record.get("source_test_item") != native.TestItem or record.get("source_is_stackable") != _categories[str(int(native.CategoryID))].IsStackable or record.get("source_level_limit_min") != native.LevelLimitMin or record.get("source_level_limit_max") != native.LevelLimitMax: continue
		if _sorted_ids(record.get("source_class_ids",[])) != _ids(_limits.get(key,[]),"ClassID",true) or _sorted_ids(record.get("source_equip_slot_ids",[])) != _ids(_equip_links.get(key,[]),"EquipSlotID"): continue
		var previous: Array = _by_id.get(key,[])
		if not _full_native and previous.size() == 1 and _by_name[previous[0].name].size() == 1 and not (record.get("source_projection")=="current523_original_typed_game_dto_v1" and record.get("source_definition_archive")==source.identity() and _same_original(record,native)): continue
		if _by_name[record.name].size() == 1: _by_id[key] = [record]
	for entry: Dictionary in catalog:
		var raw_id: Variant = entry.get("source_item_class_id",0)
		if not _integer(raw_id): continue
		var key: String = str(int(raw_id))
		var state: Variant = entry.get("source_bless_raw",1)
		if state not in [2,3] or _by_id.get(key,[]).size() != 1: continue
		var base: Dictionary = _by_id[key][0]
		if not base.get("source_m_native_item",false) or not base.get("source_is_stackable",false) or entry.get("source") != "lineagem_patch523" or entry.get("sourceId") != str(base.sourceId)+":bless:"+str(int(state)) or entry.get("name") != str(base.name)+(" · 축복" if state == 2 else " · 저주"): continue
		var same: bool = true
		for field: String in ["source_snapshot","source_item_class_id","source_display_name","source_test_item","source_is_stackable","source_level_limit_min","source_level_limit_max","source_class_ids","source_equip_slot_ids","slot"]:
			if entry.get(field) != base.get(field): same = false
		if same and _by_name[entry.name].size() == 1:
			if not _variants.has(key): _variants[key] = {}
			_variants[key][str(int(state))] = entry
	var wallet_names: Dictionary = {}
	for record: Dictionary in wallet_records:
		if record.get("slot") == "currency": wallet_names[record.name] = true
	for key: String in _policy.get("source_currency_bindings",{}):
		var binding: Dictionary = _policy.source_currency_bindings[key]
		var matches: Array = _by_id.get(key,[])
		if matches.size() == 1 and matches[0].get("source_m_native_item") == true and _categories[str(int(_items[key].CategoryID))].Name == "Currency" and matches[0].get("source_display_name") in binding.source_names and wallet_names.has(binding.inventory_key): _currency_keys[key] = binding.inventory_key
	for key: String in _items:
		var item: Dictionary = _items[key]
		var class_ids: Array = _ids(_limits.get(key,[]),"ClassID",true)
		var minimum: int = maxi(int(item.LevelLimitMin),int(item.get("MaxLevelLimitMin",0)))
		var maximum: int = 0
		for value: Variant in [item.LevelLimitMax,item.get("MaxLevelLimitMax",0)]:
			if int(value) > 0: maximum = int(value) if maximum == 0 else mini(maximum,int(value))
		if minimum != 0 or maximum != 0 or not class_ids.is_empty():
			var names: Array = []
			for id: int in class_ids: names.append(_description(int(_classes.get(str(id),{}).get("DescID",0)),str(id)))
			_use_conditions[key] = {"schema":"patch523-item-use-v1","source_id":key,"min_level":minimum,"max_level":maximum,"class_ids":class_ids,"class_names":names}
	for key: String in _policy.get("host_material_bindings",{}):
		if not _items.has(key): continue
		if _by_id.get(key,[]).size() == 1 and _by_id[key][0].get("source_m_native_item") == true: continue
		var binding: Dictionary = _policy.host_material_bindings[key]
		if not _by_id.get(key,[]).is_empty() or _by_name.has(binding.item): problem = "기존 제작 host binding 정체가 충돌합니다"; return false
		var original: Dictionary = _items[key]
		if _description(int(original.DescID)) != binding.item or not _categories[str(int(original.CategoryID))].IsStackable: problem = "기존 제작 host binding의 원본 재료가 다릅니다"; return false
		var record: Dictionary = {"name":binding.item,"source":"twilight_host_binding","sourceId":key,"slot":"consumable","host_kind":binding.kind,"host_amount":binding.amount,"binding_origin":binding.origin}
		_by_id[key] = [record]; _by_name[binding.item] = [record]; _host_materials[key] = record
	return true

func _native_non_equipment(key: String) -> bool:
	if not _policy.get("native_non_equipment_holding",{}).get("enabled",false) or _by_id.get(key,[]).size() != 1: return false
	var entry: Dictionary = _by_id[key][0]
	return entry.get("source") == "lineagem_patch523" and entry.get("source_m_native_item") == true and entry.get("slot") in ["material","consumable","currency",""] and entry.get("source_equipment_status") == "no_source_equip_slot" and entry.get("source_equip_slot_ids") == [] and _equip_links.get(key,[]).is_empty()

func _physical(key: String) -> bool:
	return not _categories[str(int(_items[key].CategoryID))].IsStackable and not _native_non_equipment(key)

func _record(original: Dictionary) -> Dictionary:
	var key: String = str(int(original.ItemClassID))
	if original.ItemBlessCodeID != 1 and _categories[str(int(_items[key].CategoryID))].IsStackable:
		return _variants.get(key,{}).get(str(int(original.ItemBlessCodeID)),{})
	return _by_id.get(key,[{}])[0]

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
	var first: Dictionary = _dates.get(str(int(view.EffectiveFrom)),{})
	var last: Dictionary = _dates.get(str(int(view.EffectiveTo)),{})
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
		if row.Amount < 1 or row.Amount > (1000000000 if key == "26" else 100000000) or row.Enchant < 0 or row.Enchant > 21 or row.ItemBlessCodeID not in [1,2] or int(row.get("ItemHoningEpithetID",0)) != 0: return {"reason":"unresolved_item_state","item_id":row.ItemClassID}
		var item: Dictionary = _items.get(key,{})
		if item.is_empty(): return {"reason":"unresolved_item_condition","item_id":row.ItemClassID}
		var exclusion: Dictionary = _declared_exclusion("ItemClass",item)
		if not exclusion.is_empty(): return {"reason":"source_declared_exclusion","item_id":row.ItemClassID,"source_exclusion":exclusion}
		var category: Dictionary = _categories[str(int(item.CategoryID))]
		var invalid_classes: bool = false
		for link: Dictionary in _limits.get(key,[]):
			if int(link.ClassID) <= 0 or not _classes.has(str(int(link.ClassID))): invalid_classes = true
		var allowance: Dictionary = _policy.get("nonactivating_material_class_references",{}).get(key,{})
		var source_input: bool = ins.has(row) and category.get("IsStackable") == true and category.get("IsActivatable") == false and _item_bonuses.get(key,[]).is_empty() and allowance.get("scope") == "source_input_only" and _ids(_limits.get(key,[]),"ClassID",true) == allowance.get("class_ids")
		if item.TestItem or _truthy(item.ServiceRegionCode) or item.LevelLimitMin < 0 or item.LevelLimitMin > 1000 or item.LevelLimitMax < 0 or item.LevelLimitMax > 1000 or (item.LevelLimitMax != 0 and item.LevelLimitMax < item.LevelLimitMin) or (invalid_classes and not source_input): return {"reason":"unresolved_item_condition","item_id":row.ItemClassID}
		if key == "26":
			if row.Enchant != 0 or row.ItemBlessCodeID != 1 or _description(int(item.DescID)) != "아데나": return {"reason":"unsupported_currency_state","item_id":row.ItemClassID}
			continue
		var matches: Array = _by_id.get(key,[])
		if matches.size() != 1 or _by_name[matches[0].name].size() != 1: return {"reason":"missing_or_ambiguous_catalog_identity","item_id":row.ItemClassID}
		if matches[0].get("source") == "inven" and matches[0].name not in [_description(int(item.DescID)),_description(int(item.IdentifiedDescID))]: return {"reason":"source_identity_name_disagreement","item_id":row.ItemClassID}
		if _native_non_equipment(key) and not category.IsStackable and (row.Enchant != 0 or row.ItemBlessCodeID != 1): return {"reason":"non_equipment_state_unrepresented","item_id":row.ItemClassID}
		var stack: bool = not _physical(key)
		if stack and (row.Enchant != 0 or _record(row).is_empty()): return {"reason":"stack_state_cannot_be_represented","item_id":row.ItemClassID}
		if not stack and matches[0].get("slot","") not in ["weapon","helmet","armor","cloak","gloves","boots","shield","gaiters","shirt","belt","ring","earring","necklace","seal","rune","shoulder","insignia","body","offhand","tshirt","bracelet","badge","crystal","catalyst"]: return {"reason":"unmapped_physical_slot","item_id":row.ItemClassID}
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
		if row.ItemCraftOutputTypeID not in [0,1,2] or row.Probability <= 0 or row.Probability > 1000000: valid_outs = false
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
	elif int(craft_id) in _policy.get("delegated_protection_recipe_ids",[]): reason = "delegated_protection_owner"
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

func _bound_items(bonuses: Dictionary, used_bonuses: Dictionary) -> Dictionary:
	var inspectable: Dictionary = _by_id.duplicate()
	if _items.has("26") and _description(int(_items["26"].DescID)) == "아데나": inspectable["26"] = [_currency_record()]
	for key: String in _item_bonuses:
		if inspectable.has(key) or not _items.has(key): continue
		for link: Dictionary in _item_bonuses[key]:
			if bonuses[str(int(link.BonusID))].BonusTypeID in [2022,8352]:
				inspectable[key] = [{"name":_description(int(_items[key].DescID),_items[key].Name),"source":"lineagem_patch523","sourceId":key,"slot":"consumable"}]
				break
	var enchant: Dictionary = _group(_tables.ItemEnchantBonus,"ItemEnchantBonusGroupID")
	var result: Dictionary = {}
	for key: String in inspectable:
		var records: Array = inspectable[key]
		if not _items.has(key) or records.size() != 1: continue
		var links: Array = _item_bonuses.get(key,[])
		var effects: Array = []
		for link: Dictionary in links:
			var bonus_id: String = str(int(link.BonusID))
			var bonus: Dictionary = bonuses[bonus_id]
			used_bonuses[bonus_id] = true
			if bonus.BonusTypeID == 71: effects.append_array(enchant.get(str(int(bonus.Value)),[]))
		for row: Dictionary in effects: used_bonuses[str(int(row.BonusID))] = true
		var record: Dictionary = records[0]
		var item: Dictionary = _items[key]
		var genuine: bool = record.get("source") == "inven" and record.name in [_description(int(item.DescID)),_description(int(item.IdentifiedDescID))]
		result[key] = {"catalog_record":record,"item_class":item,"item_bonuses":links,"enchant_effects":effects,"use_conditions":_use_conditions.get(key,{}) if genuine or record.get("source_m_native_item",false) else {}}
		var exclusion: Dictionary = _declared_exclusion("ItemClass",item)
		if not exclusion.is_empty(): result[key].source_exclusion = exclusion
		if _variants.has(key): result[key].stack_variants = _variants[key]
		if _currency_keys.has(key): result[key].currency_inventory_key = _currency_keys[key]
	for key: String in _policy.get("nonactivating_material_class_references",{}):
		if result.has(key) and _categories[str(int(result[key].item_class.CategoryID))].get("IsActivatable") == false and result[key].item_bonuses.is_empty(): result[key].craft_material_only_class_references = _policy.nonactivating_material_class_references[key]
	return result

func _boxes() -> Dictionary:
	var result: Dictionary = {}
	var classes: Dictionary = _index(_tables.LuckyBagClass)
	var types: Dictionary = _index(_tables.LuckyBagEntityType)
	var limits: Dictionary = {}
	for row: Dictionary in _tables.LuckyBagEntityClassLimit: limits[str(int(row.LuckyBagEntityID))] = true
	var entities: Dictionary = _group(_tables.LuckyBagEntityView,"LuckyBagClassID")
	for target: Array in [[30701,12741,30671],[130611,22871,130551]]:
		var rewards: Array = entities.get(str(target[1]),[])
		if rewards.is_empty(): continue
		var expected: Dictionary = {str(target[2])+":1":true,"320802:8":true}
		var found: Dictionary = {}
		var supported: bool = types.get("1",{}).get("Name") == "IsGiven" and classes.has(str(target[1])) and rewards.size() == 2
		for row: Dictionary in rewards:
			found[str(int(row.ItemClassID))+":"+str(int(row.ItemAmount))] = true
			if row.LuckyBagEntityTypeID != 1 or row.Probability != 10000000 or row.ItemBlessCodeID != 1 or row.ItemEnchant != 0 or row.LimitClass != 10000 or limits.has(str(int(row.ID))): supported = false
		if not supported or found != expected: problem = "기존 확정 상자의 원본 계약이 다릅니다"; return {}
		result[str(target[0])] = {"bag_class":classes[str(target[1])],"rewards":rewards}
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

static func binding_document(items: Array, contract: Dictionary, parse: bool = true) -> Dictionary:
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
		var copies: Array = []
		if parse: copies.resize(items.size())
		size += _hash_text(hash,"[")
		for index: int in items.size():
			# Registered records are identified by their full form (template
			# fields included), exactly as registration produced them.
			var item: Variant = NATIVE_FIELDS.full(items[index])
			var text: String = JSON.stringify(item,"",true,true)
			size += _hash_text(hash,("" if index == 0 else ",")+text)
			# Same values a whole-document parse gives for these fields.
			if parse: copies[index] = JSON.parse_string(JSON.stringify(slim_binding_record(item),"",true,true))
		size += _hash_text(hash,"]")
		parsed[key] = copies
	size += _hash_text(hash,"}")
	return {"binding":parsed,"sha256":hash.finish().hex_encode(),"bytes":size}

## JSON.parse_string(JSON.stringify(value,"",true,true)) and the SHA256 input
## of that text, produced container by container to `depth` levels so the
## whole text never exists at once. hash.update() receives the exact bytes.
static func stream_round_trip(value: Variant, hash: HashingContext, depth: int, size: Array) -> Variant:
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
		size[0] += _hash_text(hash,"]")
		return copies
	var keys: Array = value.keys()
	# Same order as Godot's JSON key sort: String and StringName compare as
	# text, other types by type first.
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		if (a is String or a is StringName) and (b is String or b is StringName): return str(a) < str(b)
		return typeof(a) < typeof(b) if typeof(a) != typeof(b) else a < b)
	var result: Dictionary = {}
	size[0] += _hash_text(hash,"{")
	for index: int in keys.size():
		var name: String = str(keys[index])
		size[0] += _hash_text(hash,("" if index == 0 else ",")+JSON.stringify(name)+":")
		result[name] = stream_round_trip(value[keys[index]],hash,depth-1,size)
	size[0] += _hash_text(hash,"}")
	return result

## Drops the source tables and indexes once the model is built.
func release() -> void:
	_tables.clear(); _evidence.clear(); _descriptions.clear(); _by_id.clear(); _by_name.clear(); _variants.clear(); _currency_keys.clear(); _host_materials.clear(); _use_conditions.clear(); _exclusions.clear()
	_items = {}; _categories = {}; _classes = {}; _dates = {}; _limits = {}; _equip_links = {}; _item_bonuses = {}

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
		var slim: Array = []
		for record: Variant in binding["아이템"]: slim.append(slim_binding_record(record))
		binding["아이템"] = slim
	return build_bound(catalog_bytes,binding,_sha(binding_catalog_bytes) if not binding_catalog_bytes.is_empty() else "")

## Same as build() with the binding catalog already parsed (binding_document()).
func build_bound(catalog_bytes: PackedByteArray, binding: Dictionary, binding_sha256: String) -> Dictionary:
	problem = ""
	_tables.clear(); _evidence.clear(); _descriptions.clear(); _by_id.clear(); _by_name.clear(); _variants.clear(); _currency_keys.clear(); _host_materials.clear(); _use_conditions.clear(); _exclusions.clear()
	_full_native = false
	var original: Variant = JSON.parse_string(catalog_bytes.get_string_from_utf8())
	if not original is Dictionary or not original.get("아이템") is Array: problem = "기존 제작 카탈로그 입력이 필요합니다"; return {}
	if not binding.is_empty() and not binding.get("아이템") is Array: problem = "실제 등록된 제작 카탈로그 정체가 필요합니다"; return {}
	var parsed_policy: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
	if not parsed_policy is Dictionary or parsed_policy.is_empty(): problem = "기존 공개 제작 정책을 읽을 수 없습니다"; return {}
	_policy = parsed_policy
	if not _read_source(): return {}
	var catalog: Array = _catalog(original["아이템"],binding)
	var wallets: Array = catalog if binding.is_empty() else binding["아이템"]
	if not _bind_catalog(catalog,wallets): return {}
	var inputs: Dictionary = _group(_tables.ItemCraftInput,"ItemCraftID")
	var outputs: Dictionary = _group(_tables.ItemCraftOutputView,"ItemCraftID")
	var views: Dictionary = _group(_tables.ItemCraftView,"ItemCraftID")
	var restrictions: Dictionary = _group(_tables.ItemCraftRestriction,"ItemCraftID")
	var recipes: Dictionary = {}; var rejected: Dictionary = {}; var admission: Dictionary = {}
	for craft_id: String in views:
		var compiled: Dictionary = _recipe(craft_id,views[craft_id],inputs.get(craft_id,[]),outputs.get(craft_id,[]),restrictions.get(craft_id,[]))
		if not problem.is_empty(): return {}
		if compiled.has("recipe"): recipes["patch523:"+craft_id] = compiled.recipe; continue
		var reason: String = str(compiled.get("reason",""))
		rejected[reason] = int(rejected.get(reason,0))+1
		admission[craft_id] = {"reason":reason}
		if compiled.has("source_exclusion"): admission[craft_id].source_exclusion = compiled.source_exclusion
		if reason in ["missing_or_ambiguous_catalog_identity","unresolved_item_condition","unmapped_physical_slot","unresolved_item_state","source_identity_name_disagreement","stack_state_cannot_be_represented"]: admission[craft_id].first_blocking_item_class_id = compiled.get("item_id")
	var referenced: Dictionary = {}
	for table: String in ["ItemBonus","ItemEnchantBonus"]:
		for row: Dictionary in _tables[table]:
			if _integer(row.get("BonusID")): referenced[int(row.BonusID)] = true
	var bonuses: Dictionary = _index(source.rows_matching("Bonus","ID",referenced))
	var used: Dictionary = {}
	var bound_items: Dictionary = _bound_items(bonuses,used)
	var boxes: Dictionary = _boxes()
	if not problem.is_empty(): return {}
	var selected_bonuses: Dictionary = {}
	for key: String in used: selected_bonuses[key] = bonuses[key]
	var enchantment: Dictionary = {}
	for table: String in ["ItemEnchantProbabilityGroup","ItemEnchantEquipGroupMapping","ItemEnchantScrollGroup","ItemEnchantScrollGroupMapping","BmItemEnchantProView","ItemEnchantCostView","ItemEnchantProbabilityView","ItemBlessEnchantProbability","ItemBlessCode","EquipSlotConfig","ItemEquipSlot"]: enchantment[table] = _tables[table]
	var result: Dictionary = {"schema":"twilight-patch523-equipment-v1","snapshot":"patch523","catalog_sha256":_sha(catalog_bytes),"source_files":_evidence,
		"source_archive_sha256":SOURCE.SOURCE_SHA,"recipes":recipes,"recipe_summary":{"active":recipes.size(),"rejected":rejected},"recipe_admission":admission,
		"raw_recipes":{"inputs":inputs,"outputs":outputs,"views":views,"restrictions":restrictions},"guaranteed_boxes":boxes,
		"items":bound_items,"bonuses":selected_bonuses,"bonus_types":_index(_tables.BonusType),"enchantment":enchantment,"source_exclusions":_exclusions}
	if not binding_sha256.is_empty(): result.binding_catalog_sha256 = binding_sha256
	if not ResourceLoader.exists(EQUIPMENT_PATH): problem = "제작 장비 projection 모듈이 아직 없습니다 · 미완료"; return {}
	var equipment_script: Script = load(EQUIPMENT_PATH)
	if equipment_script == null: problem = "제작 장비 projection 모듈을 읽을 수 없습니다 · 미완료"; return {}
	var equipment = equipment_script.new()
	var eligible_items: Dictionary = {}
	for key: String in bound_items:
		if not bound_items[key].has("source_exclusion") and bound_items[key].item_class.get("TestItem") != true: eligible_items[key] = bound_items[key]
	result.equipment_runtime = equipment.build(_tables,eligible_items,bonuses)
	if not str(equipment.problem).is_empty(): problem = str(equipment.problem); return {}
	for table: String in ["ItemBlessBonus","Material","Unit","UIUnit","InvokeOption","InvokeOptionType","BonusApplicationType","AttackType","SpecialResistanceType"]: result.enchantment[table] = _tables[table]
	# item_class/item_bonuses/enchant_effects are verbatim original rows; the
	# model keeps a lazy marker and patch523_rules.item_entry() reads the same
	# rows back from the shared reader (source_fields) instead of ~0.6 GB of copies.
	for key: String in bound_items:
		for field: String in SOURCE_FIELDS: bound_items[key].erase(field)
		bound_items[key]["twilight_source_lazy"] = true
	# The grouped craft rows are the verbatim ItemCraftID groups;
	# patch523_rules.recipe_evidence() reads them from the shared reader.
	result.raw_recipes = {"twilight_source_lazy":true}
	# The selected Bonus rows are verbatim original rows: the model keeps their
	# IDs and patch523_rules.bonus() reads the row from the shared reader.
	var bonus_ids: Array = result.bonuses.keys()
	result.bonuses = {"twilight_source_lazy":true,"ids":bonus_ids}
	return result

