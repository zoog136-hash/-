extends RefCounted
## Saves made before the 523 resource pack can sit on an old map (the old
## PNG/remake fields: faith, albino, escaros, oman, temples ...). With the 523
## pack installed, Aden is the 523 host and those old maps only ever had
## monsters from the old base508 monster pack, which current installs do not
## have: the character loaded there met no monsters at all, or the load was
## refused when the old map pictures were gone. Such a save is moved once to
## 523 Aden town (Land 4), keeping all progression. The original file is
## backed up byte for byte by the caller, and the move is recorded in the
## save so it happens only once.

const KEY := "old_map_relocation523"
const TARGET_MAP := "aden_world"

## True when `data` (a parsed save) must be moved to 523 Aden on load.
static func needed(data: Dictionary, host_requested: bool, legacy_layouts: bool) -> bool:
	if not host_requested or legacy_layouts: return false
	if data.has(KEY): return false
	var map_id: String = str(data.get("map_id", ""))
	# 523 Aden itself and original source-travel maps (l1_*) are 523 maps.
	if map_id.is_empty() or map_id == TARGET_MAP or map_id.begins_with("l1_"): return false
	# A dungeon run in progress keeps its own map and rules.
	var runs: Variant = data.get("source_dungeon523", {})
	if runs is Dictionary:
		var active: Variant = (runs as Dictionary).get("active", {})
		if active is Dictionary and str(active.get("status", "")) == "active" and str(active.get("map_id", "")) == map_id: return false
	return true

## A copy of `data` placed at 523 Aden town, with where it was recorded.
static func relocated(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result[KEY] = {
		"from_map_id": str(data.get("map_id", "")),
		"from_position": data.get("position", []),
		"from_original_position": data.get("original_position", {}),
	}
	result["map_id"] = TARGET_MAP
	result["position"] = []
	result["map_layout_revision"] = -1
	result["original_position"] = {}
	# No saved 523 spot: 523 play mode starts the character at Aden town.
	result.erase("character_source_cursor")
	for key: String in ["native_png_plan_sha256", "native_png_review_sha256", "oman_png_index_sha256"]:
		result.erase(key)
	return result
