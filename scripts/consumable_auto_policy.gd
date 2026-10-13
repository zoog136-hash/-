extends RefCounted
class_name TwilightConsumableAutoPolicy

# TWILIGHT safety defaults, not claims about official Lineage M settings.
const RULES = preload("res://scripts/consumable_rules.gd")
const DEFAULTS: Dictionary = {
	"hp_enabled":true, "hp_percent":70,
	"mp_enabled":true, "mp_percent":30,
	"long_mp_enabled":false, "long_mp_percent":20
}

static func normalize(input: Variant) -> Dictionary:
	var result: Dictionary = DEFAULTS.duplicate(true)
	if not input is Dictionary:
		return result
	var data: Dictionary = input as Dictionary
	for key: String in ["hp_enabled", "mp_enabled", "long_mp_enabled"]:
		if data.get(key) is bool:
			result[key] = data[key]
	for key: String in ["hp_percent", "mp_percent", "long_mp_percent"]:
		var value: Variant = data.get(key)
		if (value is int or value is float) and is_finite(float(value)):
			result[key] = clampi(roundi(float(value)), 5, 95)
	return result

static func below_threshold(current: int, maximum: int, percent: int) -> bool:
	if maximum <= 0 or current < 0 or current >= maximum:
		return false
	return float(current) * 100.0 <= float(maximum) * float(percent)

static func priority(record: Dictionary, spec: Dictionary) -> int:
	if int(record.get("heal", 0)) > 0:
		return 0
	if str(spec.get("kind", "")) == "instant_mp":
		return 1
	return 2

static func wanted(item_name: String, record: Dictionary, spec: Dictionary,
		settings: Dictionary, hp: int, max_hp: int, mp: int, max_mp: int,
		job: String, active_buffs: Dictionary) -> bool:
	if RULES.is_removed_item(item_name):
		return false
	if int(record.get("heal", 0)) > 0:
		return bool(settings.hp_enabled) and below_threshold(hp, max_hp, int(settings.hp_percent))
	var kind: String = str(spec.get("kind", ""))
	if kind == "instant_mp":
		if float(spec.get("cooldown", 0.0)) >= 60.0:
			return bool(settings.long_mp_enabled) and below_threshold(mp, max_mp, int(settings.long_mp_percent))
		return bool(settings.mp_enabled) and below_threshold(mp, max_mp, int(settings.mp_percent))
	if kind not in ["regen", "food", "buff"]:
		return false
	var classes: Variant = spec.get("classes", [])
	if classes is Array and not classes.is_empty() and not classes.has(job):
		return false
	var group: String = str(spec.get("group", ""))
	var normalized_name: String = RULES.normalize_name(item_name)
	for key: Variant in active_buffs.keys():
		var value: Variant = active_buffs[key]
		if not value is Dictionary:
			continue
		var buff: Dictionary = value as Dictionary
		if float(buff.get("remaining", 0.0)) <= 0.0:
			continue
		if RULES.normalize_name(str(key)) == normalized_name:
			return false
		if not group.is_empty() and str(buff.get("group", "")) == group:
			return false
	return true
