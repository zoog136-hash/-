extends RefCounted
## Original 523 NPC production (NpcProduction* tables), read only from the
## installed original definition archive.
##
## In the 523 client these tables belong to the LuckyDefence mini game
## (MiniGame 8, ContentsControl "LuckyDefence"): the "produced NPCs" are
## allied defence units ([디펜스][아군 npc] NpcClass rows), not items.
## LuckyDefenceUnitSummon is the only table that points at
## NpcProductionGenerationOutput (NpcProductionGenerationID) and gives each
## summon its cost (CurrencyID 2718 "[디펜스] 마물의 결정", paid with the bag
## item CurrencyUnitClass names: 326368).
##
## Implemented only as the tables state it:
##  - 소환: LuckyDefenceUnitSummon row -> its Cost of the currency item ->
##    one roll over NpcProductionGenerationOutput (Probability per 1,000,000,
##    row ID order). When a generation's probabilities add up to less than
##    1,000,000 the rest of the range gives no unit (영웅/전설 소환 rows sum to
##    11%..40%; a normalised draw would make every level identical).
##  - 조합: NpcProductionCombinationInput (exact NpcClassID multiset of one
##    CombinationID) -> NpcProductionCombinationOutput by Probability.
## Refused (no rule in the tables, see docs/npc_production523_missing_rules.md):
## 합성 (NpcProductionMerge has no output column), summon level changes,
## UnitSummonType 38/48 rows, the in-match wave/currency/placement loop, and
## NpcCombination/NpcCombinationPool (a party-dungeon pool with no input).
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SCALE: int = 1000000
const CONTENTS: String = "LuckyDefence"
## UnitSummonType values whose rows name 랜덤/영웅/전설 소환 and match the
## original Hud_Defense_AttackPad_Random/Epic/Legend pads.
const SUMMON_TYPES: Dictionary = {8:"랜덤 소환",18:"영웅 소환",28:"전설 소환"}
## Lowest player-facing level: rows named "...레벨0" carry Level 1; "레벨X"
## (Level 0) rows have no stated use.
const START_LEVEL: int = 1
const UNIT_PREFIX: String = "[디펜스][아군 npc]"
static var _payment_key: String = ""
static var _payment_items: Dictionary = {}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _fail(reason: String, code: String) -> Dictionary:
	return {"ok":false,"reason":reason,"code":code}

## related() does not record a missing-ID problem in the shared reader.
static func _first(table: String, id: int) -> Dictionary:
	var found: Array[Dictionary] = SOURCE.related(table,"ID",id)
	return found[0] if found.size()==1 else {}

static func installed() -> bool:
	return not SOURCE.not_installed() and SOURCE.row_count("NpcProductionGenerationOutput")>0 and SOURCE.row_count("LuckyDefenceUnitSummon")>0

## ContentsControl Enable of LuckyDefence (false in 523). Shown, not enforced.
static func contents_enabled() -> Variant:
	for row: Dictionary in SOURCE.rows("ContentsControl"):
		if str(row.get("Name",""))==CONTENTS: return row.get("Enable")
	return null

## A produced unit's NpcClass row (must be a [디펜스][아군 npc] row).
static func unit_row(npc_class_id: int) -> Dictionary:
	var row: Dictionary = _first("NpcClass",npc_class_id) if npc_class_id>0 else {}
	if row.is_empty() or row.get("TestNPC")!=false or not str(row.get("Name","")).begins_with(UNIT_PREFIX): return {}
	return row

## "[전설] 16(젠)" from the original NpcClass Name (DescData rows are empty).
static func unit_name(npc_class_id: int) -> String:
	var row: Dictionary = unit_row(npc_class_id)
	return str(row.Name).trim_prefix(UNIT_PREFIX).strip_edges() if not row.is_empty() else "NpcClass %d" % npc_class_id

## The bag item that pays one currency unit (CurrencyUnitClass, ExchangeRate 1).
static func currency_item(currency_id: int) -> Dictionary:
	var currency: Dictionary = _first("Currency",currency_id)
	if currency.is_empty() or not _integer(currency.get("ExchangeRate")) or int(currency.ExchangeRate)!=1: return _fail("원본 재화 정의 확인 실패","currency_row")
	var links: Array = SOURCE.rows_matching("CurrencyUnitClass","CurrencyID",{currency_id:true})
	if links.size()!=1 or not _integer(links[0].get("ClassID")): return _fail("원본 재화의 아이템 연결이 하나로 정해지지 않습니다","currency_unit")
	var item: Dictionary = _first("ItemClass",int(links[0].ClassID))
	if item.is_empty() or item.get("TestItem")!=false: return _fail("원본 재화 아이템 정의 확인 실패","currency_item")
	return {"ok":true,"currency_id":currency_id,"currency_name":str(currency.get("Name","")),"item_class_id":int(links[0].ClassID),"item_name":str(item.get("Name",""))}

## True when `item_class_id` is the bag item of a currency a summon row costs.
## Cached per installed archive (supply profiles are checked for every stack).
static func payment_item(item_class_id: int) -> bool:
	if item_class_id<=0 or not installed(): return false
	var key: String = JSON.stringify(SOURCE.identity())
	if key!=_payment_key:
		_payment_items = {}
		for row: Dictionary in SOURCE.rows("LuckyDefenceUnitSummon"):
			if not _integer(row.get("CurrencyID")): continue
			var paid: Dictionary = currency_item(int(row.CurrencyID))
			if paid.ok: _payment_items[int(paid.item_class_id)] = true
		_payment_key = key
	return _payment_items.has(item_class_id)

## Outputs of one NpcProductionGenerationOutput group, in row ID order.
static func generation(generation_id: int) -> Dictionary:
	var rows: Array = SOURCE.rows_matching("NpcProductionGenerationOutput","GenerationID",{generation_id:true})
	if rows.is_empty(): return _fail("원본 생산 결과 행이 없습니다","generation_missing")
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.ID)<int(b.ID))
	var outputs: Array = []; var total: int = 0
	for row: Dictionary in rows:
		if not _integer(row.get("NpcClassID")) or not _integer(row.get("Probability")) or int(row.Probability)<0: return _fail("원본 생산 결과 행 형식 확인 실패","generation_format")
		if unit_row(int(row.NpcClassID)).is_empty(): return _fail("원본 생산 결과 유닛 정의 확인 실패","generation_unit")
		outputs.append(row.duplicate(true)); total += int(row.Probability)
	if total<=0 or total>SCALE: return _fail("원본 생산 확률 합계가 범위를 벗어납니다","generation_total")
	return {"ok":true,"generation_id":generation_id,"outputs":outputs,"total":total}

## One LuckyDefenceUnitSummon row resolved to cost and outputs.
static func summon(summon_id: int) -> Dictionary:
	if not installed(): return _fail("원본 523 정의 ZIP 미설치 · NPC 생산 보류","source_not_installed")
	var row: Dictionary = _first("LuckyDefenceUnitSummon",summon_id)
	if row.is_empty(): return _fail("원본 소환 행이 없습니다","summon_missing")
	for field: String in ["UnitSummonType","Level","NpcProductionGenerationID","CurrencyID","Cost"]:
		if not _integer(row.get(field)): return _fail("원본 소환 행 형식 확인 실패","summon_format")
	if not SUMMON_TYPES.has(int(row.UnitSummonType)): return _fail("이 소환 종류(UnitSummonType %d)의 의미가 원본 표에 없어 보류합니다" % int(row.UnitSummonType),"summon_type")
	if int(row.Level)!=START_LEVEL: return _fail("소환 레벨을 올리는 조건·비용이 원본 표에 없어 시작 레벨만 사용합니다","summon_level")
	if int(row.Cost)<1: return _fail("원본 소환 비용 확인 실패","summon_cost")
	var paid: Dictionary = currency_item(int(row.CurrencyID))
	if not paid.ok: return paid
	var drawn: Dictionary = generation(int(row.NpcProductionGenerationID))
	if not drawn.ok: return drawn
	return {"ok":true,"summon_id":summon_id,"name":str(row.get("Name","")),"type":int(row.UnitSummonType),"type_name":str(SUMMON_TYPES[int(row.UnitSummonType)]),"level":int(row.Level),"cost":int(row.Cost),"currency":paid,"generation":drawn}

## Usable summons (start level of each known type), in type order.
static func summons() -> Array:
	var result: Array = []
	if not installed(): return result
	var types: Array = SUMMON_TYPES.keys(); types.sort()
	for type_id: int in types:
		for row: Dictionary in SOURCE.rows_matching("LuckyDefenceUnitSummon","UnitSummonType",{type_id:true}):
			if _integer(row.get("Level")) and int(row.Level)==START_LEVEL:
				var entry: Dictionary = summon(int(row.ID))
				if entry.ok: result.append(entry)
	return result

## The output of a roll in [0, SCALE) or {} when the roll is past the total.
static func pick(outputs: Array, roll: int) -> Dictionary:
	var cursor: int = 0
	for row: Dictionary in outputs:
		cursor += int(row.Probability)
		if roll<cursor: return row
	return {}

## NpcProductionCombinationInput/Output of one CombinationID.
static func combination(combination_id: int) -> Dictionary:
	if not installed(): return _fail("원본 523 정의 ZIP 미설치 · NPC 조합 보류","source_not_installed")
	var inputs: Array = SOURCE.rows_matching("NpcProductionCombinationInput","CombinationID",{combination_id:true})
	var outputs: Array = SOURCE.rows_matching("NpcProductionCombinationOutput","CombinationID",{combination_id:true})
	if inputs.is_empty() or outputs.is_empty(): return _fail("원본 조합 재료·결과 행이 없습니다","combination_missing")
	var need: Dictionary = {}
	for row: Dictionary in inputs:
		if not _integer(row.get("NpcClassID")) or unit_row(int(row.NpcClassID)).is_empty(): return _fail("원본 조합 재료 유닛 정의 확인 실패","combination_input")
		var key: String = str(int(row.NpcClassID))
		need[key] = int(need.get(key,0))+1
	outputs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.ID)<int(b.ID))
	var total: int = 0; var clean: Array = []
	for row: Dictionary in outputs:
		if not _integer(row.get("NpcClassID")) or not _integer(row.get("Probability")) or int(row.Probability)<0 or unit_row(int(row.NpcClassID)).is_empty(): return _fail("원본 조합 결과 행 확인 실패","combination_output")
		clean.append(row.duplicate(true)); total += int(row.Probability)
	if total<=0 or total>SCALE: return _fail("원본 조합 결과 확률 합계가 범위를 벗어납니다","combination_total")
	return {"ok":true,"combination_id":combination_id,"inputs":need,"input_rows":inputs.size(),"outputs":clean,"total":total}

static func combinations() -> Array:
	var ids: Dictionary = {}
	if not installed(): return []
	for row: Dictionary in SOURCE.rows("NpcProductionCombinationOutput"):
		if _integer(row.get("CombinationID")): ids[int(row.CombinationID)] = true
	var keys: Array = ids.keys(); keys.sort()
	var result: Array = []
	for id: int in keys:
		var entry: Dictionary = combination(id)
		if entry.ok: result.append(entry)
	return result

## 합성 (NpcProductionMerge): the grade and quantity are stated, the result is not.
static func merge(merge_id: int) -> Dictionary:
	if not installed(): return _fail("원본 523 정의 ZIP 미설치 · NPC 합성 보류","source_not_installed")
	var row: Dictionary = _first("NpcProductionMerge",merge_id)
	if row.is_empty(): return _fail("원본 합성 행이 없습니다","merge_missing")
	return _fail("%s: 같은 등급 %d개를 쓰는 것까지만 원본 표에 있고 결과 유닛·확률이 없어 보류합니다" % [str(row.get("Name","")),int(row.get("Quantity",0))],"merge_output_missing")

static func percent_text(probability: int) -> String:
	var value: float = float(probability)*100.0/float(SCALE)
	return ("%.2f%%" % value).replace(".00%","%")
