extends RefCounted
## Explicit TWILIGHT display region. These bounds are not native M geometry.

static func normalized(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var center: Variant = value.get("center")
	var radius: Variant = value.get("radius")
	var row: Variant = value.get("row_id")
	if not center is Vector2 or not center.is_finite(): return {}
	if not (radius is int or radius is float) or not is_finite(float(radius)) or float(radius)<16.0 or float(radius)>4096.0: return {}
	if not (row is int or row is float) or not is_finite(float(row)) or float(row)<=0.0 or float(row)!=floorf(float(row)): return {}
	if not value.get("enabled") is bool or value.get("branch") not in ["default","condition"]: return {}
	return {"center":center,"radius":float(radius),"row_id":int(row),"enabled":value.enabled,"branch":value.branch}

static func at_point(value: Dictionary, point: Vector2, rules: RefCounted) -> Dictionary:
	if value.is_empty() or not bool(value.enabled): return {"status":"off","settings":{}}
	var row: Dictionary = rules.by_id.get(int(value.row_id),{})
	if row.is_empty(): return {"status":"source_unavailable","settings":{}}
	if not point.is_finite(): return {"status":"invalid_point","settings":{}}
	var delta: Vector2 = (point-value.center).abs()
	# Inclusive square and radius are the user's own game-world preference.
	if delta.x>float(value.radius) or delta.y>float(value.radius): return {"status":"outside","settings":{}}
	if value.branch=="condition" and int(row.ConditionTypeId)==0: return {"status":"condition_unavailable","settings":{}}
	var settings: Dictionary = rules.defaults_for(int(value.row_id))
	if value.branch=="condition":
		settings = {"hide_doll":bool(row.ConditionHideMagicDoll),"limit_effect_count":bool(row.ConditionLowEffectCount)}
	return {"status":"TWILIGHT_local_estimate","settings":settings,"row_id":int(value.row_id),"branch":value.branch}
