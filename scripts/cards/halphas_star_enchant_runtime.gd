extends RefCounted
## User-authorized offline estimates; native source flags remain immutable.
const Native = preload("res://scripts/cards/native_halphas_star_enchant.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const POLICY = preload("res://data/cards/halphas_estimated_policy.json")
const SAVE_KEY: String = "halphas_star_enchant"
const IDENTITY: String = "source:m508:1:24504"
const CATEGORY: String = "변신"
const FLAT: Dictionary = {"HPPlus":"hpFlat", "MPPlus":"mpFlat", "Strength":"strFlat", "Dexterity":"dexFlat", "Intelligence":"intFlat", "Constitution":"conFlat", "Wisdom":"wisFlat", "ArmorClass":"def", "PierceDamageReduction":"damage_reduction_ignore", "MeleeDamage":"meleeDamage", "RangeDamage":"rangedDamage", "MagicDamage":"magicDamage", "HPRestoration":"hp_regen", "MPRestoration":"mp_regen"}
const STATUS_TARGETS: Dictionary = {6:"stun",7:"hold",8:"fear",5:"dark",1:"ice"}
const STATUS_NAMES: Dictionary = {6:"Stun",7:"Hold",8:"Fear",5:"Dark",1:"Ice"}
const PERCENT: Dictionary = {"AttackSpeedBonus":"attackSpeed", "MoveSpeedBonus":"speedBonusPct", "CastSpeedBonus":"skillCooldownPct"}
const Combat=preload("res://scripts/cards/halphas_combat_adapter.gd")
var combat=Combat.new()
var world: Node
var progress: Dictionary = fresh()
var rng := RandomNumberGenerator.new()
var save_blocked: bool = false
var busy: bool = false
var settings: Dictionary = POLICY.data.duplicate(true)
var _effect_stage: int = -1
var _effects: Dictionary = {}

static func fresh() -> Dictionary:
	return {"schema":1, "policy_id":"twilight-halphas-estimated-v1", "level":0, "revision":0, "attempts":0, "successes":0, "spent_gold":0, "spent_cards":0, "attempts_by_stage":[0,0,0], "consumed_by_stage":[0,0,0], "rng_state":"", "last_operation":"", "last_result":{}}

func _init() -> void: rng.randomize()
func configure(host: Node) -> void: world = host;combat.configure(self)
static func integer(v: Variant, low: int, high: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and float(v) >= low and float(v) <= high
static func validate(value: Variant) -> String:
	if not value is Dictionary: return "할파스 강화 저장 형식 오류"
	if not Combat.validate_player(value.get("custom_combat",{})):return "자체 상태 효과 저장 오류"
	if value.get("schema") != 1 or value.get("policy_id") != POLICY.data.policy_id: return "할파스 강화 정책/버전 불일치"
	for key: String in ["level","revision","attempts","successes","spent_gold","spent_cards"]:
		if not integer(value.get(key),0,5500000000000): return "할파스 강화 저장 수치 오류: " + key
	if int(value.level)>3 or int(value.attempts)>1000000 or int(value.successes)!=int(value.level) or int(value.revision)<int(value.attempts): return "할파스 강화 단계/시도 이력 불일치"
	var counts: Variant = value.get("attempts_by_stage")
	var consumed: Variant = value.get("consumed_by_stage")
	if not counts is Array or counts.size()!=3 or not consumed is Array or consumed.size()!=3: return "할파스 강화 시도 장부 오류"
	var total: int = 0; var materials: int = 0;var payments: int=0
	for i: int in range(3):
		if not integer(counts[i],0,1000000): return "할파스 강화 시도 횟수 오류"
		if not integer(consumed[i],0,int(counts[i])):return "할파스 강화 결제 장부 오류"
		if i>int(value.level) and int(counts[i])!=0: return "도달하지 않은 강화 단계 이력"
		if i<int(value.level) and int(counts[i])<1: return "강화 성공 단계의 시도 이력 누락"
		if i<int(value.level) and int(consumed[i])<1:return "강화 성공 단계의 소비 이력 누락"
		total += int(counts[i]); materials += int(consumed[i])*(i+1); payments+=int(consumed[i])
	if total!=int(value.attempts) or materials!=int(value.spent_cards) or int(value.spent_gold)!=payments*5500000: return "할파스 강화 소비 장부 불일치"
	var state: Variant = value.get("rng_state")
	if not state is String or (not state.is_empty() and (not state.is_valid_int() or str(int(state))!=state)): return "할파스 강화 난수 저장 오류"
	if not value.get("last_operation") is String or str(value.last_operation).length()>160 or not value.get("last_result") is Dictionary: return "할파스 강화 거래 이력 오류"
	if total>0 and (state.is_empty() or str(value.last_operation).is_empty()): return "할파스 강화 확정 이력 누락"
	return ""
func export_state() -> Dictionary:
	var out: Dictionary = progress.duplicate(true); out.rng_state = str(rng.state);out.custom_combat=combat.export_player();return out
func check_load(data: Dictionary) -> String:
	return validate(data[SAVE_KEY]) if data.has(SAVE_KEY) else ""
func prepare_load(data: Dictionary) -> bool:
	if not check_load(data).is_empty(): save_blocked=true; return false
	if not data.has(SAVE_KEY) and FileAccess.file_exists(world.save_path()):
		var sha: String = FileAccess.get_sha256(world.save_path())
		var backup: String = world.save_path()+".pre-halphas-"+sha
		if (not FileAccess.file_exists(backup) and DirAccess.copy_absolute(world.save_path(),backup)!=OK) or FileAccess.get_sha256(backup)!=sha:
			save_blocked=true; return false
	return true
func accept_load(data: Dictionary) -> bool:
	if not check_load(data).is_empty(): save_blocked=true; return false
	progress = data.get(SAVE_KEY,fresh()).duplicate(true)
	if not str(progress.rng_state).is_empty(): rng.state=int(progress.rng_state)
	save_blocked=false; _effect_stage=-1
	combat.reset();combat.pending_player=progress.get("custom_combat",{}).duplicate(true)
	if world!=null: world.set("equipment_records_dirty",true)
	return true
func _record(identity: String) -> Dictionary:
	if identity!=IDENTITY:return {}
	var found: Array[Dictionary] = []
	for row: Dictionary in world.catalog_db.get(CATEGORY,[]):
		if Cards.card_id(row)==identity and Native.is_target(CATEGORY,row): found.append(row)
	return found[0] if found.size()==1 else {}
func materials() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in world.catalog_db.get(CATEGORY,[]):
		if row.get("source","")!="lineagem_base508" or int(row.get("source_deck_id",-1))!=int(POLICY.data.material_deck_id) or int(row.get("source_grade_id",-1))!=52:continue
		var id: String = Cards.card_id(row)
		if world.card_draw_fusion.owned.get(CATEGORY,{}).get(id,false)!=true:continue
		result.append({"id":id,"name":row.name,"spare":int(world.card_draw_fusion.spare.get(CATEGORY,{}).get(id,0))})
	return result
func view(identity: String) -> Dictionary:
	var record: Dictionary = _record(identity)
	if record.is_empty():return {"ok":false,"code":"not_halphas","error":"할파스 성급 강화 대상이 아닙니다"}
	var out: Dictionary = Native.snapshot(CATEGORY,record,world.card_draw_fusion.export_state(),int(world.gold),world.card_collections.source_server_context())
	out.native_problems=out.problems.duplicate(); out.native_can_attempt=out.can_attempt
	out.estimated_mode=true; out.policy_id=POLICY.data.policy_id; out.earned_stage=int(progress.level); out.revision=int(progress.revision)
	out.materials=materials();out.can_attempt=false;out.blocked_reason=""
	if save_blocked:out.blocked_reason="강화 저장 보호 중 · 정상 저장을 다시 불러오세요"
	elif not out.owned:out.blocked_reason="해방된 할파스 카드를 보유해야 합니다"
	elif int(progress.level)>=3:out.blocked_reason="최대 3단계에 도달했습니다"
	else:
		out.next_rule=out.stages[int(progress.level)]
		var spares: int = 0
		for item: Dictionary in out.materials: spares+=maxi(0,int(item.spare))
		if int(world.gold)<int(out.next_rule.CurrencyCost):out.blocked_reason="아데나가 부족합니다"
		elif spares<int(out.next_rule.SourceAmount):out.blocked_reason="유일 변신 중복 카드가 부족합니다"
		else:out.can_attempt=true
	out.bonuses=effects(int(progress.level)).duplicate(true)
	var technical: String = technical_problem(out)
	if not technical.is_empty():out.can_attempt=false;out.blocked_reason=technical
	return out
func technical_problem(native_view: Dictionary = {}) -> String:
	for flag: String in ["offline_enable_despite_native_flag","offline_server_override","failure_consumes_material_and_gold"]:
		if not settings.get(flag) is bool:return "추정 강화 정책 설정 오류"
	if settings.get("target_card_id")!=24504:return "추정 강화 대상 설정 오류"
	if not integer(settings.get("probability_scale"),1000000,1000000000) or settings.get("failure_keeps_stage_and_target")!=true or settings.get("consume_duplicates_only")!=true or settings.get("material_deck_id")!=1 or settings.get("policy_id")!=POLICY.data.policy_id or settings.get("bonus_aggregation")!="latest_value_per_supported_unconditional_type_at_or_below_stage" or settings.get("appearance_unlock")!="option_StarEnchant_at_or_below_earned_stage":return "추정 강화 정책 설정 오류"
	if Native.DATA.data.content_control.Enable!=true and not bool(settings.offline_enable_despite_native_flag):return "원본 기능 비활성 · 경제 추정 설정만 준비됨"
	if not bool(settings.offline_server_override):
		var native: Dictionary=native_view
		if native.is_empty():native=Native.snapshot(CATEGORY,_record(IDENTITY),world.card_draw_fusion.export_state(),int(world.gold),world.card_collections.source_server_context())
		if not native.get("ok",false):return "원본 할파스 정체성 확인 실패"
		for evaluation: Dictionary in native.get("server_evaluations",[]):
			if evaluation.status not in ["eligible","unrestricted"]:return "원본 서버 자격 미확인 · 기능 활성화 별도 확인 필요"
	return ""
static func fail(code: String, message: String) -> Dictionary:return {"ok":false,"code":code,"error":message}
func attempt(identity: String, selected: Dictionary, expected_revision: int, operation: String) -> Dictionary:
	if busy:return fail("busy","이전 강화 처리 중")
	if identity!=IDENTITY or _record(identity).is_empty():return fail("not_halphas","할파스 성급 강화 대상이 아닙니다")
	if operation.is_empty() or operation.length()>160:return fail("operation","강화 거래 번호 오류")
	if operation==str(progress.last_operation):return {"ok":true,"replayed":true,"success":bool(progress.last_result.get("success",false)),"level":int(progress.level)}
	if expected_revision!=int(progress.revision):return fail("stale_revision","강화 정보가 변경됐습니다. 다시 확인하세요")
	var snapshot: Dictionary = view(identity)
	if not snapshot.can_attempt:return fail("unavailable",snapshot.blocked_reason)
	var rule: Dictionary = snapshot.next_rule
	var allowed: Dictionary = {}
	for item: Dictionary in snapshot.materials:allowed[item.id]=item
	var count: int = 0
	for id: String in selected:
		if not allowed.has(id) or not integer(selected[id],1,3) or int(selected[id])>int(allowed[id].spare):return fail("materials","사용 가능한 유일 변신 중복 카드를 선택하세요")
		count+=int(selected[id])
	if count!=int(rule.SourceAmount):return fail("materials","필요한 중복 카드 수량을 정확히 선택하세요")
	busy=true
	var staged := RandomNumberGenerator.new();staged.state=rng.state
	var roll: int = staged.randi_range(0,int(settings.probability_scale)-1)
	var success: bool = roll<int(rule.Probability)
	var payable: bool = success or bool(settings.failure_consumes_material_and_gold)
	var paid_gold: int=int(rule.CurrencyCost) if payable else 0
	var paid_cards: int=count if payable else 0
	var next: Dictionary = export_state()
	next.attempts+=1;next.revision+=1;next.attempts_by_stage[int(progress.level)]+=1
	if payable:next.consumed_by_stage[int(progress.level)]+=1
	next.spent_gold+=paid_gold;next.spent_cards+=paid_cards
	if success:next.level+=1;next.successes+=1
	next.rng_state=str(staged.state);next.last_operation=operation
	next.last_result={"success":success,"level":int(next.level),"target_stage":int(rule.Enchant),"consumed_gold":paid_gold,"consumed_cards":paid_cards,"roll":roll}
	var cards: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
	if payable:
		for id: String in selected:cards.spare[CATEGORY][id]=int(cards.spare[CATEGORY][id])-int(selected[id])
	if not validate(next).is_empty():busy=false;return fail("state","강화 결과 저장 검증 실패")
	var error: Error = world._save_game(true,{SAVE_KEY:next,"card_draw_fusion":cards,"gold":int(world.gold)-paid_gold})
	if error!=OK:busy=false;return fail("save_failed","저장 실패 · 카드·아데나·단계·난수를 보존했습니다")
	progress=next; rng.state=staged.state;world.gold-=paid_gold
	world.card_draw_fusion.import_state(cards);world.set("equipment_records_dirty",true);world.set("equipment_effects_dirty",true)
	_effect_stage=-1;busy=false
	if world.has_method("_update_hud"):world.call_deferred("_update_hud")
	return {"ok":true,"success":success,"level":int(progress.level),"consumed_gold":paid_gold,"consumed_cards":paid_cards,"estimated":true}
func active() -> bool:
	return world!=null and not save_blocked and int(progress.level)>0 and technical_problem().is_empty() and world.card_draw_fusion.owned.get(CATEGORY,{}).get(IDENTITY,false)==true and Cards.card_id(world.equipped_catalog.get(CATEGORY,{}))==IDENTITY
static func conditional_key(row: Dictionary) -> String:
	var bonus: Dictionary=row.get("bonus",{})
	var target: int=int(bonus.get("BonusApplicationTargetID",0))
	if int(bonus.get("BonusApplicationTypeID",0))!=2 or not STATUS_TARGETS.has(target):return ""
	if row.get("application_type",{}).get("Name")!="SpecialResistanceType" or row.get("application_target",{}).get("Name")!=STATUS_NAMES[target] or int(row.application_target.get("ID",-1))!=target:return ""
	if row.get("unit",{}).get("Name")!="Percentage" or int(row.get("ui_unit",{}).get("Denominator",0))!=10000:return ""
	match row.get("type",{}).get("Name"):
		"HitSpecialResistance":return str(STATUS_TARGETS[target])+"_accuracy"
		"SpecialResistance":return str(STATUS_TARGETS[target])+"_resistance"
	return ""
func effects(level: int) -> Dictionary:
	if _effect_stage==level:return _effects
	_effect_stage=level;_effects={}
	for stage: int in range(1,level+1):
		var scoped: Dictionary={}
		for row: Dictionary in Native.DATA.data.effects:
			if int(row.link.Enchant)!=stage:continue
			var key: String=conditional_key(row)
			if not key.is_empty():
				# Independent same-stage links add through TWILIGHT's existing
				# record channel. Never flatten distinct resistance targets.
				scoped[key]=float(scoped.get(key,0.0))+float(row.bonus.Value)/float(row.ui_unit.Denominator)
				continue
			if int(row.bonus.BonusApplicationTypeID)!=0 or int(row.bonus.BonusApplicationTargetID)!=0:continue
			var kind: String = row.type.Name
			if FLAT.has(kind):_effects[FLAT[kind]]=int(row.bonus.Value)
			elif PERCENT.has(kind):_effects[PERCENT[kind]]=float(row.bonus.Value)/10000.0
			elif kind=="DecreaseChargeStepTime" and row.unit.Name=="ValuePercent" and int(row.ui_unit.Denominator)==1:_effects["charge_time_reduction_pct"]=float(row.bonus.Value)
		_effects.merge(scoped,true)
	return _effects
func status_hit_bonus(kind: String) -> int:
	if kind not in STATUS_TARGETS.values():return 0
	return catalog_bonus(kind+"_accuracy")
static func pending_effects() -> Array[Dictionary]:
	var pending: Array[Dictionary]=[]
	for row: Dictionary in Native.DATA.data.effects:
		var unconditional: bool=int(row.bonus.BonusApplicationTypeID)==0 and int(row.bonus.BonusApplicationTargetID)==0
		if (unconditional and (FLAT.has(row.type.Name) or PERCENT.has(row.type.Name) or row.type.Name=="DecreaseChargeStepTime")) or not conditional_key(row).is_empty():continue
		pending.append(row.duplicate(true))
	return pending
func catalog_bonus(key: String) -> int:
	return int(effects(int(progress.level)).get(key,0)) if active() else 0
func bonus_records() -> Array[Dictionary]:
	if not active():return []
	var stats: Dictionary = effects(int(progress.level))
	var record: Dictionary={"_halphas_estimated_bonus":true,"hpFlat":stats.get("hpFlat",0),"def":stats.get("def",0),"attackSpeed":stats.get("attackSpeed",0),"speedBonusPct":stats.get("speedBonusPct",0)}
	for kind: String in STATUS_TARGETS.values():
		for suffix: String in ["_accuracy","_resistance"]:
			record[kind+suffix]=stats.get(kind+suffix,0)
	return [record]
func apply_appearance(identity: String, expected_revision: int) -> Dictionary:
	if busy or save_blocked:return fail("busy","강화 저장 보호 중")
	if not technical_problem().is_empty():return fail("technical_gate",technical_problem())
	if identity!=IDENTITY or _record(identity).is_empty() or expected_revision!=int(progress.revision) or int(progress.level)<1:return fail("stage","획득한 할파스 강화 단계가 없습니다")
	if world.card_draw_fusion.owned.get(CATEGORY,{}).get(identity,false)!=true:return fail("ownership","할파스 카드를 보유해야 합니다")
	var option_id: int = 0
	for option: Dictionary in Native.DATA.data.sprite_options:
		if int(option.StarEnchant)==int(progress.level):option_id=int(option.ID)
	if option_id==0:return fail("appearance","이 단계의 원본 외형이 없습니다")
	var options: Dictionary = world.source_card_visual_options.duplicate(true);options["m508:1:24504"]=option_id
	if options==world.source_card_visual_options:return {"ok":true,"unchanged":true}
	var next: Dictionary=export_state();next.revision+=1
	busy=true
	var error: Error=world._save_game(true,{SAVE_KEY:next,"source_visual_context":{"snapshot":"base508","gender_id":world.source_gender_id,"active_card_options":options}})
	if error!=OK:busy=false;return fail("save_failed","외형 저장 실패 · 기존 외형 보존")
	progress=next;world.source_card_visual_options=options;busy=false
	if world.has_method("_restore_equipped_visuals"):world._restore_equipped_visuals()
	return {"ok":true,"option_id":option_id}
