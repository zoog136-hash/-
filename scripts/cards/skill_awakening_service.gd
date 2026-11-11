extends RefCounted
## Native card skill awakening, independent of option awakening and aura.
## Book quantity and fees are explicit user game policy, separate from source pools.
const CurrentInput=preload("res://scripts/cards/current523_skill_awakening_input.gd")
const Native=preload("res://scripts/lineagem_base508.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Conditions=preload("res://scripts/cards/source_collection_conditions.gd")
const MAX_EXPERIENCE: int=9999999999999
const MAX_REVISION: int=9007199254740000
const BOOK_QUANTITY: int=1 # user policy, not recovered source consumption evidence
const GRADE_NAMES: Dictionary={3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}
const FEES: Dictionary={3:100000,4:500000,5:1000000,32:2000000,52:5000000}
const REROLL_POLICY: String="source_weighted_reroll_reset_growth"
var conditions=Conditions.new()
var patch523_conditions=Conditions.new()
var source_server_context: Dictionary={}
var cards: Dictionary={}
var pools: Dictionary={}
var stats: Dictionary={}
## BuffCardSkillAwakenStat ID -> row (the named stat set a card points to).
var stat_sets: Dictionary={}
var invokes: Dictionary={}
var experiences: Dictionary={}
var data: Dictionary={}
var problem: String=""

func _init() -> void:
	data=CurrentInput.build(Native.cards().get("catalog",{}))
	problem=str(data.get("problem","")) if data.get("source_definition_archive",{}).is_empty() or data.get("cards",{}).is_empty() else ""
	cards=data.cards.duplicate(true)
	conditions.configure(data.source_server_limits)
	patch523_conditions.configure(data.source_server_limits)
	for row: Dictionary in data.tables.get("BuffCardSkillAwakenStat",[]):
		stat_sets[str(int(row.ID))]=row
	for row: Dictionary in data.tables.get("BuffCardSkillAwakenStatPerLevel",[]):
		stats[str(int(row.MagicDollAwakenStatID))+":"+str(int(row.Level))]=row
	for row: Dictionary in data.tables.get("BuffCardSkillAwakenSkillInvokeProb",[]):
		invokes[_invoke_key(int(row.BuffCardDeckID),int(row.GradeID),int(row.Level))]=row
	for row: Dictionary in data.tables.get("BuffCardSkillAwakenExp",[]):
		experiences[str(int(row.BuffCardDeckID))+":"+str(int(row.Level))]=row
	for book: Dictionary in data.books:
		var key: String=str(int(book.target_deck_from_named_bonus_type))+":"+str(int(book.group_row.GradeID))
		if pools.has(key) or int(book.group_row.ID)==0 or int(book.pool_weight_sum)!=100000:
			problem="원본 스킬 각성 pool 연결 오류";continue
		pools[key]=book

static func _invoke_key(deck: int, grade: int, level: int) -> String:return str(deck)+":"+str(grade)+":"+str(level)
static func fresh_state() -> Dictionary:return {"version":1,"source_snapshot":"base508","cards":{},"revision":0,"rng_state":"","last_operation_id":""}
static func integer(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))
static func fail(code: String,message: String) -> Dictionary:return {"ok":false,"code":code,"error":message}

func book_for(identity: String) -> Dictionary:
	var card: Dictionary=cards.get(identity,{})
	if card.is_empty():return {}
	var raw: Dictionary=card.source_card
	return pools.get(str(int(raw.BuffCardDeckID))+":"+str(int(raw.GradeID)),{})

func profile(identity: String,level: int) -> Dictionary:
	var card: Dictionary=cards.get(identity,{})
	if card.is_empty() or level<1 or level>20:return {}
	var raw: Dictionary=card.source_card
	# BuffCard.MagicDollAwakenStatID names a BuffCardSkillAwakenStat set; its
	# per-level rows hold the only stat the tables give (HP).
	var stat_set: Dictionary=stat_sets.get(str(int(raw.MagicDollAwakenStatID)),{})
	var hp_row: Dictionary=stats.get(str(int(raw.MagicDollAwakenStatID))+":"+str(level),{}) if not stat_set.is_empty() else {}
	var invoke: Dictionary=invokes.get(_invoke_key(int(raw.BuffCardDeckID),int(raw.GradeID),level),{})
	var exp: Dictionary=experiences.get(str(int(raw.BuffCardDeckID))+":"+str(level),{})
	if hp_row.is_empty() or invoke.is_empty() or exp.is_empty() or book_for(identity).is_empty():return {}
	return {"hp":int(hp_row.HP),"invoke":invoke.duplicate(true),"experience_row":exp.duplicate(true),"hp_row":hp_row.duplicate(true),"stat_set":stat_set.duplicate(true),"level":level}

func eligibility(identity: String) -> Dictionary:
	var card: Dictionary=cards.get(identity,{})
	if card.is_empty():return fail("identity","원본 카드 ID 연결 없음")
	if profile(identity,1).is_empty():return fail("profile","원본 스킬 각성 레벨 프로필 없음")
	var raw: Dictionary=card.source_card
	if int(raw.StartDateTimeID)!=0 or int(raw.EndDateTimeID)!=0:return fail("time_condition","원본 카드 기간 조건 확인 필요")
	var evaluator: RefCounted=patch523_conditions if card.get("source_snapshot","")=="patch523" else conditions
	var server: Dictionary=evaluator.evaluate(int(raw.ServerLimitSetID),source_server_context)
	if server.status not in ["unrestricted","eligible"]:return fail("server_condition","원본 서버 조건 확인 필요 · "+str(server.status))
	return {"ok":true}

func spell_allowed(identity: String,spell_id: int) -> bool:
	if spell_id==0:return false
	var book: Dictionary=book_for(identity)
	if book.is_empty() or not data.spells.has(str(spell_id)):return false
	for row: Dictionary in book.pool_rows:
		if int(row.SpellClassID)==spell_id:return true
	return false

func validate_state(value: Variant) -> String:
	if not value is Dictionary or not integer(value.get("version")) or int(value.get("version",0))!=1 or value.get("source_snapshot","")!="base508" or not value.get("cards") is Dictionary:return "스킬 각성 저장 형식 오류"
	if not integer(value.get("revision",0)) or int(value.get("revision",0))<0 or int(value.get("revision",0))>=MAX_REVISION:return "스킬 각성 저장 revision 오류"
	var rng_text: Variant=value.get("rng_state","")
	if not rng_text is String or (not rng_text.is_empty() and (not rng_text.is_valid_int() or str(int(rng_text))!=rng_text)):return "스킬 각성 난수 저장 오류"
	if not value.get("last_operation_id","") is String:return "스킬 각성 거래 ID 오류"
	for key: Variant in value.cards:
		if not key is String or not (key.begins_with("source:m508:") or key.begins_with("source:m523:")):return "스킬 각성 sourceID 오류"
		var parts: PackedStringArray=key.split(":")
		if parts.size()!=4 or not parts[2].is_valid_int() or not parts[3].is_valid_int() or str(int(parts[2]))!=parts[2] or str(int(parts[3]))!=parts[3] or int(parts[2])<1 or int(parts[3])<1:return "스킬 각성 sourceID 정규형 오류"
		var entry: Variant=value.cards[key]
		if not entry is Dictionary:return "스킬 각성 카드 저장 오류"
		for field: String in ["spell_id","level"]:
			if not integer(entry.get(field)):return "스킬 각성 정수 필드 오류"
		if int(entry.spell_id)<0 or int(entry.level)<0 or int(entry.level)>20:return "스킬 각성 범위 오류"
		var xp: Variant=entry.get("experience")
		if not xp is String or not xp.is_valid_int() or str(int(xp))!=xp or int(xp)<0 or int(xp)>MAX_EXPERIENCE:return "스킬 각성 경험치 저장 오류"
		if int(entry.spell_id)>0 and int(entry.level)<1:return "스킬 각성 레벨 누락"
		# Preserve unknown future source IDs as inert same-version records.
		if cards.has(key) and int(entry.spell_id)>0 and not book_for(key).is_empty():
			if not spell_allowed(key,int(entry.spell_id)) or profile(key,int(entry.level)).is_empty():return "스킬 각성 카드·스킬·레벨 조인 오류"
	return ""

func candidates(identity: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for row: Dictionary in book_for(identity).get("pool_rows",[]):
		var spell: Dictionary=data.spells.get(str(int(row.SpellClassID)),{})
		if spell.is_empty():continue
		result.append({"spell_id":int(row.SpellClassID),"name":spell.name,"selection_weight":int(row.Prob),"selection_total":100000,"source_spell":spell.source_spell.duplicate(true),"effects":spell.effects.duplicate(true)})
	return result

func view(state: Dictionary,owned: Dictionary,identity: String,preview_level: int=1) -> Dictionary:
	var card: Dictionary=cards.get(identity,{})
	if card.is_empty():return fail("identity","원본 카드 ID 연결 없음")
	var entry: Dictionary=state.cards.get(identity,{"spell_id":0,"level":0,"experience":"0"})
	var available: Dictionary=eligibility(identity)
	return {"ok":true,"card":card.duplicate(true),"target_id":identity,"owned":owned.get(card.category,{}).get(identity,false)==true,"entry":entry.duplicate(true),"saved_profile":profile(identity,int(entry.level)) if int(entry.spell_id)>0 else {},"preview_profile":profile(identity,preview_level),"eligibility":available,"candidates":candidates(identity),"book":book_for(identity).duplicate(true),"book_requirement":book_requirement(identity),"can_awaken":available.ok and owned.get(card.category,{}).get(identity,false)==true,"can_feed":false,"blocked_reason":"각성서 1장 + "+str(book_requirement(identity).get("fee",0))+" 아데나 · 재각성 시 Lv.1 · 경험치 0부터","unknown_rules":data.unknown_rules}

func request_operation(_state: Dictionary,_owned: Dictionary,_identity: String,_materials: Dictionary) -> Dictionary:
	return fail("runtime_transaction_required","실제 인벤토리·재화 거래는 스킬 각성 런타임에서 처리합니다")

func book_requirement(identity: String) -> Dictionary:
	var book: Dictionary=book_for(identity)
	if book.is_empty():return {}
	return {"source_snapshot":"patch523","source_definition_archive":book.source_definition_archive.duplicate(true),"saved_identity_namespace":str(book.saved_identity_namespace),"saved_item_source_id":str(book.saved_item_source_id),"item_class_id":int(book.item_row.ID),"quantity":BOOK_QUANTITY,"quantity_provenance":"explicit_user_policy","fee_verified":false,"fee":int(FEES.get(int(cards[identity].source_card.GradeID),0)),"fee_provenance":"explicit_user_policy"}

func prepare_book_debit(identity: String,source_book_counts: Dictionary) -> Dictionary:
	# Pure source-ID boundary. The caller must supply an explicitly verified
	# physical inventory mapping, never an inferred name or equal numeric ID.
	# Pure preparation only; the runtime owns the atomic paid transaction.
	var requirement: Dictionary=book_requirement(identity)
	if requirement.is_empty():return fail("identity","원본 각성서 연결 없음")
	var key: String=str(requirement.item_class_id)
	var count: Variant=source_book_counts.get(key,0)
	if not integer(count) or int(count)<0 or int(count)>1000000000:return fail("book_quantity","각성서 소유 수량 오류")
	if int(count)<BOOK_QUANTITY:return fail("insufficient_book","해당 등급 각성서 1장 필요")
	var next: Dictionary=source_book_counts.duplicate(true)
	if int(count)==BOOK_QUANTITY:next.erase(key)
	else:next[key]=int(count)-BOOK_QUANTITY
	return {"ok":true,"source_book_counts":next,"consumed_book":requirement,"committed":false,"fee_verified":false}

func fixed_damage_profile(spell_id: int) -> Dictionary:
	var spell: Dictionary=data.spells.get(str(spell_id),{})
	if spell.is_empty() or bool(spell.source_spell.TestSpell):return {}
	var values: Dictionary={}
	for effect: Dictionary in spell.effects:
		if int(effect.link.MinSpellLevel)!=0 or int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0:return {}
		values[effect.type.Name]=int(effect.bonus.Value)
	if values.size()!=4 or int(values.get("FixedMagicDamage",0))!=1:return {}
	for key: String in ["SpellDamageBase","SpellDamageDiceNumber","SpellDamageDiceSpotCount"]:
		if not values.has(key) or int(values[key])<0:return {}
	return values

func invoke(identity: String,entry: Dictionary,roll: int) -> Dictionary:
	var eligible: Dictionary=eligibility(identity)
	if not eligible.ok:return eligible
	if roll<0 or roll>=10000:return fail("roll","발동 난수 범위 오류")
	if not spell_allowed(identity,int(entry.get("spell_id",0))):return fail("spell","원본 각성 스킬 연결 없음")
	var level: Dictionary=profile(identity,int(entry.get("level",0)))
	if level.is_empty():return fail("level","스킬 각성 레벨 오류")
	var spell_id: int=int(entry.spell_id)
	var damage: Dictionary=fixed_damage_profile(spell_id)
	if damage.is_empty():return fail("effect","원본 스킬 효과 런타임 미지원")
	return {"ok":true,"invoked":roll<int(level.invoke.CastSuccessProb),"profile":level,"spell":data.spells[str(spell_id)].duplicate(true),"damage":damage}


func select_candidate(identity: String,roll: int) -> Dictionary:
	if roll<0 or roll>=100000:return fail("selection_roll","후보 선택 난수 범위 오류")
	var total: int=0
	for row: Dictionary in candidates(identity):
		total+=int(row.selection_weight)
		if roll<total:return {"ok":true,"candidate":row}
	return fail("pool","원본 후보 pool 연결 없음")


func normalized_state(value: Dictionary) -> Dictionary:
	var result: Dictionary=value.duplicate(true)
	result.version=int(result.version)
	result.revision=int(result.get("revision",0))
	result.rng_state=str(result.get("rng_state",""))
	result.last_operation_id=str(result.get("last_operation_id",""))
	for identity: String in result.cards:
		for field: String in ["spell_id","level"]:result.cards[identity][field]=int(result.cards[identity][field])
	return result


func prepare_reroll(state: Dictionary,owned: Dictionary,identity: String,roll: int,expected_revision: int,operation_id: String) -> Dictionary:
	var error: String=validate_state(state)
	if not error.is_empty():return fail("invalid_state",error)
	if operation_id.is_empty():return fail("operation_id","재각성 거래 ID 누락")
	if operation_id==str(state.get("last_operation_id","")):return fail("duplicate_operation","이미 처리된 재각성 거래")
	if expected_revision!=int(state.get("revision",0)):return fail("stale_revision","각성 상태가 변경됐습니다")
	var available: Dictionary=eligibility(identity)
	if not available.ok:return available
	var card: Dictionary=cards[identity]
	if owned.get(card.category,{}).get(identity,false)!=true:return fail("not_owned","대상 카드 미보유")
	var chosen: Dictionary=select_candidate(identity,roll)
	if not chosen.ok:return chosen
	var next: Dictionary=normalized_state(state)
	var entry: Dictionary=next.cards.get(identity,{"spell_id":0,"level":1,"experience":"0"}).duplicate(true)
	var previous: int=int(entry.spell_id)
	# Explicit user policy: paid reawakening resets to Lv1 / zero EXP.
	# Existing saved growth remains unchanged until the transaction succeeds.
	entry.spell_id=int(chosen.candidate.spell_id)
	entry.level=1
	entry.experience="0"
	next.cards[identity]=entry
	next.revision=int(next.revision)+1
	next.last_operation_id=operation_id
	next.reroll_policy=REROLL_POLICY
	return {"ok":true,"state":next,"target_id":identity,"previous_spell_id":previous,"spell_id":int(entry.spell_id),"policy":REROLL_POLICY}


func request_experience_feed(_state: Dictionary,_owned: Dictionary,_identity: String,_materials: Dictionary) -> Dictionary:
	return fail("source_exp_rules_unresolved","경험치 재료별 획득량·소모·강화 처리 규칙 확인 필요 · 카드 차감 없음")

static func install_book_definitions(catalog: Dictionary) -> void:
	if not catalog.has("아이템"):catalog["아이템"]=[]
	var seen: Dictionary={}
	var input: Dictionary=CurrentInput.build(Native.cards().get("catalog",{}))
	for book: Dictionary in input.books:
		var item: Dictionary=book.item_row
		var id: int=int(item.ID)
		if seen.has(id):continue
		seen[id]=true
		var exists: bool=false
		for record: Dictionary in catalog["아이템"]:
			if record.get("name","")==str(book.name):exists=true;break
		if exists:continue # Never assign source ownership to a legacy name alias.
		catalog["아이템"].append({"name":str(book.name),"source":"lineagem_patch523","source_snapshot":"patch523","source_content_snapshot":"patch523","source_definition_archive":book.source_definition_archive.duplicate(true),"saved_identity_namespace":str(book.saved_identity_namespace),"source_item_class_id":id,"sourceId":str(book.saved_item_source_id),"type":"재료","slot":"material","grade":str(GRADE_NAMES.get(int(book.group_row.GradeID),"미확인")),"stackable":true,"source_item":item.duplicate(true),"source_image_status":"original_icon_not_installed","desc":"카드 스킬 각성 재료 · 거래당 1장"})

