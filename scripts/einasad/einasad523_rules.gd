extends RefCounted
## Original 523 "아인하사드의 축복" rules read from the original definition ZIP
## (tables/source.zip through current523_definition_rows). Only what the rows
## state is used; everything else is listed in docs/einasad523_missing_rules.md.
##
##  - EinasadVariable #42 (6000): original bless units per shown point. Every
##    other EinasadVariable row has no type name in the tables and is unused.
##  - EinasadLevel: ordinary stages "Level0/1/2" by CumulativeValue (upper bound
##    of the stage in bless units): 0 -> stage 0, 1..200 -> 1, 201..99999 -> 2.
##    The two named rows (Level_SpecialBless, Level_DragonCristal) are not
##    point stages; they are only reached through their own buffs.
##  - EinasadBenefit/EinasadBenefitType: per stage Experience and Adena percent
##    (Unit "Percentage", per 100: the SpecialBless buff text "경험치 획득률
##    1000% / 아데나 획득률 200%" is stage 3's +900/+100) and GetItem (a DescID).
##  - ItemConsumeRate: level-indexed groups referenced by item bonuses
##    (ItemConsumeRate / LevelEinasadBlessRecharge, unit ItemConsumeRateGourpID).
## Without the archive (or with rows that do not validate) definition().ok is
## false and the caller keeps the existing TWILIGHT values.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const POINT_VARIABLE_TYPE := 42
const RETRY_MSEC := 30000
const ORDINARY := ["Level0","Level1","Level2"]
const BENEFIT_TYPES := {"Experience":"exp_pct","Adena":"adena_pct","GetItem":"get_item_desc_id"}

static var _definition: Dictionary = {}
static var _attempted_at: int = -RETRY_MSEC
static var _groups: Dictionary = {}

static func reset_cache() -> void:
	_definition = {}; _attempted_at = -RETRY_MSEC; _groups = {}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"problem":reason}

## {"ok", "unit", "stages":[{level,name,upper_units,upper_points}], "max_points",
## "benefits":{level:{exp_pct,adena_pct,get_item_desc_id,get_item_text}},
## "special":{name:level}} or {"ok":false,"problem"}.
static func definition() -> Dictionary:
	if _definition.get("ok",false): return _definition
	var now: int = Time.get_ticks_msec()
	if not _definition.is_empty() and now-_attempted_at<RETRY_MSEC: return _definition
	_attempted_at = now
	_definition = _build()
	return _definition

static func _build() -> Dictionary:
	if SOURCE.identity().is_empty(): return _fail("원본523 정의 ZIP 미설치: "+SOURCE.problem())
	var variables: Array[Dictionary] = SOURCE.rows_matching("EinasadVariable","EinasadVariableTypeID",{POINT_VARIABLE_TYPE:true})
	if variables.size()!=1 or not _integer(variables[0].get("Value")) or int(variables[0].Value)<=0: return _fail("EinasadVariable #42 확인 실패")
	var unit: int = int(variables[0].Value)
	var stages: Array = []; var special: Dictionary = {}
	for row: Dictionary in SOURCE.rows("EinasadLevel"):
		if not _integer(row.get("Level")) or not _integer(row.get("CumulativeValue")): return _fail("EinasadLevel 행 형식 오류")
		var name: String = str(row.get("Name",""))
		if name in ORDINARY:
			if int(row.Level)!=ORDINARY.find(name) or int(row.CumulativeValue)%unit!=0: return _fail("EinasadLevel "+name+" 값 오류")
			stages.append({"level":int(row.Level),"name":name,"upper_units":int(row.CumulativeValue),"upper_points":int(row.CumulativeValue)/unit})
		else:
			special[name] = int(row.Level)
	stages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.level)<int(b.level))
	if stages.size()!=ORDINARY.size() or int(stages[0].upper_units)!=0: return _fail("EinasadLevel 일반 단계 0/1/2 확인 실패")
	for index: int in range(1,stages.size()):
		if int(stages[index].upper_units)<=int(stages[index-1].upper_units): return _fail("EinasadLevel 누적값이 증가하지 않습니다")
	var types: Dictionary = {}
	for row: Dictionary in SOURCE.rows("EinasadBenefitType"):
		if _integer(row.get("ID")) and BENEFIT_TYPES.has(str(row.get("Name",""))): types[int(row.ID)] = BENEFIT_TYPES[str(row.Name)]
	if types.size()!=BENEFIT_TYPES.size(): return _fail("EinasadBenefitType Experience/Adena/GetItem 확인 실패")
	var units: Dictionary = {"Percentage":-1,"DescID":-1}
	for row: Dictionary in SOURCE.rows("Unit"):
		if units.has(str(row.get("Name",""))) and _integer(row.get("ID")): units[str(row.Name)] = int(row.ID)
	var benefits: Dictionary = {}
	for row: Dictionary in SOURCE.rows("EinasadBenefit"):
		for field: String in ["Level","EinasadBenefitTypeID","UnitID","Value"]:
			if not _integer(row.get(field)): return _fail("EinasadBenefit 행 형식 오류")
		var key: String = str(types.get(int(row.EinasadBenefitTypeID),""))
		if key.is_empty(): return _fail("EinasadBenefit 알 수 없는 혜택 종류 %d" % int(row.EinasadBenefitTypeID))
		var expected_unit: int = int(units.DescID) if key=="get_item_desc_id" else int(units.Percentage)
		if int(row.UnitID)!=expected_unit: return _fail("EinasadBenefit 단위 불일치 #%d" % int(row.get("ID",0)))
		var level: int = int(row.Level)
		if not benefits.has(level): benefits[level] = {}
		if benefits[level].has(key): return _fail("EinasadBenefit 중복 혜택 %d:%s" % [level,key])
		benefits[level][key] = int(row.Value)
		if key=="get_item_desc_id":
			benefits[level]["get_item_text"] = str(SOURCE.row("DescData_Korean",int(row.Value)).get("Description","")) if int(row.Value)>0 else ""
	for stage: Dictionary in stages:
		var entry: Dictionary = benefits.get(int(stage.level),{})
		if not entry.has("exp_pct") or not entry.has("adena_pct"): return _fail("EinasadBenefit 단계 %d 경험치/아데나 행 없음" % int(stage.level))
	return {"ok":true,"problem":"","unit":unit,"stages":stages,"max_points":int(stages[-1].upper_points),"benefits":benefits,"special":special}

static func available() -> bool:
	return bool(definition().get("ok",false))

## Ordinary stage of a point balance (0, 1 or 2), or -1 without the rows.
## A balance above the last stage's CumulativeValue keeps the last stage.
static func stage_for_points(points: int) -> int:
	var data: Dictionary = definition()
	if not data.get("ok",false): return -1
	var units: int = maxi(0,points)*int(data.unit)
	for stage: Dictionary in data.stages:
		if units<=int(stage.upper_units): return int(stage.level)
	return int(data.stages[-1].level)

static func benefit(level: int) -> Dictionary:
	return definition().get("benefits",{}).get(level,{})

## 1 + Experience percent / 100 for an ordinary/special stage, or -1.0.
static func experience_multiplier(level: int) -> float:
	var entry: Dictionary = benefit(level)
	return 1.0+float(entry.exp_pct)/100.0 if entry.has("exp_pct") else -1.0

static func adena_multiplier(level: int) -> float:
	var entry: Dictionary = benefit(level)
	return 1.0+float(entry.adena_pct)/100.0 if entry.has("adena_pct") else -1.0

## Highest point balance an ordinary stage holds (EinasadLevel2 / unit = 99999), or -1.
static func max_points() -> int:
	var data: Dictionary = definition()
	return int(data.max_points) if data.get("ok",false) else -1

## Level -> Value of one ItemConsumeRate group; {} when the group has no rows
## or a row is malformed/duplicated.
static func consume_rate_group(group: int) -> Dictionary:
	if group<=0 or not available(): return {}
	if _groups.has(group): return _groups[group]
	var values: Dictionary = {}
	for row: Dictionary in SOURCE.rows_matching("ItemConsumeRate","ItemConsumeRateGroupID",{group:true}):
		if not _integer(row.get("Level")) or not _integer(row.get("Value")) or values.has(int(row.Level)):
			values = {}; break
		values[int(row.Level)] = int(row.Value)
	_groups[group] = values
	return values

## The first level with a row of an ItemConsumeRate group, or -1.
static func first_rate_level(group: int) -> int:
	var values: Dictionary = consume_rate_group(group)
	if values.is_empty(): return -1
	var lowest: int = 1<<30
	for level: int in values: lowest = mini(lowest,level)
	return lowest

## Snapshot used by the HUD/tests: what the rows say for this balance.
static func describe(points: int, fixed_level: int = 0) -> Dictionary:
	var data: Dictionary = definition()
	if not data.get("ok",false): return {"source":false,"problem":str(data.get("problem",""))}
	var ordinary: int = stage_for_points(points)
	var effective: int = maxi(ordinary,fixed_level)
	var entry: Dictionary = benefit(effective)
	var name: String = ""
	for stage: Dictionary in data.stages:
		if int(stage.level)==effective: name = str(stage.name)
	return {"source":true,"stage":effective,"ordinary_stage":ordinary,"stage_name":name,"exp_pct":int(entry.get("exp_pct",0)),"adena_pct":int(entry.get("adena_pct",0)),"get_item_text":str(entry.get("get_item_text","")),"max_points":int(data.max_points),"unit":int(data.unit)}
