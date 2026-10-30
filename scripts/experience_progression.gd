extends RefCounted
class_name TwilightExperienceProgression

const DATA_PATH: String = "res://data/experience_progression_v1.json"
const CURVE_VERSION: int = 2
# Lineage M Dragon's Holy Water gives 31.92M EXP. The v2 curve is the Lineage M
# curve scaled for TWILIGHT at 3x speed, so the item keeps 3x its relative value.
# Regenerate with tools/generate_experience_curve.py (prints the equivalent).
const HOLY_WATER_EXP: int = 3864874

# This is a TWILIGHT balance table, NOT a claimed official Lineage M XP table.
# v2: about 3x faster than Lineage M in kills per level (blessing 4x).
# Existing saved progress is migrated by fractional progress, not reset.
# Hunting-ground EXP bonus by map family (user balance request, 2026-10-31).
# Applies to the monster's EXP where it is killed; blessing use stays on base EXP.
const MAP_EXP_MULTIPLIERS: Dictionary = {
	"oman_": 5.0,       # 오만의 탑 1~10층
	"domination": 20.0, # 지배의 탑
	"escaros": 20.0,    # 에스카로스 (escaros_01~05, escaros_world)
}

static func map_exp_multiplier(map_id: String) -> float:
	for prefix: String in MAP_EXP_MULTIPLIERS:
		if map_id.begins_with(prefix):
			return float(MAP_EXP_MULTIPLIERS[prefix])
	return 1.0

static func table_requirement(level: int) -> int:
	if level < 1 or not FileAccess.file_exists(DATA_PATH):
		return -1
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (content is Dictionary):
		return -1
	var document: Dictionary = content as Dictionary
	var values: Variant = document.get("required_for_level", {})
	if not (values is Dictionary):
		return -1
	var required: Dictionary = values as Dictionary
	var key: String = str(level)
	if not required.has(key):
		return -1
	return maxi(1, int(required[key]))

static func required_for_level(level: int, previous_need: int) -> int:
	var value: int = table_requirement(level)
	if value > 0:
		return value
	# Preserve legacy behavior for levels not yet covered by the table.
	return maxi(1, int(round(float(maxi(1, previous_need)) * 1.14 + 120.0)))

static func migrate_progress(level: int, saved_experience: int, saved_need: int, saved_version: int) -> Dictionary:
	var old_need: int = maxi(1, saved_need)
	if saved_version >= CURVE_VERSION:
		return {"experience": maxi(0, saved_experience), "exp_need": old_need}
	var current_need: int = table_requirement(level)
	if current_need <= 0:
		return {"experience": maxi(0, saved_experience), "exp_need": old_need}
	# No level-loss and no free XP: preserve the in-level fraction.
	var fraction: float = clampf(float(maxi(0, saved_experience)) / float(old_need), 0.0, 1.0)
	return {
		"experience": maxi(0, int(round(fraction * float(current_need)))),
		"exp_need": current_need
	}
