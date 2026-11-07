extends RefCounted
## UNVERIFIED: the public fishing importer projection, read from held originals.
## Input admission only; session, exchange, reward and save policy stay owned
## by the existing services. No generated pack or prior card/monster input.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const TABLES = ["Fish","FishConstant","FishContest","FishContestRank","FishContestRankReward",
	"FishContestRule","FishContestRuleType","FishDistribution","FishMiniGameAI","FishMiniGameAIList",
	"FishMiniGameDifficulty","FishPoolProbability","FishSite","FishSize","FishStage","FishTerritory",
	"FishMiniGameAIType","FishPool","UIHiddenFish","ExchangeSystemConstant","ExchangeSystemInput",
	"ExchangeSystemInputBonus","ExchangeSystemInputBonusOutput","ExchangeSystemOutput","ExchangeSystemRule"]
const ITEM_FIELDS = ["ID","Name","GradeID","CategoryID","IsTradable","MaxStackAmount","TestItem","Cost"]
var problem: String = ""
var unavailable_source_definitions: Array = []
var source_exclusion_evidence: Array = []
var _raw: Dictionary = {}
var _metadata: Dictionary = {}
var _denied: Dictionary = {}
var _fatal: bool = false

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

func _unavailable(table: String, row: Dictionary, reason: String) -> void:
	unavailable_source_definitions.append({"table":table,"row":row,"reason":reason,"source_input_identity":SOURCE.identity()})

func _fail(reason: String) -> void:
	_fatal = true
	if problem.is_empty(): problem = reason

func _id(value: Variant) -> int:
	if not _integer(value) or int(value) < 0:
		_fail("invalid_integral_source_reference")
		return -1
	return int(value)

func _table_metadata(table: String) -> bool:
	if _metadata.has(table): return true
	var value: Dictionary = SOURCE.table_metadata(table)
	if value.get("version") != 523 or value.get("path") != "content/"+table+".json" or not _integer(value.get("row_count")) or int(value.row_count) < 0 or not value.get("sha256") is String or str(value.sha256).length() != 64:
		_fail("source_table_metadata_unavailable:"+table+":"+SOURCE.problem())
		return false
	_metadata[table] = value
	return true

func _table(table: String) -> Array:
	if _raw.has(table): return _raw[table]
	if not _table_metadata(table): return []
	var rows: Array[Dictionary] = SOURCE.rows(table)
	if rows.size() != int(_metadata[table].row_count):
		_fail("source_table_rows_unavailable:"+table+":"+SOURCE.problem())
		return []
	_raw[table] = rows
	return rows

func _at(table: String, id: Variant) -> Dictionary:
	if not _integer(id) or int(id) < 0 or not _table_metadata(table):
		_fail("invalid_source_reference:"+table)
		return {}
	var row: Dictionary = SOURCE.row(table,int(id))
	if row.is_empty(): _fail("missing_or_ambiguous_source_reference:"+table+":"+str(int(id))+":"+SOURCE.problem())
	return row

func _excluded(table: String, row: Dictionary) -> bool:
	var key: String = table+":"+(str(int(row.ID)) if _integer(row.get("ID")) else JSON.stringify(row))
	if _denied.has(key): return bool(_denied[key])
	var evidence: Dictionary = SOURCE.declared_exclusion(table,row)
	_denied[key] = not evidence.is_empty()
	if not evidence.is_empty():
		source_exclusion_evidence.append({"table":table,"row":row,"evidence":evidence})
		_unavailable(table,row,"source_declared_exclusion")
	return not evidence.is_empty()

func _effect(link: Dictionary) -> Dictionary:
	var bonus: Dictionary = _at("Bonus",link.get("BonusID"))
	if bonus.is_empty(): return {}
	var type: Dictionary = _at("BonusType",bonus.get("BonusTypeID"))
	if type.is_empty(): return {}
	if not type.get("Name") is String or typeof(bonus.get("Value")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(bonus.Value)):
		_fail("invalid_source_item_bonus:"+str(bonus.get("ID","")))
		return {}
	return {"type":type.Name,"value":bonus.Value,"bonus_id":bonus.ID,"source_link":link,"source_bonus":bonus,"source_type":type}

func _project() -> Dictionary:
	var tables: Dictionary = {}
	for table: String in TABLES: tables[table] = _table(table)
	var rod_ids: Dictionary = {}
	for row: Dictionary in tables.FishDistribution:
		if not _integer(row.get("FishingRodID")):
			_fail("invalid_source_FishDistribution.FishingRodID")
			continue
		if int(row.FishingRodID) != 0: rod_ids[int(row.FishingRodID)] = true
	var rods: Dictionary = {}; var effects: Dictionary = {}; var effect_rows: Dictionary = {}
	var effect_ids: Dictionary = rod_ids.duplicate()
	for row: Dictionary in tables.ExchangeSystemOutput:
		if row.get("RuleID") in [1,11,21] and _integer(row.get("ItemClassID")): effect_ids[int(row.ItemClassID)] = true
	for row: Dictionary in tables.Fish:
		if _integer(row.get("ItemClassID")) and int(row.ItemClassID) > 0: effect_ids[int(row.ItemClassID)] = true
	for link_index: int in _count("ItemBonus"):
		var link: Dictionary = SOURCE.row_at("ItemBonus",link_index)
		if not _integer(link.get("ItemClassID")):
			_fail("invalid_source_ItemBonus.ItemClassID")
			continue
		var item: int = int(link.ItemClassID)
		if not effect_ids.has(item): continue
		var detail: Dictionary = _effect(link)
		if detail.is_empty(): continue
		var key: String = str(item)
		if not effects.has(key): effects[key] = []; effect_rows[key] = []
		effects[key].append({"type":detail.type,"value":detail.value,"bonus_id":detail.bonus_id})
		effect_rows[key].append(detail)
		if rod_ids.has(item):
			if not rods.has(key): rods[key] = {}
			rods[key][detail.type] = detail.value
	var items: Array = []
	for raw_index: int in _count("ItemClass"):
		var raw: Dictionary = SOURCE.row_at("ItemClass",raw_index)
		var selected: Dictionary = {}
		for field: String in ITEM_FIELDS:
			if not raw.has(field):
				_fail("missing_source_ItemClass_field:"+field)
				continue
			selected[field] = raw[field]
		items.append(selected)
	tables.ItemClass = items
	var goods: Array = []
	for raw: Dictionary in _table("MerchantGoods"):
		if raw.get("MerchantsID") == 2231 and rod_ids.has(_id(raw.get("ItemClassID"))): goods.append(raw)
	tables.MerchantGoods = goods
	var territory_ids: Dictionary = {}; var group_ids: Dictionary = {}; var time_ids: Dictionary = {}; var reward_ids: Dictionary = {}
	for row: Dictionary in tables.FishTerritory: territory_ids[row.get("TerritoriesID")] = true
	for row: Dictionary in tables.FishContest: group_ids[row.get("WeeklyOpenTimeGroupID")] = true
	tables.Territories = _select("Territories","ID",territory_ids)
	tables.WeeklyOpenTimeGroupSet = _select("WeeklyOpenTimeGroupSet","WeeklyOpenTimeGroupId",group_ids)
	for row: Dictionary in tables.WeeklyOpenTimeGroupSet: time_ids[row.get("WeeklyOpenTimeId")] = true
	tables.WeeklyOpenTimeEntity = _select("WeeklyOpenTimeEntity","WeeklyOpenTimeID",time_ids)
	for row: Dictionary in tables.FishContestRankReward: reward_ids[row.get("RewardID")] = true
	tables.Reward = _select("Reward","ID",reward_ids)
	var bags: Dictionary = {}; var cards: Dictionary = {}; var buffs: Dictionary = {}; var descriptions: Dictionary = {}
	for key: String in effects:
		for detail: Dictionary in effects[key]:
			if detail.type in ["LuckyBagClassID","BuffCardID"]:
				if not _integer(detail.value):
					_fail("invalid_typed_source_item_effect:"+str(detail.type))
					continue
				if detail.type == "LuckyBagClassID": bags[int(detail.value)] = true
				else: cards[int(detail.value)] = true
	tables.LuckyBagClass = _select("LuckyBagClass","ID",bags)
	tables.LuckyBagEntityView = _select("LuckyBagEntityView","LuckyBagClassID",bags)
	tables.BuffCard = _select("BuffCard","ID",cards)
	for row: Dictionary in tables.BuffCard: buffs[row.get("BuffClassID")] = true
	tables.CardBuffBonus = _select("BuffBonus","BuffClassID",buffs)
	var card_bonuses: Array = []
	for row: Dictionary in tables.CardBuffBonus:
		var bonus: Dictionary = _at("Bonus",row.get("BonusID"))
		if not bonus.is_empty(): card_bonuses.append(bonus)
	tables.CardBonus = card_bonuses
	for row: Dictionary in tables.FishContestRuleType:
		for field: String in ["RuleDescID","RuleAlterDescID","UnitDescID"]: descriptions[row.get(field)] = true
	tables.ContestDescriptions = _select("DescData_Korean","ID",descriptions)
	tables.LuckyBagEntityType = _table("LuckyBagEntityType")
	tables.CurrencyUnitClass = _select("CurrencyUnitClass","CurrencyID",{2561:true})
	tables.Currency = _select("Currency","ID",{2561:true})
	return {"version":523,"tables":tables,"rods":rods,"item_effects":effects,"source_effect_rows":effect_rows}

## Verified row count of a table streamed by position (0 on failure), so a
## large table is never materialized whole (same checks as _table()).
func _count(table: String) -> int:
	if not _table_metadata(table): return 0
	var count: int = SOURCE.row_count(table)
	if count != int(_metadata[table].row_count):
		_fail("source_table_rows_unavailable:"+table+":"+SOURCE.problem())
		return 0
	return count

func _select(table: String, field: String, ids: Dictionary) -> Array:
	var result: Array = []
	var selected: Dictionary = {}
	for value: Variant in ids: selected[_id(value)] = true
	var count: int = 0 if _raw.has(table) else _count(table)
	var column: Variant = SOURCE.column(table,field) if count > 0 else []
	if count > 0 and column.size() == count:
		# Same per-row reference checks, read from the packed column; only
		# the selected rows are built.
		for value: Variant in column: _id(value)
		result.append_array(SOURCE.rows_matching(table,field,selected))
		return result
	if count == 0 and not _raw.has(table) and _fatal: return result
	for row: Dictionary in _table(table):
		if selected.has(_id(row.get(field))): result.append(row)
	return result

func _admit(original: Dictionary) -> Dictionary:
	var result: Dictionary = original.duplicate(true)
	var blocked_items: Dictionary = {}; var blocked_fish: Dictionary = {}; var blocked_pools: Dictionary = {}
	var blocked_territories: Dictionary = {}; var blocked_bags: Dictionary = {}
	var known_items: Dictionary = {}; var known_fish: Dictionary = {}
	for raw_index: int in _count("ItemClass"):
		var raw: Dictionary = SOURCE.row_at("ItemClass",raw_index)
		if not _integer(raw.get("ID")): _fail("invalid_source_ItemClass.ID"); continue
		known_items[int(raw.ID)] = true
		if _excluded("ItemClass",raw) or typeof(raw.get("TestItem")) != TYPE_BOOL or raw.TestItem:
			blocked_items[int(raw.ID)] = true
			if raw.get("TestItem") == true: _unavailable("ItemClass",raw,"source_TestItem_true")
	for key: String in original.source_effect_rows:
		for detail: Dictionary in original.source_effect_rows[key]:
			if _excluded("ItemBonus",detail.source_link) or _excluded("Bonus",detail.source_bonus) or _excluded("BonusType",detail.source_type): blocked_items[int(key)] = true
			if detail.type == "DeleteTime":
				blocked_items[int(key)] = true
				_unavailable("ItemBonus",detail.source_link,"source_DeleteTime_requires_original_expiry_contract")
	# Preserve each original row, including withheld declarations, beside the
	# active input. The archive and the public compiler's projection are intact.
	result["raw_tables"] = original.tables
	result["raw_rods"] = original.rods
	result["raw_item_effects"] = original.item_effects
	for table: String in original.tables:
		var eligible: Array = []
		var source_table: String = "BuffBonus" if table == "CardBuffBonus" else ("Bonus" if table == "CardBonus" else ("DescData_Korean" if table == "ContestDescriptions" else table))
		for row: Dictionary in original.tables[table]:
			if _excluded(source_table,row):
				if table in ["FishConstant","FishMiniGameDifficulty","FishMiniGameAI","FishMiniGameAIList"]: _fail("excluded_required_fishing_parameter:"+table)
				if table == "Fish": blocked_fish[_id(row.get("ID"))] = true
				elif table == "FishPoolProbability": blocked_pools[_id(row.get("FishPoolID"))] = true
				elif table == "FishPool": blocked_pools[_id(row.get("ID"))] = true
				elif table == "FishTerritory": blocked_territories[_id(row.get("ID"))] = true
				elif table == "LuckyBagClass": blocked_bags[_id(row.get("ID"))] = true
				elif table == "LuckyBagEntityView": blocked_bags[_id(row.get("LuckyBagClassID"))] = true
				continue
			if table == "ItemClass" and blocked_items.has(_id(row.get("ID"))): continue
			if table == "FishContest":
				if typeof(row.get("TimeLimit")) != TYPE_BOOL or not _integer(row.get("WeeklyOpenTimeGroupID")):
					_unavailable(table,row,"unsupported_time_contract:invalid_source_time_fields")
					continue
				# These fields do not establish expiry, duration units or current
				# eligibility. Keep them verbatim and withhold unsupported admission.
				if row.TimeLimit or int(row.WeeklyOpenTimeGroupID) != 0:
					var reasons: Array[String] = []
					if row.TimeLimit: reasons.append("unsupported_time_contract")
					if int(row.WeeklyOpenTimeGroupID) != 0: reasons.append("weekly_schedule_contract")
					_unavailable(table,row,",".join(reasons))
					continue
			eligible.append(row)
		result.tables[table] = eligible
	for row: Dictionary in original.tables.LuckyBagEntityView:
		if blocked_items.has(_id(row.get("ItemClassID"))) or not known_items.has(_id(row.get("ItemClassID"))):
			blocked_bags[_id(row.get("LuckyBagClassID"))] = true
			_unavailable("LuckyBagEntityView",row,"excluded_item_withholds_whole_bag_without_reweighting")
	for key: String in original.item_effects:
		for effect: Dictionary in original.item_effects[key]:
			if effect.type == "LuckyBagClassID" and blocked_bags.has(_id(effect.value)): blocked_items[int(key)] = true
	for key: String in original.rods:
		if not known_items.has(int(key)):
			blocked_items[int(key)] = true
			_unavailable("ItemClass",{"ID":int(key)},"source_rod_item_unavailable")
		if blocked_items.has(int(key)): result.rods.erase(key)
	for key: String in original.item_effects:
		if blocked_items.has(int(key)): result.item_effects.erase(key)
	for row: Dictionary in original.tables.Fish:
		known_fish[_id(row.get("ID"))] = true
		if blocked_items.has(_id(row.get("ItemClassID"))) or not known_items.has(_id(row.get("ItemClassID"))) or _id(row.get("ItemClassID")) == 0:
			blocked_fish[_id(row.get("ID"))] = true
			_unavailable("Fish",row,"source_fish_item_excluded")
	for row: Dictionary in original.tables.FishPoolProbability:
		if blocked_fish.has(_id(row.get("FishID"))) or not known_fish.has(_id(row.get("FishID"))):
			blocked_pools[_id(row.get("FishPoolID"))] = true
			_unavailable("FishPoolProbability",row,"excluded_fish_withholds_whole_pool_without_reweighting")
	result.tables.Fish = result.tables.Fish.filter(func(row: Dictionary) -> bool: return not blocked_fish.has(_id(row.get("ID"))))
	result.tables.FishPoolProbability = result.tables.FishPoolProbability.filter(func(row: Dictionary) -> bool: return not blocked_pools.has(_id(row.get("FishPoolID"))))
	var distributions: Array = []
	for row: Dictionary in result.tables.FishDistribution:
		if blocked_pools.has(_id(row.get("FishPoolID"))) or blocked_items.has(_id(row.get("FishingRodID"))) or blocked_territories.has(_id(row.get("FishTerritoryID"))):
			_unavailable("FishDistribution",row,"source_pool_rod_or_territory_unavailable")
			continue
		distributions.append(row)
	result.tables.FishDistribution = distributions
	var goods: Array = []
	for row: Dictionary in result.tables.MerchantGoods:
		if blocked_items.has(_id(row.get("ItemClassID"))): continue
		var timed: bool = false
		for field: String in ["LimitStartTime","LimitEndTime","LimitStartHour","LimitEndHour"]:
			if not _integer(row.get(field)) or int(row[field]) != 0: timed = true
		if timed:
			_unavailable("MerchantGoods",row,"rod_goods_time_admission_not_evaluated_by_existing_buy_rod")
			continue
		goods.append(row)
	result.tables.MerchantGoods = goods
	# exchange() currently consumes selected equipment even when no rule/reward
	# can be returned. Do not stage a partial exchange graph into that service.
	for rule: Dictionary in original.tables.ExchangeSystemRule:
		if rule.get("SystemTypeID") != 1: continue
		var input: Dictionary = _at("ExchangeSystemInput",rule.get("InputID"))
		if input.get("Type") != 1 or input.get("Value") not in [2,3,4]: continue
		if _excluded("ExchangeSystemRule",rule) or _excluded("ExchangeSystemInput",input): _fail("exchange_requires_unavailable_rule_guard:"+str(rule.get("ID")))
		for row: Dictionary in original.tables.ExchangeSystemOutput:
			if row.get("RuleID") == rule.get("ID") and (blocked_items.has(_id(row.get("ItemClassID"))) or not known_items.has(_id(row.get("ItemClassID"))) or _excluded("ExchangeSystemOutput",row)):
				_unavailable("ExchangeSystemOutput",row,"existing_exchange_would_consume_equipment_with_unavailable_reward")
				_fail("exchange_requires_unavailable_reward_guard:"+str(rule.get("ID")))
	return result

func build() -> Dictionary:
	problem = ""; unavailable_source_definitions = []; source_exclusion_evidence = []
	_raw.clear(); _metadata.clear(); _denied.clear(); _fatal = false
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty():
		problem = "current523_original_unavailable:"+SOURCE.problem()
		return {}
	var original: Dictionary = _project()
	if _fatal: return {}
	var result: Dictionary = _admit(original)
	if _fatal: return {}
	result["unavailable_source_definitions"] = unavailable_source_definitions.duplicate(true)
	result["source_exclusion_evidence"] = source_exclusion_evidence.duplicate(true)
	result["source_table_metadata"] = _metadata.duplicate(true)
	var bytes: PackedByteArray = JSON.stringify(result).to_utf8_buffer()
	var hash = HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(bytes) != OK:
		problem = "fishing_model_payload_hash_unavailable"
		return {}
	result["input_identity"] = {"kind":"current523_original_fishing_memory","archive":identity,
		"model_payload_sha256":hash.finish().hex_encode(),"model_payload_sha256_scope":"JSON.stringify(model_without_input_identity).to_utf8_buffer()",
		"source_table_metadata":_metadata.duplicate(true),"pack_file_created":false}
	return result

