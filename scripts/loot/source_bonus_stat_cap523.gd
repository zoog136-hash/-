extends RefCounted

const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SAVE_KEY := "bonus_stat_cap523"
# ConstantData #282, MaxStatValue. An extension applies to base allocation.
const BASE_LIMIT := 50
const MAX_EXACT_INTEGER := 9007199254740991
const MAX_EXTENSION := MAX_EXACT_INTEGER - BASE_LIMIT
const MIN_LEVEL := 89
const HEART := 146412
const FRUIT := 147152


static func valid_extension(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value >= 0 and value <= MAX_EXTENSION and value == int(value)


static func profile(id: int, definition: Dictionary) -> Dictionary:
	if id not in [HEART, FRUIT]:
		return {}
	var raw: Dictionary = definition.get("original_item", {})
	if raw.get("ID") != id or raw.get("TestItem") != false or raw.get("CategoryID") != 87 \
			or raw.get("LevelLimitMin") != MIN_LEVEL or raw.get("LevelLimitMax") != 0 \
			or raw.get("MaxLevelLimitMin") != 0 or raw.get("MaxLevelLimitMax") != 0 \
			or raw.get("TargettingTypeID") != 1 or raw.get("ServiceRegionCode") != "" \
			or raw.get("CanUseWhenInvisible") != true:
		return {}
	var rows: Array = definition.get("item_bonus", [])
	if rows.size() != (1 if id == HEART else 2):
		return {}
	var has_cap := false
	var has_point := false
	for row: Dictionary in rows:
		var bonus: Dictionary = row.get("bonus", {})
		if row.get("IsPossession") != false or row.get("unit", {}).get("Name") != "Value" \
				or bonus.get("Value") != 1 or bonus.get("BonusApplicationTypeID") != 0 \
				or bonus.get("BonusApplicationTargetID") != 0:
			return {}
		var kind: Dictionary = row.get("bonus_type", {})
		if kind.get("Name") == "MaxStatBonusAmount" and kind.get("ID") == 4662:
			if row.get("ID") != (228442 if id == HEART else 230552) \
					or bonus.get("ID") != (726512 if id == HEART else 730232):
				return {}
			has_cap = true
		elif id == FRUIT and kind.get("Name") == "BonusSubStatAmount" and kind.get("ID") == 4822 \
				and row.get("ID") == 230542 and bonus.get("ID") == 730222:
			has_point = true
		else:
			return {}
	if not has_cap or has_point != (id == FRUIT):
		return {}
	var limit: Dictionary = SOURCE.row("ConstantData", 282)
	if limit.get("Name") != "MaxStatValue" or limit.get("Value") != str(BASE_LIMIT) or limit.get("Type") != 1:
		return {}
	return {"stat_points": int(has_point), "can_use_when_invisible": true}
