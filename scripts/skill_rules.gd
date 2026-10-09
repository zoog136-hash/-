extends RefCounted
class_name TwilightSkillRules

# Data-driven rules for local/offline skill execution. "activation" is the
# source of truth: a buff type alone never makes a skill passive.
const BUFF_EFFECTS: Array[String] = ["atkBuff", "defBuff", "hpBuff", "speedBuff"]
const TARGET_EFFECTS: Array[String] = ["damage", "turnUndead", "charge", "stun", "silence", "poison", "bleed", "hold", "fear"]
const SUPPORTED_EFFECTS: Array[String] = [
	"damage", "turnUndead", "charge", "stun", "silence", "poison", "bleed", "hold", "fear",
	"heal", "atkBuff", "defBuff", "hpBuff", "speedBuff", "teleport", "invisibility"
]

static func effect_kind(skill: Dictionary) -> String:
	return str(skill.get("effect", "utility"))

static func is_passive(skill: Dictionary) -> bool:
	return str(skill.get("activation", "active")).strip_edges().to_lower() == "passive"

static func has_target(effect: String) -> bool:
	return TARGET_EFFECTS.has(effect)

static func is_buff(effect: String) -> bool:
	return BUFF_EFFECTS.has(effect)

static func is_supported(effect: String) -> bool:
	return SUPPORTED_EFFECTS.has(effect)

static func cooldown_seconds(skill: Dictionary) -> float:
	if skill.has("cooldown"):
		return maxf(0.0, float(skill.get("cooldown", 0.0)))
	match effect_kind(skill):
		"stun", "silence", "fear", "hold":
			return 8.0
		"poison", "bleed":
			return 5.0
		"teleport", "invisibility":
			return 10.0
		"heal":
			return 3.0
		"atkBuff", "defBuff", "hpBuff", "speedBuff":
			return 3.0
		"charge":
			return 7.0
		"turnUndead":
			return 5.0
		"damage":
			return 1.0
	return 0.0

static func global_cooldown_seconds(skill: Dictionary) -> float:
	return maxf(0.0, float(skill.get("global_cooldown", 0.25)))

static func range_pixels(skill: Dictionary) -> float:
	return maxf(80.0, float(skill.get("range", 120.0)))

static func can_auto_cast(skill: Dictionary) -> bool:
	if is_passive(skill):
		return false
	if skill.get("origin", "") == "LINEAGEM_20250617": return skill.get("mode", "") in ["attack", "status", "heal", "buff", "counter", "cleanse", "convert"]
	return effect_kind(skill) in ["damage", "turnUndead", "charge", "heal", "stun", "silence", "poison", "bleed", "hold", "fear"]

static func heal_threshold(skill: Dictionary) -> float:
	return clampf(float(skill.get("auto_hp_threshold", 0.65)), 0.05, 0.95)

static func passive_trigger(skill: Dictionary) -> String:
	# Empty / always means an unconditional stat passive. Future data can specify
	# on_hit, on_damaged or on_kill and a proc_effect.
	return str(skill.get("trigger", "always")).strip_edges().to_lower()

static func passive_proc_chance(skill: Dictionary) -> float:
	return clampf(float(skill.get("proc_chance", 1.0)), 0.0, 1.0)
