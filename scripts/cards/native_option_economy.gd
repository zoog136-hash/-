extends RefCounted
## Named base508 option rules only. Never reuse these for skill awakening.
const DATA=preload("res://data/cards/base508_option_extensions.json")
const SCALE: int=100 # exact migration of prior TWILIGHT integer-percent progress
const FIELD: String="base508_option_exp_hundredths"

static func fail(code: String,message: String) -> Dictionary:return {"ok":false,"code":code,"error":message}
static func format_units(value: int) -> String:
	var whole: int=int(value/SCALE);var fraction: int=value%SCALE
	return str(whole)+(".%02d" % fraction if fraction!=0 else "")
static func raw(deck: int,grade: int,name_value: String) -> Variant:
	return DATA.data.economy.get(str(deck)+":"+str(grade),{}).get(name_value,{}).get("Value")
static func rule(row: Dictionary) -> Dictionary:
	var card: Dictionary=row.get("native_source",{}).get("card",{})
	if card.is_empty():return {}
	var deck: int=int(card.BuffCardDeckID);var grade: int=int(card.GradeID)
	var required: Variant=raw(deck,grade,"EnchantMaxExp")
	var cost: Variant=raw(deck,grade,"AwakenAdenaCost")
	var minimum: Variant=raw(deck,grade,"EnchantMinGrade");var maximum: Variant=raw(deck,grade,"EnchantMaxGrade")
	if required==null or cost==null or minimum==null or maximum==null:return {}
	return {"deck":deck,"required":int(required),"attempt_cost":int(cost),"min_grade":int(minimum),"max_grade":int(maximum),"decrease":raw(deck,grade,"EnchantFailDecreaseExp")}
static func material(record: Dictionary,r: Dictionary) -> Dictionary:
	if record.get("source","")!="lineagem_base508" or int(record.get("source_deck_id",-1))!=int(r.deck):return {}
	var grade: int=int(record.get("source_grade_id",-1))
	if grade<int(r.min_grade) or grade>int(r.max_grade):return {}
	var exp: Variant=raw(int(r.deck),grade,"EnchantExp");var fee: Variant=raw(int(r.deck),grade,"EnchantCost")
	if exp==null or fee==null:return {}
	return {"experience":int(exp)*SCALE,"cost":int(fee)}
static func units(entry: Dictionary,r: Dictionary) -> int:
	return int(entry[FIELD]) if entry.has(FIELD) else int(entry.experience)*int(r.required)
static func assign(entry: Dictionary,r: Dictionary,value: int) -> void:
	entry[FIELD]=value
	entry.experience=int(value/int(r.required))
static func validate(entry: Dictionary,row: Dictionary) -> String:
	if not entry.has(FIELD):return ""
	var r: Dictionary=rule(row)
	if r.is_empty():return "원본 옵션 각성 경험치 정의 누락"
	var value: Variant=entry[FIELD]
	if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)):return "원본 옵션 각성 경험치 형식 오류"
	if int(value)<0 or int(value)>int(r.required)*SCALE or int(entry.experience)!=int(int(value)/int(r.required)):return "원본 옵션 각성 경험치 범위 오류"
	if bool(entry.awakened) and int(value)!=0:return "완료된 원본 옵션 각성 경험치 오류"
	return ""
static func view(core: RefCounted,state: Dictionary,cards: Dictionary,gold: int,category: String,identity: String) -> Dictionary:
	var row: Dictionary=core.definition(category,identity);var r: Dictionary=rule(row)
	if r.is_empty():return fail("source_rules_missing","원본 옵션 각성 규칙 연결 없음")
	var entry: Dictionary=core.card_progress(state,category,identity)
	var error: String=validate(entry,row)
	if not error.is_empty():return fail("invalid_state",error)
	var availability: Dictionary=core.native_eligibility(category,identity)
	var owned: bool=core.owned(cards,category,identity);var amount: int=units(entry,r);var required: int=int(r.required)*SCALE
	var materials: Array=[];var per_grade: Dictionary={}
	for material_id: String in core.catalog[category]:
		var record: Dictionary=core.catalog[category][material_id];var spec: Dictionary=material(record,r)
		if spec.is_empty():continue
		per_grade[str(record.grade)]=int(spec.experience)
		var spare: int=core.available_material_spare(cards,category,material_id)
		if spare>0 and core.owned(cards,category,material_id) and core.native_material_available(record):materials.append({"id":material_id,"record":record.duplicate(true),"spare":spare,"experience_per_card":int(spec.experience),"cost_per_card":int(spec.cost)})
	var refund: int=(int(r.required)-int(r.decrease))*SCALE if r.decrease!=null else 0
	return {"ok":true,"category":category,"target_id":identity,"target_record":core.catalog[category][identity].duplicate(true),"revision":int(state.revision),"owned":owned,"awakened":bool(entry.awakened),"experience":amount,"required_experience":required,"source_exp_scale":SCALE,"materials":materials,"material_experience":per_grade,"success_chance_pct":float(core.probabilities[category][row.grade])/100.0,"attempt_cost":int(r.attempt_cost),"gold":gold,"failure_refund_experience":refund,"blocked_reason":availability.get("error",""),"can_feed":bool(availability.ok) and owned and not bool(entry.awakened) and amount<required and not materials.is_empty(),"can_awaken":bool(availability.ok) and owned and not bool(entry.awakened) and amount==required and gold>=int(r.attempt_cost),"bonus_options":row.bonus_options.duplicate(),"applied_options":row.applied_options.duplicate(),"pending_options":row.pending_options.duplicate(),"policy_note":"원본 OptionAwakenValueType 이름 기준 비용·재료 등급·EXP·실패 감소량 · 스킬 각성과 별도","attempts":int(entry.attempts),"failures":int(entry.failures),"pity_enabled":false,"collections":core.collection_views(state,cards)}
static func feed(core: RefCounted,state: Dictionary,cards: Dictionary,gold: int,category: String,identity: String,selected: Dictionary) -> Dictionary:
	var row: Dictionary=core.definition(category,identity);var r: Dictionary=rule(row)
	if r.is_empty():return fail("source_rules_missing","원본 옵션 각성 규칙 연결 없음")
	var entry: Dictionary=core.card_progress(state,category,identity);var current: int=units(entry,r);var required: int=int(r.required)*SCALE
	if current>=required:return fail("full","각성 경험치가 이미 가득 찼습니다")
	if selected.is_empty():return fail("empty_materials","중복 재료 카드를 선택하세요")
	var count: int=0;var gained: int=0;var fee: int=0
	for id: Variant in selected:
		var quantity: Variant=selected[id]
		if not id is String or not core.integer(quantity) or int(quantity)<1 or int(quantity)>core.MAX_COUNT:return fail("invalid_quantity","재료 수량 오류")
		var record: Dictionary=core.catalog[category].get(id,{})
		var spec: Dictionary=material(record,r)
		if spec.is_empty():return fail("invalid_material","같은 종류의 원본 허용 등급 카드만 주입할 수 있습니다")
		if not core.native_material_available(record):return fail("source_material_condition","원본 재료 카드 조건 확인 필요")
		var spare: Variant=cards.get("spare",{}).get(category,{}).get(id,0)
		if not core.owned(cards,category,id) or not core.integer(spare) or int(spare)<int(quantity):return fail("insufficient_materials","중복 카드 부족")
		count+=int(quantity)
		if count>core.MAX_COUNT:return fail("invalid_quantity","재료 수량 한도 초과")
		gained+=int(spec.experience)*int(quantity);fee+=int(spec.cost)*int(quantity)
	if gold<fee:return fail("insufficient_gold","원본 경험치 주입 비용 부족")
	var next: Dictionary=state.duplicate(true);var next_cards: Dictionary=cards.duplicate(true)
	for id: String in selected:
		var remaining: int=int(next_cards.spare[category][id])-int(selected[id])
		if remaining==0:next_cards.spare[category].erase(id)
		else:next_cards.spare[category][id]=remaining
	var accepted: int=mini(required-current,gained);assign(entry,r,current+accepted)
	next.cards[category][identity]=entry;next.revision=int(next.revision)+1
	return {"ok":true,"state":next,"card_state":next_cards,"gold":gold-fee,"consumed_gold":fee,"consumed_materials":count,"gained_experience":accepted,"discarded_experience":gained-accepted,"source_exp_scale":SCALE}
static func awaken(core: RefCounted,state: Dictionary,cards: Dictionary,gold: int,category: String,identity: String,roll: int) -> Dictionary:
	var row: Dictionary=core.definition(category,identity);var r: Dictionary=rule(row)
	if r.is_empty():return fail("source_rules_missing","원본 옵션 각성 규칙 연결 없음")
	var entry: Dictionary=core.card_progress(state,category,identity)
	if units(entry,r)!=int(r.required)*SCALE:return fail("experience_needed","경험치100%를 채운 뒤 각성할 수 있습니다")
	if gold<int(r.attempt_cost):return fail("insufficient_gold","각성 시도 비용 부족")
	if roll<0 or roll>=10000:return fail("invalid_roll","각성 확률 계산 오류")
	if int(entry.attempts)>=core.MAX_COUNT:return fail("attempt_limit","각성 시도 한도 초과")
	var success: bool=roll<int(core.probabilities[category][row.grade])
	if not success and r.decrease==null:return fail("source_rules_missing","원본 실패 감소량 정의 없음")
	entry.attempts=int(entry.attempts)+1;entry.awakened=success
	assign(entry,r,0 if success else (int(r.required)-int(r.decrease))*SCALE)
	if not success:entry.failures=int(entry.failures)+1
	var next: Dictionary=state.duplicate(true);next.cards[category][identity]=entry;next.revision=int(next.revision)+1
	return {"ok":true,"state":next,"card_state":cards.duplicate(true),"gold":gold-int(r.attempt_cost),"success":success,"consumed_gold":int(r.attempt_cost),"refunded_experience":int(entry.experience),"source_refunded_experience":int(entry[FIELD]),"source_exp_scale":SCALE}
