extends RefCounted
## C15 / P4. DESIGN_NOT_RECOVERED_API. Received movement and actor playback state. Receive,
## step and draw are separate events; draw anchor (+140), step destination (+148) and the
## received/planned consumed position (+150) are separate coordinates. No client prediction.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const COLLISION = preload("res://scripts/original_client/terrain_collision.gd")

static func internal_x(source_x: int) -> int:
	return VOCAB.i32(2 * source_x - 0x8000)

static func make_state() -> Dictionary:
	return {"record": "ActorMotionState", "design_status": VOCAB.EVIDENCE_DESIGN, "draw_anchor": Vector2i.ZERO, "step_destination": Vector2i.ZERO,
		"received_position": Vector2i.ZERO, "local_goal": null, "facing": 0, "action": 0, "ordinal": 0, "picture": 0, "timer_generation": 0,
		"manager_flags": 0, "manager_counter": 0, "queue": [], "timers": []}

## Source coordinate -> internal x = low32(2x - 0x8000), y unchanged. Only the received
## position changes; nothing is drawn yet.
static func receive_position(state: Dictionary, source_x: int, source_y: int) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["received_position"] = Vector2i(internal_x(source_x), source_y)
	return out

## Move start: old draw removed, the record point becomes the draw anchor, one step in the
## direction becomes the step destination, facing/action/ordinal restart, then one advance.
## A normal path with at least two points therefore shows ordinal 1 on its first new frame.
static func begin_step(state: Dictionary, record_point: Vector2i, direction: int, path_count: int, action: int) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["draw_anchor"] = record_point
	out["step_destination"] = COLLISION.direction_step(record_point, direction)
	out["facing"] = direction & 7
	out["action"] = action
	out["ordinal"] = 1 if path_count >= 2 else 0
	out["timer_generation"] = int(state.timer_generation) + 1
	return out

## CANCEL ACK resets the manager flags and counter. It does not clear coordinates, the move
## queue, or stop the current step on its own.
static func cancel_ack(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["manager_flags"] = 0
	out["manager_counter"] = 0
	return out

## END: when the target is not near the player's consumed position the planned path may be
## kept for re-pathing or the next request; it is not dropped here.
static func end_event(state: Dictionary, is_near: bool) -> Dictionary:
	return {"state": state, "replan_possible": not is_near, "path_kept": not is_near, "next_request_possible": true}

static func schedule_timer(state: Dictionary, callback_id: int, object_id: int, kind: String) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	(out["timers"] as Array).append({"callback": callback_id, "object": object_id, "kind": kind})
	return out

## A timer is removed only when BOTH the callback and the object match.
static func cancel_timer(state: Dictionary, callback_id: int, object_id: int) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var kept: Array = []
	for timer: Dictionary in state.timers:
		if not (timer.callback == callback_id and timer.object == object_id):
			kept.append(timer)
	out["timers"] = kept
	return out
