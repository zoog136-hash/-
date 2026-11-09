extends RefCounted
## Ordinary Challenge (DungeonCategory 21), separate from TrialTower 174.
## Proposals are pure. The owner must durably save the whole transaction before
## applying funds, blessing, rewards or this state. Events come from real World
## gameplay, never from user-facing completion buttons.

const MAX_UNIX: int = 253402300799
const RESET_HOUR: int = 5
const RETRY_PAYMENT_ID: int = 51
const LOCAL_POLICY: String = "current_map_kill_estimate_v1"
const SURVIVAL_TICK_GRACE: int = 5
const MAX_CROSSING_HP: int = 9007199254740991
const SUPPORTED_TYPES: Array[int] = [1, 3, 30, 72, 261, 574, 1011, 1031]

var _source: Object
var _tables: Dictionary = {}
var _index: Dictionary = {}
var _challenges: Dictionary = {}
var _goals: Dictionary = {}
var _prerequisites: Dictionary = {}
var _failures: Dictionary = {}
var _rewards: Dictionary = {}
var _sections: Dictionary = {}
var _section_rewards: Dictionary = {}
var _npc_groups: Dictionary = {}

func setup(source: Object) -> void:
	_source = source
	_tables.clear()
	_index.clear()
	_challenges.clear()
	_goals.clear()
	_prerequisites.clear()
	_failures.clear()
	_rewards.clear()
	_sections.clear()
	_section_rewards.clear()
	_npc_groups.clear()
	for row: Dictionary in _rows("Challenge"):
		_challenges[int(row.get("ID", 0))] = row
	for link: Dictionary in _rows("ChallengeGoal"):
		var goal: Dictionary = _row("Goal", int(link.get("GoalID", 0))).duplicate(true)
		if not goal.is_empty():
			goal["GoalGroup"] = int(link.get("GoalGroup", 0))
			_append(_goals, int(link.get("ChallengeID", 0)), goal)
	for link: Dictionary in _rows("ChallengePrerequisite"):
		_append(_prerequisites, int(link.get("ChallengeID", 0)), _row("Prerequisite", int(link.get("PrerequisiteID", 0))))
	for link: Dictionary in _rows("ChallengeFailureCondition"):
		_append(_failures, int(link.get("ChallengeID", 0)), _row("FailureCondition", int(link.get("FailureConditionID", 0))))
	for link: Dictionary in _rows("ChallengeReward"):
		_append(_rewards, int(link.get("ChallengeID", 0)), int(link.get("RewardID", 0)))
	for section: Dictionary in _rows("ChallengeExtraRewardSection"):
		_append(_sections, int(section.get("ChallengeID", 0)), section)
	for link: Dictionary in _rows("ChallengeExtraReward"):
		_append(_section_rewards, int(link.get("SectionID", 0)), int(link.get("RewardID", 0)))
	for link: Dictionary in _rows("NpcClassForNpcGroup"):
		_append(_npc_groups, int(link.get("NpcClassID", 0)), link)

func initial_state() -> Dictionary:
	return {"version": 1, "latest_at": 0, "next_run_id": 1,
		"reset_offset_minutes": 1441, "days": {}, "active": {}}

func validate_state(value: Variant) -> String:
	if not value is Dictionary:
		return "challenge_state_not_dictionary"
	var state: Dictionary = value
	if not _integer(state.get("version"), 1, 1) or not _integer(state.get("latest_at"), 0, MAX_UNIX) or not _integer(state.get("next_run_id"), 1):
		return "challenge_state_header_invalid"
	if not _integer(state.get("reset_offset_minutes"), -840, 1441) or (int(state.reset_offset_minutes) > 840 and int(state.reset_offset_minutes) != 1441):
		return "challenge_reset_policy_invalid"
	if not state.get("days") is Dictionary or not state.get("active") is Dictionary:
		return "challenge_state_sections_invalid"
	for day: Variant in state.days:
		if not day is String or not str(day).is_valid_int() or not state.days[day] is Dictionary:
			return "challenge_day_invalid"
		for key: Variant in state.days[day]:
			var entry: Variant = state.days[day][key]
			if not key is String or not str(key).is_valid_int() or not _challenges.has(int(key)) or not entry is Dictionary:
				return "challenge_daily_entry_invalid"
			var base: int = int(_challenges[int(key)].get("BaseTryCount", 0))
			if not _integer(entry.get("used"), 0, base + 1) or not _integer(entry.get("retry_used"), 0, 1) or not _integer(entry.get("claimed"), 0, int(entry.get("used", 0))):
				return "challenge_daily_count_invalid"
			if int(entry.used) > base + int(entry.retry_used):
				return "challenge_daily_retry_invalid"
	var active: Dictionary = state.active
	if active.is_empty():
		return ""
	if not _integer(active.get("challenge_id"), 1) or not _challenges.has(int(active.challenge_id)) or not _integer(active.get("run_id"), 1, int(state.next_run_id) - 1):
		return "challenge_active_id_invalid"
	var definition: Dictionary = _challenges[int(active.challenge_id)]
	if not _integer(active.get("started_at"), 1, int(state.latest_at)) or not _integer(active.get("deadline"), int(active.get("started_at", 0)) + 1, MAX_UNIX) or int(active.deadline) - int(active.started_at) != int(definition.get("TimeLimit", 0)):
		return "challenge_active_timer_invalid"
	if not active.get("day_key") is String or not state.days.has(active.day_key) or not state.days[active.day_key].has(str(int(active.challenge_id))):
		return "challenge_active_day_invalid"
	var daily: Dictionary = state.days[active.day_key][str(int(active.challenge_id))]
	if int(daily.used) <= int(daily.claimed) or int(state.reset_offset_minutes) == 1441:
		return "challenge_active_consumed_attempt_missing"
	if not active.get("local_policy") is bool or not bool(active.local_policy) or active.get("policy_id") != LOCAL_POLICY or not active.get("host_map_id") is String or str(active.host_map_id).is_empty() or not active.get("failed") is bool or not _integer(active.get("activity_count"), 0):
		return "challenge_active_policy_invalid"
	if not _integer(active.get("alive_observed"), 0, int(definition.TimeLimit)) or not _integer(active.get("last_alive_at"), int(active.started_at), int(state.latest_at)):
		return "challenge_active_survival_invalid"
	if not active.get("progress") is Dictionary or not active.get("extra_sections") is Array or not active.get("seen_events") is Array:
		return "challenge_active_progress_invalid"
	var expected: Dictionary = {}
	for goal: Dictionary in _goals.get(int(active.challenge_id), []):
		expected[str(goal.ID)] = int(goal.get("Amount", 0))
	if active.progress.size() != expected.size():
		return "challenge_active_goal_count_invalid"
	for key: Variant in expected:
		if not _integer(active.progress.get(key), 0, int(expected[key])):
			return "challenge_active_goal_invalid"
	var seen: Dictionary = {}
	for key: Variant in active.seen_events:
		if not key is String or str(key).is_empty() or str(key).length() > 160 or seen.has(key):
			return "challenge_event_history_invalid"
		seen[key] = true
	seen.clear()
	for section_id: Variant in active.extra_sections:
		if not _integer(section_id, 1) or seen.has(int(section_id)) or not _section_for(int(active.challenge_id), int(section_id)):
			return "challenge_extra_section_invalid"
		seen[int(section_id)] = true
	return ""

func metadata(challenge_id: int) -> Dictionary:
	if not _challenges.has(challenge_id):
		return {}
	return {"source": _challenges[challenge_id].duplicate(true),
		"goals": _goals.get(challenge_id, []).duplicate(true),
		"prerequisites": _prerequisites.get(challenge_id, []).duplicate(true),
		"failure_conditions": _failures.get(challenge_id, []).duplicate(true),
		"completion_reward_ids": _rewards.get(challenge_id, []).duplicate(),
		"play_reward_sections": _sections.get(challenge_id, []).duplicate(true),
		"dungeon_category_id": 21}

func eligibility(challenge_id: int, context: Dictionary) -> String:
	if not _challenges.has(challenge_id):
		return "challenge_source_id_missing"
	var definition: Dictionary = _challenges[challenge_id]
	if not bool(definition.get("IsWorking", false)):
		return "challenge_source_inactive"
	if str(context.get("region", "KR")) != "KR":
		return "challenge_region_unsupported"
	if not _region_allowed(int(definition.get("ServerLimitSetID", 0)), context):
		return "challenge_server_restricted"
	if not _integer(context.get("level"), 40):
		return "challenge_level_below_40"
	for prerequisite: Dictionary in _prerequisites.get(challenge_id, []):
		if prerequisite.is_empty():
			return "challenge_prerequisite_missing"
		match int(prerequisite.get("PrerequisiteTypeID", 0)):
			1:
				if int(context.level) < int(prerequisite.get("Value", 0)):
					return "challenge_source_min_level"
			2:
				if int(context.level) > int(prerequisite.get("Value", 0)):
					return "challenge_source_max_level"
			_:
				return "challenge_prerequisite_unsupported"
	if _goals.get(challenge_id, []).is_empty():
		return "challenge_source_goals_missing"
	for goal: Dictionary in _goals.get(challenge_id, []):
		if not int(goal.get("GoalTypeID", 0)) in SUPPORTED_TYPES or int(goal.get("Amount", 0)) < 1:
			return "challenge_source_goal_unsupported"
	if int(definition.get("TimeLimit", 0)) < 1 or int(definition.get("BaseTryCount", 0)) < 1:
		return "challenge_source_limits_invalid"
	return ""

func view(context: Dictionary, state: Dictionary) -> Dictionary:
	var rows: Array = []
	var error: String = validate_state(state)
	if not error.is_empty():
		return {"title": "시련 던전", "notes": [error], "rows": rows}
	var active: Dictionary = state.active
	if not active.is_empty():
		var run_id: int = int(active.challenge_id)
		var actions: Array = [{"label": "도전 포기", "request": {"op": "challenge_abandon"}}]
		if not bool(active.failed) and _complete(active, context):
			actions.push_front({"label": "완료 보상 수령", "request": {"op": "challenge_claim"}})
		rows.append({"id": "challenge_active", "label": "진행 중 · " + str(_challenges[run_id].get("Name", run_id)),
			"detail": _progress_label(active) + " · 남은 %d초%s" % [maxi(0, int(active.deadline) - int(context.get("nowUnix", 0))), " · 실패" if bool(active.failed) else ""], "actions": actions})
	for key: Variant in _challenges:
		var challenge_id: int = int(key)
		var definition: Dictionary = _challenges[key]
		var reason: String = eligibility(challenge_id, context)
		var actions: Array = []
		var detail: String = "ID %d · %d초 · 축복 %d · 일 %d회 · 목표 %s" % [challenge_id, int(definition.get("TimeLimit", 0)), int(definition.get("EinhasadCost", 0)), int(definition.get("BaseTryCount", 0)), _goal_label(challenge_id)]
		if reason.is_empty() and active.is_empty():
			var day: Dictionary = _daily(state, _day_key(context), challenge_id)
			var retry: bool = int(day.used) >= int(definition.get("BaseTryCount", 0))
			if not retry or int(day.retry_used) == 0:
				var label: String = "TWILIGHT 현재 맵 실전 시작" + (" · 재도전 20 다이아" if retry else "")
				actions.append({"label": label, "request": {"op": "challenge_start", "challenge_id": challenge_id, "local_policy": true, "retry": retry}})
				var instant: Dictionary = _instant_price(challenge_id, context)
				if bool(instant.get("ok", false)):
					actions.append({"label": "즉시 완료 · %s ×%d%s" % [str(_row("Currency", int(instant.cost.id)).get("Name", instant.cost.id)), int(instant.cost.amount), " + 재도전 20 다이아" if retry else ""], "request": {"op": "challenge_instant", "challenge_id": challenge_id, "retry": retry}})
			else:
				detail += " · 일일 횟수 소진"
		if not reason.is_empty():
			detail += " · " + reason
		rows.append({"id": "challenge:%d" % challenge_id, "label": str(definition.get("Name", challenge_id)), "detail": detail, "actions": actions})
	return {"title": "시련 던전", "notes": [
		"일반 시련 Challenge 69종 · 무한의 탑과 별도 · 원본 비활성/레벨/서버 조건 유지 · 매일 05시 초기화",
		"현재 맵 실전은 조정 가능한 TWILIGHT 규칙: 원본 전용 지형 대신 현재 맵의 실제 처치를 처치 목표에 대응합니다. 원본 NPC·목표 ID/수량은 보존됩니다.",
		"그룹별 목표는 그룹 안 모두 달성, 그룹 간 하나 달성으로 해석합니다. 생존 경로는 실제 활동과 연속 생존 관측이 필요하며 오프라인 경과만으로 완료되지 않습니다.",
		"축복은 시작 시 소모 · 일일 추가 재도전 1회 20 다이아는 TWILIGHT 제한 · 즉시 완료는 원본 구매 비용과 완료 보상만 적용",
		"플레이 보상은 실제 원본 NPC/HP 구간 증거가 있을 때만 별도 누적됩니다. 몬스터 일반 전리품은 기존 바닥 드랍 규칙을 따릅니다."], "rows": rows}

func propose(request: Dictionary, context: Dictionary, state: Dictionary) -> Dictionary:
	var checked: String = _check_context(context, state)
	if not checked.is_empty():
		return _fail(checked)
	var staged: Dictionary = state.duplicate(true)
	staged.latest_at = int(context.nowUnix)
	if int(staged.reset_offset_minutes) == 1441:
		staged.reset_offset_minutes = _offset(context)
	var op: String = str(request.get("op", ""))
	if op == "observe":
		_expire(staged, context)
		return _success(staged)
	if op == "challenge_abandon":
		if staged.active.is_empty():
			return _fail("challenge_no_active_run")
		staged.active = {}
		return _success(staged)
	if op == "challenge_claim":
		return _claim(context, staged)
	if op != "challenge_start" and op != "challenge_instant":
		return _fail("challenge_operation_unknown")
	if not staged.active.is_empty():
		return _fail("challenge_run_already_active")
	if not _integer(request.get("challenge_id"), 1):
		return _fail("challenge_source_id_invalid")
	var challenge_id: int = int(request.challenge_id)
	checked = eligibility(challenge_id, context)
	if not checked.is_empty():
		return _fail(checked)
	if op == "challenge_start" and not request.get("local_policy", false) is bool:
		return _fail("challenge_local_policy_invalid")
	if op == "challenge_start" and not bool(request.get("local_policy", false)):
		return _fail("challenge_current_map_policy_opt_in_required")
	if op == "challenge_start" and (not context.get("map_id") is String or str(context.map_id).is_empty()):
		return _fail("challenge_current_map_unavailable")
	var definition: Dictionary = _challenges[challenge_id]
	if int(context.nowUnix) > MAX_UNIX - int(definition.TimeLimit):
		return _fail("challenge_clock_invalid")
	var day_key: String = _day_key(context)
	var day: Dictionary = _daily(staged, day_key, challenge_id)
	var retry: bool = int(day.used) >= int(definition.get("BaseTryCount", 0))
	var costs: Array = []
	if retry:
		if not request.get("retry", false) is bool or not bool(request.get("retry", false)):
			return _fail("challenge_retry_confirmation_required")
		if int(day.retry_used) >= 1:
			return _fail("challenge_daily_attempts_exhausted")
		var price: Dictionary = _retry_price()
		if not bool(price.get("ok", false)):
			return _fail(str(price.get("error", "challenge_retry_source_missing")))
		costs.append(price.cost)
	elif bool(request.get("retry", false)):
		return _fail("challenge_retry_not_needed")
	if not context.get("ain") is Dictionary or not _integer(context.ain.get("blessing"), 0):
		return _fail("challenge_blessing_state_unavailable")
	var blessing_cost: int = int(definition.get("EinhasadCost", 0))
	if int(context.ain.blessing) < blessing_cost:
		return _fail("challenge_blessing_insufficient")
	var rewards: Array = []
	if op == "challenge_instant":
		var instant: Dictionary = _instant_price(challenge_id, context)
		if not bool(instant.get("ok", false)):
			return _fail(str(instant.get("error", "challenge_instant_unavailable")))
		costs.append(instant.cost)
		var resolved: Dictionary = _resolve_rewards(_rewards.get(challenge_id, []), context)
		if not bool(resolved.get("ok", false)):
			return _fail(str(resolved.get("error", "challenge_reward_unavailable")))
		rewards = resolved.rewards
	checked = _afford(costs, context)
	if not checked.is_empty():
		return _fail(checked)
	var ain: Dictionary = context.ain.duplicate(true)
	ain.blessing = int(ain.blessing) - blessing_cost
	day.used = int(day.used) + 1
	if retry:
		day.retry_used = 1
	if op == "challenge_instant":
		day.claimed = int(day.claimed) + 1
	else:
		var progress: Dictionary = {}
		for goal: Dictionary in _goals.get(challenge_id, []):
			progress[str(goal.ID)] = 0
		staged.active = {"run_id": int(staged.next_run_id), "challenge_id": challenge_id,
			"started_at": int(context.nowUnix), "deadline": int(context.nowUnix) + int(definition.TimeLimit),
			"day_key": day_key, "local_policy": true, "policy_id": LOCAL_POLICY, "host_map_id": str(context.get("map_id", "")),
			"progress": progress, "extra_sections": [], "seen_events": [], "failed": false, "activity_count": 0,
			"alive_observed": 0, "last_alive_at": int(context.nowUnix)}
		staged.next_run_id = int(staged.next_run_id) + 1
	_set_daily(staged, day_key, challenge_id, day)
	var result: Dictionary = _success(staged, costs, rewards)
	result.ain = ain
	return result

## Pure observer filter: only pending sections for the actual source NPC matter.
## Bound integral HP before multiplying by 100 to keep every comparison exact
## within int64, including HP values restored from JSON as integral floats.
func has_hp_section_crossing(npc_id: int, previous_hp: Variant, hp: Variant, max_hp: Variant, state: Dictionary) -> bool:
	if not _integer(max_hp, 1, MAX_CROSSING_HP) or not _integer(previous_hp, 0, int(max_hp)) or not _integer(hp, 0, int(max_hp)) or hp >= previous_hp:
		return false
	if not validate_state(state).is_empty():
		return false
	var active: Dictionary = state.active
	if active.is_empty() or bool(active.failed):
		return false
	for section: Dictionary in _sections.get(int(active.challenge_id), []):
		if int(section.get("ID", 0)) in active.extra_sections or int(section.get("NpcClassID", 0)) != npc_id:
			continue
		if _crosses_hp_threshold(section.get("HPPercentThreshold"), int(previous_hp), int(hp), int(max_hp)):
			return true
	return false

func event(input: Dictionary, context: Dictionary, state: Dictionary) -> Dictionary:
	var checked: String = _check_context(context, state)
	if not checked.is_empty():
		return _fail(checked)
	if state.active.is_empty():
		return _fail("challenge_no_active_run")
	var event_id: Variant = input.get("event_id")
	if not event_id is String or str(event_id).is_empty() or str(event_id).length() > 160:
		return _fail("challenge_event_id_required")
	var staged: Dictionary = state.duplicate(true)
	var active: Dictionary = staged.active
	if event_id in active.seen_events:
		return _fail("challenge_event_duplicate")
	if active.seen_events.size() >= 8192:
		return _fail("challenge_event_limit")
	staged.latest_at = int(context.nowUnix)
	if bool(active.failed):
		return _fail("challenge_run_failed")
	var kind: String = str(input.get("kind", ""))
	if not str(active.host_map_id).is_empty() and str(context.get("map_id", "")) != str(active.host_map_id):
		active.failed = true
		return _success(staged)
	if not kind in ["kill", "item_use", "territory_enter", "npc_transform", "npc_hp", "player_death", "map_change", "survival_tick"]:
		return _fail("challenge_event_kind_unsupported")
	active.seen_events.append(event_id)
	if kind == "player_death":
		active.failed = true
		return _success(staged)
	if kind == "map_change":
		if str(input.get("map_id", "")) != str(active.host_map_id):
			active.failed = true
		return _success(staged)
	if int(context.nowUnix) > int(active.deadline) and not (kind == "survival_tick" and int(context.nowUnix) <= int(active.deadline) + SURVIVAL_TICK_GRACE):
		_expire(staged, context)
		return _success(staged)
	if kind == "survival_tick":
		if not input.get("alive") is bool or not bool(input.alive):
			active.failed = true
			return _success(staged)
		var elapsed: int = int(context.nowUnix) - int(active.last_alive_at)
		if elapsed > SURVIVAL_TICK_GRACE:
			# Missed live observations cannot be replaced with offline time.
			active.alive_observed = 0
		else:
			active.alive_observed = int(active.alive_observed) + mini(int(context.nowUnix), int(active.deadline)) - mini(int(active.last_alive_at), int(active.deadline))
		active.last_alive_at = int(context.nowUnix)
		if int(active.alive_observed) >= int(active.deadline) - int(active.started_at) and int(active.activity_count) > 0:
			for goal: Dictionary in _goals.get(int(active.challenge_id), []):
				if int(goal.get("GoalTypeID", 0)) == 1031 and int(goal.get("GoalClassID", 0)) == int(active.challenge_id):
					active.progress[str(goal.ID)] = int(goal.Amount)
		return _success(staged)
	var npc_id: int = int(input.get("npc_id", 0))
	if kind == "kill":
		for failure: Dictionary in _failures.get(int(active.challenge_id), []):
			if int(failure.get("FailureConditionTypeID", 0)) == 4 and int(failure.get("FailureConditionClassID", 0)) == npc_id:
				active.failed = true
		if bool(active.failed):
			return _success(staged)
	var credited: bool = bool(input.get("player_credit", true))
	if kind == "kill" and not credited:
		return _success(staged)
	if kind in ["kill", "item_use", "territory_enter", "npc_transform"]:
		active.activity_count = int(active.activity_count) + 1
	for goal: Dictionary in _goals.get(int(active.challenge_id), []):
		var type: int = int(goal.get("GoalTypeID", 0))
		var target: int = int(goal.get("GoalClassID", 0))
		var matches: bool = false
		match type:
			1, 261:
				matches = kind == "kill" and (npc_id == target or bool(active.local_policy))
			72, 574:
				matches = kind == "kill" and (_group_member(npc_id, target, context) or bool(active.local_policy))
			3:
				matches = kind == "item_use" and int(input.get("item_id", 0)) == target
			30:
				matches = kind == "territory_enter" and int(input.get("territory_id", 0)) == target
			1011:
				matches = kind == "npc_transform" and npc_id == target
		if matches:
			var key: String = str(goal.ID)
			active.progress[key] = mini(int(goal.Amount), int(active.progress[key]) + 1)
	# A source HP section requires exact source-NPC evidence. Generic local kills
	# never synthesize earlier thresholds or section steps.
	var previous_hp: Variant = input.get("previous_hp_percent")
	var hp: Variant = input.get("hp_percent")
	var maximum_hp: Variant = 100
	# A supplied raw observation is authoritative; incomplete or invalid raw HP
	# must not silently fall back to rounded percentages from the same event.
	if input.has("previous_hp") or input.has("hp") or input.has("max_hp"):
		previous_hp = input.get("previous_hp")
		hp = input.get("hp")
		maximum_hp = input.get("max_hp")
	var hp_crossed: bool = kind == "npc_hp" and has_hp_section_crossing(npc_id, previous_hp, hp, maximum_hp, staged)
	for section: Dictionary in _sections.get(int(active.challenge_id), []):
		var section_id: int = int(section.get("ID", 0))
		if section_id in active.extra_sections or int(section.get("NpcClassID", 0)) != npc_id:
			continue
		var threshold: int = int(section.get("HPPercentThreshold", -1))
		var crossed: bool = kind == "kill" and threshold == 0
		if hp_crossed:
			crossed = _crosses_hp_threshold(section.get("HPPercentThreshold"), int(previous_hp), int(hp), int(maximum_hp))
		if crossed:
			active.extra_sections.append(section_id)
	return _success(staged)

func _crosses_hp_threshold(threshold: Variant, previous_hp: int, hp: int, max_hp: int) -> bool:
	return _integer(threshold, 0, 100) and previous_hp * 100 > int(threshold) * max_hp and hp * 100 <= int(threshold) * max_hp

func _claim(context: Dictionary, staged: Dictionary) -> Dictionary:
	var active: Dictionary = staged.active
	if active.is_empty():
		return _fail("challenge_no_active_run")
	if bool(active.failed):
		return _fail("challenge_run_failed")
	if str(context.get("map_id", "")) != str(active.host_map_id):
		return _fail("challenge_host_map_changed")
	if not _complete(active, context):
		return _fail("challenge_goals_incomplete" if int(context.nowUnix) <= int(active.deadline) else "challenge_time_expired")
	var ids: Array = _rewards.get(int(active.challenge_id), []).duplicate()
	for section_id: Variant in active.extra_sections:
		ids.append_array(_section_rewards.get(int(section_id), []))
	var resolved: Dictionary = _resolve_rewards(ids, context)
	if not bool(resolved.get("ok", false)):
		return _fail(str(resolved.get("error", "challenge_reward_unavailable")))
	var daily: Dictionary = _daily(staged, str(active.day_key), int(active.challenge_id))
	daily.claimed = int(daily.claimed) + 1
	_set_daily(staged, str(active.day_key), int(active.challenge_id), daily)
	staged.active = {}
	return _success(staged, [], resolved.rewards)

func _complete(active: Dictionary, context: Dictionary) -> bool:
	var groups: Dictionary = {}
	for goal: Dictionary in _goals.get(int(active.challenge_id), []):
		var group: int = int(goal.get("GoalGroup", 0))
		var achieved: bool = int(active.progress.get(str(goal.ID), 0)) >= int(goal.get("Amount", 1))
		groups[group] = bool(groups.get(group, true)) and achieved
	# Group 0 is mandatory; positive groups represent alternative success routes.
	if groups.has(0) and not bool(groups[0]):
		return false
	var alternative: bool = false
	var positive: bool = false
	for group: Variant in groups:
		if int(group) > 0:
			positive = true
			alternative = alternative or bool(groups[group])
	return not groups.is_empty() and (not positive or alternative)

func _expire(staged: Dictionary, context: Dictionary) -> void:
	if not staged.active.is_empty() and int(context.nowUnix) > int(staged.active.deadline) and not _complete(staged.active, context):
		staged.active.failed = true

func _instant_price(challenge_id: int, context: Dictionary) -> Dictionary:
	var purchase: Dictionary = _row("MarketPurchase_Korean", int(_challenges[challenge_id].get("ImmediateCompleteMarketPurchaseID", 0)))
	if purchase.is_empty() or not bool(purchase.get("OnSale", false)):
		return _fail("challenge_instant_source_unavailable")
	if _source == null or not _source.has_method("timestamp"):
		return _fail("challenge_source_date_resolver_missing")
	var starts: int = int(_source.call("timestamp", int(purchase.get("EffectiveFromId", 0)), context))
	var ends: int = int(_source.call("timestamp", int(purchase.get("EffectiveToId", 0)), context))
	var now: int = int(context.get("nowUnix", 0))
	if starts < 0 or ends < 0 or (starts > 0 and now < starts) or (ends > 0 and now >= ends):
		return _fail("challenge_instant_source_date_inactive")
	var linked: bool = false
	for product_link: Dictionary in _rows("MarketPurchaseProduct"):
		if int(product_link.get("MarketPurchaseID", 0)) != int(purchase.ID):
			continue
		var product: Dictionary = _row("MarketProduct", int(product_link.get("MarketProductID", 0)))
		if int(product.get("UnitID", 0)) == 42 and int(product.get("ClassID", 0)) == challenge_id and int(product.get("Amount", 0)) == 1:
			linked = true
	if not linked:
		return _fail("challenge_instant_product_mismatch")
	return _payment_price(_row("MarketPayment_Korean", int(purchase.get("MarketPaymentID", 0))))

func _retry_price() -> Dictionary:
	var payment: Dictionary = _row("MarketPayment_Korean", RETRY_PAYMENT_ID)
	if str(payment.get("UniqueKey", "")) != "challenge_try_gem_1" or int(payment.get("Amount", 0)) != 20:
		return _fail("challenge_retry_source_mismatch")
	return _payment_price(payment)

func _payment_price(payment: Dictionary) -> Dictionary:
	var currency_id: int = 0
	if int(payment.get("UnitID", 0)) == 201:
		currency_id = int(payment.get("ClassID", 0))
	else:
		for mapping: Dictionary in _rows("CurrencyUnitClass"):
			if int(mapping.get("UnitID", -1)) == int(payment.get("UnitID", 0)) and int(mapping.get("ClassID", -1)) == int(payment.get("ClassID", 0)):
				currency_id = int(mapping.get("CurrencyID", 0))
				break
	if currency_id <= 0 or not _integer(payment.get("Amount"), 1):
		return _fail("challenge_payment_unsupported")
	return {"ok": true, "cost": {"kind": "currency", "id": currency_id, "amount": int(payment.Amount)}}

func _resolve_rewards(ids: Array, context: Dictionary) -> Dictionary:
	if ids.is_empty() or _source == null or not _source.has_method("resolve_reward"):
		return _fail("challenge_reward_resolver_missing")
	var result: Array = []
	for reward_id: Variant in ids:
		var reward: Dictionary = _row("Reward", int(reward_id))
		if reward.is_empty():
			return _fail("challenge_source_reward_missing")
		# Ranking rewards are not earned by local practice or immediate completion.
		if int(reward.get("Ranking", 0)) > 0:
			continue
		if int(reward.get("CharacterClassID", 0)) != 0 and int(reward.CharacterClassID) != int(context.get("class_id", 0)):
			continue
		var resolved: Dictionary = _source.call("resolve_reward", int(reward_id), context)
		if not bool(resolved.get("ok", false)):
			return _fail(str(resolved.get("error", "challenge_reward_unsupported")))
		result.append_array(resolved.get("rewards", []))
	return {"ok": true, "rewards": result}

func _check_context(context: Dictionary, state: Dictionary) -> String:
	var error: String = validate_state(state)
	if not error.is_empty():
		return error
	if not _integer(context.get("nowUnix"), 1, MAX_UNIX):
		return "challenge_clock_invalid"
	if int(context.nowUnix) < int(state.latest_at):
		return "challenge_clock_rollback"
	var policy: Variant = context.get("time_policy", {})
	if not policy is Dictionary or (policy.has("utc_offset_minutes") and not _integer(policy.utc_offset_minutes, -840, 840)):
		return "challenge_clock_policy_invalid"
	var offset: int = _offset(context)
	if offset < -840 or offset > 840:
		return "challenge_clock_policy_invalid"
	if int(state.reset_offset_minutes) != 1441 and int(state.reset_offset_minutes) != offset:
		return "challenge_clock_policy_changed"
	return ""

func _afford(costs: Array, context: Dictionary) -> String:
	var sums: Dictionary = {}
	for cost: Dictionary in costs:
		var key: String = str(cost.id)
		sums[key] = int(sums.get(key, 0)) + int(cost.amount)
	for key: String in sums:
		if _count(context.get("currencies", {}), int(key)) < int(sums[key]):
			return "challenge_currency_insufficient:%s" % key
	return ""

func _day_key(context: Dictionary) -> String:
	return str(int(floor(float(int(context.get("nowUnix", 0)) + _offset(context) * 60 - RESET_HOUR * 3600) / 86400.0)))

func _offset(context: Dictionary) -> int:
	var policy: Variant = context.get("time_policy", {})
	return int(policy.get("utc_offset_minutes", 540)) if policy is Dictionary else 1442

func _daily(state: Dictionary, day: String, challenge_id: int) -> Dictionary:
	return state.days.get(day, {}).get(str(challenge_id), {"used": 0, "retry_used": 0, "claimed": 0}).duplicate(true)

func _set_daily(state: Dictionary, day: String, challenge_id: int, entry: Dictionary) -> void:
	if not state.days.has(day):
		state.days[day] = {}
	state.days[day][str(challenge_id)] = entry

func _group_member(npc_id: int, group_id: int, context: Dictionary) -> bool:
	for link: Dictionary in _npc_groups.get(npc_id, []):
		if int(link.get("NpcGroupID", 0)) == group_id and _region_allowed(int(link.get("ServerLimitSetID", 0)), context):
			return true
	return false

func _section_for(challenge_id: int, section_id: int) -> bool:
	for section: Dictionary in _sections.get(challenge_id, []):
		if int(section.get("ID", 0)) == section_id:
			return true
	return false

func _goal_label(challenge_id: int) -> String:
	var labels: PackedStringArray = []
	for goal: Dictionary in _goals.get(challenge_id, []):
		labels.append("%s:%d ×%d" % [str(_row("GoalType", int(goal.get("GoalTypeID", 0))).get("Name", goal.get("GoalTypeID", 0))), int(goal.get("GoalClassID", 0)), int(goal.get("Amount", 0))])
	return ", ".join(labels)

func _progress_label(active: Dictionary) -> String:
	var labels: PackedStringArray = []
	for goal: Dictionary in _goals.get(int(active.challenge_id), []):
		labels.append("%d: %d/%d" % [int(goal.ID), int(active.progress.get(str(goal.ID), 0)), int(goal.get("Amount", 0))])
	return " · ".join(labels)

func _rows(table: String) -> Array:
	if not _tables.has(table):
		var value: Variant = _source.call("rows", table) if _source != null and _source.has_method("rows") else []
		_tables[table] = value if value is Array else []
	return _tables[table]

func _row(table: String, id: int) -> Dictionary:
	if not _index.has(table):
		var index: Dictionary = {}
		for row: Dictionary in _rows(table):
			var row_id: int = int(row.get("ID", 0))
			index[row_id] = {} if index.has(row_id) else row
		_index[table] = index
	return _index[table].get(id, {})

func _region_allowed(set_id: int, context: Dictionary) -> bool:
	if set_id == 0:
		return true
	return bool(_source.call("region_allowed", set_id, context)) if _source != null and _source.has_method("region_allowed") else false

func _append(index: Dictionary, key: Variant, value: Variant) -> void:
	if not index.has(key):
		index[key] = []
	index[key].append(value)

func _integer(value: Variant, low: int, high: int = 9007199254740991) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func _count(values: Variant, id: int) -> int:
	return int(values.get(str(id), values.get(id, 0))) if values is Dictionary else 0

func _success(state: Dictionary, costs: Array = [], rewards: Array = []) -> Dictionary:
	return {"ok": true, "error": "", "state": state, "costs": costs, "rewards": rewards}

func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
