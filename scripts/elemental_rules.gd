extends RefCounted
class_name TwilightElementRules

# Twilight-local elemental channels. "physical" bypasses elemental resistance.
const CHANNELS: Array[String] = ["physical", "fire", "ice", "lightning", "earth", "wind", "holy", "dark", "arcane"]

static func channel(raw_value: String) -> String:
	var value: String = raw_value.strip_edges().to_lower()
	return value if CHANNELS.has(value) else "physical"

static func damage_after_resistance(raw_damage: int, resistance_percent: float) -> int:
	var resistance: float = clampf(resistance_percent, -80.0, 85.0)
	return maxi(1, int(round(float(maxi(1, raw_damage)) * (1.0 - resistance / 100.0))))

static func damage_with_bonus(raw_damage: int, bonus_percent: float) -> int:
	return maxi(1, int(round(float(maxi(1, raw_damage)) * (1.0 + clampf(bonus_percent, -90.0, 300.0) / 100.0))))
