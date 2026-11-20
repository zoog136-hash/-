extends RefCounted
## Original 523 blessing powder (용해, BlessPowderAmount) and 질서의 연금
## (Refine*) rules, read only from the installed original definition archive.
##
## Only what the tables state is implemented. Every rule the tables do not
## give is refused here with a reason (and listed in
## docs/bless_refine523_missing_rules.md), never filled with a local guess:
##  - 용해 (normal dissolution): BlessPowderAmount[GradeID][Enchant] of the
##    item's own ItemClass row; BlessConstant BlessPowderRate must be 100 (the
##    only value seen; another value has no stated meaning). Items with an
##    elemental enchant are refused: BlessPowderAmplifyRate gives a rate per
##    elemental level but not how it is applied to the amount or rounded.
##    상급/최상급 용해 (AdvancedBlessPowder*): original consumption rule with a
##    TWILIGHT 근사 helper safe below (the catalyst amount, the below-safe branch
##    and the 최상급 output item are not in the tables).
##  - 질서의 연금: RefineItem (target ItemClassID + exact Enchant) -> group,
##    RefineInput slot 1 (상급 축복의 가루) registered at exactly MinAmount
##    (MinProbability) or MaxAmount (MaxProbability), RefineOutput weighted by
##    Probability, RefineConstants RefineCost in RefineCurrencyID 1 (Adena).
##    Amounts between Min and Max use a straight line (TWILIGHT 근사), the
##    special input (IsSpecialInput, slot 2) is refused (no rule combining it
##    with the main slot), RefineDivinationProb is not used (presentation of
##    the crystal colour only; its MaxGrade meaning is not stated).
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SCALE: int = 1000000
const MAX_DISSOLVE_AMOUNT: int = 9000000000000000000
## The only active (TestItem false) ItemClass rows named 축복의 가루 / 상급
## 축복의 가루. BlessPowderAmount has no item column; 3732 is the 523 item the
## dissolution UI text ("축복의 가루 100") names. 117544 is RefineInput's own
## ItemClassID.
const BLESS_POWDER_ITEM: int = 3732
const ADVANCED_BLESS_POWDER_ITEM: int = 117544
const ADENA_CURRENCY_ID: int = 1
const REFINE_CONTENTS: String = "Refine"

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _fail(reason: String, code: String) -> Dictionary:
	return {"ok":false,"reason":reason,"code":code}

## Value rounded to IEEE float32 (the original client computes these in float).
static func _f32(value: float) -> float:
	var packed := PackedFloat32Array([value])
	return packed[0]

## 일반 용해 (원본 소비 규칙, 보고서2 NEW01): base + ceilf(float32(rate/100) ×
## float32(base)), then × quantity. The preview (dissolve_quote/snapshot) and the
## grant (dissolve) both read this one function.
static func normal_amount(base: int, rate: int, count: int = 1) -> int:
	if base<0 or rate<0 or count<1:return -1
	var share: float = _f32(_f32(_f32(float(rate))/100.0)*_f32(float(base)))
	if not is_finite(share) or share<0.0 or share>=float(MAX_DISSOLVE_AMOUNT):return -1
	var extra: int=int(ceilf(share))
	if base>MAX_DISSOLVE_AMOUNT-extra:return -1
	var each: int=base+extra
	if each>MAX_DISSOLVE_AMOUNT/count:return -1
	return each*count

## 상급/최상급 용해 (원본 소비 규칙, 보고서2 NEW02): base × pow(Multiplier,
## enchant − safe) cut to an integer, plus the elemental increment, × quantity.
## At or below safe the exponent is 0 (TWILIGHT 근사: the original below-safe
## branch is not recovered). -1 when the value leaves the int64 range.
static func advanced_amount(base: int, multiplier: float, enchant: int, safe: int, increment: int, count: int = 1) -> int:
	var scaled: float = float(base)*pow(_f32(multiplier),float(maxi(0,enchant-safe)))
	if not is_finite(scaled) or scaled<0.0 or scaled>=9.0e18: return -1
	var each: int = int(scaled)+increment
	if each<0 or (count>0 and each>9000000000000000000/count): return -1
	return each*count

static func installed() -> bool:
	return not SOURCE.not_installed() and SOURCE.row_count("BlessPowderAmount")>0

## Value of the single row `name` in a Name/Value constant table, or null.
static func constant(table: String, name_value: String) -> Variant:
	var found: Array = []
	for row: Dictionary in SOURCE.rows(table):
		if str(row.get("Name",""))==name_value: found.append(row.get("Value"))
	return found[0] if found.size()==1 else null

## ContentsControl Enable of the original Refine content (false in 523).
static func refine_contents_enabled() -> Variant:
	for row: Dictionary in SOURCE.rows("ContentsControl"):
		if str(row.get("Name",""))==REFINE_CONTENTS: return row.get("Enable")
	return null

static func item_row(item_class_id: int) -> Dictionary:
	return SOURCE.row("ItemClass",item_class_id) if item_class_id>0 else {}

## {ok, item_class_id, amount, grade_id, enchant} for one normal dissolution.
static func dissolve_yield(item_class_id: int, enchant: int, element_level: int, count: int = 1) -> Dictionary:
	if not installed(): return _fail("원본 523 정의 ZIP 미설치 · 용해 보류","source_not_installed")
	var raw: Dictionary = item_row(item_class_id)
	if raw.is_empty() or raw.get("TestItem")!=false: return _fail("원본 아이템 정의 확인 실패","item_row_missing")
	if raw.get("IsSoluble")!=true: return _fail("원본에서 용해할 수 없는 아이템입니다 (IsSoluble)","not_soluble")
	var amplify: int = 0
	if element_level!=0:
		# 원본 소비 규칙(보고서2 NEW01, docs #4): BlessPowderAmplifyRate is a
		# percent whose float32 share of the table amount is rounded UP and
		# added (normal_amount). 인벤 "계산은 강화 가루 + 속성단계 가루" agrees.
		var rates: Array = SOURCE.rows_matching("BlessPowderAmplifyRate","ElementalEnchantLevel",{element_level:true})
		if not APPROX_ELEMENT_AMPLIFY or rates.size()!=1 or not _integer(rates[0].get("AmplifyRate")): return _fail("속성 강화 장비의 가루 증폭 계산식이 원본 표에 없어 보존합니다","amplify_rule_missing")
		amplify = int(rates[0].AmplifyRate)
	var rate: Variant = constant("BlessConstant","BlessPowderRate")
	if not _integer(rate) or int(rate)!=100: return _fail("BlessPowderRate 의미 미확정 · 용해 보류","powder_rate_unresolved")
	if not _integer(raw.get("GradeID")) or enchant<0: return _fail("원본 등급·강화 수치 확인 실패","grade_or_enchant")
	var grade: int = int(raw.GradeID)
	var rows: Array = []
	for row: Dictionary in SOURCE.rows_matching("BlessPowderAmount","GradeID",{grade:true}):
		if _integer(row.get("Enchant")) and int(row.Enchant)==enchant: rows.append(row)
	if rows.size()!=1 or not _integer(rows[0].get("Amount")) or int(rows[0].Amount)<1:
		return _fail("이 등급·강화 수치의 원본 가루 수량 행이 없습니다","amount_row_missing")
	var powder: Dictionary = item_row(BLESS_POWDER_ITEM)
	if powder.is_empty() or powder.get("TestItem")!=false: return _fail("원본 축복의 가루 아이템 정의 확인 실패","powder_item_missing")
	if count<1: return _fail("용해 수량 확인 실패","count")
	var amount: int = normal_amount(int(rows[0].Amount),amplify,count)
	if amount<0:return _fail("용해 수량이 안전한 정수 범위를 초과합니다","amount_overflow")
	var result: Dictionary = {"ok":true,"item_class_id":BLESS_POWDER_ITEM,"amount":amount,"grade_id":grade,"enchant":enchant,"count":count,"source_row":rows[0].duplicate(true)}
	if amplify>0: result.merge({"amplify_percent":amplify,"formula":"NATIVE_BASE_PLUS_CEILF32_RATE"})
	return result

## ---- TWILIGHT 근사(근거 약함) switches, docs/bless_refine523_missing_rules.md
## "근사 적용 (2) 2026-11-16". false restores the earlier refusal.
const APPROX_ELEMENT_AMPLIFY: bool = true
const APPROX_ADVANCED_DISSOLVE: bool = true
const APPROX_SPECIAL_INPUT: bool = true
## Solvents used per dissolved item (no table column; the most conservative).
const ADVANCED_SOLVENT_PER_ITEM: int = 1

## Solvent ItemClass -> {method, output}: ItemBonus DissolutionMethodID and
## SolutionItemClassID of an active Solvent item (상급 용해제 24 → 상급 축복의
## 가루 117544, 최상급 용해제 34 → 최상급 축복의 가루 192654).
static func solvent(item_class_id: int) -> Dictionary:
	var raw: Dictionary = item_row(item_class_id)
	if raw.is_empty() or raw.get("TestItem")!=false: return {}
	var method: int = 0; var output: int = 0
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",item_class_id):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: String = str(SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1))).get("Name",""))
		if type=="DissolutionMethodID" and _integer(bonus.get("Value")): method = int(bonus.Value)
		elif type=="SolutionItemClassID" and _integer(bonus.get("Value")): output = int(bonus.Value)
	if method<=0 or output<=0 or item_row(output).is_empty(): return {}
	return {"item_class_id":item_class_id,"method":method,"output_item_class_id":output}

## 상급/최상급 용해 (docs #5·#6). Rows: AdvancedBlessPowderAmount (ItemCategory,
## GradeID, DissolutionMethodType) -> Amount, Multiplier, MinSafeEnchantLevel,
## ItemEnchantScrollID; AdvancedBlessPowderIncrement (same method, EnchantLevel =
## the item's elemental level) -> Amount, a missing row adds 0 (원본 소비 규칙).
## amount = advanced_amount(Amount, Multiplier, item enchant, safe, increment).
## safe = max(MinSafeEnchantLevel, helper safe). The original helper is not
## recovered; TWILIGHT 근사 uses the item's safe enchant for the row's own
## ItemEnchantScrollID (scroll group): the number of leading 100% stages in
## BmItemEnchantProView (item_safe_enchant). If that cannot be resolved only
## MinSafeEnchantLevel is used. External check: 인벤 "영웅 무기 6강 + 속성 1단 =
## 4090개" = 4000 × 2^(6−6) + 90 (영웅 무기 safe 6).
## Grade range: BlessConstant HighMelt* (24) / Highest*Melt* (34) per category.
static func advanced_dissolve_yield(item_class_id: int, element_level: int, method: int, enchant: int = 0, count: int = 1) -> Dictionary:
	if not installed(): return _fail("원본 523 정의 ZIP 미설치 · 용해 보류","source_not_installed")
	if not APPROX_ADVANCED_DISSOLVE: return _fail("상급·최상급 용해 규칙 미구현","advanced_off")
	var raw: Dictionary = item_row(item_class_id)
	if raw.is_empty() or raw.get("TestItem")!=false: return _fail("원본 아이템 정의 확인 실패","item_row_missing")
	if raw.get("IsSoluble")!=true: return _fail("원본에서 용해할 수 없는 아이템입니다 (IsSoluble)","not_soluble")
	if enchant<0 or count<1: return _fail("강화 수치·수량 확인 실패","grade_or_enchant")
	var category: int = int(raw.get("CategoryID",-1)); var grade: int = int(raw.get("GradeID",-1))
	var bounds: Array = grade_bounds(method,category)
	if bounds.is_empty() or grade<int(bounds[0]) or grade>int(bounds[1]): return _fail("이 용해제로 용해할 수 없는 등급입니다","grade_range")
	var rows: Array = []
	for row: Dictionary in SOURCE.rows("AdvancedBlessPowderAmount"):
		if int(row.get("ItemCategory",-1))==category and int(row.get("GradeID",-1))==grade and int(row.get("DissolutionMethodType",-1))==method: rows.append(row)
	if rows.size()!=1 or not _integer(rows[0].get("Amount")): return _fail("이 종류·등급의 원본 상급 가루 수량 행이 없습니다","advanced_row_missing")
	var row: Dictionary = rows[0]
	var multiplier: Variant = row.get("Multiplier")
	var min_safe: Variant = row.get("MinSafeEnchantLevel")
	if typeof(multiplier) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(multiplier)) or float(multiplier)<1.0 or not _integer(min_safe) or int(min_safe)<0:
		return _fail("원본 상급 가루 배수·안전 강화 열 확인 실패","advanced_row_format")
	var increment: int = 0
	if element_level>0:
		for inc: Dictionary in SOURCE.rows("AdvancedBlessPowderIncrement"):
			if int(inc.get("DissolutionMethodType",-1))==method and int(inc.get("EnchantLevel",-1))==element_level and _integer(inc.get("Amount")): increment = int(inc.Amount)
	var helper: int = item_safe_enchant(item_class_id,int(row.get("ItemEnchantScrollID",-1)))
	var safe: int = maxi(int(min_safe),helper)
	var amount: int = advanced_amount(int(row.Amount),float(multiplier),enchant,safe,increment,count)
	if amount<0: return _fail("상급 가루 수량이 표현 범위를 넘습니다","overflow")
	return {"ok":true,"method":method,"grade_id":grade,"category":category,"amount":amount,"base":int(row.Amount),"increment":increment,
		"enchant":enchant,"count":count,"multiplier":float(multiplier),"min_safe":int(min_safe),"helper_safe":helper,"safe":safe,
		"approximation":"TWILIGHT_ADVANCED_DISSOLVE_HELPER_SAFE" if helper>=0 else "TWILIGHT_ADVANCED_DISSOLVE_MIN_SAFE_ONLY"}

## TWILIGHT 근사 of the original "helper safe": leading 100% (1000000) Success
## stages in BmItemEnchantProView for the probability group shared by the item's
## EnchantEquipGroupID and the scroll group. Bless code 1 rows win over 0 rows.
## -1 when the group is missing or not unique.
static func item_safe_enchant(item_class_id: int, scroll_group: int) -> int:
	if scroll_group<0: return -1
	var equip: Dictionary = {}
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",item_class_id):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		if str(SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1))).get("Name",""))=="EnchantEquipGroupID" and _integer(bonus.get("Value")): equip[int(bonus.Value)] = true
	if equip.is_empty(): return -1
	var probability: Dictionary = {}
	for map: Dictionary in SOURCE.rows("ItemEnchantEquipGroupMapping"):
		if equip.has(int(map.get("ItemEnchantEquipGroupID",-1))): probability[int(map.get("ItemEnchantProbabilityGroupID",-1))] = true
	var groups: Array = []
	for map: Dictionary in SOURCE.rows("ItemEnchantScrollGroupMapping"):
		var group: int = int(map.get("ItemEnchantProbabilityGroupID",-1))
		if int(map.get("ItemEnchantScrollGroupID",-1))==scroll_group and probability.has(group) and group not in groups: groups.append(group)
	if groups.size()!=1: return -1
	var success: Dictionary = {}
	for view: Dictionary in SOURCE.rows("BmItemEnchantProView"):
		if int(view.get("ItemEnchantProbabilityGroupID",-1))!=groups[0]: continue
		var code: int = int(view.get("TargetItemBlessCode",-1)); var level: int = int(view.get("EnchantLevel",-1))
		if code==1 or (code==0 and not success.has(level)): success[level] = int(view.get("Success",0))
	var safe: int = 0
	while int(success.get(safe,0))==1000000: safe += 1
	return safe

static func grade_bounds(method: int, category: int) -> Array:
	var names: Array = []
	if method==24: names = ["HighMeltGradeMinValue","HighMeltGradeMaxValue"]
	elif method==34:
		match category:
			1: names = ["HighestWeaponMeltGradeMinValue","HighestWeaponMeltGradeMaxValue"]
			2: names = ["HighestArmorMeltGradeMinValue","HighestArmorMeltGradeMaxValue"]
			43: names = ["HighestAccessoryMeltGradeMinValue","HighestAccessoryMeltGradeMaxValue"]
	if names.is_empty(): return []
	var low: Variant = constant("BlessConstant",names[0]); var high: Variant = constant("BlessConstant",names[1])
	return [int(low),int(high)] if _integer(low) and _integer(high) else []

## 특수 재료(2번 슬롯, TWILIGHT 근사 docs #12): its own Min~Max probability on the
## same straight line, added to the main probability and capped at 100%.
static func special_registration(entry: Dictionary, amount: int) -> Dictionary:
	if amount<=0: return {"ok":true,"amount":0,"probability":0}
	if not APPROX_SPECIAL_INPUT or entry.get("special_inputs",[]).size()!=1: return _fail("특수 재료 규칙 미확정","special_input")
	var registered: Dictionary = registration({"input":entry.special_inputs[0]},"amount:%d" % amount)
	if not registered.ok: return registered
	registered["item_class_id"] = int(entry.special_inputs[0].ItemClassID)
	return registered

## Original refine recipe for one target ItemClassID at its exact enchant.
static func refine_entry(item_class_id: int, enchant: int) -> Dictionary:
	if not installed(): return _fail("원본 523 정의 ZIP 미설치 · 질서의 연금 보류","source_not_installed")
	var targets: Array = []
	for row: Dictionary in SOURCE.rows_matching("RefineItem","ItemClassID",{item_class_id:true}):
		if _integer(row.get("Enchant")) and int(row.Enchant)==enchant: targets.append(row)
	if targets.is_empty(): return _fail("질서의 연금 대상이 아닌 장비·강화 수치입니다","not_refine_target")
	if targets.size()!=1 or not _integer(targets[0].get("RefineItemGroupID")): return _fail("원본 연금 대상 행이 하나로 정해지지 않습니다","ambiguous_target")
	var group: int = int(targets[0].RefineItemGroupID)
	if SOURCE.rows_matching("RefineItemGroup","ID",{group:true}).size()!=1: return _fail("원본 연금 그룹 행 확인 실패","group_missing")
	var main: Array = []; var special: Array = []
	for row: Dictionary in SOURCE.rows_matching("RefineInput","RefineItemGroupID",{group:true}):
		for field: String in ["ItemClassID","MinAmount","MaxAmount","MinProbability","MaxProbability","SlotIndex"]:
			if not _integer(row.get(field)): return _fail("원본 연금 재료 행 형식 확인 실패","input_format")
		if row.get("IsSpecialInput")==true: special.append(row)
		elif row.get("IsSpecialInput")==false and int(row.SlotIndex)==1: main.append(row)
		else: return _fail("원본 연금 재료 슬롯 의미 미확정","input_slot")
	if main.size()!=1: return _fail("원본 연금 기본 재료 행이 하나가 아닙니다","main_input")
	var input: Dictionary = main[0]
	if int(input.MinAmount)<1 or int(input.MaxAmount)<int(input.MinAmount) or int(input.MinProbability)<0 or int(input.MaxProbability)>SCALE or int(input.MinProbability)>int(input.MaxProbability):
		return _fail("원본 연금 재료 수량·확률 범위 확인 실패","input_range")
	var outputs: Array = []; var total: int = 0
	for row: Dictionary in SOURCE.rows_matching("RefineOutput","RefineItemGroupID",{group:true}):
		for field: String in ["ItemClassID","Probability","Enchant","Amount","ClassID"]:
			if not _integer(row.get(field)): return _fail("원본 연금 결과 행 형식 확인 실패","output_format")
		# ClassID 0 throughout 523; a class-limited output has no stated rule.
		if int(row.ClassID)!=0 or int(row.Amount)!=1 or int(row.Probability)<0 or int(row.Enchant)<0: return _fail("원본 연금 결과의 직업·수량 조건 미지원","output_unsupported")
		var output_raw: Dictionary = item_row(int(row.ItemClassID))
		if output_raw.is_empty() or output_raw.get("TestItem")!=false: return _fail("원본 연금 결과 아이템 정의 확인 실패","output_item")
		outputs.append(row); total += int(row.Probability)
	if outputs.is_empty() or total!=SCALE: return _fail("원본 연금 결과 확률 합계가 100%가 아닙니다","output_total")
	var cost: Variant = constant("RefineConstants","RefineCost")
	var currency: Variant = constant("RefineConstants","RefineCurrencyID")
	var target_max: Variant = constant("RefineConstants","TargetItemMaxAmount")
	if not _integer(cost) or int(cost)<0 or not _integer(currency) or int(currency)!=ADENA_CURRENCY_ID or not _integer(target_max) or int(target_max)!=1:
		return _fail("원본 연금 비용·대상 수량 상수 확인 실패","constants")
	return {"ok":true,"group_id":group,"target_row":targets[0].duplicate(true),"input":input.duplicate(true),"special_inputs":special.duplicate(true),"outputs":outputs.duplicate(true),"cost":int(cost),"currency_id":int(currency),"contents_enabled":refine_contents_enabled()}

## TWILIGHT 근사 (user policy 2026-11-16 "원본 데이터에 없는 건 검색 후 근사치로
## 적용해"): the tables give only the two endpoints. A registered amount between
## them takes the straight-line probability between the endpoints, rounded
## down to the SCALE unit. Basis: the 523 rows themselves are proportional
## (10,000→10% · 20,000→20%, 1% per 1,000 powder) and a player report
## "확률 10% 부터 도전이 가능 … 9천개니깐 확률 9%?" (인벤, 2021-02-08,
## https://www.inven.co.kr/board/lineagem/5056/17012, checked 2026-11-16).
## Recorded in docs/bless_refine523_missing_rules.md #11. Set to false to
## return to endpoint-only registration.
const APPROX_LINEAR_BETWEEN: bool = true

## Registered amount and success probability (per SCALE). mode is "min",
## "max" or "amount:N" (N inside [MinAmount, MaxAmount], TWILIGHT 근사).
static func registration(entry: Dictionary, mode: String) -> Dictionary:
	var input: Dictionary = entry.get("input",{})
	match mode:
		"min": return {"ok":true,"mode":mode,"amount":int(input.MinAmount),"probability":int(input.MinProbability)}
		"max": return {"ok":true,"mode":mode,"amount":int(input.MaxAmount),"probability":int(input.MaxProbability)}
	if not mode.begins_with("amount:") or not APPROX_LINEAR_BETWEEN or not mode.get_slice(":",1).is_valid_int():
		return _fail("최소·최대 사이 수량의 확률 계산식이 원본 표에 없습니다","amount_between")
	var amount: int = int(mode.get_slice(":",1))
	var low: int = int(input.MinAmount); var high: int = int(input.MaxAmount)
	if amount<low or amount>high: return _fail("등록 수량은 원본 최소 %d ~ 최대 %d개입니다" % [low,high],"amount_range")
	var probability: int = int(input.MinProbability)
	if high>low: probability += int(floor(float(int(input.MaxProbability)-int(input.MinProbability))*float(amount-low)/float(high-low)))
	return {"ok":true,"mode":"amount","amount":amount,"probability":clampi(probability,int(input.MinProbability),int(input.MaxProbability)),"approximation":"TWILIGHT_LINEAR_BETWEEN_ENDPOINTS"}

## Shown as the original help text says: percent with decimals cut off.
static func percent_text(probability: int) -> String:
	return "%d%%" % int(floor(float(probability)*100.0/float(SCALE)))

static func pick_output(entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var outputs: Array = entry.get("outputs",[])
	if outputs.size()==1: return outputs[0]
	var roll: int = rng.randi_range(0,SCALE-1)
	var cursor: int = 0
	for row: Dictionary in outputs:
		cursor += int(row.Probability)
		if roll<cursor: return row
	return outputs[outputs.size()-1]
