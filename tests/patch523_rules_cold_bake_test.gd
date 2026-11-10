extends SceneTree
## Standalone, synthetic (no original installed): the bounded cold compile of
## the equipment rules model (scripts/crafting/patch523_rules.gd +
## patch523_rules_projection.gd + patch523_enchantment_projection.gd) must
## produce exactly what the former whole-model compile produced. The former
## algorithm is kept frozen in tests/fixtures/rules_cold_legacy/ and both are
## run on the same synthetic definition tables through a reader double with
## current523_definition_rows' public API (JSON float numbers, column-packed
## tables and a row-store table).
##
## Compared: model digest, `data`, materialized_data(), recipes, every public
## accessor over every item, the three record files and the whole-model bake
## byte for byte, the resident modes, the storage-failure fallbacks, and the
## bounded retention (no whole-table reads of the big tables, per-item parts,
## lower peak memory on the same input).

const RULES = preload("res://scripts/crafting/patch523_rules.gd")
const PROJECTION = preload("res://scripts/crafting/patch523_rules_projection.gd")
const ENCHANTMENT = preload("res://scripts/crafting/patch523_enchantment_projection.gd")
const PACKED = preload("res://scripts/crafting/patch523_packed_records.gd")
const LEGACY_RULES = preload("res://tests/fixtures/rules_cold_legacy/legacy_rules.gd")
const LEGACY_PROJECTION = preload("res://tests/fixtures/rules_cold_legacy/legacy_projection.gd")
const LEGACY_ENCHANTMENT = preload("res://tests/fixtures/rules_cold_legacy/legacy_enchantment.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
const ENHANCEMENT = preload("res://scripts/crafting/patch523_enhancement.gd")
const BAKES: Array[String] = ["equipment_rules_catalog_records","equipment_rules_runtime","equipment_rules","equipment_rules_cold"]
const LOG_DIR := "user://rules_cold_bake_test_log"

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok and failures.size() < 40: failures.append(description)

func same(description: String, left: Variant, right: Variant) -> bool:
	var ok: bool = typeof(left) == typeof(right) and var_to_bytes(left) == var_to_bytes(right)
	check(ok, description)
	return ok

## Reader double. Uniform tables behave like the packed column store; tables
## named in `row_store` (or with differing row keys) like its "rows" fallback.
class FakeRows extends RefCounted:
	var tables: Dictionary = {}
	var row_store: Dictionary = {}
	var full_reads: Dictionary = {}
	var row_reads: int = 0
	func _uniform(table: String) -> bool:
		if row_store.has(table): return false
		var rows: Array = tables.get(table, [])
		if rows.is_empty(): return true
		var keys: Array = (rows[0] as Dictionary).keys()
		for row: Dictionary in rows:
			if row.size() != keys.size(): return false
			for key: Variant in keys:
				if not row.has(key): return false
		return true
	static func _integer(value: Variant) -> bool:
		return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0
	func identity() -> Dictionary:
		return {"kind":"twilight.current523.original-definitions.v1","source_snapshot":"patch523","source_sha256":SOURCE.SOURCE_SHA,"source_bytes":25031173}
	func table_metadata(table: String) -> Dictionary:
		if not tables.has(table): return {}
		return {"path":"content/"+table+".json","sha256":(table+":synthetic").sha256_text(),"bytes":(tables[table] as Array).size()*97,"row_count":(tables[table] as Array).size()}
	func declared_exclusion(table: String, row: Dictionary, _scope: String = "record") -> Dictionary:
		var excluded: bool = (table == "ItemClass" and str(row.get("Name","")).begins_with("EXCL")) or (table == "ItemCraftView" and row.get("PopupText") == 777.0)
		return {"source_sha256":SOURCE.SOURCE_SHA,"excluded_from_connection":true,"table":table,"row_id":row.get("ID",row.get("ItemCraftID")),"basis":"synthetic declaration"} if excluded else {}
	func rows(table: String) -> Array[Dictionary]:
		full_reads[table] = int(full_reads.get(table, 0)) + 1
		var result: Array[Dictionary] = []
		for row: Dictionary in tables.get(table, []): result.append(row.duplicate(true))
		return result
	func row_count(table: String) -> int: return (tables.get(table, []) as Array).size()
	func row_at(table: String, index: int) -> Dictionary:
		row_reads += 1
		var rows: Array = tables.get(table, [])
		return (rows[index] as Dictionary).duplicate(true) if index >= 0 and index < rows.size() else {}
	func column(table: String, field: String) -> Variant:
		var rows: Array = tables.get(table, [])
		var uniform: bool = _uniform(table)
		if rows.is_empty() or (uniform and not (rows[0] as Dictionary).has(field)): return []
		var values: Array = []
		for row: Dictionary in rows:
			if not row.has(field): return []
			values.append(row[field])
		if not uniform: return values
		for value: Variant in values:
			if typeof(value) != TYPE_FLOAT: return values
		return PackedFloat64Array(values)
	func rows_matching(table: String, field: String, ids: Dictionary) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		if ids.is_empty(): return result
		for row: Dictionary in tables.get(table, []):
			var value: Variant = row.get(field)
			if _integer(value) and ids.has(int(value)): result.append(row.duplicate(true))
		return result
	func related(table: String, foreign_key: String, id: int) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for row: Dictionary in tables.get(table, []):
			var value: Variant = row.get(foreign_key)
			if _integer(value) and int(value) == id: result.append(row.duplicate(true))
		return result

# --- synthetic definitions ----------------------------------------------------

var _reader: FakeRows
var _descriptions: int = 0
var _bonus_id: int = 0
var _link_id: int = 0
var _input_id: int = 0
var _archive: Dictionary = {}
var _desc_text: Dictionary = {}

func add(table: String, row: Dictionary) -> Dictionary:
	if not _reader.tables.has(table): _reader.tables[table] = []
	(_reader.tables[table] as Array).append(row)
	return row

func describe(text: String) -> float:
	_descriptions += 1
	add("DescData_Korean", {"ID": float(9000000 + _descriptions), "Description": text})
	_desc_text[float(9000000 + _descriptions)] = text
	return float(9000000 + _descriptions)

## One ItemClass row with the original's 42 columns.
func item_class(id: int, display: String, category: int, options: Dictionary = {}) -> Dictionary:
	var desc: float = describe(display)
	return add("ItemClass", {"ID": float(id), "Name": str(options.get("name", "item_"+str(id))), "DescID": desc,
		"IdentifiedDescID": float(options.get("identified", desc)), "IconID": float(id % 97), "SpriteID": float(id % 89),
		"CategoryID": float(category), "MaterialID": float(options.get("material", 3)), "Weight": float(id % 50), "IsTradable": true,
		"IsStorable": true, "IsDeletable": true, "IsDroppable": id % 2 == 0, "LevelLimitMin": float(options.get("min", 0)),
		"LevelLimitMax": float(options.get("max", 0)), "IsShowProbability": false, "TargettingTypeID": 0.0, "Cost": float(id % 1000),
		"GradeID": float(options.get("grade", 1)), "StoryDescID": 0.0, "MaxStackAmount": 1000.0, "IsTrash": false, "IsSoluble": false,
		"UseDescID": 0.0, "ProductTitleDescID": 0.0, "ProductDescID": 0.0, "EinasadLevel": 0.0, "DecreaseLogInterval": 0.0,
		"TestItem": bool(options.get("test", false)), "IsShownEnchantProb": false, "IsCraftable": true, "GettablePlaceID": 0.0,
		"SpriteAnimationID": 0.0, "CanUseWhenInvisible": false, "QualityLevel": 0.0, "MaxLevelLimitMin": float(options.get("max_min", 0)),
		"MaxLevelLimitMax": float(options.get("max_max", 0)), "GradeTierID": 0.0, "IsPersonalTradable": false,
		"IsEventProbability": false, "ServiceRegionCode": str(options.get("region", "")), "LinkSeasonShopType": 0.0})

func bonus(type: int, value: float, application: int = 0, target: int = 0) -> int:
	_bonus_id += 1
	add("Bonus", {"ID": float(_bonus_id), "BonusTypeID": float(type), "Value": value,
		"BonusApplicationTypeID": float(application), "BonusApplicationTargetID": float(target)})
	return _bonus_id

func link(item: int, bonus_id: int) -> void:
	_link_id += 1
	add("ItemBonus", {"ID": float(_link_id), "ItemClassID": float(item), "BonusID": float(bonus_id), "IsPossession": false})

## The registered native record of an ItemClass row, as registration stores it.
func native_record(row: Dictionary, slot: String, options: Dictionary = {}) -> Dictionary:
	var key: String = str(int(row.ID))
	var display: String = str(options.get("display", _display(row)))
	var category: Dictionary = _category(int(row.CategoryID))
	var record: Dictionary = {"name": display+" · 원본#"+key, "source": "lineagem_patch523", "sourceId": "m523:item:"+key, "slot": slot,
		"grade": "일반", "weight": int(row.Weight), "source_snapshot": "patch523", "source_item_class_id": int(row.ID),
		"source_m_native_item": true, "source_bless_raw": 1, "source_display_name": display, "source_test_item": row.TestItem,
		"source_is_stackable": category.IsStackable, "source_level_limit_min": int(row.LevelLimitMin), "source_level_limit_max": int(row.LevelLimitMax),
		"source_class_ids": options.get("classes", []), "source_equip_slot_ids": options.get("slots", []),
		"source_projection": "current523_original_typed_game_dto_v1", "source_definition_archive": _archive.duplicate(true),
		"source_original_item": row.duplicate(true),
		"source_equipment_status": "no_source_equip_slot" if (options.get("slots", []) as Array).is_empty() else "source_equip_slot",
		# Fields outside the compiler's binding fields: never part of the model.
		"source_icon_id": int(row.IconID), "desc": "synthetic "+key, "source_use_spec": {"kind": "none", "values": [1, 2, 3]}}
	if options.has("drop"):
		for field: String in options.drop: record.erase(field)
	return record

func _display(row: Dictionary) -> String:
	return str(_desc_text.get(row.DescID, ""))

func _category(id: int) -> Dictionary:
	for row: Dictionary in _reader.tables.ItemCategory:
		if int(row.ID) == id: return row
	return {}

func small_table(table: String, count: int, extra: Dictionary = {}) -> void:
	for index: int in count:
		var row: Dictionary = {"ID": float(index + 1), "Name": table+"_"+str(index + 1)}
		for key: String in extra: row[key] = extra[key]
		add(table, row)

func craft_view(craft: int, item: int, amount: int, enchant: int, bless: int, options: Dictionary = {}) -> void:
	add("ItemCraftView", {"ItemCraftID": float(craft), "ItemClassID": float(item), "Amount": float(amount),
		"Enchant": float(enchant), "ItemBlessCodeID": float(bless), "ServerLimitSetID": float(options.get("server", 0)),
		"IsCoalitionItem": false, "NoRepeat": false, "IsBelowLevelLimit": false, "LevelLimitValue": float(options.get("level", 0)),
		"CraftTimeTypeID": float(options.get("time", 1)), "EffectiveFrom": float(options.get("from", 1)), "EffectiveTo": float(options.get("to", 3)),
		"AlwaysSuccess": float(options.get("always", 1)), "PopupText": float(options.get("popup", 0)), "ItemCategoryID": 1.0, "WeaponType": 0.0, "EquipSlot": 0.0})

func craft_input(craft: int, slot: int, item: int, amount: int, enchant: int = 0, bless: int = 1) -> void:
	_input_id += 1
	add("ItemCraftInput", {"ID": float(_input_id), "ItemCraftID": float(craft), "SlotIndex": float(slot), "ItemClassID": float(item),
		"Amount": float(amount), "Enchant": float(enchant), "ItemBlessCodeID": float(bless), "ItemHoningEpithetID": 0.0})

func craft_output(craft: int, type: int, item: int, amount: int, enchant: int, bless: int, probability: int, clan: int = 0) -> void:
	_input_id += 1
	add("ItemCraftOutputView", {"ID": float(_input_id), "ItemCraftID": float(craft), "ItemCraftOutputTypeID": float(type), "ItemClassID": float(item),
		"Amount": float(amount), "Enchant": float(enchant), "ItemBlessCodeID": float(bless), "Probability": float(probability),
		"ItemHoningEpithetID": 0.0, "ClanItemClassID": float(clan), "ClanAmount": 0.0, "GradeID": 1.0, "CategoryID": 1.0})

## {reader, items, contract, catalog_bytes}: `bulk` generated native items on
## top of the hand-made cases. `full_native` selects the registration contract.
func fixture(bulk: int, full_native: bool = true, integers: bool = false) -> Dictionary:
	_reader = FakeRows.new()
	_descriptions = 0; _bonus_id = 0; _link_id = 0; _input_id = 0
	_desc_text = {}
	_archive = _reader.identity()
	var policy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/crafting/patch523_crafting_policy.json"))
	var catalog_bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://data/catalog_v19.json")
	var catalog: Array = JSON.parse_string(catalog_bytes.get_string_from_utf8())["아이템"]
	var items: Array = []
	for row: Array in [[1,"Weapon",false,true],[2,"Armor",false,true],[3,"Material",true,false],[4,"Currency",true,true],[5,"Scroll",true,true]]:
		add("ItemCategory", {"ID": float(row[0]), "Name": row[1], "IsStackable": row[2], "IsActivatable": row[3], "Order": float(row[0]),
			"A": 0.0, "B": 0.0, "C": "", "D": false, "E": 0.0})
	for id: int in [1, 2, 3]: add("Class", {"ID": float(id), "DescID": describe("class "+str(id)), "Name": "class_"+str(id)})
	small_table("SpecialResistanceType", 0)
	for row: Array in [[1,"Stun"],[2,"Hold"],[3,"Fear"],[4,"Poison"],[5,"Silence"],[6,"Other"]]: add("SpecialResistanceType", {"ID": float(row[0]), "Name": row[1], "X": 0.0})
	for name: String in ["InvokeOptionType","BonusApplicationType","AttackType","Material","Unit","UIUnit","ItemEnchantProbabilityGroup","ItemEnchantScrollGroup",
		"ItemBlessEnchantProbability","ItemBlessCode","EquipSlotConfig","LuckyBagEntityType"]:
		small_table(name, 4)
	(_reader.tables.LuckyBagEntityType[0] as Dictionary).Name = "IsGiven"
	for index: int in 6:
		add("ItemEnchantEquipGroupMapping", {"ItemEnchantEquipGroupID": float(index % 3 + 1), "ItemEnchantProbabilityGroupID": float(index + 1)})
		add("ItemEnchantScrollGroupMapping", {"ItemEnchantScrollGroupID": float(index % 2 + 1), "ItemEnchantProbabilityGroupID": float(index + 1)})
		for level: int in 4:
			add("BmItemEnchantProView", {"ID": float(index * 10 + level), "ItemEnchantProbabilityGroupID": float(index + 1), "EnchantLevel": float(level), "TargetItemBlessCode": float(level % 3), "Probability": 500000.0, "A": 0.0, "B": 0.0})
			add("ItemEnchantCostView", {"ID": float(index * 10 + level), "ItemEnchantProbabilityGroupID": float(index + 1), "EnchantLevel": float(level), "TargetItemBlessCode": float(level % 3), "Cost": 10.0})
			add("ItemEnchantProbabilityView", {"ID": float(index * 10 + level), "ItemEnchantProbabilityGroupID": float(index + 1), "EnchantLevel": float(level), "Probability": 1.0})
	for index: int in 12: add("DateTimes_Korean", {"ID": float(index + 1), "Year": 2026.0 + float(index / 6), "Month": float(index % 12 + 1), "Day": 5.0, "Hour": 5.0, "Minute": 0.0})
	# The last row of a duplicated ID is the one _index() keeps.
	add("DateTimes_Korean", {"ID": 10.0, "Year": 2027.0, "Month": 2.0, "Day": 7.0, "Hour": 6.0, "Minute": 30.0})
	# Bonus types the runtime projection maps, qualifies, skips or rejects.
	var type_rows: Array = [[71,"ItemEnchantBonusGroup",1],[2022,"ScrollGroup",1],[8352,"ScrollGroupBless",1],[2032,"EquipGroup",1],
		[1001,"WeaponDamageBonus",1],[1002,"ArmorClass",1],[1003,"HPPlus",1],[1004,"Strength",1],[1005,"InvokeOption",3],
		[1006,"SpecialResistance",3],[1007,"HitSpecialResistance",3],[1008,"ElementalDamage",1],[1009,"FinalBlowProbability",3],
		[1010,"MagicDamage",1],[1011,"PierceDamageReduction",1],[1012,"IncreaseNpcItemDropAmount",3],[1013,"ArmorClassBonus",1],
		[1014,"UnknownThing",1],[1015,"ExperienceAdditionPercent",3],[1016,"AttackDrainHP",1],[1017,"FinalBlowAdditionalScale",1],[1018,"CarryPlus",1]]
	for row: Array in type_rows:
		add("BonusType", {"ID": float(row[0]), "Name": row[1], "UnitID": float(row[2]), "DescID": 0.0, "A": 0.0, "B": false, "C": "", "D": 0.0})
	for index: int in 8:
		add("InvokeOption", {"ID": float(index + 1), "InvokeOptionTypeID": float([3,5,6,4,3,6,5,3][index]), "Param1": float([10,20,1500000,5,-1,500,30,40][index]),
			"Param2": 0.0, "Param3": 0.0 if index != 7 else 2.0, "Param4": 0.0, "Param5": 0.0, "Param6": 0.0, "MaterialTypeID": 0.0, "MaterialAmount": 0.0,
			"IsAmmoAttack": false, "WeaponGroupID": 0.0, "ShieldTypeID": 0.0, "SuccessedInvokeOptionID": 0.0, "TargetKind": 0.0, "SiegeTargetKind": 0.0,
			"BySpellAttack": false, "AttackTypeID": float(index % 4), "Name": "invoke_"+str(index)})
	# Duplicate InvokeOption ID: the last row is the one indexed.
	var again: Dictionary = (_reader.tables.InvokeOption[1] as Dictionary).duplicate(true)
	again.Param1 = 25.0
	add("InvokeOption", again)
	for grade: int in [1, 2]:
		for category: int in [1, 2]:
			add("ItemBlessBonus", {"ID": float(grade * 10 + category), "ItemCategoryID": float(category), "GradeID": float(grade), "IsTest": false,
				"IsPossession": grade == 2 and category == 2, "BonusApplicationTypeID": 0.0, "BonusApplicationTargetID": 0.0,
				"BonusTypeID": 1013.0 if category == 2 else 1001.0, "Value": float(grade + category)})
	# Enchant effect groups: per level rows in bless codes 0/1/2.
	var stat_bonuses: Array = [bonus(1001, 3.0), bonus(1002, 2.0), bonus(1003, 50.0), bonus(1004, 1.0), bonus(1005, 250000.0, 10, 1),
		bonus(1005, 100000.0, 10, 2), bonus(1005, 300000.0, 10, 3), bonus(1005, 50000.0, 10, 4), bonus(1006, 30000.0, 2, 1),
		bonus(1007, 20000.0, 2, 3), bonus(1008, 4.0, 3, 1), bonus(1009, 15000.0, 0, 0), bonus(1010, 6.0, 2, 1), bonus(1011, 2.0, 2, 3),
		bonus(1012, 5.0, 5, 26), bonus(1014, 9.0), bonus(1015, 20000.0), bonus(1016, 2.0), bonus(1017, 7.0), bonus(1018, 300.0),
		bonus(1005, 250000.0, 10, 8), bonus(1005, 250000.0, 10, 99), bonus(1006, 30000.0, 2, 6), bonus(1001, 1.5)]
	var effect_id: int = 0
	for group: int in range(1, 9):
		for level: int in 10:
			for bless: int in ([0, 1, 2] if group % 3 == 0 else ([0] if group % 3 == 1 else [1, 2])):
				for pick: int in 3:
					effect_id += 1
					add("ItemEnchantBonus", {"ID": float(effect_id), "EnchantLevel": float(level), "ItemEnchantBonusGroupID": float(group),
						"BonusID": float(stat_bonuses[(group * 7 + level * 3 + bless * 5 + pick * 11) % stat_bonuses.size()]), "BlessCode": float(bless)})
	var group_bonus: Array = []
	for group: int in range(1, 9): group_bonus.append(bonus(71, float(group)))
	group_bonus.append(bonus(71, 404.0)) # a group without rows
	var equip_group: int = bonus(2032, 2.0)
	# Unreferenced rows, a duplicated ID (the later row wins) and a fractional ID.
	for index: int in 40: bonus(1001, float(index))
	add("Bonus", {"ID": float(stat_bonuses[0]), "BonusTypeID": 1001.0, "Value": 4.0, "BonusApplicationTypeID": 0.0, "BonusApplicationTargetID": 0.0})
	add("Bonus", {"ID": 12.5, "BonusTypeID": 1001.0, "Value": 1.0, "BonusApplicationTypeID": 0.0, "BonusApplicationTargetID": 0.0})
	# Adena, policy currency, host material, non-activating material.
	item_class(26, "아데나", 4)
	var currency_id: int = int((policy.source_currency_bindings as Dictionary).keys()[0])
	var currency_policy: Dictionary = policy.source_currency_bindings[str(currency_id)]
	var currency_row: Dictionary = item_class(currency_id, str(currency_policy.source_names[0]), 4)
	items.append(native_record(currency_row, "currency"))
	items.append({"name": currency_policy.inventory_key, "source": "twilight_wallet", "sourceId": "wallet:1", "slot": "currency", "weight": 0})
	var host_id: int = int((policy.host_material_bindings as Dictionary).keys()[0])
	item_class(host_id, str(policy.host_material_bindings[str(host_id)].item), 3)
	var reference_id: int = int((policy.nonactivating_material_class_references as Dictionary).keys()[0])
	var reference_row: Dictionary = item_class(reference_id, "비활성 재료", 3)
	add("ItemClassLimit", {"ItemClassID": float(reference_id), "ClassID": 0.0})
	items.append(native_record(reference_row, "material", {"classes": [0]}))
	# catalog_v19 (inven) records bound by their source ID: equipment and materials.
	var names: Dictionary = {}
	for record: Dictionary in catalog: names[record.name] = int(names.get(record.name, 0)) + 1
	var inven_equipment: Array = []
	var inven_materials: Array = []
	for record: Dictionary in catalog:
		if names[record.name] != 1 or not str(record.sourceId).is_valid_int() or int(record.sourceId) < 1000 or int(record.sourceId) in [currency_id, host_id, reference_id]: continue
		if record.slot == "material" and inven_materials.size() < 12: inven_materials.append(record)
		elif record.slot in ["weapon","helmet","ring","cloak"] and inven_equipment.size() < 40: inven_equipment.append(record)
	var inven_ids: Dictionary = {}
	for index: int in inven_equipment.size():
		var record: Dictionary = inven_equipment[index]
		var id: int = int(record.sourceId)
		inven_ids[id] = true
		# Every fifth keeps another original name: not "genuine" (no use conditions).
		item_class(id, str(record.name) if index % 5 != 4 else "다른 이름", 1 if record.slot == "weapon" else 2,
			{"grade": index % 2 + 1, "min": 10 * (index % 4), "max": 0 if index % 3 else 80, "max_min": 5 * (index % 3)})
		if index not in [2, 6]: add("ItemEquipSlot", {"ItemClassID": float(id), "EquipSlotID": float(index % 4 + 1)})
		if index % 4 == 0: add("ItemClassLimit", {"ItemClassID": float(id), "ClassID": float(index % 3 + 1)})
		link(id, group_bonus[index % group_bonus.size()])
		if index % 2 == 0: link(id, group_bonus[(index + 3) % group_bonus.size()])
		link(id, equip_group)
		link(id, stat_bonuses[index % stat_bonuses.size()])
		items.append(record)
	for index: int in inven_materials.size():
		var record: Dictionary = inven_materials[index]
		inven_ids[int(record.sourceId)] = true
		item_class(int(record.sourceId), str(record.name), 3)
		items.append(record)
	# A registered catalog record whose ItemClass does not exist, and one that
	# is in catalog_v19 but not registered (never bound).
	for record: Dictionary in catalog:
		if names[record.name] == 1 and str(record.sourceId).is_valid_int() and not inven_ids.has(int(record.sourceId)) and int(record.sourceId) not in [26, currency_id, host_id, reference_id]:
			items.append(record)
			break
	# Native items: equipment, stackables with blessed/cursed variants, a
	# native record over an inven-bound ID, excluded, test and unbound ones.
	var native_equipment: Array = []
	var native_materials: Array = []
	for index: int in bulk + 24:
		var id: int = 500000 + index * 7
		var equipment: bool = index % 3 != 0
		var row: Dictionary = item_class(id, "원본 "+("장비" if equipment else "재료")+" "+str(index), (1 + index % 2) if equipment else (3 if index % 2 else 5),
			{"grade": index % 3 + 1, "min": index % 5, "max": 0 if index % 4 else 90, "max_max": 0 if index % 6 else 70, "material": index % 4})
		var options: Dictionary = {}
		if equipment:
			# A registered record's slot/class ID lists are JSON numbers and the
			# compiler compares them with integer lists: only records without
			# either are bound. Both kinds are generated.
			if index % 3 == 2:
				add("ItemEquipSlot", {"ItemClassID": float(id), "EquipSlotID": float(index % 5 + 1)})
				options["slots"] = [index % 5 + 1]
				if index % 7 == 0:
					add("ItemEquipSlot", {"ItemClassID": float(id), "EquipSlotID": 9.0})
					options["slots"] = [9, index % 5 + 1]
			link(id, group_bonus[index % group_bonus.size()])
			if index % 5 == 0: link(id, group_bonus[(index + 1) % group_bonus.size()])
			if index % 4 == 0: link(id, equip_group)
			link(id, stat_bonuses[(index * 3) % stat_bonuses.size()])
		if index % 6 == 5:
			add("ItemClassLimit", {"ItemClassID": float(id), "ClassID": float(index % 3 + 1)})
			add("ItemClassLimit", {"ItemClassID": float(id), "ClassID": float((index + 1) % 3 + 1)})
			options["classes"] = [(index + 1) % 3 + 1, index % 3 + 1]
		var slot: String = ["weapon","helmet","ring","armor","cloak"][index % 5] if equipment else ("material" if index % 2 else "consumable")
		if index % 11 == 5: options["drop"] = ["grade","weight","source_bless_raw"]
		if index % 13 == 7: options["display"] = "틀린 이름" # never bound: display name disagrees
		var record: Dictionary = native_record(row, slot, options)
		items.append(record)
		if index % 13 == 7: continue
		if equipment:
			if index % 3 == 1: native_equipment.append(id)
		else:
			native_materials.append(id)
			if index % 4 == 0:
				for state: int in [2, 3]:
					var variant: Dictionary = record.duplicate(true)
					variant.sourceId = str(record.sourceId)+":bless:"+str(state)
					variant.name = str(record.name)+(" · 축복" if state == 2 else " · 저주")
					variant.source_bless_raw = state
					items.append(variant)
	# Duplicated ItemClass ID: the later row is the item.
	var later: Dictionary = (_reader.tables.ItemClass[_reader.tables.ItemClass.size() - 3] as Dictionary).duplicate(true)
	later.Cost = 4242.0
	add("ItemClass", later)
	# Native records over inven-bound IDs: one exact, one whose original row
	# differs (bound only under the full native contract).
	for pick: int in [6, 2]:
		var over_inven: int = int(inven_equipment[pick].sourceId)
		for row: Dictionary in _reader.tables.ItemClass:
			if int(row.ID) != over_inven: continue
			var over: Dictionary = native_record(row, str(inven_equipment[pick].slot), {})
			if pick == 2: over.source_original_item.Cost = -1.0
			items.append(over)
	var excluded_row: Dictionary = item_class(600001, "선언 제외 장비", 1, {"name": "EXCL_declared"})
	link(600001, group_bonus[0])
	items.append(native_record(excluded_row, "weapon"))
	var test_row: Dictionary = item_class(600002, "시험 장비", 1, {"test": true})
	link(600002, group_bonus[1])
	items.append(native_record(test_row, "weapon"))
	# Scrolls that are not registered: inspectable through their scroll bonuses.
	item_class(700001, "강화 주문서", 5)
	link(700001, stat_bonuses[0])
	link(700001, bonus(2022, 1.0))
	item_class(700002, "축복 주문서", 5)
	link(700002, bonus(8352, 2.0, 202, 2))
	item_class(700003, "효과 없는 물건", 5)
	link(700003, stat_bonuses[1])
	link(999999, stat_bonuses[2]) # ItemBonus of an ItemClass that does not exist
	# Guaranteed boxes.
	for id: int in [30701, 30671, 320802]: item_class(id, "상자 물품 "+str(id), 3)
	for index: int in 30: add("LuckyBagClass", {"ID": float(12700 + index), "Name": "bag_"+str(index), "DescID": 0.0})
	add("LuckyBagClass", {"ID": 12741.0, "Name": "bag_target", "DescID": 0.0})
	var entity_id: int = 0
	for row: Array in [[12700,1,5,1],[12741,30671,1,1],[12705,7,2,1],[12741,320802,8,1],[12706,7,2,2]]:
		entity_id += 1
		add("LuckyBagEntityView", {"ID": float(entity_id), "LuckyBagClassID": float(row[0]), "LuckyBagEntityTypeID": float(row[3]), "Probability": 10000000.0,
			"ItemClassID": float(row[1]), "ItemAmount": float(row[2]), "ItemBlessCodeID": 1.0, "ItemEnchant": 0.0, "GradeID": 1.0, "CategoryID": 1.0,
			"EquipSlotID": 0.0, "CategoryDisplayPriority": 0.0, "BlessDisplayPriority": 0.0, "LimitClass": 10000.0})
	for id: int in [1, 3, 5]: add("LuckyBagEntityClassLimit", {"LuckyBagEntityID": float(id), "ClassID": 1.0})
	# Recipes.
	var material_a: int = int(inven_materials[0].sourceId)
	var material_b: int = int(inven_materials[1].sourceId)
	var weapon: int = native_equipment[0]
	var armor: int = native_equipment[1]
	var stack: int = native_materials[0]
	var stack_plain: int = native_materials[1]
	craft_view(1001, weapon, 1, 0, 1)
	craft_input(1001, 0, 26, 100); craft_input(1001, 1, material_a, 2); craft_input(1001, 2, stack_plain, 1); craft_input(1001, 2, material_b, 3)
	craft_output(1001, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1002, armor, 1, 3, 1, {"always": 0})
	craft_input(1002, 0, material_a, 5); craft_input(1002, 1, int(inven_equipment[1].sourceId), 1, 8, 2)
	craft_output(1002, 1, armor, 1, 3, 1, 700000); craft_output(1002, 2, armor, 1, 5, 2, 200000); craft_output(1002, 0, 0, 0, 0, 1, 100000)
	var missing_id: int = 0
	for key: String in policy.missing_failure_contracts:
		if policy.missing_failure_contracts[key].get("enabled") == true and missing_id == 0: missing_id = int(key)
	craft_view(missing_id, weapon, 1, 0, 1, {"always": 0})
	craft_input(missing_id, 0, material_b, 1); craft_input(missing_id, 1, 26, 5000)
	craft_output(missing_id, 1, weapon, 1, 0, 1, int(policy.missing_failure_contracts[str(missing_id)].source_success_weight))
	for key: String in policy.verified_craft_constraints:
		var constraint: Dictionary = policy.verified_craft_constraints[key]
		craft_view(int(key), stack, 2, 0, 1, {"level": 30})
		craft_input(int(key), 0, material_a, 1)
		craft_output(int(key), 1, stack, 2, 0, 1, 1000000)
		var restriction: Dictionary = {}
		for field: String in constraint.source_restriction:
			var value: Variant = constraint.source_restriction[field]
			restriction[field] = float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else value
		add("ItemCraftRestriction", restriction)
	craft_view(1003, stack, 1, 0, 2, {"from": 4, "to": 10})
	craft_input(1003, 0, stack, 3, 0, 1); craft_input(1003, 1, currency_id, 2); craft_input(1003, 2, host_id, 1)
	craft_output(1003, 1, stack, 1, 0, 2, 1000000)
	craft_view(1004, 123456789, 1, 0, 1); craft_input(1004, 0, material_a, 1); craft_output(1004, 1, 123456789, 1, 0, 1, 1000000)
	craft_view(1005, weapon, 1, 0, 1); craft_input(1005, 0, material_a, 1); craft_output(1005, 1, weapon, 1, 0, 1, 1000000)
	add("ItemCraftRestriction", {"ID": 5.0, "ItemCraftID": 1005.0, "ServiceTypeID": 1.0, "Value": 1.0, "RefreshUnitID": 1.0, "isMultiCount": false})
	craft_view(1006, weapon, 1, 0, 1); craft_input(1006, 0, 600001, 1); craft_output(1006, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1007, weapon, 1, 7, 2); craft_input(1007, 0, armor, 1, 8, 2); craft_input(1007, 1, 26, 10); craft_input(1007, 2, 26, 15)
	craft_output(1007, 1, weapon, 1, 7, 2, 1000000)
	craft_view(1008, weapon, 1, 0, 1, {"always": 0}); craft_view(1008, armor, 1, 0, 1, {"always": 0})
	craft_input(1008, 0, material_a, 1)
	craft_output(1008, 1, weapon, 1, 0, 1, 400000); craft_output(1008, 1, armor, 1, 0, 1, 400000); craft_output(1008, 0, material_a, 1, 0, 1, 200000)
	var verified: int = int(policy.verified_source_craft_ids[0])
	craft_view(verified, armor, 1, 0, 1, {"always": 0}); craft_input(verified, 0, material_b, 4)
	craft_output(verified, 1, armor, 1, 0, 1, 250000); craft_output(verified, 0, 0, 0, 0, 1, 750000)
	var delegated: int = int(policy.delegated_protection_recipe_ids[0])
	craft_view(delegated, weapon, 1, 0, 1); craft_input(delegated, 0, material_a, 1); craft_output(delegated, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1009, stack_plain, 1, 0, 1); craft_input(1009, 0, reference_id, 2); craft_output(1009, 1, stack_plain, 1, 0, 1, 1000000)
	craft_view(1010, weapon, 1, 0, 1); craft_input(1010, 0, stack, 4, 0, 2); craft_output(1010, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1012, weapon, 1, 0, 1); craft_input(1012, 0, 26, 50); craft_output(1012, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1013, weapon, 1, 0, 1); craft_input(1013, 0, 600002, 1); craft_output(1013, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1014, weapon, 1, 0, 1, {"popup": 777}); craft_input(1014, 0, material_a, 1); craft_output(1014, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1015, weapon, 1, 0, 1, {"time": 2}); craft_input(1015, 0, material_a, 1); craft_output(1015, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1016, weapon, 1, 0, 1); craft_output(1016, 1, weapon, 1, 0, 1, 1000000)
	craft_view(1017, weapon, 1, 0, 1); craft_input(1017, 0, material_a, 1); craft_output(1017, 1, weapon, 1, 0, 1, 1000000, 5)
	craft_view(1018, 26, 500, 0, 1); craft_input(1018, 0, material_a, 1); craft_output(1018, 1, 26, 500, 0, 1, 1000000)
	craft_view(1019, weapon, 1, 0, 1); craft_input(1019, 0, stack, 1, 3, 1); craft_output(1019, 1, weapon, 1, 0, 1, 1000000)
	craft_input(424242, 0, material_a, 1) # input of a craft without a view: never read
	for index: int in mini(bulk, 60):
		var craft: int = 3000 + index
		var result_item: int = native_equipment[index % native_equipment.size()] if index % 2 else native_materials[index % native_materials.size()]
		craft_view(craft, result_item, 1 + index % 3 if index % 2 == 0 else 1, 0, 1)
		craft_input(craft, 0, native_materials[(index * 3) % native_materials.size()], 1 + index % 4)
		if index % 3 == 0: craft_input(craft, 1, native_equipment[(index * 5) % native_equipment.size()], 1, index % 9, 1 + index % 2)
		craft_output(craft, 1, result_item, 1 + index % 3 if index % 2 == 0 else 1, 0, 1, 1000000)
	if integers:
		# Integer-typed numbers (a reader or engine that keeps JSON integers):
		# the craft and binding comparisons written against integers then pass.
		for table: String in _reader.tables:
			for row: Dictionary in _reader.tables[table]:
				for field: String in row:
					if typeof(row[field]) == TYPE_FLOAT and row[field] == floorf(row[field]): row[field] = int(row[field])
		for record: Dictionary in items:
			if record.get("source_original_item") is Dictionary:
				for field: String in record.source_original_item:
					var value: Variant = record.source_original_item[field]
					if typeof(value) == TYPE_FLOAT and value == floorf(value): record.source_original_item[field] = int(value)
	var contract: Dictionary = {"mode": "full_native_supplement", "source_bin_sha256": "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27", "normal_ids": 30398} if full_native else {"mode": "partial"}
	return {"reader": _reader, "items": items, "contract": contract, "catalog_bytes": catalog_bytes}

# --- helpers --------------------------------------------------------------------

## Highest static memory seen while a compile runs (the engine's own peak
## counter is already above these compiles when the test starts).
class Sampler extends RefCounted:
	var thread := Thread.new()
	var running: bool = false
	var peak: int = 0
	func start() -> void:
		running = true
		peak = OS.get_static_memory_usage()
		thread.start(_poll)
	func _poll() -> void:
		while running:
			peak = maxi(peak, OS.get_static_memory_usage())
			OS.delay_usec(500)
	func stop() -> int:
		running = false
		thread.wait_to_finish()
		return peak

func bake_bytes() -> Dictionary:
	var result: Dictionary = {}
	for name: String in BAKES:
		var path: String = BAKE.data_path(name)
		result[name] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	return result

func clear_bakes() -> void:
	for name: String in BAKES:
		BAKE.clear(name)
		for suffix: String in [".bin", ".bin.part"]:
			var path: String = BAKE.ROOT + "/" + name + suffix
			if DirAccess.dir_exists_absolute(path):
				DirAccess.remove_absolute(path.path_join("blocker"))
				DirAccess.remove_absolute(path)
			elif FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func compile_new(data: Dictionary, key: String) -> Variant:
	var rules = RULES.new()
	rules._projection_source = data.reader
	var ok: bool = rules.compile_original_bound(data.catalog_bytes, data.items, data.contract, key)
	return rules if ok else rules.problem

func compile_old(data: Dictionary, key: String) -> Variant:
	var rules = LEGACY_RULES.new()
	var ok: bool = rules.legacy_compile(data.reader, data.catalog_bytes, data.items, data.contract, key)
	return rules if ok else rules.problem

## Every public read of the model over every item, hashed in a fixed order.
func accessors(rules: Variant) -> Dictionary:
	var result: Dictionary = {}
	var ids: Array = rules.materialized_data().items.keys()
	ids.append_array(["0", "26", "does-not-exist", "999999"])
	for id: String in ids:
		var entry: Dictionary = {"item_entry": rules.item_entry(id), "catalog_record_of": rules.catalog_record_of(id),
			"runtime": rules.equipment_runtime_of(id), "has_runtime": rules.has_equipment_runtime(id)}
		for bless: int in [1, 2, 3]:
			entry["compiled:"+str(bless)] = rules.compiled_record(id, bless)
			entry["record:"+str(bless)] = rules.record(id, bless)
		var canonical: Dictionary = rules.catalog_record_of(id)
		if not canonical.is_empty():
			entry["prepare:1"] = ENHANCEMENT.prepare(rules, canonical.duplicate(true), 1)
			entry["prepare:2"] = ENHANCEMENT.prepare(rules, canonical.duplicate(true), 2)
			entry["craftsman"] = rules.craftsman_weapon_rule(canonical)
			entry["identity"] = rules.catalog_identity_matches(canonical, id)
		entry["seal"] = rules.supported_seal_options(id, 2)
		result[id] = entry
	var types: Dictionary = {}
	for id: Variant in rules.materialized_data().bonus_types: types[str(id)] = rules.bonus_type(str(id))
	types["none"] = rules.bonus_type("none")
	result["#bonus_types"] = types
	var invokes: Dictionary = {}
	for id: int in 12: invokes[str(id)] = rules.offloaded_invoke_option(str(id))
	result["#invokes"] = invokes
	var bonus_rows: Dictionary = {}
	for id: Variant in rules.materialized_data().bonuses.get("ids", []): bonus_rows[str(id)] = rules.bonus_row(str(id))
	result["#bonus_rows"] = bonus_rows
	var evidence: Dictionary = {}
	for id: Variant in rules.recipes:
		var craft: int = int(rules.recipes[id].source_craft_id)
		evidence[id] = [rules.recipe_evidence(craft), rules.material_selection(str(id)), rules.enhancement_evidence(craft, 700001, 1, 1, 1)]
	result["#recipes"] = evidence
	result["#any_runtime"] = rules.has_any_equipment_runtime()
	return result

func compare_models(label: String, new_rules: Variant, old_rules: Variant) -> bool:
	if not (new_rules is Object and old_rules is Object):
		check(false, label+": compile failed new="+str(new_rules)+" old="+str(old_rules))
		return false
	var ok: bool = true
	ok = same(label+": digest", new_rules.digest, old_rules.digest) and ok
	ok = same(label+": data", new_rules.data, old_rules.data) and ok
	ok = same(label+": materialized_data", new_rules.materialized_data(), old_rules.materialized_data()) and ok
	ok = same(label+": recipes", new_rules.recipes, old_rules.recipes) and ok
	var new_reads: Dictionary = accessors(new_rules)
	var old_reads: Dictionary = accessors(old_rules)
	ok = same(label+": accessor keys", new_reads.keys(), old_reads.keys()) and ok
	for key: Variant in old_reads:
		if not same(label+": accessors of "+str(key), new_reads.get(key), old_reads[key]):
			ok = false
			var mine: Variant = new_reads.get(key)
			if mine is Dictionary and old_reads[key] is Dictionary:
				for field: Variant in old_reads[key]:
					if var_to_bytes(mine.get(field)) != var_to_bytes(old_reads[key][field]): failures.append("  differs: "+str(key)+"."+str(field))
			break
	return ok

func _initialize() -> void:
	BOOT_LOG.reset_for_test(LOG_DIR, BOOT_LOG.CAP_BYTES, false)
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	clear_bakes()
	_run()
	clear_bakes()
	for name: String in [BOOT_LOG.FILE_NAME, BOOT_LOG.OVER_NAME, BOOT_LOG.PREV_NAME]: DirAccess.remove_absolute(LOG_DIR.path_join(name))
	BOOT_LOG.reset_for_test("user://", BOOT_LOG.CAP_BYTES, false)
	DirAccess.remove_absolute(LOG_DIR)
	var result := {"checks": checks, "failures": failures}
	print("PATCH523_RULES_COLD_BAKE_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _run() -> void:
	_packed_records()
	_stream_and_runtime_units()
	# 1. Peak memory on the same input, new first (the peak counter only grows).
	var big: Dictionary = fixture(1500)
	var base: int = OS.get_static_memory_usage()
	var sampler := Sampler.new()
	sampler.start()
	var new_big: Variant = compile_new(big, "rules-cold-big")
	var peak_new: int = sampler.stop()
	var new_bytes: Dictionary = bake_bytes()
	var big_reader: FakeRows = big.reader
	var new_full_reads: Dictionary = big_reader.full_reads.duplicate()
	clear_bakes()
	big_reader.full_reads.clear()
	var held: int = OS.get_static_memory_usage() - base # the accepted new model, still held
	sampler = Sampler.new()
	sampler.start()
	var old_big: Variant = compile_old(big, "rules-cold-big")
	var peak_old: int = sampler.stop() - held
	var old_bytes: Dictionary = bake_bytes()
	check(new_big is Object and old_big is Object, "big: both compile ("+str(new_big if not new_big is Object else "")+"/"+str(old_big if not old_big is Object else "")+")")
	if not (new_big is Object and old_big is Object): return
	var new_rise: int = peak_new - base
	var old_rise: int = peak_old - base
	print("PATCH523_RULES_COLD_BAKE_MEMORY new_peak_rise=", new_rise, " old_peak_rise=", old_rise, " items=", (big.items as Array).size())
	check(new_rise > 0 and float(new_rise) <= float(old_rise) * 0.55, "big: peak rise new "+str(new_rise)+" <= 55% of old "+str(old_rise))
	# 2. Identical record files and bake, byte for byte.
	for name: String in BAKES:
		check(not (old_bytes[name] as PackedByteArray).is_empty(), "big: the former compile wrote "+name)
		check(new_bytes[name] == old_bytes[name], "big: "+name+" is byte-identical ("+str((new_bytes[name] as PackedByteArray).size())+" / "+str((old_bytes[name] as PackedByteArray).size())+")")
	# 3. Bounded retention: no whole-table read of the big tables.
	for table: String in PROJECTION.SELECTIVE:
		check(not new_full_reads.has(table), "big: "+table+" is never read as a whole row array")
	for table: String in ["ItemClass","ItemBonus","ItemCraftInput","ItemCraftOutputView","ItemCraftRestriction","LuckyBagEntityView","DateTimes_Korean"]:
		check(big_reader.full_reads.has(table), "big: the former compile read "+table+" whole (the reference really differs)")
	# 4. The model and every accessor.
	print("PATCH523_RULES_COLD_BAKE_MODEL items=", new_big.data.items.size(), " runtime=", new_big._runtime_ids.size(), " records_bytes=", (new_bytes["equipment_rules_catalog_records"] as PackedByteArray).size(), " runtime_bytes=", (new_bytes["equipment_rules_runtime"] as PackedByteArray).size())
	check(new_big.data.items.size() > 900 and new_big._runtime_ids.size() > 300, "big: items and runtime compiled")
	check((new_big.data.recipe_summary.rejected as Dictionary).size() >= 6, "big: rejection reasons covered "+str(new_big.data.recipe_summary.rejected))
	var marked: int = 0
	for id: String in new_big.data.items:
		if new_big.data.items[id].get(RULES.RECORDS_MARK) == true and not new_big.data.items[id].has("catalog_record"): marked += 1
	check(marked == new_big.data.items.size(), "big: every catalog identity is on storage")
	check(new_big.data.equipment_runtime == {RULES.RUNTIME_MARK: true}, "big: the runtime is on storage")
	check(not (new_big.materialized_data().guaranteed_boxes as Dictionary).is_empty(), "big: guaranteed box compiled")
	compare_models("big", new_big, old_big)
	# A later start reads the bake the new compile wrote.
	# (The files on storage are now the former compile's, byte-identical.)
	var warm = RULES.new()
	var baked: Variant = BAKE.read("equipment_rules", "rules-cold-big")
	check(baked is Dictionary and baked.get("offloaded") == true, "big: bake readable")
	if baked is Dictionary:
		warm._model_key = "rules-cold-big"
		check(warm._accept(baked.model, baked.sha256), "big: bake accepted")
		warm._release_cold()
		same("big: warm accessors", accessors(warm), accessors(new_big))
	warm = null
	new_big = null
	old_big = null
	big = {}
	clear_bakes()
	# 5. Other registration contract (original-row digest path), small.
	var small: Dictionary = fixture(40, false)
	compare_models("partial contract", compile_new(small, "rules-cold-small"), compile_old(small, "rules-cold-small"))
	clear_bakes()
	# 5b. Integer-typed rows: recipes, native binding and variants compile.
	var typed: Dictionary = fixture(60, true, true)
	var typed_new: Variant = compile_new(typed, "rules-cold-typed")
	var typed_bytes: Dictionary = bake_bytes()
	clear_bakes()
	var typed_old: Variant = compile_old(typed, "rules-cold-typed")
	if compare_models("integer rows", typed_new, typed_old):
		for name: String in BAKES: check(typed_bytes[name] == bake_bytes()[name] and not (typed_bytes[name] as PackedByteArray).is_empty(), "integer rows: "+name+" is byte-identical")
		print("PATCH523_RULES_COLD_BAKE_COVERAGE recipes=", typed_new.recipes.size(), " rejected=", typed_new.data.recipe_summary.rejected)
		check(typed_new.recipes.size() >= 12, "integer rows: recipes compiled ("+str(typed_new.recipes.size())+")")
		check((typed_new.data.recipe_summary.rejected as Dictionary).size() >= 8, "integer rows: rejection reasons covered")
		var currencies: int = 0
		var exclusions: int = 0
		var data: Dictionary = typed_new.materialized_data()
		for id: String in data.items:
			if data.items[id].has("currency_inventory_key"): currencies += 1
			if data.items[id].has("source_exclusion"): exclusions += 1
		# (Blessed/cursed stack variants and class-limited natives cannot be bound
		# from JSON-typed registered records; their rejection is compared above.)
		check(currencies > 0 and exclusions > 0, "integer rows: currency/exclusion entries present "+str([currencies,exclusions]))
	typed_new = null
	typed_old = null
	typed = {}
	clear_bakes()
	# 6. Resident modes: no key, and the environment switch.
	small = fixture(40)
	var resident_new: Variant = compile_new(small, "")
	var resident_old: Variant = compile_old(small, "")
	if compare_models("no key (resident)", resident_new, resident_old):
		check(resident_new.data.items.values()[0].has("catalog_record") and resident_new.data.equipment_runtime.size() > 1, "no key: everything resident")
	OS.set_environment("TWILIGHT_RULES_RECORDS_RESIDENT", "1")
	compare_models("resident switch", compile_new(small, "rules-cold-env"), compile_old(small, "rules-cold-env"))
	OS.set_environment("TWILIGHT_RULES_RECORDS_RESIDENT", "")
	check(bake_bytes()["equipment_rules"].is_empty(), "resident switch: no bake written")
	clear_bakes()
	var reference: Variant = compile_new(small, "rules-cold-reference")
	var reference_reads: Dictionary = accessors(reference) if reference is Object else {}
	var reference_digest: String = reference.digest if reference is Object else ""
	reference = null
	clear_bakes()
	# 7. Record storage that cannot be opened: resident from the start.
	DirAccess.make_dir_recursive_absolute(BAKE.ROOT + "/equipment_rules_runtime.bin.part")
	var blocked: Variant = compile_new(small, "rules-cold-blocked")
	check(blocked is Object, "writer blocked: the model is still compiled")
	if blocked is Object:
		check(blocked.digest == reference_digest, "writer blocked: same model digest")
		check(blocked.data.items.values()[0].has("catalog_record") and not blocked.data.equipment_runtime.has(RULES.RUNTIME_MARK), "writer blocked: catalog identities and runtime stay resident")
		check(bake_bytes()["equipment_rules"].is_empty(), "writer blocked: no bake written")
		same("writer blocked: accessors", accessors(blocked), reference_reads)
	blocked = null
	clear_bakes()
	# 8. Record file that cannot be committed: compiled again, resident.
	var blocker: String = BAKE.ROOT + "/equipment_rules_catalog_records.bin"
	DirAccess.make_dir_recursive_absolute(blocker)
	var keep := FileAccess.open(blocker.path_join("blocker"), FileAccess.WRITE)
	keep.store_string("x")
	keep.close()
	var uncommitted: Variant = compile_new(small, "rules-cold-uncommitted")
	check(uncommitted is Object, "commit blocked: the model is still compiled")
	if uncommitted is Object:
		check(uncommitted.digest == reference_digest, "commit blocked: same model digest")
		check(uncommitted.data.items.values()[0].has("catalog_record") and not uncommitted.data.equipment_runtime.has(RULES.RUNTIME_MARK), "commit blocked: everything resident")
		check(bake_bytes()["equipment_rules"].is_empty(), "commit blocked: no bake written")
		same("commit blocked: accessors", accessors(uncommitted), reference_reads)
	uncommitted = null
	clear_bakes()
	# 9. Rejections are the same rejection.
	var broken: Dictionary = fixture(10)
	(broken.reader as FakeRows).tables.erase("ItemBlessCode")
	same("missing table: same problem", compile_new(broken, "rules-cold-broken"), compile_old(broken, "rules-cold-broken"))
	broken = fixture(10)
	(broken.reader as FakeRows).tables.BonusType = ((broken.reader as FakeRows).tables.BonusType as Array).filter(func(row: Dictionary) -> bool: return int(row.ID) != 1003)
	var rejected_new: Variant = compile_new(broken, "rules-cold-broken")
	same("unusable effect row: same problem", rejected_new, compile_old(broken, "rules-cold-broken"))
	check(rejected_new is String and not (rejected_new as String).is_empty(), "unusable effect row: rejected with a problem")
	check(bake_bytes()["equipment_rules_catalog_records"].is_empty() and bake_bytes()["equipment_rules_runtime"].is_empty(), "unusable effect row: no record file is left")
	check(not FileAccess.file_exists(BAKE.ROOT + "/equipment_rules_runtime.bin.part") and not FileAccess.file_exists(BAKE.ROOT + "/equipment_rules_catalog_records.bin.part"), "unusable effect row: no partial file is left")
	broken = fixture(10)
	(broken.reader as FakeRows).tables.LuckyBagEntityView[1].Probability = 5.0
	same("box contract: same problem", compile_new(broken, "rules-cold-broken"), compile_old(broken, "rules-cold-broken"))
	clear_bakes()
	# 10. A big table in the reader's row-store form (rows with differing keys).
	var rowstore: Dictionary = fixture(20)
	for table: String in ["ItemBonus","Bonus","ItemClass","ItemCraftInput","LuckyBagEntityView","DateTimes_Korean"]: (rowstore.reader as FakeRows).row_store[table] = true
	compare_models("row-store tables", compile_new(rowstore, "rules-cold-rowstore"), compile_old(rowstore, "rules-cold-rowstore"))
	clear_bakes()

func _packed_records() -> void:
	var store = PACKED.new()
	var records: Array = [
		{"name": "a", "source": "x", "n": 1.0, "flag": true, "list": [1.0, "two", {"k": null}], "nested": {"a": [1.0]}},
		{"name": "b", "source": "x", "n": 2.5, "flag": false, "list": [], "nested": {"a": [1.0]}},
		{"name": "c", "source": "x", "n": 3, "flag": false, "list": [], "nested": {"a": [1.0]}},
		{"source": "x", "name": "d", "n": 4.0, "flag": true, "list": [], "nested": {}},
		{}, {"only": null}, "not a record", 17, null, {1: "non-string key"},
		{"name": "e", "source": "x", "n": NAN, "flag": true, "list": [[[]]], "nested": {"deep": {"deeper": ["x"]}}}]
	for round: int in 3:
		for record: Variant in records: store.add(record if round != 1 else (record.duplicate(true) if record is Dictionary else record), round != 2)
	var equal: bool = store.size() == records.size() * 3
	for handle: int in store.size():
		var expected: Variant = records[handle % records.size()]
		var fetched: Variant = store.fetch(handle)
		if typeof(fetched) != typeof(expected) or var_to_bytes(fetched) != var_to_bytes(expected): equal = false
		if expected is Dictionary and expected.has("name") and store.field(handle, "name") != expected.name: equal = false
		if store.field(handle, "absent", "default") != "default": equal = false
	check(equal, "packed records: fetch() returns each added record (keys, order, values, types)")
	check(store.shape_count() >= 4 and store.packed_count() < store.size(), "packed records: shapes shared, unpackable records kept as they are")
	var first: Dictionary = store.fetch(0)
	(first.list as Array).append("changed")
	(first.nested as Dictionary)["changed"] = true
	check(var_to_bytes(store.fetch(0)) == var_to_bytes(records[0]) and var_to_bytes(store.fetch(1)) == var_to_bytes(records[1]), "packed records: a fetched record is independent of the store")

func _stream_and_runtime_units() -> void:
	# Plain values: the streamed round trip is unchanged (bytes, hash, parse).
	var value: Dictionary = {"b": [1, 2.5, "x", null, true, {"z": [], "a": {}}], "a": {"k": {"deep": [1, [2, [3]]]}, "": 0}, "한글": "값", "empty": {}, "list": []}
	for depth: int in [0, 1, 2, 3, 5]:
		var new_hash := HashingContext.new(); new_hash.start(HashingContext.HASH_SHA256)
		var old_hash := HashingContext.new(); old_hash.start(HashingContext.HASH_SHA256)
		var new_size: Array = [0]
		var old_size: Array = [0]
		var new_parsed: Variant = PROJECTION.stream_round_trip(value, new_hash, depth, new_size)
		var old_parsed: Variant = LEGACY_PROJECTION.stream_round_trip(value, old_hash, depth, old_size)
		check(var_to_bytes(new_parsed) == var_to_bytes(old_parsed) and new_size == old_size and new_hash.finish() == old_hash.finish(), "stream: plain value unchanged at depth "+str(depth))
	# A Part serializes as the Dictionary of its entries.
	var entries: Dictionary = {"10": {"v": 1}, "9": {"v": [2]}, "b": {}, "a": {"skip": true}, "2": {"v": "x"}}
	var part := PROJECTION.Part.new()
	part.name = "unit"
	part.keys = entries.keys()
	var alive: Array = [0, 0]
	part.make = func(key: String) -> Variant:
		return PROJECTION.SKIP if entries[key].has("skip") else entries[key]
	part.take = func(_key: String, copy: Variant) -> Variant:
		alive[0] += 1
		return PROJECTION.SKIP if copy.is_empty() else copy
	var kept: Dictionary = entries.duplicate(true)
	kept.erase("a")
	var part_hash := HashingContext.new(); part_hash.start(HashingContext.HASH_SHA256)
	var plain_hash := HashingContext.new(); plain_hash.start(HashingContext.HASH_SHA256)
	var part_size: Array = [0]
	var plain_size: Array = [0]
	var part_parsed: Variant = PROJECTION.stream_round_trip({"x": 1, "part": part, "y": [part.name]}, part_hash, 3, part_size)
	var plain_parsed: Variant = LEGACY_PROJECTION.stream_round_trip({"x": 1, "part": kept, "y": ["unit"]}, plain_hash, 3, plain_size)
	check(part_size == plain_size and part_hash.finish() == plain_hash.finish(), "stream: a part has the bytes of its entries")
	(plain_parsed.part as Dictionary).erase("b")
	check(var_to_bytes(part_parsed) == var_to_bytes(plain_parsed) and part.count == 4 and alive[0] == 4, "stream: take() decides what the parsed model keeps")
	part.make = func(key: String) -> Variant:
		return PROJECTION.FAIL if key == "9" else entries[key]
	var failed_size: Array = [0]
	var failed_hash := HashingContext.new(); failed_hash.start(HashingContext.HASH_SHA256)
	check(PROJECTION.stream_round_trip({"part": part}, failed_hash, 3, failed_size) == null and int(failed_size[0]) < 0, "stream: a failed entry stops the stream")
	part.make = Callable(); part.take = Callable()
	# The per-item runtime split equals the former whole build.
	var data: Dictionary = fixture(30)
	var reader: FakeRows = data.reader
	var tables: Dictionary = {}
	for name: String in ["BonusType","InvokeOption","SpecialResistanceType","ItemBlessBonus"]: tables[name] = reader.rows(name)
	var bonuses: Dictionary = {}
	for row: Dictionary in reader.rows("Bonus"): bonuses[str(int(row.ID))] = row
	var groups: Dictionary = {}
	for row: Dictionary in reader.rows("ItemEnchantBonus"):
		if not groups.has(int(row.ItemEnchantBonusGroupID)): groups[int(row.ItemEnchantBonusGroupID)] = []
		groups[int(row.ItemEnchantBonusGroupID)].append(row)
	var bound: Dictionary = {}
	var index: int = 0
	for row: Dictionary in reader.rows("ItemClass"):
		index += 1
		var effects: Array = []
		effects.append_array(groups.get(index % 9 + 1, []))
		if index % 4 == 0: effects.append_array(groups.get((index + 2) % 9 + 1, []))
		bound[str(int(row.ID))] = {"item_class": row, "catalog_record": {"slot": ["weapon","material","helmet",""][index % 4], "name": "n"}, "enchant_effects": effects}
	var new_builder = ENCHANTMENT.new()
	var old_builder = LEGACY_ENCHANTMENT.new()
	var new_runtime: Dictionary = new_builder.build(tables, bound, bonuses)
	var old_runtime: Dictionary = old_builder.build(tables, bound, bonuses)
	check(not old_runtime.is_empty() and var_to_bytes(new_runtime) == var_to_bytes(old_runtime) and new_builder.problem == old_builder.problem, "runtime: build() equals the former build ("+str(old_runtime.size())+" items)")
	bonuses.erase(bonuses.keys()[3])
	check(var_to_bytes(new_builder.build(tables, bound, bonuses)) == var_to_bytes(old_builder.build(tables, bound, bonuses)) and new_builder.problem == old_builder.problem and not str(old_builder.problem).is_empty(), "runtime: same rejection ("+str(old_builder.problem)+")")
