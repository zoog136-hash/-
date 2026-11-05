extends RefCounted
## Pure staging. The runtime owns atomic persistence and inventory publication.
## Source level profiles stay separate from adjustable TWILIGHT economics.
const POLICY=preload("res://data/cards/skill_awakening_growth_policy.json")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const MAX_LEVEL: int=20
const MAX_DUPLICATES: int=1000000

static func _fail(code: String,message: String) -> Dictionary:return {"ok":false,"code":code,"error":message,"committed":false}
static func _integer(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))
static func _owned(owned: Dictionary,category: String,identity: String) -> bool:
	var values: Variant=owned.get(category,{})
	if not values is Dictionary:return false
	var value: Variant=values.get(identity,false)
	return value is bool and value

static func validate_policy() -> String:
	var data: Dictionary=POLICY.data
	if int(data.get("schema",0))!=1 or int(data.local_integration.maximum_level)!=MAX_LEVEL or data.local_integration.maximum_experience!="9999999999999":return "스킬 성장 설정 형식 오류"
	if int(data.custom_economy.material_quantity)!=1 or not bool(data.custom_economy.same_category_and_grade) or not bool(data.custom_economy.preserve_permanent_owned_card):return "중복 카드 1장 성장 정책 오류"
	for grade: String in ["3","4","5","32","52"]:
		var row: Dictionary=data.custom_economy.grades.get(grade,{})
		if not _integer(row.get("cards_per_level")) or int(row.get("cards_per_level",0))<1 or not _integer(row.get("fee_adena")) or int(row.get("fee_adena",-1))<0:return "스킬 성장 등급 설정 오류"
	return ""

static func _target(core: Variant,state: Dictionary,owned: Dictionary,identity: String) -> Dictionary:
	var error: String=core.validate_state(state)
	if not error.is_empty():return _fail("invalid_state",error)
	error=validate_policy()
	if not error.is_empty():return _fail("invalid_policy",error)
	var available: Dictionary=core.eligibility(identity)
	if not available.ok:return available
	var card: Dictionary=core.cards[identity]
	if not _owned(owned,str(card.category),identity):return _fail("not_owned","대상 카드 미보유")
	var entry: Dictionary=state.cards.get(identity,{})
	if not core.spell_allowed(identity,int(entry.get("spell_id",0))) or int(entry.get("level",0))<1:return _fail("not_awakened","스킬 각성 후 성장할 수 있습니다")
	return {"ok":true,"card":card,"entry":entry}

static func _curve(core: Variant,identity: String) -> Dictionary:
	var thresholds: Array[int]=[0]
	for level: int in range(1,MAX_LEVEL+1):
		var profile: Dictionary=core.profile(identity,level)
		var row: Dictionary=profile.get("experience_row",{})
		if not _integer(row.get("CumExp")) or int(row.CumExp)<=thresholds[-1] or int(row.CumExp)>core.MAX_EXPERIENCE:return _fail("source_curve","원본 성장 경험치 연결 오류")
		thresholds.append(int(row.CumExp))
	return {"ok":true,"thresholds":thresholds}

static func _quote(core: Variant,identity: String,entry: Dictionary,curve: Dictionary) -> Dictionary:
	var level: int=int(entry.level)
	if level>=MAX_LEVEL:return _fail("maximum_level","최대 성장 레벨입니다")
	var grade: String=str(int(core.cards[identity].source_card.GradeID))
	var rule: Dictionary=POLICY.data.custom_economy.grades.get(grade,{})
	if rule.is_empty():return _fail("grade_policy","성장 등급 설정 없음")
	var gap: int=int(curve.thresholds[level])-int(curve.thresholds[level-1])
	var count: int=int(rule.cards_per_level)
	@warning_ignore("integer_division")
	var amount: int=(gap+count-1)/count
	if int(entry.experience)>=core.MAX_EXPERIENCE:return _fail("experience_capacity","저장 경험치 상한입니다")
	return {"ok":true,"experience":str(amount),"fee":int(rule.fee_adena),"cards_per_level":count,"quantity":1,"provenance":"twilight_custom_economy","next_level_experience":str(curve.thresholds[level])}

static func _material(core: Variant,card_state: Dictionary,target: Dictionary,identity: String) -> Dictionary:
	if not card_state.get("owned") is Dictionary or not card_state.get("spare") is Dictionary:return _fail("card_state","카드 보유 저장 형식 오류")
	var owned: Dictionary=card_state.get("owned",{})
	var spare: Dictionary=card_state.get("spare",{})
	if not core.cards.has(identity):return _fail("material_identity","중복 원본 카드만 사용할 수 있습니다")
	var card: Dictionary=core.cards[identity]
	if card.category!=target.category or int(card.source_card.GradeID)!=int(target.source_card.GradeID):return _fail("material_grade","같은 종류·등급 중복 카드 1장 필요")
	if not _owned(owned,str(card.category),identity):return _fail("material_not_owned","보유 첫 카드는 소모할 수 없습니다")
	var available: Dictionary=core.eligibility(identity)
	if not available.ok:return available
	if bool(card.source_card.get("IsNoMergeOut",false)):return _fail("material_restricted","합성 재료 사용이 제한된 카드입니다")
	var values: Variant=spare.get(card.category,{})
	if not values is Dictionary:return _fail("material_quantity","중복 카드 수량 형식 오류")
	var quantity: Variant=values.get(identity,0)
	if not _integer(quantity) or int(quantity)<0 or int(quantity)>MAX_DUPLICATES:return _fail("material_quantity","중복 카드 수량 오류")
	if int(quantity)<1:return _fail("insufficient_material","사용 가능한 중복 카드 1장 필요")
	if not card_state.get("source_card_receipts",[]) is Array:return _fail("card_receipts","원본 카드 소유 영수증 확인 필요")
	var reserved: int=Cards.quest_reserved_spare(card_state,str(card.category),identity)
	var available_quantity: int=Cards.outgoing_material_spare(card_state,str(card.category),identity)
	if available_quantity<1:return _fail("material_reserved","보호된 퀘스트 중복 카드는 성장 재료로 사용할 수 없습니다")
	return {"ok":true,"card":card,"quantity":int(quantity),"available_quantity":available_quantity,"reserved_quantity":reserved}

static func view(core: Variant,state: Dictionary,owned: Dictionary,identity: String,spare: Dictionary,gold: Variant,card_state: Dictionary={}) -> Dictionary:
	var result: Dictionary={"can_feed":false,"can_enhance":false,"enhancement_rng":false,"materials":[],"material_status":"duplicate_native_card","probability_status":"deterministic_experience_growth","policy_id":POLICY.data.policy_id,"policy_label":POLICY.data.policy_label,"blocked_reason":"","custom_economy":true}
	var target: Dictionary=_target(core,state,owned,identity)
	if not target.ok:result.blocked_reason=target.error;result.code=target.code;return result
	var curve: Dictionary=_curve(core,identity)
	if not curve.ok:result.blocked_reason=curve.error;result.code=curve.code;return result
	result.entry=target.entry.duplicate(true)
	result.next_level_experience=str(curve.thresholds[int(target.entry.level)]) if int(target.entry.level)<MAX_LEVEL else ""
	var quote: Dictionary=_quote(core,identity,target.entry,curve)
	if not quote.ok:result.blocked_reason=quote.error;result.code=quote.code;return result
	result.quote=quote
	# Runtime callers supply the complete receipt ledger. The legacy pure-view
	# signature remains usable for old saves which predate source receipts.
	var material_state: Dictionary=card_state if not card_state.is_empty() else {"owned":owned,"spare":spare}
	for material_id: String in core.cards:
		var candidate: Dictionary=_material(core,material_state,target.card,material_id)
		if candidate.ok:result.materials.append({"id":material_id,"name":str(candidate.card.name),"quantity":candidate.available_quantity,"owned_quantity":candidate.quantity,"reserved_quantity":candidate.reserved_quantity})
	if not _integer(gold) or int(gold)<0:result.blocked_reason="아데나 수량 오류";result.code="gold_quantity"
	elif int(gold)<int(quote.fee):result.blocked_reason="아데나 부족";result.code="insufficient_gold"
	elif result.materials.is_empty():result.blocked_reason="같은 종류·등급 중복 카드 1장 필요";result.code="insufficient_material"
	else:result.can_feed=true
	return result

static func _apply(core: Variant,entry: Dictionary,curve: Dictionary,amount: int) -> Dictionary:
	var next: Dictionary=entry.duplicate(true)
	var before: int=int(entry.experience)
	var granted: int=mini(amount,core.MAX_EXPERIENCE-before)
	next.experience=str(before+granted)
	var previous_level: int=int(next.level)
	while int(next.level)<MAX_LEVEL and int(next.experience)>=int(curve.thresholds[int(next.level)]):next.level=int(next.level)+1
	return {"entry":next,"granted_experience":str(granted),"levels_gained":int(next.level)-previous_level}

static func prepare_feed(core: Variant,state: Dictionary,card_state: Dictionary,gold: Variant,identity: String,material_id: String,expected_revision: int,operation_id: String="") -> Dictionary:
	if not _integer(card_state.get("version")) or int(card_state.get("version",0))!=1 or not card_state.get("owned") is Dictionary or not card_state.get("spare") is Dictionary:return _fail("card_state","카드 보유 저장 형식 오류")
	var target: Dictionary=_target(core,state,card_state.owned,identity)
	if not target.ok:return target
	if expected_revision!=int(state.get("revision",0)):return _fail("stale_revision","각성 상태가 변경됐습니다")
	if int(state.revision)>=core.MAX_REVISION-1:return _fail("revision_capacity","각성 저장 revision 상한입니다")
	if not operation_id.is_empty() and operation_id==str(state.get("last_operation_id","")):return _fail("duplicate_operation","이미 처리된 성장 거래")
	if not _integer(gold) or int(gold)<0:return _fail("gold_quantity","아데나 수량 오류")
	var curve: Dictionary=_curve(core,identity)
	if not curve.ok:return curve
	var quote: Dictionary=_quote(core,identity,target.entry,curve)
	if not quote.ok:return quote
	if int(gold)<int(quote.fee):return _fail("insufficient_gold","아데나 부족")
	var material: Dictionary=_material(core,card_state,target.card,material_id)
	if not material.ok:return material
	var applied: Dictionary=_apply(core,target.entry,curve,int(quote.experience))
	var next: Dictionary=state.duplicate(true)
	next.cards[identity]=applied.entry
	next.revision=int(state.revision)+1
	if not operation_id.is_empty():next.last_operation_id=operation_id
	var next_cards: Dictionary=card_state.duplicate(true)
	var category: String=str(target.card.category)
	if int(material.quantity)==1:next_cards.spare[category].erase(material_id)
	else:next_cards.spare[category][material_id]=int(material.quantity)-1
	return {"ok":true,"state":next,"card_state":next_cards,"gold":int(gold)-int(quote.fee),"target_id":identity,"material_id":material_id,"consumed_quantity":1,"consumed_gold":int(quote.fee),"granted_experience":applied.granted_experience,"levels_gained":applied.levels_gained,"quote":quote,"committed":false,"policy_id":POLICY.data.policy_id}

static func prepare_hunt(core: Variant,state: Dictionary,owned: Dictionary,equipped: Dictionary,experience_amount: Variant) -> Dictionary:
	var error: String=core.validate_state(state)
	if not error.is_empty():return _fail("invalid_state",error)
	if not _integer(experience_amount) or int(experience_amount)<0 or int(experience_amount)>core.MAX_EXPERIENCE:return _fail("experience_amount","사냥 경험치 수량 오류")
	var next: Dictionary=state.duplicate(true)
	var grants: Array[Dictionary]=[]
	if int(experience_amount)==0:return {"ok":true,"state":next,"changed":false,"grants":grants,"committed":false}
	for category: String in Cards.CATEGORIES:
		# Public guides establish hunting EXP only for transformations and dolls.
		# Relic EXP existence alone does not establish its hunting grant contract.
		if category not in ["변신","마법인형"]:continue
		var record: Variant=equipped.get(category,{})
		var identity: String=Cards.card_id(record) if record is Dictionary else ""
		if not core.cards.has(identity) or core.cards[identity].category!=category:continue
		var target: Dictionary=_target(core,state,owned,identity)
		if not target.ok or int(target.entry.level)>=MAX_LEVEL:continue
		var curve: Dictionary=_curve(core,identity)
		if not curve.ok:return curve
		var applied: Dictionary=_apply(core,target.entry,curve,int(experience_amount))
		if applied.entry==target.entry:continue
		next.cards[identity]=applied.entry
		grants.append({"target_id":identity,"granted_experience":applied.granted_experience,"levels_gained":applied.levels_gained,"source":"hunting","provenance":"official_guide"})
	if not grants.is_empty():
		if int(state.revision)>=core.MAX_REVISION-1:return _fail("revision_capacity","각성 저장 revision 상한입니다")
		next.revision=int(state.revision)+1
	return {"ok":true,"state":next,"changed":not grants.is_empty(),"grants":grants,"committed":false}
