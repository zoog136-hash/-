extends RefCounted
## 523 카드 다시 뽑기 (원본 창 CardChange). 같은 덱·같은 등급 안에서 카드 한 장을
## 다른 카드로 바꾼다. 수치는 523 표만 쓴다:
##   BuffCardRuleSwap      덱·등급별 MaxSwapCount, Activate, ActivateCardAmount, ServerLimitSetID
##   BuffCardRuleSwapCost  덱·등급·SwapCount별 CurrencyID(4 = Gem = 다이아), Cost, PickCount
##   BuffCardSourceView    결과 후보(IsSwapOut), BuffCard.IsNoSwapOut
## 사용자 결정 2026-11-16 (표에 없는 규칙):
##   - 대상: 보유한 아무 카드(중복분 포함, 1장뿐인 카드도), 영웅 등급 이상만 (09:19, 09:23).
##     확정 때 중복분부터 쓰고, 모자라면 영구 보유(해금) 1장을 바꾼다. 그 1장에 기존 소유자
##     상태(장착, 옵션 각성·추가 슬롯, 스킬 각성, 할파스 별, 탐험 파견, 완성 컬렉션)가 걸려
##     있으면 거부했으나, TWILIGHT 근사(2026-11-16)로 결과 카드에 진행을 옮긴다(_move_progress).
##   - 다시 뽑은 결과는 바로 받지 않고 "대기 결과"로 저장한다(09:23). 원래 카드는 확정 전까지
##     그대로다. 대기 중 다시 뽑기(다음 횟수·비용)는 대기 결과를 바꾸고, 확정(confirm)해야
##     원래 카드가 대기 결과로 바뀐다. 6회째 고른 카드도 대기 결과가 된다. 원본 창에 별도
##     포기 버튼이 없어 취소 API는 없다(대기 결과는 계속 남는다).
##   - 횟수: 카드(정체)마다 누적, 초기화 없음.
##   - 결과: 표의 같은 덱·같은 등급 후보(IsSwapOut, 현재 서버 조건) 중 균등, 현재 카드 제외.
##   - PickCount>0 회차(6회째): 후보 5장을 보여 주고 플레이어가 하나를 고른다. 보여 준
##     5장은 처음 보여 줄 때 저장되고 그 회차를 실행할 때까지 고정된다(다시 견적해도 같은 5장).
##   - ActivateCardAmount 1(신화·유일): 같은 카드 1장을 더 소모한다.
##   - 비용: 게임 다이아 지갑(인벤토리 "다이아")에서 뺀다.
## 견적(quote) → 다시 뽑기(execute) → 확정(confirm). 각 단계는 저장 한 번으로 끝나고,
## 저장 실패 시 카드·다이아·횟수·대기 결과를 모두 되돌린다.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SERVER = preload("res://scripts/loot/current523_server_profile.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const SAVE_KEY := "card_swap523"
const SCHEMA := 1
const DECKS := {"변신":1, "마법인형":2, "성물":98}
const GEM_CURRENCY_ID := 4
const DIAMOND := "다이아"
const MAX_SPARE := 1000000

var world: Object = null
var state: Dictionary = empty_state()
## A save value this version cannot read is kept as it was (exported unchanged)
## and actions stay off, so loading never loses it.
var preserved: Variant = null
var problem: String = ""
var rng := RandomNumberGenerator.new()
var revision: int = 0
var _quotes: Dictionary = {}
var _index: Dictionary = {}
var _index_key: String = ""
var _picks_dirty: bool = false

func _init() -> void:
	rng.randomize()

static func empty_state() -> Dictionary:
	return {"schema":SCHEMA, "counts":{}, "picks":{}, "pending":{}, "confirmed":{}}

func configure(owner: Object) -> void:
	world = owner

static func _whole(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0 and float(value) <= 9007199254740991.0

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "카드 다시 뽑기 저장 형식 오류"
	if (value as Dictionary).is_empty(): return ""
	if not _whole(value.get("schema")) or int(value.schema) != SCHEMA: return "카드 다시 뽑기 저장 버전 오류"
	if not value.get("counts") is Dictionary or not value.get("picks") is Dictionary: return "카드 다시 뽑기 저장 값 오류"
	for category: Variant in value.counts:
		if not DECKS.has(category) or not value.counts[category] is Dictionary: return "카드 다시 뽑기 덱 기록 오류"
		for identity: Variant in value.counts[category]:
			if not identity is String or not _whole(value.counts[category][identity]) or int(value.counts[category][identity]) > 1000: return "카드 다시 뽑기 횟수 기록 오류"
	for key: Variant in value.picks:
		var pick: Variant = value.picks[key]
		if not key is String or not pick is Dictionary or not _whole(pick.get("swap_count")) or not pick.get("candidates") is Array or (pick.candidates as Array).size() > 64: return "카드 다시 뽑기 선택 후보 기록 오류"
		for identity: Variant in pick.candidates:
			if not identity is String: return "카드 다시 뽑기 선택 후보 기록 오류"
	# Saves from before the 09:23 decision have no pending results.
	var pending: Variant = value.get("pending", {})
	if not pending is Dictionary: return "카드 다시 뽑기 대기 결과 기록 오류"
	for key: Variant in pending:
		var entry: Variant = pending[key]
		if not key is String or not entry is Dictionary or not entry.get("result") is String or not _whole(entry.get("swap_count")) or not entry.get("picked") is bool: return "카드 다시 뽑기 대기 결과 기록 오류"
	var confirmed: Variant = value.get("confirmed", {})
	if not confirmed is Dictionary: return "카드 확정 기록 오류"
	for category: Variant in confirmed:
		if not DECKS.has(category) or not confirmed[category] is Dictionary: return "카드 확정 덱 기록 오류"
		for identity: Variant in confirmed[category]:
			if not identity is String or identity.is_empty() or confirmed[category][identity] != true: return "카드 확정 정체 기록 오류"
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
	state = (value as Dictionary).duplicate(true)
	state.schema = SCHEMA
	for category: String in state.counts:
		for identity: String in state.counts[category]:
			state.counts[category][identity] = int(state.counts[category][identity])
	for key: String in state.picks:
		state.picks[key].swap_count = int(state.picks[key].swap_count)
	if not state.has("pending"): state["pending"] = {}
	if not state.has("confirmed"): state["confirmed"] = {}
	for key: String in state.pending:
		state.pending[key].swap_count = int(state.pending[key].swap_count)

func swap_count(category: String, identity: String) -> int:
	return int(state.counts.get(category, {}).get(identity, 0))

## --- original rules ----------------------------------------------------------

func _admitted(set_id: Variant) -> bool:
	return bool(SERVER.allows(world, set_id).get("ok", false))

## The one active BuffCardRuleSwap row of this deck/grade for this server.
func rule(deck: int, grade_id: int) -> Dictionary:
	var found: Array = []
	for row: Dictionary in SOURCE.rows("BuffCardRuleSwap"):
		if int(row.get("BuffCardDeckID",-1)) != deck or int(row.get("GradeID",-1)) != grade_id: continue
		if row.get("Activate") != true or not _admitted(row.get("ServerLimitSetID",0)): continue
		found.append(row)
	return found[0] if found.size() == 1 else {}

func cost_row(deck: int, grade_id: int, count: int) -> Dictionary:
	var found: Array = []
	for row: Dictionary in SOURCE.rows("BuffCardRuleSwapCost"):
		if int(row.get("BuffCardDeckID",-1)) == deck and int(row.get("GradeID",-1)) == grade_id and int(row.get("SwapCount",-1)) == count: found.append(row)
	return found[0] if found.size() == 1 else {}

func _catalog_index() -> Dictionary:
	var catalog: Dictionary = world.get("catalog_db") if world != null and world.get("catalog_db") is Dictionary else {}
	var sizes: Array = []
	for category: String in DECKS:
		sizes.append((catalog.get(category, []) as Array).size())
		sizes.append((world.card_draw_fusion.known_ids.get(category, {}) as Dictionary).size() if world != null else 0)
	var key: String = "%d|%s" % [SOURCE.cache_generation(), str(sizes)]
	if key == _index_key: return _index
	_index_key = key
	_index = {}
	for category: String in DECKS:
		var by_identity: Dictionary = {}
		for record: Variant in catalog.get(category, []):
			if not record is Dictionary: continue
			var identity: String = CARDS.card_id(record)
			if identity.is_empty() or by_identity.has(identity): continue
			if int(record.get("source_deck_id", -1)) != int(DECKS[category]) or not _whole(record.get("source_card_id")): continue
			by_identity[identity] = record
		_index[category] = by_identity
	return _index

func card_record(category: String, identity: String) -> Dictionary:
	return _catalog_index().get(category, {}).get(identity, {})

## Same-deck, same-grade cards the table lets a swap produce (IsSwapOut), in this
## server and registered in the game's card list, sorted by original card ID.
func candidates(category: String, grade_id: int, exclude: String = "") -> Array:
	var result: Array = []
	var deck: int = int(DECKS.get(category, 0))
	var known: Dictionary = world.card_draw_fusion.known_ids.get(category, {})
	var index: Dictionary = _catalog_index().get(category, {})
	for identity: String in index:
		if identity == exclude or not known.has(identity): continue
		var record: Dictionary = index[identity]
		var raw: Dictionary = SOURCE.row("BuffCard", int(record.source_card_id))
		if raw.is_empty() or int(raw.get("BuffCardDeckID",-1)) != deck or int(raw.get("GradeID",-1)) != grade_id: continue
		if raw.get("IsNoSwapOut") != false: continue
		if SOURCE.row("BuffCardSourceView", int(raw.ID)).get("IsSwapOut") != true: continue
		if int(raw.get("StartDateTimeID",0)) != 0 or int(raw.get("EndDateTimeID",0)) != 0: continue
		if not _admitted(raw.get("ServerLimitSetID",0)): continue
		result.append({"identity":identity, "card_id":int(raw.ID), "name":str(record.get("name","")), "grade":str(record.get("grade",""))})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.card_id) < int(b.card_id))
	return result

## --- quote / execute ---------------------------------------------------------

func _fail(reason: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok":false, "reason":reason}
	result.merge(extra, true)
	return result

const HALPHAS_IDENTITY := "source:m508:1:24504"
const NATIVE_COLLECTIONS = preload("res://scripts/cards/native_collection_rules.gd")

## Why the permanent (last) copy of a card cannot be swapped away now, or "".
## Existing owners keep their state attached to the permanent unlock; none of
## it is moved or erased here, so a card that carries it is refused.
## TWILIGHT 근사 (사용자 지시 2026-11-16 11:40 "근사치로 다 넣어"): progress on
## the last copy MOVES to the result card at confirmation instead of refusing:
## equipped slot, option awakening / extra slots, skill awakening and
## expedition records are re-keyed from the old identity to the result
## identity. A completed collection that needed the card is recomputed (it
## may come undone; the quote lists it). Switch: APPROX_MOVE_PROGRESS.
## 할파스 별 강화 (TWILIGHT 근사(근거 약함), 지시 2026-11-16): the star system
## exists only for 해방된 할파스, so there is no card to move it to. The last
## 할파스 copy may be swapped; its star progress is KEPT unchanged under the
## 할파스 identity (inactive while the card is not owned and equipped,
## halphas_star_enchant_runtime line "owned and equipped") and resumes if 할파스
## is owned again. Nothing is erased. Switch: APPROX_KEEP_HALPHAS_STAR.
const APPROX_MOVE_PROGRESS := true
const APPROX_KEEP_HALPHAS_STAR := true
const PROGRESS_OWNERS := ["option_awakening", "skill_awakening", "expedition_local"]

func _last_copy_guard(category: String, identity: String) -> String:
	if APPROX_MOVE_PROGRESS:
		if not APPROX_KEEP_HALPHAS_STAR and identity == HALPHAS_IDENTITY and world.get("halphas_star") != null and int(world.halphas_star.progress.get("level", 0)) > 0: return "별 강화 진행이 있는 카드입니다"
		return ""
	if CARDS.card_id(world.equipped_catalog.get(category, {})) == identity: return "장착 중인 카드입니다 · 해제 후 다시 뽑으세요"
	var token: String = JSON.stringify(identity)
	var owners: Array = [["option_awakening", "옵션 각성·추가 슬롯 진행이 있는 카드입니다"], ["skill_awakening", "스킬 각성 진행이 있는 카드입니다"], ["expedition_local", "탐험 파견 기록이 있는 카드입니다"]]
	for owner: Array in owners:
		var service: Variant = world.get(owner[0])
		if service != null and service.has_method("export_state") and JSON.stringify(service.call("export_state")).contains(token): return str(owner[1])
	if identity == HALPHAS_IDENTITY and world.get("halphas_star") != null and int(world.halphas_star.progress.get("level", 0)) > 0: return "별 강화 진행이 있는 카드입니다"
	var collections: Variant = world.get("card_collections")
	if collections != null and collections.problem.is_empty() and collections.core != null and collections.core.has_method("derive"):
		collections.current_revision()
		var before: Dictionary = collections._completed
		if not before.is_empty():
			var owned: Dictionary = world.card_draw_fusion.owned.duplicate(true)
			(owned[category] as Dictionary).erase(identity)
			var input: Dictionary = {"owned":owned, "source_server_context":collections.source_server_context()}
			if collections.core is NATIVE_COLLECTIONS: input["source_option_awakening"] = world.option_awakening.native_collection_state()
			var after: Dictionary = collections.core.derive(input).get("completed", {})
			for key: Variant in before:
				if not after.has(key): return "완성한 카드 컬렉션에 쓰인 마지막 1장입니다"
	return ""

## What moving the last copy would carry over (shown in the quote).
func progress_report(category: String, identity: String) -> Dictionary:
	var report: Dictionary = {"equipped":CARDS.card_id(world.equipped_catalog.get(category, {})) == identity, "owners":[], "collections_undone":0}
	if APPROX_KEEP_HALPHAS_STAR and identity == HALPHAS_IDENTITY and world.get("halphas_star") != null and int(world.halphas_star.progress.get("level", 0)) > 0:
		report["halphas_star_kept"] = int(world.halphas_star.progress.get("level", 0))
	var token: String = JSON.stringify(identity)
	for owner: String in PROGRESS_OWNERS:
		var service: Variant = world.get(owner)
		if service != null and service.has_method("export_state") and JSON.stringify(service.call("export_state")).contains(token): report.owners.append(owner)
	var collections: Variant = world.get("card_collections")
	if collections != null and collections.problem.is_empty() and collections.core != null and collections.core.has_method("derive"):
		collections.current_revision()
		var before: Dictionary = collections._completed
		if not before.is_empty():
			var owned: Dictionary = world.card_draw_fusion.owned.duplicate(true)
			(owned[category] as Dictionary).erase(identity)
			var input: Dictionary = {"owned":owned, "source_server_context":collections.source_server_context()}
			if collections.core is NATIVE_COLLECTIONS: input["source_option_awakening"] = world.option_awakening.native_collection_state()
			var after: Dictionary = collections.core.derive(input).get("completed", {})
			for key: Variant in before:
				if not after.has(key): report.collections_undone = int(report.collections_undone) + 1
	return report

static func _rekey(value: Variant, from: String, to: String) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			var moved: Variant = to if key is String and key == from else key
			result[moved] = _rekey(value[key], from, to)
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_rekey(entry, from, to))
		return result
	if value is String and value == from: return to
	return value

## Moves the owners' state; returns the states before (for a rollback).
func _move_progress(category: String, identity: String, result_identity: String, result_record: Dictionary) -> Dictionary:
	var before: Dictionary = {"equipped":world.equipped_catalog.get(category, {}).duplicate(true) if world.equipped_catalog.get(category, {}) is Dictionary else world.equipped_catalog.get(category, {})}
	for owner: String in PROGRESS_OWNERS:
		var service: Variant = world.get(owner)
		if service == null or not service.has_method("export_state"): continue
		var exported: Variant = service.call("export_state")
		if not JSON.stringify(exported).contains(JSON.stringify(identity)): continue
		before[owner] = exported
		_put_state(service, _rekey(exported, identity, result_identity))
	if CARDS.card_id(world.equipped_catalog.get(category, {})) == identity: world.equipped_catalog[category] = result_record.duplicate(true)
	return before

## Owners load their state through import_state, or (skill awakening) keep it
## in `progress`, which export_state copies.
static func _put_state(service: Object, value: Variant) -> void:
	if service.has_method("import_state"): service.call("import_state", value)
	elif "progress" in service: service.set("progress", value)

func _restore_progress(category: String, before: Dictionary) -> void:
	for owner: String in before:
		if owner == "equipped": world.equipped_catalog[category] = before[owner]
		else: _put_state(world.get(owner), before[owner])

func _plan(category: String, identity: String, confirmation_only: bool = false) -> Dictionary:
	if world == null: return _fail("게임 연결 전")
	if not problem.is_empty(): return _fail("카드 다시 뽑기 저장을 읽지 못해 막았습니다: " + problem)
	if not DECKS.has(category): return _fail("다시 뽑기를 지원하지 않는 카드 종류입니다")
	if SOURCE.identity().is_empty(): return _fail("원본 523 정의가 설치되지 않았습니다")
	var record: Dictionary = card_record(category, identity)
	if record.is_empty(): return _fail("원본 카드 정의를 찾을 수 없습니다")
	var deck: int = int(DECKS[category])
	var raw: Dictionary = SOURCE.row("BuffCard", int(record.source_card_id))
	if raw.is_empty() or int(raw.get("BuffCardDeckID",-1)) != deck: return _fail("원본 카드 정의가 바뀌었습니다")
	var grade_id: int = int(raw.GradeID)
	var owner = world.card_draw_fusion
	var cards: Dictionary = {"owned":owner.owned,"spare":owner.spare,"source_card_receipts":owner.source_card_receipts}
	if cards.get("owned",{}).get(category,{}).get(identity,false) != true: return _fail("보유하지 않은 카드입니다")
	var grade_value: int = int(SOURCE.row("Grade", grade_id).get("GradeValue", 0))
	if grade_value < int(SOURCE.row("Grade", 4).get("GradeValue", 4)) or grade_value > int(SOURCE.row("Grade", 52).get("GradeValue", 7)): return _fail("영웅 등급 이상 카드만 다시 뽑을 수 있습니다")
	var held: Dictionary = state.pending.get(category + "|" + identity, {})
	if held.is_empty():
		if state.confirmed.get(category,{}).has(identity): return _fail("이미 확정한 카드입니다")
		if confirmation_only:
			var card: Dictionary = {"identity":identity,"card_id":int(raw.ID),"name":str(record.get("name","")),"grade":str(record.get("grade","")),"grade_id":grade_id}
			return {"category":category,"card":card,"pending":{},"copies_required":0,"can_confirm":true}
	var swap: Dictionary = rule(deck, grade_id)
	if swap.is_empty(): return _fail("이 등급은 다시 뽑기 대상이 아닙니다 (원본 표)")
	var used: int = swap_count(category, identity)
	var limit: int = int(swap.MaxSwapCount)
	var extra: int = maxi(0, int(swap.get("ActivateCardAmount",0)))
	var copies: int = 1 + extra
	var spares: int = maxi(0, int(cards.get("spare",{}).get(category,{}).get(identity,0)))
	var free: int = CARDS.outgoing_material_spare(cards, category, identity)
	var info: Dictionary = {"category":category, "card":{"identity":identity, "card_id":int(raw.ID), "name":str(record.get("name","")), "grade":str(record.get("grade","")), "grade_id":grade_id},
		"used":used, "max":limit, "remaining":maxi(0, limit-used), "copies_required":copies, "extra_copies":extra, "copies_available":free + 1, "uses_last_copy":free < copies,
		"pending":{}, "can_confirm":false, "confirm_reason":"", "swap_count":used + 1, "cost":{}, "diamonds":maxi(0, int(world.inventory.get(DIAMOND, 0))),
		"candidates":[], "candidate_count":0, "pick_count":0, "pick_candidates":[]}
	# Copies at confirmation: free duplicates first, then the permanent copy.
	var copy_reason: String = ""
	if free + 1 < copies: copy_reason = "같은 카드 %d장(대상 1장 + 추가 %d장)이 필요합니다 · 보유 %d장" % [copies, extra, free + 1]
	elif free < copies:
		if spares > free: copy_reason = "퀘스트로 받아 보류 중인 중복분이 있어 마지막 1장은 바꿀 수 없습니다"
		else:
			copy_reason = _last_copy_guard(category, identity)
			if not confirmation_only and APPROX_MOVE_PROGRESS and copy_reason.is_empty(): info["progress_moves"] = progress_report(category, identity)
	if not held.is_empty():
		var result_record: Dictionary = card_record(category, str(held.result))
		info.pending = {"result":{"identity":str(held.result), "card_id":int(result_record.get("source_card_id", 0)), "name":str(result_record.get("name","")), "grade":str(result_record.get("grade",""))},
			"swap_count":int(held.swap_count), "picked":bool(held.picked)}
		info.can_confirm = copy_reason.is_empty() and not result_record.is_empty()
		info.confirm_reason = copy_reason if not copy_reason.is_empty() else ("" if not result_record.is_empty() else "대기 결과 카드 정의를 찾을 수 없습니다")
		if info.can_confirm and int(cards.get("spare",{}).get(category,{}).get(str(held.result),0)) >= MAX_SPARE:
			info.can_confirm = false
			info.confirm_reason = "결과 카드 저장 한도"
	if confirmation_only: return info
	if used >= limit: return _fail("다시 뽑기 최대 횟수(%d회)를 모두 썼습니다" % limit, info)
	var next: int = used + 1
	var cost: Dictionary = cost_row(deck, grade_id, next)
	if cost.is_empty(): return _fail("원본 비용 표에 %d회째 비용이 없습니다" % next, info)
	if int(cost.get("CurrencyID",-1)) != GEM_CURRENCY_ID or SOURCE.row("Currency", GEM_CURRENCY_ID).get("Name") != "Gem": return _fail("원본 비용 화폐가 다이아가 아닙니다", info)
	var pool: Array = candidates(category, grade_id, identity)
	var pick_count: int = maxi(0, int(cost.get("PickCount",0)))
	info.merge({"cost":{"currency":DIAMOND, "currency_id":GEM_CURRENCY_ID, "amount":int(cost.Cost)}, "candidates":pool, "candidate_count":pool.size(), "pick_count":pick_count}, true)
	if pool.is_empty(): return _fail("바꿀 수 있는 같은 등급 카드가 없습니다", info)
	if pick_count > 0: info.pick_candidates = _pick_candidates(category, identity, next, pool, pick_count)
	if not copy_reason.is_empty(): return _fail(copy_reason, info)
	if int(info.diamonds) < int(cost.Cost): return _fail("다이아가 부족합니다 (필요 %d · 보유 %d)" % [int(cost.Cost), int(info.diamonds)], info)
	info["ok"] = true
	info["reason"] = ""
	return info

## The PickCount candidates shown for this card's numbered swap. They are kept
## in the save state until that swap is executed, so quoting again shows the
## same cards instead of new ones.
func _pick_candidates(category: String, identity: String, count: int, pool: Array, pick_count: int) -> Array:
	var key: String = category + "|" + identity
	var held: Dictionary = state.picks.get(key, {})
	var by_identity: Dictionary = {}
	for entry: Dictionary in pool: by_identity[str(entry.identity)] = entry
	if int(held.get("swap_count",-1)) == count:
		var kept: Array = []
		for chosen: Variant in held.get("candidates", []):
			if by_identity.has(chosen): kept.append(by_identity[chosen])
		if kept.size() == (held.candidates as Array).size() and not kept.is_empty(): return kept
	var shuffled: Array = pool.duplicate()
	for index: int in range(shuffled.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Variant = shuffled[index]; shuffled[index] = shuffled[other]; shuffled[other] = swap
	var chosen_cards: Array = shuffled.slice(0, mini(pick_count, shuffled.size()))
	state.picks[key] = {"swap_count":count, "candidates":chosen_cards.map(func(entry: Dictionary) -> String: return str(entry.identity))}
	_picks_dirty = true
	return chosen_cards

## Quote one reroll of `identity` (a CARDS.card_id) in `category`, and its
## pending result if one is waiting. `ok` = a reroll can run now (`token`);
## `can_confirm` = the pending result can be taken now (`confirm_token`).
## Fields: category, card{identity,card_id,name,grade,grade_id}, used, max, remaining,
## swap_count, cost{currency,currency_id,amount}, diamonds, copies_required, extra_copies,
## copies_available, uses_last_copy, candidates[...], candidate_count, pick_count,
## pick_candidates[...], pending{result{identity,card_id,name,grade},swap_count,picked}|{},
## can_confirm, confirm_reason. ok:false still carries the known fields for display.
func quote(category: String, identity: String, confirmation_only: bool = false) -> Dictionary:
	_picks_dirty = false
	var plan: Dictionary = _plan(category, identity, confirmation_only)
	# Newly shown pick candidates are saved at once, so restarting the game
	# does not show a different 5 (a refused save keeps them for this session).
	if _picks_dirty and world != null: world.call("_save_game", true)
	_picks_dirty = false
	_quotes.clear() # one confirmation at a time
	if not confirmation_only and bool(plan.get("ok", false)):
		plan["token"] = Crypto.new().generate_random_bytes(16).hex_encode()
		_quotes[plan.token] = _fingerprint(plan)
	if bool(plan.get("can_confirm", false)):
		plan["confirm_token"] = Crypto.new().generate_random_bytes(16).hex_encode()
		_quotes[plan.confirm_token] = _confirm_fingerprint(plan)
	return plan

## Every pending result, for showing them again after a reload:
## [{category, identity, name, result{identity,name,grade}, swap_count, picked}].
func pending_results() -> Array:
	var result: Array = []
	for key: String in state.pending:
		var parts: PackedStringArray = key.split("|", true, 1)
		if parts.size() != 2: continue
		var entry: Dictionary = state.pending[key]
		var original: Dictionary = card_record(parts[0], parts[1])
		var target: Dictionary = card_record(parts[0], str(entry.result))
		result.append({"category":parts[0], "identity":parts[1], "name":str(original.get("name","")), "result":{"identity":str(entry.result), "name":str(target.get("name","")), "grade":str(target.get("grade",""))},
			"swap_count":int(entry.swap_count), "picked":bool(entry.picked)})
	return result

func confirmed_cards() -> Dictionary:
	return state.confirmed.duplicate(true)

func _fingerprint(plan: Dictionary) -> Dictionary:
	return {"kind":"reroll", "category":plan.category, "identity":plan.card.identity, "swap_count":plan.swap_count, "cost":plan.cost.amount, "copies":plan.copies_required,
		"pick":plan.pick_candidates.map(func(entry: Dictionary) -> String: return str(entry.identity)), "pending":plan.pending, "revision":revision}

func _confirm_fingerprint(plan: Dictionary) -> Dictionary:
	return {"kind":"confirm", "category":plan.category, "identity":plan.card.identity, "pending":plan.pending, "copies":plan.copies_required, "revision":revision}

func _saved_world(bag: Dictionary) -> Error:
	return world.call("_save_game", true, {"inventory":bag})

func _after_save(bag: Dictionary, message: String) -> void:
	world.inventory = bag
	if world.has_method("_invalidate_equipment_static"): world.call("_invalidate_equipment_static")
	var collections: Variant = world.get("card_collections")
	if collections != null and collections.has_method("invalidate"): collections.invalidate()
	var hud: Variant = world.get("hud")
	if hud != null and is_instance_valid(hud):
		if hud.has_method("refresh_inventory"): hud.refresh_inventory(world.inventory)
		if hud.has_method("append_log"): hud.append_log(message)
	if world.has_method("_update_hud"): world.call("_update_hud")

## Reroll (pay the next count's diamonds): the result becomes the card's pending
## result; the original card is unchanged until confirm(). `pick` is the chosen
## identity on a PickCount swap (one of quote.pick_candidates), else ignored.
## {ok, reason, saved, category, from{...}, pending{...}, picked, cost, swap_count, remaining}
func execute(token: String, pick: String = "") -> Dictionary:
	var held: Dictionary = _quotes.get(token, {})
	if held.is_empty() or held.get("kind") != "reroll": return _fail("견적이 없거나 만료되었습니다 · 다시 확인하세요")
	var plan: Dictionary = _plan(str(held.category), str(held.identity))
	if not bool(plan.get("ok", false)): _quotes.erase(token); return plan
	if _fingerprint(plan) != held: _quotes.erase(token); return _fail("카드·다이아·횟수가 바뀌었습니다 · 다시 확인하세요")
	var result_entry: Dictionary = {}
	if int(plan.pick_count) > 0:
		for entry: Dictionary in plan.pick_candidates:
			if str(entry.identity) == pick: result_entry = entry
		if result_entry.is_empty(): return _fail("보여 준 후보 %d장 중 하나를 고르세요" % (plan.pick_candidates as Array).size())
	var category: String = str(plan.category)
	var identity: String = str(plan.card.identity)
	var key: String = category + "|" + identity
	var roll_before: int = rng.state
	var state_before: Dictionary = state.duplicate(true)
	if result_entry.is_empty():
		var pool: Array = plan.candidates
		result_entry = pool[rng.randi_range(0, pool.size() - 1)]
	var counts: Dictionary = state.counts.get(category, {})
	counts[identity] = int(plan.swap_count)
	state.counts[category] = counts
	state.picks.erase(key)
	state.pending[key] = {"result":str(result_entry.identity), "swap_count":int(plan.swap_count), "picked":int(plan.pick_count) > 0}
	var bag: Dictionary = world.inventory.duplicate(true)
	var balance: int = int(bag.get(DIAMOND, 0)) - int(plan.cost.amount)
	if balance > 0: bag[DIAMOND] = balance
	else: bag.erase(DIAMOND)
	revision += 1
	_quotes.erase(token)
	if _saved_world(bag) != OK:
		state = state_before
		rng.state = roll_before
		revision += 1
		return _fail("다시 뽑기 저장 실패 · 다이아와 횟수를 그대로 두었습니다")
	_after_save(bag, "카드 다시 뽑기 · %s → 대기 결과 %s (%s) · 다이아 %d" % [str(plan.card.name), str(result_entry.name), category, int(plan.cost.amount)])
	var pending: Dictionary = {"result":{"identity":str(result_entry.identity), "card_id":int(result_entry.card_id), "name":str(result_entry.name), "grade":str(result_entry.grade)}, "swap_count":int(plan.swap_count), "picked":int(plan.pick_count) > 0}
	return {"ok":true, "reason":"", "saved":true, "category":category, "from":plan.card, "pending":pending, "picked":int(plan.pick_count) > 0,
		"cost":plan.cost, "swap_count":int(plan.swap_count), "remaining":maxi(0, int(plan.max) - int(plan.swap_count))}

## Take the pending result: the original card (duplicates first, then the
## permanent copy; 신화·유일 one more copy) is replaced by the pending card.
## {ok, reason, saved, category, from{...}, result{id,identity,name,grade,new}, consumed, used_last_copy}
func confirm(token: String) -> Dictionary:
	var held: Dictionary = _quotes.get(token, {})
	if held.is_empty() or held.get("kind") != "confirm": return _fail("확정할 대기 결과가 없거나 견적이 만료되었습니다 · 다시 확인하세요")
	_quotes.erase(token)
	var committed: Dictionary = _commit_confirmations([held])
	return committed.results[0] if committed.get("ok",false) else committed

## Snapshot payable pending results and owned cards that can be kept. Quoting
## confirmation must never roll new candidates, touch the wallet, or save.
func quote_all() -> Dictionary:
	_quotes.clear()
	var eligible: Array[Dictionary] = []
	var settled_by_pending: Dictionary = {}
	for row: Dictionary in pending_results():
		var plan: Dictionary = _plan(str(row.category),str(row.identity),true)
		if plan.get("can_confirm",false):
			eligible.append(_confirm_fingerprint(plan))
			settled_by_pending[str(row.category)+"|"+str(row.result.identity)] = true
	var blocked: int = state.pending.size() - eligible.size()
	for category: String in DECKS:
		var owned: Dictionary = world.card_draw_fusion.owned.get(category,{})
		for identity: String in owned:
			var key: String = category+"|"+identity
			if owned[identity]!=true or state.pending.has(key) or settled_by_pending.has(key) or state.confirmed.get(category,{}).has(identity):continue
			var record: Dictionary = card_record(category,identity)
			if str(record.get("grade","")) not in ["영웅","전설","신화","유일"]:continue
			var plan: Dictionary = _plan(category,identity,true)
			if plan.get("can_confirm",false):eligible.append(_confirm_fingerprint(plan))
	if eligible.is_empty(): return _fail("확정할 수 있는 카드가 없습니다 · 조건 미충족 %d장" % blocked)
	var token: String = Crypto.new().generate_random_bytes(16).hex_encode()
	_quotes[token] = {"kind":"confirm_all","entries":eligible}
	return {"ok":true,"token":token,"count":eligible.size(),"blocked":blocked}

func confirm_all(token: String) -> Dictionary:
	var held: Dictionary = _quotes.get(token,{})
	if held.get("kind") != "confirm_all": return _fail("전체 확정 견적이 만료되었습니다 · 다시 확인하세요")
	_quotes.erase(token)
	return _commit_confirmations(held.entries)

func _commit_confirmations(entries: Array[Dictionary]) -> Dictionary:
	var cards_before: Dictionary = world.card_draw_fusion.export_state()
	var pending_before: Dictionary = state.pending.duplicate(true)
	var confirmed_before: Dictionary = state.confirmed.duplicate(true)
	var results: Array[Dictionary] = []
	var moved: Array[Dictionary] = []
	var reason: String = ""
	for expected: Dictionary in entries:
		var plan: Dictionary = _plan(str(expected.category),str(expected.identity),true)
		if not plan.get("can_confirm",false) or _confirm_fingerprint(plan) != expected:
			reason = str(plan.get("confirm_reason",plan.get("reason","")))
			if reason.is_empty(): reason = "카드·대기 결과가 바뀌었습니다 · 다시 확인하세요"
			break
		var result: Dictionary = _apply_confirmation(plan,moved)
		if not result.get("ok",false):
			reason = str(result.reason)
			break
		results.append(result)
	var bag: Dictionary = world.inventory.duplicate(true)
	if reason.is_empty() and _saved_world(bag) != OK:
		reason = "확정 저장 실패 · 원래 카드와 대기 결과를 그대로 두었습니다"
	revision += 1
	if not reason.is_empty():
		state.pending = pending_before
		state.confirmed = confirmed_before
		world.card_draw_fusion.import_state(cards_before)
		moved.reverse()
		for entry: Dictionary in moved:
			_restore_progress(str(entry.category),entry.before)
		return _fail(reason)
	var message: String = "카드 다시 뽑기 전체 확정 · %d장" % results.size()
	if results.size() == 1:
		var result: Dictionary = results[0]
		message = "카드 다시 뽑기 확정 · %s → %s (%s)" % [str(result.from.name),str(result.result.get("name","")),str(result.category)]
	_after_save(bag,message)
	return {"ok":true,"saved":true,"results":results,"count":results.size()}

func _apply_confirmation(plan: Dictionary, progress: Array[Dictionary]) -> Dictionary:
	var category: String = str(plan.category)
	var identity: String = str(plan.card.identity)
	if not state.confirmed.has(category):state.confirmed[category]={}
	if plan.pending.is_empty():
		state.confirmed[category][identity]=true
		return {"ok":true,"reason":"","saved":true,"category":category,"from":plan.card,"result":plan.card,"consumed":0,"used_last_copy":false,"moved_progress":[]}
	var result_identity: String = str(plan.pending.result.identity)
	var result_record: Dictionary = card_record(category,result_identity)
	var cards = world.card_draw_fusion
	var extras: Dictionary = cards.spare[category]
	var copies: int = int(plan.copies_required)
	var from_spare: int = mini(copies,int(plan.copies_available)-1)
	var last_copy: bool = from_spare < copies
	var left: int = int(extras.get(identity,0)) - from_spare
	if last_copy and left > 0: return _fail("퀘스트 보류 중복분이 있어 마지막 1장은 바꿀 수 없습니다")
	if left > 0: extras[identity] = left
	else: extras.erase(identity)
	if last_copy: (cards.owned[category] as Dictionary).erase(identity)
	var received: Dictionary = cards._receive(category,{"id":result_identity,"record":result_record})
	received["identity"] = str(received.get("id",""))
	var moved: Dictionary = {}
	if last_copy and APPROX_MOVE_PROGRESS:
		moved = _move_progress(category,identity,result_identity,result_record)
		progress.append({"category":category,"before":moved})
	state.pending.erase(category+"|"+identity)
	state.confirmed[category][identity]=true
	state.confirmed[category][result_identity]=true
	return {"ok":true,"reason":"","saved":true,"category":category,"from":plan.card,"result":received,"consumed":copies,"used_last_copy":last_copy,"moved_progress":moved.keys()}
