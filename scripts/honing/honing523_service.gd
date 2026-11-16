extends RefCounted
## 대장간 연마 (ItemHoning, 523 원본 표) — world transaction.
## Original tables: ItemHoningEntity (target ItemClassID + MinEnchant),
## ItemHoningProbability (Enchant 7/8/9 → 7/15/33%), ItemHoningCost (신화 연금석 2
## + 태고의 구 1 per attempt), ItemHoningEpithet (태고의, Probability 100%) and
## ItemHoningEpithetBonus (PierceDamageReductionPercent 50000).
## NC 공식 확률 정보 "무기 연마 확률" (https://probability.plaync.com/lineagem/view?probCategoryId=6a66b3649bb1696f4bf77325,
## checked 2026-11-16) gives the same 7/15/33%, "+7 이상 신화 등급 무기에만 연마가
## 가능", "아래 성공 확률을 제외한 나머지 값은 실패 확률", and the epithet option
## "태고의 · 대미지 증가 +5%".
## TWILIGHT 근사 (user policy 2026-11-16 "근사치로 다 넣어"):
##  - enchant above the last probability row (+10 and up) uses the +9 row;
##  - failure: the materials are spent, the weapon and its enchant stay
##    (the NC page lists no destruction; scripts/honing/outcome_policy.gd);
##  - one epithet per weapon (a honed weapon is refused);
##  - PierceDamageReductionPercent 5% is applied as "대미지 +5%" (the NC text)
##    on normal attacks and skills while the honed weapon is equipped.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const REFINE = preload("res://scripts/refine523/bless_refine523_service.gd")
const OUTCOME = preload("res://scripts/honing/outcome_policy.gd")
const SCALE: int = 1000000
const NC_SOURCE := "https://probability.plaync.com/lineagem/view?probCategoryId=6a66b3649bb1696f4bf77325"

static func _fail(reason: String, code: String = "refused") -> Dictionary:
	return {"ok":false,"reason":reason,"code":code}

static func _int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

## Original honing rule for one weapon class at an enchant, or a refusal.
static func entry(item_class_id: int, enchant: int) -> Dictionary:
	if SOURCE.identity().is_empty(): return _fail("원본 523 정의 ZIP 미설치 · 연마 보류","source_not_installed")
	var entities: Array = SOURCE.rows_matching("ItemHoningEntity","ItemClassID",{item_class_id:true})
	if entities.size()!=1 or not _int(entities[0].get("HoningID")): return _fail("연마 대상 무기가 아닙니다","not_target")
	var honing: int = int(entities[0].HoningID)
	if enchant<int(entities[0].get("MinEnchant",0)): return _fail("+%d 이상만 연마할 수 있습니다" % int(entities[0].MinEnchant),"enchant_low")
	var probabilities: Array = SOURCE.rows_matching("ItemHoningProbability","HoningID",{honing:true})
	var top: int = -1
	for row: Dictionary in probabilities: top = maxi(top, int(row.get("Enchant",-1)))
	var used_enchant: int = mini(enchant, top)
	var probability: int = -1
	for row: Dictionary in probabilities:
		if int(row.get("Enchant",-1))==used_enchant and _int(row.get("Probability")): probability = int(row.Probability)
	if probability<0: return _fail("이 강화 수치의 원본 연마 확률 행이 없습니다","probability_missing")
	var costs: Array = []
	for row: Dictionary in SOURCE.rows_matching("ItemHoningCost","HoningID",{honing:true}):
		if int(row.get("Enchant",-1))==used_enchant and _int(row.get("ItemClassID")) and _int(row.get("Amount")) and int(row.Amount)>0: costs.append({"item_class_id":int(row.ItemClassID),"amount":int(row.Amount)})
	if costs.is_empty(): return _fail("원본 연마 비용 행이 없습니다","cost_missing")
	var epithets: Array = SOURCE.rows_matching("ItemHoningEpithet","HoningID",{honing:true})
	if epithets.is_empty(): return _fail("원본 연마 수식어 행이 없습니다","epithet_missing")
	var bonuses: Array = []
	for link: Dictionary in SOURCE.rows_matching("ItemHoningEpithetBonus","EpithetID",{int(epithets[0].ID):true}):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		bonuses.append({"bonus_id":int(link.BonusID),"type":str(type.get("Name","")),"value":float(bonus.get("Value",0))})
	var damage_percent: float = 0.0
	for bonus: Dictionary in bonuses:
		if bonus.type=="PierceDamageReductionPercent": damage_percent += float(bonus.value)/10000.0
	return {"ok":true,"honing_id":honing,"enchant_row":used_enchant,"approximated_enchant":used_enchant!=enchant,"probability":probability,"costs":costs,
		"epithet":{"id":int(epithets[0].ID),"name":str(SOURCE.row("DescData_Korean",int(epithets[0].get("DescID",0))).get("Description","")),"bonuses":bonuses},"damage_percent":damage_percent}

static func item_name(item_class_id: int) -> String:
	return str(preload("res://scripts/loot/patch523_monster_drops.gd").definition_id(str(item_class_id)).get("native_record",{}).get("name",""))

static func quote(world: Node, uid: String) -> Dictionary:
	var entry_value: Variant = world.item_instances.get(uid)
	if entry_value is Dictionary and (entry_value as Dictionary).has("honing"): return _fail("이미 연마된 무기입니다","honed")
	var info: Dictionary = REFINE.equipment(world,uid)
	if not info.ok: return info
	var rule: Dictionary = entry(int(info.item_class_id),int(info.enchant))
	if not rule.ok: return rule
	var requests: Array = []; var lacking: Array = []
	for cost: Dictionary in rule.costs:
		var owned: Dictionary = REFINE.stacks_of(world,int(cost.item_class_id))
		if int(owned.total)<int(cost.amount): lacking.append("%s %d/%d" % [item_name(int(cost.item_class_id)),int(owned.total),int(cost.amount)])
		else: requests.append_array(REFINE._debit_requests(owned.stacks,int(cost.amount)))
	var result: Dictionary = {"ok":lacking.is_empty(),"target":info,"rule":rule,"requests":requests,"percent":"%d%%" % int(rule.probability*100/SCALE)}
	if not lacking.is_empty(): result.merge({"reason":"연마 재료가 부족합니다 (" + ", ".join(PackedStringArray(lacking)) + ")","code":"materials"})
	return result

static func attempt(world: Node, uid: String) -> Dictionary:
	var q: Dictionary = quote(world,uid)
	if not q.ok: return q
	var debit: Dictionary = STACK.stage_debit(world,q.requests)
	if not debit.get("ok",false): return _fail(str(debit.get("reason",debit.get("error","연마 재료 차감 준비 실패"))),"debit")
	var rng := RandomNumberGenerator.new()
	rng.state = world.rng.state
	var roll: int = rng.randi_range(0,SCALE-1)
	var success: bool = roll<int(q.rule.probability)
	var staged: Dictionary = {"inventory":debit.overrides.inventory,"item_instances":debit.overrides.item_instances,"consumable_state":debit.overrides.consumable_state}
	if success:
		var instance: Dictionary = (staged.item_instances[uid] as Dictionary).duplicate(true)
		instance["honing"] = {"honing_id":int(q.rule.honing_id),"epithet_id":int(q.rule.epithet.id),"epithet":str(q.rule.epithet.name),"bonuses":q.rule.epithet.bonuses.duplicate(true),
			"damage_percent":float(q.rule.damage_percent),"enchant":int(q.target.enchant),"roll":roll,"probability":int(q.rule.probability),"source":"ItemHoning*","approximation":"TWILIGHT_HONING_DAMAGE_PERCENT"}
		staged.item_instances[uid] = instance
	var before: int = world.rng.state
	world.rng.state = rng.state
	if world._save_game(true,staged)!=OK:
		world.rng.state = before
		return _fail("연마 저장 실패 · 재료·무기 보존","save")
	world.inventory = staged.inventory; world.item_instances = staged.item_instances
	world.consumable_service.import_state(staged.consumable_state)
	if world.has_method("_invalidate_equipment_static"): world._invalidate_equipment_static()
	if world.hud!=null: world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	var name_value: String = str(q.target.name)
	var detail: String = ("대장간 연마 성공 · %s %s (대미지 +%.0f%%)" % [str(q.rule.epithet.name),name_value,float(q.rule.damage_percent)]) if success else ("대장간 연마 실패 · %s 그대로, 재료 소모" % name_value)
	return {"ok":true,"success":success,"roll":roll,"probability":int(q.rule.probability),"detail":detail,"target_physical_id":uid}

## Damage percent of the equipped honed weapon (0 without one).
static func damage_percent(world: Node) -> float:
	var worn: Variant = world.equipped_items.get("weapon",{})
	if not worn is Dictionary: return 0.0
	var physical: Variant = world.item_instances.get(str((worn as Dictionary).get("instance_id","")),{})
	if not physical is Dictionary or not (physical as Dictionary).get("honing") is Dictionary: return 0.0
	return float(physical.honing.get("damage_percent",0.0))

## Owned weapons the rule accepts, for the panel.
static func candidates(world: Node) -> Array:
	var rows: Array = []
	var ids: Array = world.item_instances.keys(); ids.sort()
	for value: Variant in ids:
		var uid: String = str(value)
		var physical: Variant = world.item_instances[uid]
		if not physical is Dictionary or not physical.get("record") is Dictionary: continue
		var rule: Dictionary = entry(int(physical.record.get("source_item_class_id",0)),int(physical.get("level",0)))
		if not rule.ok and rule.code=="not_target": continue
		var q: Dictionary = quote(world,uid) if rule.ok else rule
		rows.append({"uid":uid,"label":"+%d %s" % [int(physical.get("level",0)),str(physical.get("name",""))],"ok":q.ok,"reason":str(q.get("reason","")),"percent":str(q.get("percent","")),"honed":(physical as Dictionary).has("honing")})
	return rows
