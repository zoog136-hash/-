extends RefCounted
## User preferences only. Source territory conditions are not inferred here.
const REGION_KEYS: Array[String] = ["effect_detail", "limit_effect_count", "hide_doll"]
const DEFAULTS: Dictionary = {"impact_intensity":0.85, "reduced_motion":false,
	"effect_detail":"full", "limit_effect_count":false, "hide_doll":false}

static func normalized(value: Dictionary, base: Dictionary = DEFAULTS) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: String in DEFAULTS:
		if not value.has(key): continue
		if key == "effect_detail":
			if value[key] is String and value[key] in ["full", "low"]: result[key] = value[key]
		elif key == "impact_intensity":
			if (value[key] is float or value[key] is int) and is_finite(float(value[key])):
				result[key] = clampf(float(value[key]), 0.0, 1.0)
		elif value[key] is bool: result[key] = value[key]
	return result

static func region(value: Dictionary) -> Dictionary:
	var clean: Dictionary = normalized(value)
	var result: Dictionary = {}
	for key: String in REGION_KEYS:
		if not value.has(key): continue
		if key == "effect_detail":
			if value[key] is String and value[key] in ["full", "low"]: result[key] = clean[key]
		elif value[key] is bool: result[key] = value[key]
	return result

static func effective(global: Dictionary, overrides: Dictionary, map_id: String) -> Dictionary:
	var result: Dictionary = normalized(global)
	var local: Variant = overrides.get(map_id, {})
	if local is Dictionary: result.merge(region(local), true)
	return result
