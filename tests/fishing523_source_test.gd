extends SceneTree
## Full supplied-table checks, separate from actual Main/UI tests.
const Runtime = preload("res://scripts/fishing/fishing_runtime.gd")
const Session = preload("res://scripts/fishing/fishing_session.gd")
const Rules = preload("res://scripts/fishing/fishing_rules.gd")
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	var rules = Rules.new()
	check(rules.load_pack(OS.get_environment("TWILIGHT_FISHING523_PACK")), "private 523 input")
	if not failures.is_empty(): quit(2); return
	for distribution: Dictionary in rules.rows("FishDistribution"):
		var hour: int = int(distribution.GameTimeFrom)
		var selected: Dictionary = rules.distribution(int(distribution.FishTerritoryID), int(distribution.FishingRodID), hour)
		check(not selected.is_empty(), "distribution reachable " + str(distribution.ID))
	for row: Dictionary in rules.rows("FishPoolProbability"):
		check(not rules.row("Fish", int(row.FishID)).is_empty(), "fish reference " + str(row.ID))
	var count: int = 0
	for name: String in ["ExchangeSystemConstant", "ExchangeSystemInput", "ExchangeSystemInputBonus", "ExchangeSystemInputBonusOutput", "ExchangeSystemOutput", "ExchangeSystemRule"]: count += rules.rows(name).size()
	check(count == 35, "all six exchange tables and all 35 rows retained")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for grade: int in [2, 3, 4]:
		for trial: int in range(1000):
			var awards: Dictionary = rules.exchange_rewards(grade, rng)
			check(int(awards.get("303031", 0)) == {2:1, 3:8, 4:300}[grade], "guaranteed amount")
			check(not awards.has("323853"), "system thirteen excluded")
	for row: Dictionary in rules.rows("FishContestRankReward"):
		check(not rules.row("Reward", int(row.RewardID)).is_empty(), "all rank rewards linked")
	check(rules.exchange_outputs(13, 1).is_empty(), "rule and system composite key")
	check(int(rules.distribution(1, 303021, 6).FishPoolID) == 101 and int(rules.distribution(1, 303021, 18).FishPoolID) == 111, "day/night boundary")
	var runtime = Runtime.new()
	check(runtime.valid_policy(), "default host policy validates")
	runtime.policy.game_hour = 24
	check(not runtime.valid_policy(), "out-of-range host hour rejected")
	runtime.policy.game_hour = 12
	runtime.policy.gauge_rate_scale = 0
	check(not runtime.valid_policy(), "zero gauge divisor rejected")
	for territory: Dictionary in rules.rows("FishTerritory"):
		for rod: String in rules.rods:
			for hour: int in range(24):
				var distribution: Dictionary = rules.distribution(int(territory.ID), int(rod), hour)
				check(not distribution.is_empty(), "complete territory/rod/hour resolution")
				var session = Session.new()
				check(session.start(rules, int(territory.ID), int(rod), hour), "source session has valid fish and difficulty")
	var raw_state: Dictionary = Runtime.fresh_state()
	raw_state.items["197561"] = 2
	check(runtime.check_state(raw_state), "ownership ledger may aggregate multiple single-item stacks")
	print("FISHING523_SOURCE_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
