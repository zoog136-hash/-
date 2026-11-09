extends RefCounted
## C19 / P5. DESIGN_NOT_RECOVERED_API. Big-map and minimap presentation state. The world
## S32 and the big-map UI texture are separate; the minimap consumes the local 1CB payload
## directly and is not driven by the big map's member-cache refresh.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const PARTY_CONTAINER := "ICON_NODE_PARTY"
const TABS := ["World", "Area", "Dungeon", "Special", "Siege"]

static func make_state(tab: String, selected_land: int, image_key: String) -> Dictionary:
	return {"record": "MapPresentationState", "design_status": VOCAB.EVIDENCE_DESIGN, "tab": tab, "selected_land": selected_land, "image_key": image_key,
		"view_generation": 0, "party_cache": [], "visible": true, "subscribed": true, "destructed": false, "minimap": {}}

## Party markers are PARTY1..PARTY4 (the later PARTY1-4 contract wins over the earlier
## ICON_ wording); the container ICON_NODE_PARTY keeps its name. ICON_1..4 is never made.
static func party_node_name(index: int) -> Variant:
	return "PARTY%d" % index if index >= 1 and index <= 4 else null

static func party_node_names() -> Array:
	return ["PARTY1", "PARTY2", "PARTY3", "PARTY4"]

## The World/Area four-number sprite reuse loop is a member-index loop, not the server's
## party capacity. Dungeon walks all members separately.
static func party_capacity_from_sprite_loop() -> Dictionary:
	return {"capacity": null, "status": "NOT_DERIVABLE_FROM_SPRITE_REUSE_LOOP"}

## Local 1CB: the minimap reads map, channel and coordinates straight from the payload.
static func apply_minimap_local_1cb(state: Dictionary, payload: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["minimap"] = {"map": payload.get("map"), "channel": payload.get("channel"), "x": payload.get("x"), "y": payload.get("y"), "source": "local_1cb_payload", "waited_for_big_map_timer": false}
	return out

## The big map refreshes from its member cache on a timer, independently.
static func big_map_timer_refresh(state: Dictionary, members: Array) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["party_cache"] = members.duplicate(true)
	out["view_generation"] = int(state.view_generation) + 1
	return out

## Hiding the view is only hiding: nothing is destructed or unsubscribed by it.
static func hide_view(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["visible"] = false
	return out

static func destruct_view(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["visible"] = false
	out["subscribed"] = false
	out["destructed"] = true
	return out
