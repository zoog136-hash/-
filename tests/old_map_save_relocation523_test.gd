extends SceneTree
## Old saves on old maps (pre-523 pack: faith, albino, escaros, oman ...)
## are moved once to 523 Aden town when the 523 pack is installed. Synthetic
## save dictionaries only; no packs or real saves are read.
const RELOCATION = preload("res://scripts/maps/old_map_save_relocation523.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	var old_save: Dictionary = {"map_id":"faith_01", "position":[1200.0, 640.0], "map_layout_revision":2026102002,
		"native_png_plan_sha256":"a".repeat(64), "native_png_review_sha256":"a".repeat(64), "original_position":{},
		"level":35, "gold":1234, "inventory":{"HP 물약":10}, "character_source_cursor":{"native_land_id":7, "source_position":[1, 2]}}
	check(RELOCATION.needed(old_save, true, false), "old map save with the 523 pack moves")
	check(not RELOCATION.needed(old_save, false, false), "without the 523 pack the old map stays")
	check(not RELOCATION.needed(old_save, true, true), "explicit legacy layouts keep the old map")
	for map_id: String in ["aden_world", "l1_4", ""]:
		var save: Dictionary = old_save.duplicate(true); save.map_id = map_id
		check(not RELOCATION.needed(save, true, false), "523 map %s is not moved" % map_id)
	var in_run: Dictionary = old_save.duplicate(true)
	in_run["source_dungeon523"] = {"active":{"status":"active", "map_id":"faith_01"}}
	check(not RELOCATION.needed(in_run, true, false), "an active dungeon run keeps its map")
	var moved: Dictionary = RELOCATION.relocated(old_save)
	check(moved.map_id == "aden_world" and moved.position == [] and moved.map_layout_revision == -1, "placed at Aden with no old position")
	check(moved.original_position == {} and not moved.has("character_source_cursor"), "523 play mode starts at Aden town")
	check(not moved.has("native_png_plan_sha256") and not moved.has("native_png_review_sha256"), "old map picture keys dropped")
	check(moved.level == 35 and moved.gold == 1234 and moved.inventory == {"HP 물약":10}, "progression unchanged")
	check(moved[RELOCATION.KEY] == {"from_map_id":"faith_01", "from_position":[1200.0, 640.0], "from_original_position":{}}, "move recorded: " + str(moved.get(RELOCATION.KEY)))
	check(old_save.map_id == "faith_01" and old_save.has("character_source_cursor"), "input save untouched")
	check(not RELOCATION.needed(moved, true, false), "moved only once")
	var marked_new: Dictionary = old_save.duplicate(true); marked_new[RELOCATION.KEY] = {}
	check(not RELOCATION.needed(marked_new, true, false), "saves written by this build are not moved again")
	print("OLD_MAP_SAVE_RELOCATION523_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
