extends RefCounted
signal changed
## Durable local execution. The map/clock owner must supply a verified523 host;
## a menu selection, Land number, JSON flag or test scene cannot authorize entry.
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
var world: Node
var rules: RefCounted
var state: Dictionary = empty_state()
var busy: bool = false
var save_blocked: bool = false
var problem: String = ""

static func empty_state() -> Dictionary:
	return {"schema":1,"source_sha256":SOURCE_SHA,"revision":0,"next_run":1,"active":{},"clears":{},"settled":{},"cycles":{},"local_settings":{"enabled":true,"time_scale":1},"local_default_on_v2":true}

static func whole(value: Variant, lower: int = 0, upper: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= lower and float(value) <= upper

func configure(owner: Node, definitions: RefCounted) -> void:
	world = owner
	rules = definitions

func validate(value: Variant) -> String:
	if not value is Dictionary: return "던전 저장 형식이 손상되었습니다."
	if not whole(value.get("schema"),1,1) or value.get("source_sha256","") != SOURCE_SHA: return "알 수 없는 던전 저장 버전입니다."
	if not whole(value.get("local_day",0)): return "현재 지역 도전의 일일 기록이 손상되었습니다."
	var local: Variant = value.get("local_settings",{"enabled":true,"time_scale":1})
	if not local is Dictionary or not local.get("enabled") is bool or not whole(local.get("time_scale"),1,10): return "현재 지역 도전 설정이 손상되었습니다."
	for key: String in ["revision","next_run"]:
		if not whole(value.get(key),1 if key == "next_run" else 0): return "던전 저장 번호가 손상되었습니다."
	for key: String in ["active","clears","settled","cycles"]:
		if not value.get(key) is Dictionary or value[key].size() > 10000: return "던전 기록이 손상되었거나 한도를 초과했습니다."
	if not value.active.is_empty():
		var run: Dictionary = value.active
		for key: String in ["id","map_id","clock_contract","status"]:
			if not run.get(key) is String or run[key].is_empty() or run[key].length() > 256: return "던전 실행 식별자가 손상되었습니다."
		if run.status not in ["active","cleared","failed"] or not whole(run.get("stage_id"),1) or not whole(run.get("cycle")): return "던전 실행 상태가 손상되었습니다."
		if run.get("host_kind","") == "twilight_local" and (run.clock_contract != "twilight-local-kst05-v1" or not whole(run.get("local_deadline"),1,9000000000000000)): return "현재 지역 도전의 시간 기록이 손상되었습니다."
		var parts: PackedStringArray = str(run.id).split(":")
		if parts.size() != 3 or parts[0] != "tower" or parts[1] != str(int(run.stage_id)) or not parts[2].is_valid_int() or int(parts[2]) < 1 or int(parts[2]) >= int(value.next_run): return "던전 실행 번호가 올바르지 않습니다."
		if not run.get("grantable_ids") is Array: return "던전 지급 자격 기록이 손상되었습니다."
		if not run.get("hard") is bool or not run.get("counts") is Dictionary or not run.get("events") is Dictionary or run.events.size() > 1000: return "던전 목표 기록이 손상되었습니다."
		var stage: Dictionary = rules.stage("tower",int(run.stage_id))
		if stage.is_empty() or bool(stage.stage.IsHard) != run.hard: return "저장된 던전의 원본 자료를 확인할 수 없습니다."
		var expected: Dictionary = {}
		for goal: Dictionary in stage.goals: expected[str(int(goal.row.ID))] = int(goal.row.Amount)
		if expected.size() != run.counts.size(): return "던전 목표가 원본과 다릅니다."
		for key: String in expected:
			if not whole(run.counts.get(key),0,expected[key]): return "던전 목표 수량이 손상되었습니다."
			if run.status == "cleared" and int(run.counts[key]) != int(expected[key]): return "클리어 목표가 완료되지 않았습니다."
		for event: Variant in run.events:
			if not event is String or event.length() > 256 or run.events[event] != true: return "던전 이벤트 기록이 손상되었습니다."
		if run.status == "cleared" and run.grantable_ids != _reward_ids(rules.reward_preview("tower",int(run.stage_id))): return "보상 수령 조건이 확인되지 않았습니다."
	for key: Variant in value.clears:
		var clear: Variant = value.clears[key]
		if not key is String or not key.is_valid_int() or not clear is Dictionary or not whole(clear.get("cycle")) or not clear.get("hard") is bool or not clear.get("clock_contract") is String: return "던전 클리어 이력이 손상되었습니다."
		var stage: Dictionary = rules.stage("tower",int(key))
		if stage.is_empty() or bool(stage.stage.IsHard) != clear.hard: return "던전 클리어 자료가 다릅니다."
	for key: Variant in value.cycles:
		var cycle: Variant = value.cycles[key]
		if not key is String or key.length() > 256 or not cycle is Dictionary or not whole(cycle.get("tries"),0,2) or not whole(cycle.get("purchases"),0,1): return "던전 도전 횟수가 손상되었습니다."
		if int(cycle.tries) > 1 + int(cycle.purchases): return "던전 도전 횟수가 한도를 초과했습니다."
	for key: Variant in value.settled:
		var receipt: Variant = value.settled[key]
		if not key is String or key.length() > 256 or not receipt is Dictionary or not whole(receipt.get("stage_id"),1) or not receipt.get("immediate") is bool or not receipt.get("reward_rows") is Array: return "던전 보상 영수증이 손상되었습니다."
		if not key.begins_with(("immediate:" if receipt.immediate else "tower:") + str(int(receipt.stage_id)) + ":"): return "던전 보상 영수증의 종류가 다릅니다."
		var rewards: Array = rules.reward_preview("tower",int(receipt.stage_id),bool(receipt.immediate))
		if rewards.is_empty() or receipt.reward_rows != _reward_identity(rewards): return "던전 보상 영수증이 원본과 다릅니다."
	return ""

func restore(value: Variant) -> bool:
	problem = validate(value)
	save_blocked = not problem.is_empty()
	if save_blocked: return false
	state = value.duplicate(true)
	# The local Tower of Trials host is on by default; older saves are switched on once.
	if not state.get("local_default_on_v2", false):
		var local: Dictionary = state.get("local_settings", {"enabled":true,"time_scale":1})
		state["local_settings"] = {"enabled":true,"time_scale":int(local.get("time_scale",1))}
		state["local_default_on_v2"] = true
	return true

func has_experience_award() -> bool:
	for receipt: Dictionary in state.settled.values():
		for row: Dictionary in receipt.reward_rows:
			if int(row.RewardTypeID) == 1 and int(row.RewardClassID) == 281: return true
	return false

func context(stage_id: int) -> Dictionary:
	# The actual Main implements this through its current source field. No
	# registered current field exposes this contract yet; do not fabricate one.
	var value: Variant = world.source_dungeon_host_context(stage_id)
	if not value is Dictionary: return {}
	var stage: Dictionary = rules.stage("tower",stage_id)
	if stage.is_empty() or value.get("source_sha256","") != SOURCE_SHA: return {}
	if not whole(value.get("stage_id"),1) or int(value.stage_id) != stage_id or value.get("hard") != stage.stage.IsHard: return {}
	if not whole(value.get("land_id"),1) or int(value.land_id) != int(stage.place.land.ID): return {}
	if not value.get("map_id") is String or value.map_id != world.active_map_id: return {}
	if not whole(value.get("cycle")) or not value.get("clock_contract") is String or value.clock_contract.is_empty(): return {}
	if value.get("stage_access",false) != true: return {}
	return value

func check(stage_id: int, immediate: bool = false) -> Dictionary:
	var reasons: Array[String] = []
	var stage: Dictionary = rules.stage("tower",stage_id)
	if stage.is_empty(): return {"ok":false,"reasons":["시련의 탑 원본 자료가 없습니다."]}
	if save_blocked: reasons.append(problem)
	if busy: reasons.append("던전 저장을 처리 중입니다.")
	if world.has_method("source_dungeon_additional_busy") and world.source_dungeon_additional_busy():reasons.append("다른 던전 실행과 보상을 먼저 처리하세요.")
	if int(world.level) < int(stage.stage.MinLevel): reasons.append("%d레벨부터 입장할 수 있습니다." % int(stage.stage.MinLevel))
	var host := context(stage_id)
	if host.is_empty(): reasons.append("원본 Land %d의 전투·착지점·입장 자격·일일 시계 연결이 필요합니다." % int(stage.place.land.ID))
	if not state.active.is_empty() and (immediate or state.active.status == "active" or state.active.status == "cleared"):
		reasons.append("진행 중인 도전 또는 수령할 보상을 먼저 처리해 주세요.")
	if not host.is_empty():
		var cycle_key := _cycle_key(stage,host)
		var cycle: Dictionary = state.cycles.get(cycle_key,{"tries":0,"purchases":0})
		if int(cycle.tries) >= 1 + int(cycle.purchases): reasons.append("이 모드의 도전 횟수를 모두 사용했습니다.")
		if immediate:
			var clear: Dictionary = state.clears.get(str(stage_id),{})
			if clear.is_empty() or clear.clock_contract != host.clock_contract or int(clear.cycle) >= int(host.cycle): reasons.append("이전 날 클리어한 층부터 즉시 완료할 수 있습니다.")
			if state.settled.has(_immediate_key(stage_id,host)): reasons.append("이 주기의 즉시 완료 보상을 이미 받았습니다.")
			if host.get("immediate_reward_ids",[]) != _reward_ids(rules.reward_preview("tower",stage_id,true)): reasons.append("즉시 완료의 지급 시점·보상 자격 판정 연결이 필요합니다.")
	var payment: Dictionary = world.source_dungeon_payment_plan(764 if immediate else 174,int(stage.immediate.payment.Amount) if immediate else int(rules.tower_entry_cost(bool(stage.stage.IsHard)).get("BaseTryCurrencyCost",0)))
	if not bool(payment.get("ok",false)): reasons.append(str(payment.get("reason","재화를 확인할 수 없습니다.")))
	return {"ok":reasons.is_empty(),"reasons":reasons,"host":host,"payment":payment}

func begin(stage_id: int) -> Dictionary:
	var checked := check(stage_id)
	if not checked.ok: return checked
	var stage: Dictionary = rules.stage("tower",stage_id)
	var next := state.duplicate(true)
	var cycle_key := _cycle_key(stage,checked.host)
	var cycle: Dictionary = next.cycles.get(cycle_key,{"tries":0,"purchases":0})
	cycle.tries = int(cycle.tries) + 1
	next.cycles[cycle_key] = cycle
	var counts: Dictionary = {}
	for goal: Dictionary in stage.goals: counts[str(int(goal.row.ID))] = 0
	next.active = {"id":"tower:%d:%d" % [stage_id,int(next.next_run)],"stage_id":stage_id,"hard":bool(stage.stage.IsHard),"map_id":str(checked.host.map_id),"clock_contract":str(checked.host.clock_contract),"cycle":int(checked.host.cycle),"status":"active","counts":counts,"events":{},"grantable_ids":[]}
	if checked.host.get("host_kind","") == "twilight_local":
		next.active.host_kind = "twilight_local"
		next.active.local_deadline = int(checked.host.local_deadline)
	next.next_run = int(next.next_run) + 1
	return _commit(next,checked.payment)

func configure_local(enabled: bool, time_scale: int) -> Dictionary:
	if time_scale < 1 or time_scale > 10: return {"ok":false,"reason":"시간 배율은 1~10입니다."}
	if not state.active.is_empty() and state.active.status in ["active","cleared"]: return {"ok":false,"reason":"현재 도전과 보상을 먼저 처리해 주세요."}
	var next := state.duplicate(true)
	next.local_settings = {"enabled":enabled,"time_scale":time_scale}
	return _commit(next,{})

func buy_attempt(stage_id: int) -> Dictionary:
	var stage: Dictionary = rules.stage("tower",stage_id)
	var host := context(stage_id)
	if stage.is_empty() or host.is_empty() or int(world.level) < int(stage.stage.MinLevel): return {"ok":false,"reason":"입장 자격과 일일 주기 연결이 필요합니다."}
	if not state.active.is_empty() and state.active.status in ["active","cleared"]: return {"ok":false,"reason":"현재 도전을 먼저 처리해 주세요."}
	var price: Dictionary = {}
	for row: Dictionary in rules.data.get("declarations",{}).get("TrialTowerTryCountPurchase",[]):
		if bool(row.IsHard) == bool(stage.stage.IsHard): price = row
	if price.is_empty() or int(price.CurrencyID) != 4: return {"ok":false,"reason":"추가 횟수 비용을 확인할 수 없습니다."}
	var key := _cycle_key(stage,host)
	var cycle: Dictionary = state.cycles.get(key,{"tries":0,"purchases":0}).duplicate(true)
	if int(cycle.purchases) != 0: return {"ok":false,"reason":"이 모드의 추가 횟수를 이미 구매했습니다."}
	var payment: Dictionary = world.source_dungeon_payment_plan(int(price.CurrencyID),int(price.CurrencyCost))
	if not payment.get("ok",false): return payment
	cycle.purchases = 1
	var next := state.duplicate(true)
	next.cycles[key] = cycle
	return _commit(next,payment)

func record_event(kind: String, token: String, source_item_id: int = 0) -> Dictionary:
	if state.active.is_empty() or state.active.status != "active": return {"ok":false,"reason":"진행 중인 도전이 없습니다."}
	if token.is_empty() or token.length() > 220 or kind not in ["kill","pickup"]: return {"ok":false,"reason":"던전 이벤트가 올바르지 않습니다."}
	var host := context(int(state.active.stage_id))
	if host.is_empty() or host.clock_contract != state.active.clock_contract or int(host.cycle) != int(state.active.cycle): return {"ok":false,"reason":"도전의 지도·주기 식별자가 다릅니다."}
	if host.get("combat_open",false) != true: return {"ok":false,"reason":"원본 전투·시간 제한 판정 연결이 필요합니다."}
	var key := kind + ":" + token
	if state.active.events.has(key): return {"ok":true,"duplicate":true}
	var next := state.duplicate(true)
	var stage: Dictionary = rules.stage("tower",int(next.active.stage_id))
	var changed := false
	var complete := true
	for goal: Dictionary in stage.goals:
		var id := str(int(goal.row.ID))
		if (kind == "kill" and goal.type == "AnyNpcKill") or (kind == "pickup" and goal.type == "ItemCollect" and int(goal.row.GoalClassID) == source_item_id):
			next.active.counts[id] = mini(int(goal.row.Amount),int(next.active.counts[id])+1)
			changed = true
		complete = complete and int(next.active.counts[id]) >= int(goal.row.Amount)
	if not changed: return {"ok":false,"reason":"이 도전의 목표 이벤트가 아닙니다."}
	if complete and host.get("completion_allowed",false) != true: return {"ok":false,"reason":"원본 클리어·시간 제한 판정을 확인할 수 없습니다."}
	if complete and host.get("completion_reward_ids",[]) != _reward_ids(rules.reward_preview("tower",int(stage.stage.ID))): return {"ok":false,"reason":"보상의 지급 시점·수령 자격 판정 연결이 필요합니다."}
	next.active.events[key] = true
	if complete:
		next.active.status = "cleared"
		next.active.grantable_ids = host.completion_reward_ids.duplicate()
		next.clears[str(int(stage.stage.ID))] = {"cycle":int(host.cycle),"clock_contract":str(host.clock_contract),"hard":bool(stage.stage.IsHard)}
	return _commit(next,{})

func fail_run() -> Dictionary:
	if state.active.is_empty() or state.active.status != "active": return {"ok":true,"duplicate":true}
	var next := state.duplicate(true)
	next.active.status = "failed"
	# Source UI explicitly says exit fails and entry payment is not refunded.
	return _commit(next,{})

func claim() -> Dictionary:
	if state.active.is_empty() or state.active.status != "cleared": return {"ok":false,"reason":"클리어한 도전의 보상이 없습니다."}
	var run: Dictionary = state.active
	if state.settled.has(run.id): return {"ok":false,"reason":"이미 지급된 보상입니다."}
	return _settle(int(run.stage_id),str(run.id),false,{})

func immediate(stage_id: int) -> Dictionary:
	var checked := check(stage_id,true)
	if not checked.ok: return checked
	return _settle(stage_id,_immediate_key(stage_id,checked.host),true,checked.payment,checked.host)

func _settle(stage_id: int, key: String, immediate_mode: bool, payment: Dictionary, host: Dictionary = {}) -> Dictionary:
	if state.settled.has(key): return {"ok":false,"reason":"이미 지급된 보상입니다."}
	var rewards: Array = rules.reward_preview("tower",stage_id,immediate_mode)
	var prepared: Dictionary = world.source_dungeon_reward_plan(rewards,payment)
	if not bool(prepared.get("ok",false)): return prepared
	var next := state.duplicate(true)
	next.settled[key] = {"stage_id":stage_id,"immediate":immediate_mode,"reward_rows":_reward_identity(rewards)}
	if (host if immediate_mode else state.active).get("host_kind","") == "twilight_local": next.settled[key].host_kind = "twilight_local"
	if immediate_mode:
		var stage: Dictionary = rules.stage("tower",stage_id)
		var cycle_key := _cycle_key(stage,host)
		var cycle: Dictionary = next.cycles.get(cycle_key,{"tries":0,"purchases":0})
		cycle.tries = int(cycle.tries) + 1
		next.cycles[cycle_key] = cycle
	else: next.active = {}
	return _commit(next,prepared)

func _commit(next: Dictionary, changes: Dictionary) -> Dictionary:
	if busy or save_blocked: return {"ok":false,"reason":"던전 저장을 확인해 주세요."}
	if world.has_method("source_dungeon_local_cycle"): next.local_day = world.source_dungeon_local_cycle()
	next.revision = int(state.revision) + 1
	var error := validate(next)
	if not error.is_empty(): return {"ok":false,"reason":error}
	busy = true
	var result: Error = world.commit_source_dungeon(next,changes)
	busy = false
	if result != OK: return {"ok":false,"reason":problem if save_blocked else "저장 실패 · 재화와 던전 기록을 변경하지 않았습니다.","error":result,"requires_reload":save_blocked}
	state = next
	changed.emit()
	return {"ok":true,"revision":int(state.revision)}

static func _cycle_key(stage: Dictionary, host: Dictionary) -> String:
	return ("hard:" if bool(stage.stage.IsHard) else "normal:") + str(host.clock_contract) + ":" + str(int(host.cycle))

static func _immediate_key(stage_id: int, host: Dictionary) -> String:
	return "immediate:%d:%s:%d" % [stage_id,str(host.clock_contract),int(host.cycle)]

static func _reward_identity(rewards: Array) -> Array:
	var result: Array = []
	for reward: Dictionary in rewards: result.append(reward.row.duplicate(true))
	return result

static func _reward_ids(rewards: Array) -> Array:
	var result: Array = []
	for reward: Dictionary in rewards: result.append(int(reward.row.ID))
	return result
