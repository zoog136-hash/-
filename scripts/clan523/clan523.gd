extends RefCounted
## Original 523 혈맹 (Clan) as the local player's OWN clan, offline.
## In Lineage M a clan is many players; TWILIGHT has one, so only the part the
## original tables define for the founder (Owner) alone is connected:
##  - creation: ClanCreateGameClass (GameClassID 8 = 군주 only),
##    ClanPolicies CreateLevelCondition (Lv.30) / CreateCommission (100,000
##    아데나, Unit 4 ItemClassID 26); the founder is ClanMemberRankType Owner.
##  - clan level: ClanExperience.CumulativeExperience of level L is the clan
##    experience that completes L (level 20 = 999,999,999,999,999, the cap).
##    A new clan is level 1 (the first row; ClanContentLevelRestriction and
##    Emblem.OpenGrade start at 1).
##  - clan experience: ClanDonate (일반 200,000 아데나 · 고급 100 · 최고급 300
##    Gem) with its ClanDonateReward rows (Unit ClanExperience, ItemClassID,
##    ClanDonatePoint, Einasad), ClanPolicies DonateExpRatio, MaxDonateCount
##    and ClanDonatePolicy.DailyMaxDonatePoint per day (TWILIGHT game day,
##    KST 05:00), WeeklyMaxDonatePoint and ClanDonateWeeklyReward per week.
##  - clan buff: ClanReward(Level) -> Reward (RewardType Buff) -> BuffClass
##    "[혈맹] 버프 N단계" -> BuffBonus -> Bonus; applied for the current level
##    with the same BonusType -> buff key mapping as the timed item buffs.
##  - level benefits text: UIClanBenefit (ContentsDescID, BuffIconAssetID).
## Everything else (members, joining, wars, alliances, raids, ranking, clan
## quests, hunting clan experience) is online-only or has no table rule and is
## listed in docs/clan523_missing_rules.md.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SAVE_KEY := "clan523"
const SCHEMA := 1
const RETRY_MSEC := 30000
const NAME_MAX := 16
## Buff key the existing consumers read (world._active_item_buff_total, and
## _catalog_damage_bonus for magic_damage) per original BonusType, Unit Value.
## Same mapping as current523_native_item_projection timed buffs.
const FIELDS := {"ArmorClassBonus":"def","HPPlus":"hp_flat","MPPlus":"mp_flat","DamageReduction":"damage_reduction",
	"MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","MagicDamage":"magic_damage",
	"MeleeHit":"melee_accuracy","RangeHit":"ranged_accuracy","MagicHit":"magic_accuracy"}
## Percentage effects read as whole percent points (Value / UIUnit Denominator).
const PERCENT_FIELDS := {"ExperienceAdditionPercent":"xp"}
const LABELS := {"def":"AC","hp_flat":"최대 HP","mp_flat":"최대 MP","damage_reduction":"대미지 리덕션","melee_damage":"근거리 대미지",
	"ranged_damage":"원거리 대미지","magic_damage":"마법 대미지","melee_accuracy":"근거리 명중","ranged_accuracy":"원거리 명중",
	"magic_accuracy":"마법 명중","xp":"획득 경험치 %"}
const POLICIES := ["CreateLevelCondition","CreateCommission","MaxDonateCount","WeeklyMaxDonatePoint","DonateExpRatio","AdenaDonateID"]

static var _definition: Dictionary = {}
static var _attempted_at: int = -RETRY_MSEC

var state: Dictionary = {}
var problem: String = ""
var now_override: int = -1
var _effects_level: int = -1
var _effects: Dictionary = {}

static func reset_cache() -> void:
	_definition = {}; _attempted_at = -RETRY_MSEC

## Uses an already built definition (tests build one from synthetic rows).
static func use_definition(value: Dictionary) -> void:
	_definition = value.duplicate(true); _attempted_at = Time.get_ticks_msec()

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"problem":reason}

## {"ok", ...} from the installed original definition ZIP (cached).
static func definition() -> Dictionary:
	if _definition.get("ok",false): return _definition
	var now: int = Time.get_ticks_msec()
	if not _definition.is_empty() and now-_attempted_at<RETRY_MSEC: return _definition
	_attempted_at = now
	if SOURCE.identity().is_empty(): _definition = _fail("원본523 정의 ZIP 미설치: "+SOURCE.problem())
	else: _definition = build(SOURCE)
	return _definition

static func _text(src: Variant, id: int) -> String:
	if id<=0: return ""
	var matches: Array = src.related("DescData_Korean","ID",id)
	return "" if matches.is_empty() else str(matches[-1].get("Description",""))

static func _one(src: Variant, table: String, id: int) -> Dictionary:
	var matches: Array = src.related(table,"ID",id)
	return matches[0] if matches.size()==1 else {}

static func _names(src: Variant, table: String) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in src.rows(table):
		if _integer(row.get("ID")): result[int(row.ID)] = str(row.get("Name",""))
	return result

## Builds the clan rules from any table source with rows(table),
## related(table, field, id) (the original rows, or a synthetic test source).
static func build(src: Variant) -> Dictionary:
	var levels: Array = []
	for row: Dictionary in src.rows("ClanExperience"):
		if not _integer(row.get("Level")) or not _integer(row.get("CumulativeExperience")): return _fail("ClanExperience 형식 오류")
		levels.append({"level":int(row.Level),"cumulative":int(row.CumulativeExperience)})
	if levels.is_empty(): return _fail("ClanExperience 행 없음")
	levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.level)<int(b.level))
	for index: int in range(levels.size()):
		if int(levels[index].level)!=index+1 or (index>0 and int(levels[index].cumulative)<=int(levels[index-1].cumulative)): return _fail("ClanExperience 레벨·누적 경험치 순서 오류")
	var policies: Dictionary = {}
	for row: Dictionary in src.rows("ClanPolicies"):
		var name: String = str(row.get("Name",""))
		if name not in POLICIES: continue
		if policies.has(name) or not _integer(row.get("Value")) or not _integer(row.get("UnitId",0)) or not _integer(row.get("ClassId",0)): return _fail("ClanPolicies %s 형식 오류" % name)
		policies[name] = {"value":int(row.Value),"unit_id":int(row.get("UnitId",0)),"class_id":int(row.get("ClassId",0))}
	for name: String in POLICIES:
		if not policies.has(name): return _fail("ClanPolicies %s 없음" % name)
	var units: Dictionary = _names(src,"Unit")
	var commission: Dictionary = policies.CreateCommission
	if units.get(commission.unit_id)!="ItemClassID" or commission.class_id!=26: return _fail("CreateCommission 단위 확인 실패")
	var classes: Array[int] = []
	for row: Dictionary in src.rows("ClanCreateGameClass"):
		if not _integer(row.get("GameClassID")): return _fail("ClanCreateGameClass 형식 오류")
		classes.append(int(row.GameClassID))
	if classes.is_empty(): return _fail("ClanCreateGameClass 행 없음")
	var class_names: Array[String] = []
	for id: int in classes: class_names.append(_text(src,int(_one(src,"Class",id).get("DescID",0))))
	var owner: String = ""
	for row: Dictionary in src.rows("ClanMemberRankType"):
		if str(row.get("Name",""))=="Owner": owner = _text(src,int(row.get("DescID",0)))
	if owner.is_empty(): return _fail("ClanMemberRankType Owner 확인 실패")
	# Payment currencies: Currency -> CurrencyUnitClass (the only source row).
	var currency_rows: Dictionary = {}
	for row: Dictionary in src.rows("CurrencyUnitClass"):
		if not _integer(row.get("CurrencyID")): continue
		if not currency_rows.has(int(row.CurrencyID)): currency_rows[int(row.CurrencyID)] = []
		currency_rows[int(row.CurrencyID)].append(row)
	var donate_policy: Dictionary = {}
	for row: Dictionary in src.rows("ClanDonatePolicy"):
		if not _integer(row.get("ClanDonateID")) or not _integer(row.get("DailyMaxDonatePoint")) or donate_policy.has(int(row.ClanDonateID)): return _fail("ClanDonatePolicy 형식 오류")
		donate_policy[int(row.ClanDonateID)] = int(row.DailyMaxDonatePoint)
	var donates: Array = []
	var by_donate: Dictionary = {}
	for row: Dictionary in src.rows("ClanDonate"):
		for field: String in ["ID","PaymentCurrencyID","Amount","SlotType"]:
			if not _integer(row.get(field)): return _fail("ClanDonate %s 형식 오류" % field)
		var id: int = int(row.ID)
		var currency: Dictionary = _one(src,"Currency",int(row.PaymentCurrencyID))
		var sources: Array = currency_rows.get(int(row.PaymentCurrencyID),[])
		if currency.is_empty() or sources.size()!=1: return _fail("ClanDonate #%d 결제 재화 확인 실패" % id)
		var source: Dictionary = sources[0]
		var payment: Dictionary = {"currency_id":int(row.PaymentCurrencyID),"currency":str(currency.get("Name","")),"unit":str(units.get(int(source.get("UnitID",0)),"")),"class_id":int(source.get("ClassID",0)),"amount":int(row.Amount)}
		var rewards: Array = []
		for reward: Dictionary in src.related("ClanDonateReward","ClanDonateID",id):
			if not _integer(reward.get("UnitID")) or not _integer(reward.get("ClassID")) or not _integer(reward.get("Amount")) or int(reward.Amount)<1: return _fail("ClanDonateReward 형식 오류")
			rewards.append({"id":int(reward.get("ID",0)),"unit":str(units.get(int(reward.UnitID),"")),"class_id":int(reward.ClassID),"amount":int(reward.Amount),
				"name":_text(src,int(_one(src,"ItemClass",int(reward.ClassID)).get("DescID",0))) if str(units.get(int(reward.UnitID),""))=="ItemClassID" else ""})
		var entry: Dictionary = {"id":id,"name":_text(src,int(row.get("DescID",0))),"source_name":str(row.get("Name","")),"slot":int(row.SlotType),
			"payment":payment,"rewards":rewards,"daily_max_point":int(donate_policy.get(id,0)),"has_daily_max":donate_policy.has(id)}
		if str(entry.name).is_empty(): entry.name = entry.source_name
		donates.append(entry); by_donate[id] = entry
	if donates.is_empty(): return _fail("ClanDonate 행 없음")
	donates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.slot)<int(b.slot))
	var weekly: Array = []
	for row: Dictionary in src.rows("ClanDonateWeeklyReward"):
		if not _integer(row.get("ID")) or not _integer(row.get("DonatePoint")) or not _integer(row.get("RewardID")): return _fail("ClanDonateWeeklyReward 형식 오류")
		var reward: Dictionary = _one(src,"Reward",int(row.RewardID))
		var kind: String = str(_one(src,"RewardType",int(reward.get("RewardTypeID",0))).get("Name",""))
		weekly.append({"id":int(row.ID),"points":int(row.DonatePoint),"bonus":row.get("IsBonus")==true,"reward_id":int(row.RewardID),"kind":kind,
			"class_id":int(reward.get("RewardClassID",0)),"amount":int(reward.get("Amount",0)),"bless":int(reward.get("ItemBlessCodeID",1)),
			"name":_text(src,int(_one(src,"ItemClass",int(reward.get("RewardClassID",0))).get("DescID",0))) if kind=="Item" else ""})
	weekly.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.points)<int(b.points))
	var benefits: Dictionary = {}
	for row: Dictionary in src.rows("UIClanBenefit"):
		if not _integer(row.get("ClanLevel")): continue
		benefits[int(row.ClanLevel)] = {"text":_text(src,int(row.get("ContentsDescID",0))),"icon_asset_id":int(row.get("BuffIconAssetID",0))}
	var buffs: Dictionary = {}
	for row: Dictionary in src.rows("ClanReward"):
		if not _integer(row.get("Level")) or not _integer(row.get("RewardID")): return _fail("ClanReward 형식 오류")
		buffs[int(row.Level)] = _buff(src,int(row.RewardID),units)
	return {"ok":true,"levels":levels,"max_level":int(levels[-1].level),"policies":policies,"create_classes":classes,"create_class_names":class_names,
		"owner_rank":owner,"donates":donates,"by_donate":by_donate,"weekly":weekly,"benefits":benefits,"buffs":buffs}

## One level's clan buff: {buff_class_id, name, effects{key:value}, held[{type,value,reason}]}.
static func _buff(src: Variant, reward_id: int, units: Dictionary) -> Dictionary:
	var reward: Dictionary = _one(src,"Reward",reward_id)
	var result: Dictionary = {"reward_id":reward_id,"effects":{},"held":[],"rows":[]}
	if str(_one(src,"RewardType",int(reward.get("RewardTypeID",0))).get("Name",""))!="Buff": result.problem = "Reward #%d 버프 아님" % reward_id; return result
	var buff: Dictionary = _one(src,"BuffClass",int(reward.get("RewardClassID",0)))
	if buff.is_empty(): result.problem = "BuffClass #%d 없음" % int(reward.get("RewardClassID",0)); return result
	result.buff_class_id = int(buff.ID)
	result.name = _text(src,int(buff.get("DescID",0)))
	if str(result.name).is_empty(): result.name = str(buff.get("Name",""))
	for link: Dictionary in src.related("BuffBonus","BuffClassID",int(buff.ID)):
		var bonus: Dictionary = _one(src,"Bonus",int(link.get("BonusID",0)))
		var type: Dictionary = _one(src,"BonusType",int(bonus.get("BonusTypeID",0)))
		var name: String = str(type.get("Name",""))
		var unit: String = str(units.get(int(type.get("UnitID",0)),""))
		var value: Variant = bonus.get("Value")
		result.rows.append({"type":name,"value":value,"unit":unit})
		var conditional: bool = int(bonus.get("BonusApplicationTypeID",0))!=0 or int(bonus.get("BonusApplicationTargetID",0))!=0
		for key: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
			if int(link.get(key,0))!=0: conditional = true
		if bonus.is_empty() or type.is_empty() or not _integer(value): result.held.append({"type":name,"value":value,"reason":"행 형식 오류"}); continue
		if conditional: result.held.append({"type":name,"value":int(value),"reason":"조건부 효과(적용 대상·레벨·직업)"}); continue
		if PERCENT_FIELDS.has(name) and unit=="Percentage":
			var scale: Array = src.related("UIUnit","UnitID",int(type.get("UnitID",0)))
			if scale.size()!=1 or int(scale[0].get("Denominator",0))!=10000 or int(value)%10000!=0:
				result.held.append({"type":name,"value":int(value),"reason":"백분율 분모 해석 불가"}); continue
			var key: String = PERCENT_FIELDS[name]
			result.effects[key] = int(result.effects.get(key,0))+int(value)/10000
		elif FIELDS.has(name) and unit=="Value":
			var key2: String = FIELDS[name]
			result.effects[key2] = int(result.effects.get(key2,0))+int(value)
		else:
			result.held.append({"type":name,"value":int(value),"reason":"게임에 이 효과를 읽는 곳 없음"})
	return result

## Clan level of an experience total: 1 + the levels it has completed.
static func level_for(levels: Array, experience: int) -> int:
	var level: int = 1
	for row: Dictionary in levels:
		if experience>=int(row.cumulative) and int(row.level)<int(levels[-1].level): level = int(row.level)+1
	return mini(level,int(levels[-1].level)) if not levels.is_empty() else 0

## --- Save -----------------------------------------------------------------

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "혈맹 저장 구조 오류"
	if (value as Dictionary).is_empty(): return ""
	if not _integer(value.get("schema")) or int(value.schema)!=SCHEMA: return "혈맹 저장 스키마 오류"
	if not value.get("name") is String or str(value.name).strip_edges().is_empty() or str(value.name).length()>NAME_MAX: return "혈맹 이름 저장 오류"
	for key: String in ["created_at","experience","day","week","week_points"]:
		if not _integer(value.get(key)) or int(value[key])<0: return "혈맹 저장 값 오류: "+key
	for key: String in ["donations","day_points"]:
		if not value.get(key) is Dictionary: return "혈맹 저장 값 오류: "+key
		for id: Variant in value[key]:
			if not str(id).is_valid_int() or not _integer(value[key][id]) or int(value[key][id])<0: return "혈맹 저장 값 오류: "+key
	if not value.get("weekly_claimed") is Array: return "혈맹 저장 값 오류: weekly_claimed"
	for id: Variant in value.weekly_claimed:
		if not _integer(id): return "혈맹 저장 값 오류: weekly_claimed"
	return ""

func export_state() -> Dictionary:
	return state.duplicate(true)

func import_state(value: Variant) -> void:
	problem = ""
	state = {}
	_effects_level = -1
	var invalid: String = validate(value)
	if not invalid.is_empty(): problem = invalid; return
	state = (value as Dictionary).duplicate(true)
	for key: String in ["created_at","experience","day","week","week_points"]:
		if state.has(key): state[key] = int(state[key])
	if state.has("weekly_claimed"):
		var claimed: Array = []
		for id: Variant in state.weekly_claimed: claimed.append(int(id))
		state.weekly_claimed = claimed

## --- Queries ----------------------------------------------------------------

func has_clan() -> bool:
	return not state.is_empty()

func now() -> int:
	return now_override if now_override>=0 else int(Time.get_unix_time_from_system())

static func day_key(unix_time: int) -> int:
	return preload("res://scripts/routine523/routine523_runtime.gd").period_key("daily",unix_time)

static func week_key(unix_time: int) -> int:
	return preload("res://scripts/routine523/routine523_runtime.gd").period_key("weekly",unix_time)

## The clan level (0 without a clan or without the tables).
func level() -> int:
	if not has_clan(): return 0
	var data: Dictionary = definition()
	return level_for(data.levels,int(state.experience)) if data.get("ok",false) else 0

## Buff value of the current clan level for one existing buff key.
func buff_value(key: String) -> int:
	var current: int = level()
	if current!=_effects_level:
		_effects_level = current
		_effects = definition().get("buffs",{}).get(current,{}).get("effects",{}) if current>0 else {}
	return int(_effects.get(key,0))

## Daily/weekly counters rolled forward to now (a copy; state is untouched).
func _rolled(base: Dictionary, at: int) -> Dictionary:
	var next: Dictionary = base.duplicate(true)
	var day: int = day_key(at)
	if int(next.get("day",-1))!=day:
		next.day = day; next.donations = {}; next.day_points = {}
	var week: int = week_key(at)
	if int(next.get("week",-1))!=week:
		next.week = week; next.week_points = 0; next.weekly_claimed = []
	return next

func view_state() -> Dictionary:
	return _rolled(state,now()) if has_clan() else {}

## Original Class ID of the character's job: the base catalog's class row,
## else the reviewed job -> class map of the 523 skill bindings (repo data).
static func _class_id(world: Object) -> int:
	var job: String = str(world.get("job_class"))
	var id: int = int(preload("res://scripts/lineagem_base508.gd").source_class_id(job))
	if id>0: return id
	var bindings: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/player_skills523_bindings.json"))
	var value: Variant = bindings.get("class_ids",{}).get(job) if bindings is Dictionary else null
	return int(value) if _integer(value) else 0

## --- Creation ---------------------------------------------------------------

func create_quote(world: Object) -> Dictionary:
	var data: Dictionary = definition()
	if not data.get("ok",false): return {"ok":false,"reason":str(data.get("problem",""))}
	if has_clan(): return {"ok":false,"reason":"이미 혈맹이 있습니다"}
	if not problem.is_empty(): return {"ok":false,"reason":"혈맹 저장 보호 중: "+problem}
	if world==null: return {"ok":false,"reason":"게임 연결 없음"}
	if _class_id(world) not in data.create_classes: return {"ok":false,"reason":"혈맹 창설은 %s만 가능합니다 (ClanCreateGameClass) · 다른 직업은 다른 군주의 혈맹 가입(온라인)" % "/".join(data.create_class_names)}
	var need_level: int = int(data.policies.CreateLevelCondition.value)
	if int(world.get("level"))<need_level: return {"ok":false,"reason":"혈맹 창설은 %d레벨 이상 (CreateLevelCondition)" % need_level}
	var fee: int = int(data.policies.CreateCommission.value)
	if int(world.get("gold"))<fee: return {"ok":false,"reason":"창설 수수료 아데나 %d 부족" % fee}
	return {"ok":true,"fee":fee,"level":need_level}

func create(world: Object, clan_name: String) -> Dictionary:
	var quote: Dictionary = create_quote(world)
	if not quote.ok: return quote
	var trimmed: String = clan_name.strip_edges()
	if trimmed.is_empty() or trimmed.length()>NAME_MAX: return {"ok":false,"reason":"혈맹 이름은 1~%d자" % NAME_MAX}
	var at: int = now()
	var next: Dictionary = {"schema":SCHEMA,"name":trimmed,"created_at":at,"experience":0,"day":day_key(at),"donations":{},"day_points":{},"week":week_key(at),"week_points":0,"weekly_claimed":[]}
	return _commit(world,next,{"gold":int(world.get("gold"))-int(quote.fee)},"혈맹 '%s' 창설 · 아데나 %d" % [trimmed,int(quote.fee)])

## Saves `next` (with the inventory/gold overrides) or restores the old state.
func _commit(world: Object, next: Dictionary, overrides: Dictionary, message: String) -> Dictionary:
	var previous: Dictionary = state.duplicate(true)
	state = next
	_effects_level = -1
	var saved: bool = true
	if world!=null and world.has_method("_save_game"):
		saved = world.call("_save_game",true,overrides)==OK
	if not saved:
		state = previous; _effects_level = -1
		return {"ok":false,"reason":"혈맹 저장 실패 · 이전 상태 유지"}
	if world!=null:
		if overrides.has("gold"): world.set("gold",int(overrides.gold))
		if overrides.has("inventory"): world.set("inventory",overrides.inventory)
		if overrides.has("item_instances"): world.set("item_instances",overrides.item_instances)
		if world.has_method("_refresh_after_clan_change"): world.call("_refresh_after_clan_change")
	return {"ok":true,"reason":message,"level":level()}

## --- Donation ---------------------------------------------------------------

## Game wallet of a donation payment: Currency -> CurrencyUnitClass source.
static func payment_wallet(payment: Dictionary) -> String:
	if payment.get("unit")=="ItemClassID" and int(payment.get("class_id",0))==26: return "아데나"
	if payment.get("unit")=="IntangibleItemClassID":
		return str(preload("res://scripts/shop/source523_shop_runtime.gd").INTANGIBLE_BINDINGS.get(int(payment.get("class_id",0)),""))
	return ""

static func _balance(world: Object, wallet: String) -> int:
	if wallet=="아데나": return int(world.get("gold"))
	return int((world.get("inventory") as Dictionary).get(wallet,0))

func donate_quote(world: Object, donate_id: int) -> Dictionary:
	var data: Dictionary = definition()
	if not data.get("ok",false): return {"ok":false,"reason":str(data.get("problem",""))}
	if not has_clan(): return {"ok":false,"reason":"혈맹이 없습니다"}
	if not problem.is_empty(): return {"ok":false,"reason":"혈맹 저장 보호 중"}
	var entry: Dictionary = data.by_donate.get(donate_id,{})
	if entry.is_empty(): return {"ok":false,"reason":"기부 종류 없음"}
	var wallet: String = payment_wallet(entry.payment)
	if wallet.is_empty(): return {"ok":false,"reason":"기부 재화(%s)의 게임 지갑 연결 없음" % str(entry.payment.currency)}
	var rolled: Dictionary = _rolled(state,now())
	var total: int = 0
	for id: Variant in rolled.donations: total += int(rolled.donations[id])
	var max_count: int = int(data.policies.MaxDonateCount.value)
	if total>=max_count: return {"ok":false,"reason":"오늘 기부 %d/%d회 완료 (MaxDonateCount)" % [total,max_count]}
	var points: int = 0; var experience: int = 0
	for reward: Dictionary in entry.rewards:
		if reward.unit=="ClanDonatePoint": points += int(reward.amount)
		if reward.unit=="ClanExperience": experience += int(reward.amount)*int(data.policies.DonateExpRatio.value)
	if entry.has_daily_max and int(rolled.day_points.get(str(donate_id),0))+points>int(entry.daily_max_point): return {"ok":false,"reason":"오늘 %s 기부 포인트 한도 %d" % [str(entry.name),int(entry.daily_max_point)]}
	var amount: int = int(entry.payment.amount)
	if _balance(world,wallet)<amount: return {"ok":false,"reason":"%s %d 부족" % [wallet,amount]}
	return {"ok":true,"entry":entry,"wallet":wallet,"amount":amount,"points":points,"experience":experience,"count":total,"max_count":max_count}

func donate(world: Object, donate_id: int) -> Dictionary:
	var quote: Dictionary = donate_quote(world,donate_id)
	if not quote.ok: return quote
	var data: Dictionary = definition()
	var gold: int = int(world.get("gold"))
	var inventory: Dictionary = (world.get("inventory") as Dictionary).duplicate(true)
	if quote.wallet=="아데나": gold -= int(quote.amount)
	else: inventory[quote.wallet] = int(inventory.get(quote.wallet,0))-int(quote.amount)
	var overrides: Dictionary = {"gold":gold,"inventory":inventory,"item_instances":(world.get("item_instances") as Dictionary).duplicate(true)}
	var granted: Array[String] = []
	var withheld: Array[String] = []
	for reward: Dictionary in quote.entry.rewards:
		if reward.unit!="ItemClassID":
			if reward.unit=="Einasad": withheld.append("아인하사드 %d (단위 해석 없음)" % int(reward.amount))
			continue
		var staged: Dictionary = _stage_item(world,overrides,int(reward.class_id),int(reward.amount),1,{"kind":"clan523_donate","donate_id":donate_id,"reward_id":int(reward.id)})
		if staged.get("ok",false):
			overrides = staged.overrides; granted.append("%s %d" % [str(reward.name),int(reward.amount)])
		else: withheld.append("%s %d (%s)" % [str(reward.name),int(reward.amount),str(staged.get("error",""))])
	var next: Dictionary = _rolled(state,now())
	next.experience = int(next.experience)+int(quote.experience)
	next.donations[str(donate_id)] = int(next.donations.get(str(donate_id),0))+1
	next.day_points[str(donate_id)] = int(next.day_points.get(str(donate_id),0))+int(quote.points)
	var weekly_cap: int = int(data.policies.WeeklyMaxDonatePoint.value)
	next.week_points = mini(weekly_cap,int(next.week_points)+int(quote.points))
	var before: int = level()
	var message: String = "%s 기부 · 혈맹 경험치 +%d · 기부 포인트 +%d" % [str(quote.entry.name),int(quote.experience),int(quote.points)]
	if not granted.is_empty(): message += " · 획득 "+", ".join(granted)
	if not withheld.is_empty(): message += " · 미지급 "+", ".join(withheld)
	var result: Dictionary = _commit(world,next,overrides,message)
	if result.ok and int(result.level)>before: result.reason = str(result.reason)+" · 혈맹 레벨 %d" % int(result.level)
	result["granted"] = granted; result["withheld"] = withheld
	return result

## Stages one original item into the overrides through the shared 523 item
## supplier (wallets such as 명예 코인, physical stacks); it refuses an item
## the game has no owner for, and the caller withholds that one.
static func _stage_item(world: Object, overrides: Dictionary, item_class_id: int, amount: int, bless: int, origin: Dictionary) -> Dictionary:
	if world==null or not world.has_method("_save_game"): return {"ok":false,"error":"게임 연결 없음"}
	# An original currency item with an existing game wallet (명예 코인 3631 ...):
	# the same ItemClassID -> wallet identity the monster drops use.
	var D: Script = preload("res://scripts/loot/patch523_monster_drops.gd")
	var summary: Dictionary = D.definition_id(str(item_class_id))
	if bless==1 and not summary.is_empty():
		var wallet: String = D.currency_identity_name(summary.get("native_record",{}))
		if not wallet.is_empty() and wallet!="아데나" and wallet in preload("res://scripts/loot/currency_drops.gd").CURRENCY_NAMES:
			var next: Dictionary = overrides.duplicate(true)
			next.inventory[wallet] = int(next.inventory.get(wallet,0))+amount
			return {"ok":true,"overrides":next}
	var staged: Dictionary = preload("res://scripts/loot/patch523_stage_view.gd").stage_one(world,overrides.inventory,overrides.item_instances,int(overrides.gold),item_class_id,amount,bless,origin)
	if not staged.get("ok",false): return {"ok":false,"error":str(staged.get("error",""))}
	return {"ok":true,"overrides":staged.overrides}

## --- Weekly donation reward -------------------------------------------------

func weekly_quote(world: Object, reward_row_id: int) -> Dictionary:
	var data: Dictionary = definition()
	if not data.get("ok",false): return {"ok":false,"reason":str(data.get("problem",""))}
	if not has_clan(): return {"ok":false,"reason":"혈맹이 없습니다"}
	var row: Dictionary = {}
	for entry: Dictionary in data.weekly:
		if int(entry.id)==reward_row_id: row = entry
	if row.is_empty(): return {"ok":false,"reason":"주간 보상 행 없음"}
	var rolled: Dictionary = _rolled(state,now())
	if reward_row_id in rolled.weekly_claimed: return {"ok":false,"reason":"이번 주 수령 완료"}
	if int(rolled.week_points)<int(row.points): return {"ok":false,"reason":"주간 기부 포인트 %d/%d" % [int(rolled.week_points),int(row.points)]}
	if row.kind!="Item": return {"ok":false,"reason":"보상 종류(%s) 미연결" % str(row.kind)}
	return {"ok":true,"row":row}

func claim_weekly(world: Object, reward_row_id: int) -> Dictionary:
	var quote: Dictionary = weekly_quote(world,reward_row_id)
	if not quote.ok: return quote
	var overrides: Dictionary = {"gold":int(world.get("gold")),"inventory":(world.get("inventory") as Dictionary).duplicate(true),"item_instances":(world.get("item_instances") as Dictionary).duplicate(true)}
	var staged: Dictionary = _stage_item(world,overrides,int(quote.row.class_id),int(quote.row.amount),int(quote.row.bless),{"kind":"clan523_weekly","weekly_id":reward_row_id,"reward_id":int(quote.row.reward_id)})
	if not staged.get("ok",false): return {"ok":false,"reason":"%s 지급 불가 · %s" % [str(quote.row.name),str(staged.get("error",""))]}
	var next: Dictionary = _rolled(state,now())
	next.weekly_claimed.append(reward_row_id)
	return _commit(world,next,staged.overrides,"주간 기부 보상 · %s %d" % [str(quote.row.name),int(quote.row.amount)])

## --- Merchant conditions -----------------------------------------------------

## MerchantGoods clan columns: ClanLevelMin and LimitMinClanLevel are both
## minimum clan levels; a row needs the local clan at the higher of the two.
## DaysAfterClanJoin / LimitDaysAfterClanJoin / LimitClanMemberRank have no
## local meaning defined and refuse.
func merchant_gate(row: Dictionary) -> Dictionary:
	var need: int = maxi(int(row.get("ClanLevelMin",0)),int(row.get("LimitMinClanLevel",0)))
	if int(row.get("DaysAfterClanJoin",0))!=0 or int(row.get("LimitDaysAfterClanJoin",0))!=0: return {"ok":false,"reason":"혈맹 가입 경과일 조건 미해석"}
	if row.get("LimitClanMemberRank",false): return {"ok":false,"reason":"혈맹 직위 조건 미해석"}
	if need<=0: return {"ok":true,"need":0}
	if not has_clan(): return {"ok":false,"reason":"혈맹 레벨 %d 필요 · 혈맹 없음 (혈맹 창으로 창설)" % need,"need":need}
	if level()<need: return {"ok":false,"reason":"혈맹 레벨 %d 필요 · 현재 %d" % [need,level()],"need":need}
	return {"ok":true,"need":need}

## Emblem.OpenGrade the clan unlocks (the clan level), 0 without a clan.
func emblem_grade() -> int:
	return level()

func snapshot(world: Object) -> Dictionary:
	var data: Dictionary = definition()
	var current: int = level()
	var view: Dictionary = view_state()
	var next_need: int = -1
	if data.get("ok",false) and current>0 and current<int(data.max_level): next_need = int(data.levels[current-1].cumulative)
	return {"ok":data.get("ok",false),"problem":str(data.get("problem",problem)),"has_clan":has_clan(),"name":str(state.get("name","")),
		"level":current,"experience":int(state.get("experience",0)),"next_experience":next_need,"state":view,
		"buff":data.get("buffs",{}).get(current,{}),"create":create_quote(world) if not has_clan() else {}}
