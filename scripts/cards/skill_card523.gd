extends RefCounted
## 523 스킬 카드 덱 (BuffCardDeck 41 "Spell", 원본 창 SkillCard_All): 합성과 강화.
## 수치는 523 표만 쓴다:
##   BuffCardRuleMergeView (덱 41)   일반 8장→영웅 1%, 영웅 4장→전설 12%, 전설 2장→신화 11%,
##                                   OnFailReward false
##   BuffCardLevelUp / LevelUpMapping / LevelUpProbability
##                                   카드·단계별 Cost, RequiredExperience, FailureExperience, 확률
##   BuffCardExperience / ExperienceMapping / ExperienceGrade
##                                   재료 카드가 주는 경험치·비용, 같은 등급끼리만
## 사용자 결정 2026-11-16 (표에 없는 규칙):
##   - 카드 = 아직 쓰지 않은(배우지 않은) 스킬서 아이템. 합성·강화 재료로 소모한다.
##   - 합성 실패: 재료는 모두 사라지고 아무것도 받지 않는다 (OnFailReward=false).
##   - 합성 결과: 목표 등급 카드 중 내 직업(SpellLearnLimit)이 배울 수 있는 카드에서 균등.
##   - 강화: 표의 3단계(0→1→2→3)만. 원본 창의 4단계 칸은 비워 둔다.
##   - 강화 비용 화폐: 아데나. 실패하면 FailureExperience를 받는다.
##   - 단계 효과: SpellBonus MinSpellLevel>0 행을 기존 주문 단계 소비자
##     (cards/relic_spell_effects.gd, 성물 스킬 레벨과 같은 경로)로 켠다.
## TWILIGHT 해석 (표에 없음, 문서에 기록):
##   - 강화 대상("덱 카드")은 스킬서를 써서 배운 카드(스킬서 학습 영수증의 card_id).
##   - 재료 경험치 비용 BuffCardExperience.Cost는 재료 1장마다, 강화 시도 비용
##     BuffCardLevelUp.Cost는 시도 1회마다 아데나로 낸다.
##   - 경험치 게이지는 현재 단계의 RequiredExperience에서 멈춘다(넘친 양은 사라짐, 견적에 표시).
##     시도하면 게이지를 비우고, 성공은 다음 단계 0부터, 실패는 FailureExperience로 채운다.
##   - 합성 결과로 받는 스킬서는 그 카드의 정상(TestItem false, 바로 학습 가능) 스킬서 중
##     원본 ItemClassID가 가장 작은 것, 일반 축복으로 1장.
##   - 재료는 원본 영수증이 있는 일반 소지 스킬서만(퀘스트 보상 스킬서·잠금 아이템 제외).
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SERVER = preload("res://scripts/loot/current523_server_profile.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const STAGE = preload("res://scripts/loot/patch523_stage_view.gd")
const SAVE_KEY := "skill_card523"
const SCHEMA := 1
const DECK := 41
const PROBABILITY_SCALE := 1000000
const MAX_GOLD := 9007199254740991

var world: Object = null
var state: Dictionary = empty_state()
var preserved: Variant = null
var problem: String = ""
var rng := RandomNumberGenerator.new()
## Bumped whenever a card level can change (save load, enhancement): spell
## record caches that read levels key on it.
var revision: int = 0
var _quotes: Dictionary = {}
var _item_index: Dictionary = {}
var _item_index_key: int = -1

func _init() -> void:
	rng.randomize()

static func empty_state() -> Dictionary:
	return {"schema":SCHEMA, "cards":{}}

func configure(owner: Object) -> void:
	world = owner

static func _whole(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0 and float(value) <= 9007199254740991.0

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "스킬 카드 저장 형식 오류"
	if (value as Dictionary).is_empty(): return ""
	if not _whole(value.get("schema")) or int(value.schema) != SCHEMA or not value.get("cards") is Dictionary: return "스킬 카드 저장 버전·값 오류"
	for key: Variant in value.cards:
		var entry: Variant = value.cards[key]
		if not key is String or not (key as String).is_valid_int() or not entry is Dictionary: return "스킬 카드 기록 오류"
		if not _whole(entry.get("level")) or int(entry.level) > 3 or not _whole(entry.get("exp")): return "스킬 카드 단계·경험치 오류"
	return ""

func export_state() -> Variant:
	if preserved != null: return preserved
	return state.duplicate(true)

func import_state(value: Variant) -> void:
	_quotes.clear()
	problem = ""
	preserved = null
	state = empty_state()
	revision += 1
	if value == null: return
	var invalid: String = validate(value)
	if not invalid.is_empty():
		problem = invalid
		preserved = value.duplicate(true) if value is Dictionary or value is Array else value
		return
	if (value as Dictionary).is_empty(): return
	for key: String in value.cards:
		state.cards[key] = {"level":int(value.cards[key].level), "exp":int(value.cards[key].exp)}

## Enhancement stage (0..3) of a deck-41 card. Unknown cards are 0.
func level(card_id: int) -> int:
	if not problem.is_empty(): return 0
	return int(state.cards.get(str(card_id), {}).get("level", 0))

func experience(card_id: int) -> int:
	return int(state.cards.get(str(card_id), {}).get("exp", 0))

## --- original rows -----------------------------------------------------------

func _admitted(set_id: Variant) -> bool:
	return bool(SERVER.allows(world, set_id).get("ok", false))

func card(card_id: int) -> Dictionary:
	var raw: Dictionary = SOURCE.row("BuffCard", card_id)
	return raw if int(raw.get("BuffCardDeckID", -1)) == DECK else {}

func grade_name(grade_id: int) -> String:
	var grade: Dictionary = SOURCE.row("Grade", grade_id)
	var text: String = str(SOURCE.row("DescData_Korean", int(grade.get("DescID", 0))).get("Description", ""))
	return text if not text.is_empty() else str(grade.get("Name", ""))

func card_name(card_id: int) -> String:
	var raw: Dictionary = card(card_id)
	var text: String = str(SOURCE.row("DescData_Korean", int(raw.get("DescID", 0))).get("Description", ""))
	return text if not text.is_empty() else str(raw.get("Name", ""))

func merge_rule(grade_id: int) -> Dictionary:
	var found: Array = []
	for row: Dictionary in SOURCE.rows("BuffCardRuleMergeView"):
		if int(row.get("BuffCardDeckID",-1)) == DECK and int(row.get("GradeID",-1)) == grade_id and _admitted(row.get("ServerLimitSetID",0)): found.append(row)
	return found[0] if found.size() == 1 else {}

## Next-stage LevelUp row of a card at `stage` ({} at the top or unmapped).
func levelup_row(card_id: int, stage: int) -> Dictionary:
	var found: Array = []
	for link: Dictionary in SOURCE.related("BuffCardLevelUpMapping", "BuffCardID", card_id):
		var row: Dictionary = SOURCE.row("BuffCardLevelUp", int(link.get("BuffCardLevelUpID", 0)))
		if not row.is_empty() and int(row.get("Level", -1)) == stage: found.append(row)
	return found[0] if found.size() == 1 else {}

func levelup_probability(levelup_id: int) -> int:
	var found: Array = SOURCE.related("BuffCardLevelUpProbability", "BuffCardLevelUpID", levelup_id)
	return int(found[0].get("Probability", -1)) if found.size() == 1 else -1

func max_stage(card_id: int) -> int:
	return SOURCE.related("BuffCardLevelUpMapping", "BuffCardID", card_id).size()

## Experience row a fed card gives ({Experience, Cost}).
func feed_row(card_id: int) -> Dictionary:
	var found: Array = SOURCE.related("BuffCardExperienceMapping", "BuffCardID", card_id)
	return SOURCE.row("BuffCardExperience", int(found[0].get("BuffCardExperienceID", 0))) if found.size() == 1 else {}

func feed_allowed(target_grade: int, source_grade: int) -> bool:
	for row: Dictionary in SOURCE.rows("BuffCardExperienceGrade"):
		if int(row.get("TargetCardGradeID",-1)) == target_grade and int(row.get("SourceCardGradeID",-1)) == source_grade: return true
	return false

## --- owned cards -------------------------------------------------------------

## Unused skill books (deck 41 cards) the player holds with an original receipt.
## [{physical_id, name, card_id, grade_id, grade, remaining, locked}], physical-ID order.
func materials(grade_id: int = -1) -> Array:
	var result: Array = []
	if world == null: return result
	var ids: Array = world.item_instances.keys()
	ids.sort()
	for uid: Variant in ids:
		var owned: Dictionary = STACK.proof(world, str(uid))
		if owned.is_empty(): continue
		var spec: Dictionary = NATIVE_FIELDS.full(owned.record).get("source_use_spec", {})
		if spec.get("kind") != "source_skill_book" or int(spec.get("deck_id", -1)) != DECK: continue
		var raw: Dictionary = card(int(spec.get("card_id", 0)))
		if raw.is_empty(): continue
		if grade_id >= 0 and int(raw.GradeID) != grade_id: continue
		var name_value: String = str(owned.record.name)
		result.append({"physical_id":str(uid), "name":name_value, "card_id":int(raw.ID), "card_name":card_name(int(raw.ID)), "grade_id":int(raw.GradeID), "grade":grade_name(int(raw.GradeID)),
			"remaining":int(owned.remaining), "locked":bool(world._item_locked(name_value, str(uid)) or world._item_locked(name_value)), "receipt":owned.receipt})
	return result

## Cards the player has learned from a skill book (the deck), with stage info.
func deck_cards() -> Array:
	var result: Array = []
	if world == null: return result
	var seen: Dictionary = {}
	var receipts: Variant = world.consumable_service.export_state().get("source_skill_book_receipts", [])
	if not receipts is Array: return result
	for receipt: Variant in receipts:
		if not receipt is Dictionary or not _whole(receipt.get("card_id")) or seen.has(int(receipt.card_id)): continue
		var raw: Dictionary = card(int(receipt.card_id))
		if raw.is_empty(): continue
		seen[int(raw.ID)] = true
		var stage: int = level(int(raw.ID))
		var next: Dictionary = levelup_row(int(raw.ID), stage)
		result.append({"card_id":int(raw.ID), "name":card_name(int(raw.ID)), "grade_id":int(raw.GradeID), "grade":grade_name(int(raw.GradeID)), "spell_class_id":int(raw.get("SpellClassID",0)),
			"level":stage, "max_level":max_stage(int(raw.ID)), "exp":experience(int(raw.ID)), "required_exp":int(next.get("RequiredExperience", 0)), "enhanceable":not next.is_empty(),
			"stage_descriptions":stage_descriptions(int(raw.ID))})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.card_id) < int(b.card_id))
	return result

## UIBuffCardLevelUpDesc text per stage (1..4). The table's enhancement reaches
## stage 3; stage 4 text is listed but no enhancement reaches it.
func stage_descriptions(card_id: int) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in SOURCE.related("UIBuffCardLevelUpDesc", "BuffCardID", card_id):
		result[int(row.get("Level", 0))] = str(SOURCE.row("DescData_Korean", int(row.get("DescID", 0))).get("Description", ""))
	return result

func _in_deck(card_id: int) -> bool:
	for entry: Dictionary in deck_cards():
		if int(entry.card_id) == card_id: return true
	return false

## Skill book items per deck-41 card: the lowest original ItemClassID whose
## native record is an unrestricted (learnable) skill book of that card.
func _book_items() -> Dictionary:
	if _item_index_key == SOURCE.cache_generation() and not _item_index.is_empty(): return _item_index
	_item_index_key = SOURCE.cache_generation()
	_item_index = {}
	var categories: Dictionary = {}
	for row: Dictionary in SOURCE.rows("ItemCategory"):
		if str(row.get("Name","")) == "BuffCardDrawer": categories[int(row.ID)] = true
	if categories.is_empty(): return _item_index
	var rows: Array = SOURCE.rows_matching("ItemClass", "CategoryID", categories)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.ID) < int(b.ID))
	for row: Dictionary in rows:
		if row.get("TestItem") != false: continue
		var record: Dictionary = D.variant_item(D.definition_id(str(int(row.ID))).get("native_record", {}), 1)
		if record.is_empty(): continue
		var spec: Dictionary = NATIVE_FIELDS.full(record).get("source_use_spec", {})
		if spec.get("kind") != "source_skill_book" or spec.get("activation_status") != "unrestricted" or int(spec.get("deck_id",-1)) != DECK: continue
		if STACK.supply_profile(record).is_empty(): continue
		var card_id: int = int(spec.get("card_id", 0))
		if not _item_index.has(card_id): _item_index[card_id] = int(row.ID)
	return _item_index

## Target-grade cards a synthesis can give this character: deck 41, IsMergeOut,
## this server, no date window, learnable by the current class, with a book item.
func merge_candidates(grade_id: int) -> Array:
	var result: Array = []
	var class_id: int = STACK.current_class(world)
	if class_id <= 0: return result
	var books: Dictionary = _book_items()
	for raw: Dictionary in SOURCE.related("BuffCard", "BuffCardDeckID", DECK):
		if int(raw.get("GradeID",-1)) != grade_id or raw.get("IsNoMergeOut") != false: continue
		if SOURCE.row("BuffCardSourceView", int(raw.ID)).get("IsMergeOut") != true: continue
		if int(raw.get("StartDateTimeID",0)) != 0 or int(raw.get("EndDateTimeID",0)) != 0 or not _admitted(raw.get("ServerLimitSetID",0)): continue
		if not books.has(int(raw.ID)): continue
		var learnable: bool = false
		for limit: Dictionary in SOURCE.related("SpellLearnLimit", "SpellClassID", int(raw.get("SpellClassID", 0))):
			if int(limit.get("ClassID",-1)) == class_id and limit.get("IsTutorialSpell") == false: learnable = true
		if learnable: result.append({"card_id":int(raw.ID), "name":card_name(int(raw.ID)), "item_class_id":int(books[int(raw.ID)])})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.card_id) < int(b.card_id))
	return result

## --- material selection ------------------------------------------------------

func _fail(reason: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok":false, "reason":reason}
	result.merge(extra, true)
	return result

## Resolves {physical_id: quantity} (or, when empty, the first `amount` usable
## books of `grade_id` in physical-ID order) into stage_debit requests.
func _select(selection: Dictionary, grade_id: int, amount: int, require_exact: bool) -> Dictionary:
	var pool: Dictionary = {}
	for entry: Dictionary in materials(grade_id): pool[str(entry.physical_id)] = entry
	var chosen: Array = []
	var total: int = 0
	if selection.is_empty():
		var ids: Array = pool.keys(); ids.sort()
		for uid: String in ids:
			if total >= amount: break
			var entry: Dictionary = pool[uid]
			if bool(entry.locked): continue
			var take: int = mini(int(entry.remaining), amount - total)
			chosen.append({"entry":entry, "quantity":take}); total += take
	else:
		var ids: Array = selection.keys(); ids.sort()
		for uid: Variant in ids:
			var entry: Dictionary = pool.get(str(uid), {})
			if entry.is_empty(): return _fail("고른 스킬 카드가 없거나 등급이 다릅니다")
			if bool(entry.locked): return _fail("잠긴 스킬 카드는 재료로 쓸 수 없습니다")
			var take: Variant = selection[uid]
			if not _whole(take) or int(take) < 1 or int(take) > int(entry.remaining): return _fail("스킬 카드 재료 수량 오류")
			chosen.append({"entry":entry, "quantity":int(take)}); total += int(take)
	if require_exact and total != amount: return _fail("같은 등급 스킬 카드 %d장이 필요합니다 (선택 %d장)" % [amount, total])
	var requests: Array = []
	var shown: Array = []
	for pick: Dictionary in chosen:
		var entry: Dictionary = pick.entry
		requests.append({"physical_id":str(entry.physical_id), "quantity":int(pick.quantity), "expected_quantity":int(entry.remaining), "expected_remaining":int(entry.remaining) - int(pick.quantity), STACK.RECEIPT:entry.receipt.duplicate(true)})
		shown.append({"physical_id":str(entry.physical_id), "name":str(entry.name), "card_id":int(entry.card_id), "card_name":str(entry.card_name), "quantity":int(pick.quantity)})
	return {"ok":true, "requests":requests, "materials":shown, "count":total}

func _new_token(fingerprint: Dictionary) -> String:
	var token: String = Crypto.new().generate_random_bytes(16).hex_encode()
	_quotes.clear()
	_quotes[token] = fingerprint
	return token

func _base_problem() -> String:
	if world == null: return "게임 연결 전"
	if not problem.is_empty(): return "스킬 카드 저장을 읽지 못해 막았습니다: " + problem
	if SOURCE.identity().is_empty(): return "원본 523 정의가 설치되지 않았습니다"
	return ""

## --- synthesis ---------------------------------------------------------------

func _merge_plan(grade_id: int, selection: Dictionary) -> Dictionary:
	var issue: String = _base_problem()
	if not issue.is_empty(): return _fail(issue)
	var rule: Dictionary = merge_rule(grade_id)
	if rule.is_empty(): return _fail("이 등급은 스킬 카드 합성 대상이 아닙니다 (원본 표)")
	var target: int = int(rule.SuccessGradeID)
	var amount: int = int(rule.SourceAmount)
	var pool: Array = merge_candidates(target)
	var info: Dictionary = {"grade_id":grade_id, "grade":grade_name(grade_id), "target_grade_id":target, "target_grade":grade_name(target), "source_amount":amount,
		"probability":int(rule.SuccessProbability), "probability_percent":float(rule.SuccessProbability) * 100.0 / PROBABILITY_SCALE, "fail_reward":rule.get("OnFailReward") == true,
		"candidates":pool, "candidate_count":pool.size(), "owned_count":0}
	for entry: Dictionary in materials(grade_id):
		if not bool(entry.locked): info.owned_count = int(info.owned_count) + int(entry.remaining)
	if rule.get("OnFailReward") != false: return _fail("원본 실패 보상 규칙은 지원하지 않습니다", info)
	if pool.is_empty(): return _fail("내 직업이 받을 수 있는 %s 스킬 카드가 없습니다" % str(info.target_grade), info)
	var picked: Dictionary = _select(selection, grade_id, amount, true)
	if not bool(picked.get("ok", false)): return _fail(str(picked.reason), info)
	info.merge({"ok":true, "reason":"", "materials":picked.materials, "requests":picked.requests}, true)
	return info

## Quote a synthesis of `grade_id` skill cards. `selection` = {physical_id: quantity}
## (empty: the first usable books). {ok, reason, token, grade_id, grade, target_grade_id,
## target_grade, source_amount, probability (of 1,000,000), probability_percent, candidates,
## candidate_count, owned_count, materials[...]}
func merge_quote(grade_id: int, selection: Dictionary = {}) -> Dictionary:
	var plan: Dictionary = _merge_plan(grade_id, selection)
	if not bool(plan.get("ok", false)): return plan
	var shown: Dictionary = plan.duplicate(true)
	shown.erase("requests")
	shown["token"] = _new_token({"kind":"merge", "grade_id":grade_id, "requests":plan.requests, "revision":revision})
	return shown

## {ok, reason, saved, success, result{card_id,name,item_class_id,item}|{}, consumed}
func merge_execute(token: String) -> Dictionary:
	var held: Dictionary = _quotes.get(token, {})
	if held.is_empty() or held.get("kind") != "merge": return _fail("견적이 없거나 만료되었습니다 · 다시 확인하세요")
	var selection: Dictionary = {}
	for request: Dictionary in held.requests: selection[str(request.physical_id)] = int(request.quantity)
	var plan: Dictionary = _merge_plan(int(held.grade_id), selection)
	_quotes.erase(token)
	if not bool(plan.get("ok", false)): return plan
	if plan.requests != held.requests or int(held.revision) != revision: return _fail("재료가 바뀌었습니다 · 다시 확인하세요")
	var paid: Dictionary = STACK.stage_debit(world, plan.requests)
	if not bool(paid.get("ok", false)): return _fail(str(paid.get("reason", paid.get("error", "스킬 카드 재료 차감 실패"))))
	var roll_before: int = rng.state
	var success: bool = rng.randi_range(0, PROBABILITY_SCALE - 1) < int(plan.probability)
	var payload: Dictionary = paid.overrides.duplicate(true)
	var result: Dictionary = {}
	if success:
		var pool: Array = plan.candidates
		var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var issued: Dictionary = STAGE.stage_one(world, payload.inventory, payload.item_instances, int(world.gold), int(chosen.item_class_id), 1, 1, {"kind":"skill_card523_merge", "deck_id":DECK, "card_id":int(chosen.card_id), "source_grade_id":int(plan.grade_id)})
		if not bool(issued.get("ok", false)):
			rng.state = roll_before
			return _fail(str(issued.get("error", "합성 결과 스킬 카드 지급 실패")) + " · 재료 보존")
		payload.inventory = issued.overrides.inventory
		payload.item_instances = issued.overrides.item_instances
		var item: String = ""
		for uid: Variant in payload.item_instances:
			if not world.item_instances.has(uid) and int(NATIVE_FIELDS.full(payload.item_instances[uid].get("record", {})).get("source_item_class_id", -1)) == int(chosen.item_class_id): item = str(payload.item_instances[uid].name)
		result = {"card_id":int(chosen.card_id), "name":str(chosen.name), "item_class_id":int(chosen.item_class_id), "item":item}
	var saved: Error = world.call("_save_game", true, payload)
	if saved != OK:
		rng.state = roll_before
		return _fail("합성 저장 실패 · 재료를 그대로 두었습니다")
	_commit_world(payload)
	var message: String = ("스킬 카드 합성 성공 · %s" % str(result.name)) if success else ("스킬 카드 합성 실패 · %s %d장 소멸" % [str(plan.grade), int(plan.source_amount)])
	_log(message)
	return {"ok":true, "reason":"", "saved":true, "success":success, "result":result, "consumed":int(plan.source_amount), "grade_id":int(plan.grade_id), "target_grade_id":int(plan.target_grade_id), "message":message}

## --- enhancement -------------------------------------------------------------

func _levelup_plan(card_id: int, feed: Dictionary, attempt: bool) -> Dictionary:
	var issue: String = _base_problem()
	if not issue.is_empty(): return _fail(issue)
	var raw: Dictionary = card(card_id)
	if raw.is_empty(): return _fail("스킬 카드 정의를 찾을 수 없습니다")
	if not _in_deck(card_id): return _fail("배운 스킬 카드만 강화할 수 있습니다")
	var stage: int = level(card_id)
	var row: Dictionary = levelup_row(card_id, stage)
	var info: Dictionary = {"card_id":card_id, "name":card_name(card_id), "grade_id":int(raw.GradeID), "grade":grade_name(int(raw.GradeID)), "level":stage, "max_level":max_stage(card_id),
		"exp":experience(card_id), "stage_descriptions":stage_descriptions(card_id)}
	if row.is_empty(): return _fail("최고 강화 단계입니다" if max_stage(card_id) > 0 else "이 스킬 카드는 강화 대상이 아닙니다 (원본 표)", info)
	var required: int = int(row.RequiredExperience)
	var probability: int = levelup_probability(int(row.ID))
	if probability < 0 or probability > PROBABILITY_SCALE: return _fail("원본 강화 확률 행을 찾을 수 없습니다", info)
	var feed_exp: int = 0
	var feed_cost: int = 0
	var picked: Dictionary = {"ok":true, "requests":[], "materials":[], "count":0}
	if not feed.is_empty():
		picked = _select(feed, -1, 0, false)
		if not bool(picked.get("ok", false)): return _fail(str(picked.reason), info)
		for material: Dictionary in picked.materials:
			var source: Dictionary = card(int(material.card_id))
			if not feed_allowed(int(raw.GradeID), int(source.get("GradeID", -1))): return _fail("같은 등급 스킬 카드만 먹일 수 있습니다", info)
			var gives: Dictionary = feed_row(int(material.card_id))
			if gives.is_empty(): return _fail("%s는 경험치를 주지 않는 카드입니다 (원본 표)" % str(material.card_name), info)
			feed_exp += int(gives.Experience) * int(material.quantity)
			feed_cost += int(gives.Cost) * int(material.quantity)
	var before: int = experience(card_id)
	var filled: int = mini(required, before + feed_exp)
	var can_try: bool = filled >= required
	var try_cost: int = int(row.Cost) if attempt and can_try else 0
	info.merge({"levelup_id":int(row.ID), "required_exp":required, "failure_exp":int(row.FailureExperience), "probability":probability, "probability_percent":float(probability) * 100.0 / PROBABILITY_SCALE,
		"feed_exp":feed_exp, "exp_after_feed":filled, "wasted_exp":maxi(0, before + feed_exp - required), "materials":picked.materials, "requests":picked.requests,
		"feed_cost":feed_cost, "attempt":attempt and can_try, "attempt_cost":int(row.Cost), "cost":{"currency":"아데나", "amount":feed_cost + try_cost}, "gold":int(world.gold)}, true)
	if feed.is_empty() and not attempt: return _fail("먹일 카드나 강화 시도를 고르세요", info)
	if attempt and not can_try: return _fail("경험치가 부족합니다 (%d / %d)" % [filled, required], info) if feed.is_empty() else _fail("먹인 뒤에도 경험치가 부족합니다 (%d / %d)" % [filled, required], info)
	if int(world.gold) < feed_cost + try_cost: return _fail("아데나가 부족합니다 (필요 %d)" % (feed_cost + try_cost), info)
	info["ok"] = true
	info["reason"] = ""
	return info

## Quote feeding `feed` = {physical_id: quantity} same-grade books into a learned
## card and/or one enhancement attempt. {ok, reason, token, card_id, name, grade, level, max_level,
## exp, required_exp, failure_exp, probability, probability_percent, feed_exp, exp_after_feed,
## wasted_exp, materials, feed_cost, attempt, attempt_cost, cost{currency:"아데나",amount}, gold,
## stage_descriptions{1..4}}
func levelup_quote(card_id: int, feed: Dictionary = {}, attempt: bool = true) -> Dictionary:
	var plan: Dictionary = _levelup_plan(card_id, feed, attempt)
	if not bool(plan.get("ok", false)): return plan
	var shown: Dictionary = plan.duplicate(true)
	shown.erase("requests")
	shown["token"] = _new_token({"kind":"levelup", "card_id":card_id, "feed":feed.duplicate(true), "attempt":attempt, "requests":plan.requests, "cost":plan.cost.amount, "level":plan.level, "exp":plan.exp, "revision":revision})
	return shown

## {ok, reason, saved, attempted, success, level, exp, cost, message}
func levelup_execute(token: String) -> Dictionary:
	var held: Dictionary = _quotes.get(token, {})
	if held.is_empty() or held.get("kind") != "levelup": return _fail("견적이 없거나 만료되었습니다 · 다시 확인하세요")
	_quotes.erase(token)
	var plan: Dictionary = _levelup_plan(int(held.card_id), held.feed, bool(held.attempt))
	if not bool(plan.get("ok", false)): return plan
	if plan.requests != held.requests or int(plan.cost.amount) != int(held.cost) or int(plan.level) != int(held.level) or int(plan.exp) != int(held.exp) or int(held.revision) != revision: return _fail("재료·단계·아데나가 바뀌었습니다 · 다시 확인하세요")
	var payload: Dictionary = {}
	if not (plan.requests as Array).is_empty():
		var paid: Dictionary = STACK.stage_debit(world, plan.requests)
		if not bool(paid.get("ok", false)): return _fail(str(paid.get("reason", paid.get("error", "스킬 카드 재료 차감 실패"))))
		payload = paid.overrides.duplicate(true)
	payload["gold"] = int(world.gold) - int(plan.cost.amount)
	var key: String = str(int(plan.card_id))
	var before: Dictionary = state.duplicate(true)
	var roll_before: int = rng.state
	var stage: int = int(plan.level)
	var exp_value: int = int(plan.exp_after_feed)
	var success: bool = false
	if bool(plan.attempt):
		success = rng.randi_range(0, PROBABILITY_SCALE - 1) < int(plan.probability)
		if success:
			stage += 1
			exp_value = 0
		else:
			exp_value = mini(int(plan.required_exp), int(plan.failure_exp))
	state.cards[key] = {"level":stage, "exp":exp_value}
	revision += 1
	var saved: Error = world.call("_save_game", true, payload)
	if saved != OK:
		state = before
		rng.state = roll_before
		revision += 1
		return _fail("강화 저장 실패 · 재료·아데나·단계를 그대로 두었습니다")
	_commit_world(payload)
	_refresh_skills()
	var message: String
	if not bool(plan.attempt): message = "스킬 카드 경험치 +%d · %s (%d / %d)" % [int(plan.feed_exp), str(plan.name), exp_value, int(plan.required_exp)]
	elif success: message = "스킬 카드 강화 성공 · %s %d단계" % [str(plan.name), stage]
	else: message = "스킬 카드 강화 실패 · %s %d단계 유지 · 경험치 %d" % [str(plan.name), stage, exp_value]
	_log(message)
	return {"ok":true, "reason":"", "saved":true, "card_id":int(plan.card_id), "attempted":bool(plan.attempt), "success":success, "level":stage, "exp":exp_value,
		"cost":plan.cost, "consumed":int((plan.materials as Array).reduce(func(sum: int, entry: Dictionary) -> int: return sum + int(entry.quantity), 0)), "message":message}

## --- helpers -----------------------------------------------------------------

func _commit_world(payload: Dictionary) -> void:
	if payload.has("inventory"): world.inventory = payload.inventory
	if payload.has("item_instances"): world.item_instances = payload.item_instances
	if payload.has("gold"): world.gold = int(payload.gold)
	if payload.has("consumable_state"): world.consumable_service.import_state(payload.consumable_state)
	var deferred: Variant = world.get("deferred_save")
	if deferred != null and deferred.has_method("cancel"): deferred.cancel()
	var hud: Variant = world.get("hud")
	if hud != null and is_instance_valid(hud) and hud.has_method("refresh_inventory"): hud.refresh_inventory(world.inventory)
	if world.has_method("_update_hud"): world.call("_update_hud")

func _refresh_skills() -> void:
	if world.has_method("_refresh_speed_modifiers"): world.call("_refresh_speed_modifiers")

func _log(message: String) -> void:
	var hud: Variant = world.get("hud")
	if hud != null and is_instance_valid(hud) and hud.has_method("append_log"): hud.append_log(message)
