extends SceneTree
const Core = preload("res://scripts/mastery/mastery523.gd")
const Runtime = preload("res://scripts/mastery/mastery_runtime.gd")
const Fixture = preload("res://tests/mastery523_test.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MASTERY_EFFECT_FAIL: ",label)

static func fixture() -> Dictionary:
	var pack: Dictionary = Fixture.fixture()
	var names: Array = ["PVPMeleeAdditionDamage","PVPRangeAdditionDamage","PVPMagicAdditionDamage","PierceDamageReduction","PiercePVPDamageReduction","IgnoreMeleeDamageReductionPercent","IgnoreRangeDamageReductionPercent","IgnoreMagicDamageReductionPercent"]
	for index: int in names.size(): pack.tables.BonusType.append({"ID":1000+index,"Name":names[index],"UnitID":3 if index >= 5 else 1})
	pack.tables.UIUnit.append({"ID":1,"UnitID":3,"Denominator":10000})
	var levels: Dictionary = {}
	var bonuses: Dictionary = {}
	for row: Dictionary in pack.tables.MasteryWeaponLevelView: levels[int(row.ID)] = row
	for row: Dictionary in pack.tables.Bonus: bonuses[int(row.ID)] = row
	for row: Dictionary in pack.tables.MasteryBonusView:
		if int(row.Slot) != 2: continue
		var level: Dictionary = levels[int(row.MasteryWeaponLevelID)]
		var style: int = 1 if int(level.WeaponTypeID) == 3 else (2 if int(level.WeaponTypeID) == 5 else 0)
		var bonus: Dictionary = bonuses[int(row.BonusID)]
		if int(level.Level) == 2: bonus.BonusTypeID = 1000+style
		elif int(level.Level) == 3: bonus.BonusTypeID = 1003
		elif int(level.Level) == 7: bonus.BonusTypeID = 1004
		elif int(level.Level) == 8: bonus.BonusTypeID = 1005+style; bonus.Value = int(bonus.Value)*10000
	return pack

static func group_for(core, weapon: int, level: int, slot: int) -> int:
	for group: int in core.options:
		var row: Dictionary = core.options[group][weapon]
		if int(row.level) == level and int(row.Slot) == slot: return group
	return 0

static func owned(core, weapon: int, max_level: int = 8) -> Dictionary:
	var entry: Dictionary = {"points":str(int(core.levels[weapon][max_level-1].CumulativePoint)),"options":[],"colors":{},"locks":{}}
	for level: int in range(1,max_level+1):
		for slot: int in [1,2]: entry.options.append({"group_id":group_for(core,weapon,level,slot)})
	return entry

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var core = Core.new()
	var path: String = OS.get_environment("TWILIGHT_MASTERY523_PACK")
	check(core.configure(fixture()) if path.is_empty() else core.load_pack(path,FileAccess.get_sha256(path)),"selected source loads")
	if core.levels.is_empty(): quit(1); return
	var source_before: Dictionary = core.tables.duplicate(true)
	var runtime = Runtime.new()
	runtime.core = core
	runtime.enabled = true
	for weapon: int in core.levels:
		runtime.state = Core.fresh()
		runtime.state.weapons[str(weapon)] = owned(core,weapon)
		var expected: Dictionary = {"meleeDamage":0,"rangedDamage":0,"magicDamage":0,"damage_reduction_ignore":0}
		var amps: Dictionary = {"melee":0.0,"ranged":0.0,"magic":0.0}
		for option: Dictionary in runtime.state.weapons[str(weapon)].options:
			var bonus: Dictionary = core.bonuses[int(core.options[int(option.group_id)][weapon].BonusID)]
			var name: String = str(core.types[int(bonus.BonusTypeID)].Name)
			if name in ["MeleeDamage","PVPMeleeAdditionDamage"]: expected.meleeDamage += int(bonus.Value)
			elif name in ["RangeDamage","PVPRangeAdditionDamage"]: expected.rangedDamage += int(bonus.Value)
			elif name in ["MagicDamage","PVPMagicAdditionDamage"]: expected.magicDamage += int(bonus.Value)
			elif name in ["PierceDamageReduction","PiercePVPDamageReduction"]: expected.damage_reduction_ignore += int(bonus.Value)
			elif name == "IgnoreMeleeDamageReductionPercent": amps.melee += float(bonus.Value)/10000.0
			elif name == "IgnoreRangeDamageReductionPercent": amps.ranged += float(bonus.Value)/10000.0
			elif name == "IgnoreMagicDamageReductionPercent": amps.magic += float(bonus.Value)/10000.0
		for key: String in expected: check(runtime.catalog_bonus(key,weapon) == expected[key],"source native/PvP/flat-ignore consumer counted once: "+str(weapon)+"/"+key)
		for kind: String in amps: check(runtime.damage_amplification(kind,weapon) == amps[kind],"percent source units and attack-kind isolation: "+str(weapon)+"/"+kind)
		runtime.balance_config.typed_percent_ignore = "display_only"
		check(runtime.damage_amplification("melee",weapon)+runtime.damage_amplification("ranged",weapon)+runtime.damage_amplification("magic",weapon) == 0.0 and runtime.catalog_bonus("damage_reduction_ignore",weapon) == expected.damage_reduction_ignore,"display-only affects only inferred percentages")
		runtime.balance_config.typed_percent_ignore = "style_amplifier"
		runtime.state.weapons[str(weapon)].points = "0"
		check(runtime.catalog_bonus("damage_reduction_ignore",weapon) == 0 and runtime.damage_amplification("melee",weapon)+runtime.damage_amplification("ranged",weapon)+runtime.damage_amplification("magic",weapon) == 0.0,"above-level ownership grants no combat effects")
	var state: Dictionary = Core.fresh()
	var grade: int = int(core.tables.MasteryGradeView[0].GradeID)
	var first: int = group_for(core,1,1,1)
	var variable: int = group_for(core,1,2,1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 987
	state.rng_state = str(rng.state)
	state.weapons["1"] = {"points":str(int(core.levels[1][7].CumulativePoint)),"options":[{"group_id":first,"memo":"preserve"},{"group_id":variable,"memo":"unknown missing peer"}],"colors":{"1":[grade,grade,grade,grade],"2":[grade,grade,grade,grade]},"locks":{"1":[true,false,true,false],"2":[true,true,true,true]},"user_note":"preserve"}
	var fixed_partial: Dictionary = Core.fresh()
	fixed_partial.weapons["1"] = {"points":"0","options":[{"group_id":first}],"colors":{"1":[grade,grade,grade,grade]},"locks":{}}
	var no_draw: int = rng.state
	check(not core.plan_fixed_reset(fixed_partial,1,rng,"legacy-fixed-bypass").ok and rng.state == no_draw,"legacy fixed-reset API also refuses incomplete ownership before any RNG draw")
	var before: Dictionary = state.duplicate(true)
	var status: Dictionary = core.partial_status(state,1)
	check(status.ok and status.repairs.size() == 1 and int(status.repairs[0].level) == 1,"only absent unique100-percent value is recoverable")
	var repair: Dictionary = core.plan_partial_repair(state,1,"repair",{"CurrencyID":1,"Cost":0})
	check(repair.ok and core.validate_state(repair.after).is_empty(),"fixed missing value produces valid explicit repair plan")
	var repaired: Dictionary = core.record(repair.after,1)
	check(repaired.options.size() == 3 and repaired.options[0] == before.weapons["1"].options[0] and repaired.options[1] == before.weapons["1"].options[1],"known values and their opaque metadata remain exact")
	check(repaired.colors == before.weapons["1"].colors and repaired.locks == before.weapons["1"].locks and repaired.points == before.weapons["1"].points and repaired.user_note == "preserve" and repair.after.rng_state == before.rng_state,"repair preserves colors locks points metadata and RNG without a draw")
	check(repair.after.receipts.repair.custom_repair.rerolled == false and state == before,"repair records custom provenance without mutating input")
	check(not core.plan_partial_repair(repair.after,1,"repeat",{"CurrencyID":1,"Cost":0}).ok,"unresolved variable missing value is not drawn or granted on repeat")
	state = repair.after
	for slot: int in [1,2]: state.weapons["1"].options.append({"group_id":group_for(core,1,3,slot)})
	state.weapons["1"].colors["3"] = [grade,grade,grade,grade]
	check(not core.reroll_availability(state,1).ok,"strict mode retains whole-weapon partial guard")
	var scope: Dictionary = core.reroll_availability(state,1,"complete_levels_only")
	check(scope.ok and scope.levels == [1,3] and scope.frozen == [2] and int(scope.charge.LockSlotCount) == 2,"local complete-level scope uses original fee for only locks on changed levels")
	var roll: Dictionary = core.plan_reroll(state,1,rng,"scoped-reset","independent_fields","complete_levels_only")
	var unknown_before: Dictionary = core.record(state,1)
	var unknown_after: Dictionary = core.record(roll.after,1)
	var old_index: int = int(core._owned_slots(unknown_before,1,2)[1])
	var new_index: int = int(core._owned_slots(unknown_after,1,2)[1])
	check(roll.ok and unknown_after.options[new_index] == unknown_before.options[old_index] and unknown_after.colors["2"] == unknown_before.colors["2"] and unknown_after.locks["2"] == unknown_before.locks["2"],"complete-level reroll leaves all partial-level known data untouched")
	check(roll.after.receipts["scoped-reset"].custom_partial_scope.preserved_levels == [2],"scoped reroll records preserved partial levels")
	var corrupt: Dictionary = state.duplicate(true)
	corrupt.weapons["1"].colors["2"].pop_back()
	check(not core.validate_state(corrupt).is_empty() and not core.plan_partial_repair(corrupt,1,"invalid-repair",{}).ok,"invalid save is rejected, never silently repaired")
	check(core.tables == source_before,"all source rows remain immutable")
	print("MASTERY_EFFECT_REPAIR_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":"synthetic" if path.is_empty() else "actual523"}))
	quit(0 if failures.is_empty() else 1)
