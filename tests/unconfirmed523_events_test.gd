extends SceneTree
## Focused domain regression tests. Real-source assertions run only with the
## user's private source directory; synthetic fixtures are explicitly separate.
const EVENTS = preload("res://scripts/unconfirmed523/events_domain.gd")
const SOURCE = preload("res://scripts/unconfirmed523/source523.gd")
var failures: Array[String] = []
var checks: int = 0

class FixtureSource extends RefCounted:
	var tables: Dictionary = {}
	func rows(table: String) -> Array:
		return tables.get(table, [])
	func row(table: String, id: int) -> Dictionary:
		for entry in rows(table):
			if int(entry.get("ID", 0)) == id:
				return entry
		return {}
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
	var directory := OS.get_environment("TWILIGHT_523_SOURCE_DIR")
	if not directory.is_empty():
		_real_source(directory)
	else:
		print("EVENTS523_REAL_SOURCE_SKIPPED: TWILIGHT_523_SOURCE_DIR not set")
	print("EVENTS523_", "PASS" if failures.is_empty() else "FAIL", " checks=", checks)
	quit(0 if failures.is_empty() else 1)

func _context() -> Dictionary:
	return {"now": Time.get_unix_time_from_datetime_string("2026-11-04T12:00:00"), "level": 90, "class_id": 1, "region": "KR", "service_region": "KR", "world_no": 1, "owned": {}, "currencies": {"1": 5000000, "4": 5000}, "pass_exp": {}, "completed_quests": {}, "event_counters": {}, "time_policy": {"utc_offset_minutes": 0}, "twilight_policy": {"luckybag_random_mode": "source_weights", "attendance_blessing_base": 200}}

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
	var unowned := context.duplicate(true)
	unowned.owned = {}
	check(not domain.propose(bag_request, unowned, state).ok, "no free roulette without owned source item")
	var half_group_total := 0
	for row in source.rows("RouletteDisplayOfMergeProbability"):
		if int(row.RouletteDisplayStepID) == 55 and int(row.GradeID) == 1 and int(row.RouletteDisplayRouteID) == 25:
			half_group_total += int(row.Probability)
	check(half_group_total == 500000, "presentation partial pool retained without padding")
