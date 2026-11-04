extends "res://scripts/expedition/legacy_runtime.gd"

const MODEL = preload("res://scripts/expedition/estimated_simulation.gd")
var random = RandomNumberGenerator.new()
var clock: Callable
var migration_backup_pending: bool = false
var last_error: String = ""

func _init() -> void:
	random.randomize()
	state = fresh_estimate()

static func fresh_estimate() -> Dictionary:
	return {"version": 2, "source_sha256": SOURCE.SOURCE_SHA256, "revision": 0, "jobs": [], "attempts": {}, "day": 0, "rng_state": "", "storage": {}, "issued": {}, "receipts": {}}

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
		if k not in ["2", "98"] or not integer(v.attempts[k]) or v.attempts[k] < 0 or v.attempts[k] > 15: return "탐험 일일 횟수 오류"
	var ids := {}
	var identities := {}
	var spots := {}
	var counts := {}
	for job in v.jobs:
		if not job is Dictionary or not job.get("sim") is Dictionary: return "탐험 시뮬레이션 기록 누락"
		for f in ["id", "spot_id", "group_id", "deck_id", "cost", "duration", "remaining", "completion_reward_id"]:
			if not integer(job.get(f)) or job[f] < 0 or job[f] >= MAX_INTEGER: return "탐험 기록 정수 오류"
		if job.id < 1 or job.id > v.revision or job.spot_id < 1 or job.group_id < 1 or int(job.deck_id) not in [2, 98] or int(job.duration) != 28800 or job.remaining > job.duration or job.completion_reward_id < 1 or job.cost < 1: return "탐험 기록 범위 오류"
		if not job.get("identity") is String or not job.identity.begins_with("source:m508:%d:" % int(job.deck_id)): return "탐험 카드 ID 오류"
		var parts: PackedStringArray = job.identity.split(":")
		if parts.size() != 4 or not parts[3].is_valid_int() or str(int(parts[3])) != parts[3] or int(parts[3]) < 1: return "탐험 카드 정규형 오류"
		if ids.has(str(int(job.id))) or identities.has(job.identity) or spots.has(str(int(job.spot_id))) or v.receipts.has(str(int(job.id))): return "탐험 중복/기수령 기록 오류"
		ids[str(int(job.id))] = true; identities[job.identity] = true; spots[str(int(job.spot_id))] = true
		var deck := str(int(job.deck_id)); counts[deck] = int(counts.get(deck, 0))+1
		if counts[deck] > 5: return "탐험 동시 횟수 오류"
		var s: Dictionary = job.sim
		if not MODEL.valid_policy(s.get("policy")) or not _rng_text(s.get("rng_state")) or str(s.get("rng_state", "")).is_empty() or not _valid_loot(s.get("loot")): return "탐험 규칙·난수·보상 오류"
		for f in ["level", "hp", "max_hp", "elapsed", "next_event", "events", "resurrections", "last_wall"]:
			if not integer(s.get(f)) or s[f] < 0 or s[f] >= MAX_INTEGER: return "탐험 상태 정수 오류"
		if s.level < 1 or s.level > 20 or s.max_hp < 1 or s.hp > s.max_hp or s.elapsed > job.duration or job.remaining != job.duration-s.elapsed or s.next_event <= s.elapsed or s.resurrections > 3 or not s.get("exp") is String or not s.exp.is_valid_int() or str(int(s.exp)) != s.exp or int(s.exp) < 0 or int(s.exp) > 9999999999999: return "탐험 상태 범위 오류"
		if job.get("status") not in ["running", "dead", "completed"]: return "탐험 상태 오류"
		if (job.status == "dead") != (s.hp == 0) or (job.status == "completed" and job.remaining != 0) or (job.status == "running" and job.remaining == 0): return "탐험 생존·완료 상태 불일치"
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

func prepare(spot_id: int, identities: Array) -> Dictionary:
	var result := super.prepare(spot_id, identities)
	if not result.ok: return result
	if not MODEL.valid_policy(MODEL.policy()): return _fail("추정 규칙 설정이 잘못되었습니다.")
	var profile: Dictionary = world.skill_awakening.core.profile(str(result.identity), int(result.inspection.cards[0].skill_awaken_level))
	if profile.is_empty(): return _fail("카드의 원본 HP·경험치 연결이 없습니다.")
	result.profile = profile
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

func start(spot_id: int, identities: Array) -> Dictionary:
	var p := prepare(spot_id, identities)
	if not p.ok: return p
	if not _backup_before_first_start(): return _fail("출발 전 저장 원본 백업 실패")
	var next := state.duplicate(true)
	if today() > int(next.day): next.day = today(); next.attempts = {}
	next.revision = int(next.revision)+1
	var rng := RandomNumberGenerator.new(); rng.state = random.state
	var i: Dictionary = p.inspection
	var job := {"id": int(next.revision), "spot_id": spot_id, "group_id": int(i.group_id), "deck_id": int(i.spot.BuffCardDeckID), "cost": int(p.cost), "identity": p.identity, "duration": int(i.spot.TimeLimitSecond), "remaining": int(i.spot.TimeLimitSecond), "status": "running", "completion_reward_id": int(i.completion[0].reward.ID)}
	MODEL.initialize(job, int(p.profile.hp), int(i.cards[0].skill_awaken_level), rng.randi(), MODEL.policy(), now())
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
		var cost := int(job.cost)*int(job.sim.policy.resurrection_cost_multiplier_permyriad)/10000
		if int(world.gold) < cost: return _fail("부활 아데나 부족")
		job.sim.hp = maxi(1, int(job.sim.max_hp)*int(job.sim.policy.resurrection_hp_permyriad)/10000)
		job.sim.resurrections = int(job.sim.resurrections)+1; job.sim.last_wall = now(); job.status = "completed" if job.remaining == 0 else "running"
		next.revision = int(next.revision)+1
		if not _commit(next, {"gold": int(world.gold)-cost}): return _fail(last_error)
		world.gold -= cost; world.call_deferred("_update_hud")
		return {"ok": true, "message": "부활 완료 · 추정 비용 아데나 %d" % cost}
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

func _skill_reward(identity: String, amount: int) -> Dictionary:
	var progress: Dictionary = world.skill_awakening.export_state()
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
	var skill := _skill_reward(str(job.identity), xp)
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
			if r.get("sourceId") == "m523:expedition:"+key: found = true; break
		if not found:
			world.catalog_db["아이템"].append({"name": str(state.issued[key]), "source": "lineagem_patch523", "source_snapshot": "patch523", "sourceId": "m523:expedition:"+key, "source_item_class_id": id, "source_item": item, "expedition_key": key, "slot": "material", "type": "탐험 보상", "grade": {1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}.get(int(item.get("GradeID", 1)), "일반"), "stackable": true, "desc": "원본 ID·축복·강화를 보존한 탐험 보상"})
	world._index_catalog_item_sources()

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
	if not _commit(next, {"inventory": bag}): return _fail(last_error)
	world.inventory = bag; install_inventory_definitions(); world.call_deferred("_update_hud")
	return {"ok": true, "message": "인벤토리 수령 완료"}
