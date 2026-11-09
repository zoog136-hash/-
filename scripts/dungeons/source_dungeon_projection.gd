extends RefCounted
## UNVERIFIED: in-memory port of tools/build_dungeon523_pack.py:build.
## No files, installation, execution sidecar, grants, or map changes.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
var problem: String = ""
var _tables: Dictionary = {}
var _indexes: Dictionary = {}
var _groups: Dictionary = {}
var _provenance: Dictionary = {}

func _require(condition: bool, reason: String) -> bool:
	if not condition and problem.is_empty(): problem = reason
	return condition

func _metadata(table: String) -> void:
	if _provenance.has(table): return
	var original: Dictionary = SOURCE.table_metadata(table)
	var selected: Dictionary = {}
	for key: String in ["path","bytes","sha256","crc32","row_count"]:
		if not original.has(key):
			_require(false,"던전 원본 provenance 필드가 없습니다: "+table+"."+key)
			return
		selected[key] = original[key]
	_provenance[table] = selected

func _rows(table: String) -> Array:
	if not _tables.has(table):
		_metadata(table)
		_tables[table] = SOURCE.rows(table)
		_require(_tables[table].size() == int(_provenance.get(table,{}).get("row_count",-1)),"던전 원본 행을 읽을 수 없습니다: "+table)
	return _tables[table]

func _keyed(table: String) -> Dictionary:
	if not _indexes.has(table):
		var index: Dictionary = {}
		for original: Dictionary in _rows(table):
			var id: int = int(original.ID)
			# The existing Python builder permits repeated sentinel ID0 and
			# keeps the final row. Other duplicate identities remain rejected.
			if not _require(id == 0 or not index.has(id),"던전 원본 ID가 중복됩니다: "+table): return {}
			index[id] = original
		_indexes[table] = index
	return _indexes[table]

## Large original tables are read through the shared reader by ID instead of
## being materialized and indexed here; _keyed()'s duplicate rule (only the
## sentinel ID0 may repeat, last row kept) is checked once over the column.
const SHARED_TABLES: Array[String] = ["Bonus","ItemClass","Reward","DateTimes_Korean","Territories","ItemBonus"]
var _checked: Dictionary = {}

func _shared_keyed(table: String) -> bool:
	if not table in SHARED_TABLES: return false
	if not _checked.has(table):
		_metadata(table)
		var ids: Variant = SOURCE.column(table,"ID")
		var count: int = SOURCE.row_count(table)
		_require(count == int(_provenance.get(table,{}).get("row_count",-1)),"던전 원본 행을 읽을 수 없습니다: "+table)
		var seen: Dictionary = {}
		if ids.size() == count:
			for value: Variant in ids:
				var id: int = int(value)
				if not _require(id == 0 or not seen.has(id),"던전 원본 ID가 중복됩니다: "+table): break
				seen[id] = true
		_checked[table] = true
	return true

func _shared_row(table: String, id: int) -> Variant:
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",id)
	return matches[-1] if not matches.is_empty() else null

func _row(table: String, id: int) -> Dictionary:
	if _shared_keyed(table):
		var shared: Variant = _shared_row(table,id)
		_require(shared != null,"던전 원본 참조가 없습니다: "+table+"#"+str(id))
		return shared if shared != null else {}
	var value: Dictionary = _keyed(table).get(id,{})
	_require(not value.is_empty(),"던전 원본 참조가 없습니다: "+table+"#"+str(id))
	return value

func _optional_row(table: String, id: int) -> Variant:
	if _shared_keyed(table): return _shared_row(table,id)
	return _keyed(table).get(id)

func _grouped(table: String, field: String) -> Dictionary:
	var key: String = table+":"+field
	if not _groups.has(key):
		var groups: Dictionary = {}
		for original: Dictionary in _rows(table):
			var id: int = int(original[field])
			if not groups.has(id): groups[id] = []
			groups[id].append(original)
		_groups[key] = groups
	return _groups[key]

func _related(table: String, field: String, id: int) -> Array:
	return _grouped(table,field).get(id,[])

func _text(id: int) -> String:
	# Only IDs selected by the existing dungeon projection are requested.
	# No description catalog, search, substitution, or UI is introduced.
	_metadata("DescData_Korean")
	var matches: Array[Dictionary] = SOURCE.related("DescData_Korean","ID",id)
	if matches.is_empty(): return ""
	if not _require(id == 0 or matches.size() == 1,"던전 설명 원본 ID가 중복됩니다"): return ""
	return str(matches[-1].get("Description",""))

func _item(id: int) -> Dictionary:
	var original: Dictionary = _row("ItemClass",id)
	if original.is_empty(): return {}
	var deletion: Array = []
	for link: Dictionary in _related("ItemBonus","ItemClassID",id):
		var bonus: Dictionary = _row("Bonus",int(link.BonusID))
		if bonus.get("BonusTypeID") == 492:
			deletion.append({"link":link,"row":bonus,
				"date":_optional_row("DateTimes_Korean",int(bonus.BonusApplicationTargetID)) if bonus.get("BonusApplicationTypeID") == 298 else null})
	var name: String = _text(int(original.DescID))
	return {"row":original,"name":name if not name.is_empty() else original.Name,"deletion":deletion}

func _currency(id: int) -> Dictionary:
	var original: Dictionary = _row("Currency",id)
	if original.is_empty(): return {}
	var name: String = _text(int(original.DescID))
	return {"row":original,"name":name if not name.is_empty() else original.Name,"sources":_related("CurrencyUnitClass","CurrencyID",id)}

func _rewards(links: Array) -> Array:
	var result: Array = []
	for link: Dictionary in links:
		var original: Dictionary = _row("Reward",int(link.RewardID))
		if original.is_empty(): return []
		var type_name: String = str(_row("RewardType",int(original.RewardTypeID)).get("Name",""))
		result.append({"link":link,"row":original,"type":type_name,
			"item":_item(int(original.RewardClassID)) if type_name == "Item" else null})
	return result

func _time_group(id: int) -> Dictionary:
	var original: Dictionary = _row("LandTimeLimitGroup",id)
	if original.is_empty(): return {}
	return {"row":original,"name":_text(int(original.DescID)),
		"reset":_optional_row("ContentsResetScheduleType",int(original.ContentsResetScheduleTypeID)),
		"start":_optional_row("DateTimes_Korean",int(original.StartDateTimeID)),
		"end":_optional_row("DateTimes_Korean",int(original.EndDateTimeID))}

func _place(id: int) -> Dictionary:
	var territory: Dictionary = _row("Territories",id)
	if territory.is_empty(): return {}
	var land: Dictionary = _row("Land",int(territory.LandID))
	if land.is_empty(): return {}
	var attributes: Array = []
	for original: Dictionary in _related("LandAttribute","LandID",int(land.ID)):
		attributes.append({"row":original,"type":_row("LandAttributeType",int(original.LandAttributeTypeID)).get("Name","")})
	var time_groups: Array = []
	for link: Dictionary in _related("LandTimeLimit","LandID",int(land.ID)):
		time_groups.append(_time_group(int(link.LandTimeLimitGroupID)))
	var name: String = _text(int(territory.DescID))
	return {"territory":territory,"land":land,"name":name if not name.is_empty() else territory.Name,
		"attributes":attributes,"time_groups":time_groups}

func _tower() -> Array:
	var result: Array = []
	for stage: Dictionary in _rows("TrialTowerStage"):
		var purchase: Dictionary = _row("MarketPurchase_Korean",int(stage.ImmediateCompleteMarketPurchaseID))
		if purchase.is_empty(): return []
		var payment: Dictionary = _row("MarketPayment_Korean",int(purchase.MarketPaymentID))
		if payment.is_empty(): return []
		var targets: Array = []
		for link: Dictionary in _related("MarketPurchaseProduct","MarketPurchaseID",int(purchase.ID)):
			targets.append(_row("MarketProduct",int(link.MarketProductID)))
		if not _require(targets.size() == 1 and not targets[0].is_empty(),"던전 즉시 완료 상품 관계가 다릅니다"): return []
		if not _require(_row("Unit",int(targets[0].UnitID)).get("Name") == "TrialTowerStageID" and targets[0].get("ClassID") == stage.ID and targets[0].get("Amount") == 1,"던전 즉시 완료 단계 참조가 다릅니다"): return []
		if not _require(_row("Unit",int(payment.UnitID)).get("Name") == "CurrencyID" and payment.get("ClassID") == 764,"던전 즉시 완료 재화 참조가 다릅니다"): return []
		var goals: Array = []
		for link: Dictionary in _related("TrialTowerGoal","StageID",int(stage.ID)):
			var goal: Dictionary = _row("Goal",int(link.GoalID))
			if goal.is_empty(): return []
			var kind: String = str(_row("GoalType",int(goal.GoalTypeID)).get("Name",""))
			goals.append({"link":link,"row":goal,"type":kind,"item":_item(int(goal.GoalClassID)) if kind == "ItemCollect" else null})
		result.append({"stage":stage,"type":_row("TrialTowerStageType",int(stage.StageTypeID)).get("Name",""),
			"place":_place(int(stage.TeleportTerritoryID)),"goals":goals,
			"normal_rewards":_rewards(_related("TrialTowerReward","StageID",int(stage.ID))),
			"immediate_rewards":_rewards(_related("TrialTowerImmediateReward","StageID",int(stage.ID))),
			"immediate":{"purchase":purchase,"payment":payment,"products":targets,"currency":_currency(int(payment.ClassID))}})
	return result

func _orim() -> Array:
	var result: Array = []
	for stage: Dictionary in _rows("OrimsTrailStage"):
		var sections: Array = []
		for section: Dictionary in _related("OrimsTrailBossKillRewardSection","StageID",int(stage.ID)):
			sections.append({"row":section,"care_rewards":_rewards(_related("OrimsTrailCareReward","SectionID",int(section.ID)))})
		result.append({"stage":stage,"place":_place(int(stage.TeleportTerritoryID)),
			"normal_rewards":_rewards(_related("OrimsTrailReward","StageID",int(stage.ID))),
			"lucky_rewards":_rewards(_related("OrimsTrailLuckyReward","StageID",int(stage.ID))),"sections":sections,
			"spawns":_related("OrimsTrailSpawn","StageID",int(stage.ID)),
			"messages":_related("OrimsTrailStageMessage","StageID",int(stage.ID))})
	return result

func _special() -> Array:
	var result: Array = []
	for original: Dictionary in _rows("SpecialDungeon"):
		var teleport: Dictionary = _row("LandTeleport",int(original.LandTeleportID))
		if teleport.is_empty(): return []
		var conditions: Array = []
		for link: Dictionary in _related("LandTeleportPrerequisite","LandTeleportID",int(teleport.ID)):
			var condition: Dictionary = _row("Prerequisite",int(link.PrerequisiteID))
			if condition.is_empty(): return []
			conditions.append({"link":link,"row":condition,"type":_row("PrerequisiteType",int(condition.PrerequisiteTypeID)).get("Name","")})
		var destinations: Array = []
		for link: Dictionary in _related("LandTeleportTerritories","LandTeleportID",int(teleport.ID)):
			destinations.append({"link":link,"place":_place(int(link.TerritoryID))})
		result.append({"row":original,"type":_row("SpecialDungeonType",int(original.SpecialDungeonTypeID)),
			"teleport":teleport,"currency":_currency(int(teleport.CurrencyID)),"destinations":destinations,"prerequisites":conditions})
	return result

func _recharge_candidates() -> Array:
	_metadata("ItemBonus")
	var count: int = SOURCE.row_count("ItemBonus")
	_require(count == int(_provenance.get("ItemBonus",{}).get("row_count",-1)),"던전 원본 행을 읽을 수 없습니다: ItemBonus")
	var recharge_bonuses: Dictionary = {}
	for bonus: Dictionary in SOURCE.rows_matching("Bonus","BonusTypeID",{712:true}): recharge_bonuses[int(bonus.ID)] = true
	var owners: Variant = SOURCE.column("ItemBonus","ItemClassID")
	var bonus_ids: Variant = SOURCE.column("ItemBonus","BonusID")
	var candidates: Dictionary = {}
	for index: int in count:
		if recharge_bonuses.has(int(bonus_ids[index])): candidates[int(owners[index])] = true
	var ordered: Array = []
	var seen: Dictionary = {}
	for index: int in count:
		var owner: int = int(owners[index])
		if candidates.has(owner) and not seen.has(owner):
			seen[owner] = true
			ordered.append(owner)
	return ordered

func _rechargers() -> Array:
	# Existing source-specific recharge declarations, not a new use engine.
	_keyed("UseDesc")
	var result: Array = []
	# Only items with a BonusTypeID 712 link can recharge; they are visited in
	# the same first-appearance order _grouped("ItemBonus","ItemClassID") gives.
	for item_id: int in _recharge_candidates():
		var links: Array = SOURCE.related("ItemBonus","ItemClassID",item_id)
		var group_links: Array = []
		for link: Dictionary in links:
			if _row("Bonus",int(link.BonusID)).get("BonusTypeID") == 712: group_links.append(link)
		if group_links.is_empty(): continue
		if not _require(group_links.size() == 1,"던전 시간 충전 그룹 관계가 다릅니다"): return []
		var target: int = int(_row("Bonus",int(group_links[0].BonusID)).get("Value",0))
		if not _require(_keyed("LandTimeLimitGroup").has(target),"던전 시간 충전 대상이 없습니다"): return []
		var effects: Array = []
		var recharge: Array = []
		for link: Dictionary in links:
			var bonus: Dictionary = _row("Bonus",int(link.BonusID))
			if bonus.is_empty(): return []
			var effect: Dictionary = {"link":link,"row":bonus,"type":_row("BonusType",int(bonus.BonusTypeID))}
			effects.append(effect)
			if bonus.get("BonusTypeID") == 722: recharge.append(effect)
			if not _require(link.get("IsPossession") == false,"던전 충전의 소유 효과 조건이 다릅니다"): return []
		if not _require(recharge.size() == 1 and recharge[0].row.get("Value") == 3600,"던전 충전의 원본 시간 선언이 다릅니다"): return []
		if not _require(_row("Unit",int(recharge[0].type.UnitID)).get("Name") == "Seconds","던전 충전의 원본 시간 단위가 다릅니다"): return []
		var info: Dictionary = _item(item_id)
		if info.is_empty(): return []
		var use: Variant = _optional_row("UseDesc",int(info.row.UseDescID))
		result.append({"item":info,"group_id":target,"effects":effects,
			"use_text":_text(int(use.get("DescID",0))) if use is Dictionary else _text(0)})
	return result

func build() -> Dictionary:
	problem = ""
	_tables.clear(); _indexes.clear(); _groups.clear(); _provenance.clear()
	var identity: Dictionary = SOURCE.identity()
	if not _require(identity.get("source_sha256") == SOURCE.SOURCE_SHA,"보유 원본523 정의 ZIP이 필요합니다"): return {}
	# The Python builder eagerly reads these inputs, including provenance for
	# optional empty relations. Description values still use selected IDs only.
	_metadata("DescData_Korean")
	for table: String in ["Land","Territories","ItemClass","RewardType","Reward","LandAttribute","LandAttributeType","LandTimeLimitGroup","LandTimeLimit","ContentsResetScheduleType","DateTimes_Korean","Currency","CurrencyUnitClass","Unit","Bonus","BonusType","ItemBonus","Goal","GoalType","TrialTowerGoal","TrialTowerReward","TrialTowerImmediateReward","MarketPurchase_Korean","MarketPayment_Korean","MarketPurchaseProduct","MarketProduct","TrialTowerStageType","OrimsTrailReward","OrimsTrailLuckyReward","OrimsTrailBossKillRewardSection","OrimsTrailCareReward","OrimsTrailSpawn","OrimsTrailStageMessage","LandTeleport","LandTeleportTerritories","LandTeleportPrerequisite","Prerequisite","PrerequisiteType","SpecialDungeonType"]:
		_rows(table)
	if not problem.is_empty(): return {}
	var tower: Array = _tower()
	var orim: Array = _orim()
	var special: Array = _special()
	var rechargers: Array = _rechargers()
	if not _require(tower.size() == 200 and orim.size() == 20 and special.size() == 22 and rechargers.size() == 450,"던전 원본 projection 구성 수가 다릅니다"): return {}
	if not problem.is_empty(): return {}
	var control_ids: Dictionary = {}
	for entry: Dictionary in special: control_ids[int(entry.type.ContentsControlID)] = true
	var controls: Array = []
	for original: Dictionary in _rows("ContentsControl"):
		if original.Name in ["TrialTower","TrialTowerHardMode","OrimsTrail"] or control_ids.has(int(original.ID)): controls.append(original)
	var categories: Array = []
	for original: Dictionary in _rows("DungeonCategory"):
		if original.Name in ["TrialTower","OrimsTrail","Special"]: categories.append(original)
	var seasons: Array = []
	for original: Dictionary in _rows("SeasonDungeon"):
		if original.Name in ["시련의 탑","오림의 흔적"]: seasons.append(original)
	var server_ids: Dictionary = {}
	for original: Dictionary in controls: server_ids[int(original.ServerLimitSetID)] = true
	for original: Dictionary in categories: server_ids[int(original.ServerLimitSetId)] = true
	for original: Dictionary in seasons: server_ids[int(original.ServerLimitsetID)] = true
	for entry: Dictionary in special: server_ids[int(entry.row.ServerLimitSetID)] = true
	var servers: Array = []
	for original: Dictionary in _rows("ServerLimit"):
		if server_ids.has(int(original.ServerLimitSetID)): servers.append(original)
	var declarations: Dictionary = {}
	for table: String in ["TrialTowerConstant","TrialTowerTryCountPurchase","TrialTowerBuff","TrialTowerBanCondition","TrialTowerBanConditionType","OrimsTrailConstant","OrimsTrailBuff","OrimsTrailRerollCurrencyCost","OrimsTrailSeason"]:
		declarations[table] = _rows(table)
	var time_groups: Array = []
	for original: Dictionary in _rows("LandTimeLimitGroup"): time_groups.append(_time_group(int(original.ID)))
	if not problem.is_empty(): return {}
	return {"schema":1,"source_sha256":SOURCE.SOURCE_SHA,"version":523,
		"tower":tower,"orim":orim,"special":special,"time_groups":time_groups,"land_times":_rows("LandTimeLimit"),
		"rechargers":rechargers,"controls":controls,"categories":categories,"seasons":seasons,"servers":servers,
		"declarations":declarations,"table_provenance":_provenance.duplicate(true)}

static func _canonical(value: Variant) -> String:
	# Source integer fields may be represented as floats by Godot's JSON parser.
	# Byte identity, not this normalization, remains the runtime authority.
	if value == null: return "null"
	if value is bool: return "true" if value else "false"
	if value is int: return str(value)
	if value is float:
		if is_finite(value) and value == floorf(value) and absf(value) <= 9007199254740991.0: return str(int(value))
		return JSON.stringify(value)
	if value is String: return JSON.stringify(value)
	if value is Array:
		var parts: PackedStringArray = []
		for element: Variant in value: parts.append(_canonical(element))
		return "["+",".join(parts)+"]"
	if value is Dictionary:
		# Keys sort as text, like the Python compiler's sort_keys. Rows built
		# with `row.name = ...` carry StringName keys, and a StringName sorts
		# by identity rather than text, so the order (and the pinned payload
		# SHA) depended on what else the process had interned.
		var keys := PackedStringArray()
		for key: Variant in value: keys.append(str(key))
		keys.sort()
		var parts: PackedStringArray = []
		for key: String in keys: parts.append(JSON.stringify(key)+":"+_canonical(value[key]))
		return "{"+",".join(parts)+"}"
	return ""

static func encoded(candidate: Dictionary) -> PackedByteArray:
	return (_canonical(candidate)+"\n").to_utf8_buffer()
