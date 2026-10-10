extends RefCounted
# TWILIGHT's existing formulas, made explicit and regression-safe.
# This is NOT a wholesale replacement with L1J; the existing grade/gear/skill
# balance remains unchanged. AC/MR participate in hit, not flat mitigation.
static func physical_hit_chance(accuracy: int, target_ac: int, avoidance: int) -> float:
	var base_percent: float = 75.0 + float(accuracy - absi(target_ac)) * 0.7
	var final_percent: float = base_percent - float(maxi(0,avoidance))
	return clampf(final_percent / 100.0,0.05,0.95)

static func magic_hit_chance(accuracy: int, target_mr: int) -> float:
	var percent: float = 75.0 + float(accuracy - maxi(0,target_mr)) * 0.7
	return clampf(percent / 100.0,0.05,0.95)

static func physical_after_flat_reduction(raw_damage: int, equipment_reduction: int, buff_reduction: int) -> int:
	# AC is deliberately not an input; applying AC again here double-counts
	# the dodge/AC hit calculation.
	return maxi(1,raw_damage - equipment_reduction - buff_reduction)
