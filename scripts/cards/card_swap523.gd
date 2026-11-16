extends RefCounted
## 523 카드 다시 뽑기 (원본 창 CardChange). 같은 덱·같은 등급 안에서 카드 한 장을
## 다른 카드로 바꾼다. 수치는 523 표만 쓴다:
##   BuffCardRuleSwap      덱·등급별 MaxSwapCount, Activate, ActivateCardAmount, ServerLimitSetID
##   BuffCardRuleSwapCost  덱·등급·SwapCount별 CurrencyID(4 = Gem = 다이아), Cost, PickCount
##   BuffCardSourceView    결과 후보(IsSwapOut), BuffCard.IsNoSwapOut
## 사용자 결정 2026-11-16 (표에 없는 규칙):
##   - 대상: 보유한 아무 카드(중복분 포함). TWILIGHT 카드 보유는 "영구 보유(해금) 1장 +
##     중복분"이며 다시 뽑기는 중복분 1장을 바꾼다. 영구 보유 1장은 각성·컬렉션·장착이
##     걸려 있어 기존 합성과 같이 소모하지 않는다(저장 보존).
##   - 횟수: 카드(정체)마다 누적, 초기화 없음.
##   - 결과: 표의 같은 덱·같은 등급 후보(IsSwapOut, 현재 서버 조건) 중 균등, 현재 카드 제외.
##   - PickCount>0 회차(6회째): 후보 5장을 보여 주고 플레이어가 하나를 고른다. 보여 준
##     5장은 처음 보여 줄 때 저장되고 그 회차를 실행할 때까지 고정된다(다시 견적해도 같은 5장).
##   - ActivateCardAmount 1(신화·유일): 같은 카드 1장을 더 소모한다.
##   - 비용: 게임 다이아 지갑(인벤토리 "다이아")에서 뺀다.
## 견적(quote) → 확인 → 실행(execute) 형태이며, 실행은 한 번의 저장으로 확정된다.
## 저장 실패 시 카드·다이아·횟수를 모두 되돌린다.
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
	return {"schema":SCHEMA, "counts":{}, "picks":{}}

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

func _plan(category: String, identity: String) -> Dictionary:
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
	var cards: Dictionary = world.card_draw_fusion.export_state()
	if cards.get("owned",{}).get(category,{}).get(identity,false) != true: return _fail("보유하지 않은 카드입니다")
	var swap: Dictionary = rule(deck, grade_id)
	if swap.is_empty(): return _fail("이 등급은 다시 뽑기 대상이 아닙니다 (원본 표)")
	var used: int = swap_count(category, identity)
	var limit: int = int(swap.MaxSwapCount)
	var info: Dictionary = {"category":category, "card":{"identity":identity, "card_id":int(raw.ID), "name":str(record.get("name","")), "grade":str(record.get("grade","")), "grade_id":grade_id},
		"used":used, "max":limit, "remaining":maxi(0, limit-used)}
	if used >= limit: return _fail("다시 뽑기 최대 횟수(%d회)를 모두 썼습니다" % limit, info)
	var next: int = used + 1
	var cost: Dictionary = cost_row(deck, grade_id, next)
	if cost.is_empty(): return _fail("원본 비용 표에 %d회째 비용이 없습니다" % next, info)
	if int(cost.get("CurrencyID",-1)) != GEM_CURRENCY_ID or SOURCE.row("Currency", GEM_CURRENCY_ID).get("Name") != "Gem": return _fail("원본 비용 화폐가 다이아가 아닙니다", info)
	var extra: int = maxi(0, int(swap.get("ActivateCardAmount",0)))
	var copies: int = 1 + extra
	var available: int = CARDS.outgoing_material_spare(cards, category, identity)
	var pool: Array = candidates(category, grade_id, identity)
	var pick_count: int = maxi(0, int(cost.get("PickCount",0)))
	var diamonds: int = maxi(0, int(world.inventory.get(DIAMOND, 0)))
	info.merge({"swap_count":next, "cost":{"currency":DIAMOND, "currency_id":GEM_CURRENCY_ID, "amount":int(cost.Cost)}, "diamonds":diamonds,
		"copies_required":copies, "extra_copies":extra, "copies_available":available, "candidates":pool, "candidate_count":pool.size(),
		"pick_count":pick_count, "pick_candidates":[]}, true)
	if pool.is_empty(): return _fail("바꿀 수 있는 같은 등급 카드가 없습니다", info)
	if pick_count > 0:
		info.pick_candidates = _pick_candidates(category, identity, next, pool, pick_count)
	if available < copies:
		return _fail(("같은 카드 %d장(대상 1장 + 추가 %d장)이 필요합니다 · 중복분 %d장" % [copies, extra, available]) if extra > 0 else "바꿀 중복 카드가 없습니다 (영구 보유 1장은 유지)", info)
	if diamonds < int(cost.Cost): return _fail("다이아가 부족합니다 (필요 %d · 보유 %d)" % [int(cost.Cost), diamonds], info)
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

## Quote one swap of `identity` (a CARDS.card_id) in `category`.
## {ok, reason, token, category, card{identity,card_id,name,grade,grade_id}, used, max, remaining,
##  swap_count, cost{currency,currency_id,amount}, diamonds, copies_required, extra_copies,
##  copies_available, candidates[...], candidate_count, pick_count, pick_candidates[...]}
## ok:false still carries the known fields for display. Pass `token` to execute().
func quote(category: String, identity: String) -> Dictionary:
	_picks_dirty = false
	var plan: Dictionary = _plan(category, identity)
	# Newly shown pick candidates are saved at once, so restarting the game
	# does not show a different 5 (a refused save keeps them for this session).
	if _picks_dirty and world != null: world.call("_save_game", true)
	_picks_dirty = false
	if not bool(plan.get("ok", false)): return plan
	var token: String = Crypto.new().generate_random_bytes(16).hex_encode()
	_quotes.clear() # one confirmation at a time
	_quotes[token] = _fingerprint(plan)
	plan["token"] = token
	return plan

func _fingerprint(plan: Dictionary) -> Dictionary:
	return {"category":plan.category, "identity":plan.card.identity, "swap_count":plan.swap_count, "cost":plan.cost.amount, "copies":plan.copies_required,
		"pick":plan.pick_candidates.map(func(entry: Dictionary) -> String: return str(entry.identity)), "revision":revision}

## Execute a quoted swap. `pick` is the chosen identity on a PickCount swap
## (must be one of quote.pick_candidates); otherwise it is ignored.
## {ok, reason, saved, result{identity,name,grade,new}, consumed, cost, swap_count, remaining}
func execute(token: String, pick: String = "") -> Dictionary:
	var held: Dictionary = _quotes.get(token, {})
	if held.is_empty(): return _fail("견적이 없거나 만료되었습니다 · 다시 확인하세요")
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
	var cards = world.card_draw_fusion
	var cards_before: Dictionary = cards.export_state()
	var roll_before: int = rng.state
	var state_before: Dictionary = state.duplicate(true)
	if result_entry.is_empty():
		var pool: Array = plan.candidates
		result_entry = pool[rng.randi_range(0, pool.size() - 1)]
	var result_record: Dictionary = card_record(category, str(result_entry.identity))
	if result_record.is_empty() or int(cards.spare.get(category,{}).get(str(result_entry.identity),0)) >= MAX_SPARE: return _fail("결과 카드 저장 한도")
	var extras: Dictionary = cards.spare[category]
	var left: int = int(extras.get(identity, 0)) - int(plan.copies_required)
	if left < 0: return _fail("중복 카드가 부족합니다")
	if left == 0: extras.erase(identity)
	else: extras[identity] = left
	var received: Dictionary = cards._receive(category, {"id":str(result_entry.identity), "record":result_record})
	received["identity"] = str(received.get("id", ""))
	var counts: Dictionary = state.counts.get(category, {})
	counts[identity] = int(plan.swap_count)
	state.counts[category] = counts
	state.picks.erase(category + "|" + identity)
	var bag: Dictionary = world.inventory.duplicate(true)
	var balance: int = int(bag.get(DIAMOND, 0)) - int(plan.cost.amount)
	if balance > 0: bag[DIAMOND] = balance
	else: bag.erase(DIAMOND)
	revision += 1
	var saved: Error = world.call("_save_game", true, {"inventory":bag})
	if saved != OK:
		state = state_before
		cards.import_state(cards_before)
		rng.state = roll_before
		_quotes.erase(token)
		return _fail("다시 뽑기 저장 실패 · 카드와 다이아를 그대로 두었습니다")
	_quotes.erase(token)
	world.inventory = bag
	if world.has_method("_invalidate_equipment_static"): world.call("_invalidate_equipment_static")
	var collections: Variant = world.get("card_collections")
	if collections != null and collections.has_method("invalidate"): collections.invalidate()
	var hud: Variant = world.get("hud")
	if hud != null and is_instance_valid(hud):
		if hud.has_method("refresh_inventory"): hud.refresh_inventory(world.inventory)
		if hud.has_method("append_log"): hud.append_log("카드 다시 뽑기 · %s → %s (%s) · 다이아 %d" % [str(plan.card.name), str(received.get("name","")), category, int(plan.cost.amount)])
	if world.has_method("_update_hud"): world.call("_update_hud")
	return {"ok":true, "reason":"", "saved":true, "category":category, "from":plan.card, "result":received, "picked":int(plan.pick_count) > 0,
		"consumed":int(plan.copies_required), "cost":plan.cost, "swap_count":int(plan.swap_count), "remaining":maxi(0, int(plan.max) - int(plan.swap_count))}
