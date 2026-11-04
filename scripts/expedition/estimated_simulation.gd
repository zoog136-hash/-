extends RefCounted

## Explicit TWILIGHT estimates. Original table weights are never edited.
const CONFIG = preload("res://data/expedition/twilight_estimated_rules.json")
const TYPES = [61, 71, 81, 91, 101, 111]

static func policy() -> Dictionary:
	return CONFIG.data.duplicate(true)

static func valid_policy(p: Variant) -> bool:
	if not p is Dictionary or p.get("policy_id") != "twilight_expedition_estimate_v1": return false
	for k in ["event_interval_seconds", "monster_win_permyriad", "win_bonus_per_level", "maximum_win_permyriad", "resurrection_hp_permyriad", "abort_recovery_permyriad", "completion_box_draws", "daily_reset_hour_utc", "resurrection_cost_multiplier_permyriad", "daily_reset_utc_offset_minutes"]:
		if not (p.get(k) is float or p.get(k) is int) or not is_finite(float(p[k])) or float(p[k]) != floorf(float(p[k])): return false
	if int(p.event_interval_seconds) < 60 or int(p.event_interval_seconds) > 28800 or int(p.completion_box_draws) < 1 or int(p.completion_box_draws) > 10 or int(p.daily_reset_hour_utc) != 5 or int(p.resurrection_hp_permyriad) != 5000 or int(p.resurrection_cost_multiplier_permyriad) < 0 or int(p.resurrection_cost_multiplier_permyriad) > 100000 or absi(int(p.daily_reset_utc_offset_minutes)) > 840: return false
	for k in ["monster_win_permyriad", "win_bonus_per_level", "maximum_win_permyriad", "resurrection_hp_permyriad", "abort_recovery_permyriad"]:
		if int(p[k]) < 0 or int(p[k]) > 10000: return false
	if p.get("potion_tie_order","before_event") not in ["before_event","after_event"]: return false
	if p.get("dispatch_representative","lowest_grade_then_level") not in ["lowest_grade_then_level","highest_grade_then_level"] or p.get("dispatch_hp","sum") not in ["sum","minimum"] or p.get("dispatch_experience","split_total") not in ["split_total","each_total"]:return false
	for key in ["dispatch_synergy_members","dispatch_monster_damage_multiplier"]:
		var value:Variant=p.get(key,4)
		if not (value is int or value is float) or float(value)!=floorf(float(value)) or int(value)<1 or int(value)>(4 if key=="dispatch_synergy_members" else 10):return false
	var diamond_price:Variant=p.get("local_diamond_adena_price",10000)
	if not (diamond_price is int or diamond_price is float) or float(diamond_price)!=floorf(float(diamond_price)) or diamond_price<1 or diamond_price>100000000 or p.get("luck_stacking","maximum") not in ["maximum","additive"]:return false
	if not p.get("normal_event_weights") is Dictionary: return false
	var total := 0
	for type in TYPES:
		var v: Variant = p.normal_event_weights.get(str(type))
		if not (v is float or v is int) or float(v) != floorf(float(v)) or int(v) < 0 or int(v) > 10000: return false
		total += int(v)
	return total > 0 and p.get("monster_damage") == "median_normal_source_HPDecrease" and p.get("resurrection_cost") == "same_as_departure" and p.get("offline_progress") is bool

static func key(item_id: int, bless: int = 1, enchant: int = 0) -> String:
	return "%d:%d:%d" % [item_id, bless, enchant]

static func add_loot(loot: Dictionary, item_id: int, amount: int, bless: int = 1, enchant: int = 0) -> void:
	if amount <= 0: return
	var id := key(item_id, bless, enchant)
	loot[id] = int(loot.get(id, 0))+amount

static func choose(rows: Array, field: String, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for row: Dictionary in rows: total += maxi(0, int(row.get(field, 0)))
	if total <= 0 or total > 2147483647: return {}
	var needle := rng.randi_range(0, total-1)
	for row: Dictionary in rows:
		needle -= maxi(0, int(row.get(field, 0)))
		if needle < 0: return row.duplicate(true)
	return {}

static func initialize(job: Dictionary, hp: int, level: int, seed: int, p: Dictionary, now: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	job.status = "running"
	job.remaining = int(job.duration)
	job.sim = {"policy": p.duplicate(true), "level": level, "hp": hp, "max_hp": hp, "elapsed": 0, "next_event": int(p.event_interval_seconds), "events": 0, "resurrections": 0, "exp": "0", "loot": {}, "rng_state": str(rng.state), "last_wall": now, "last_event": "출발"}

static func step(job: Dictionary, seconds: int, catalog: RefCounted) -> Dictionary:
	if job.status != "running" or seconds <= 0: return {"economic": false}
	var s: Dictionary = job.sim
	var p: Dictionary = s.policy
	var rng := RandomNumberGenerator.new()
	rng.state = int(s.rng_state)
	var target := mini(int(job.duration), int(s.elapsed)+seconds)
	var potion_at := int(s.get("next_potion",0)) if int(s.get("potion_heal",0)) > 0 else 2147483647
	if mini(int(s.next_event),potion_at) > target:
		s.elapsed = target
		job.remaining = maxi(0, int(job.duration)-target)
		if job.remaining == 0: job.status = "completed"
		return {"economic": job.status == "completed"}
	var group: Dictionary = catalog.record("MagicDollExpeditionGroup", int(job.group_id))
	var grade: Dictionary = catalog.record("Grade", int(group.get("GradeID", 0)))
	var detail: Dictionary = catalog.group_detail(int(job.spot_id), int(job.group_id))
	var events: Array = []
	var special_allowed := false
	for evidence: Dictionary in detail.events:
		var event: Dictionary = evidence.event
		var minimum: Dictionary = catalog.record("Grade", int(event.MinGradeID))
		if int(grade.get("GradeValue", -1)) < int(minimum.get("GradeValue", 0)) or int(s.level) < int(event.MinLevel): continue
		var type := int(evidence.bonus.get("MagicDollExpeditionBonusTypeID", 0))
		if type == 141: special_allowed = true
		if type not in TYPES: continue
		events.append({"type": type, "value": int(evidence.bonus.get("Value", 0)), "weight": int(p.normal_event_weights.get(str(type), 0))})
	var damage: Array[int] = []
	for monster: Dictionary in catalog.rows("MagicDollExpeditionMonster"):
		if not bool(monster.IsSpecial) and int(monster.HPDecrease) > 0: damage.append(int(monster.HPDecrease))
	damage.sort()
	var representative_damage := damage[damage.size()/2] if not damage.is_empty() else 1
	var economic := false
	while mini(int(s.next_event),potion_at) <= target and job.status == "running":
		if potion_at < int(s.next_event) or (potion_at == int(s.next_event) and p.get("potion_tie_order","before_event") == "before_event"):
			s.elapsed = potion_at
			s.hp = mini(int(s.max_hp),int(s.hp)+int(s.potion_heal))
			s.next_potion = potion_at+int(s.potion_interval); potion_at = int(s.next_potion)
			s.last_event = "회복제 · HP 회복"; economic = true
			continue
		s.elapsed = int(s.next_event)
		s.next_event = int(s.next_event)+int(p.event_interval_seconds)
		var event := choose(events, "weight", rng)
		if event.is_empty(): return {"economic": true, "error": "탐험 이벤트 추정 설정 또는 원본 연결 오류"}
		s.events = int(s.events)+1
		economic = true
		match int(event.type):
			61:
				var pool: Array = []
				for row: Dictionary in detail.event_rewards:
					if int(row.MagicDollExpeditionSpotRewardTypeID) not in ([0,4,14,24] if int(job.get("deck_id",2))==1 else [0]): continue
					if not row.IsSpecial or special_allowed: pool.append(row)
				var selected := choose(pool, "Probability", rng)
				var reward: Dictionary = catalog.record("Reward", int(selected.get("RewardID", 0)))
				if int(reward.get("RewardTypeID", 0)) != 2: return {"economic": true, "error": "탐험 보상 타입 연결 오류"}
				add_loot(s.loot, int(reward.RewardClassID), int(reward.Amount), int(reward.get("ItemBlessCodeID", 1)), 0)
				s.last_event = "아이템 발견"
				s.last_reward_id=int(selected.RewardID);s.last_reward_type=int(selected.MagicDollExpeditionSpotRewardTypeID)
			71: s.last_event = "아무 일도 없음"
			81:
				s.exp = str(mini(9999999999999, int(s.exp)+maxi(0, int(event.value))))
				s.last_event = "카드 경험치 발견"
			91:
				var chance := mini(int(p.maximum_win_permyriad), int(p.monster_win_permyriad)+maxi(0, int(s.level)-5)*int(p.win_bonus_per_level))
				if rng.randi_range(0, 9999) >= chance:
					s.hp = maxi(0, int(s.hp)-representative_damage*(int(p.get("dispatch_monster_damage_multiplier",4)) if int(job.get("deck_id",2))==1 else 1))
					s.last_event = "몬스터 조우 · 패배"
				else: s.last_event = "몬스터 조우 · 승리"
			101:
				s.hp = maxi(0, int(s.hp)-maxi(0, int(event.value)))
				s.last_event = "넘어짐"
			111:
				s.hp = mini(int(s.max_hp), int(s.hp)+maxi(0, int(event.value))*(100+int(p.get("dispatch_rest_hp_percent",0)))/100)
				s.last_event = "휴식"
		if int(s.hp) == 0:
			job.status = "dead"
			# In after_event mode, death suppresses the same-instant potion.
			if int(s.get("potion_heal",0)) > 0 and int(s.next_potion) <= int(s.elapsed): s.next_potion = int(s.next_potion)+int(s.potion_interval)
	if job.status == "running": s.elapsed = target
	job.remaining = maxi(0, int(job.duration)-int(s.elapsed))
	if job.status == "running" and job.remaining == 0:
		job.status = "completed"
		economic = true
	s.rng_state = str(rng.state)
	return {"economic": economic}
