extends RefCounted
## C26 / P7. DESIGN_NOT_RECOVERED_API. Per-stage render observations so API-call success is never
## recorded as on-screen success.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")

static func make() -> Dictionary:
	return {"record": "RenderTrace", "design_status": VOCAB.EVIDENCE_DESIGN, "floor_decision": null, "item_suffix": null, "blend_branch": null,
		"cpu_surface": null, "texture_upload": null, "scene_visit": [], "command_queue": [], "screen_success": "UNOBSERVED"}

## Cell items: with cell+58 == 0 and N > 0, the LAST N item pointers are drawn in stored order.
## A true row gate makes N = 35. Nothing here sorts. visited_slots counts the suffix, which is
## separate from null skips and from the number actually drawn.
static func item_suffix(count: int, cell_u16_58: int, row_gate: bool) -> Dictionary:
	if cell_u16_58 != 0:
		return {"start_index": count, "visited_slots": 0, "applied": false}
	var n: int = 35 if row_gate else 0
	if n <= 0:
		return {"start_index": count, "visited_slots": 0, "applied": false}
	n = mini(n, count)
	return {"start_index": count - n, "visited_slots": n, "applied": true}

## The floor interceptor and the item opaque-admission dispatcher are different; an accepted
## floor never skips item processing.
static func process_cell(trace: Dictionary, floor_accepted: bool, count: int, cell_u16_58: int, row_gate: bool) -> Dictionary:
	var out: Dictionary = trace.duplicate(true)
	out["floor_decision"] = {"accepted": floor_accepted}
	out["item_suffix"] = item_suffix(count, cell_u16_58, row_gate)
	out["item_dispatcher_ran"] = true
	return out

## updateWithData returns false for texture name 0; the Surface caller does not consume the bool.
static func texture_upload(trace: Dictionary, texture_name: int, api_called: bool) -> Dictionary:
	var out: Dictionary = trace.duplicate(true)
	var returned: bool = texture_name != 0
	out["texture_upload"] = {"api_called": api_called, "returned": returned, "caller_consumed_bool": false}
	out["screen_success"] = "UNOBSERVED"
	return out
