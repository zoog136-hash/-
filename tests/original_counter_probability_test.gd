extends SceneTree
const Service = preload("res://scripts/skills/skill_service.gd")
const Catalog = preload("res://scripts/skills/skill_catalog.gd")

func _initialize() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 20250617
	var fallback: Dictionary = Catalog.read_json("balance.json").counter_fallback
	var failed := false
	for grade: String in fallback:
		var probability := float(fallback[grade])
		var trials := 100000
		var hits := 0
		for _trial: int in range(trials):
			if Service.roll_counter(random, probability): hits += 1
		var measured := float(hits) / trials
		# Six sigma, with a fixed seed. This checks the production RNG predicate,
		# not a test-specific implementation or an invented unique-grade skill.
		var margin := 6 * sqrt(probability * (1 - probability) / trials)
		if absf(measured - probability) > margin: failed = true
		print("COUNTER_SAMPLE ", grade, " expected=", probability, " measured=", measured, " trials=", trials)
	if not failed: print("ORIGINAL_COUNTER_PROBABILITY_OK")
	quit(1 if failed else 0)
