extends SceneTree

const RULES = preload("res://scripts/card_draw_fusion.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CARD_DRAW_FUSION_FAIL: " + label)

func _fixture() -> Dictionary:
	var catalog: Dictionary = {}
	for category: String in RULES.CATEGORIES:
		var cards: Array = []
		for grade: String in RULES.GRADES:
			for index: int in range(24):
				cards.append({
					"sourceId": "%s-%s-%d" % [category, grade, index],
					"name": "%s %s 카드 %d" % [category, grade, index],
					"grade": grade, "type": "test"
				})
		catalog[category] = cards
	return catalog

func _run() -> void:
	var total_weight: int = 0
	for grade: String in RULES.DRAW_ORDER:
		total_weight += int(RULES.DRAW_WEIGHTS[grade])
	_check(total_weight == 10000, "fixed 10,000-weight draw table")
	_check(RULES.DRAW_WEIGHTS == {"고급": 9359, "희귀": 550, "영웅": 90, "전설": 1}, "agreed draw probabilities")
	_check(RULES.FUSION_WEIGHTS == {"일반": 3500, "고급": 1700, "희귀": 1200, "영웅": 1100, "전설": 1100, "신화": 10000}, "agreed fusion probabilities")
	_check(RULES.FUSION_MATERIALS["전설"] == 2 and RULES.FUSION_MATERIALS["영웅"] == 4, "fusion recipe counts")
	var rules = RULES.new()
	rules.configure(_fixture())
	rules.rng.seed = 81495
	var counts: Dictionary = {"고급": 0, "희귀": 0, "영웅": 0, "전설": 0}
	var seen_common: Dictionary = {}
	# Enough seeded rolls to exercise even the 0.01% tier, without asserting
	# statistically impossible exact counts or relying on unknown game art.
	for batch: int in range(20000):
		var result: Dictionary = rules.draw_pack("변신")
		if not bool(result.get("ok", false)):
			_check(false, "valid pack must draw")
			break
		var cards: Array = result.get("results", []) as Array
		if cards.size() != 11:
			_check(false, "every pack has 11 cards")
			break
		for raw: Variant in cards:
			var card: Dictionary = raw as Dictionary
			var grade: String = str(card.get("grade", ""))
			if not counts.has(grade):
				_check(false, "draw outside fixed rarity table")
				continue
			counts[grade] = int(counts[grade]) + 1
			if grade == "고급":
				seen_common[str(card.get("id", ""))] = true
	_check(absf(float(counts["고급"]) / 220000.0 - 0.9359) < 0.012, "common-tier draw frequency")
	_check(absf(float(counts["희귀"]) / 220000.0 - 0.055) < 0.007, "rare-tier draw frequency")
	_check(absf(float(counts["영웅"]) / 220000.0 - 0.009) < 0.003, "hero-tier draw frequency")
	_check(int(counts["전설"]) > 0 and int(counts["전설"]) < 100, "legendary tier attainable")
	_check(seen_common.size() == 24, "uniform common pool includes every source ID")
	_check((rules.export_state()["owned"] as Dictionary).get("성물", {}).is_empty(), "categories are independent")
	_check((rules.export_state()["owned"] as Dictionary).get("마법인형", {}).is_empty(), "dolls are independent")

	var a = RULES.new()
	var b = RULES.new()
	a.configure(_fixture())
	b.configure(_fixture())
	a.rng.seed = 12345
	b.rng.seed = 12345
	_check(a.draw_pack("성물") == b.draw_pack("성물"), "seeded reproducible equal-weight draws")
	_check(a.draw_pack("아이템").get("ok", false) == false, "non-card categories fail closed")

	var incomplete: Dictionary = _fixture()
	var relics: Array = incomplete["성물"] as Array
	for index: int in range(relics.size() - 1, -1, -1):
		if str((relics[index] as Dictionary).get("grade", "")) == "전설":
			relics.remove_at(index)
	var blocked = RULES.new()
	blocked.configure(incomplete)
	_check(not blocked.can_draw("성물"), "missing grade does not redistribute weights")
	_check(not bool(blocked.draw_pack("성물").get("ok", true)), "missing grade aborts whole pack")
	_check((blocked.export_state()["owned"] as Dictionary).get("성물", {}).is_empty(), "failed pack does not grant cards")

	# Duplicate copies are consumable; the first unlocked card is not.
	var fusion = RULES.new()
	fusion.configure(_fixture())
	fusion.rng.seed = 55
	var common_id: String = "source:변신-고급-0"
	fusion.import_state({
		"owned": {"변신": {"source:변신-고급-0": true}},
		"spare": {"변신": {"source:변신-고급-0": 4}},
		"pity": {}
	})
	_check(fusion.spare_count("변신", "고급") == 4, "four duplicate materials imported")
	var fused: Dictionary = fusion.fuse("변신", "고급")
	_check(bool(fused.get("ok", false)), "valid fusion resolves")
	_check(int(fused.get("consumed", 0)) == 4, "four duplicates consumed")
	_check(bool((fusion.export_state()["owned"] as Dictionary)["변신"].get(common_id, false)), "base unlock survives fusion")
	var gain: int = 1 if str(fused.get("to_grade", "")) == "고급" and not bool((fused.get("result", {}) as Dictionary).get("new", false)) else 0
	_check(fusion.spare_count("변신", "고급") == gain, "material debit and failed-result return are exact")
	var snapshot: Dictionary = fusion.export_state()
	_check(not bool(fusion.fuse("변신", "고급").get("ok", true)), "insufficient duplicates rejected")
	_check(fusion.export_state() == snapshot, "rejected fusion never spends materials")
	var restored = RULES.new()
	restored.configure(_fixture())
	restored.import_state(snapshot)
	_check(restored.export_state() == snapshot, "card ownership and counters save round-trip")

	# Set pity to 19 and find one ordinary failure; its next failed attempt must
	# award the extra higher-grade card and reset only that category/grade.
	var pity_case = RULES.new()
	pity_case.configure(_fixture())
	pity_case.rng.seed = 90816
	var rare_id: String = "source:마법인형-희귀-0"
	pity_case.import_state({
		"owned": {"마법인형": {"source:마법인형-희귀-0": true}},
		"spare": {"마법인형": {"source:마법인형-희귀-0": 200}},
		"pity": {"마법인형": {"희귀": 19}}
	})
	var encountered_failure: bool = false
	for attempt: int in range(10):
		var sample: Dictionary = pity_case.fuse("마법인형", "희귀")
		if not bool(sample.get("ok", false)):
			break
		if not bool(sample.get("success", true)):
			encountered_failure = true
			var reward: Dictionary = sample.get("pity_reward", {}) as Dictionary
			_check(str(reward.get("grade", "")) == "영웅", "20th failure grants extra hero")
			_check(int(sample.get("pity_progress", -1)) == 0, "pity counter resets on reward")
			break
	_check(encountered_failure, "pity test reached a failure")

	var myth = RULES.new()
	myth.configure(_fixture())
	var myth_id: String = "source:성물-신화-0"
	myth.import_state({
		"owned": {"성물": {"source:성물-신화-0": true}},
		"spare": {"성물": {"source:성물-신화-0": 4}},
		"pity": {}
	})
	var top: Dictionary = myth.fuse("성물", "신화")
	_check(bool(top.get("ok", false)) and bool(top.get("success", false)), "configured mythic fusion is guaranteed")
	_check(str(top.get("to_grade", "")) == "유일", "mythic result is unique tier")

	var corrupted = RULES.new()
	corrupted.configure(_fixture())
	corrupted.import_state({
		"owned": {"변신": {"unknown": true}},
		"spare": {"변신": {"unknown": 999}},
		"pity": {"변신": {"희귀": 999}}
	})
	_check((corrupted.export_state()["owned"] as Dictionary)["변신"].is_empty(), "unknown identities rejected")
	_check(corrupted.spare_count("변신", "희귀") == 0, "invalid materials rejected")
	_check(int((corrupted.export_state()["pity"] as Dictionary)["변신"]["희귀"]) == 19, "corrupt pity clamped")
	corrupted.import_state({})
	_check(corrupted.spare_count("변신", "희귀") == 0, "old save defaults to empty card inventory")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("CARD_DRAW_FUSION_OK %d checks" % checks)
		quit(0)
	else:
		print("CARD_DRAW_FUSION_FAILED %d/%d: %s" % [failures.size(), checks, ", ".join(failures)])
		quit(1)
