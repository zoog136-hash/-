extends SceneTree
## Focused domain regression tests. Real-source assertions run only with the
## user's private source directory; synthetic fixtures are explicitly separate.
const EVENTS = preload("res://scripts/unconfirmed523/events_domain.gd")
const SOURCE = preload("res://scripts/unconfirmed523/source523.gd")
var failures: Array[String] = []
var checks: int = 0

class FixtureSource extends RefCounted:
	var tables: Dictionary = {}
	var blocked_items: Array = []
	var blocked_reason: String = "fixture blocked source item"
	func rows(table: String) -> Array:
		return tables.get(table, [])
	func row(table: String, id: int) -> Dictionary:
		for entry in rows(table):
			if int(entry.get("ID", 0)) == id:
				return entry
		return {}
	func item_eligibility(id: int, _context: Dictionary) -> Dictionary:
		return {"ok": id not in blocked_items, "error": blocked_reason}
	func resolve_reward(id: int, _context: Dictionary, selection: Dictionary, _rng: RandomNumberGenerator) -> Dictionary:
		if id == 555:
			return {"ok": true, "rewards": [{"kind": "pass_exp", "id": 50, "amount": 10}]}
		if id == 999:
			return {"ok": false, "error": "fixture unsupported native reward"}
		if id == 888 and selection.get("888", []) != [2]:
			return {"ok": false, "error": "fixture explicit selection required"}
		return {"ok": true, "rewards": [{"kind": "item", "id": id, "amount": 1}]}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EVENTS523_FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_synthetic_edges()
	_synthetic_final_edges()
	_synthetic_seven_unit_cube()
	var directory := OS.get_environment("TWILIGHT_523_SOURCE_DIR")
	if not directory.is_empty():
		_real_source(directory)
	else:
		print("EVENTS523_REAL_SOURCE_SKIPPED: TWILIGHT_523_SOURCE_DIR not set")
	print("EVENTS523_", "PASS" if failures.is_empty() else "FAIL", " checks=", checks)
	quit(0 if failures.is_empty() else 1)

func _context() -> Dictionary:
	return {"now": Time.get_unix_time_from_datetime_string("2026-11-04T12:00:00"), "level": 90, "class_id": 1, "region": "KR", "service_region": "KR", "world_no": 1, "owned": {}, "currencies": {"1": 5000000, "4": 5000}, "pass_exp": {}, "completed_quests": {}, "event_counters": {}, "time_policy": {"utc_offset_minutes": 0}, "twilight_policy": {"luckybag_random_mode": "source_weights", "attendance_blessing_base": 200}}

func _container_view(domain: Object, context: Dictionary, state: Dictionary, item_id: int) -> Dictionary:
	for row in domain.view(context, state).rows:
		if str(row.id) == "container:%d" % item_id:
			return row
	return {}

func _synthetic_edges() -> void:
	# These deliberately tiny fixtures test invariants, not original content.
	var source := FixtureSource.new()
	source.tables = {
		"PassSystem": [{"ID": 50, "PassSystemTypeID": 12, "IsActive": true, "PassSystemQuestListID": 60, "PassSystemDailyQuestListID": 0}],
		"PassSystemQuest": [{"ID": 61, "PassSystemQuestListID": 60, "QuestID": 70}],
		"PassSystemLevel": [{"ID": 901, "PassSystemID": 50, "Level": 1, "Experience": 10, "RewardID": 777, "PremiumRewardID": 777}],
		"QuestView": [{"ID": 70, "TypeID": 102, "QuestResetType": 11}],
		"QuestGoal": [{"QuestID": 70, "GoalID": 80, "GoalPredicateTypeID": 1}],
		"Goal": [{"ID": 80, "GoalTypeID": 62, "Amount": 2}],
		"QuestReward": [{"QuestID": 70, "RewardID": 555}],
		"AttendanceVersion": [{"ID": 8, "AttendanceTypeID": 1, "Version": 39, "ServiceRegionCode": "KR"}],
		"AttendanceReward": [{"AttendanceVersionID": 8, "RewardIndex": 1, "RewardID": 999, "Goal": 0, "ServerLimitSetID": 0}],
		"ItemClass": [{"ID": 10, "Name": "Fixture bag", "CategoryID": 78, "TestItem": false}, {"ID": 11, "Name": "Fixture output"}, {"ID": 12, "Name": "Fixture selected", "CategoryID": 10}],
		"ItemCategory": [{"ID": 78, "IsConsumable": true}],
		"ItemBonus": [{"ItemClassID": 10, "BonusID": 100, "IsPossession": false}],
		"Bonus": [{"ID": 100, "BonusTypeID": 110, "Value": 20}],
		"LuckyBagClass": [{"ID": 20, "AbleMultiple": true}],
		"LuckyBagEntityView": [{"ID": 21, "LuckyBagClassID": 20, "LuckyBagEntityTypeID": 0, "Probability": 500000, "ItemClassID": 11, "ItemAmount": 2, "ItemBlessCodeID": 1, "ItemEnchant": 0, "LimitClass": 10000}, {"ID": 22, "LuckyBagClassID": 20, "LuckyBagEntityTypeID": 3, "Probability": 0, "ItemClassID": 12, "ItemAmount": 1, "ItemBlessCodeID": 2, "ItemEnchant": 3, "LimitClass": 10000}]
	}
	var domain := EVENTS.new()
	domain.setup(source)
	var state := domain.initial_state()
	var original := state.duplicate(true)
	var context := _context()
	var failed := domain.propose({"action": "attendance_claim", "version_id": 8, "index": 1}, context, state)
	check(not failed.ok and state == original, "unsupported reward never advances attendance")
	var corrupt := state.duplicate(true)
	corrupt.rng_state = "invalid"
	check(not domain.validate_state(corrupt).is_empty(), "corrupt RNG rejected")
	corrupt = state.duplicate(true)
	corrupt.passes["1"] = {"experience": 0, "base": false, "premium": true, "claims": {}}
	check(not domain.validate_state(corrupt).is_empty(), "premium without base rejected in persisted state")
	context.owned["10"] = 1
	var context_before_view := context.duplicate(true)
	var allowed_view := _container_view(domain, context, state, 10)
	check(not allowed_view.is_empty() and allowed_view.actions.size() == 1 and not bool(allowed_view.actions[0].get("disabled", false)), "eligible owned bag remains enabled in read-only view")
	source.blocked_items = [11]
	var blocked_view := _container_view(domain, context, state, 10)
	check(blocked_view.actions.size() == 1 and bool(blocked_view.actions[0].get("disabled", false)) and "fixture blocked source item" in str(blocked_view.detail), "owned bag view disables opening with exact shared reward-leaf failure")
	source.blocked_reason = "item_expired"
	var expired_view := _container_view(domain, context, state, 10)
	check(bool(expired_view.actions[0].get("disabled", false)) and "만료된 보상 포함" in str(expired_view.detail) and "item_expired" not in str(expired_view.detail), "owned bag view presents expiration gate in plain Korean")
	source.blocked_reason = "fixture blocked source item"
	check(state == original and context == context_before_view, "bag eligibility view never changes inventory context state or RNG")
	source.blocked_items = []
	source.tables.LuckyBagEntityView[0].ItemAmount = 0
	domain.setup(source)
	var invalid_view := _container_view(domain, context, state, 10)
	check(bool(invalid_view.actions[0].get("disabled", false)) and "원문 상자 보상 아이템" in str(invalid_view.detail), "owned bag view blocks invalid reward definitions using opening guard")
	source.tables.LuckyBagEntityView[0].ItemAmount = 2
	domain.setup(source)
	var request := {"action": "consume_item", "item_id": 10}
	check(not domain.propose(request, context, state).ok, "selectable bag requires explicit choice")
	request["luckybag_selection"] = [22]
	context.twilight_policy.luckybag_random_mode = "strict_10000000"
	check(not domain.propose(request, context, state).ok, "strict mode preserves partial probability bag")
	context.twilight_policy.luckybag_random_mode = "source_weights"
	var opened := domain.propose(request, context, state)
	check(opened.ok and opened.costs == [{"kind": "item", "id": 10, "amount": 1}], "TWILIGHT source-weight draw consumes exactly one owned bag")
	check(opened.ok and opened.rewards.size() == 2 and opened.rewards[0].enchant == 3 and opened.rewards[0].bless_code == 2, "explicit selected item preserves enchant and blessing")
	check(state == original and int(context.owned["10"]) == 1, "proposal leaves caller state and inventory unchanged")
	check(opened.ok and opened.state.rng_state != state.rng_state, "successful lottery stages durable RNG")
	request.luckybag_selection = [22, 22]
	check(not domain.propose(request, context, state).ok, "duplicate selection rejected")
	check(not domain.propose({"action": "consume_item", "item_id": 10.5}, context, state).ok, "fractional item identity rejected")
	source.tables.LuckyBagEntityView[0].LuckyBagEntityTypeID = 2
	domain.setup(source)
	request.luckybag_selection = [22]
	check(not domain.propose(request, context, state).ok, "unsupported final reward preserves bag")
	var played := domain.event({"kind": "kill", "amount": 2}, context, state)
	var quest_claim := domain.propose({"action": "pass_quest_claim", "pass_id": 50, "quest_id": 70}, context, played.state)
	check(quest_claim.ok and domain.validate_state(quest_claim.state).is_empty(), "synthetic completed task survives strong save validation")
	if quest_claim.ok:
		var damaged: Dictionary = quest_claim.state.duplicate(true)
		for token in damaged.quest_progress:
			damaged.quest_progress[token]["80"] = 1
		check(not domain.validate_state(damaged).is_empty(), "claimed task with insufficient saved progress is rejected")
		var old_clock := context.duplicate(true)
		old_clock.now -= 1
		check(not domain.propose({"action": "pass_quest_claim", "pass_id": 50, "quest_id": 70}, old_clock, quest_claim.state).ok, "clock rollback cannot commit an action")
	check(opened.ok and domain.validate_state(JSON.parse_string(JSON.stringify(opened.state))).is_empty(), "JSON save round trip retains valid staged state")
	source.tables.LuckyBagEntityView[0].LuckyBagEntityTypeID = 0
	source.tables.ItemClass[0]["MaxLevelLimitMin"] = 68
	domain.setup(source)
	check(not domain.propose(request, context, state).ok, "missing authoritative maximum level preserves constrained bag")
	context.max_level = 67
	check(not domain.propose(request, context, state).ok, "source maximum level minimum enforced")
	context.max_level = 68
	check(domain.propose(request, context, state).ok, "authoritative maximum level meeting source minimum permits bag")

func _synthetic_final_edges() -> void:
	# Synthetic threshold2 is an explicit local policy, not original content.
	var source := FixtureSource.new()
	source.tables = {
		"ItemClass": [{"ID": 30, "Name": "Fixture final bag", "CategoryID": 78, "MaxStackAmount": 1}, {"ID": 31, "Name": "Fixture ordinary"}, {"ID": 32, "Name": "Fixture final"}],
		"ItemCategory": [{"ID": 78, "IsConsumable": true}],
		"ItemBonus": [{"ItemClassID": 30, "BonusID": 300, "IsPossession": false}],
		"Bonus": [{"ID": 300, "BonusTypeID": 110, "Value": 40}],
		"LuckyBagClass": [{"ID": 40, "AbleMultiple": false}],
		"LuckyBagEntityView": [{"ID": 41, "LuckyBagClassID": 40, "LuckyBagEntityTypeID": 0, "Probability": 10000000, "ItemClassID": 31, "ItemAmount": 1}, {"ID": 42, "LuckyBagClassID": 40, "LuckyBagEntityTypeID": 2, "Probability": 10000000, "ItemClassID": 32, "ItemAmount": 4}]
	}
	var domain := EVENTS.new()
	domain.setup(source)
	var state := domain.initial_state()
	var context := _context()
	context.owned = {"30": 1}
	context.instances = {"fixture-first": {"instance_id": "fixture-first", "sourceID": 30, "quantity": 1, "bless_code": 2, "record": {"source_reward_quantity": 1, "issued_receipt_fixture": {"quantity": 7, "source_sha256": "fixture"}}, "quest_reward_receipt": {"schema": 1, "quantity": 7, "source_sha256": "fixture"}}}
	var request := {"action": "consume_item", "item_id": 30, "instance_id": "fixture-first"}
	check(not domain.propose(request, context, state).ok, "unknown FinalReward threshold never infers all prizes or physical charges")
	context.twilight_policy.luckybag_final_rules = {"40": {"uses": 2, "completion": "once", "scope": "source_item", "final_rewards": "all"}}
	var first := domain.propose(request, context, state)
	check(first.ok and first.rewards.size() == 1 and first.costs == [{"kind": "item", "id": 30, "amount": 1, "instance_id": "fixture-first", "expected_quantity": 1}], "final bag consumes one exact physical unit and delays final reward")
	if not first.ok:
		return
	check(first.state.final_progress["30"].units["fixture-first:1"].source_record.issued_receipt_fixture.quantity == 7, "immutable issued quantity preserved separately from consumed remaining quantity")
	check(first.state.final_progress["30"].units["fixture-first:1"].quest_reward_receipt == context.instances["fixture-first"].quest_reward_receipt, "canonical outer quest receipt retained verbatim")
	check(not domain.propose(request, context, first.state).ok, "same physical unit token cannot count twice")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(first.state))
	check(domain.validate_state(saved).is_empty(), "final consumed-unit receipt survives JSON save and reload")
	context.instances = {"fixture-second": {"instance_id": "fixture-second", "sourceID": 30, "quantity": 1, "bless_code": 1, "record": {"source_reward_quantity": 1}}}
	request.instance_id = ["fixture-second"]
	var before := saved.duplicate(true)
	source.blocked_items = [32]
	var failed := domain.propose(request, context, saved)
	check(not failed.ok and saved == before, "ineligible final leaf fails before cost RNG or progress staging")
	source.blocked_items = []
	var second := domain.propose(request, context, saved)
	check(second.ok and second.rewards.size() == 2 and second.rewards[0].id == 32 and second.rewards[0].amount == 4 and second.state.final_progress["30"].completed == 1, "threshold awards exact final row together with normal draw")
	var retried := domain.propose(request, context, saved)
	check(saved == before and retried.ok and second.ok and retried.rewards == second.rewards, "discarded proposal preserves progress and deterministic RNG for retry")
	if not second.ok:
		return
	context.instances = {"fixture-third": {"instance_id": "fixture-third", "sourceID": 30, "quantity": 1, "record": {}}}
	request.instance_id = "fixture-third"
	var third := domain.propose(request, context, second.state)
	check(third.ok and third.rewards.size() == 1 and third.state.final_progress["30"].completed == 1, "default once policy never repeats final after completion")
	var changed := context.duplicate(true)
	changed.twilight_policy.luckybag_final_rules["40"].uses = 3
	check(not domain.propose(request, changed, second.state).ok, "changing threshold cannot reinterpret existing progress")
	var corrupt: Dictionary = first.state.duplicate(true)
	corrupt.final_progress["30"].units["fixture-first:1"].source_record.issued_receipt_fixture.quantity = 1
	check(not domain.validate_state(corrupt).is_empty(), "edited persisted physical receipt rejected")
	corrupt = first.state.duplicate(true)
	corrupt.final_progress["30"].completed = 1
	check(not domain.validate_state(corrupt).is_empty(), "premature persisted completion rejected")
	var locked := context.duplicate(true)
	locked.instances["fixture-third"].locked = true
	check(not domain.propose(request, locked, second.state).ok, "locked physical bag cannot count toward final reward")
	var stacked := context.duplicate(true)
	stacked.instances = {"fixture-stack": {"instance_id": "fixture-stack", "sourceID": 30, "quantity": 2, "record": {"source_reward_quantity": 2}}}
	request.instance_id = "fixture-stack"
	var stack_first := domain.propose(request, stacked, state)
	stacked.instances["fixture-stack"].quantity = 1
	stacked.instances["fixture-stack"].record.source_reward_quantity = 1
	var stack_second := domain.propose(request, stacked, stack_first.state)
	check(stack_first.ok and stack_second.ok and stack_second.state.final_progress["30"].units.size() == 2, "remaining-quantity token distinguishes two consumed units in a real stack")
	var cycle := context.duplicate(true)
	cycle.twilight_policy.luckybag_final_rules["40"].completion = "cycle"
	var cycle_state := domain.initial_state()
	var cycle_rewards: Array = []
	var cycle_detail := ""
	for index in range(4):
		var uid := "fixture-cycle-%d" % index
		cycle.instances = {uid: {"instance_id": uid, "sourceID": 30, "quantity": 1, "record": {}}}
		var result := domain.propose({"action": "consume_item", "item_id": 30}, cycle, cycle_state)
		if not result.ok:
			break
		cycle_rewards.append(result.rewards.size())
		cycle_state = result.state
		if index == 2:
			for row in domain.view(cycle, cycle_state).rows:
				if str(row.id) == "container:30":
					cycle_detail = str(row.detail)
	check(cycle_rewards == [1, 2, 1, 2] and "1/2" in cycle_detail, "explicit cycle policy repeats only after full cycles and shows current-cycle progress")
	# Exact source metadata names/shapes may be no-ops for opening; lifecycle
	# requirements remain blocked without a dedicated native consumer.
	source.tables.ItemBonus.append({"ItemClassID": 30, "BonusID": 301, "IsPossession": false})
	source.tables.ItemBonus.append({"ItemClassID": 30, "BonusID": 302, "IsPossession": false})
	source.tables.Bonus.append({"ID": 301, "BonusTypeID": 11883, "Value": 1, "BonusApplicationTypeID": 0, "BonusApplicationTargetID": 0})
	source.tables.Bonus.append({"ID": 302, "BonusTypeID": 5253, "Value": 1, "BonusApplicationTypeID": 0, "BonusApplicationTargetID": 0})
	source.tables.BonusType = [{"ID": 11883, "Name": "UIShowFilter"}, {"ID": 5253, "Name": "CannotExtendDeleteTime"}]
	domain.setup(source)
	check(domain.propose(request, stacked, state).ok, "verified visibility and cannot-extend-expiry metadata permit owned opening")
	source.tables.Bonus[1].BonusApplicationTargetID = 1
	domain.setup(source)
	check(not domain.propose(request, stacked, state).ok, "conditional visibility metadata stays blocked")
	source.tables.Bonus[1].BonusApplicationTargetID = 0
	source.tables.Bonus[2].BonusTypeID = 422
	domain.setup(source)
	check(not domain.propose(request, stacked, state).ok, "lifetime restriction stays blocked without authoritative native expiry")
	source.tables.BonusType.append({"ID": 422, "Name": "Life", "UnitID": 17})
	source.tables.Unit = [{"ID": 17, "Name": "Seconds"}]
	source.tables.Bonus[2].Value = 86400
	domain.setup(source)
	stacked.instances["fixture-stack"].record.merge({"issued_at": int(stacked.now), "expires_at": int(stacked.now) + 86400, "source_life_seconds": 86400})
	check(domain.propose(request, stacked, state).ok, "verified native seconds lifetime permits the already-issued exact physical unit")
	var expired := stacked.duplicate(true)
	expired.now += 86400
	check(not domain.propose(request, expired, state).ok, "physical lifetime expiration boundary preserves container without opening")
	expired = stacked.duplicate(true)
	expired.instances["fixture-stack"].record.expires_at += 1
	check(not domain.propose(request, expired, state).ok, "opening cannot extend native lifetime by changing its expiry proof")

func _synthetic_seven_unit_cube() -> void:
	# Deliberately synthetic reward31 replaces the actual blocked TestItem8961.
	# This verifies the observed7-unit rule without claiming original eligibility.
	var source := FixtureSource.new()
	source.tables = {
		"ItemClass": [{"ID": 8951, "Name": "Synthetic seven-use cube", "CategoryID": 78, "MaxStackAmount": 1}, {"ID": 31, "Name": "Synthetic ordinary output"}, {"ID": 8361, "Name": "Synthetic final output"}],
		"ItemCategory": [{"ID": 78, "IsConsumable": true}],
		"ItemBonus": [{"ItemClassID": 8951, "BonusID": 300, "IsPossession": false}, {"ItemClassID": 8951, "BonusID": 301, "IsPossession": false}],
		"Bonus": [{"ID": 300, "BonusTypeID": 110, "Value": 1991}, {"ID": 301, "BonusTypeID": 451, "Value": 36000}],
		"LuckyBagClass": [{"ID": 1991, "AbleMultiple": false}],
		"LuckyBagEntityView": [{"ID": 18901, "LuckyBagClassID": 1991, "LuckyBagEntityTypeID": 0, "Probability": 10000000, "ItemClassID": 31, "ItemAmount": 1}, {"ID": 19111, "LuckyBagClassID": 1991, "LuckyBagEntityTypeID": 2, "Probability": 10000000, "ItemClassID": 8361, "ItemAmount": 4}]
	}
	var domain := EVENTS.new()
	domain.setup(source)
	var state := domain.initial_state()
	var context := _context()
	context.owned = {"8951": 1}
	var reward_counts: Array = []
	for index in range(8):
		context.now += 86400
		var uid := "synthetic-seven-cube-%d" % index
		context.instances = {uid: {"instance_id": uid, "sourceID": 8951, "quantity": 1, "record": {"source_reward_quantity": 1}}}
		var before := state.duplicate(true)
		var request := {"action": "consume_item", "item_id": 8951, "instance_id": uid}
		var result := domain.propose(request, context, state)
		check(result.ok and result.costs == [{"kind": "item", "id": 8951, "amount": 1, "instance_id": uid, "expected_quantity": 1}], "synthetic seven-use cube%d consumes one separate physical unit" % (index + 1))
		if not result.ok:
			return
		reward_counts.append(result.rewards.size())
		if index == 6:
			var retry := domain.propose(request, context, state)
			check(state == before and retry.ok and retry.state == result.state and retry.rewards == result.rewards, "synthetic seventh-use failed commit can retry exact final and RNG")
		state = JSON.parse_string(JSON.stringify(result.state))
		check(domain.validate_state(state).is_empty(), "synthetic seven-use history reload%d retains valid receipts" % (index + 1))
	check(reward_counts == [1, 1, 1, 1, 1, 1, 2, 1] and state.final_progress["8951"].completed == 1, "synthetic seventh final is once and eighth cannot repeat or multiply physical charges")

func _real_source(directory: String) -> void:
	var source := SOURCE.new()
	var configured := source.configure_directory(directory)
	check(configured.ok, "private original directory configured under test gate")
	if not configured.ok:
		return
	var domain := EVENTS.new()
	domain.setup(source)
	var state := domain.initial_state()
	var context := _context()
	check(source.rows("PassSystem").size() == 64 and source.rows("PassSystemLevel").size() == 1751 and source.rows("PassSystemQuest").size() == 1258, "actual source counts retain pass sentinel")
	check(source.rows("RouletteDisplayOfGachaProbability").size() == 56 and source.rows("RouletteDisplayOfMergeProbability").size() == 95 and source.rows("GotChaEntityView").size() == 14447, "actual roulette presentation/reward counts")
	var before := state.duplicate(true)
	var page := domain.view(context, state)
	var visible: Dictionary = {}
	for entry in page.rows:
		visible[str(entry.id)] = entry
	check(visible.has("pass:692") and visible.has("pass:724"), "simultaneous seasons remain independent and visible")
	check(state == before, "view performs no rolls or mutation")
	var may := context.duplicate(true)
	may.now = Time.get_unix_time_from_datetime_string("2026-05-23T12:00:00")
	var may_page := domain.view(may, state)
	var may_season := false
	for entry in may_page.rows:
		may_season = may_season or str(entry.id) in ["pass:692", "pass:724"]
	check(not may_season, "IsActive alone cannot bypass source season start")
	var daily := domain.propose({"action": "attendance_claim", "version_id": 8, "index": 1}, context, state)
	check(daily.ok and daily.rewards[0].kind == "blessing" and daily.rewards[0].amount == 1000, "TWILIGHT 200 base times existing level89 multiplier unblocks daily attendance")
	check(daily.ok and not domain.propose({"action": "attendance_claim", "version_id": 8, "index": 2}, context, daily.state).ok, "only one daily claim per local day")
	var seven_state := state.duplicate(true)
	var claims: Dictionary = {}
	for i in range(1, 7):
		claims[str(i)] = true
	seven_state.attendance["8:39:KR"] = {"count": 6, "last_day": int(floor(float(context.now) / 86400.0)) - 1, "claims": claims}
	var seventh := domain.propose({"action": "attendance_claim", "version_id": 8, "index": 7}, context, seven_state)
	check(seventh.ok and seventh.rewards.size() == 1 and int(seventh.rewards[0].id) == 369132, "day7 selects only matching server alternative")
	if seventh.ok:
		var stack := domain.propose({"action": "attendance_claim", "version_id": 18, "index": 1}, context, seventh.state)
		check(stack.ok and not domain.propose({"action": "attendance_claim", "version_id": 18, "index": 1}, context, stack.state).ok, "stack goal and duplicate claims enforced")
	var rollover := state.duplicate(true)
	rollover.attendance["8:38:KR"] = {"count": 6, "last_day": int(floor(float(context.now) / 86400.0)), "claims": claims}
	check(domain.propose({"action": "attendance_claim", "version_id": 8, "index": 1}, context, rollover).ok, "version38 claim cannot suppress version39")
	check(not domain.propose({"action": "pass_purchase", "pass_id": 692, "premium": false}, context, state).ok, "expired season692 purchase window is enforced")
	var bought := domain.propose({"action": "pass_purchase", "pass_id": 724, "premium": false}, context, state)
	check(bought.ok and bought.costs == [{"kind": "currency", "id": 1, "amount": 3000000}], "actual season724 base price charged")
	if bought.ok:
		check(not domain.propose({"action": "pass_purchase", "pass_id": 724, "premium": false}, context, bought.state).ok, "duplicate purchase rejected")
		var bonus_context := context.duplicate(true)
		bonus_context.pass_exp["724"] = 300
		var bonus_tier := domain.propose({"action": "pass_claim", "pass_id": 724, "level_id": 17384, "premium": false}, bonus_context, bought.state)
		check(bonus_tier.ok and bonus_tier.rewards[0].kind == "bonus" and int(bonus_tier.rewards[0].id) == 2415124 and int(bonus_tier.rewards[0].expires_at) == source.timestamp(292644, bonus_context), "pass bonus retains exact source ID and season expiry")
		var premium := domain.propose({"action": "pass_purchase", "pass_id": 724, "premium": true}, context, bought.state)
		check(premium.ok and premium.costs == [{"kind": "currency", "id": 4, "amount": 3000}], "actual premium price charged separately")
		context.pass_exp["724"] = 8999
		check(not domain.propose({"action": "pass_claim", "pass_id": 724, "level_id": 17674, "premium": false}, context, bought.state).ok, "9000XP tier locked at8999")
		context.pass_exp["724"] = 9000
		var final_tier := domain.propose({"action": "pass_claim", "pass_id": 724, "level_id": 17674, "premium": false}, context, bought.state)
		check(final_tier.ok, "final source tier unlocks at9000 without summing thresholds")
		if final_tier.ok:
			check(not domain.propose({"action": "pass_claim", "pass_id": 724, "level_id": 17674, "premium": false}, context, final_tier.state).ok, "final tier cannot be claimed twice")
		check(not domain.propose({"action": "pass_claim", "pass_id": 692, "level_id": 17674, "premium": false}, context, bought.state).ok, "cross-season tier forgery rejected")
	var poor := context.duplicate(true)
	poor.currencies = {"1": 2999999}
	check(not domain.propose({"action": "pass_purchase", "pass_id": 724, "premium": false}, poor, state).ok, "purchase checks available currency")
	var growth := source.row("PassSystem", 662)
	var growth_context := context.duplicate(true)
	var servers := source.find_rows("ServerLimit", "ServerLimitSetID", int(growth.ServerLimitSetID))
	if not servers.is_empty():
		growth_context.world_no = int(servers[0].WorldNo)
		growth_context.level = 4
		var growth_state := state.duplicate(true)
		growth_state.passes["662"] = {"experience": 0, "base": true, "premium": false, "claims": {}}
		check(not domain.propose({"action": "pass_claim", "pass_id": 662, "level_id": 16082, "premium": false}, growth_context, growth_state).ok, "growth Experience0 does not bypass level5")
		growth_context.level = 90
		check(not domain.propose({"action": "pass_claim", "pass_id": 662, "level_id": 16082, "premium": false}, growth_context, growth_state).ok, "growth Experience0 does not bypass linked quest")
	var xp_before := state.duplicate(true)
	var xp_added := domain.add_pass_exp(state, 724, 60)
	check(xp_added.ok and int(xp_added.state.passes["724"].experience) == 60 and state == xp_before, "host-only pass experience adapter stages without mutation")
	check(not domain.add_pass_exp(state, 662, 60).ok, "growth pass cannot receive season experience")
	var pass_task := {"action": "pass_quest_claim", "pass_id": 724, "quest_id": 101884}
	check(not domain.propose(pass_task, context, state).ok, "daily pass task cannot be claimed before actual kills")
	var live := domain.event({"kind": "kill", "source_id": 4, "amount": 99}, context, state)
	check(live.ok and not domain.propose(pass_task, context, live.state).ok, "source daily task still needs its hundredth kill")
	live = domain.event({"kind": "kill", "source_id": 4, "amount": 1}, context, live.state)
	var task_reward := domain.propose(pass_task, context, live.state)
	check(task_reward.ok and task_reward.rewards.size() == 1 and task_reward.rewards[0].kind == "pass_exp" and int(task_reward.rewards[0].id) == 724 and int(task_reward.rewards[0].amount) == 60, "actual hundred kills unlock source60XP daily reward")
	if task_reward.ok:
		check(not domain.propose(pass_task, context, task_reward.state).ok, "daily pass task cannot be redeemed twice")
		var tomorrow := context.duplicate(true)
		tomorrow.now += 86400
		check(not domain.propose(pass_task, tomorrow, task_reward.state).ok, "daily reset requires new gameplay rather than yesterday counts")
		var restarted := domain.event({"kind": "kill", "source_id": 4, "amount": 100}, tomorrow, task_reward.state)
		check(restarted.ok and domain.propose(pass_task, tomorrow, restarted.state).ok, "new daily gameplay can earn next day task")
	check(not domain.propose({"action": "pass_quest_claim", "pass_id": 724, "quest_id": 101864}, context, live.state).ok, "excluded clan donation goal stays unclaimable")
	context.owned["166594"] = 1
	var bag_request := {"action": "consume_item", "item_id": 166594}
	var opened := domain.propose(bag_request, context, state)
	var repeated := domain.propose(bag_request, context, state)
	check(opened.ok and opened.costs == [{"kind": "item", "id": 166594, "amount": 1}], "real roulette consumes its sourced owned container")
	check(opened.ok and repeated.ok and opened.rewards == repeated.rewards and opened.state.rng_state == repeated.state.rng_state, "staged RNG repeats until committed")
	var actual_bag_view := _container_view(domain, context, state, 166594)
	check(actual_bag_view.actions.size() == 1 and not bool(actual_bag_view.actions[0].get("disabled", false)), "actual eligible owned LuckyBag remains enabled after shared view guard")
	var unowned := context.duplicate(true)
	unowned.owned = {}
	check(not domain.propose(bag_request, unowned, state).ok, "no free roulette without owned source item")
	var half_group_total := 0
	for row in source.rows("RouletteDisplayOfMergeProbability"):
		if int(row.RouletteDisplayStepID) == 55 and int(row.GradeID) == 1 and int(row.RouletteDisplayRouteID) == 25:
			half_group_total += int(row.Probability)
	check(half_group_total == 500000, "presentation partial pool retained without padding")
	_real_owned_frontiers(source, domain, context, state)

func _real_owned_frontiers(source: Object, domain: Object, context: Dictionary, state: Dictionary) -> void:
	# Read every actual FinalReward pool, not only the usable8951 example.
	var expected_pools := [981, 1991, 12182, 12192, 12202, 12212, 13251, 13261, 13271, 13281, 13291, 14203, 40752, 40762, 40772, 40782, 40792, 40802]
	var pools: Dictionary = {}
	var final_count := 0
	for entity in source.rows("LuckyBagEntityView"):
		if int(entity.get("LuckyBagEntityTypeID", -1)) == 2:
			pools[int(entity.LuckyBagClassID)] = true
			final_count += 1
	var found: Array = pools.keys()
	found.sort()
	check(found == expected_pools and final_count == 25, "whole source preserves all18 FinalReward pools and25 final rows")
	var consumer_count := 0
	var production_openable: Array = []
	var final_audit: Array = []
	for link in source.rows("ItemBonus"):
		var bonus: Dictionary = source.row("Bonus", int(link.get("BonusID", 0)))
		if bool(link.get("IsPossession", false)) or int(bonus.get("BonusTypeID", 0)) != 110 or not pools.has(int(bonus.get("Value", 0))):
			continue
		consumer_count += 1
		var item_id := int(link.ItemClassID)
		var bag_id := int(bonus.Value)
		var owned := context.duplicate(true)
		owned.max_level = 90
		owned.owned = {str(item_id): 1}
		owned.instances = {"actual-frontier-fixture": {"instance_id": "actual-frontier-fixture", "sourceID": item_id, "quantity": 1, "record": {"source_reward_quantity": 1}}}
		# A local threshold never relaxes native TestItem/calendar/server gates.
		owned.twilight_policy.luckybag_final_rules = {str(bag_id): {"uses": 7 if item_id == 8951 else 2, "final_rewards": "all"}}
		var opened: Dictionary = domain.propose({"action": "consume_item", "item_id": item_id}, owned, state)
		final_audit.append({"item_id": item_id, "luckybag_class_id": bag_id, "consumer_reason": str(domain.call("_item_reason", item_id, owned, state)), "proposal_ok": bool(opened.ok), "proposal_error": str(opened.get("error", "")), "source_final_rule": domain.call("_final_rule", item_id, bag_id, context)})
		if opened.ok:
			production_openable.append(item_id)
	production_openable.sort()
	check(consumer_count == 18 and production_openable.is_empty(), "all18 final consumers retain test calendar and reward-leaf gates even under explicit local policy")
	var final_output := OS.get_environment("TWILIGHT_523_FINAL_AUDIT_FILE")
	if not final_output.is_empty():
		var output := FileAccess.open(final_output, FileAccess.WRITE)
		check(output != null, "private all-final proposal audit output available")
		if output != null:
			output.store_string(JSON.stringify({"scope": "all18 original FinalReward direct consumers; owned-unit fixture atNov4/class1/level90/max90/offset0; unknown thresholds explicitly configured only to verify native gates", "final_pool_count": pools.size(), "final_row_count": final_count, "end_to_end_openable": production_openable, "consumers": final_audit}, "  ", true))
	var market: Dictionary = source.row("MarketProduct", 11931)
	check(int(source.row("ItemClass", 8951).MaxStackAmount) == 1 and int(market.get("ClassID", 0)) == 8951 and int(market.get("Amount", 0)) == 7, "native package gives seven nonstacking8951 units rather than seven charges per unit")
	var contradict := context.duplicate(true)
	contradict.twilight_policy.luckybag_final_rules = {"1991": {"uses": 1, "final_rewards": "all"}}
	check(not domain.call("_final_rule", 8951, 1991, contradict).ok, "configuration cannot override proven native seven-use final threshold")
	var cube_context := context.duplicate(true)
	cube_context.owned = {"8951": 1}
	cube_context.instances = {"actual-cube-fixture": {"instance_id": "actual-cube-fixture", "sourceID": 8951, "quantity": 1, "record": {"source_reward_quantity": 1}}}
	var cube_before := state.duplicate(true)
	var blocked_cube: Dictionary = domain.propose({"action": "consume_item", "item_id": 8951}, cube_context, state)
	check(not blocked_cube.ok and "test_item" in str(blocked_cube.get("error", "")) and state == cube_before, "actual8951 TestItem8961 reward leaf blocks opening before cost progress or RNG")
	var cube_context_before_view := cube_context.duplicate(true)
	var cube_view := _container_view(domain, cube_context, state, 8951)
	check(cube_view.actions.size() == 1 and bool(cube_view.actions[0].get("disabled", false)) and "시험용 보상 포함" in str(cube_view.detail) and "test_item" not in str(cube_view.detail) and str(domain.call("_luckybag_reward_reason", 1991, cube_context)) == str(blocked_cube.error), "actual8951 view disables opening with Korean TestItem explanation while preserving exact proposal gate")
	check(state == cube_before and cube_context == cube_context_before_view, "actual8951 blocked view preserves all caller inventory state and RNG")
	var cooldown := state.duplicate(true)
	cooldown.uses["item:8951"] = int(cube_context.now) - 35999
	check(not str(domain.call("_item_reason", 8951, cube_context, cooldown)).is_empty(), "actual native10hour cube cooldown remains enforced independently of final rules")
	# Metadata acceptance cannot bypass this complex container's expired
	# guaranteed leaf155994 (native deletion2021063005).
	var complex_context := context.duplicate(true)
	complex_context.owned = {"167404": 1}
	var complex_root := 138714
	var choices: Array = domain.call("_reward_choices", complex_root, complex_context)
	check(not choices.is_empty() and choices[0].min_count == 1 and choices[0].max_count == 1 and str(choices[0].options[0].label).find("×") >= 0, "actual complex choice preview exposes human labels and source selection count")
	check(not domain.propose({"action": "consume_item", "item_id": 167404}, complex_context, state).ok, "actual complex container never picks an implicit selection")
	if not choices.is_empty():
		var selection: Dictionary = {}
		selection[str(choices[0].selection_key)] = [int(choices[0].options[0].value)]
		var complex_opened: Dictionary = domain.propose({"action": "consume_item", "item_id": 167404, "selection": selection}, complex_context, state)
		check(not complex_opened.ok and "item_expired" in str(complex_opened.get("error", "")), "actual complex guaranteed expired reward cannot be unlocked by metadata allowance")
	for item_id in [189834, 353592]:
		var lifetime := context.duplicate(true)
		lifetime.owned = {str(item_id): 1}
		check(not domain.propose({"action": "consume_item", "item_id": item_id}, lifetime, state).ok, "actual lifetime container%d preserved without authoritative physical expiry" % item_id)
		var root := 0
		var seconds := 0
		for link in source.find_rows("ItemBonus", "ItemClassID", item_id):
			var bonus: Dictionary = source.row("Bonus", int(link.BonusID))
			if int(bonus.BonusTypeID) in [5031, 5774]:
				root = int(bonus.Value)
			elif int(bonus.BonusTypeID) == 422:
				seconds = int(bonus.Value)
		var requirements: Array = domain.call("_reward_choices", root, lifetime)
		var selection: Dictionary = {}
		for requirement in requirements:
			selection[str(requirement.selection_key)] = [int(requirement.options[0].value)]
		var uid := "actual-life-fixture-%d" % item_id
		lifetime.instances = {uid: {"instance_id": uid, "sourceID": item_id, "quantity": 1, "record": {"source_reward_quantity": 1, "issued_at": int(lifetime.now), "expires_at": int(lifetime.now) + seconds, "source_life_seconds": seconds}}}
		var life_opened: Dictionary = domain.propose({"action": "consume_item", "item_id": item_id, "selection": selection}, lifetime, state)
		check(life_opened.ok and life_opened.costs == [{"kind": "item", "id": item_id, "amount": 1, "instance_id": uid, "expected_quantity": 1}], "actual lifetime container%d opens only through verified existing expiry and exact owned unit" % item_id)
	_real_all_typed_proposals(source, domain, context)

func _real_all_typed_proposals(source: Object, domain: Object, base_context: Dictionary) -> void:
	# Every direct original typed carrier gets a separately staged ownership
	# fixture. No quantities, source definitions or persistent save are granted.
	var before_domain: Object = null
	var before_script: GDScript
	var before_source: Object = source
	var before_source_script: GDScript
	var baseline_file := OS.get_environment("TWILIGHT_523_BASELINE_EVENTS_FILE")
	if not baseline_file.is_empty():
		before_script = GDScript.new()
		before_script.source_code = FileAccess.get_file_as_string(baseline_file)
		check(before_script.reload() == OK, "frozen events baseline compiles for private proposal comparison")
		before_domain = before_script.new()
		var baseline_source_file := OS.get_environment("TWILIGHT_523_BASELINE_SOURCE_FILE")
		if not baseline_source_file.is_empty():
			before_source_script = GDScript.new()
			before_source_script.source_code = FileAccess.get_file_as_string(baseline_source_file)
			check(before_source_script.reload() == OK, "frozen source baseline compiles for private proposal comparison")
			before_source = before_source_script.new()
			var configured: Dictionary = before_source.configure_directory(OS.get_environment("TWILIGHT_523_SOURCE_DIR"))
			check(configured.ok, "frozen source uses same gated original directory")
			# Immutable original rows and lazy indices are shared, not recopied.
			for cache in ["_tables", "_indices", "_joins"]:
				before_source.set(cache, source.get(cache))
		before_domain.setup(before_source)
	var report := {"scope": "all direct original typed carriers; explicit owned-unit fixtures; deterministic proposal paths; no natural supply or saved claims", "snapshot": {"now": int(base_context.now), "class_id": 1, "level": 90, "max_level": 90, "region": "KR", "world_no": 1, "utc_offset_minutes": 0}, "baseline_events": "6bf89f6" if before_domain != null else "not supplied", "baseline_source": "6bf89f6" if before_source != source else "same current resolver", "carriers": [], "counts": {"carriers": 0, "before_allowed": 0, "after_allowed": 0, "newly_allowed": 0, "newly_rejected": 0, "after_rejected": 0, "explicit_choice_paths": 0}}
	var seen: Dictionary = {}
	for link in source.rows("ItemBonus"):
		var bonus: Dictionary = source.row("Bonus", int(link.get("BonusID", 0)))
		if bool(link.get("IsPossession", false)) or int(bonus.get("BonusTypeID", 0)) not in [5031, 5774]:
			continue
		var item_id := int(link.ItemClassID)
		if seen.has(item_id):
			continue
		seen[item_id] = true
		var root := int(bonus.Value)
		var context := base_context.duplicate(true)
		context.level = 90
		context.max_level = 90
		context.owned = {str(item_id): 1}
		var uid := "typed-ownership-fixture-%d" % item_id
		context.instances = {uid: {"instance_id": uid, "sourceID": item_id, "quantity": 1, "record": {"source_reward_quantity": 1}}}
		var after_state: Dictionary = domain.initial_state()
		var before_state: Dictionary = before_domain.initial_state() if before_domain != null else {}
		var after_reason := str(domain.call("_item_reason", item_id, context, after_state))
		var before_reason := str(before_domain.call("_item_reason", item_id, context, before_state)) if before_domain != null else after_reason
		var preview: Dictionary = source.reward_choices(root, context)
		var cases: Array = [{}]
		if after_reason.is_empty() or before_reason.is_empty():
			for requirement in preview.get("choices", []):
				var expanded: Array = []
				for prior in cases:
					for option in requirement.get("options", []):
						var choice: Dictionary = prior.duplicate(true)
						choice[str(requirement.selection_key)] = [int(option.value)]
						expanded.append(choice)
				cases = expanded
		var entry := {"item_id": item_id, "root_reward_id": root, "consumer_before": before_reason, "consumer_after": after_reason, "before_allowed": false, "after_allowed": false, "deferred_random": preview.get("deferred_random", []), "paths": []}
		for selection in cases:
			var request := {"action": "consume_item", "item_id": item_id, "selection": selection}
			var after: Dictionary = domain.propose(request, context, after_state)
			var before: Dictionary = before_domain.propose(request, context, before_state) if before_domain != null else {"ok": false, "error": "baseline not supplied"}
			entry.after_allowed = bool(entry.after_allowed) or bool(after.ok)
			entry.before_allowed = bool(entry.before_allowed) or bool(before.ok)
			entry.paths.append({"selection": selection.duplicate(true), "before": {"ok": bool(before.ok), "error": str(before.get("error", ""))}, "after": {"ok": bool(after.ok), "error": str(after.get("error", "")), "rewards": after.get("rewards", [])}})
			report.counts.explicit_choice_paths += 1
			check(after_state == domain.initial_state() and int(context.owned[str(item_id)]) == 1, "actual typed proposal%d leaves ownership fixture and caller state untouched" % item_id)
		if bool(entry.after_allowed):
			report.counts.after_allowed += 1
		else:
			report.counts.after_rejected += 1
		if bool(entry.before_allowed):
			report.counts.before_allowed += 1
		if before_domain != null and bool(entry.after_allowed) and not bool(entry.before_allowed):
			report.counts.newly_allowed += 1
		if bool(entry.before_allowed) and not bool(entry.after_allowed):
			report.counts.newly_rejected += 1
		report.carriers.append(entry)
		report.counts.carriers += 1
	check(int(report.counts.carriers) == 3369, "all3359 SelectReward and10 ComplexReward native consumers proposal-audited")
	check(int(report.counts.after_allowed) > 0 and int(report.counts.newly_rejected) == 0, "whole typed proposal audit gains only eligible paths and retains previous valid openings")
	var output_file := OS.get_environment("TWILIGHT_523_TYPED_AUDIT_FILE")
	if not output_file.is_empty():
		var output := FileAccess.open(output_file, FileAccess.WRITE)
		check(output != null, "private all-typed proposal audit output available")
		if output != null:
			output.store_string(JSON.stringify(report, "  ", true))
	print("EVENTS523_TYPED_PROPOSAL_COUNTS ", JSON.stringify(report.counts))
