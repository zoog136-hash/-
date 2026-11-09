extends RefCounted
## M51 + M79 (C10/C12/C15; R51, R79_A, R79_B). DESIGN_NOT_RECOVERED_API. Manual-move gate and
## A6/A8 request preparation. Preparing a request is not a send, an ACK or server acceptance;
## no sender success bool is checked anywhere on this path. Candidate directions arrive from the
## caller: how the original generates them is not reproduced here.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

## R51: dynamic_cast target is cocos2d::ui::Button (not Widget). class_chain = most-derived first.
static func cast_node_to_button(node_id: Variant, class_chain: Array) -> Dictionary:
	var ok: bool = node_id != null and "Button" in class_chain
	return V.rec("ButtonCast", "M51", V.CONFIRMED, {"result": node_id if ok else null, "cast_target": "cocos2d::ui::Button"})

## R51: the old "returns bool true" claim is removed; the return type is not fixed.
static func focus_handler_return() -> Dictionary:
	return V.rec("FocusReturn", "M51", V.UNKNOWN, {"bool_true_claim": "REMOVED_BY_ERRATUM", "return_type": V.UNKNOWN})

## R79_A: walk the raw Actor's component ordered map; the first non-null ComponentBase ->
## PlayerComponent dynamic_cast result gets a strong ref. components: [{"id", "player_component": bool, "byte218": int}]
static func acquire_player_component(components: Array) -> Dictionary:
	for c: Dictionary in components:
		if bool(c.get("player_component", false)) and c.get("id") != null:
			return {"component": c, "strong_acquired": true}
	return {"component": null, "strong_acquired": false}

## Tick gate: byte +218 nonzero -> release and return from tick; lookup null -> continue.
static func player_gate(components: Array) -> Dictionary:
	var got: Dictionary = acquire_player_component(components)
	if got.component == null:
		return V.rec("PlayerGate", "M79", V.CONFIRMED, {"continue_tick": true, "released": false, "component_found": false})
	if int(got.component.get("byte218", 0)) & 0xFF != 0:
		return V.rec("PlayerGate", "M79", V.CONFIRMED, {"continue_tick": false, "released": true, "component_found": true})
	return V.rec("PlayerGate", "M79", V.CONFIRMED, {"continue_tick": true, "released": false, "holding_strong": true, "component_found": true})

## S0675 L55. collision: {"observer_dword10", "terrain_reject", "portal", "actors": [...] , "self_id"}
## actor: {"id", "component_first_null": bool, "contains": bool, "pred_01C8F9A0": bool}
static func candidate_collision(collision: Dictionary) -> Dictionary:
	if int(collision.get("observer_dword10", 0)) != 0:
		return {"allowed": true, "path": "observer_skip_collision"}
	if bool(collision.get("terrain_reject", false)):
		return {"allowed": false, "path": "terrain_helper_allow40_false_true"}
	if bool(collision.get("portal", false)):
		return {"allowed": true, "path": "portal_skips_actor_loop"}
	for a: Dictionary in collision.get("actors", []):
		if a.get("id") == collision.get("self_id"):
			continue
		if bool(a.get("component_first_null", false)) or not bool(a.get("contains", false)):
			continue
		if not bool(a.get("pred_01C8F9A0", true)):
			return {"allowed": false, "path": "actor_occupancy_reject"}
	return {"allowed": true, "path": "actor_loop_passed"}

## C-style signed remainder (truncating), kept explicit for direction arithmetic.
## A zero divisor is not defended by the original; the design layer returns null instead.
static func signed_remainder(a: int, b: int) -> Variant:
	if b == 0:
		return null
	return a % b

## One manual-move decision. state: {"facing", "pending", "field50", "field22", "field78", "timer_handle", "field90", "field98"}
## candidates: [{"direction": int, "collision": Dictionary}], original_direction: int32 value.
static func manual_move(state: Dictionary, candidates: Array, original_direction: int) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var trace: Array = []
	for cand: Dictionary in candidates:
		var col: Dictionary = candidate_collision(cand.get("collision", {}))
		trace.append("candidate:%d:%s" % [int(cand.direction), col.path])
		if not col.allowed:
			continue
		trace.append("reset_01FEE540")
		if int(cand.direction) == int(state.get("facing", -1)) or bool(state.get("pending", false)):
			trace.append("skip_this_A6_only")
			return V.rec("ManualMove", "M79", V.CONFIRMED, {"state": out, "trace": trace, "a6_prepared": false, "a8_prepared": false, "sender_success_checked": false})
		out["field50"] = 999
		out["field22"] = 0
		trace.append_array(["write_+50=999", "write_+22=0", "call_A6_02476960"])
		# After the normal return only. The stored +78 value and the new handle are not given by the package.
		out["field78"] = "STORED_AFTER_A6_RETURN"
		out["timer_handle"] = "REPLACED_AFTER_A6_RETURN"
		out["field90"] = 0
		out["field98"] = 0
		trace.append_array(["store_+78", "replace_timer_handle", "write_+90=0", "write_+98=0", "release_old"])
		return V.rec("ManualMove", "M79", V.CONFIRMED, {"state": out, "trace": trace, "a6_prepared": true, "a6_direction": int(cand.direction), "a8_prepared": false, "sender_success_checked": false})
	trace.append("all_candidates_rejected_A8_prepare_sender_ingress")
	return V.rec("ManualMove", "M79", V.CONFIRMED, {"state": out, "trace": trace, "a6_prepared": false, "a8_prepared": true,
		"a8_direction_i32": V.i32(original_direction), "sender_success_checked": false, "server_accepted": V.UNKNOWN})
