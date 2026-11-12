extends RefCounted
## Original 523 혈맹 문장 (Emblem) read from the installed original definition
## ZIP. In Lineage M an emblem belongs to a clan (혈맹): the clan master picks
## it in Clan_Popup_Symbol, it unlocks with the clan level (Emblem.OpenGrade,
## the ClanExperience levels 1..20) and it is shown beside clan members' names.
## TWILIGHT has no clan, so only the local part is connected:
##  - the Korean selection list: EmblemSelectionRegion_Korean (LanguageID
##    Korean) -> Emblem, in table order;
##  - pictures: Emblem.EmblemLargeID / EmblemSmallID -> AssetView (AssetType
##    111 "Emblem", Path UI/Emblem/) original PNGs from the 523 UI pack;
##  - name: Emblem.descID (DescData_Korean); kind: EmblemType;
##  - change fee: ClanPolicies "EmblemChangeCommission" (Value 0, ItemClassID
##    26 아데나): free in 523.
## Local decision (no clan level exists offline): an emblem can be chosen when
## its type is Predefined and its OpenGrade is the first clan level of
## ClanExperience. Everything else stays locked with its OpenGrade shown.
## Emblems have no stat effect in any table. Rules the tables do not hold are
## listed in docs/acquisition_emblem523_missing_rules.md.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SAVE_KEY := "emblem523"
const ASSET_TYPE_EMBLEM := 111
const RETRY_MSEC := 30000

static var _definition: Dictionary = {}
static var _attempted_at: int = -RETRY_MSEC

var emblem_id: int = 0
var problem: String = ""

static func reset_cache() -> void:
	_definition = {}; _attempted_at = -RETRY_MSEC

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _row(table: String, id: int) -> Dictionary:
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",id)
	return matches[0] if matches.size()==1 else {}

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"problem":reason}

static func _text(id: int) -> String:
	if id<=0: return ""
	var matches: Array[Dictionary] = SOURCE.related("DescData_Korean","ID",id)
	return "" if matches.is_empty() else str(matches[-1].get("Description",""))

## {"ok", "options":[{id,name,source_name,type,open_grade,selectable,large,small}],
##  "by_id", "local_grade", "fee":{value,unit,class_id}} or {"ok":false,"problem"}.
static func definition() -> Dictionary:
	if _definition.get("ok",false): return _definition
	var now: int = Time.get_ticks_msec()
	if not _definition.is_empty() and now-_attempted_at<RETRY_MSEC: return _definition
	_attempted_at = now
	_definition = _build()
	return _definition

static func _build() -> Dictionary:
	if SOURCE.identity().is_empty(): return _fail("원본523 정의 ZIP 미설치: "+SOURCE.problem())
	var korean: int = -1
	for row: Dictionary in SOURCE.rows("LanguageID"):
		if str(row.get("Name",""))=="Korean" and _integer(row.get("ID")): korean = int(row.ID)
	if korean<0: return _fail("LanguageID Korean 확인 실패")
	var asset_type: Dictionary = _row("AssetType",ASSET_TYPE_EMBLEM)
	if str(asset_type.get("Name",""))!="Emblem" or str(asset_type.get("Path",""))!="UI/Emblem/": return _fail("AssetType #111 Emblem 확인 실패")
	var types: Dictionary = {}
	for row: Dictionary in SOURCE.rows("EmblemType"):
		if _integer(row.get("ID")): types[int(row.ID)] = str(row.get("Name",""))
	var grades: Array[int] = []
	for row: Dictionary in SOURCE.rows("ClanExperience"):
		if _integer(row.get("Level")): grades.append(int(row.Level))
	if grades.is_empty(): return _fail("ClanExperience 확인 실패")
	grades.sort()
	var local_grade: int = grades[0]
	var options: Array = []
	var by_id: Dictionary = {}
	for link: Dictionary in SOURCE.rows("EmblemSelectionRegion_Korean"):
		if not _integer(link.get("EmblemID")) or int(link.get("LanguageID",-1))!=korean: continue
		var id: int = int(link.EmblemID)
		if by_id.has(id): continue
		var emblem: Dictionary = _row("Emblem",id)
		if emblem.is_empty(): return _fail("Emblem #%d 없음" % id)
		for field: String in ["EmblemLargeID","EmblemSmallID","Type","OpenGrade","descID"]:
			if not _integer(emblem.get(field)): return _fail("Emblem #%d %s 형식 오류" % [id,field])
		var pictures: Dictionary = {}
		for pair: Array in [["large","EmblemLargeID"],["small","EmblemSmallID"]]:
			var view: Array[Dictionary] = SOURCE.related("AssetView","AssetId",int(emblem[pair[1]]))
			if view.size()!=1 or int(view[0].get("AssetTypeId",-1))!=ASSET_TYPE_EMBLEM or str(view[0].get("FilePath","")).is_empty(): return _fail("Emblem #%d %s AssetView 확인 실패" % [id,pair[1]])
			pictures[pair[0]] = "Emblem/"+str(view[0].FilePath)
		var kind: String = str(types.get(int(emblem.Type),""))
		var option: Dictionary = {"id":id,"name":_text(int(emblem.descID)),"source_name":str(emblem.get("Name","")),
			"type":kind,"type_id":int(emblem.Type),"open_grade":int(emblem.OpenGrade),
			"selectable":kind=="Predefined" and int(emblem.OpenGrade)<=local_grade,
			"large":pictures.large,"small":pictures.small}
		if option.name.is_empty(): option.name = option.source_name
		options.append(option)
		by_id[id] = option
	if options.is_empty(): return _fail("EmblemSelectionRegion_Korean 행 없음")
	var fee: Dictionary = {}
	for row: Dictionary in SOURCE.rows("ClanPolicies"):
		if str(row.get("Name",""))=="EmblemChangeCommission":
			fee = {"value":int(row.get("Value",0)),"unit":str(_row("Unit",int(row.get("UnitId",0))).get("Name","")),"class_id":int(row.get("ClassId",0))}
	if fee.is_empty(): return _fail("ClanPolicies EmblemChangeCommission 확인 실패")
	return {"ok":true,"options":options,"by_id":by_id,"local_grade":local_grade,"fee":fee}

## The OpenGrade the player has: the local clan's level (scripts/clan523)
## when a clan exists, else the first ClanExperience level (no clan).
static func grade_for(world: Variant) -> int:
	var data: Dictionary = definition()
	var base: int = int(data.get("local_grade",1))
	var clan: Variant = world.get("clan523") if world is Object and is_instance_valid(world) else null
	if clan is Object and clan.has_method("emblem_grade"): return maxi(base,int(clan.call("emblem_grade")))
	return base

## Predefined emblems open at their OpenGrade; other types are clan data.
static func option_selectable(world: Variant, option: Dictionary) -> bool:
	return str(option.get("type",""))=="Predefined" and int(option.get("open_grade",0))<=grade_for(world)

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "문장 저장 구조 오류"
	if int(value.get("schema",0))!=1 or not _integer(value.get("emblem_id",0)) or int(value.get("emblem_id",0))<0: return "문장 저장 값 오류"
	return ""

func export_state() -> Dictionary:
	return {"schema":1,"emblem_id":emblem_id}

## A saved choice is kept as-is (also when the archive is missing); it is only
## shown when its row is still selectable.
func import_state(value: Variant) -> void:
	problem = ""
	emblem_id = 0
	if value is Dictionary and value.is_empty(): return
	var invalid: String = validate(value)
	if not invalid.is_empty(): problem = invalid; return
	emblem_id = int(value.emblem_id)

func equipped() -> Dictionary:
	if emblem_id<=0: return {}
	var data: Dictionary = definition()
	return data.get("by_id",{}).get(emblem_id,{}) if data.get("ok",false) else {}

## Equips one selectable emblem (0 removes it) and saves through the world.
func choose(world: Node, id: int) -> Dictionary:
	var data: Dictionary = definition()
	if not data.get("ok",false): return {"ok":false,"error":str(data.get("problem",""))}
	if id!=0:
		var option: Dictionary = data.by_id.get(id,{})
		if option.is_empty(): return {"ok":false,"error":"한국 선택 목록에 없는 문장입니다"}
		if not option_selectable(world,option): return {"ok":false,"error":"혈맹 레벨 %d 문장 · 현재 %d" % [int(option.open_grade),grade_for(world)] if option.type=="Predefined" else "혈맹 전용 문장(%s) · 로컬 선택 불가" % option.type}
	if int(data.fee.value)!=0: return {"ok":false,"error":"문장 변경 수수료 %d · 지불 경로 미연결" % int(data.fee.value)}
	if id==emblem_id: return {"ok":true,"unchanged":true,"emblem_id":id}
	var previous: int = emblem_id
	emblem_id = id
	if world!=null and world.has_method("_save_game") and world._save_game(true)!=OK:
		emblem_id = previous
		return {"ok":false,"error":"문장 저장 실패 · 이전 문장 유지"}
	return {"ok":true,"emblem_id":id,"saved":world!=null}
