extends "res://scripts/expedition/legacy_runtime.gd"
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")

const REWARD_BRIDGE=preload("res://scripts/expedition/reward_bridge.gd")
const REWARD_CARDS=preload("res://scripts/expedition/reward_cards.gd")
const DISPATCH=preload("res://scripts/expedition/dispatch_rules.gd")
const MODEL = preload("res://scripts/expedition/estimated_simulation.gd")
var random = RandomNumberGenerator.new()
var clock: Callable
var migration_backup_pending: bool = false
var last_error: String = ""
var reward_item_provider: Variant = null # Optional shared native-item adapter; defaults to the host loader.
var reward_recipients:Dictionary={} # Optional actual consumer instances; never serialized.

func _init() -> void:
	random.randomize()
	state = fresh_estimate()

static func fresh_estimate() -> Dictionary:
	return {"version": 2, "source_sha256": SOURCE.SOURCE_SHA256, "revision": 0, "jobs": [], "attempts": {}, "day": 0, "rng_state": "", "storage": {}, "issued": {}, "receipts": {}, "local_diamonds":0}

func now() -> int:
	return int(clock.call()) if clock.is_valid() else int(Time.get_unix_time_from_system())

func today() -> int:
	var p := MODEL.policy()
	return floori((float(now())+float(p.daily_reset_utc_offset_minutes)*60.0-float(p.daily_reset_hour_utc)*3600.0)/86400.0)

func rules_view() -> Dictionary:
	return MODEL.policy()

func _rng_text(value: Variant) -> bool:
	return value is String and (value.is_empty() or (value.is_valid_int() and str(int(value)) == value))

func _valid_loot(loot: Variant) -> bool:
	if not loot is Dictionary or loot.size() > 1000: return false
	for k in loot:
		if not k is String: return false
		var parts: PackedStringArray = k.split(":")
		if parts.size() != 3: return false
		for p in parts:
			if not p.is_valid_int() or str(int(p)) != p or int(p) < 0: return false
		if int(parts[0]) < 1 or not integer(loot[k]) or int(loot[k]) < 1 or int(loot[k]) > 1000000000: return false
	return true

func validate(v: Variant) -> String:
	if v is Dictionary and v.get("version") == 1: return super.validate(v)
	if not v is Dictionary or v.get("version") != 2 or v.get("source_sha256") != SOURCE.SOURCE_SHA256: return "탐험 추정 규칙 저장 버전 오류"
	for field in ["revision", "day"]:
		if not integer(v.get(field)) or v[field] < 0 or v[field] >= MAX_INTEGER: return "탐험 저장 정수 오류"
	if not v.get("jobs") is Array or v.jobs.size() > 15 or not v.get("attempts") is Dictionary or not _rng_text(v.get("rng_state")) or not _valid_loot(v.get("storage")) or v.storage.size() > 75 or not v.get("issued") is Dictionary or not v.get("receipts") is Dictionary: return "탐험 저장 구조 오류"
	for k in v.attempts:
		if k not in ["1", "2", "98"] or not integer(v.attempts[k]) or v.attempts[k] < 0 or v.attempts[k] > 15: return "탐험 일일 횟수 오류"
	if not integer(v.get("local_diamonds",0)) or int(v.get("local_diamonds",0))<0 or int(v.get("local_diamonds",0))>1000000000:return "탐험 로컬 다이아 잔액 오류"
	var ids := {}
	var identities := {}
	var spots := {}
	var counts := {}
	for job in v.jobs:
		if not job is Dictionary or not job.get("sim") is Dictionary: return "탐험 시뮬레이션 기록 누락"
		for f in ["id", "spot_id", "group_id", "deck_id", "cost", "duration", "remaining", "completion_reward_id"]:
			if not integer(job.get(f)) or job[f] < 0 or job[f] >= MAX_INTEGER: return "탐험 기록 정수 오류"
		if job.id < 1 or job.id > v.revision or job.spot_id < 1 or job.group_id < 1 or int(job.deck_id) not in [1, 2, 98] or int(job.duration) != 28800 or job.remaining > job.duration or job.completion_reward_id < 1 or job.cost < 1: return "탐험 기록 범위 오류"
		if not job.get("identity") is String or not REWARD_CARDS.identity_shape(job.identity,int(job.deck_id)): return "탐험 카드 ID 오류"
		var parts: PackedStringArray = job.identity.split(":")
		if parts.size() != 4 or not parts[3].is_valid_int() or str(int(parts[3])) != parts[3] or int(parts[3]) < 1: return "탐험 카드 정규형 오류"
		if ids.has(str(int(job.id))) or spots.has(str(int(job.spot_id))) or v.receipts.has(str(int(job.id))): return "탐험 중복/기수령 기록 오류"
		ids[str(int(job.id))] = true; spots[str(int(job.spot_id))] = true
		var members:Variant=job.get("member_ids",[job.identity])
		if not members is Array or members.size()!=(4 if int(job.deck_id)==1 else 1) or job.identity not in members:return "탐험 파견 카드 수 오류"
		for member in members:
			if not member is String or not REWARD_CARDS.identity_shape(member,int(job.deck_id)) or identities.has(member):return "탐험 파견 카드 중복·계열 오류"
			var fields:PackedStringArray=member.split(":")
			if fields.size()!=4 or not fields[3].is_valid_int() or str(int(fields[3]))!=fields[3] or int(fields[3])<1:return "탐험 파견 카드 정규형 오류"
			identities[member]=true
		var deck := str(int(job.deck_id)); counts[deck] = int(counts.get(deck, 0))+1
		if counts[deck] > 5: return "탐험 동시 횟수 오류"
		var s: Dictionary = job.sim
		if not MODEL.valid_policy(s.get("policy")) or not _rng_text(s.get("rng_state")) or str(s.get("rng_state", "")).is_empty() or not _valid_loot(s.get("loot")): return "탐험 규칙·난수·보상 오류"
		for f in ["level", "hp", "max_hp", "elapsed", "next_event", "events", "resurrections", "last_wall"]:
			if not integer(s.get(f)) or s[f] < 0 or s[f] >= MAX_INTEGER: return "탐험 상태 정수 오류"
		if s.level < 1 or s.level > 20 or s.max_hp < 1 or s.hp > s.max_hp or s.elapsed > job.duration or job.remaining != job.duration-s.elapsed or s.next_event <= s.elapsed or s.resurrections > 3 or not s.get("exp") is String or not s.exp.is_valid_int() or str(int(s.exp)) != s.exp or int(s.exp) < 0 or int(s.exp) > 9999999999999: return "탐험 상태 범위 오류"
		if job.has("buff_ids"):
			if not job.buff_ids is Array or job.buff_ids.size() > 3: return "탐험 버프 기록 오류"
			var buff_seen := {}
			for id in job.buff_ids:
				if not integer(id) or id < 1 or buff_seen.has(int(id)): return "탐험 버프 ID 오류"
				buff_seen[int(id)] = true
			for field in ["potion_heal","potion_interval","next_potion"]:
				if not integer(s.get(field)) or s[field] < 0: return "탐험 회복제 저장 오류"
			if s.potion_heal > 1000 or (s.potion_heal > 0 and (s.potion_interval != 900 or s.next_potion <= s.elapsed or int(s.next_potion)%900 != 0)) or (s.potion_heal == 0 and (s.potion_interval != 0 or s.next_potion != 0)): return "탐험 회복제 주기 오류"
		if job.get("status") not in ["running", "dead", "completed"]: return "탐험 상태 오류"
		if (job.status == "dead") != (s.hp == 0) or (job.status == "completed" and job.remaining != 0) or (job.status == "running" and job.remaining == 0): return "탐험 생존·완료 상태 불일치"
	var handoffs:Variant=v.get("native_handoffs",{})
	if not handoffs is Dictionary or handoffs.size()>1000:return "탐험 소비자 연결 기록 오류"
	for name in handoffs:
		if not name is String or name.is_empty() or name.length()>2048 or not handoffs[name] is String or not _valid_loot({handoffs[name]:1}):return "탐험 소비자 연결 정규형 오류"
	for k in v.issued:
		if not _valid_loot({k: 1}) or not v.issued[k] is String or not v.issued[k].ends_with(" (탐험 "+k+")"): return "탐험 인벤토리 연결 오류"
	for k in v.receipts:
		if not k is String or not k.is_valid_int() or str(int(k)) != k or int(k) < 1 or int(k) > v.revision or not v.receipts[k] is Dictionary: return "탐험 수령 영수증 오류"
		var r: Dictionary = v.receipts[k]
		if r.get("job_id") != int(k) or not r.get("aborted") is bool or not integer(r.get("exp")) or r.exp < 0 or r.exp > 9999999999999 or not integer(r.get("claimed_at")) or r.claimed_at < 0 or r.get("policy") != "twilight_expedition_estimate_v1": return "탐험 영수증 내용 오류"
	return ""

func restore(data: Dictionary) -> void:
	namespace_present = data.has(KEY)
	var loaded: Dictionary = data.get(KEY, fresh_estimate()).duplicate(true)
	migration_backup_pending = namespace_present and int(loaded.version) == 1
	if int(loaded.version) == 1:
		if not loaded.jobs.is_empty() and not world.get_expedition_catalog().ready():
			state = loaded; save_blocked = false; migration_backup_pending = false; return
		var upgraded := fresh_estimate()
		upgraded.revision = int(loaded.revision); upgraded.attempts = loaded.attempts.duplicate(true); upgraded.day = today()
		for old: Dictionary in loaded.jobs:
			var catalog: RefCounted = world.get_expedition_catalog()
			var group: Dictionary = catalog.record("MagicDollExpeditionGroup", int(old.group_id))
			var level := int(group.get("MinLevel", 5))
			var profile: Dictionary = world.skill_awakening.core.profile(str(old.identity), level)
			if profile.is_empty() or not catalog.completion_contract(int(old.spot_id), int(old.group_id), int(old.completion_reward_id)).get("ok", false):
				save_blocked = true; last_error = "기존 탐험의 원본 팩·카드 프로필을 확인한 뒤 이전해야 합니다."; state = loaded; return
			var job := old.duplicate(true)
			MODEL.initialize(job, int(profile.hp), level, hash([old.id, old.identity, SOURCE.SOURCE_SHA256]), MODEL.policy(), now()-(int(old.duration)-int(old.remaining)))
			job.sim.legacy_level_lower_bound = true
			upgraded.jobs.append(job)
		loaded = upgraded
	state = loaded
	if not str(state.rng_state).is_empty(): random.state = int(state.rng_state)
	save_blocked = false; busy = false; fraction = 0.0
	install_inventory_definitions()

func before_save() -> bool:
	if not migration_backup_pending: return true
	var path: String = world.save_path()
	if FileAccess.file_exists(path):
		var sha := FileAccess.get_sha256(path)
		var backup := path+".pre-expedition-estimate-"+sha
		if (not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path, backup) != OK) or FileAccess.get_sha256(backup) != sha: return false
	migration_backup_pending = false
	return true

func attempts_used(deck: String) -> int:
	return 0 if today() > int(state.get("day", 0)) else int(state.attempts.get(deck, 0))

func inspect_for_start(spot_id:int,identities:Array)->Dictionary:
	var inspection:Dictionary=world.inspect_expedition(spot_id,identities)
	if int(inspection.get("spot",{}).get("BuffCardDeckID",0))!=1 or not inspection.get("static_conditions_met",false):return inspection
	var party:Dictionary=DISPATCH.plan(world.get_expedition_catalog(),inspection.cards,MODEL.policy())
	if not party.ok:inspection.static_conditions_met=false;return inspection
	var detail:Dictionary=world.get_expedition_catalog().group_detail(spot_id,int(party.group_id))
	inspection.merge(detail,true);inspection.group_id=party.group_id;inspection.party=party;inspection.representative_identity=party.representative.identity
	return inspection

func diamond_balance()->int:
	return int(state.get("local_diamonds",0))

func exchange_diamonds(amount:int)->Dictionary:
	if world==null or save_blocked or not validate(state).is_empty() or int(state.version)!=2 or not MODEL.valid_policy(MODEL.policy()):return _fail("유효한 탐험 저장·설정이 필요합니다.")
	if amount<1 or amount>1000 or diamond_balance()+amount>1000000000:return _fail("로컬 다이아 교환 수량 오류")
	var cost:int=amount*int(MODEL.policy().local_diamond_adena_price)
	if int(world.gold)<cost:return _fail("로컬 다이아 교환 아데나 부족")
	if not _backup_before_first_start():return _fail("로컬 다이아 교환 전 저장 백업 실패")
	var next:Dictionary=state.duplicate(true);next.local_diamonds=diamond_balance()+amount;next.revision=int(next.revision)+1
	if not _commit(next,{"gold":int(world.gold)-cost}):return _fail(last_error)
	world.gold-=cost;world.call_deferred("_update_hud")
	return {"ok":true,"message":"TWILIGHT 탐험 로컬다이아%d개 교환 · 자체 교환비 아데나%d"%[amount,cost]}

func buff_options(deck: int) -> Array:
	var options: Array = []
	if world == null or not world.get_expedition_catalog().ready(): return options
	var catalog: RefCounted = world.get_expedition_catalog()
	for buff: Dictionary in catalog.rows("MagicDollExpeditionBuff"):
		if int(buff.BuffCardDeckID) != deck or int(buff.CostCurrencyID) not in [1,4] or int(buff.Cost)<=0: continue
		var bonus: Dictionary = catalog.record("MagicDollExpeditionBonus", int(buff.MagicDollExpeditionBonusID))
		var type := int(bonus.get("MagicDollExpeditionBonusTypeID", 0))
		if type not in [1,11,21]: continue
		options.append({"buff":buff,"bonus":bonus,"supported":(int(buff.CostCurrencyID)==1 and type in [1,11]) or (int(buff.CostCurrencyID)==4 and type==21)})
	return options

func _buff_plan(deck: int, ids: Array) -> Dictionary:
	if ids.size() > 3: return _fail("버프는 종류별1개씩 선택하세요.")
	var result := {"ok":true,"cost":0,"hp":0,"heal":0,"interval":0,"luck":0,"diamonds":0,"ids":[]}
	var kinds := {}
	for id in ids:
		if not integer(id) or result.ids.has(int(id)): return _fail("잘못되거나 중복된 버프 ID")
		var matched := false
		for option: Dictionary in buff_options(deck):
			if int(option.buff.ID) != int(id): continue
			var type := int(option.bonus.MagicDollExpeditionBonusTypeID)
			if not option.supported or kinds.has(type): return _fail("현재 재화로 사용할 수 없는 버프 또는 중복 종류")
			matched = true; kinds[type] = true; result.ids.append(int(id))
			if int(option.buff.CostCurrencyID)==1:result.cost += int(option.buff.Cost)
			else:result.diamonds += int(option.buff.Cost)
			if type==21:result.luck=int(option.bonus.Value)
			if type == 1: result.hp = int(option.bonus.Value)
			if type == 11:
				result.heal = int(option.bonus.Value)
				result.interval = 900 if deck==1 else _constant(world.get_expedition_catalog(),("MagicDoll" if deck == 2 else "HolyStuff")+"ExpeditionPotionInterval")
		if not matched: return _fail("해당 계열 원본 버프가 없습니다.")
	if result.heal > 0 and result.interval != 900: return _fail("원본 회복제 주기 확인 필요")
	return result

func prepare(spot_id: int, identities: Array, buff_ids: Array = []) -> Dictionary:
	var result := super.prepare(spot_id, identities)
	if not result.ok: return result
	if not MODEL.valid_policy(MODEL.policy()): return _fail("추정 규칙 설정이 잘못되었습니다.")
	var rep:Dictionary=result.inspection.get("party",{}).get("representative",result.inspection.cards[0])
	var profile:Dictionary=world.skill_awakening.core.profile(str(result.identity),int(rep.skill_awaken_level)).duplicate(true)
	result.level=int(rep.skill_awaken_level)
	if int(result.inspection.spot.BuffCardDeckID)==1:
		var hp_values:Array[int]=[]
		for member:Dictionary in result.inspection.cards:
			var member_profile:Dictionary=world.skill_awakening.core.profile(str(member.identity),int(member.skill_awaken_level))
			if member_profile.is_empty():return _fail("변신 파견 카드 HP 프로필 누락")
			hp_values.append(int(member_profile.hp))
		profile.hp=hp_values.reduce(func(a:int,b:int)->int:return a+b,0) if MODEL.policy().get("dispatch_hp","sum")=="sum" else hp_values.min()
	if profile.is_empty(): return _fail("카드의 원본 HP·경험치 연결이 없습니다.")
	var buffs := _buff_plan(int(result.inspection.spot.BuffCardDeckID),buff_ids)
	if not buffs.ok: return buffs
	result.profile = profile; result.buffs = buffs; result.entry_cost = int(result.cost)
	result.cost = int(result.cost)+int(buffs.cost)
	if int(world.gold) < int(result.cost): return _fail("입장비·선택 버프 아데나 부족")
	if diamond_balance()<int(buffs.diamonds):return _fail("TWILIGHT 탐험 로컬다이아 부족 · 원본 버프 비용은10다이아입니다.")
	return result

func _commit(next: Dictionary, overrides: Dictionary = {}) -> bool:
	if world == null or not world.pending_map_save_record.is_empty(): last_error = "진행 중인 저장 이전을 먼저 완료하세요."; return false
	if int(next.get("version", 0)) == 2 and str(next.rng_state).is_empty(): next.rng_state = str(random.state)
	if busy or save_blocked or not validate(next).is_empty(): last_error = "탐험 저장 검증 또는 거래 처리 중"; return false
	busy = true
	overrides[KEY] = next
	var error: Error = world._save_game(true, overrides)
	busy = false
	if error != OK: last_error = "저장 실패 · 보상·재화·난수 보존"; return false
	state = next; namespace_present = true
	if not str(state.rng_state).is_empty(): random.state = int(state.rng_state)
	last_error = ""
	return true

func start(spot_id: int, identities: Array, buff_ids: Array = []) -> Dictionary:
	var p := prepare(spot_id, identities, buff_ids)
	if not p.ok: return p
	if not _backup_before_first_start(): return _fail("출발 전 저장 원본 백업 실패")
	var next := state.duplicate(true)
	if today() > int(next.day): next.day = today(); next.attempts = {}
	next.revision = int(next.revision)+1
	var rng := RandomNumberGenerator.new(); rng.state = random.state
	var i: Dictionary = p.inspection
	var job := {"id": int(next.revision), "spot_id": spot_id, "group_id": int(i.group_id), "deck_id": int(i.spot.BuffCardDeckID), "cost": int(p.entry_cost), "identity": p.identity, "duration": int(i.spot.TimeLimitSecond), "remaining": int(i.spot.TimeLimitSecond), "status": "running", "completion_reward_id": int(i.completion[0].reward.ID)}
	var run_policy:Dictionary=MODEL.policy()
	var extra_hp:=0;var extra_heal:=0;var synergy_luck:=0
	if int(job.deck_id)==1:
		job.member_ids=identities.duplicate();job.synergy_ids=i.party.synergy_ids.duplicate()
		extra_hp=int(i.party.effects.hp);extra_heal=int(i.party.effects.heal)
		synergy_luck=int(i.party.effects.luck_seconds)
		run_policy.monster_win_permyriad=mini(10000,int(run_policy.monster_win_permyriad)+int(i.party.effects.win_permyriad))
		run_policy.dispatch_rest_hp_percent=int(i.party.effects.rest_hp_percent)
	var luck:int=maxi(int(p.buffs.luck),synergy_luck) if run_policy.get("luck_stacking","maximum")=="maximum" else int(p.buffs.luck)+synergy_luck
	run_policy.event_interval_seconds=maxi(60,int(run_policy.event_interval_seconds)-luck)
	if int(p.buffs.diamonds)>0:next.local_diamonds=diamond_balance()-int(p.buffs.diamonds)
	MODEL.initialize(job, int(p.profile.hp)+int(p.buffs.hp)+extra_hp, int(p.level), rng.randi(), run_policy, now())
	if not p.buffs.ids.is_empty() or extra_heal>0:
		job.buff_ids = p.buffs.ids.duplicate()
		job.sim.potion_heal = int(p.buffs.heal)+extra_heal
		job.sim.potion_interval = 900 if extra_heal>0 else int(p.buffs.interval)
		job.sim.next_potion = int(job.sim.potion_interval)
	next.rng_state = str(rng.state); next.jobs.append(job); next.attempts[p.deck] = int(next.attempts.get(p.deck, 0))+1
	if not _commit(next, {"gold": int(world.gold)-int(p.cost)}): return _fail(last_error)
	world.gold -= int(p.cost); world.call_deferred("_update_hud")
	return {"ok": true, "cost": int(p.cost), "message": "출발 완료 · 원본 수치 + TWILIGHT 추정 규칙 적용"}

func tick(delta: float) -> void:
	if state.jobs.is_empty() or save_blocked or busy or world == null: return
	fraction += delta
	if fraction < 1.0: return
	var seconds := floori(fraction)
	fraction -= seconds
	_advance(seconds, now())

func advance_to(timestamp: int) -> void:
	_advance(0, timestamp)

func advance(seconds: int) -> void:
	_advance(seconds, -1)

func _advance(seconds: int, timestamp: int) -> void:
	if (seconds <= 0 and timestamp < 0) or save_blocked or busy or world == null or not world.get_expedition_catalog().ready(): return
	if int(state.get("version", 0)) == 1:
		restore({KEY: state})
		if int(state.get("version", 0)) != 2: return
	var next := state.duplicate(true)
	var economic := false
	var changed := false
	for job: Dictionary in next.jobs:
		if job.status != "running": continue
		var passed := seconds if timestamp < 0 or not job.sim.policy.offline_progress else maxi(0, timestamp-int(job.sim.last_wall))
		if passed <= 0: continue
		var result: Dictionary = MODEL.step(job, passed, world.get_expedition_catalog())
		if result.has("error"): last_error = str(result.error); return
		job.sim.last_wall = int(job.sim.last_wall)+passed if timestamp < 0 else maxi(int(job.sim.last_wall), timestamp)
		economic = economic or result.economic; changed = true
	if not changed: return
	next.revision = int(next.revision)+1
	if economic:
		_commit(next)
	else:
		state = next
		world._request_deferred_save()

func resurrect(job_id: int) -> Dictionary:
	if world == null or save_blocked or not validate(state).is_empty() or not world.get_expedition_catalog().ready(): return _fail("유효한 탐험 저장·원본 팩이 필요합니다.")
	var next := state.duplicate(true)
	for job: Dictionary in next.jobs:
		if int(job.id) != job_id: continue
		var spot: Dictionary = world.get_expedition_catalog().record("MagicDollExpeditionSpot", int(job.spot_id))

		if job.status != "dead" or int(job.sim.resurrections) >= int(spot.get("ResurrectionLimit", 0)): return _fail("부활 가능한 사망 탐험이 아닙니다.")
		var dispatch:bool=int(job.deck_id)==1
		var cost:int=0 if dispatch else int(job.cost)*int(job.sim.policy.resurrection_cost_multiplier_permyriad)/10000
		if dispatch and diamond_balance()<50:return _fail("원본 파견 부활50다이아 · TWILIGHT 탐험 로컬다이아 부족")
		if dispatch:next.local_diamonds=diamond_balance()-50
		if int(world.gold) < cost: return _fail("부활 아데나 부족")
		job.sim.hp = maxi(1, int(job.sim.max_hp)*int(job.sim.policy.resurrection_hp_permyriad)/10000)
		job.sim.resurrections = int(job.sim.resurrections)+1; job.sim.last_wall = now(); job.status = "completed" if job.remaining == 0 else "running"
		next.revision = int(next.revision)+1
		if not _commit(next, {"gold": int(world.gold)-cost}): return _fail(last_error)
		world.gold -= cost; world.call_deferred("_update_hud")
		return {"ok": true, "message": "부활 완료 · 원본 비용50 로컬다이아" if dispatch else "부활 완료 · 추정 비용 아데나 %d" % cost}
	return _fail("해당 탐험이 없습니다.")

func settlement_view(job_id: int) -> Dictionary:
	if world == null or save_blocked or not validate(state).is_empty() or int(state.version) != 2: return _fail("유효한 탐험 저장 기록이 필요합니다.")
	var catalog: RefCounted = world.get_expedition_catalog()
	if not catalog.ready(): return _fail(catalog.error)
	for job: Dictionary in state.jobs:
		if int(job.id) != job_id: continue
		var contract: Dictionary = catalog.completion_contract(int(job.spot_id), int(job.group_id), int(job.completion_reward_id))
		if not contract.ok: return contract
		contract.job = job.duplicate(true); contract.claimable = job.status == "completed"
		contract.reason = "완주 성공 · 보상 수령 가능" if contract.claimable else ("사망 · 부활 또는 중단 후 일부 수령 가능" if job.status == "dead" else "탐험 진행 중 · 중단 시 추정 회수율%.1f%%" % (float(job.sim.policy.abort_recovery_permyriad)/100.0))
		return contract
	return _fail("수령했거나 존재하지 않는 탐험입니다.")

func _skill_reward(identity: String, amount: int, base_progress:Dictionary={}) -> Dictionary:
	var progress: Dictionary = base_progress.duplicate(true) if not base_progress.is_empty() else world.skill_awakening.export_state()
	var entry: Dictionary = progress.cards.get(identity, {})
	if amount <= 0 or entry.is_empty() or int(entry.get("level", 0)) >= 20: return {"state": progress, "applied": 0}
	var card: Dictionary = world.skill_awakening.core.cards.get(identity, {})
	if card.is_empty(): return {"state": progress, "applied": 0}
	var deck := int(card.source_card.BuffCardDeckID)
	var level := int(entry.level)
	var floor_exp := int(world.skill_awakening.core.experiences.get("%d:%d" % [deck, level-1], {}).get("CumExp", 0))
	var total := mini(9999999999999, maxi(int(entry.experience), floor_exp)+amount)
	while level < 20 and total >= int(world.skill_awakening.core.experiences.get("%d:%d" % [deck, level], {}).get("CumExp", 9999999999999)): level += 1
	entry.level = level; entry.experience = str(total); progress.revision = int(progress.revision)+1
	return {"state": progress, "applied": amount}

func claim(job_id: int, abort: bool = false) -> Dictionary:
	if world == null or not world.pending_map_save_record.is_empty(): return _fail("저장 이전 완료 후 수령하세요.")
	var view := settlement_view(job_id)
	if not view.ok: return view
	var job: Dictionary = view.job
	if not abort and job.status != "completed": return _fail("완주 후 수령하거나 중단을 선택하세요.")
	if abort and job.status == "completed": return _fail("완료된 탐험은 전체 보상으로 수령하세요.")
	var next := state.duplicate(true)
	var factor := int(job.sim.policy.abort_recovery_permyriad) if abort else 10000
	var loot: Dictionary = job.sim.loot.duplicate(true)
	if not abort:
		MODEL.add_loot(loot, int(view.reward.RewardClassID), int(view.reward.Amount), int(view.reward.get("ItemBlessCodeID", 1)), 0)
	for k in loot:
		var amount := int(loot[k])*factor/10000
		if amount > 0: next.storage[k] = int(next.storage.get(k, 0))+amount
	if next.storage.size() > 75: return _fail("탐험 보관함75칸이 가득 찼습니다. 먼저 인벤토리로 옮기세요.")
	var xp := int(job.sim.exp)*factor/10000
	var skill:Dictionary={"state":world.skill_awakening.export_state(),"applied":0}
	var recipients:Array=job.get("member_ids",[job.identity]).duplicate();recipients.sort()
	for index in range(recipients.size()):
		var gain:int=xp
		if recipients.size()>1 and job.sim.policy.get("dispatch_experience","split_total")=="split_total":gain=xp/recipients.size()+(1 if index<xp%recipients.size() else 0)
		skill=_skill_reward(str(recipients[index]),gain,skill.state)
	if not world.skill_awakening.core.validate_state(skill.state).is_empty(): return _fail("카드 경험치 저장 검증 실패")
	var receipt := {"job_id": job_id, "aborted": abort, "exp": xp, "claimed_at": now(), "policy": job.sim.policy.policy_id}
	next.jobs = next.jobs.filter(func(r: Dictionary) -> bool: return int(r.id) != job_id)
	next.receipts[str(job_id)] = receipt; next.revision = int(next.revision)+1
	if not _commit(next, {"card_skill_awakening": skill.state}): return _fail(last_error)
	world.skill_awakening.progress = skill.state; world.equipment_records_dirty = true; world.call_deferred("_update_hud")
	return {"ok": true, "message": "중단 보상 수령 완료 · 추정 회수율%.1f%%" % (float(job.sim.policy.abort_recovery_permyriad)/100.0) if abort else "완주 보상 수령 완료", "receipt": receipt}

func storage_view() -> Array:
	var result: Array = []
	if int(state.get("version", 0)) != 2: return result
	var catalog: RefCounted = world.get_expedition_catalog()
	for k in state.storage:
		var parts: PackedStringArray = k.split(":")
		result.append({"key": k, "amount": int(state.storage[k]), "item": catalog.record("ItemClass", int(parts[0])), "box": not catalog.completion_box_candidates(int(parts[0])).is_empty()})
	return result

func open_box(key: String, expected_revision: int = -1, from_inventory: String = "") -> Dictionary:
	if world == null or save_blocked or not validate(state).is_empty() or int(state.version) != 2 or not MODEL.valid_policy(MODEL.policy()) or not world.get_expedition_catalog().ready(): return _fail("유효한 탐험 저장·원본 팩·설정이 필요합니다.")
	if expected_revision >= 0 and expected_revision != int(state.revision): return _fail("보관함 상태가 변경되었습니다. 다시 선택하세요.")
	if not _valid_loot({key: 1}): return _fail("잘못된 보관함 아이템 ID")
	var catalog: RefCounted = world.get_expedition_catalog()
	var candidates: Array = catalog.completion_box_candidates(int(key.split(":")[0]))
	if candidates.is_empty(): return _fail("완료상자 원본 후보가 없습니다.")
	var total := 0
	for row: Dictionary in candidates:
		if int(row.LuckyBagEntityTypeID) != 0 or int(row.LimitClass) != 10000: return _fail("확인되지 않은 상자 분기")
		total += int(row.Probability)
	if total != 10000000: return _fail("상자 원가중치 합 오류")
	var next := state.duplicate(true)
	var overrides := {}
	if from_inventory.is_empty():
		if int(next.storage.get(key, 0)) < 1: return _fail("보관함에 상자가 없습니다.")
		next.storage[key] = int(next.storage[key])-1
		if next.storage[key] == 0: next.storage.erase(key)
	else:
		if next.issued.get(key) != from_inventory or int(world.inventory.get(from_inventory, 0)) < 1: return _fail("확인된 인벤토리 상자가 없습니다.")
		var bag: Dictionary = world.inventory.duplicate(true)
		bag[from_inventory] = int(bag[from_inventory])-1
		if bag[from_inventory] == 0: bag.erase(from_inventory)
		overrides.inventory = bag
	var rng := RandomNumberGenerator.new(); rng.state = random.state
	var draws := int(MODEL.policy().completion_box_draws)
	var outcomes: Array = []
	for i in range(draws):
		var chosen := MODEL.choose(candidates, "Probability", rng)
		MODEL.add_loot(next.storage, int(chosen.ItemClassID), int(chosen.ItemAmount), int(chosen.ItemBlessCodeID), int(chosen.ItemEnchant))
		outcomes.append(chosen)
	if next.storage.size() > 75: return _fail("탐험 보관함이 가득 찼습니다.")
	next.rng_state = str(rng.state); next.revision = int(next.revision)+1
	if not _commit(next, overrides): return _fail(last_error)
	if overrides.has("inventory"): world.inventory = overrides.inventory
	world.call_deferred("_update_hud")
	return {"ok": true, "message": "상자1개 개봉 · 원본 가중치%d회 추첨" % draws, "candidate": outcomes[0], "candidates": outcomes}

func _reward_provider() -> Variant:
	if reward_item_provider!=null:return reward_item_provider
	if world==null:return null
	var constants:Dictionary=world.get_script().get_script_constant_map()
	var loot:Variant=constants.get("LOOT_DROP")
	if loot!=null and loot is Script:
		var registered:Variant=loot.get_script_constant_map().get("PATCH523_DROPS")
		if registered!=null:return registered
	return REWARD_BRIDGE.provider()

func _native_target(key:String) -> Dictionary:
	if world==null or not _valid_loot({key:1}) or not world.get_expedition_catalog().ready():return _fail("원본 탐험 자료를 확인해야 합니다.")
	var parts:PackedStringArray=key.split(":")
	if int(parts[2])!=0:return _fail("강화된 보상은 전용 아이템 기능 연결이 필요합니다.")
	var source:Dictionary=world.get_expedition_catalog().record("ItemClass",int(parts[0]))
	var restriction:String=REWARD_BRIDGE.protected_reason(source)
	if not restriction.is_empty():return _fail(restriction)
	var existing:Dictionary=REWARD_BRIDGE.existing_target(world,source,int(parts[1]),int(parts[2]))
	if not existing.is_empty():return existing
	var material:Dictionary=REWARD_BRIDGE.registered_material_target(world,source,int(parts[1]),int(parts[2]),reward_recipients)
	if not material.is_empty():return material
	var provider:Variant=_reward_provider()
	if provider==null:return _fail("이 보상의 전용 소비자/정체 계약이 아직 연결되지 않았습니다. 아이템은 보존됩니다.")
	var definition:Dictionary=REWARD_BRIDGE.definition(provider,parts[0])
	if definition.get("original_item",{})!=source:return _fail("보상과 소비자의 원본 아이템 정의가 다릅니다. 아이템은 보존됩니다.")
	var target:Dictionary=provider.variant_item(definition.get("native_record",{}),int(parts[1]))
	if target.is_empty() or target.get("source_test_item",true) or not target.get("source_m_native_item",false) or int(target.get("source_item_class_id",0))!=int(parts[0]) or target.get("source_snapshot")!="patch523" or int(target.get("source_bless_raw",1))!=int(parts[1]) or provider.equipment(target):return _fail("이 보상의 전용 소비자 연결을 확인해야 합니다.")
	var action:Dictionary=target
	var consumer:Variant=REWARD_BRIDGE.consumer()
	if REWARD_BRIDGE.exposes(consumer,"action_record"):action=consumer.action_record(world,target)
	var spec:Dictionary=NATIVE_FIELDS.full(action).get("source_use_spec",{})
	var use_ready:bool=spec.get("activation_status")=="unrestricted" and spec.get("kind") in ["source_timed_buff","source_mp_dice","guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward"]
	var receiver:String=REWARD_BRIDGE.recipient(world,target,source,reward_recipients)
	if not use_ready and receiver.is_empty():return _fail("원본 사용 조건 또는 재료 소비자가 미연결입니다. 아이템은 보존됩니다.")
	var registered:Dictionary=world._find_catalog_item_record(str(target.get("name","")))
	if registered.is_empty() and REWARD_BRIDGE.consumer()!=null:
		# Register only this verified reward definition, never the other PR's loot pool.
		var conflicts:Array=world.catalog_db.get("아이템",[]).filter(func(r:Dictionary)->bool:return r.get("name")==target.name or r.get("sourceId")==target.sourceId)
		if not conflicts.is_empty():return _fail("보상 카탈로그 정체 충돌 · 기존 정의 보존")
		world.catalog_db["아이템"].append(target.duplicate(true));world._index_catalog_item_sources()
		registered=world._find_catalog_item_record(str(target.name))
	if not provider.matches(registered,target):return _fail("보상의 원본 소비자가 설치·등록되지 않았습니다. 아이템은 보존됩니다.")
	return {"ok":true,"record":target,"wallet":"","kind":"native" if use_ready else "native_material","recipient":receiver}

func _inventory_handoff(key:String,item_name:String) -> Dictionary:
	var target:Dictionary=_native_target(key)
	if not target.ok:return target
	if world._item_locked(item_name,""):return _fail("잠긴 탐험 보상은 소비자에 전달할 수 없습니다.")
	var amount:int=int(world.inventory.get(item_name,0))
	if amount<1 or amount>1000000000:return _fail("소지한 탐험 보상 수량을 확인하세요.")
	var destination:String=str(target.record.name) if str(target.wallet).is_empty() else str(target.wallet)
	if destination==item_name:return _fail("보상 소비자 정체가 중복되어 연결을 보류합니다.")
	var next:Dictionary=state.duplicate(true)
	var bag:Dictionary=world.inventory.duplicate(true)
	var overrides:Dictionary={"inventory":bag}
	if target.get("kind")=="native" and REWARD_BRIDGE.supplier()!=null:
		# The supplier stages a complete candidate from the current live baseline.
		# Debit this receipt from that candidate, then commit its output and our
		# ledger together; never merge it over an independently debited inventory.
		var parts:PackedStringArray=key.split(":")
		var staged:Dictionary=world.stage_source_item_grants([{"item_class_id":int(parts[0]),"amount":amount,"bless_raw":int(parts[1]),"enchant":int(parts[2])}],{"kind":"expedition523_receipt","source_snapshot":"patch523","receipt_key":key,"revision":int(next.revision)+1})
		if not staged.get("ok",false):return staged
		overrides=staged.overrides
		bag=overrides.inventory
		if int(bag.get(item_name,0))!=amount:return _fail("보상 후보의 원본 소지 수량 불일치 · 아이템 보존")
		bag.erase(item_name)
		if not next.has("native_handoffs"):next.native_handoffs={}
		next.native_handoffs[destination]=key
	elif destination=="아데나":
		if int(world.gold)>MAX_INTEGER-amount:return _fail("보상 재화의 저장 범위를 초과합니다.")
		bag.erase(item_name)
		overrides.gold=int(world.gold)+amount
	else:
		if int(bag.get(destination,0))>MAX_INTEGER-amount:return _fail("보상 수량의 저장 범위를 초과합니다.")
		bag.erase(item_name)
		bag[destination]=int(bag.get(destination,0))+amount
		if str(target.wallet).is_empty():
			if not next.has("native_handoffs"):next.native_handoffs={}
			next.native_handoffs[destination]=key
	next.revision=int(next.revision)+1
	if not _commit(next,overrides):return _fail(last_error)
	world.inventory=bag
	if overrides.has("item_instances"):world.item_instances=overrides.item_instances
	if overrides.has("gold"):world.gold=int(overrides.gold)
	world.call_deferred("_update_hud")
	return {"ok":true,"message":"원본 ID·축복을 확인해 기존 아이템 기능으로 연결했습니다: "+destination,"native_handoff":true}

func receive_card(key:String,item_name:String)->Dictionary:
	if world==null or not _valid_loot({key:1}) or state.get("issued",{}).get(key)!=item_name:return _fail("탐험 지급 정체 오류")
	if world._item_locked(item_name,"") or int(world.inventory.get(item_name,0))<1:return _fail("소지/잠금 상태 확인 필요")
	var source:RefCounted=world.get_expedition_catalog()
	var parts:PackedStringArray=key.split(":")
	if int(parts[1]) not in [1,2,3] or int(parts[2])!=0:return _fail("지원하는 원본 축복·강화 정체 확인 필요")
	var item_id:int=int(parts[0])
	var error:String=REWARD_CARDS.item_conditions(source,item_id)
	if not error.is_empty():return _fail(error)
	var item:Dictionary=source.record("ItemClass",item_id)
	if not bool(item.get("CanUseWhenInvisible",false)):return _fail("원본 은신 사용 제한 소비자 확인 필요")
	var raw:Dictionary=REWARD_CARDS.fixed_target(source,item_id)
	var record:Dictionary=REWARD_CARDS.registered(world.catalog_db,raw)
	if record.is_empty():return _fail("정확한 원본 카드 등록 필요 · 보상 보존")
	var staged=CARDS.new();staged.configure(world.catalog_db);staged.import_state(world.card_draw_fusion.export_state())
	var no_swap:bool=bool(raw.IsNoSwapOut)
	for link:Dictionary in source.rows("ItemBonus"):
		if int(link.ItemClassID)!=item_id:continue
		var bonus:Dictionary=source.record("Bonus",int(link.BonusID))
		if source.record("BonusType",int(bonus.BonusTypeID)).get("Name")=="BuffCardCannotSwap" and int(bonus.Value)!=0:no_swap=true
	var result:Dictionary=staged.receive_source_card(REWARD_CARDS.CATEGORIES[int(raw.BuffCardDeckID)],record,{"card_id":int(raw.ID),"item_class_id":item_id,"bless":int(parts[1]),"enchant":0,"cannot_swap":no_swap,"cannot_merge":bool(raw.IsNoMergeOut),"expedition_item":key,"source_snapshot":"patch523"})
	if not result.ok:return result
	var bag:Dictionary=world.inventory.duplicate(true)
	bag[item_name]=int(bag[item_name])-1
	if bag[item_name]==0:bag.erase(item_name)
	var next:Dictionary=state.duplicate(true);next.revision=int(next.revision)+1
	if not _commit(next,{"inventory":bag,"card_draw_fusion":staged.export_state()}):return _fail(last_error)
	world.inventory=bag;world.card_draw_fusion.import_state(staged.export_state())
	world.call_deferred("_update_hud")
	return {"ok":true,"message":"원본 지정 카드 수령: "+str(record.name),"identity":CARDS.card_id(record)}

func inventory_activation(item_name:String) -> Dictionary:
	var belongs:bool=state.get("native_handoffs",{}).has(item_name) or state.get("issued",{}).values().has(item_name)
	if not belongs:
		# A stale visible tag is refusal evidence only, never ownership proof.
		if item_name.contains(" (탐험 137:") or item_name.contains(" (탐험 138:"):return {"handled":true,"ok":false,"committed":false,"error":"탐험 주문서 발급 장부를 확인하세요 · 주문서 보존"}
		return {"handled":false}
	if world==null or save_blocked or not validate(state).is_empty():return {"handled":true,"ok":false,"error":"탐험 저장 보호 중"}
	if world._item_locked(item_name,""):return {"handled":true,"ok":false,"error":"잠긴 탐험 보상은 사용할 수 없습니다"}
	var handoffs:Dictionary=state.get("native_handoffs",{})
	if handoffs.has(item_name):
		var target:Dictionary=_native_target(str(handoffs[item_name]))
		if not target.ok:return {"handled":true,"ok":false,"error":target.error}
		if str(target.record.name)!=item_name:return {"handled":true,"ok":false,"error":"보상의 소비자 정체가 변경되었습니다. 아이템은 보존됩니다."}
		if target.get("kind") in ["legacy_material","native_material"]:return {"handled":true,"ok":true,"message":"정확한 재료 소지 키입니다. 기존 제작·보관·판매 메뉴에서 사용하세요."}
		var consumer:Variant=REWARD_BRIDGE.consumer()
		if consumer==null:return {"handled":true,"ok":false,"error":"원본 소비자 실행 코드 미설치 · 아이템 보존"}
		var handled:bool=bool(consumer.try_use(world,target.record))
		if handled and world.hud.has_meta("patch523_reward_choice"):
			var dialog:Variant=world.hud.get_meta("patch523_reward_choice")
			if is_instance_valid(dialog) and dialog.record.get("name")==item_name:dialog.use_service=REWARD_BRIDGE
		return {"handled":handled}
	for key:String in state.get("issued",{}):
		if state.issued[key]!=item_name:continue
		if not world.get_expedition_catalog().ready():return {"handled":true,"ok":false,"error":"원본 탐험 팩이 필요합니다. 아이템은 보존됩니다."}
		var owner_ui:Dictionary=REWARD_BRIDGE.open_issued_owner_ui(world,key,item_name)
		if owner_ui.get("handled",false):return owner_ui
		var result:Dictionary
		if not world.get_expedition_catalog().completion_box_candidates(int(key.split(":")[0])).is_empty():result=open_box(key,-1,item_name)
		elif not compatible_skill_book(key).is_empty():result={"ok":false,"error":"카드 상세의 스킬 각성에서 사용할 수 있는 각성서입니다."}
		elif not REWARD_CARDS.fixed_target(world.get_expedition_catalog(),int(key.split(":")[0])).is_empty():result=receive_card(key,item_name)
		elif int(key.split(":")[0]) in REWARD_BRIDGE.OWNED_TICKETS:
			var shop:Variant=REWARD_BRIDGE.shop(world)
			if not REWARD_BRIDGE.exposes(shop,"use_inventory_ticket"):result=_fail("검증된 소지 티켓 소비자 미설치 · 티켓 보존")
			else:
				# The owner saves debit/cards/independent RNG/counter together.
				# Do not debit, grant, or commit again; handled is recognition only.
				result=shop.use_inventory_ticket(item_name,{})
				if not result.get("ok",false):result.error=str(result.get("reason","티켓 소비 실패 · 소지품 보존"))
		else:result=_inventory_handoff(key,item_name)
		result.handled=true
		return result
	return {"handled":false}

func received_material_records()->Dictionary:
	var result:Dictionary={}
	if world==null or not world.get_expedition_catalog().ready():return result
	for name:String in state.get("native_handoffs",{}):
		var key:String=str(state.native_handoffs[name]);var fields:PackedStringArray=key.split(":")
		var source:Dictionary=world.get_expedition_catalog().record("ItemClass",int(fields[0]))
		var target:Dictionary=REWARD_BRIDGE.existing_target(world,source,int(fields[1]),int(fields[2]))
		if target.get("kind")=="legacy_material" and target.record.name==name:result[name]=target.record
	return result

func transfer_restriction(item_name:String,operation:String)->String:
	var key:String=str(state.get("native_handoffs",{}).get(item_name,""))
	if key.is_empty():
		for source_key:String in state.get("issued",{}):
			if state.issued[source_key]==item_name:key=source_key;break
	if key.is_empty():return ""
	if not world.get_expedition_catalog().ready():return "원본 팩이 필요합니다 · 아이템 보존"
	var item:Dictionary=world.get_expedition_catalog().record("ItemClass",int(key.split(":")[0]))
	if operation=="deposit" and not bool(item.get("IsStorable",false)):return "원본 보관 제한 아이템입니다"
	if operation=="sell" and (not bool(item.get("IsTradable",false)) or not REWARD_BRIDGE.protected_reason(item).is_empty()):return "원본 판매 제한 아이템입니다"
	return ""

func inventory_name(key: String) -> String:
	var item: Dictionary = world.get_expedition_catalog().record("ItemClass", int(key.split(":")[0]))
	return str(item.get("Name", "원본 아이템"))+" (탐험 "+key+")"

func install_inventory_definitions() -> void:
	if world == null or not world.get_expedition_catalog().ready() or int(state.get("version", 0)) != 2: return
	for key: String in state.issued:
		var id := int(key.split(":")[0])
		var item: Dictionary = world.get_expedition_catalog().record("ItemClass", id)
		if item.is_empty(): continue
		var found := false
		for r: Dictionary in world.catalog_db.get("아이템", []):
			if r.get("sourceId") == "m523:expedition:"+key:
				r.IsStorable=bool(item.IsStorable);r.tradeable=bool(item.IsTradable);r.bound=not bool(item.IsTradable);r.droppable=bool(item.IsDroppable)
				if id in REWARD_BRIDGE.OWNED_TICKETS:r.desc=REWARD_BRIDGE.TICKET_POLICY_TEXT
				found = true; break
		if not found:
			world.catalog_db["아이템"].append({"name": str(state.issued[key]), "source": "lineagem_patch523", "source_snapshot": "patch523", "sourceId": "m523:expedition:"+key, "source_item_class_id": id, "source_item": item, "expedition_key": key, "slot": "material", "type": "탐험 보상", "grade": {1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}.get(int(item.get("GradeID", 1)), "일반"), "stackable": true, "IsStorable":bool(item.IsStorable), "tradeable":bool(item.IsTradable), "bound":not bool(item.IsTradable), "droppable":bool(item.IsDroppable), "desc": REWARD_BRIDGE.TICKET_POLICY_TEXT if id in REWARD_BRIDGE.OWNED_TICKETS else "원본 ID·축복·강화를 보존한 탐험 보상"})
	world._index_catalog_item_sources()

func compatible_skill_book(key:String)->Dictionary:
	if world==null or not _valid_loot({key:1}) or not key.ends_with(":1:0") or not world.get_expedition_catalog().ready():return {}
	var catalog:RefCounted=world.get_expedition_catalog();var id:int=int(key.split(":")[0])
	for book:Dictionary in world.skill_awakening.core.DATA.data.books:
		if int(book.item_row.ID)!=id:continue
		if catalog.record("ItemClass",id)!=book.item_row or catalog.record("ItemBonus",int(book.item_bonus_row.ID))!=book.item_bonus_row or catalog.record("Bonus",int(book.bonus_row.ID))!=book.bonus_row:continue
		var canonical:Dictionary=world._find_catalog_item_record(str(book.name))
		if canonical.get("source")!="lineagem_base508" or canonical.get("sourceId")!="m508:item:"+str(id):continue
		return canonical.duplicate(true)
	return {}

func withdraw(key: String, amount: int = 1) -> Dictionary:
	if world == null or save_blocked or not validate(state).is_empty() or int(state.version) != 2 or not _valid_loot({key: 1}) or not world.get_expedition_catalog().ready(): return _fail("유효한 탐험 저장·원본 팩이 필요합니다.")
	if amount < 1 or int(state.storage.get(key, 0)) < amount: return _fail("보관함 수량 부족")
	if world.get_expedition_catalog().record("ItemClass", int(key.split(":")[0])).is_empty(): return _fail("원본 아이템 정의가 없습니다.")
	var name := inventory_name(key)
	var next := state.duplicate(true)
	var bag: Dictionary = world.inventory.duplicate(true)
	bag[name] = int(bag.get(name, 0))+amount
	next.storage[key] = int(next.storage[key])-amount
	if next.storage[key] == 0: next.storage.erase(key)
	next.issued[key] = name; next.revision = int(next.revision)+1
	var overrides:Dictionary={"inventory":bag}
	var skill_book:Dictionary=compatible_skill_book(key)
	if not skill_book.is_empty():
		if amount>1000:return _fail("각성서는 한 번에1000개까지 수령할 수 있습니다.")
		# Exact, unchanged source book identity is adapted to the existing native
		# awakening API. Catalog/inventory keep patch523 provenance and typed name.
		var physicals:Dictionary=world.item_instances.duplicate(true)
		skill_book.name=name;skill_book.expedition_key=key;skill_book.source_origin_snapshot="patch523";skill_book.source_compatibility="exact_ItemClass_ItemBonus_Bonus_match"
		for index in range(amount):
			var physical_id:String="expedition-book:%s:%d:%d"%[key,int(next.revision),index]
			if physicals.has(physical_id):return _fail("각성서 물리 ID 충돌 · 기존 저장 보존")
			physicals[physical_id]={"name":name,"level":0,"element":"","element_level":0,"record":NATIVE_FIELDS.full(skill_book).duplicate(true)}
		overrides.item_instances=physicals
	if not _commit(next, overrides): return _fail(last_error)
	world.inventory = bag
	if overrides.has("item_instances"):world.item_instances=overrides.item_instances
	install_inventory_definitions(); world.call_deferred("_update_hud")
	return {"ok": true, "message": "인벤토리 수령 완료"}
