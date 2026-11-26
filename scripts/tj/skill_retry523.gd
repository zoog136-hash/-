extends RefCounted
## Offline deck-41 retries. The dated server seasons and ordinary merge odds
## come from the held definitions. Older editions use the published Korean
## event windows. Expired editions reuse the game's local date rotation.
const DROP = preload("res://scripts/loot/patch523_monster_drops.gd")
const SERVER = preload("res://scripts/loot/current523_server_profile.gd")
const BOOK = preload("res://scripts/loot/patch523_stage_view.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
## Half-open local Korean times. Older coupons predate TJCouponSeason.
## The source world sets name legacy through Balrog (732), and Talking Island /
## Windawood (891). The Dec 2024 announcement gives the latter a later start.
const PUBLISHED_WINDOWS := {
	213901:[202101270500,202207060500], 222931:[202207060500,202209070500],
	244582:[202209070500,202306210500], 267868:[202306210500,202311220500],
	289082:[202311220500,202406120500], 307581:[202406120500,202412040500],
}

static func matches(policy: Dictionary) -> bool:
	return int(policy.get("ID",0)) == 121 and int(policy.get("UITypeID",0)) == 121 and int(policy.get("PlayerValueReturnTypeID",0)) == 94 and int(policy.get("BuffCardDeckID",0)) == 41 and int(policy.get("TJCouponHistoryType",0)) == 31 and int(policy.get("OwnerTypeID",0)) == 2 and int(policy.get("ChoiceFailCardCount",-1)) == 0 and policy.get("PossibleUnderGradeMerge") == true

static func context(world: Node) -> Dictionary:
	var profile: Dictionary = SERVER.profile(world)
	return {"service_region_code":str(profile.ServiceRegionCode),"world_no":int(profile.WorldNo)}

static func range_for(core: Object, window: Dictionary, expiry: int, now: int, item: int, server: Dictionary) -> Dictionary:
	var offset := int(core.settings.utc_offset_minutes)
	var deadline := DROP.source_deadline_unix(expiry,offset) if expiry > 0 else -1
	if expiry != -1 and deadline < 0: return {}
	var rotate: bool = deadline > 0 and now >= deadline and DROP.rotate_ended_dates
	if deadline > 0 and now >= deadline and not rotate: return {}
	var first_raw: int
	var end_raw: int
	if window.is_empty():
		if deadline < 0 or not PUBLISHED_WINDOWS.has(item): return {}
		var bounds: Array = PUBLISHED_WINDOWS[item]
		if core.server_matches(732,server): first_raw = int(bounds[0])
		elif item == 307581 and core.server_matches(891,server): first_raw = 202406192000
		else: return {}
		end_raw = int(bounds[1])
	else:
		first_raw = core.date_value(int(window.StartDateTimeID))
		end_raw = core.date_value(int(window.EndDateTimeID))
	var first := DROP.source_deadline_unix(first_raw,offset)
	var end := DROP.source_deadline_unix(end_raw,offset)
	if first < 0 or end <= first or now < end: return {}
	if rotate: return {"start":now + 1 - (end-first),"end":now + 1,"model":"offline_season_rotation"}
	return {"start":first,"end":end,"model":"published_window" if window.is_empty() else "source_season"}

static func stage_failure(world: Node, core: Object, plan: Dictionary) -> Dictionary:
	var ids: Array = []
	for candidate: Dictionary in plan.candidates: ids.append(str(candidate.card_id))
	return core.stage_failure({"adapter":"skill_fusion","history_type":31,"deck":41,"grade":int(plan.grade_id),
		"target_grade":int(plan.target_grade_id),"class_id":STACK.current_class(world),"time":core.clock(),
		"context":context(world),"success_candidates":ids,"fail_candidates":[]})

## Build both the result book and coupon debit against the same inventory snapshot.
## RNG is private to the staged result; a failed write consumes neither a roll nor an item.
static func redeem(runtime: Object, prepared: Dictionary, physical_id: String) -> Dictionary:
	var w: Node = runtime.world
	var core: Object = runtime.core
	var event: Dictionary = prepared.event
	var grade := int(event.grade)
	var rule: Dictionary = w.skill_cards523.merge_rule(grade)
	var target := int(event.get("target_grade",-1))
	if not w.skill_cards523.problem.is_empty() or STACK.current_class(w) != int(event.get("class_id",-1)) or rule.get("OnFailReward") != false or int(rule.get("SuccessGradeID",-2)) != target:
		return {"ok":false,"error":"현재 캐릭터의 스킬 합성 규칙과 실패 이력이 다릅니다 · 쿠폰 보존"}
	var pool: Array = []
	for card: Dictionary in w.skill_cards523.merge_candidates(target):
		if event.success_candidates.has(str(card.card_id)): pool.append(card)
	if pool.is_empty(): return {"ok":false,"error":"현재 직업과 원본 정의에 맞는 결과 스킬 카드가 없습니다"}
	var debit: Dictionary = {}
	var payload := {"gold":int(w.gold) - int(core.settings.retry_gold_cost)}
	if prepared.bag_debit:
		debit = runtime._bag_debit(prepared.item,physical_id)
		if not debit.get("ok",false): return debit
		payload.merge(debit.overrides)
	var rng := RandomNumberGenerator.new()
	rng.state = int(core.state.get("rng_state",str(w.skill_cards523.rng.state)))
	var chance := int(rule.SuccessProbability)
	var success := rng.randi_range(0,999999) < chance
	var result := {}
	if success:
		result = pool[rng.randi_range(0,pool.size()-1)]
		var grant: Dictionary = BOOK.stage_one(w,payload.get("inventory",w.inventory),payload.get("item_instances",w.item_instances),int(payload.gold),int(result.item_class_id),1,1,{"kind":"tj_skill_merge","deck_id":41,"card_id":int(result.card_id),"source_grade_id":grade})
		if not grant.get("ok",false): return {"ok":false,"error":str(grant.get("error","스킬 카드 지급 실패"))}
		payload.merge(grant.overrides,true)
	var next: Dictionary = prepared.state
	next["rng_state"] = str(rng.state)
	next.receipts.append({"revision":next.revision,"coupon":prepared.item,"event":event.id,"success":success,"time":next.last_time,"adapter":"skill_fusion","card":str(result.get("card_id","")),"probability":chance})
	payload[core.KEY] = next
	if w._save_game(true,payload) != OK: return {"ok":false,"error":"저장 실패 · 쿠폰과 실패 이력을 보존했습니다"}
	core.import_state(next)
	w.skill_cards523._commit_world(payload)
	var message := "스킬 재합성 성공 · %s" % str(result.name) if success else "스킬 재합성 실패"
	return {"ok":true,"success":success,"result":result,"error":message}
