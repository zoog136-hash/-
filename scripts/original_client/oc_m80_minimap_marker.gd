extends RefCounted
## M80 (C10/C13/C18, R80). DESIGN_NOT_RECOVERED_API. Minimap target marker lifetime. A duplicate
## updates the same Node (no factory); empty/expired/alias-null snapshots keep the existing marker;
## only remove-then-reappear takes the new-instance path; refresh re-attaches the existing Node.
## Setter values are not the per-frame visibility: the CSB VisibleForFrame tracks of
## /Nd/Panel_Arrow and Panel_Dot (loop windows 5..30 and 35..100) can change it afterwards.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

const ARROW_TAG_VALUE := 1234567
const LOOP_WINDOWS := [[5, 30], [35, 100]]

static func make() -> Dictionary:
	return {"markers": {}, "factory_calls": 0, "next_node": 1, "reattach_calls": 0}

## snapshot: {"status": "valid"|"empty"|"expired"|"alias_null", "target": id, "visible": bool}
static func apply_snapshot(mm: Dictionary, snapshot: Dictionary) -> Dictionary:
	var out: Dictionary = mm.duplicate(true)
	if snapshot.get("status") != "valid":
		return {"state": out, "path": "PRESERVE_EXISTING"}
	var t: Variant = snapshot.target
	if out.markers.has(t):
		out.markers[t].setter_visible = bool(snapshot.get("visible", true))
		out.markers[t].updates = int(out.markers[t].updates) + 1
		return {"state": out, "path": "UPDATE_SAME_NODE"}
	out.markers[t] = {"node": out.next_node, "setter_visible": bool(snapshot.get("visible", true)), "updates": 0, "tag": null}
	out.next_node = int(out.next_node) + 1
	out.factory_calls = int(out.factory_calls) + 1
	return {"state": out, "path": "NEW_INSTANCE"}

static func remove(mm: Dictionary, target: Variant) -> Dictionary:
	var out: Dictionary = mm.duplicate(true)
	out.markers.erase(target)
	return out

static func refresh(mm: Dictionary) -> Dictionary:
	var out: Dictionary = mm.duplicate(true)
	out.reattach_calls = int(out.reattach_calls) + out.markers.size()
	return out

## Hide is not unsubscribe/destroy/pending cancel.
static func hide(mm: Dictionary) -> Dictionary:
	var out: Dictionary = mm.duplicate(true)
	out["view_visible"] = false
	out["subscribed"] = true
	out["destroyed"] = false
	return out

## E0330B7BC: the caller writes tag 1234567 without a timeline null guard. The helper's own null
## guard does not protect this write.
static func arrow_after_timeline(marker: Dictionary, timeline_null: bool) -> Dictionary:
	var out: Dictionary = marker.duplicate(true)
	out["tag"] = ARROW_TAG_VALUE
	out["helper_ran"] = not timeline_null
	return out

## Per-frame visibility is a separate observation from the setter.
static func frame_visibility(marker: Dictionary, frame: int) -> Dictionary:
	var windows: Array = []
	for w: Array in LOOP_WINDOWS:
		if frame >= int(w[0]) and frame <= int(w[1]):
			windows.append(w)
	return {"setter_visible": marker.setter_visible, "frame": frame, "track_windows_containing_frame": windows, "final_visibility": "NOT_OBSERVED"}
