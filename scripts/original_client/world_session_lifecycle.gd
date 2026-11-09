extends RefCounted
## C25 / P7. DESIGN_NOT_RECOVERED_API. Scene-ownership bookkeeping. Every owner field
## carries the basis it was derived on; raw owners are not Cocos-retained children.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const SOURCE_SURFACE := Vector2i(928, 684)
const OUTPUT_SURFACE := Vector2i(1200, 675)
const SURFACE_FORMAT := 4 # RGB565
const EVENT3_HANDLER := 0x01CC57A0

static func make() -> Dictionary:
	return {"record": "WorldSessionLifecycle", "design_status": VOCAB.EVIDENCE_DESIGN, "main_root": "root",
		"event_receiver": {"value": "root+10", "basis": "EventReceiver this=root+10"},
		"raw_helpers": {"check_timer_updater": {"slot": "root+70", "value": null, "basis": "raw_owner"}, "put_object_tile_helper": {"slot": "root+78", "value": null, "basis": "raw_owner"}},
		"dynamic_loader": {"slots": ["root+60", "root+68"], "basis": "shared_pair_distinct_from_raw_helpers"},
		"grid": null, "surfaces": {"source": {"size": SOURCE_SURFACE, "format": SURFACE_FORMAT, "role": "render"}, "output": {"size": OUTPUT_SURFACE, "format": SURFACE_FORMAT, "role": "ui"}},
		"ui_roots": [], "log": []}

## local2: UI state -> grid init -> create both helpers. Duplicates are NOT claimed idempotent.
static func local2(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	(out["log"] as Array).append("ui_state")
	(out["log"] as Array).append("grid_init")
	out["grid"] = {"initialised": true}
	out["raw_helpers"]["check_timer_updater"]["value"] = "created"
	out["raw_helpers"]["put_object_tile_helper"]["value"] = "created"
	(out["log"] as Array).append("helpers_created")
	return out

## event 3 deletes the root+70/+78 raw owners and nulls them. root+60/+68 are never deleted here.
static func event3(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var deleted: Array = []
	for key: String in ["check_timer_updater", "put_object_tile_helper"]:
		if out["raw_helpers"][key]["value"] != null:
			deleted.append(out["raw_helpers"][key]["slot"])
		out["raw_helpers"][key]["value"] = null
	out["deleted_slots"] = deleted
	out["handler"] = EVENT3_HANDLER
	return out

## local3: both raw owners deleted, then the world grid is cleaned.
static func local3(state: Dictionary) -> Dictionary:
	var out: Dictionary = event3(state)
	out["grid"] = null
	return out

## 021ED160 setup of the output surface node.
static func output_node() -> Dictionary:
	return {"name": "LineageGame", "scale_y": -1.0, "position": "visible_size_center", "parent_add_child": true,
		"final_orientation": "UNVERIFIED_flip_and_uv_flip_not_cancelled_by_assumption"}
