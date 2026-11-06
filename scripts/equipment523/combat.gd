extends RefCounted

const ElementRules = preload("res://scripts/elemental_rules.gd")
const ORIGINAL_INPUT = preload("res://scripts/item_options.gd")
const CHANNELS: Array[String] = ["fire", "water", "wind", "earth"]

# These are typed patch-523 record consumers, deliberately independent of the
# legacy element_bonus_* fields whose values are percentage damage, not flat.
static func sum_stat(records: Array, key: String) -> float:
	var total: float = 0.0
	for value: Variant in records:
		if value is Dictionary:
			total += float(value.get(key, 0.0))
			total += ORIGINAL_INPUT.additional_original_flat(value,key)
			total += ORIGINAL_INPUT.additional_original_percent(value,key)
	return total

# Twilight-local ordering: sum flat damage and pierce for each source channel;
# subtract that channel's resistance, roll elemental critical once per channel,
# then sum the independently resisted channels. Main weapon element is unrelated.
# Critical multiplier=2 is a visible local policy, not a recovered source formula.
# Resistance/pierce/critical chances use percentage points. A zero flat channel
# does not create a minimum-one hit and does not draw random numbers.
static func elemental_extra(records: Array, resistance: Dictionary, rng: RandomNumberGenerator, crit_multiplier: float = 2.0, target_critical_resistance: float = 0.0) -> int:
	var total: int = 0
	var crit_chance: float = clampf((sum_stat(records, "equipment523_element_crit_pct") - target_critical_resistance) / 100.0, 0.0, 1.0)
	for channel: String in CHANNELS:
		var flat: int = maxi(0, int(round(sum_stat(records, "equipment523_element_flat_" + channel))))
		if flat == 0:
			continue
		var pierce: float = maxf(0.0, sum_stat(records, "equipment523_element_pierce_" + channel))
		var resisted: int = ElementRules.damage_after_resistance(flat, float(resistance.get(channel, 0.0)) - pierce)
		if crit_chance > 0.0 and rng.randf() < crit_chance:
			resisted = maxi(0, int(round(float(resisted) * maxf(1.0, crit_multiplier))))
		total += resisted
	return total

static func elemental_critical_resistance(records: Array, additional_percent: float = 0.0) -> float:
	return maxf(0.0, sum_stat(records, "equipment523_element_crit_resist_pct") + additional_percent)

# Apply only to incoming attacks which actually carry an elemental channel.
static func elemental_reduction(records: Array) -> int:
	return maxi(0, int(round(sum_stat(records, "equipment523_element_reduction"))))

# Keeps melee and ranged resistance distinct; neither affects magical criticals.
static func critical_resistance(records: Array, attack_style: String) -> float:
	if attack_style not in ["melee", "ranged"]:
		return 0.0
	return maxf(0.0, sum_stat(records, "equipment523_" + attack_style + "_crit_resist_pct"))

# Flat reduction is gated by the actual critical roll, never all incoming hits.
static func critical_reduction(records: Array, critical: bool) -> int:
	return maxi(0, int(round(sum_stat(records, "equipment523_critical_reduction")))) if critical else 0

# Amount per host recovery tick. The host owns the explicit 30-second interval,
# clock persistence and max-HP/MP clamps; a source +1 remains exactly +1 per tick.
static func regeneration(records: Array, resource: String) -> int:
	if resource not in ["hp", "mp"]:
		return 0
	return maxi(0, int(round(sum_stat(records, "equipment523_regen_" + resource))))

# Recovery magic only. Potions use their existing separate typed heal fields.
static func magical_heal(records: Array, base_amount: int) -> int:
	var multiplier: float = maxf(0.0, 1.0 + sum_stat(records, "equipment523_heal_pct") / 100.0)
	return maxi(0, int(round(float(maxi(0, base_amount)) * multiplier)))

# Existing skill-service lfe_scale formulas consume this exact stat addition.
static func lfe(records: Array) -> float:
	return sum_stat(records, "equipment523_lfe")

# No original KarmaDeath derived formula is present in the supplied tables.
# The caller MUST provide its displayed Twilight-local linear policy coefficient.
# Keep DTH separate from STR, flat item damage and the actual stored source value.
static func death_extra(records: Array, damage_per_point: float) -> int:
	return maxi(0, int(round(maxf(0.0, sum_stat(records, "equipment523_dth")) * maxf(0.0, damage_per_point))))
