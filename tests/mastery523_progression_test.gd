extends SceneTree
const Core = preload("res://scripts/mastery/mastery523.gd")
const Fixture = preload("res://tests/mastery523_test.gd")
const Runtime = preload("res://scripts/mastery/mastery_runtime.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MASTERY_PROGRESS_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var core = Core.new()
	var path: String = OS.get_environment("TWILIGHT_MASTERY523_PACK")
	check(core.configure(Fixture.fixture()) if path.is_empty() else core.load_pack(path,FileAccess.get_sha256(path)),"selected pack loads")
	if core.levels.is_empty(): quit(1); return
	var runtime = Runtime.new()
	var day_start: float = Time.get_unix_time_from_datetime_string("2026-11-03T20:00:00")
	check(runtime.balance_error.is_empty() and runtime.purchase_period(day_start) == runtime.purchase_period(day_start-1)+1,"configured UTC+09 05:00 boundary is exact")
	check(runtime.purchase_period(day_start+86399) == runtime.purchase_period(day_start),"configured day remains constant for the full interval")
	var state: Dictionary = Core.fresh()
	for count: int in 5:
		var plan: Dictionary = core.plan_purchase(state,1,"day100-"+str(count),100)
		check(plan.ok and int(plan.charge.Count) == count+1,"daily source payment ladder")
		state = plan.after
	check(not core.plan_purchase(state,3,"cross-weapon-sixth",100).ok,"five-use cap shared across weapon types")
	var next: Dictionary = core.plan_purchase(state,3,"day101-first",101)
	check(next.ok and int(next.charge.Count) == 1 and int(next.after.purchase_count) == 6,"new local day resets ladder, preserves lifetime receipts")
	state = next.after
	check(int(core.purchase_usage(state,99).count) == 1 and int(core.purchase_usage(state,99).period) == 101,"backwards clock cannot reset active day")
	for count: int in 4: state = core.plan_purchase(state,1,"day101-more-"+str(count),101).after
	check(not core.plan_purchase(state,2,"rollback-refill",100).ok,"exhausted daily cap survives clock rollback")
	var legacy: Dictionary = Core.fresh()
	for count: int in 5: legacy = core.plan_purchase(legacy,1,"legacy-"+str(count)).after
	legacy.legacy_purchase_period = 200
	legacy.purchase_epoch = 200
	check(not core.plan_purchase(legacy,1,"legacy-upgrade-freebie",200).ok,"legacy exhausted quota stays exhausted on migration day")
	check(core.plan_purchase(legacy,1,"legacy-next-day",201).ok,"legacy purchases resume following local day")
	var charge: Dictionary = {"CurrencyID":1,"Cost":0,"provenance":"CUSTOM_BALANCE"}
	state = Core.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	check(not core.plan_acquire(state,1,1,rng,"early-claim",charge).ok,"unreached level cannot be claimed")
	state.weapons["1"] = {"points":str(int(core.levels[1][7].CumulativePoint)),"options":[],"colors":{},"locks":{}}
	for level: int in range(1,9):
		var acquired: Dictionary = core.plan_acquire(state,1,level,rng,"acquire-"+str(level),charge)
		check(acquired.ok and core.validate_state(acquired.after).is_empty(),"claim source level"+str(level))
		state = acquired.after
		check(core._owned_slots(core.record(state,1),1,level).size() == 2 and state.weapons["1"].colors[str(level)].size() == 4,"two option values and four colors owned"+str(level))
		check(not core.plan_acquire(state,1,level,rng,"duplicate-"+str(level),charge).ok,"owned level never claimed twice"+str(level))
	check(core.active_options(state,1).size() == 16,"all eight acquired levels activate sixteen values")
	var entry: Dictionary = core.record(state,1)
	var slots: Dictionary = core._owned_slots(entry,1,2)
	entry.locks["2"] = [false,true,true,false]
	state.weapons["1"] = entry
	var original: Dictionary = state.duplicate(true)
	var different: bool = false
	for seed_value: int in 300:
		rng.seed = seed_value
		var reroll: Dictionary = core.plan_reroll(state,1,rng,"reroll-"+str(seed_value))
		check(reroll.ok,"locked source-priced reroll available")
		if not reroll.ok: break
		var changed: Dictionary = core.record(reroll.after,1)
		check(changed.options[int(slots[1])] == entry.options[int(slots[1])] and changed.colors["2"][1] == entry.colors["2"][1],"numeric lock preserves its exact group and color")
		check(changed.colors["2"][2] == entry.colors["2"][2] and changed.locks == entry.locks,"name lock preserves color; all locks remain")
		check(changed.points == entry.points and state == original,"reroll preserves points and input state")
		if changed.options[int(slots[2])] != entry.options[int(slots[2])]: different = true; break
	check(different,"unlocked numerical field can actually change source variant while neighboring name is locked")
	for key: String in entry.locks: entry.locks[key] = [true,true,true,true]
	state.weapons["1"] = entry
	check(not core.reroll_availability(state,1).ok,"all fields locked cannot consume currency for a no-op")
	entry.options.remove_at(0)
	state.weapons["1"] = entry
	check(core.validate_state(state).is_empty() and not core.reroll_availability(state,1).ok,"partial legacy ownership preserved while only destructive reroll is blocked")
	var shared: Dictionary = Core.fresh()
	shared.weapons["1"] = {"points":str(int(core.levels[1][0].CumulativePoint)),"options":[],"colors":{},"locks":{}}
	var shared_claim: Dictionary = core.plan_acquire(shared,1,1,rng,"shared-local-rule",charge,"shared_level")
	var shared_colors: Array = shared_claim.after.weapons["1"].colors["1"]
	check(shared_claim.ok and shared_colors[0] == shared_colors[1] and shared_colors[0] == shared_colors[2] and shared_colors[0] == shared_colors[3],"alternative local color coupling is configurable and distinct from native confirmation")
	check(not core.plan_acquire(shared,1,1,rng,"unknown-mode",charge,"unknown").ok,"unknown local color mode cannot silently change probability behavior")
	# Matched bonuses are per level, not deduplicated by shared BonusID.
	var matched: Dictionary = Core.fresh()
	matched.weapons["1"] = {"points":str(int(core.levels[1][7].CumulativePoint)),"options":[],"colors":{},"locks":{}}
	for level: int in range(1,9):
		matched = core.plan_acquire(matched,1,level,rng,"matching-claim-"+str(level),charge).after
		matched.weapons["1"].colors[str(level)] = [2,2,2,2]
	var bonuses: Array = core.active_matching_bonuses(matched,1)
	runtime.core = core
	runtime.enabled = true
	runtime.state = matched.duplicate(true)
	var flat: int = int(core.matching_bonus(1,2).Value)
	check(bonuses.size() == 8 and runtime.catalog_bonus("hpFlat",1) == flat*8,"eight achieved full matching levels each grant one original flat HP bonus")
	check(runtime.catalog_bonus("hpFlat",3) == 0,"matching bonuses never leak to a different weapon")
	runtime.state.weapons["1"].points = str(int(core.levels[1][0].CumulativePoint))
	check(core.active_matching_bonuses(runtime.state,1).size() == 1 and runtime.catalog_bonus("hpFlat",1) == flat,"above-level matched ownership retained but effect gated")
	runtime.state = matched.duplicate(true)
	runtime.state.weapons["1"].options.remove_at(0)
	check(core.active_matching_bonuses(runtime.state,1).size() == 7 and runtime.catalog_bonus("hpFlat",1) == flat*7,"partial legacy option ownership cannot grant a matching bonus")
	if core.tables.MasteryGradeView.size() > 1:
		runtime.state = matched.duplicate(true)
		runtime.state.weapons["1"].colors["1"][0] = int(core.tables.MasteryGradeView[1].GradeID)
		check(core.active_matching_bonuses(runtime.state,1).size() == 7 and runtime.catalog_bonus("hpFlat",1) == flat*7,"one changed color removes only that level's matching bonus")
	if core.tables.MasteryGradeView.size() == 4:
		for weapon: int in core.levels:
			var purple: Dictionary = matched.weapons["1"].duplicate(true)
			purple.points = str(int(core.levels[weapon][7].CumulativePoint))
			for key: String in purple.colors: purple.colors[key] = [5,5,5,5]
			runtime.state = Core.fresh()
			runtime.state.weapons[str(weapon)] = purple
			var matching_bonus: Dictionary = core.matching_bonus(weapon,5)
			var kind: String = str(core.types[int(matching_bonus.BonusTypeID)].Name)
			var consumer: String = {"MeleeDamage":"meleeDamage","RangeDamage":"rangedDamage","MagicDamage":"magicDamage"}.get(kind,"")
			var with_matching: int = runtime.catalog_bonus(consumer,weapon)
			runtime.state.weapons[str(weapon)].colors = {}
			check(not consumer.is_empty() and with_matching-runtime.catalog_bonus(consumer,weapon) == int(matching_bonus.Value)*8,"purple matching resolves destination-specific flat damage once per level for weapon"+str(weapon))
	var bad: Dictionary = {"schema":"twilight.mastery523.v1","tables":core.tables.duplicate(true),"operations":core.operations.duplicate(true)}
	bad.tables.MasteryGradeView[0].Probability += 1
	check(not core.configure(bad),"malformed replacement color probabilities cannot damage live registry")
	bad = {"schema":"twilight.mastery523.v1","tables":core.tables.duplicate(true),"operations":core.operations.duplicate(true)}
	bad.tables.MasteryGradeMatchingBonus[0].BonusID = -1
	check(not core.configure(bad),"missing matching bonus reference is rejected before any live consumer")
	print("MASTERY_PROGRESSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":"synthetic" if path.is_empty() else "actual523"}))
	quit(0 if failures.is_empty() else 1)
