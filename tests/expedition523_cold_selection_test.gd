extends SceneTree
## Standalone, synthetic (no original): the expedition cold projection that
## reads only the rows reachable from Spot/Reward must equal the former
## whole-table filter (kept verbatim below as LEGACY) table by table, row by
## row, in order and value type, and must reject the same inputs with the same
## error. The fake source mirrors current523_definition_rows' public reader
## API (rows / rows_matching / integer_field / column / row_count / row_at),
## including column-packed tables, row-store tables and JSON float numbers.

const Catalog = preload("res://scripts/expedition/source_catalog.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)

## Reader double. Uniform tables (every row has the same keys) behave like
## the packed column store, others like its "rows" fallback store.
class FakeRows extends RefCounted:
	var tables: Dictionary = {}
	var full_reads: Dictionary = {}
	func add(table: String, rows: Array) -> void: tables[table] = rows
	func _uniform(rows: Array) -> bool:
		if rows.is_empty(): return true
		var keys: Array = (rows[0] as Dictionary).keys()
		for row: Dictionary in rows:
			if row.size() != keys.size(): return false
			for key: Variant in keys: if not row.has(key): return false
		return true
	func _integer(value: Variant) -> bool:
		return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0
	func rows(table: String) -> Array[Dictionary]:
		full_reads[table] = int(full_reads.get(table, 0)) + 1
		var result: Array[Dictionary] = []
		for row: Dictionary in tables.get(table, []): result.append(row.duplicate(true))
		return result
	func row_count(table: String) -> int: return (tables.get(table, []) as Array).size()
	func row_at(table: String, index: int) -> Dictionary:
		var rows: Array = tables.get(table, [])
		return (rows[index] as Dictionary).duplicate(true) if index >= 0 and index < rows.size() else {}
	func column(table: String, field: String) -> Variant:
		var rows: Array = tables.get(table, [])
		if rows.is_empty() or (_uniform(rows) and not (rows[0] as Dictionary).has(field)): return []
		var values: Array = []
		for row: Dictionary in rows:
			if not row.has(field): return []
			values.append(row[field])
		if not _uniform(rows): return values
		var floats := true
		for value: Variant in values: if typeof(value) != TYPE_FLOAT: floats = false
		return PackedFloat64Array(values) if floats else values
	func integer_field(table: String, field: String) -> bool:
		var rows: Array = tables.get(table, [])
		if rows.is_empty() or not _uniform(rows): return false
		var values: Variant = column(table, field)
		if not values is PackedFloat64Array: return false
		for value: float in values: if not _integer(value): return false
		return true
	func rows_matching(table: String, field: String, ids: Dictionary) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		if ids.is_empty(): return result
		for row: Dictionary in tables.get(table, []):
			var value: Variant = row.get(field)
			if _integer(value) and ids.has(int(value)): result.append(row.duplicate(true))
		return result

## The former _original_projection(), verbatim except SOURCE_ROWS -> source
## and `error` returned alongside.
static func _source_selection(rows: Array, field: String, ids: Dictionary) -> Array:
	var selected: Array = []
	for row: Dictionary in rows:
		if ids.has(int(row.get(field,-1))): selected.append(row)
	return selected

static func legacy(source: Variant) -> Array:
	var P: String = Catalog.P
	var t: Dictionary = {}
	for suffix: String in Catalog.ORIGINAL_CORE_SUFFIXES: t[P+suffix] = source.rows(P+suffix)
	for name: String in Catalog.ORIGINAL_SYNERGY + ["Grade","BuffCard"]: t[name] = source.rows(name)
	var constants: Array = []
	for row: Dictionary in source.rows("ConstantData"):
		if str(row.Name).contains("Expedition") or row.Name=="PolymorphDispatchLevel": constants.append(row)
	t["ConstantData"] = constants
	var reward_ids: Dictionary = {}
	var completion_reward_ids: Dictionary = {}
	for row: Dictionary in t[P+"SpotReward"]: reward_ids[int(row.RewardID)] = true
	for row: Dictionary in t[P+"CompleteRewardView"]:
		reward_ids[int(row.RewardID)] = true
		completion_reward_ids[int(row.RewardID)] = true
	t["Reward"] = _source_selection(source.rows("Reward"),"ID",reward_ids)
	var item_ids: Dictionary = {}
	var completion_items: Dictionary = {}
	for row: Dictionary in t.Reward:
		if row.RewardTypeID==2: item_ids[int(row.RewardClassID)] = true
		if completion_reward_ids.has(int(row.ID)): completion_items[int(row.RewardClassID)] = true
	var all_item_bonus: Array = source.rows("ItemBonus")
	var all_bonus: Array = source.rows("Bonus")
	var all_types: Array = source.rows("BonusType")
	var bonus_index: Dictionary = {}
	for row: Dictionary in all_bonus:
		if bonus_index.has(int(row.ID)):
			return [{}, "원본 탐험 보너스 ID가 중복됩니다."]
		bonus_index[int(row.ID)] = row
	var bag_types: Dictionary = {}
	for row: Dictionary in all_types:
		if row.Name=="LuckyBagClassID" and row.UnitID==29: bag_types[int(row.ID)] = true
	var item_bonus: Array = _source_selection(all_item_bonus,"ItemClassID",item_ids)
	var bag_ids: Dictionary = {}
	for link: Dictionary in item_bonus:
		if not completion_items.has(int(link.ItemClassID)): continue
		var bonus: Dictionary = bonus_index.get(int(link.BonusID),{})
		if bonus.is_empty():
			return [{}, "원본 탐험 상자 보너스 연결이 없습니다."]
		if not bag_types.has(int(bonus.BonusTypeID)): continue
		var value: Variant = bonus.get("Value")
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value!=floorf(float(value)) or absf(float(value))>9007199254740991.0:
			return [{}, "원본 탐험 상자 참조가 정수가 아닙니다."]
		bag_ids[int(value)] = true
	t["LuckyBagClass"] = _source_selection(source.rows("LuckyBagClass"),"ID",bag_ids)
	t["LuckyBagEntityView"] = _source_selection(source.rows("LuckyBagEntityView"),"LuckyBagClassID",bag_ids)
	for row: Dictionary in t.LuckyBagEntityView: item_ids[int(row.ItemClassID)] = true
	t["ItemClass"] = _source_selection(source.rows("ItemClass"),"ID",item_ids)
	t["ItemBonus"] = _source_selection(all_item_bonus,"ItemClassID",item_ids)
	var bonus_ids: Dictionary = {}
	for row: Dictionary in t.ItemBonus + t.BuffCardExpeditionSynergyBonus: bonus_ids[int(row.BonusID)] = true
	t["Bonus"] = _source_selection(all_bonus,"ID",bonus_ids)
	var type_ids: Dictionary = {}
	for row: Dictionary in t.Bonus: type_ids[int(row.BonusTypeID)] = true
	t["BonusType"] = _source_selection(all_types,"ID",type_ids)
	var currency_ids: Dictionary = {}
	for row: Dictionary in t[P+"Spot"]: currency_ids[int(row.ExpeditionCostCurrencyID)] = true
	for row: Dictionary in t[P+"Buff"]: currency_ids[int(row.CostCurrencyID)] = true
	t["Currency"] = _source_selection(source.rows("Currency"),"ID",currency_ids)
	t["CurrencyUnitClass"] = _source_selection(source.rows("CurrencyUnitClass"),"CurrencyID",currency_ids)
	return [t, ""]

## JSON numbers are floats, exactly as the original tables are read.
func j(text: String) -> Array:
	return JSON.parse_string(text)

func fixture() -> FakeRows:
	var source := FakeRows.new()
	var X := "MagicDollExpedition"
	source.add(X+"Spot", j('[{"ID":2,"BuffCardDeckID":2,"ExpeditionCostCurrencyID":7},{"ID":1,"BuffCardDeckID":2,"ExpeditionCostCurrencyID":8}]'))
	for suffix: String in ["SpotAsset","Group","SpotRewardType","SpotEvent","EventView","Bonus","BonusType","Monster"]:
		source.add(X+suffix, j('[{"ID":1,"Name":"%s"}]' % suffix))
	source.add(X+"Buff", j('[{"ID":5,"CostCurrencyID":9},{"ID":6,"CostCurrencyID":7}]'))
	source.add(X+"SpotReward", j('[{"ID":1,"RewardID":30},{"ID":2,"RewardID":10},{"ID":3,"RewardID":31}]'))
	source.add(X+"CompleteRewardView", j('[{"ID":1,"RewardID":20},{"ID":2,"RewardID":21},{"ID":3,"RewardID":22}]'))
	source.add("BuffCardExpeditionSynergy", j('[{"ID":1}]'))
	source.add("BuffCardExpeditionSynergyCards", j('[{"ID":1,"BuffCardDispatchSynergyID":1}]'))
	source.add("BuffCardExpeditionSynergyBonus", j('[{"ID":1,"BuffCardDispatchSynergyID":1,"BonusID":900}]'))
	source.add("Grade", j('[{"ID":1,"GradeValue":1}]'))
	source.add("BuffCard", j('[{"ID":1,"BuffCardDeckID":2,"GradeID":1}]'))
	# Row store (non-uniform keys): Name lookup goes through column() of rows.
	source.add("ConstantData", j('[{"ID":1,"Name":"ExpeditionMax"},{"ID":2,"Name":"Other","Extra":1},{"ID":3,"Name":"PolymorphDispatchLevel"},{"ID":4,"Name":"MaxExpeditionSlots"}]'))
	# Out-of-order IDs; 21 rewards a non-item type; 31 is a non-completion item.
	source.add("Reward", j('[{"ID":31,"RewardTypeID":2,"RewardClassID":104},{"ID":99,"RewardTypeID":2,"RewardClassID":555},{"ID":20,"RewardTypeID":2,"RewardClassID":100},{"ID":10,"RewardTypeID":2,"RewardClassID":101},{"ID":21,"RewardTypeID":1,"RewardClassID":102},{"ID":22,"RewardTypeID":2,"RewardClassID":103},{"ID":30,"RewardTypeID":2,"RewardClassID":100}]'))
	# Two links per completion item, one stat bonus (type 1), one bag (type 3).
	source.add("ItemBonus", j('[{"ID":1,"ItemClassID":100,"BonusID":502},{"ID":2,"ItemClassID":555,"BonusID":501},{"ID":3,"ItemClassID":100,"BonusID":500},{"ID":4,"ItemClassID":104,"BonusID":503},{"ID":5,"ItemClassID":103,"BonusID":504},{"ID":6,"ItemClassID":300,"BonusID":505},{"ID":7,"ItemClassID":102,"BonusID":506}]'))
	source.add("Bonus", j('[{"ID":506,"BonusTypeID":3,"Value":42},{"ID":505,"BonusTypeID":1,"Value":1},{"ID":500,"BonusTypeID":3,"Value":70},{"ID":501,"BonusTypeID":1,"Value":5},{"ID":502,"BonusTypeID":1,"Value":2.5},{"ID":503,"BonusTypeID":3,"Value":71},{"ID":504,"BonusTypeID":4,"Value":72},{"ID":900,"BonusTypeID":5,"Value":5},{"ID":901,"BonusTypeID":1,"Value":0}]'))
	source.add("BonusType", j('[{"ID":5,"Name":"Buff","UnitID":1},{"ID":4,"Name":"LuckyBagClassID","UnitID":28},{"ID":3,"Name":"LuckyBagClassID","UnitID":29},{"ID":1,"Name":"Stat","UnitID":1},{"ID":9,"Name":"LuckyBagClassID","UnitID":29}]'))
	source.add("LuckyBagClass", j('[{"ID":71},{"ID":70},{"ID":72}]'))
	# LuckyBagClassID column holds a non-integer value -> generic column path.
	source.add("LuckyBagEntityView", j('[{"ID":1,"LuckyBagClassID":70,"ItemClassID":300,"Probability":60},{"ID":2,"LuckyBagClassID":71,"ItemClassID":301,"Probability":40},{"ID":3,"LuckyBagClassID":70.5,"ItemClassID":302,"Probability":40},{"ID":4,"LuckyBagClassID":70,"ItemClassID":301,"Probability":40}]'))
	source.add("ItemClass", j('[{"ID":301,"Name":"b"},{"ID":100,"Name":"box"},{"ID":300,"Name":"a"},{"ID":101,"Name":"c"},{"ID":104,"Name":"d"},{"ID":103,"Name":"e"},{"ID":999,"Name":"z"}]'))
	source.add("Currency", j('[{"ID":9},{"ID":8},{"ID":7},{"ID":6}]'))
	# Some row lacks CurrencyID -> row-at-a-time path with -1.
	source.add("CurrencyUnitClass", j('[{"ID":1,"CurrencyID":7},{"ID":2},{"ID":3,"CurrencyID":9}]'))
	return source

func shape(value: Variant) -> Variant:
	# Values with their Variant types and typed-array element types.
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value: out[str(key)] = shape(value[key])
		return {"t": TYPE_DICTIONARY, "v": out}
	if value is Array:
		var out: Array = []
		for item: Variant in value: out.append(shape(item))
		return {"t": TYPE_ARRAY, "typed": (value as Array).get_typed_builtin(), "v": out}
	return {"t": typeof(value), "v": value}

func compare(name: String, source: FakeRows) -> void:
	var expected: Array = legacy(source)
	var catalog := Catalog.new()
	source.full_reads.clear()
	var actual: Dictionary = catalog._original_projection(source)
	var reads: Dictionary = source.full_reads.duplicate()
	check(JSON.stringify(shape(actual), "", true) == JSON.stringify(shape(expected[0]), "", true), name + ": same tables, rows, order and value types")
	check((catalog.error if actual.is_empty() else "") == expected[1], name + ": same rejection " + str(expected[1]) + " / " + str(catalog.error))
	if not actual.is_empty():
		check(actual.keys() == (expected[0] as Dictionary).keys(), name + ": same table order")
	for table: String in ["ItemBonus","Bonus","BonusType","ItemClass","LuckyBagClass","LuckyBagEntityView","Reward","Currency","CurrencyUnitClass"]:
		check(not reads.has(table), name + ": no whole-table rows(" + table + ")")

func _initialize() -> void:
	var base := fixture()
	var expected: Dictionary = legacy(base)[0]
	check(not expected.is_empty() and expected.LuckyBagEntityView.size() == 3 and expected.ItemClass.size() == 6, "fixture reaches boxes and box items")
	check(expected.Bonus.size() == 6 and expected.ItemBonus.size() == 5 and expected.BonusType.size() == 4 and expected.Currency.size() == 3 and expected.CurrencyUnitClass.size() == 2, "fixture selects across all paths")
	compare("normal", base)
	var duplicate := fixture()
	var bonus: Array = duplicate.tables.Bonus
	bonus.append({"ID": 999.0, "BonusTypeID": 1.0, "Value": 0.0})
	bonus.append({"ID": 999.0, "BonusTypeID": 1.0, "Value": 1.0})
	compare("duplicate unreferenced Bonus ID", duplicate)
	var truncated := fixture()
	(truncated.tables.Bonus as Array).append({"ID": 901.5, "BonusTypeID": 1.0, "Value": 0.0})
	compare("duplicate Bonus ID after int()", truncated)
	var missing := fixture()
	missing.tables.Bonus = (missing.tables.Bonus as Array).filter(func(row: Dictionary) -> bool: return int(row.ID) != 500)
	compare("missing completion bonus", missing)
	var fractional := fixture()
	for row: Dictionary in fractional.tables.Bonus:
		if int(row.ID) == 500: row.Value = 70.25
	compare("non-integer box reference", fractional)
	var unused_fraction := fixture()
	for row: Dictionary in unused_fraction.tables.Bonus:
		if int(row.ID) == 504: row.Value = 1.5 # type 4 is not a box type: ignored
	compare("non-box fractional value ignored", unused_fraction)
	var no_boxes := fixture()
	no_boxes.tables.BonusType = j('[{"ID":1,"Name":"Stat","UnitID":1},{"ID":3,"Name":"Other","UnitID":29}]')
	compare("no box bonus types", no_boxes)
	var empty := fixture()
	empty.tables.ItemBonus = []
	empty.tables.Bonus = []
	compare("empty link tables", empty)
	var result := {"checks": checks, "failures": failures}
	print("EXPEDITION523_COLD_SELECTION_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
