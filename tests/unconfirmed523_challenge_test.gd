extends SceneTree

const Domain = preload("res://scripts/unconfirmed523/challenge_domain.gd")
const Source = preload("res://scripts/unconfirmed523/source523.gd")
var checked: int = 0
var failures: Array[String] = []

class Fixture extends RefCounted:
	var data: Dictionary = {}
	func rows(table: String) -> Array:
		return data.get(table, [])
	func timestamp(id: int, _context: Dictionary = {}) -> int:
		return 0 if id == 0 else (1451606400 if id == 1 else 4102444800)
	func region_allowed(id: int, context: Dictionary = {}) -> bool:
		return id == 0 or int(context.get("world_no", 1)) == 1
	func resolve_reward(id: int, _context: Dictionary = {}) -> Dictionary:
		for row: Dictionary in rows("Reward"):
			if int(row.ID) == id:
				return {"ok": true, "rewards": [{"kind": "experience" if int(row.RewardTypeID) == 1 else "item", "id": int(row.RewardClassID), "amount": int(row.Amount), "source_reward_id": id}]}
		return {"ok": false, "error": "fixture_reward_missing"}

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checked += 1
	if not value:
		failures.append(label)
		printerr("CHALLENGE_FAIL: " + label)

func _context(level: int = 40) -> Dictionary:
	return {"nowUnix": 1793764800, "level": level, "class_id": 1, "region": "KR", "service_region": "KR", "world_no": 1,
		"time_policy": {"utc_offset_minutes": 0}, "map_id": "aden", "owned": {}, "currencies": {"4": 100, "764": 10},
		"ain": {"blessing": 200, "dragon_orb_expires_at": 0, "auto_recharge": true},
		"boss_quest": {"claimed": {"preserve": true}, "boss_spawn": 123}, "event_counters": {}}

func _start(domain, id: int, context: Dictionary, state: Dictionary, retry: bool = false) -> Dictionary:
	return domain.propose({"op": "challenge_start", "challenge_id": id, "local_policy": true, "retry": retry}, context, state)

func _kill(domain, context: Dictionary, state: Dictionary, serial: int, npc_id: int = 999) -> Dictionary:
	return domain.event({"kind": "kill", "npc_id": npc_id, "event_id": "kill:%d" % serial, "player_credit": true}, context, state)

func _run() -> void:
	var domain = Domain.new()
	domain.setup(_fixture())
	_exercise(domain)
	_hp_crossings(domain)
	var directory: String = OS.get_environment("TWILIGHT_SOURCE523_DIR")
	if not directory.is_empty():
		var source = Source.new()
		var loaded: Dictionary = source.configure_directory(directory)
		_check(bool(loaded.get("ok", false)), "original source directory loads")
		if bool(loaded.get("ok", false)):
			var actual = Domain.new()
			actual.setup(source)
			_source_contract(actual, source)
	else:
		print("CHALLENGE_SOURCE523_NOT_RUN: set TWILIGHT_SOURCE523_DIR and TWILIGHT_523_ALLOW_TEST_SOURCE=1")
	if failures.is_empty():
		print("UNCONFIRMED523_CHALLENGE_OK: %d assertions" % checked)
		quit(0)
	else:
		printerr("UNCONFIRMED523_CHALLENGE_FAILED: " + ", ".join(failures))
		quit(1)

func _exercise(domain) -> void:
	var context: Dictionary = _context()
	var initial: Dictionary = domain.initial_state()
	_check(domain.validate_state(initial).is_empty(), "initial state valid")
	var before: Dictionary = initial.duplicate(true)
	var context_before: Dictionary = context.duplicate(true)
	domain.view(context, initial)
	domain.view(context, initial)
	_check(initial == before and context == context_before, "view pure including boss quest and blessing")
	_check(domain.propose({"op": "challenge_start", "challenge_id": 5}, context, initial).get("error") == "challenge_current_map_policy_opt_in_required", "local current-map hosting explicit opt-in")
	_check(_start(domain, 999999, context, initial).get("error") == "challenge_source_id_missing", "unknown sourceID rejected")
	context.level = 39
	_check(_start(domain, 5, context, initial).get("error") == "challenge_level_below_40", "official level40 unlock")
	context.level = 52
	_check(_start(domain, 5, context, initial).get("error") == "challenge_source_max_level", "source level variant maximum")
	context = _context()
	context.ain.blessing = 19
	_check(_start(domain, 5, context, initial).get("error") == "challenge_blessing_insufficient", "blessing shortage cannot start")
	context = _context()
	var started: Dictionary = _start(domain, 5, context, initial)
	_check(bool(started.get("ok", false)), "Baphomet fixture starts")
	if not bool(started.get("ok", false)):
		return
	_check(int(started.ain.blessing) == 180 and started.costs.is_empty() and started.rewards.is_empty(), "entry blessing charged only in staged proposal")
	_check(initial == before and context == context_before, "start preserves input and unrelated boss state")
	var state: Dictionary = started.state
	_check(domain.validate_state(state).is_empty(), "active timer validates")
	_check(_start(domain, 8, context, state).get("error") == "challenge_run_already_active", "cannot start second run")
	_check(domain.propose({"op": "challenge_claim"}, context, state).get("error") == "challenge_goals_incomplete", "no free completion")
	_check(domain.event({"kind": "kill", "npc_id": 858}, context, state).get("error") == "challenge_event_id_required", "events require replay identity")
	var uncredited: Dictionary = domain.event({"kind": "kill", "npc_id": 858, "event_id": "uncredited", "player_credit": false}, context, state)
	_check(bool(uncredited.get("ok", false)) and int(uncredited.state.active.progress["2"]) == 0, "uncredited kill cannot progress")
	var killed: Dictionary = _kill(domain, context, state, 1)
	_check(bool(killed.get("ok", false)) and killed.rewards.is_empty() and killed.costs.is_empty() and int(killed.state.active.progress["2"]) == 1, "real kill advances opted local kill goal without ordinary loot")
	_check(domain.event({"kind": "kill", "npc_id": 999, "event_id": "kill:1"}, context, killed.state).get("error") == "challenge_event_duplicate", "same kill cannot replay")
	var claimed: Dictionary = domain.propose({"op": "challenge_claim"}, context, killed.state)
	_check(bool(claimed.get("ok", false)) and claimed.state.active.is_empty() and claimed.rewards.size() == 2, "source completion rewards claimed once")
	_check(domain.propose({"op": "challenge_claim"}, context, claimed.state).get("error") == "challenge_no_active_run", "duplicate claim rejected")
	var moved: Dictionary = context.duplicate(true)
	moved.map_id = "other"
	_check(domain.propose({"op": "challenge_claim"}, moved, killed.state).get("error") == "challenge_host_map_changed", "completed claim checks host map directly")
	var delayed: Dictionary = context.duplicate(true)
	delayed.nowUnix = int(context.nowUnix) + 600
	_check(bool(domain.propose({"op": "challenge_claim"}, delayed, killed.state).get("ok", false)), "completed-before-deadline proof allows delayed claim")
	_check(_start(domain, 5, context, claimed.state).get("error") == "challenge_retry_confirmation_required", "daily retry requires explicit choice")
	var retry: Dictionary = _start(domain, 5, context, claimed.state, true)
	_check(bool(retry.get("ok", false)) and retry.costs == [{"kind": "currency", "id": 4, "amount": 20}], "retry exact source first-tier gem20 cost")
	var abandoned: Dictionary = domain.propose({"op": "challenge_abandon"}, context, retry.state)
	_check(bool(abandoned.get("ok", false)) and abandoned.rewards.is_empty(), "abandon grants no reward and consumes attempt")
	_check(_start(domain, 5, context, abandoned.state, true).get("error") == "challenge_daily_attempts_exhausted", "additional retry cap enforced")
	context.currencies["4"] = 19
	_check(_start(domain, 5, context, claimed.state, true).get("error") == "challenge_currency_insufficient:4", "retry shortage rejected")
	context = _context()
	var treasure: Dictionary = _start(domain, 8, context, initial)
	state = treasure.state
	for serial: int in range(4):
		state = _kill(domain, context, state, serial).state
	_check(domain.propose({"op": "challenge_claim"}, context, state).get("error") == "challenge_goals_incomplete", "Ghast requires all five real kills")
	state = _kill(domain, context, state, 4).state
	_check(bool(domain.propose({"op": "challenge_claim"}, context, state).get("ok", false)), "Ghast completes fifth kill")
	var escape: Dictionary = _start(domain, 14, context, initial)
	state = _kill(domain, context, escape.state, 1).state
	_check(domain.propose({"op": "challenge_claim"}, context, state).get("error") == "challenge_goals_incomplete", "territory escape never counted as arbitrary kill")
	state = domain.event({"kind": "territory_enter", "territory_id": 999, "event_id": "wrong-exit"}, context, state).state
	_check(int(state.active.progress["16"]) == 0, "wrong source territory rejected")
	state = domain.event({"kind": "territory_enter", "territory_id": 2131, "event_id": "exit"}, context, state).state
	_check(bool(domain.propose({"op": "challenge_claim"}, context, state).get("ok", false)), "typed source territory escape completes")
	var timed: Dictionary = _start(domain, 8, context, initial)
	context.nowUnix = int(context.nowUnix) + 303
	var late: Dictionary = _kill(domain, context, timed.state, 1)
	_check(bool(late.get("ok", false)) and bool(late.state.active.failed) and int(late.state.active.progress["3"]) == 0, "late kill cannot progress expired run")
	_check(domain.propose({"op": "challenge_claim"}, context, late.state).get("error") == "challenge_run_failed", "expired run cannot claim")
	context.nowUnix = int(context.nowUnix) - 1
	_check(_kill(domain, context, late.state, 2).get("error") == "challenge_clock_rollback", "clock rollback rejected")
	context = _context()
	state = _start(domain, 5, context, initial).state
	context.map_id = "other"
	_check(bool(_kill(domain, context, state, 1).state.active.failed), "real local host map boundary enforced")
	context = _context()
	state = _start(domain, 5, context, initial).state
	state = domain.event({"kind": "player_death", "event_id": "death"}, context, state).state
	_check(bool(state.active.failed), "player death fails local run")
	state = _start(domain, 164, context, initial).state
	state = _kill(domain, context, state, 1, 40494).state
	_check(bool(state.active.failed), "source defended-NPC death fails run")
	context = _context()
	var instant: Dictionary = domain.propose({"op": "challenge_instant", "challenge_id": 701}, context, initial)
	_check(bool(instant.get("ok", false)) and instant.costs == [{"kind": "currency", "id": 764, "amount": 3}] and instant.rewards.size() == 2 and instant.state.active.is_empty() and int(instant.ain.blessing) == 180, "instant uses source currency764x3 blessing and completion only")
	context.currencies["764"] = 2
	_check(domain.propose({"op": "challenge_instant", "challenge_id": 701}, context, initial).get("error") == "challenge_currency_insufficient:764", "instant shortage rejects atomically")
	context = _context()
	state = _start(domain, 701, context, initial).state
	state = _kill(domain, context, state, 1).state
	_check(state.active.extra_sections.is_empty(), "generic local kill grants no HP-section play reward")
	_check(domain.propose({"op": "challenge_claim"}, context, state).rewards.size() == 2, "mimic alternative final kill route completes without survival route")
	state = _start(domain, 701, context, initial).state
	state = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp_percent": 100, "hp_percent": 50, "event_id": "hp66"}, context, state).state
	state = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp_percent": 50, "hp_percent": 20, "event_id": "hp33"}, context, state).state
	state = _kill(domain, context, state, 1, 101781).state
	_check(state.active.extra_sections.size() == 3, "exact NPC crosses three source play reward sections")
	var play: Dictionary = domain.propose({"op": "challenge_claim"}, context, state)
	_check(bool(play.get("ok", false)) and play.rewards.size() == 5, "play reward distinct from direct completion")
	_check(domain.propose({"op": "challenge_claim"}, context, play.state).get("error") == "challenge_no_active_run", "play sections cannot replay through claim")
	state = _start(domain, 701, context, initial).state
	state = domain.event({"kind": "npc_transform", "npc_id": 102331, "event_id": "transform"}, context, state).state
	for second: int in range(1, 60):
		context.nowUnix = int(state.active.started_at) + second
		state = domain.event({"kind": "survival_tick", "event_id": "alive:%d" % second, "alive": true}, context, state).state
	_check(domain.propose({"op": "challenge_claim"}, context, state).get("error") == "challenge_goals_incomplete", "live survival cannot finish before exact deadline")
	# Recreate persisted domain/state before the final tick, as a same-time restart.
	var restored = Domain.new()
	restored.setup(_fixture())
	state = JSON.parse_string(JSON.stringify(state))
	var restored_error: String = restored.validate_state(state)
	_check(restored_error.is_empty(), "persisted survival progress restores with source IDs: " + restored_error)
	if not restored_error.is_empty():
		return
	context.nowUnix = int(state.active.deadline)
	state = restored.event({"kind": "survival_tick", "event_id": "alive:60", "alive": true}, context, state).state
	_check(int(state.active.progress["113011"]) == 1 and int(state.active.progress["112981"]) == 0, "continuous real live ticks complete survival alternative at deadline")
	_check(bool(restored.propose({"op": "challenge_claim"}, context, state).get("ok", false)), "transform and observed survival route claims completion")
	context = _context()
	state = _start(domain, 701, context, initial).state
	state = domain.event({"kind": "npc_transform", "npc_id": 102331, "event_id": "transform"}, context, state).state
	context.nowUnix = int(state.active.deadline)
	state = domain.event({"kind": "survival_tick", "event_id": "offline-resume", "alive": true}, context, state).state
	_check(int(state.active.progress["113011"]) == 0 and int(state.active.alive_observed) == 0, "offline elapsed time cannot synthesize survival")
	context.nowUnix = int(context.nowUnix) + 1
	state = domain.propose({"op": "observe"}, context, state).state
	_check(bool(state.active.failed), "offline incomplete route expires on observe")
	context = _context()
	state = _start(domain, 701, context, initial).state
	state = domain.event({"kind": "npc_transform", "npc_id": 102331, "event_id": "transform"}, context, state).state
	context.nowUnix = int(context.nowUnix) + 30
	state = domain.event({"kind": "player_death", "event_id": "survival-death"}, context, state).state
	_check(bool(state.active.failed) and domain.propose({"op": "challenge_claim"}, context, state).get("error") == "challenge_run_failed", "death interrupts survival before deadline")
	context = _context()
	state = _start(domain, 5, context, initial).state
	state = domain.event({"kind": "map_change", "map_id": "other", "event_id": "leave"}, context, state).state
	_check(bool(state.active.failed), "leaving and returning cannot preserve a local host run")
	var corrupt: Dictionary = _start(domain, 5, context, initial).state
	corrupt.active.deadline = int(corrupt.active.deadline) + 1
	_check(not domain.validate_state(corrupt).is_empty(), "forged source timer rejected")
	corrupt = _start(domain, 5, context, initial).state
	corrupt.days[corrupt.active.day_key]["5"].claimed = 1
	_check(domain.validate_state(corrupt) == "challenge_active_consumed_attempt_missing", "active save requires outstanding consumed attempt")
	corrupt = _start(domain, 5, context, initial).state
	corrupt.active.host_map_id = ""
	_check(not domain.validate_state(corrupt).is_empty(), "empty saved current-map host rejected")
	corrupt = initial.duplicate(true)
	corrupt.next_run_id = 1.5
	_check(not domain.validate_state(corrupt).is_empty(), "fractional save counter rejected")
	context.nowUnix = int(Time.get_unix_time_from_datetime_string("2026-11-04T04:59:59"))
	state = _start(domain, 5, context, initial).state
	state = domain.propose({"op": "challenge_abandon"}, context, state).state
	_check(_start(domain, 5, context, state).get("error") == "challenge_retry_confirmation_required", "before05 same daily entry")
	context.nowUnix = int(context.nowUnix) + 1
	_check(bool(_start(domain, 5, context, state).get("ok", false)), "exact05 daily reset")
	context.time_policy.utc_offset_minutes = 60
	_check(_start(domain, 5, context, state).get("error") == "challenge_clock_policy_changed", "timezone edits cannot mint fresh attempts")
	context.time_policy.utc_offset_minutes = 0.5
	_check(_start(domain, 5, context, state).get("error") == "challenge_clock_policy_invalid", "fractional timezone offset rejected")

func _hp_crossings(domain) -> void:
	var context: Dictionary = _context()
	var state: Dictionary = _start(domain, 701, context, domain.initial_state()).state
	var before: Dictionary = state.duplicate(true)
	_check(domain.has_hp_section_crossing(101781, 200, 199, 303, state), "raw HP crosses66 without rounded-percent loss")
	_check(not domain.has_hp_section_crossing(101781, 201, 200, 303, state), "raw HP still above66 does not cross early")
	_check(domain.has_hp_section_crossing(101781, 199, 198, 300, state), "raw exact66 boundary inclusive")
	_check(not domain.has_hp_section_crossing(101781, 198, 197, 300, state), "raw already-at-threshold does not cross again")
	_check(domain.has_hp_section_crossing(101781, 5944751508129055, 5944751508129054, 9007199254740991, state), "bounded large HP crossproducts remain exact")
	_check(domain.has_hp_section_crossing(101781, 200.0, 199.0, 303.0, state), "integral JSON HP supported")
	_check(not domain.has_hp_section_crossing(999, 100, 0, 100, state), "unknown source NPC cannot award sections")
	_check(not domain.has_hp_section_crossing(101781, 100, 0, 100, domain.initial_state()), "no active run has no pending HP sections")
	_check(not domain.has_hp_section_crossing(101781, 100, 0, 100, {}), "invalid state cannot expose HP crossing")
	var failed: Dictionary = state.duplicate(true)
	failed.active.failed = true
	_check(not domain.has_hp_section_crossing(101781, 100, 0, 100, failed), "failed run has no pending HP sections")
	var invalid: Array = [
		[50, 50, 100], [50, 60, 100], [100, 50, 0], [100, 50, -1],
		[101, 50, 100], [100, 101, 100], [100, -1, 100], [-1, 0, 100],
		[100, 50.5, 100], [100.5, 50, 101], [100, 50, 100.5],
		[100, 50, 9007199254740992], [100, NAN, 100], [100, 50, INF],
		[true, 0, 100], [100, "50", 100], [100, 50, null]]
	for index: int in range(invalid.size()):
		var values: Array = invalid[index]
		_check(not domain.has_hp_section_crossing(101781, values[0], values[1], values[2], state), "invalid/healing HP observation ignored %d" % index)
	_check(state == before, "HP observer predicate preserves complete input state")
	var above: Dictionary = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 201, "hp": 200, "max_hp": 303,
		"previous_hp_percent": 100, "hp_percent": 0, "event_id": "raw-above"}, context, state)
	_check(bool(above.get("ok", false)) and above.state.active.extra_sections.is_empty(), "raw HP overrides rounded legacy percentages")
	var malformed: Dictionary = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 100,
		"previous_hp_percent": 100, "hp_percent": 0, "event_id": "raw-incomplete"}, context, state)
	_check(bool(malformed.get("ok", false)) and malformed.state.active.extra_sections.is_empty(), "incomplete raw HP cannot fall back to legacy percentages")
	var crossed: Dictionary = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 200, "hp": 199, "max_hp": 303, "event_id": "raw66"}, context, state)
	_check(bool(crossed.get("ok", false)) and crossed.state.active.extra_sections == [61], "raw event awards exact66 section only")
	_check(state == before, "raw HP event proposal preserves source state")
	state = crossed.state
	_check(not domain.has_hp_section_crossing(101781, 200, 199, 303, state), "already-earned crossing is filtered before World event emission")
	_check(domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 200, "hp": 199, "max_hp": 303, "event_id": "raw66"}, context, state).get("error") == "challenge_event_duplicate", "raw HP event replay identity rejected")
	state = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 200, "hp": 199, "max_hp": 303, "event_id": "raw66-again"}, context, state).state
	_check(state.active.extra_sections == [61], "different event identity cannot duplicate earned HP section")
	_check(domain.has_hp_section_crossing(101781, 100, 99, 300, state), "pending exact33 crossing remains available")
	state = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 100, "hp": 99, "max_hp": 300, "event_id": "raw33"}, context, state).state
	_check(state.active.extra_sections == [61, 71], "raw event awards exact33 section")
	_check(domain.has_hp_section_crossing(101781, 1, 0, 300, state), "raw lethal HP crossing preserves zero section")
	state = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 1, "hp": 0, "max_hp": 300, "event_id": "raw0"}, context, state).state
	state = _kill(domain, context, state, 1, 101781).state
	_check(state.active.extra_sections == [61, 71, 81], "following exact-NPC kill cannot duplicate raw zero section")
	_check(not domain.has_hp_section_crossing(101781, 300, 0, 300, state), "no event emitted after all matching sections earned")
	var play: Dictionary = domain.propose({"op": "challenge_claim"}, context, state)
	_check(bool(play.get("ok", false)) and play.rewards.size() == 5, "raw HP sections flow through normal completion reward transaction")
	state = _start(domain, 701, context, domain.initial_state()).state
	state = _kill(domain, context, state, 1, 101781).state
	_check(state.active.extra_sections == [81], "exact-NPC kill retains zero-only fallback without HP history")
	state = _start(domain, 701, context, domain.initial_state()).state
	state = domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 300, "hp": 0, "max_hp": 300, "event_id": "one-hit"}, context, state).state
	_check(state.active.extra_sections == [61, 71, 81], "one real HP hit can cross every pending section")
	var duplicate_fixture: Fixture = _fixture()
	duplicate_fixture.data.ChallengeExtraRewardSection.append(duplicate_fixture.data.ChallengeExtraRewardSection[0].duplicate(true))
	var duplicate_domain = Domain.new()
	duplicate_domain.setup(duplicate_fixture)
	state = _start(duplicate_domain, 701, context, duplicate_domain.initial_state()).state
	state = duplicate_domain.event({"kind": "npc_hp", "npc_id": 101781, "previous_hp": 300, "hp": 0, "max_hp": 300, "event_id": "duplicate-section"}, context, state).state
	_check(state.active.extra_sections == [61, 71, 81] and duplicate_domain.validate_state(state).is_empty(), "duplicate source section ID awards once")

func _source_contract(domain, source) -> void:
	var context: Dictionary = _context()
	var initial: Dictionary = domain.initial_state()
	var rows: Array = source.rows("Challenge")
	_check(rows.size() == 69 and domain._challenges.size() == 69, "all69 original Challenge rows retained")
	_check(source.rows("ChallengeGoal").size() == 82 and source.rows("ChallengeGoalView").size() == 82, "all82 goal and view joins present")
	_check(source.rows("ChallengePrerequisite").size() == 77 and source.rows("ChallengeFailureCondition").size() == 4, "all77 prerequisites and4 failure links present")
	_check(source.rows("ChallengeReward").size() == 217 and source.rows("ChallengeExtraReward").size() == 108 and source.rows("ChallengeExtraRewardSection").size() == 27, "completion217 play108 section27 source count")
	var active_count: int = 0
	for row: Dictionary in rows:
		var id: int = int(row.ID)
		var metadata: Dictionary = domain.metadata(id)
		_check(metadata.source == row and int(metadata.dungeon_category_id) == 21, "source metadata preserved %d" % id)
		var expected_goals: int = 0
		var expected_prerequisites: int = 0
		for link: Dictionary in source.rows("ChallengeGoal"):
			if int(link.ChallengeID) == id:
				expected_goals += 1
		for link: Dictionary in source.rows("ChallengePrerequisite"):
			if int(link.ChallengeID) == id:
				expected_prerequisites += 1
		_check(metadata.goals.size() == expected_goals and metadata.prerequisites.size() == expected_prerequisites, "source joins preserved %d" % id)
		if not bool(row.IsWorking):
			_check(domain.eligibility(id, context) == "challenge_source_inactive", "source inactive gate %d" % id)
			continue
		active_count += 1
		var minimum: int = 40
		var maximum: int = 999
		for prerequisite: Dictionary in metadata.prerequisites:
			if int(prerequisite.PrerequisiteTypeID) == 1:
				minimum = int(prerequisite.Value)
			if int(prerequisite.PrerequisiteTypeID) == 2:
				maximum = int(prerequisite.Value)
		context = _context(minimum)
		_check(domain.eligibility(id, context).is_empty(), "source active minimum inclusive %d" % id)
		context.level = minimum - 1
		_check(not domain.eligibility(id, context).is_empty(), "source min gate %d" % id)
		if maximum < 999:
			context.level = maximum
			_check(domain.eligibility(id, context).is_empty(), "source active max inclusive %d" % id)
			context.level = maximum + 1
			_check(domain.eligibility(id, context) == "challenge_source_max_level", "source max gate %d" % id)
		context = _context(minimum)
		var started: Dictionary = _start(domain, id, context, initial)
		_check(bool(started.get("ok", false)) and int(started.ain.blessing) == 200 - int(row.EinhasadCost), "source active paid start %d" % id)
		if not bool(started.get("ok", false)):
			continue
		var state: Dictionary = started.state
		var count: int = 100 if id in [671, 681, 691] else 1
		for serial: int in range(count):
			var event_result: Dictionary = _kill(domain, context, state, serial)
			_check(bool(event_result.get("ok", false)), "source real kill %d:%d" % [id, serial])
			if bool(event_result.get("ok", false)):
				state = event_result.state
		var claimed: Dictionary = domain.propose({"op": "challenge_claim"}, context, state)
		_check(bool(claimed.get("ok", false)) and claimed.rewards.size() == 2 and int(claimed.rewards[0].amount) == 10000000, "source active completion exp10M andbox %d" % id)
		var instant: Dictionary = domain.propose({"op": "challenge_instant", "challenge_id": id}, context, initial)
		_check(bool(instant.get("ok", false)) and instant.costs == [{"kind": "currency", "id": 764, "amount": 3}] and instant.rewards.size() == 2, "source exact instant price completion-only %d" % id)
		_source_hp_sections(domain, source, id, context, started.state, metadata.play_reward_sections)
	_check(active_count == 6, "only six renewal challenges active")
	_check(domain.view(_context(), initial).rows.size() == 69, "all69 visible without mutating state")
	_check(int(domain.metadata(5).goals[0].GoalClassID) == 858 and int(domain.metadata(8).goals[0].Amount) == 5 and int(domain.metadata(14).goals[0].GoalTypeID) == 30, "Baphomet Ghast prison source identity retained")
	var rejected: Dictionary = domain.propose({"op": "challenge_start", "challenge_id": 5, "local_policy": true}, _context(), initial)
	_check(rejected.get("error") == "challenge_source_inactive", "inactive historical challenge never enabled by local policy")

func _source_hp_sections(domain, source, challenge_id: int, context: Dictionary, state: Dictionary, sections: Array) -> void:
	if sections.is_empty():
		return
	var npcs: Dictionary = {}
	var expected_ids: Array = []
	for section: Dictionary in sections:
		npcs[int(section.NpcClassID)] = true
		expected_ids.append(int(section.ID))
	var before: Dictionary = state.duplicate(true)
	var staged: Dictionary = state
	_check(not domain.has_hp_section_crossing(999, 303, 0, 303, state), "source play sections reject arbitrary local NPC %d" % challenge_id)
	for npc_id: int in npcs:
		_check(domain.has_hp_section_crossing(npc_id, 303, 0, 303, staged), "source NPC has pending raw HP sections %d:%d" % [challenge_id, npc_id])
		var observed: Dictionary = domain.event({"kind": "npc_hp", "npc_id": npc_id, "previous_hp": 303, "hp": 0, "max_hp": 303,
			"event_id": "source-hp:%d:%d" % [challenge_id, npc_id]}, context, staged)
		_check(bool(observed.get("ok", false)), "source raw HP event accepted %d:%d" % [challenge_id, npc_id])
		if not bool(observed.get("ok", false)):
			return
		staged = observed.state
		_check(not domain.has_hp_section_crossing(npc_id, 303, 0, 303, staged), "source earned NPC sections filter further HP events %d:%d" % [challenge_id, npc_id])
	_check(state == before, "source raw HP event transaction preserves input %d" % challenge_id)
	var earned_ids: Array = staged.active.extra_sections.duplicate()
	expected_ids.sort()
	earned_ids.sort()
	_check(earned_ids == expected_ids, "all original HP sections earned from matching source NPCs %d" % challenge_id)
	var extra_count: int = 0
	for link: Dictionary in source.rows("ChallengeExtraReward"):
		if int(link.SectionID) in expected_ids:
			extra_count += 1
	staged = _kill(domain, context, staged, 0).state
	var claimed: Dictionary = domain.propose({"op": "challenge_claim"}, context, staged)
	_check(bool(claimed.get("ok", false)) and claimed.rewards.size() == 2 + extra_count, "all source extra rewards join normal completion once %d" % challenge_id)

func _fixture() -> Fixture:
	var fixture: Fixture = Fixture.new()
	var challenge: Array = []
	for id: int in [5, 8, 14, 164, 671, 701]:
		challenge.append({"ID": id, "Name": "Fixture challenge %d" % id, "IsWorking": true, "TimeLimit": 60 if id == 701 else 302,
			"EinhasadCost": 20, "BaseTryCount": 1, "ServerLimitSetID": 0, "ImmediateCompleteMarketPurchaseID": 105731 if id == 701 else 0})
	fixture.data = {"Challenge": challenge,
		"ChallengeGoal": [{"ChallengeID": 5, "GoalID": 2, "GoalGroup": 0}, {"ChallengeID": 8, "GoalID": 3, "GoalGroup": 0},
			{"ChallengeID": 14, "GoalID": 16, "GoalGroup": 0}, {"ChallengeID": 164, "GoalID": 75524, "GoalGroup": 0},
			{"ChallengeID": 671, "GoalID": 112951, "GoalGroup": 0}, {"ChallengeID": 701, "GoalID": 112981, "GoalGroup": 2},
			{"ChallengeID": 701, "GoalID": 113011, "GoalGroup": 1}, {"ChallengeID": 701, "GoalID": 113051, "GoalGroup": 1}],
		"Goal": [{"ID": 2, "GoalTypeID": 1, "GoalClassID": 858, "Amount": 1}, {"ID": 3, "GoalTypeID": 1, "GoalClassID": 864, "Amount": 5},
			{"ID": 16, "GoalTypeID": 30, "GoalClassID": 2131, "Amount": 1}, {"ID": 75524, "GoalTypeID": 72, "GoalClassID": 10764, "Amount": 80},
			{"ID": 112951, "GoalTypeID": 72, "GoalClassID": 19651, "Amount": 100}, {"ID": 112981, "GoalTypeID": 1, "GoalClassID": 101781, "Amount": 1},
			{"ID": 113011, "GoalTypeID": 1031, "GoalClassID": 701, "Amount": 1}, {"ID": 113051, "GoalTypeID": 1011, "GoalClassID": 102331, "Amount": 1}],
		"ChallengePrerequisite": [{"ChallengeID": 5, "PrerequisiteID": 5}, {"ChallengeID": 5, "PrerequisiteID": 1232}],
		"Prerequisite": [{"ID": 5, "PrerequisiteTypeID": 1, "Value": 40}, {"ID": 1232, "PrerequisiteTypeID": 2, "Value": 51}],
		"ChallengeFailureCondition": [{"ChallengeID": 164, "FailureConditionID": 14}],
		"FailureCondition": [{"ID": 14, "FailureConditionTypeID": 4, "FailureConditionClassID": 40494, "Amount": 1}],
		"ChallengeReward": [], "Reward": [{"ID": 549, "RewardTypeID": 1, "RewardClassID": 281, "Amount": 10000000},
			{"ID": 381101, "RewardTypeID": 2, "RewardClassID": 344731, "Amount": 1}, {"ID": 389201, "RewardTypeID": 2, "RewardClassID": 3242, "Amount": 10}],
		"ChallengeExtraRewardSection": [{"ID": 61, "ChallengeID": 701, "NpcClassID": 101781, "HPPercentThreshold": 66},
			{"ID": 71, "ChallengeID": 701, "NpcClassID": 101781, "HPPercentThreshold": 33}, {"ID": 81, "ChallengeID": 701, "NpcClassID": 101781, "HPPercentThreshold": 0}],
		"ChallengeExtraReward": [{"ID": 1, "SectionID": 61, "RewardID": 389201}, {"ID": 11, "SectionID": 71, "RewardID": 389201}, {"ID": 21, "SectionID": 81, "RewardID": 389201}],
		"MarketPayment_Korean": [{"ID": 51, "UniqueKey": "challenge_try_gem_1", "UnitID": 34, "ClassID": 2, "Amount": 20},
			{"ID": 114121, "UnitID": 201, "ClassID": 764, "Amount": 3}],
		"CurrencyUnitClass": [{"ID": 45, "UnitID": 34, "ClassID": 2, "CurrencyID": 4}],
		"MarketPurchase_Korean": [{"ID": 105731, "MarketPaymentID": 114121, "OnSale": true, "EffectiveFromId": 1, "EffectiveToId": 3}],
		"MarketPurchaseProduct": [{"MarketPurchaseID": 105731, "MarketProductID": 149351}],
		"MarketProduct": [{"ID": 149351, "UnitID": 42, "ClassID": 701, "Amount": 1}]}
	for id: int in [5, 8, 14, 164, 671, 701]:
		fixture.data.ChallengeReward.append({"ChallengeID": id, "RewardID": 549})
		fixture.data.ChallengeReward.append({"ChallengeID": id, "RewardID": 381101})
	return fixture
