extends SceneTree

const Combat = preload("res://scripts/equipment523/combat.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 523
	var records: Array = [{"equipment523_element_flat_fire":10,"equipment523_element_flat_water":20,"equipment523_element_pierce_fire":10}]
	_check(Combat.elemental_extra(records, {"fire":50.0,"water":25.0}, rng) == 21, "flat channel resistance and fire-only pierce")
	_check(Combat.elemental_extra([], {}, rng) == 0, "no flat channel creates no minimum-one damage")
	records.append({"equipment523_element_crit_pct":100})
	_check(Combat.elemental_extra(records, {"fire":50.0,"water":25.0}, rng) == 42, "explicit double elemental critical")
	_check(Combat.elemental_extra(records, {"fire":50.0,"water":25.0}, rng, 2.0, 100.0) == 21, "target elemental critical resistance")
	records.append({"equipment523_melee_crit_resist_pct":2,"equipment523_ranged_crit_resist_pct":1,"equipment523_critical_reduction":3})
	_check(Combat.critical_resistance(records, "melee") == 2, "melee critical resistance")
	_check(Combat.critical_resistance(records, "ranged") == 1, "ranged critical resistance")
	_check(Combat.critical_resistance(records, "magic") == 0, "physical style resistance does not flatten into magic")
	_check(Combat.critical_reduction(records, false) == 0 and Combat.critical_reduction(records, true) == 3, "critical-only flat reduction")
	records.append({"equipment523_regen_hp":1,"equipment523_regen_mp":2,"equipment523_heal_pct":2,"equipment523_lfe":3,"equipment523_dth":2,"equipment523_element_reduction":1,"equipment523_element_crit_resist_pct":4})
	_check(Combat.regeneration(records, "hp") == 1 and Combat.regeneration(records, "mp") == 2, "regen preserves exact source amounts")
	_check(Combat.magical_heal(records, 100) == 102, "magic heal percentage points")
	_check(Combat.lfe(records) == 3, "distinct LFE stat")
	_check(Combat.death_extra(records, 1.0) == 2 and Combat.death_extra(records, 0.0) == 0, "explicit local DTH coefficient")
	_check(Combat.elemental_reduction(records) == 1 and Combat.elemental_critical_resistance(records) == 4, "elemental defensive fields")
	_check(not records[0].has("element_bonus_fire"), "source records remain unmodified")
	print("equipment523 combat: %d checks, %d failures" % [checks, failures])
	print("EQUIPMENT523_COMBAT_RESULT ",JSON.stringify({"checks":checks,"failures":[] if failures == 0 else ["failed"]}))
	quit(1 if failures else 0)

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)
