extends RefCounted
## Reads an owner-supplied plaintext content ZIP. No source rows ship with this code.
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const TABLES = ["HalfElixirBonus", "HalfElixirBonusExtend", "HalfElixirExtendCost", "Bonus", "BonusType", "BonusApplicationType", "SpecialResistanceType", "UIUnit", "ServerLimit", "ConstantData", "ConstantDataByServer", "ContentsControl", "ItemClass", "ItemCategory", "ItemBonus", "Currency", "CurrencyUnitClass", "DescData_Korean", "BuffClass", "BuffGroup", "ElixirCraft", "ElixirExtendCost", "ElixirStatExtend", "Grade", "ItemCraftInput", "ItemCraftOutputView", "ItemCraftView", "UIStaticTextData_Korean", "UITextData_Korean", "Unit", "UseDesc"]
const DIRECT = {"HPPlus":"hpFlat", "CarryPlus":"weightBonus", "MeleeDamage":"melee_damage", "RangeDamage":"ranged_damage", "MagicDamage":"magic_damage", "MeleeHit":"melee_accuracy", "RangeHit":"ranged_accuracy", "ArmorClass":"def", "MagicResist":"mr", "DamageReduction":"damage_reduction", "PierceMeleeEvasion":"melee_evasion_ignore", "PierceRangeEvasion":"ranged_evasion_ignore", "MagicHit":"magic_accuracy", "SpellPower":"sp", "PVEMeleeAdditionDamage":"pve_melee_damage", "PVERangeAdditionDamage":"pve_ranged_damage", "PVEMagicAdditionDamage":"pve_magic_damage", "PVEMeleeHit":"pve_melee_accuracy", "PVERangeHit":"pve_ranged_accuracy", "PVEMagicHit":"pve_magic_accuracy"}
const CONDITIONAL = ["PVPDamageReduction", "PVEDamageReduction", "PierceMagicShieldPercent", "MeleeDamageReductionPercent", "RangeDamageReductionPercent", "MagicDamageReductionPercent", "PVPDamageReductionPercent", "ElementalCriticalResistance", "PoisonDamageReductionPercent", "ElementalDamageReduction", "PVPMeleeEvasion", "PVPRangeEvasion", "PVPPierceMeleeEvasion", "PVPPierceRangeEvasion", "SpecialResistance", "HitSpecialResistance"]
var problem: String = ""
var sha: String = ""
var rules: Dictionary = {}
var extensions: Dictionary = {}
var costs: Dictionary = {}
var memberships: Dictionary = {}
var pairs: Array = []
var constants: Dictionary = {}
var overrides: Array = []
var gates: Dictionary = {}
var items: Dictionary = {}
var charges: Dictionary = {}
var resets: Dictionary = {}
var currencies: Dictionary = {}
var audits: Dictionary = {}

func fail(message: String) -> bool:
	problem = message
	return false

func parse(bytes: PackedByteArray) -> Variant:
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8().trim_prefix("\ufeff")) != OK: return null
	return parser.data

func load_zip(path: String) -> bool:
	# The verified bundled 523 archive is read through the cold row reader:
	# only the rows configure() reads, never every table parsed at once.
	if FileAccess.get_sha256(path) == DEFINITIONS.SOURCE_SHA and not DEFINITIONS.archive_path().is_empty(): return load_definitions()
	return load_zip_whole(path)

## Every table of `path` parsed whole (any other owner-supplied 523 ZIP).
func load_zip_whole(path: String) -> bool:
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return fail("원본 ZIP을 열 수 없습니다.")
	var listing := zip.get_files()
	var content_count: int = 0
	for name: String in listing:
		if name.begins_with("content/") and name.ends_with(".json"): content_count += 1
	var index: Variant = parse(zip.read_file("index.json"))
	if content_count != 1065 or not index is Array: zip.close(); return fail("523 전체 Content ZIP이 필요합니다.")
	var hashes: Dictionary = {}
	for entry: Variant in index:
		if not entry is Dictionary or int(entry.get("version", 0)) != 523: zip.close(); return fail("다른 원본 버전을 혼용할 수 없습니다.")
		var name: String = str(entry.get("path", ""))
		if hashes.has(name): zip.close(); return fail("중복된 표 경로입니다.")
		hashes[name] = entry
	var tables: Dictionary = {}
	for table: String in TABLES:
		var name: String = "content/" + table + ".json"
		if not listing.has(name) or not hashes.has(name): zip.close(); return fail("필수 표가 없습니다: " + table)
		var bytes := zip.read_file(name)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
		if bytes.size() != int(hashes[name].bytes) or hash.finish().hex_encode() != str(hashes[name].sha256): zip.close(); return fail("원본 표의 해시가 다릅니다: " + table)
		var parsed: Variant = parse(bytes)
		if not parsed is Dictionary or not parsed.get("rows") is Array: zip.close(); return fail("원본 표의 구조가 다릅니다: " + table)
		tables[table] = parsed.rows
	zip.close()
	sha = FileAccess.get_sha256(path)
	return configure(tables)

## Tables configure() reads whole (all small in 523).
const WHOLE_TABLES = ["HalfElixirBonus", "HalfElixirBonusExtend", "HalfElixirExtendCost", "BonusType", "BonusApplicationType", "SpecialResistanceType", "UIUnit", "ServerLimit", "ConstantData", "ConstantDataByServer", "ContentsControl", "ItemCategory", "Currency", "CurrencyUnitClass"]
## Tables configure() only audits by row count (and ItemCraft* by ItemClassID).
const COUNTED_TABLES = ["BuffClass", "BuffGroup", "ElixirCraft", "ElixirExtendCost", "ElixirStatExtend", "Grade", "ItemCraftInput", "ItemCraftOutputView", "ItemCraftView", "UIStaticTextData_Korean", "UITextData_Korean", "Unit", "UseDesc"]
const SUPPLY_TABLES = ["ItemCraftInput", "ItemCraftOutputView", "ItemCraftView"]
const CATEGORY_NAMES = ["HalfElixirRecharger", "HalfElixirInitializer"]

## The same configure() input from the verified 523 definitions archive
## (current523_definition_rows), like monsterbook523's cold projection: the
## large tables (Bonus, ItemClass, ItemBonus, DescData_Korean) hold only the
## rows configure() reads, and counted tables are not materialised. The
## archive SHA is verified by the definitions reader as a whole.
func load_definitions() -> bool:
	var path: String = DEFINITIONS.archive_path()
	if path.is_empty(): return fail(DEFINITIONS.problem())
	var t: Dictionary = {}
	var counts: Dictionary = {}
	for table: String in WHOLE_TABLES:
		t[table] = DEFINITIONS.rows(table)
		if (t[table] as Array).is_empty(): return fail("필수 표가 없습니다: " + table)
	for table: String in COUNTED_TABLES + ["Bonus", "ItemClass", "ItemBonus", "DescData_Korean"]:
		counts[table] = DEFINITIONS.row_count(table)
		if int(counts[table]) <= 0: return fail("필수 표가 없습니다: " + table)
	# ItemClass: every 하프 엘릭서 charger/initializer and every item unit of a currency.
	var categories: Dictionary = {}
	for row: Dictionary in t.ItemCategory:
		if str(row.get("Name", "")) in CATEGORY_NAMES: categories[int(row.ID)] = true
	var item_ids: Dictionary = {}
	for row: Dictionary in t.CurrencyUnitClass:
		if int(row.UnitID) == 4: item_ids[int(row.ClassID)] = true
	var items_rows: Array[Dictionary] = DEFINITIONS.rows_matching("ItemClass", "CategoryID", categories)
	var seen: Dictionary = {}
	for row: Dictionary in items_rows: seen[int(row.ID)] = true
	for row: Dictionary in DEFINITIONS.rows_matching("ItemClass", "ID", item_ids):
		if seen.has(int(row.ID)): continue
		seen[int(row.ID)] = true
		items_rows.append(row)
	t.ItemClass = items_rows
	# ItemBonus links of those items only (the charge amount and DeleteTime gate).
	t.ItemBonus = DEFINITIONS.rows_matching("ItemBonus", "ItemClassID", seen)
	var bonus_ids: Dictionary = {}
	for row: Dictionary in t.HalfElixirBonus: bonus_ids[int(row.BonusID)] = true
	for row: Dictionary in t.ItemBonus: bonus_ids[int(row.BonusID)] = true
	t.Bonus = DEFINITIONS.rows_matching("Bonus", "ID", bonus_ids)
	# Descriptions: the bonus types and items configure() can name.
	var type_ids: Dictionary = {}
	for row: Dictionary in t.Bonus: type_ids[int(row.BonusTypeID)] = true
	var desc_ids: Dictionary = {}
	for row: Dictionary in t.BonusType:
		if type_ids.has(int(row.ID)): desc_ids[int(row.get("DescID", 0))] = true
	for row: Dictionary in t.ItemClass: desc_ids[int(row.get("DescID", 0))] = true
	t.DescData_Korean = DEFINITIONS.rows_matching("DescData_Korean", "ID", desc_ids)
	t["_row_counts"] = counts
	sha = FileAccess.get_sha256(path)
	return configure(t)

func by_id(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var key := str(int(row.ID))
		if result.has(key): problem = "고유 표에 중복 ID가 있습니다."
		result[key] = row
	return result

func configure(t: Dictionary) -> bool:
	problem = ""; rules.clear(); extensions.clear(); costs.clear(); memberships.clear(); pairs.clear(); constants.clear(); gates.clear(); charges.clear(); resets.clear(); currencies.clear()
	if t.HalfElixirBonus.size() != 142 or t.HalfElixirBonusExtend.size() != 1430 or t.HalfElixirExtendCost.size() != 10: return fail("523 하프 엘릭서 표의 전체 범위가 다릅니다.")
	var bonus := by_id(t.Bonus)
	var types := by_id(t.BonusType)
	var applications := by_id(t.BonusApplicationType)
	var targets := by_id(t.SpecialResistanceType)
	var units: Dictionary = {}
	for row: Dictionary in t.UIUnit: units[str(int(row.UnitID))] = row
	var needed_desc: Dictionary = {}
	for raw: Dictionary in t.HalfElixirBonus:
		var id := str(int(raw.ID))
		if rules.has(id) or not bonus.has(str(int(raw.BonusID))): return fail("투자 규칙의 보너스 참조가 잘못됐습니다.")
		var b: Dictionary = bonus[str(int(raw.BonusID))]
		var typ: Dictionary = types.get(str(int(b.BonusTypeID)), {})
		var app: Dictionary = applications.get(str(int(b.BonusApplicationTypeID)), {})
		var target: Dictionary = targets.get(str(int(b.BonusApplicationTargetID)), {})
		var name: String = str(typ.get("Name", ""))
		if not DIRECT.has(name) and not CONDITIONAL.has(name): return fail("소비 어댑터가 없는 보너스입니다: " + name)
		if int(raw.Cost) <= 0 or int(raw.DefaultMaxPoint) < 0 or int(raw.DefaultMaxPoint) % int(raw.Cost) != 0: return fail("투자 비용이나 한도가 잘못됐습니다.")
		if name in ["SpecialResistance", "HitSpecialResistance"] and (str(app.get("Name", "")) != "SpecialResistanceType" or target.is_empty()): return fail("저항 대상이 누락됐습니다.")
		var unit: Dictionary = units.get(str(int(typ.get("UnitID", -1))), {})
		var denominator: float = float(unit.get("Denominator", 0))
		if denominator <= 0: denominator = 1.0
		rules[id] = {"raw":raw.duplicate(true), "bonus":b.duplicate(true), "type":name, "target":str(target.get("Name", "")), "application":str(app.get("Name", "")), "unit":int(typ.get("UnitID", 0)), "divisor":denominator, "desc":int(typ.get("DescID", 0)), "label":name}
		needed_desc[int(typ.get("DescID", 0))] = true
	for raw: Dictionary in t.HalfElixirBonusExtend:
		var id := str(int(raw.HalfElixirBonusID))
		var key := id + ":" + str(int(raw.ElixirExtendPoint))
		if not rules.has(id) or extensions.has(key) or int(raw.BonusMaxPoint) < 0: return fail("확장 좌표가 중복되거나 잘못됐습니다.")
		extensions[key] = raw.duplicate(true)
	for raw: Dictionary in t.HalfElixirExtendCost:
		var before: int = int(raw.BeforeExtendPoint)
		if costs.has(before) or int(raw.AfterExtendPoint) != before + 5 or before < 0 or before > 45 or int(raw.Cost) < 0: return fail("확장 비용 단계가 잘못됐습니다.")
		costs[before] = raw.duplicate(true)
	for row: Dictionary in t.ServerLimit:
		var set_id := str(int(row.ServerLimitSetID))
		var pair := str(row.ServiceRegionCode) + ":" + str(int(row.WorldNo))
		if not memberships.has(set_id): memberships[set_id] = {}
		memberships[set_id][pair] = true
	var seen: Dictionary = {}
	var profiles: Dictionary = {}
	for set_id: String in memberships:
		for pair: String in memberships[set_id]:
			var selected := profile(pair)
			if selected.size() != 37: continue
			if seen.has(pair): continue
			seen[pair] = true; pairs.append(pair)
			var ids: Array = selected.keys(); ids.sort()
			profiles[JSON.stringify(ids)] = true
	for row: Dictionary in t.ConstantData: constants[str(row.Name)] = row
	overrides = t.ConstantDataByServer.duplicate(true)
	for row: Dictionary in t.ContentsControl: gates[str(row.Name)] = row
	items = by_id(t.ItemClass)
	var categories := by_id(t.ItemCategory)
	var expired: Dictionary = {}
	for row: Dictionary in t.ItemBonus:
		var b: Dictionary = bonus.get(str(int(row.BonusID)), {})
		var typ: Dictionary = types.get(str(int(b.get("BonusTypeID", -1))), {})
		var item: Dictionary = items.get(str(int(row.ItemClassID)), {})
		if str(typ.get("Name", "")) == "DeleteTime": expired[str(int(row.ItemClassID))] = true
		if str(typ.get("Name", "")) == "HalfElixirPoint" and not bool(row.IsPossession) and not item.is_empty():
			var category: Dictionary = categories.get(str(int(item.CategoryID)), {})
			if str(category.get("Name", "")) == "HalfElixirRecharger" and bool(category.get("IsConsumable", false)):
				charges[str(int(item.ID))] = {"raw":item, "amount":int(b.Value)}; needed_desc[int(item.DescID)] = true
	for id: String in items:
		var item: Dictionary = items[id]
		if str(categories.get(str(int(item.CategoryID)), {}).get("Name", "")) == "HalfElixirInitializer": resets[id] = {"raw":item}; needed_desc[int(item.DescID)] = true
	# Admission is resolved after every ItemBonus row, so a later DeleteTime
	# link protects chargers as well as initializers through the existing gate.
	for group: Dictionary in [charges,resets]:
		for id: String in group:
			var entry: Dictionary = group[id]
			var reasons: Array[String] = []
			var test: Variant = entry.raw.get("TestItem")
			if typeof(test) == TYPE_BOOL and test: reasons.append("source_TestItem_true")
			if expired.has(id): reasons.append("source_DeleteTime_declared")
			var declaration: Dictionary = DEFINITIONS.declared_exclusion("ItemClass",entry.raw) if sha == DEFINITIONS.SOURCE_SHA else {}
			if not declaration.is_empty():
				reasons.append("source_declared_exclusion")
				entry["source_exclusion"] = declaration
			entry["blocked"] = not reasons.is_empty()
			entry["blocked_reasons"] = reasons
	var currency_rows := by_id(t.Currency)
	for row: Dictionary in t.CurrencyUnitClass:
		var key: int = int(row.CurrencyID)
		if not currencies.has(key): currencies[key] = {"raw":currency_rows.get(str(key), {}), "members":[]}
		currencies[key].members.append(row.duplicate(true))
	for cost: Dictionary in costs.values():
		var currency: Dictionary = currencies.get(int(cost.CurrencyID), {})
		if currency.is_empty(): return fail("확장 재화의 원본 참조가 없습니다.")
		for member: Dictionary in currency.members:
			if int(member.UnitID) == 4 and items.has(str(int(member.ClassID))): needed_desc[int(items[str(int(member.ClassID))].DescID)] = true
	var descriptions: Dictionary = {}
	for row: Dictionary in t.DescData_Korean:
		if needed_desc.has(int(row.ID)): descriptions[int(row.ID)] = str(row.Description)
	for rule: Dictionary in rules.values(): rule.label = descriptions.get(rule.desc, rule.type)
	for group: Dictionary in [charges, resets]:
		for entry: Dictionary in group.values(): entry["name"] = descriptions.get(int(entry.raw.DescID), "")
	for currency: Dictionary in currencies.values():
		for member: Dictionary in currency.members:
			if int(member.UnitID) == 4 and items.has(str(int(member.ClassID))): member["name"] = descriptions.get(int(items[str(int(member.ClassID))].DescID), "")
	if not problem.is_empty(): return false
	# Audit complete supporting tables; crafting execution remains its own feature.
	var supply_ids: Dictionary = {}
	for id: String in charges: supply_ids[id] = true
	for id: String in resets: supply_ids[id] = true
	for cost: Dictionary in costs.values():
		var currency: Dictionary = currencies[int(cost.CurrencyID)]
		for entry: Dictionary in currency.members:
			if int(entry.UnitID) == 4: supply_ids[str(int(entry.ClassID))] = true
	var supply_audit: Dictionary = {}
	var counts: Dictionary = t.get("_row_counts", {})
	for table: String in SUPPLY_TABLES:
		var matched: int = 0
		if t.has(table):
			for row: Dictionary in t[table]:
				if supply_ids.has(str(int(row.ItemClassID))): matched += 1
		else:
			var wanted: Dictionary = {}
			for id: String in supply_ids: wanted[int(id)] = true
			matched = DEFINITIONS.rows_matching(table, "ItemClassID", wanted).size()
		supply_audit[table] = {"rows_read":int(counts.get(table, t.get(table, []).size())), "exact_item_references":matched, "execution_owner":"crafting"}
	var rows_read: Dictionary = {}
	for table: String in TABLES: rows_read[table] = int(counts.get(table, t.get(table, []).size()))
	pairs.sort()
	audits = {"rows_read":rows_read, "supply_references":supply_audit, "rules":rules.size(), "extension_coordinates":extensions.size(), "cost_steps":costs.size(), "world_pairs":pairs.size(), "profiles":profiles.size(), "charge_items":charges.size(), "source_rows_preserved_in_owner_zip":true}
	return profiles.size() == 4 and pairs.size() == 451 or fail("서버별 네 프로필이 원문과 일치하지 않습니다.")

func member(set_id: int, pair: String) -> bool:
	return set_id == 0 or memberships.get(str(set_id), {}).has(pair)

func profile(pair: String) -> Dictionary:
	var result: Dictionary = {}
	for id: String in rules:
		if member(int(rules[id].raw.ServerLimitSetID), pair): result[id] = rules[id]
	return result

func constant(name: String, pair: String) -> int:
	var base: Dictionary = constants.get(name, {})
	var value: int = int(base.get("Value", 0))
	var found: bool = false
	for row: Dictionary in overrides:
		if int(row.ConstantDataID) == int(base.get("ID", -1)) and member(int(row.ServerLimitSetID), pair):
			if found and value != int(row.Value): return -1
			value = int(row.Value); found = true
	return value

func enabled(name: String, pair: String) -> bool:
	var gate: Dictionary = gates.get(name, {})
	return bool(gate.get("Enable", false)) and member(int(gate.get("ServerLimitSetID", -1)), pair)

func cap(id: String, step: int) -> int:
	return int(rules[id].raw.DefaultMaxPoint) + int(extensions.get(id + ":" + str(step), {}).get("BonusMaxPoint", 0))

func effect(id: String, purchases: int) -> Dictionary:
	var rule: Dictionary = rules[id]
	return {"type":rule.type, "target":rule.target, "application":rule.application, "value":float(rule.bonus.Value) * purchases / float(rule.divisor), "raw_value":rule.bonus.Value, "purchases":purchases}
