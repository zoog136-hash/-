extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## One existing World save owns costs, rewards, event progress and durable RNG.
const Source = preload("res://scripts/unconfirmed523/source523.gd")
const StatAdapter = preload("res://scripts/collections/equipment_collection_stats.gd")
const QuestOwnership = preload("res://scripts/quests/quest_reward_ownership.gd")
const QuestConsumption = preload("res://scripts/quests/quest_reward_consumption.gd")
const SourceUICaller = preload("res://scripts/unconfirmed523/source_ui_service.gd")
const SAVE_KEY = "unconfirmed523"
const DOMAIN_PATHS = {"events":"events_domain", "jade_grail":"jade_grail_domain", "challenge":"challenge_domain"}
var source = Source.new()
var domains: Dictionary = {}
var world
var state: Dictionary = {"schema":1,"revision":0,"domains":{},"event_counters":{},"bonus_rewards":[],"event_receipts":{}}
var problem: String = ""
var save_blocked: bool = false
var busy: bool = false
var totals: Dictionary = {}
var effect_details: Dictionary = {}
var conditional_totals: Dictionary = {"undead":{},"pvp":{}}
var _prepared_rewards: Dictionary = {}
var _committing_plan: String = ""
var _held_requests: Dictionary = {}
var _held_consumption: Dictionary = {}
var _expiry_signature: String = ""
var _event_nonce: String = Crypto.new().generate_random_bytes(12).hex_encode()
var _last_survival_tick: String = ""
var time_policy: Dictionary = {}
var _source_configured: bool = false
var policy_problem: String = ""
var _presentation_adapter: Callable
var source_ui = SourceUICaller.new()
const POLICY_PATH: String = "res://data/unconfirmed523/twilight_policy.json"
var test_now: int = 0
var policy: Dictionary = {"luckybag_random_mode":"source_weights", "random_reward_weight_mode":"equal_estimate", "attendance_blessing_base":200,"conditional_percent_mode":"percentage_points_estimate","undead_damage_mode":"uniform_1_to_max_estimate","luckybag_final_scope":"source_item","luckybag_final_completion":"once"}

func configure(host: Node) -> void:
	world = host
	source_ui.configure(self)
	source.load_zip()
	_source_configured = source.ready()
	for key: String in DOMAIN_PATHS:
		var path: String = "res://scripts/unconfirmed523/%s.gd" % DOMAIN_PATHS[key]
		if not FileAccess.file_exists(path): continue
		domains[key] = load(path).new()
		if source.ready(): domains[key].setup(source)
		state.domains[key] = domains[key].initial_state()
	_load_policy_file()
	rebuild()

func fresh() -> Dictionary:
	var result: Dictionary = {"schema":1,"revision":0,"domains":{},"event_counters":{},"bonus_rewards":[],"event_receipts":{}}
	for key: String in domains: result.domains[key] = domains[key].initial_state()
	return result

func validate(value: Variant) -> String:
	if not value is Dictionary: return "추가 콘텐츠 저장 형식 오류"
	if value.get("schema") != 1 or not _integer(value.get("revision"),0): return "추가 콘텐츠 저장 버전·진행 값 오류"
	if not value.get("domains") is Dictionary or not value.get("event_counters") is Dictionary or not value.get("bonus_rewards",[]) is Array or not value.get("event_receipts",{}) is Dictionary: return "추가 콘텐츠 저장 구조 오류"
	for key: String in domains:
		if not value.domains.has(key): return "추가 콘텐츠 저장 영역 누락: " + key
	for key: Variant in value.domains:
		if not key is String or not DOMAIN_PATHS.has(key) or not value.domains[key] is Dictionary: return "추가 콘텐츠 저장 영역 오류"
		if source.ready() and domains.has(key):
			var error: String = domains[key].validate_state(value.domains[key])
			if not error.is_empty(): return error
	for key: Variant in value.event_counters:
		if not key is String or not _integer(value.event_counters[key],0): return "추가 콘텐츠 이벤트 값 오류"
	for event_id: Variant in value.get("event_receipts",{}):
		if not event_id is String or str(event_id).is_empty() or value.event_receipts[event_id] != true: return "추가 콘텐츠 이벤트 영수증 오류"
	var receipts: Dictionary = {}
	for reward: Variant in value.get("bonus_rewards",[]):
		if not reward is Dictionary or not _integer(reward.get("id"),1) or not _integer(reward.get("expires_at",0),0): return "추가 콘텐츠 보너스 값 오류"
		var receipt: String = str(reward.get("receipt_id","%d:%d:%d" % [int(reward.get("pass_id",0)),int(reward.get("source_reward_id",0)),int(reward.get("id",0))]))
		if receipts.has(receipt): return "추가 콘텐츠 보너스 중복 수령 오류"
		receipts[receipt] = true
	return ""

func check_load(data: Dictionary) -> String:
	return validate(data.get(SAVE_KEY,fresh()))

func restore(data: Dictionary) -> void:
	source_ui.close()
	_prepared_rewards.clear()
	_committing_plan = ""
	var next: Variant = data.get(SAVE_KEY,fresh())
	problem = validate(next)
	if not problem.is_empty(): save_blocked = true; return
	state = next.duplicate(true)
	if not state.has("event_receipts"): state.event_receipts = {}
	for key: String in domains:
		if not state.domains.has(key): state.domains[key] = domains[key].initial_state()
	# A missing original pack must never discard or re-interpret owned progress.
	save_blocked = (not source.ready() or not _source_configured) and not _empty_progress(state)
	if save_blocked: problem = "추가 콘텐츠 원본523 팩이 없어 기존 진행을 보존합니다"
	rebuild()

func snapshot() -> Dictionary:
	# Staged writes ask for the ordinary snapshot before merging their payload.
	# Keep that read isolated so a failed write cannot modify live transaction state.
	var result: Dictionary = state.duplicate(true)
	if not save_blocked and source.ready() and _source_configured and result.domains.has("jade_grail"):
		result.domains.jade_grail.latest_at = maxi(int(result.domains.jade_grail.get("latest_at",0)),now())
		if not busy: state.domains.jade_grail.latest_at = result.domains.jade_grail.latest_at
	return result

func effective_now() -> int:
	return maxi(now(),int(state.domains.get("jade_grail",{}).get("latest_at",0)))

func advance_time() -> void:
	if world == null or not source.ready() or not _source_configured or save_blocked: return
	if state.domains.has("jade_grail"): state.domains.jade_grail.latest_at = effective_now()
	# Called only by the live process loop; snapshot/restore never synthesize ticks.
	if domains.has("challenge") and domains.challenge.has_method("event") and not state.domains.get("challenge",{}).get("active",{}).is_empty():
		var active: Dictionary = state.domains.challenge.active
		var tick: String = "alive:%d:%d" % [int(active.get("run_id",0)),now()]
		if tick != _last_survival_tick:
			_last_survival_tick = tick
			var tick_context: Dictionary = {"nowUnix":now(),"map_id":str(world.active_map_id),"time_policy":_time_policy()}
			var response: Dictionary = domains.challenge.event({"kind":"survival_tick","event_id":tick,"alive":int(world.hp)>0},tick_context,state.domains.challenge)
			if bool(response.get("ok",false)): state.domains.challenge = response.state
	var signature: String = str(world.ain_service.dragon_orb_expires_at > effective_now()) + ":" + str(world.level)
	# Only owned physical grails participate. This 1Hz edge check uses indexed
	# source limits per distinct item ID, without rebuilding full context/tables.
	if domains.has("jade_grail") and domains.jade_grail.has_method("is_grail_item"):
		var eligibility: Dictionary = {}
		var clock: int = effective_now()
		var limit_context: Dictionary = {"now":clock,"nowUnix":clock,"level":int(world.level),"class_id":int(world.BASE508.source_class_id(str(world.job_class))),"service_region":"KR","world_no":1,"time_policy":_time_policy(),"enforce_item_use_limits":true}
		for uid: String in world.item_instances:
			var physical: Dictionary = world.item_instances[uid]
			var id: int = native_id(physical.get("record",{}))
			if not domains.jade_grail.is_grail_item(id): continue
			if not eligibility.has(id): eligibility[id] = source.item_eligibility(id,limit_context)
			signature += ":" + uid + ":" + str(_physical_expired(physical,clock)) + ":" + str(eligibility[id]) + ":" + str(_quantity(physical))
	for reward: Dictionary in state.get("bonus_rewards",[]):
		signature += ":" + str(int(reward.get("expires_at",0)) == 0 or int(reward.expires_at) > effective_now())
	if signature != _expiry_signature:
		_expiry_signature = signature
		rebuild()
		if world.has_method("_invalidate_equipment_static"): world._invalidate_equipment_static()

func now() -> int:
	return test_now if test_now > 0 else int(Time.get_unix_time_from_system())

func context() -> Dictionary:
	var clock: int = effective_now()
	var ctx: Dictionary = {"nowUnix":clock,"now":clock,"level":int(world.level),"max_level":int(world.level),"max_level_basis":"local_monotonic_level","class_id":int(world.BASE508.source_class_id(str(world.job_class))),"region":"KR","service_region":"KR","world_no":1,"map_id":str(world.active_map_id),"owned":{},"currencies":{"1":int(world.gold)},"instances":{},"equipped":{},"ain":world.ain_service.export_state(),"event_counters":state.event_counters.duplicate(true),"completed_quests":{},"pass_exp":{},"twilight_policy":policy.duplicate(true),"time_policy":_time_policy()}
	var assigned: Dictionary = {}
	for uid: String in world.item_instances:
		var raw: Dictionary = world.item_instances[uid]
		var record: Dictionary = raw.get("record",{})
		var sid: int = native_id(record)
		var item_name: String = str(raw.get("name",""))
		var quantity: int = _quantity(raw)
		# Reserve every physical copy before considering an untracked bag remainder.
		# A conflicting native record must never be replaced by a name lookup.
		assigned[item_name] = int(assigned.get(item_name,0)) + maxi(0,quantity)
		if sid <= 0:
			if record.has("source_item_class_id") or str(record.get("sourceId","")).begins_with("m523:item:") or str(record.get("sourceId","")).begins_with("m508:item:"): ctx["ownership_error"] = "원본 개체 ID 충돌"
			continue
		if quantity < 1 or quantity > 1000000000: ctx["ownership_error"] = "원본 아이템 수량 오류"; continue
		var receipt_error: String = _grant_receipt_error(raw,sid,quantity,uid)
		if not receipt_error.is_empty(): ctx["ownership_error"] = receipt_error; continue
		if int(assigned[item_name]) > int(world.inventory.get(item_name,0)): ctx["ownership_error"] = "원본 아이템 개체와 가방 수량 불일치"; continue
		if _physical_expired(raw,maxi(now(),int(state.domains.get("jade_grail",{}).get("latest_at",0)))): continue
		var item: Dictionary = raw.duplicate(true)
		item["sourceID"] = sid; item["instance_id"] = uid; item["quantity"] = quantity
		item["locked"] = bool(raw.get("locked",false)) or bool(world.ui_preferences.get("item_locks",{}).get(uid,false)) or bool(world.ui_preferences.get("item_locks",{}).get(item_name,false))
		item["equipped"] = world._is_instance_equipped(uid)
		ctx.instances[uid] = item
		ctx.owned[str(sid)] = int(ctx.owned.get(str(sid),0)) + quantity
	ctx["stacks"] = {}
	# Ordinary native stacks already in the catalog need no synthetic physical ID.
	for item_name: String in world.inventory:
		var remainder: int = int(world.inventory[item_name]) - int(assigned.get(item_name,0))
		if remainder <= 0: continue
		var record: Dictionary = world._find_catalog_item_record(item_name)
		var sid: int = native_id(record)
		if sid <= 0: continue
		var definition: Dictionary = source.row("ItemClass",sid)
		if int(definition.get("MaxStackAmount",1)) <= 1: continue
		ctx.stacks[item_name] = {"sourceID":sid,"quantity":remainder,"record":NATIVE_FIELDS.full(record).duplicate(true),"locked":bool(world.ui_preferences.get("item_locks",{}).get(item_name,false))}
		ctx.owned[str(sid)] = int(ctx.owned.get(str(sid),0)) + remainder
	for slot: String in world.equipped_items:
		var equipped: Variant = world.equipped_items[slot]
		if equipped is Dictionary: ctx.equipped[slot] = str(equipped.get("instance_id",""))
	if source.ready():
		for row: Dictionary in source.rows("CurrencyUnitClass"):
			if int(row.get("UnitID",0)) == 4 and not bool(row.get("ForGive",true)) and int(row.get("CurrencyID",0)) != 1:
				var key: String = str(int(row.CurrencyID))
				ctx.currencies[key] = int(ctx.currencies.get(key,0)) + int(ctx.owned.get(str(int(row.ClassID)),0))
	for pass_id: String in state.domains.get("events",{}).get("passes",{}):
		ctx.pass_exp[pass_id] = int(state.domains.events.passes[pass_id].get("experience",0))
	var completed: Variant = world.quest_service.export_state().get("claimed",{})
	if completed is Dictionary: ctx.completed_quests = completed.duplicate(true)
	return ctx

static func native_id(record: Dictionary) -> int:
	var explicit: Variant = record.get("source_item_class_id",0)
	var supplied: bool = record.has("source_item_class_id")
	if supplied and not _integer(explicit,1): return 0
	var source_id: String = str(record.get("sourceId",""))
	for prefix: String in ["m523:item:","m508:item:","lineagem_m_item:"]:
		if source_id.begins_with(prefix):
			var suffix: String = source_id.trim_prefix(prefix)
			var main_id: String = suffix.get_slice(":",0)
			if not main_id.is_valid_int() or int(main_id) <= 0: return 0
			if supplied and int(explicit) != int(main_id): return 0
			if suffix != main_id and suffix not in [main_id+":bless:1",main_id+":bless:2",main_id+":bless:3"]: return 0
			return int(main_id)
	return 0

static func _quantity(physical: Dictionary) -> int:
	var record: Dictionary = physical.get("record",{})
	var amount: Variant = physical.get("source_reward_quantity",record.get("source_reward_quantity",1))
	return int(amount) if _integer(amount,1) and int(amount) <= 1000000000 else 0

func bind_presentation(adapter: Callable) -> void:
	# Original UI owns presentation/confirmation. Never persist a UI binding or
	# install a substitute when that owner's source interface is unavailable.
	_presentation_adapter = adapter
	source_ui.configure(self)
	source_ui.close()

func request_presentation(section: String = "events", focus: Dictionary = {}) -> Dictionary:
	if not DOMAIN_PATHS.has(section): return _fail("콘텐츠 영역 오류")
	if not _presentation_adapter.is_valid():
		source_ui.close()
		return {"ok":false,"code":"presentation_unavailable","error":"원본 UI 연결이 필요합니다"}
	source_ui.configure(self)
	var model: Dictionary = source_ui.open_section(section,focus)
	if not model.get("ok",false): return model
	var response: Variant = _presentation_adapter.call(section)
	if not response is Dictionary:
		source_ui.close()
		return _fail("UI 연결 응답 오류")
	if not response.get("ok",false): source_ui.close()
	# Opening a source UI is not a successful purchase/claim/use transaction.
	# That UI must submit its confirmed action separately through execute().
	return response.duplicate(true)

func page(key: String) -> Dictionary:
	if not source.ready() or not _source_configured: return {"title":"원본523 콘텐츠","notes":["기존 비공개 공통523 ZIP을 설치하면 사용할 수 있습니다.",source.last_error],"rows":[]}
	if not problem.is_empty(): return {"title":"저장 보호","notes":[problem],"rows":[]}
	if not domains.has(key): return {"title":"콘텐츠","notes":["소비자 연결 없음"],"rows":[]}
	var content: Dictionary = domains[key].view(context(),state.domains[key])
	if not policy_problem.is_empty():
		content["notes"] = content.get("notes",[]).duplicate()
		content.notes.append(policy_problem)
	return content

func fingerprint() -> String:
	var service: Variant = world.get("quest_service")
	var quest_state: Dictionary = service.export_state() if service != null and service.has_method("export_state") else {}
	return JSON.stringify([world.inventory,world.item_instances,world.gold,world.level,world.experience,world.exp_need,world.stat_points,world.equipped_items,world.ui_preferences.get("item_locks",{}),world.ain_service.export_state(),quest_state,state.revision]).sha256_text()

func execute(key: String, request: Dictionary, revision: int = -1, expected: String = "") -> Dictionary:
	if busy: return _fail("거래 처리 중")
	if save_blocked or not problem.is_empty(): return _fail(problem)
	if not source.ready() or not _source_configured or not domains.has(key): return _fail("원본523 팩을 먼저 설치하고 재시작하세요")
	if revision >= 0 and revision != int(state.revision): return _fail("화면의 진행 상태가 변경되었습니다")
	if not expected.is_empty() and fingerprint() != expected: return _fail("보유 아이템·재화가 변경되었습니다. 다시 확인하세요")
	var ctx: Dictionary = context()
	if ctx.has("ownership_error"): return _fail(str(ctx.ownership_error))
	busy = true
	var proposal: Dictionary = domains[key].propose(request,ctx,state.domains[key])
	if not bool(proposal.get("ok",false)): busy = false; return proposal
	var next: Dictionary = state.duplicate(true)
	next.domains[key] = proposal.get("state",state.domains[key]).duplicate(true)
	next.revision = int(next.revision)+1
	var staged: Dictionary = _stage_world()
	staged.ainhasad_state = proposal.get("ain",world.ain_service.export_state()).duplicate(true)
	var failure: String = ""
	for cost: Dictionary in proposal.get("costs",[]):
		failure = _cost(cost,staged,ctx)
		if not failure.is_empty(): break
	if failure.is_empty():
		for reward: Dictionary in proposal.get("rewards",[]):
			failure = _reward(reward,staged,next,ctx)
			if not failure.is_empty(): break
	if failure.is_empty() and proposal.get("ain") is Dictionary and _integer(ctx.ain.get("blessing"),0) and _integer(proposal.ain.get("blessing"),0):
		var blessing_spent: int = int(ctx.ain.blessing)-int(proposal.ain.blessing)
		if blessing_spent > 0:
			var progressed: Dictionary = _stage_pass_event(next,"blessing_use",{"amount":blessing_spent,"event_id":"source_grant:unconfirmed523:blessing_use:%d" % int(next.revision)},_fresh_context(next))
			if not progressed.get("ok",false): failure = str(progressed.get("error","축복 소비 진행 확인 필요"))
	if failure.is_empty() and key == "challenge" and str(request.get("op","")) == "challenge_claim" and domains.has("events") and domains.events.has_method("event"):
		var challenge_id: int = int(state.domains.challenge.get("active",{}).get("challenge_id",request.get("challenge_id",0)))
		var event: Dictionary = {"kind":"challenge_complete","source_id":challenge_id,"amount":1,"event_id":"challenge_claim:%d" % int(next.revision)}
		var progressed: Dictionary = domains.events.event(event,ctx,next.domains.events)
		if bool(progressed.get("ok",false)): next.domains.events = progressed.state
	if failure.is_empty(): failure = validate(next)
	if not failure.is_empty(): busy = false; return _fail(failure)
	staged[SAVE_KEY] = next
	return _publish(staged,proposal.get("rewards",[]),proposal.get("assumptions",[]))

func observe_staged_owner(overrides: Dictionary) -> Dictionary:
	if overrides.has("ground_drops") and world!=null and world.get("source_ground_acquisitions")!=null and world.source_ground_acquisitions.authorizes(overrides):
		return _observe_source_ground_acquisition(overrides)
	# Read only: a native fishing finish removes its persisted pending cast and
	# adds exactly one source Fish item. NoMemory catches need no journal entry.
	if not overrides.has("fishing523") or busy or save_blocked or not problem.is_empty(): return {"ok":true}
	if world == null or not source.ready() or not _source_configured or not domains.has("events") or not domains.events.has_method("event"): return {"ok":true}
	var owner: Variant = world.get("fishing523")
	if owner == null: return {"ok":true}
	var before: Variant = owner.get("state")
	var after: Variant = overrides.fishing523
	if not before is Dictionary or not after is Dictionary or not before.get("pending") is Dictionary or not after.get("pending") is Dictionary: return {"ok":true}
	var pending: Dictionary = before.pending
	if pending.is_empty() or not after.pending.is_empty() or not pending.get("id") is String or str(pending.id).is_empty() or not _integer(pending.get("fish"),1): return {"ok":true}
	if not before.get("items") is Dictionary or not after.get("items") is Dictionary: return {"ok":true}
	var fish: Dictionary = source.row("Fish",int(pending.fish))
	if not _integer(fish.get("ItemClassID"),1): return {"ok":true}
	var item_id: String = str(int(fish.ItemClassID))
	if not _integer(before.items.get(item_id,0),0) or not _integer(after.items.get(item_id,0),0) or int(before.items.get(item_id,0)) >= 9007199254740991: return {"ok":true}
	if int(after.items.get(item_id,0)) != int(before.items.get(item_id,0))+1: return {"ok":true}
	var next: Dictionary = state.duplicate(true)
	var response: Dictionary = _stage_pass_event(next,"fishing_success",{"amount":1,"source_id":int(pending.fish),"event_id":"source_grant:fishing523:catch:"+str(pending.id).sha256_text()},_fresh_context(next))
	if not response.get("ok",false): return response
	if not response.get("changed",false): return {"ok":true}
	next.revision = int(next.revision)+1
	var error: String = validate(next)
	if not error.is_empty(): return _fail(error)
	return {"ok":true,"state":next}

func _observe_source_ground_acquisition(overrides: Dictionary) -> Dictionary:
	# The item owner has sealed exact original drop membership, physical IDs,
	# quantities and the removed floor record. Reuse the existing event owner.
	if busy or save_blocked or not problem.is_empty() or not source.ready() or not _source_configured:return {"ok":true}
	var before: Variant=world.consumable_service.export_state().get("source_ground_acquisitions",{})
	var after: Variant=overrides.get("consumable_state",{}).get("source_ground_acquisitions",{})
	if not before is Dictionary or not after is Dictionary:return _fail("원본 습득 이벤트 영수증 형식 오류")
	var next: Dictionary=state.duplicate(true)
	var changed: bool=false
	for id: String in after:
		if before.has(id):continue
		var drop: Dictionary=world.ground_loot.records.get(id,{})
		var receipt: Variant=after[id]
		if drop.is_empty() or not receipt is Dictionary or int(receipt.get("quantity",0))!=int(drop.get("quantity",-1)):return _fail("원본 습득 이벤트 개체·수량 불일치")
		var response: Dictionary=_stage_pass_event(next,"pickup",{"amount":int(receipt.quantity),"source_id":native_id(drop.get("item_record",{})),"event_id":id},_fresh_context(next))
		if not response.get("ok",false):return response
		changed=changed or bool(response.get("changed",false))
	if not changed:return {"ok":true}
	next.revision=int(next.revision)+1
	var error: String=validate(next)
	if not error.is_empty():return _fail(error)
	return {"ok":true,"state":next}

func _fresh_context(candidate: Dictionary) -> Dictionary:
	# Event eligibility needs no inventory or quest export; avoid their live
	# synchronization while observing somebody else's staged transaction.
	var clock: int = effective_now()
	return {"nowUnix":clock,"now":clock,"level":int(world.level),"max_level":int(world.level),"class_id":int(world.BASE508.source_class_id(str(world.job_class))),"region":"KR","service_region":"KR","world_no":1,"map_id":str(world.active_map_id),"event_counters":candidate.event_counters.duplicate(true),"twilight_policy":policy.duplicate(true),"time_policy":_time_policy()}

func _stage_pass_event(candidate: Dictionary, kind: String, payload: Dictionary, ctx: Dictionary) -> Dictionary:
	if not domains.has("events") or not domains.events.has_method("event"): return {"ok":true,"changed":false}
	var receipt: String = str(payload.get("event_id",""))
	if receipt.is_empty() or receipt.length() > 160 or not _integer(payload.get("amount",1),1) or not _integer(payload.get("source_id",0),0): return _fail("추가 콘텐츠 합성 이벤트 형식 오류")
	if candidate.get("event_receipts",{}).has(receipt): return {"ok":true,"changed":false}
	var event: Dictionary = payload.duplicate(true)
	event.kind = kind
	var progressed: Dictionary = domains.events.event(event,ctx,candidate.domains.events)
	if not progressed.get("ok",false): return progressed
	candidate.domains.events = progressed.state
	if not candidate.has("event_receipts"): candidate.event_receipts = {}
	candidate.event_receipts[receipt] = true
	var amount: int = int(payload.get("amount",1))
	candidate.event_counters[kind] = int(candidate.event_counters.get(kind,0))+amount
	var source_id: int = int(payload.get("source_id",0))
	if source_id > 0:
		var key: String = "%s:%d" % [kind,source_id]
		candidate.event_counters[key] = int(candidate.event_counters.get(key,0))+amount
	return {"ok":true,"changed":true}

func _publish(staged: Dictionary, rewards: Array = [], assumptions: Array = []) -> Dictionary:
	if not _held_consumption.is_empty() and not QuestConsumption.matches_payload(world,_held_consumption,staged):
		busy = false
		return _fail("원본 보상 사용 후보·최종 저장 내용이 변경되었습니다")
	var result: Error = world._save_game(true,staged)
	if result != OK:
		busy = false
		# A writer can fail after the payload was published (e.g. pointer update).
		# Preserve live values and block another roll/save until a deliberate reload.
		save_blocked = true
		problem = "저장 결과 확인 필요 · 재시도 전 저장을 다시 불러오세요 (%d)" % result
		return _fail(problem)
	world.inventory = staged.inventory
	world.item_instances = staged.item_instances
	world.gold = staged.gold
	world.ain_service.import_state(staged.ainhasad_state)
	world.experience = staged.experience; world.level = staged.level; world.exp_need = staged.exp_need; world.stat_points = staged.stat_points
	world.next_item_instance_id = staged.next_item_instance_id
	if staged.has("quest_state"): world.quest_service.import_state(staged.quest_state)
	state = staged[SAVE_KEY].duplicate(true)
	busy = false
	_held_requests.clear()
	_held_consumption.clear()
	_prepared_rewards.clear()
	rebuild()
	world._update_hud()
	world.hud.refresh_inventory(world.inventory)
	return {"ok":true,"revision":state.revision,"rewards":rewards.duplicate(true),"assumptions":assumptions.duplicate(true)}

func prepare_pass_reward(proof: Dictionary) -> Dictionary:
	# Host-only port for a future Quest523 claim adapter. This validates the raw
	# quest->reward edge, but deliberately does not certify quest completion.
	# The upstream owner must commit its claim state with this staged payload.
	if busy or save_blocked or not problem.is_empty(): return _fail("추가 콘텐츠 거래·저장 보호 중")
	if not source.ready() or not _source_configured or not domains.has("events"): return _fail("원본523 패스 연결 필요")
	if proof.get("schema") != 1 or str(proof.get("source_sha256","")) != Source.SOURCE_SHA256: return _fail("원본 패스 지급 증명 버전·SHA 오류")
	if not _integer(proof.get("quest_id"),1) or not _integer(proof.get("reward_id"),1): return _fail("원본 패스 지급 ID 오류")
	var claim_id: String = str(proof.get("claim_id",""))
	if not proof.get("claim_id") is String or claim_id.is_empty() or claim_id.length() > 96: return _fail("검증된 상위 청구 ID 필요")
	var quest_id: int = int(proof.quest_id); var reward_id: int = int(proof.reward_id)
	var linked: bool = false
	for link: Dictionary in source.rows("QuestReward"):
		if int(link.get("QuestID",0)) == quest_id and int(link.get("RewardID",0)) == reward_id: linked = true; break
	var raw: Dictionary = source.row("Reward",reward_id)
	if not linked or int(raw.get("RewardTypeID",0)) != 172: return _fail("원본 퀘스트·시즌 경험치 연결 오류")
	var pass_id: int = int(raw.get("RewardClassID",0))
	var ctx: Dictionary = context()
	if ctx.has("ownership_error"): return _fail(str(ctx.ownership_error))
	var availability: String = _pass_reward_available(pass_id,ctx)
	if not availability.is_empty(): return _fail(availability)
	var receipt: String = "source_grant:quest523:pass_exp:%d:%d:%s" % [quest_id,reward_id,claim_id.sha256_text()]
	if state.event_receipts.has(receipt): return _fail("이미 반영한 원본 패스 지급")
	var resolved: Dictionary = source.resolve_reward(reward_id,ctx)
	if not bool(resolved.get("ok",false)): return resolved
	var next: Dictionary = state.duplicate(true)
	next.revision = int(next.revision)+1
	next.event_receipts[receipt] = true
	var staged: Dictionary = _stage_world()
	for reward: Dictionary in resolved.get("rewards",[]):
		if str(reward.get("kind","")) != "pass_exp" or int(reward.get("id",0)) != pass_id: return _fail("직접 패스 지급 외 보상은 별도 검증 필요")
		var error: String = _reward(reward,staged,next,ctx)
		if not error.is_empty(): return _fail(error)
	if resolved.get("rewards",[]).is_empty(): return _fail("원본 패스 지급 보상 누락")
	var validation: String = validate(next)
	if not validation.is_empty(): return _fail(validation)
	staged = {SAVE_KEY:next}
	var token: String = Crypto.new().generate_random_bytes(16).hex_encode()
	if _prepared_rewards.size() >= 32: _prepared_rewards.erase(_prepared_rewards.keys()[0])
	_prepared_rewards[token] = {"staged":staged,"fingerprint":fingerprint(),"state_hash":JSON.stringify(state).sha256_text(),"policy_hash":JSON.stringify([policy,time_policy]).sha256_text(),"pass_id":pass_id,"rewards":resolved.rewards.duplicate(true),"receipt":receipt}
	return {"ok":true,"plan_id":token,"staged":staged.duplicate(true),"rewards":resolved.rewards.duplicate(true),"receipt_id":receipt,"boundary":"upstream_claim_must_join_same_write; pass_time_policy_is_device_local_by_default"}

func begin_prepared_commit(plan_id: String) -> Dictionary:
	# The returned copy can be combined with the upstream claim owner's staged
	# state. STRICT synchronous critical section: begin -> writer -> finish,
	# with no await/yield and before applying upstream live state.
	if busy or save_blocked or not problem.is_empty(): return _fail("추가 콘텐츠 거래·저장 보호 중")
	if not _prepared_rewards.has(plan_id): return _fail("준비된 패스 지급이 없거나 이미 사용됨")
	var plan: Dictionary = _prepared_rewards[plan_id]
	if fingerprint() != plan.fingerprint or JSON.stringify(state).sha256_text() != plan.state_hash or JSON.stringify([policy,time_policy]).sha256_text() != plan.policy_hash: return _fail("준비 후 보유·진행·정책이 변경되었습니다")
	var available: String = _pass_reward_available(int(plan.pass_id),context())
	if not available.is_empty(): return _fail(available)
	busy = true
	_committing_plan = plan_id
	return {"ok":true,"staged":plan.staged.duplicate(true)}

func finish_prepared_commit(plan_id: String, result: Error, written: Dictionary) -> Dictionary:
	# Call only after the same World writer completed. A failed/uncertain write
	# blocks retries just like ordinary item/RNG transactions.
	if not busy or _committing_plan != plan_id or not _prepared_rewards.has(plan_id): return _fail("준비된 지급 커밋 순서 오류")
	var plan: Dictionary = _prepared_rewards[plan_id]
	_committing_plan = ""
	if result != OK:
		busy = false; save_blocked = true; _prepared_rewards.clear()
		problem = "저장 결과 확인 필요 · 재시도 전 저장을 다시 불러오세요 (%d)" % result
		return _fail(problem)
	if fingerprint() != plan.fingerprint or JSON.stringify(state).sha256_text() != plan.state_hash or JSON.stringify([policy,time_policy]).sha256_text() != plan.policy_hash:
		busy = false; save_blocked = true; _prepared_rewards.clear()
		problem = "합성 저장 중 보유·진행·정책 변경 확인 필요 · 현재 진행 보존"
		return _fail(problem)
	for key: String in plan.staged:
		if not written.has(key) or not _same_progress(written[key],plan.staged[key]):
			busy = false; save_blocked = true; _prepared_rewards.clear()
			problem = "합성 저장 내용 확인 필요 · 원본 진행 보존"
			return _fail(problem)
	_apply_prepared_state(plan.staged)
	return {"ok":true,"revision":state.revision,"rewards":plan.rewards.duplicate(true)}

func cancel_prepared(plan_id: String) -> bool:
	if busy and _committing_plan == plan_id: return false
	return _prepared_rewards.erase(plan_id)

func _stage_world() -> Dictionary:
	_held_requests.clear()
	_held_consumption.clear()
	var staged: Dictionary = {"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"gold":int(world.gold),"ainhasad_state":world.ain_service.export_state().duplicate(true),"experience":int(world.experience),"level":int(world.level),"exp_need":int(world.exp_need),"stat_points":int(world.stat_points),"next_item_instance_id":int(world.next_item_instance_id)}
	var service: Variant = world.get("quest_service")
	if service != null and service.has_method("export_state"): staged["quest_state"] = service.export_state().duplicate(true)
	return staged

func _apply_prepared_state(staged: Dictionary) -> void:
	# Direct Reward172 changes only this namespace. The upstream owner applies
	# its own staged claim/costs after the same writer succeeds.
	state = staged[SAVE_KEY].duplicate(true)
	busy = false
	_prepared_rewards.clear()
	rebuild()
	world._update_hud()
	world.hud.refresh_inventory(world.inventory)

func _pass_reward_available(pass_id: int, ctx: Dictionary) -> String:
	var pass_row: Dictionary = source.row("PassSystem",pass_id)
	if pass_row.is_empty() or int(pass_row.get("PassSystemTypeID",0)) != 12: return "원본 시즌 패스 대상 오류"
	if not bool(pass_row.get("IsActive",false)): return "비활성 원본 시즌 패스"
	if not source.region_allowed(int(pass_row.get("ServerLimitSetID",0)),ctx): return "원본 시즌 패스 지역·서버 제한"
	for field: String in ["SeasonStartDateTimeID","SeasonEndDateTimeID"]:
		var date_id: int = int(pass_row.get(field,0))
		if date_id == 0: continue
		var stamp: int = int(source.timestamp(date_id,ctx))
		if stamp < 0: return "원본 시즌 패스 시간 확인 필요"
		if field == "SeasonStartDateTimeID" and effective_now() < stamp: return "원본 시즌 패스 시작 전"
		if field == "SeasonEndDateTimeID" and effective_now() >= stamp: return "원본 시즌 패스 종료"
	return ""

func _grant_receipt_error(physical: Dictionary, item_id: int, remaining: int, physical_id: String = "") -> String:
	if not physical.has("quest_reward_receipt"): return ""
	# PR262's issued quantity is immutable proof. The physical remaining stack
	# is a separate field and may decrease after an exact-instance consumption.
	var proof: Variant = physical.quest_reward_receipt
	if not proof is Dictionary or proof.get("schema") != 1 or str(proof.get("source_sha256","")) != Source.SOURCE_SHA256: return "원본 퀘스트 지급 증명 오류"
	var quest_id: int = _canonical_quest_number(proof.get("quest_id"))
	if quest_id <= 0: return "원본 퀘스트 지급 ID 오류"
	for field: String in ["reward_id","item_class_id","bless_code_id","quantity"]:
		if not _integer(proof.get(field),1): return "원본 퀘스트 지급 증명 값 오류"
	if int(proof.item_class_id) != item_id or remaining > int(proof.quantity): return "원본 퀘스트 발행·잔여 수량 불일치"
	var record: Dictionary = physical.get("record",{})
	var bless: int = int(physical.get("bless_code",record.get("source_bless_code_id",record.get("source_bless_code",1))))
	if int(proof.bless_code_id) not in [1,2,3] or bless != int(proof.bless_code_id): return "원본 퀘스트 축복 증명 불일치"
	var reward: Dictionary = source.row("Reward",int(proof.reward_id))
	if int(reward.get("RewardTypeID",0)) != 2 or int(reward.get("RewardClassID",0)) != item_id or int(reward.get("ItemBlessCodeID",1)) != int(proof.bless_code_id) or int(proof.quantity) > int(reward.get("Amount",0)): return "원본 퀘스트 지급 보상 연결 오류"
	var linked: bool = false
	for link: Dictionary in source.rows("QuestReward"):
		if int(link.get("QuestID",0)) == quest_id and int(link.get("RewardID",0)) == int(proof.reward_id): linked = true; break
	if not linked: return "원본 퀘스트 지급 출처 연결 오류"
	if physical_id.is_empty(): return "원본 퀘스트 지급 개체 확인 필요"
	var owned: Dictionary = QuestOwnership.proof(world,physical_id)
	if not owned.get("ok",false): return str(owned.get("reason","원본 퀘스트 소유권 확인 필요"))
	if int(owned.item_class_id) != item_id or int(owned.quantity) != remaining: return "원본 퀘스트 소유 수량 불일치"
	return ""

static func _canonical_quest_number(value: Variant) -> int:
	if not value is String or not value.begins_with("m523:quest:"): return 0
	var suffix: String = value.trim_prefix("m523:quest:")
	if not suffix.is_valid_int() or int(suffix) <= 0 or str(int(suffix)) != suffix: return 0
	return int(suffix)

func _stage_owned_debit(uid: String, take: int, staged: Dictionary) -> String:
	# The published shared ABI owns batching and ledger composition. Apply this
	# selected delta without replacing other costs already staged by this owner.
	var current: Dictionary = staged.item_instances.get(uid,{})
	var live: Dictionary = world.item_instances.get(uid,{})
	var total: int = _quantity(live)-_quantity(current)+take
	var requests: Dictionary = _held_requests.duplicate(true)
	requests[uid] = {"physical_id":uid,"quantity":total,"expected_quantity":_quantity(live),"expected_remaining":_quantity(live)-total,"quest_reward_receipt":live.get("quest_reward_receipt",{}).duplicate(true)}
	var step: Dictionary = QuestConsumption.stage(world,requests.values(),Source.SOURCE_SHA256)
	if not step.get("ok",false): return str(step.get("reason","원본 보상 소비 준비 실패"))
	var name_value: String = str(live.name)
	staged.inventory[name_value] = int(staged.inventory[name_value])-take
	if int(staged.inventory[name_value]) == 0: staged.inventory.erase(name_value)
	if step.overrides.item_instances.has(uid): staged.item_instances[uid] = step.overrides.item_instances[uid].duplicate(true)
	else: staged.item_instances.erase(uid)
	staged.quest_state = step.overrides.quest_state.duplicate(true)
	_held_requests = requests
	_held_consumption = step
	return ""

func _cost(cost: Dictionary, staged: Dictionary, ctx: Dictionary) -> String:
	var amount: int = int(cost.get("amount",0)); var id: int = int(cost.get("id",0))
	if not _integer(cost.get("amount"),1) or not _integer(cost.get("id"),1): return "비용 정의 오류"
	if str(cost.get("kind","")) == "currency":
		if id == 1:
			if int(staged.gold) < amount: return "아데나 부족"
			staged.gold -= amount; return ""
		var units: Array = []
		for row: Dictionary in source.rows("CurrencyUnitClass"):
			if int(row.get("CurrencyID",0)) == id and int(row.get("UnitID",0)) == 4 and not bool(row.get("ForGive",true)): units.append(row)
		if units.is_empty(): return "지원하지 않는 재화 소비"
		units.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.get("ConsumePriority",0)) < int(b.get("ConsumePriority",0)))
		for unit: Dictionary in units:
			var available: int = _available_item(staged,ctx,int(unit.ClassID))
			var take: int = mini(amount,available)
			if take > 0:
				var error: String = _debit_item(int(unit.ClassID),take,staged,ctx)
				if not error.is_empty(): return error
				amount -= take
			if amount == 0: return ""
		return "재화 부족"
	if str(cost.get("kind","")) != "item": return "알 수 없는 비용 종류"
	if cost.has("instance_id"):
		if not cost.instance_id is String or str(cost.instance_id).is_empty(): return "비용 개체 ID 오류"
		if cost.has("expected_quantity") and not _integer(cost.expected_quantity,1): return "비용 개체 수량 오류"
		return _debit_item(id,amount,staged,ctx,str(cost.instance_id),int(cost.get("expected_quantity",-1)))
	return _debit_item(id,amount,staged,ctx)

func _debit_item(id: int, amount: int, staged: Dictionary, ctx: Dictionary, instance_id: String = "", expected_quantity: int = -1) -> String:
	var eligibility: Dictionary = source.item_eligibility(id,ctx)
	if not bool(eligibility.get("ok",false)): return str(eligibility.get("error","비용 아이템 사용 제한"))
	var pending: int = amount
	for uid: String in staged.item_instances.keys():
		if not instance_id.is_empty() and uid != instance_id: continue
		var item: Dictionary = staged.item_instances[uid]
		if native_id(item.get("record",{})) != id: continue
		if not ctx.instances.has(uid): continue
		var normalized: Dictionary = ctx.instances[uid]
		if bool(normalized.get("locked",false)) or bool(normalized.get("equipped",false)) or bool(item.get("sealed",false)): continue
		var record: Dictionary = item.get("record",{})
		var quantity: int = _quantity(item)
		if quantity <= 0: return "원본 아이템 수량 오류"
		if expected_quantity >= 0 and quantity != expected_quantity: return "비용 개체 수량이 변경되었습니다"
		if not instance_id.is_empty() and quantity < amount: return "지정한 비용 개체 수량 부족"
		var take: int = mini(pending,quantity)
		var name_value: String = str(item.get("name",""))
		if int(staged.inventory.get(name_value,0)) < take: return "개체·가방 수량 불일치"
		if item.has("quest_reward_receipt"):
			var owner_error: String = _stage_owned_debit(uid,take,staged)
			if not owner_error.is_empty(): return owner_error
			pending -= take
			if pending == 0: return ""
			continue
		staged.inventory[name_value] = int(staged.inventory[name_value])-take
		if int(staged.inventory[name_value]) == 0: staged.inventory.erase(name_value)
		if take == quantity: staged.item_instances.erase(uid)
		else:
			item["source_reward_quantity"] = quantity-take
			item.record["source_reward_quantity"] = quantity-take
			staged.item_instances[uid] = item
		pending -= take
		if pending == 0: return ""
	if not instance_id.is_empty(): return "지정한 원본 개체를 사용할 수 없습니다"
	for name_value: String in ctx.get("stacks",{}):
		var stack: Dictionary = ctx.stacks[name_value]
		if int(stack.sourceID) != id or bool(stack.get("locked",false)): continue
		var available: int = maxi(0,int(staged.inventory.get(name_value,0))-_physical_named(staged.item_instances,name_value))
		var take: int = mini(pending,available)
		if take <= 0: continue
		staged.inventory[name_value] = int(staged.inventory[name_value])-take
		if int(staged.inventory[name_value]) == 0: staged.inventory.erase(name_value)
		pending -= take
		if pending == 0: return ""
	return "정확한 원본 ID의 사용 가능한 보유 아이템 부족"

func _reward(reward: Dictionary, staged: Dictionary, next: Dictionary, ctx: Dictionary) -> String:
	var amount: int = int(reward.get("amount",0)); var id: int = int(reward.get("id",0))
	if not _integer(reward.get("amount"),1) or amount > 1000000000000: return "보상 수량 범위 오류"
	match str(reward.get("kind","")):
		"item": return stage_item(staged,id,amount,int(reward.get("enchant",0)),int(reward.get("bless_code",1)))
		"currency":
			if id == 1: staged.gold = int(staged.gold)+amount; return ""
			for row: Dictionary in source.rows("CurrencyUnitClass"):
				if int(row.get("CurrencyID",0)) == id and int(row.get("UnitID",0)) == 4 and bool(row.get("ForGive",false)): return stage_item(staged,int(row.ClassID),amount)
			return "지원하지 않는 재화 보상"
		"blessing":
			staged.ainhasad_state.blessing = mini(999999,int(staged.ainhasad_state.get("blessing",0))+amount); return ""
		"experience":
			staged.experience = int(staged.experience)+amount
			var loop_count: int = 0
			while staged.experience >= staged.exp_need and loop_count < 150:
				staged.experience -= int(staged.exp_need); staged.level += 1; staged.stat_points += 1
				staged.exp_need = world.EXP_PROGRESSION.required_for_level(int(staged.level),int(staged.exp_need)); loop_count += 1
			return "" if loop_count < 150 else "경험치 보상 상한 오류"
		"pass_exp":
			if not domains.has("events") or not domains.events.has_method("add_pass_exp"): return "패스 경험치 소비자 연결 확인 필요"
			var updated: Dictionary = domains.events.add_pass_exp(next.domains.events,id,amount,ctx)
			if not bool(updated.get("ok",false)): return str(updated.get("error","패스 경험치 오류"))
			next.domains.events = updated.state; return ""
		"bonus":
			if source.row("Bonus",id).is_empty(): return "보너스 원본 누락"
			var pass_id: int = int(reward.get("pass_id",0))
			var expires: int = int(reward.get("expires_at",0))
			var origin: int = int(reward.get("source_reward_id",0))
			if amount != 1 or pass_id <= 0 or expires <= effective_now() or origin <= 0: return "보너스 수령·만료 근거 오류"
			var receipt: String = "%d:%d:%d" % [pass_id,origin,id]
			for prior: Dictionary in next.bonus_rewards:
				if str(prior.get("receipt_id","%d:%d:%d" % [int(prior.get("pass_id",0)),int(prior.get("source_reward_id",0)),int(prior.get("id",0))])) == receipt: return "이미 수령한 보너스"
			next.bonus_rewards.append({"id":id,"expires_at":expires,"pass_id":pass_id,"source_reward_id":origin,"receipt_id":receipt}); return ""
	return "보상 소비자 미연결 · 원본 소유·청구 상태 보존"

func stage_item(staged: Dictionary, id: int, amount: int, enchant: int = 0, bless_code: int = 1) -> String:
	if amount <= 0 or amount > 1000000000 or enchant < 0 or bless_code not in [1,2,3]: return "아이템 보상 범위 오류"
	var item: Dictionary = source.row("ItemClass",id)
	if item.is_empty(): return "아이템 원본 ID 누락"
	var eligibility: Dictionary = source.item_eligibility(id,{"now":effective_now(),"nowUnix":effective_now(),"level":int(staged.get("level",world.level)),"service_region":"KR","time_policy":_time_policy()})
	if not bool(eligibility.get("ok",false)): return str(eligibility.get("error","아이템 보상 제한"))
	var life: Dictionary = _item_life(id)
	if not str(life.get("error","")).is_empty(): return str(life.error)
	var issued_at: int = effective_now()
	var label: String = "%s [523:%d]" % [str(item.get("Name","아이템")),id]
	var grade_names: Dictionary = {1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",6:"신화",7:"유일"}
	var maximum: int = maxi(1,int(item.get("MaxStackAmount",1)))
	var count: int = ceili(float(amount)/float(maximum))
	if count > 10000: return "물리 아이템 보상 개수 상한"
	var remaining: int = amount
	for _index: int in range(count):
		var quantity: int = mini(maximum,remaining)
		remaining -= quantity
		var record: Dictionary = {"name":label,"type":"원본 아이템","slot":"","grade":grade_names.get(int(item.get("GradeID",1)),"일반"),"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:%d" % id,"source_item_class_id":id,"source_reward_quantity":quantity,"source_original_item":item.duplicate(true),"source_bless_code":bless_code,"desc":"원본523 보상 · 효과 연결은 콘텐츠별로 확인됩니다"}
		var uid: String = str(int(staged.next_item_instance_id))
		while staged.item_instances.has(uid): staged.next_item_instance_id += 1; uid = str(int(staged.next_item_instance_id))
		staged.next_item_instance_id += 1
		staged.inventory[label] = int(staged.inventory.get(label,0))+quantity
		staged.item_instances[uid] = {"name":label,"level":enchant,"record":record,"source_reward_quantity":quantity,"bless_code":bless_code,"blessed":bless_code==2,"bless_state":"blessed" if bless_code==2 else "normal"}
		if int(life.seconds) > 0:
			for scope: Dictionary in [record,staged.item_instances[uid]]:
				scope["issued_at"] = issued_at
				scope["expires_at"] = issued_at+int(life.seconds)
				scope["source_life_seconds"] = int(life.seconds)
	return ""

func _item_life(id: int) -> Dictionary:
	var links: Array = source.find_rows("ItemBonus","ItemClassID",id) if source.has_method("find_rows") else source.rows("ItemBonus")
	var seconds: int = 0
	for link: Dictionary in links:
		if int(link.get("ItemClassID",0)) != id: continue
		var bonus_row: Dictionary = source.row("Bonus",int(link.get("BonusID",0)))
		if int(bonus_row.get("BonusTypeID",0)) != 422: continue
		var type_row: Dictionary = source.row("BonusType",422)
		if seconds != 0 or str(type_row.get("Name","")) != "Life" or int(type_row.get("UnitID",0)) != 17 or not _integer(bonus_row.get("Value"),1) or int(bonus_row.Value) > 2147483647 or int(bonus_row.get("BonusApplicationTypeID",0)) != 0 or int(bonus_row.get("BonusApplicationTargetID",0)) != 0: return {"error":"원본 아이템 수명 단위·기간 확인 필요"}
		seconds = int(bonus_row.Value)
	return {"seconds":seconds}

func record_event(kind: String, payload: Dictionary = {}) -> void:
	if save_blocked or not source.ready() or not _source_configured: return
	var raw_event_id: String = str(payload.get("event_id",""))
	var event_id: String = _event_nonce + ":" + raw_event_id
	# Only authoritative host occurrences, with stable per-life IDs, earn credit.
	if raw_event_id.is_empty() or event_id.length() > 160 or state.get("event_receipts",{}).has(event_id): return
	if kind == "kill" and not bool(payload.get("player_credit",false)): return
	if not _integer(payload.get("amount",1),1): return
	if not state.has("event_receipts"): state.event_receipts = {}
	state.event_receipts[event_id] = true
	if state.event_receipts.size() > 8192:
		# Transaction receipts must survive the bounded live-event replay window.
		var live_receipts: Array = []
		for old_id: String in state.event_receipts:
			if not old_id.begins_with("source_grant:"): live_receipts.append(old_id)
		for index: int in range(maxi(0,live_receipts.size()-8192)): state.event_receipts.erase(live_receipts[index])
	var amount: int = int(payload.get("amount",1))
	state.event_counters[kind] = int(state.event_counters.get(kind,0))+amount
	var source_id: int = int(payload.get("source_id",0))
	if source_id > 0:
		var counter_key: String = "%s:%d" % [kind,source_id]
		state.event_counters[counter_key] = int(state.event_counters.get(counter_key,0))+amount
	if kind in ["kill","item_use","territory_enter","npc_transform","npc_hp","player_death","map_change"] and domains.has("challenge") and domains.challenge.has_method("event"):
		var event: Dictionary = payload.duplicate(true)
		event.kind = kind
		event.event_id = event_id
		if not event.has("npc_id"): event.npc_id = source_id
		var response: Dictionary = domains.challenge.event(event,context(),state.domains.challenge)
		if bool(response.get("ok",false)): state.domains.challenge = response.state
	if domains.has("events") and domains.events.has_method("event"):
		var event: Dictionary = payload.duplicate(true)
		event.kind = kind
		event.event_id = event_id
		var response: Dictionary = domains.events.event(event,context(),state.domains.events)
		if bool(response.get("ok",false)): state.domains.events = response.state
	state.revision = int(state.revision)+1

func rebuild() -> void:
	totals.clear(); effect_details.clear(); conditional_totals = {"undead":{},"pvp":{}}
	if world == null or not source.ready() or not _source_configured: return
	if domains.has("jade_grail") and state.domains.has("jade_grail"):
		effect_details = domains.jade_grail.bonuses(context(),state.domains.jade_grail)
		var mapping: Dictionary = {"melee_damage":"melee_damage:flat","ranged_damage":"ranged_damage:flat","magic_damage":"magic_damage:flat","melee_accuracy":"melee_hit:flat","ranged_accuracy":"ranged_hit:flat","magic_accuracy":"magic_hit:flat","armor_class":"ac:flat","max_hp":"max_hp:flat","exp_bonus_pct":"experience_bonus:percent","damage_reduction":"damage_reduction:flat","pve_damage_reduction":"pve_damage_reduction:flat","move_speed_bonus":"movement_speed:percent","attack_speed_bonus":"attack_speed:percent","hp_potion_recovery_pct":"potion_percent:percent","cast_speed_bonus":"cast_speed:percent","damage_reduction_ignore":"damage_reduction_ignore:flat","ignore_melee_damage_reduction_pct":"ignore_melee_damage_reduction:percent","ignore_ranged_damage_reduction_pct":"ignore_ranged_damage_reduction:percent","ignore_magic_damage_reduction_pct":"ignore_magic_damage_reduction:percent"}
		for key: String in effect_details.get("stats",{}):
			var canonical: String = str(mapping.get(key,key))
			var value: float = float(effect_details.stats[key])
			if key == "armor_class": value = -value
			totals[canonical] = float(totals.get(canonical,0))+value
		var scoped_mapping: Dictionary = {"undead_additional_max_damage":"undead_additional_max_damage:flat","pvp_damage_reduction_pct":"pvp_damage_reduction:percent","pvp_damage_reduction_ignore_pct":"pvp_damage_reduction_ignore:percent"}
		for scope: String in conditional_totals:
			for key: String in effect_details.get("conditional_stats",{}).get(scope,{}):
				conditional_totals[scope][str(scoped_mapping.get(key,key))] = float(effect_details.conditional_stats[scope][key])
	var ids: Array = []
	for reward: Dictionary in state.get("bonus_rewards",[]):
		if int(reward.get("expires_at",0)) == 0 or int(reward.expires_at) > effective_now(): ids.append(int(reward.id))
	if not ids.is_empty():
		var earned: Dictionary = source.bonus_stats(ids,context())
		for key: String in earned.get("stats",{}): totals[key] = float(totals.get(key,0))+float(earned.stats[key])
		for scope: String in conditional_totals:
			for key: String in earned.get("conditional_stats",{}).get(scope,{}):
				conditional_totals[scope][key] = float(conditional_totals[scope].get(key,0))+float(earned.conditional_stats[scope][key])
		# Earned pass effects need the same raw evidence as possessed grail effects.
		effect_details["earned"] = earned.duplicate(true)
	effect_details["combat_policy"] = {"percent":policy.get("conditional_percent_mode","disabled"),"undead":policy.get("undead_damage_mode","disabled"),"percent_semantics":"TWILIGHT_estimate_percentage_point_budget","undead_semantics":"TWILIGHT_estimate_physical_uniform_1_to_source_max"}
	if world.ain_service != null:
		var jade: Dictionary = state.domains.get("jade_grail",{}).get("jade",{})
		var matches_timer: bool = not jade.is_empty() and int(jade.get("used_at",0))+int(jade.get("duration",0)) == int(world.ain_service.dragon_orb_expires_at)
		world.ain_service.source_jade_level_override = int(jade_status().get("protection_level",0)) if matches_timer else -1

func jade_status() -> Dictionary:
	return domains.jade_grail.jade_status(context(),state.domains.jade_grail) if source.ready() and domains.has("jade_grail") else {}

func bonus(key: String) -> float:
	return float(totals.get(key,0))

func combat_context(kind: String, target_context: Dictionary = {}) -> Dictionary:
	# These APIs consume explicit engine flags, never names or inferred PvP status.
	var result: Dictionary = {"percent_ignore":0.0,"pvp_reduction_percent":0.0,"undead_max_damage":0,"policy":policy.get("conditional_percent_mode","disabled"),"undead_policy":policy.get("undead_damage_mode","disabled")}
	if kind not in ["melee","ranged","magic"]: return result
	if str(policy.get("conditional_percent_mode","disabled")) == "percentage_points_estimate":
		result.percent_ignore = maxf(0,bonus("ignore_%s_damage_reduction:percent" % kind))
		if target_context.get("pvp") == true:
			result.percent_ignore += maxf(0,float(conditional_totals.pvp.get("pvp_damage_reduction_ignore:percent",0)))
			result.pvp_reduction_percent = clampf(float(conditional_totals.pvp.get("pvp_damage_reduction:percent",0)),0,100)
	if target_context.get("undead") == true and kind in ["melee","ranged"] and str(policy.get("undead_damage_mode","disabled")) == "uniform_1_to_max_estimate":
		result.undead_max_damage = maxi(0,int(conditional_totals.undead.get("undead_additional_max_damage:flat",0)))
	return result

func outgoing_context(kind: String, hit_context: Dictionary) -> Dictionary:
	var result: Dictionary = hit_context.duplicate(true)
	var scoped: Dictionary = combat_context(kind,hit_context)
	var budget: float = maxf(0,float(hit_context.get("percent_reduction",0)))
	# The existing guardian consumer applies this budget once. A separate final
	# damage multiplier here would count the target's reduction twice.
	result.percent_reduction = maxf(0,budget-float(scoped.percent_ignore))
	result.source523_percent_ignore = minf(budget,float(scoped.percent_ignore))
	return result

func incoming_damage(amount: int, kind: String, attacker_context: Dictionary) -> int:
	if amount <= 0: return amount
	var scoped: Dictionary = combat_context(kind,attacker_context)
	return maxi(1,int(round(float(amount)*(1.0-float(scoped.pvp_reduction_percent)/100.0))))

func stat_record() -> Dictionary:
	var result: Dictionary = StatAdapter.record(totals)
	result["def"] = -bonus("ac:flat")
	return result

func catalog_bonus(key: String) -> int:
	var mapping: Dictionary = {"potionHealFlat":"potion_flat:flat","potionHealPct":"potion_percent:percent","castSpeed":"cast_speed:percent","damage_reduction_ignore":"damage_reduction_ignore:flat"}
	if mapping.has(key): return int(bonus(str(mapping[key])))
	return StatAdapter.catalog_bonus(totals,key)

func try_use(item_name: String) -> bool:
	if not source.ready(): return false
	var ctx: Dictionary = context()
	for item_id: String in ctx.owned:
		var id: int = int(item_id)
		var matches: bool = false
		for physical: Dictionary in ctx.instances.values():
			matches = matches or (int(physical.sourceID) == id and str(physical.get("name","")) == item_name)
		if ctx.stacks.has(item_name): matches = matches or int(ctx.stacks[item_name].sourceID) == id
		if not matches: continue
		var category: int = int(source.row("ItemClass",id).get("CategoryID",0))
		if category not in [10291,10622,78,10381,10394]: return false
		request_presentation("jade_grail" if category in [10291,10622] else "events",{"item_id":id})
		# The item belongs to this consumer even while the original UI is absent.
		# Falling through could consume it through an unrelated item handler.
		return true
	return false

func _available_item(staged: Dictionary, ctx: Dictionary, id: int) -> int:
	var amount: int = 0
	for uid: String in staged.item_instances:
		var physical: Dictionary = staged.item_instances[uid]
		if not ctx.instances.has(uid): continue
		var normalized: Dictionary = ctx.instances[uid]
		if native_id(physical.get("record",{})) == id and not bool(normalized.get("locked",false)) and not bool(normalized.get("equipped",false)) and not bool(physical.get("sealed",false)):
			amount += _quantity(physical)
	for name_value: String in ctx.get("stacks",{}):
		var stack: Dictionary = ctx.stacks[name_value]
		if int(stack.sourceID) == id and not bool(stack.get("locked",false)):
			amount += maxi(0,int(staged.inventory.get(name_value,0))-_physical_named(staged.item_instances,name_value))
	return amount

static func _physical_named(instances: Dictionary, name_value: String) -> int:
	var amount: int = 0
	for physical: Dictionary in instances.values():
		if str(physical.get("name","")) == name_value: amount += _quantity(physical)
	return amount

static func _owned_in(instances: Dictionary, id: int) -> int:
	var total: int = 0
	for item: Dictionary in instances.values():
		if native_id(item.get("record",{})) == id: total += int(item.get("source_reward_quantity",item.get("record",{}).get("source_reward_quantity",1)))
	return total

func _empty_progress(value: Dictionary) -> bool:
	for key: String in value.domains:
		if not domains.has(key): return false
		var saved: Dictionary = value.domains[key]
		var initial: Dictionary = domains[key].initial_state()
		# The public pre-final-reward namespace predates this optional empty map.
		# Compare an isolated default; never rewrite the owned saved dictionary.
		if key == "events" and not saved.has("final_progress") and initial.get("final_progress") is Dictionary and initial.final_progress.is_empty():
			saved = saved.duplicate(true)
			saved.final_progress = {}
		if not _same_progress(saved,initial): return false
	return value.event_counters.is_empty() and value.get("bonus_rewards",[]).is_empty() and value.get("event_receipts",{}).is_empty()

static func _integer(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum

static func _fail(error: String) -> Dictionary:
	return {"ok":false,"error":error}

static func _physical_expired(physical: Dictionary, clock: int) -> bool:
	for scope: Dictionary in [physical,physical.get("record",{})]:
		for field: String in ["expires_at","expiration","expiresAt"]:
			if not scope.has(field): continue
			var stamp: Variant = scope[field]
			# No conversion of ambiguous strings or unsupported clock formats.
			if not _integer(stamp,0): return true
			if int(stamp) > 0 and int(stamp) <= clock: return true
	return false

func _time_policy() -> Dictionary:
	# One TWILIGHT calendar: Korea time (UTC+9), daily reset at 05:00, the same
	# boundary as quests, the monster book and dungeons (QuestCalendar.korean_daily_key).
	# Source datetimes are Korean local time, so they are read with +540 too.
	# user://twilight-policy time_policy overrides still apply.
	var result: Dictionary = {"utc_offset_minutes":540,"attendance_reset_hour":5}
	result.merge(time_policy,true)
	return result

func _load_policy_file() -> void:
	if not FileAccess.file_exists(POLICY_PATH): return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(POLICY_PATH)) != OK:
		policy_problem = "TWILIGHT 설정 파일 오류 · 안전한 기본 설정 유지"
		return
	var result: Dictionary = apply_policy_config(parser.data)
	policy_problem = "" if bool(result.get("ok",false)) else str(result.get("error","설정 오류"))

func apply_policy_config(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("policy",{}) is Dictionary or not value.get("time_policy",{}) is Dictionary: return _fail("TWILIGHT 설정 구조 오류")
	var staged_policy: Dictionary = policy.duplicate(true)
	var staged_time: Dictionary = time_policy.duplicate(true)
	for key: Variant in value.get("policy",{}):
		var setting: Variant = value.policy[key]
		match str(key):
			"luckybag_random_mode":
				if setting not in ["source_weights","strict_10000000"]: return _fail("상자 가중치 설정 오류")
			"random_reward_weight_mode":
				if setting not in ["equal_estimate","disabled"]: return _fail("무작위 보상 추정 설정 오류")
			"attendance_blessing_base":
				if not _integer(setting,1) or int(setting) > 999999: return _fail("출석 축복 기본량 범위 오류")
			"conditional_percent_mode":
				if setting not in ["percentage_points_estimate","disabled"]: return _fail("조건부 비율 전투 정책 오류")
			"undead_damage_mode":
				if setting not in ["uniform_1_to_max_estimate","disabled"]: return _fail("언데드 추가 대미지 정책 오류")
			"luckybag_final_scope":
				if setting != "source_item": return _fail("상자 확정 보상 이력 범위 오류")
			"luckybag_final_completion":
				if setting not in ["once","cycle"]: return _fail("상자 확정 보상 완료 정책 오류")
			"luckybag_final_rules":
				if not setting is Dictionary: return _fail("상자 확정 보상 설정 오류")
				for bag: Variant in setting:
					if not bag is String or not str(bag).is_valid_int() or int(str(bag)) <= 0 or not setting[bag] is Dictionary: return _fail("상자 확정 보상 풀 오류")
					var rule: Dictionary = setting[bag]
					if not _integer(rule.get("uses"),1) or int(rule.uses) > 100000: return _fail("상자 확정 보상 사용 횟수 오류")
					for field: Variant in rule:
						match str(field):
							"uses": pass
							"completion":
								if rule[field] not in ["once","cycle"]: return _fail("상자 확정 보상 완료 정책 오류")
							"scope":
								if rule[field] != "source_item": return _fail("상자 확정 보상 이력 범위 오류")
							"final_rewards":
								if rule[field] != "all": return _fail("상자 확정 보상 항목 정책 오류")
							_: return _fail("지원하지 않는 상자 확정 보상 설정")
			"luckybag_selection_counts":
				if not setting is Dictionary: return _fail("상자 선택 수 설정 오류")
				for bag: Variant in setting:
					if not str(bag).is_valid_int() or int(str(bag)) <= 0 or not _integer(setting[bag],1) or int(setting[bag]) > 100: return _fail("상자 선택 수 범위 오류")
			"stack_set_thresholds":
				if not setting is bool: return _fail("성배 세트 정책 오류")
			"protection_dispatch":
				if not setting is Dictionary: return _fail("용옥 보호 정책 오류")
				for subscription: Variant in setting:
					if str(subscription) not in ["1","14"] or not _integer(setting[subscription],1) or int(setting[subscription]) not in [54252,66574,67731]: return _fail("용옥 보호 연결 오류")
			_: return _fail("지원하지 않는 TWILIGHT 설정: " + str(key))
		staged_policy[key] = setting.duplicate(true) if setting is Dictionary or setting is Array else setting
	for key: Variant in value.get("time_policy",{}):
		var setting: Variant = value.time_policy[key]
		if str(key) == "utc_offset_minutes":
			if not _integer(setting,-840) or int(setting) > 840: return _fail("시간대 설정 범위 오류")
		elif str(key) in ["attendance_reset_hour","pass_reset_hour"]:
			if not _integer(setting,0) or int(setting) > 23: return _fail("일일 초기화 설정 범위 오류")
		else: return _fail("지원하지 않는 시간 설정: " + str(key))
		staged_time[key] = int(setting)
	policy = staged_policy
	time_policy = staged_time
	if domains.has("jade_grail"):
		if policy.has("stack_set_thresholds"): domains.jade_grail.stack_set_thresholds = bool(policy.stack_set_thresholds)
		if policy.has("protection_dispatch"):
			var dispatch: Dictionary = {}
			for subscription: Variant in policy.protection_dispatch: dispatch[int(str(subscription))] = int(policy.protection_dispatch[subscription])
			domains.jade_grail.protection_dispatch = dispatch
	return {"ok":true}

static func _same_progress(left: Variant, right: Variant) -> bool:
	# JSON loads every number as float. Default-state checks must preserve value,
	# while still rejecting extra keys or genuine progress when a pack is absent.
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not _same_progress(left[key],right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index: int in range(left.size()):
			if not _same_progress(left[index],right[index]): return false
		return true
	if (left is int or left is float) and (right is int or right is float):
		return is_finite(float(left)) and is_finite(float(right)) and float(left) == float(right)
	return typeof(left) == typeof(right) and left == right
