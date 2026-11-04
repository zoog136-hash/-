extends RefCounted
## One existing World save owns costs, rewards, event progress and durable RNG.
const Source = preload("res://scripts/unconfirmed523/source523.gd")
const StatAdapter = preload("res://scripts/collections/equipment_collection_stats.gd")
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
var _expiry_signature: String = ""
var _event_nonce: String = Crypto.new().generate_random_bytes(12).hex_encode()
var _last_survival_tick: String = ""
var time_policy: Dictionary = {}
var _source_configured: bool = false
var policy_problem: String = ""
const POLICY_PATH: String = "res://data/unconfirmed523/twilight_policy.json"
var test_now: int = 0
var policy: Dictionary = {"luckybag_random_mode":"source_weights", "random_reward_weight_mode":"equal_estimate", "attendance_blessing_base":200}

func configure(host: Node) -> void:
	world = host
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
	for reward: Dictionary in state.get("bonus_rewards",[]):
		signature += ":" + str(int(reward.get("expires_at",0)) == 0 or int(reward.expires_at) > effective_now())
	if signature != _expiry_signature:
		_expiry_signature = signature
		rebuild()
		if world.has_method("_invalidate_equipment_static"): world._invalidate_equipment_static()

func now() -> int:
	return test_now if test_now > 0 else int(Time.get_unix_time_from_system())

func context() -> Dictionary:
	var ctx: Dictionary = {"nowUnix":now(),"now":now(),"level":int(world.level),"max_level":int(world.level),"max_level_basis":"local_monotonic_level","class_id":int(world.BASE508.source_class_id(str(world.job_class))),"region":"KR","service_region":"KR","world_no":1,"map_id":str(world.active_map_id),"owned":{},"currencies":{"1":int(world.gold)},"instances":{},"equipped":{},"ain":world.ain_service.export_state(),"event_counters":state.event_counters.duplicate(true),"completed_quests":{},"pass_exp":{},"twilight_policy":policy.duplicate(true),"time_policy":_time_policy()}
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
		ctx.stacks[item_name] = {"sourceID":sid,"quantity":remainder,"record":record.duplicate(true),"locked":bool(world.ui_preferences.get("item_locks",{}).get(item_name,false))}
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
	return JSON.stringify([world.inventory,world.item_instances,world.gold,world.level,world.experience,world.exp_need,world.stat_points,world.equipped_items,world.ui_preferences.get("item_locks",{}),world.ain_service.export_state(),state.revision]).sha256_text()

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
	var staged: Dictionary = {"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"gold":int(world.gold),"ainhasad_state":proposal.get("ain",world.ain_service.export_state()).duplicate(true),"experience":int(world.experience),"level":int(world.level),"exp_need":int(world.exp_need),"stat_points":int(world.stat_points),"next_item_instance_id":int(world.next_item_instance_id)}
	var failure: String = ""
	for cost: Dictionary in proposal.get("costs",[]):
		failure = _cost(cost,staged,ctx)
		if not failure.is_empty(): break
	if failure.is_empty():
		for reward: Dictionary in proposal.get("rewards",[]):
			failure = _reward(reward,staged,next,ctx)
			if not failure.is_empty(): break
	if failure.is_empty() and key == "challenge" and str(request.get("op","")) == "challenge_claim" and domains.has("events") and domains.events.has_method("event"):
		var challenge_id: int = int(state.domains.challenge.get("active",{}).get("challenge_id",request.get("challenge_id",0)))
		var event: Dictionary = {"kind":"challenge_complete","source_id":challenge_id,"amount":1,"event_id":"challenge_claim:%d" % int(next.revision)}
		var progressed: Dictionary = domains.events.event(event,ctx,next.domains.events)
		if bool(progressed.get("ok",false)): next.domains.events = progressed.state
	if failure.is_empty(): failure = validate(next)
	if not failure.is_empty(): busy = false; return _fail(failure)
	staged[SAVE_KEY] = next
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
	state = next
	busy = false
	rebuild()
	world._update_hud()
	world.hud.refresh_inventory(world.inventory)
	return {"ok":true,"revision":state.revision,"rewards":proposal.get("rewards",[]),"assumptions":proposal.get("assumptions",[])}

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
	return _debit_item(id,amount,staged,ctx)

func _debit_item(id: int, amount: int, staged: Dictionary, ctx: Dictionary) -> String:
	var eligibility: Dictionary = source.item_eligibility(id,ctx)
	if not bool(eligibility.get("ok",false)): return str(eligibility.get("error","비용 아이템 사용 제한"))
	var pending: int = amount
	for uid: String in staged.item_instances.keys():
		var item: Dictionary = staged.item_instances[uid]
		if native_id(item.get("record",{})) != id: continue
		if not ctx.instances.has(uid): continue
		var normalized: Dictionary = ctx.instances[uid]
		if bool(normalized.get("locked",false)) or bool(normalized.get("equipped",false)) or bool(item.get("sealed",false)): continue
		var record: Dictionary = item.get("record",{})
		var quantity: int = _quantity(item)
		if quantity <= 0: return "원본 아이템 수량 오류"
		var take: int = mini(pending,quantity)
		var name_value: String = str(item.get("name",""))
		if int(staged.inventory.get(name_value,0)) < take: return "개체·가방 수량 불일치"
		staged.inventory[name_value] = int(staged.inventory[name_value])-take
		if int(staged.inventory[name_value]) == 0: staged.inventory.erase(name_value)
		if take == quantity: staged.item_instances.erase(uid)
		else:
			item["source_reward_quantity"] = quantity-take
			item.record["source_reward_quantity"] = quantity-take
			staged.item_instances[uid] = item
		pending -= take
		if pending == 0: return ""
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
			var updated: Dictionary = domains.events.add_pass_exp(next.domains.events,id,amount)
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
	var eligibility: Dictionary = source.item_eligibility(id,{"now":now(),"nowUnix":now(),"level":int(staged.get("level",world.level)),"service_region":"KR","time_policy":_time_policy()})
	if not bool(eligibility.get("ok",false)): return str(eligibility.get("error","아이템 보상 제한"))
	var label: String = "%s [523:%d]" % [str(item.get("Name","아이템")),id]
	var grade_names: Dictionary = {1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",6:"신화",7:"유일"}
	var per_copy: bool = int(item.get("MaxStackAmount",1)) <= 1
	if per_copy and amount > 10000: return "물리 아이템 보상 개수 상한"
	var count: int = amount if per_copy else 1
	for _index: int in range(count):
		var quantity: int = 1 if per_copy else amount
		var record: Dictionary = {"name":label,"type":"원본 아이템","slot":"","grade":grade_names.get(int(item.get("GradeID",1)),"일반"),"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:%d" % id,"source_item_class_id":id,"source_reward_quantity":quantity,"source_original_item":item.duplicate(true),"source_bless_code":bless_code,"desc":"원본523 보상 · 효과 연결은 콘텐츠별로 확인됩니다"}
		var uid: String = str(int(staged.next_item_instance_id))
		while staged.item_instances.has(uid): staged.next_item_instance_id += 1; uid = str(int(staged.next_item_instance_id))
		staged.next_item_instance_id += 1
		staged.inventory[label] = int(staged.inventory.get(label,0))+quantity
		staged.item_instances[uid] = {"name":label,"level":enchant,"record":record,"source_reward_quantity":quantity,"bless_code":bless_code,"blessed":bless_code==2,"bless_state":"blessed" if bless_code==2 else "normal"}
	return ""

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
	if state.event_receipts.size() > 8192: state.event_receipts.erase(state.event_receipts.keys()[0])
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
	totals.clear(); effect_details.clear()
	if world == null or not source.ready() or not _source_configured: return
	if domains.has("jade_grail") and state.domains.has("jade_grail"):
		effect_details = domains.jade_grail.bonuses(context(),state.domains.jade_grail)
		var mapping: Dictionary = {"melee_damage":"melee_damage:flat","ranged_damage":"ranged_damage:flat","magic_damage":"magic_damage:flat","melee_accuracy":"melee_hit:flat","ranged_accuracy":"ranged_hit:flat","magic_accuracy":"magic_hit:flat","armor_class":"ac:flat","max_hp":"max_hp:flat","exp_bonus_pct":"experience_bonus:percent","damage_reduction":"damage_reduction:flat","pve_damage_reduction":"pve_damage_reduction:flat","move_speed_bonus":"movement_speed:percent","attack_speed_bonus":"attack_speed:percent","hp_potion_recovery_pct":"potion_percent:percent","cast_speed_bonus":"cast_speed:percent","damage_reduction_ignore":"damage_reduction_ignore:flat","ignore_melee_damage_reduction_pct":"ignore_melee_damage_reduction:percent","ignore_ranged_damage_reduction_pct":"ignore_ranged_damage_reduction:percent","ignore_magic_damage_reduction_pct":"ignore_magic_damage_reduction:percent"}
		for key: String in effect_details.get("stats",{}):
			if key in ["ignore_melee_damage_reduction_pct","ignore_ranged_damage_reduction_pct","ignore_magic_damage_reduction_pct"]:
				for effect: Dictionary in effect_details.get("effects",[]):
					if str(effect.get("key","")) == key:
						effect.applied = false
						effect.reason = "unsupported_combat_consumer"
						effect_details.unsupported.append(effect.duplicate(true))
				continue
			var canonical: String = str(mapping.get(key,key))
			var value: float = float(effect_details.stats[key])
			if key == "armor_class": value = -value
			totals[canonical] = float(totals.get(canonical,0))+value
	var ids: Array = []
	for reward: Dictionary in state.get("bonus_rewards",[]):
		if int(reward.get("expires_at",0)) == 0 or int(reward.expires_at) > effective_now(): ids.append(int(reward.id))
	if not ids.is_empty():
		var earned: Dictionary = source.bonus_stats(ids,context())
		for key: String in earned.get("stats",{}): totals[key] = float(totals.get(key,0))+float(earned.stats[key])
	if world.ain_service != null:
		var jade: Dictionary = state.domains.get("jade_grail",{}).get("jade",{})
		var matches_timer: bool = not jade.is_empty() and int(jade.get("used_at",0))+int(jade.get("duration",0)) == int(world.ain_service.dragon_orb_expires_at)
		world.ain_service.source_jade_level_override = int(jade_status().get("protection_level",0)) if matches_timer else -1

func jade_status() -> Dictionary:
	return domains.jade_grail.jade_status(context(),state.domains.jade_grail) if source.ready() and domains.has("jade_grail") else {}

func bonus(key: String) -> float:
	return float(totals.get(key,0))

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
		world.hud.open_unconfirmed523("jade_grail" if category in [10291,10622] else "events")
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
		if not domains.has(key) or not _same_progress(value.domains[key],domains[key].initial_state()): return false
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
	var result: Dictionary = {"utc_offset_minutes":int(Time.get_time_zone_from_system().get("bias",0)),"attendance_reset_hour":0}
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
