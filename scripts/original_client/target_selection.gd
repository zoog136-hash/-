extends RefCounted
## C23 / P6. DESIGN_NOT_RECOVERED_API. Client-side target selection and the AutoPlay timer.
## No NPC AI, hostility, server attack authority or reward logic lives here.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
## 0.4 as binary32. The timer fires only on a strict greater-than against this value.
const INTERVAL_F32 := 0.4000000059604645
const PLAYER_ORIGIN_BONUS := 150
const AUTO_SELECTOR_ORIGIN_BONUS := 140

static func f32(value: float) -> float:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_float(0, value)
	return raw.decode_float(0)

static func make_state() -> Dictionary:
	return {"record": "SelectionState", "design_status": VOCAB.EVIDENCE_DESIGN, "current": null, "previous": null, "front_oid": null, "exclusions": [],
		"forced_state": null, "enabled": false, "pause_reasons": [], "timer_elapsed": 0.0}

## enabled and pause reasons are separate: enabled stays true while paused.
static func is_running(state: Dictionary) -> bool:
	return bool(state.enabled) and (state.pause_reasons as Array).is_empty()

## One tick: accumulate in binary32; fire at most once and subtract one interval. No catch-up loop.
static func timer_tick(state: Dictionary, dt: float) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var elapsed: float = f32(float(state.timer_elapsed) + f32(dt))
	var fired: bool = elapsed > INTERVAL_F32
	if fired:
		elapsed = f32(elapsed - INTERVAL_F32)
	out["timer_elapsed"] = elapsed
	return {"state": out, "fired": fired}

## Candidate: {"oid", "category", "path_nodes", "dx", "dy", "origin_bonus"?}. Score is the low 32 bits
## of (path_node_count << 10) + D with D = dx*dx/4 + dy*dy (dx*dx/4 truncates).
@warning_ignore("integer_division")
static func score(path_nodes: int, dx: int, dy: int, origin_bonus: int = 0) -> int:
	var d: int = (dx * dx) / 4 + dy * dy
	return ((path_nodes << 10) + d + origin_bonus) & 0xFFFFFFFF

## Stable ordering by (primary, secondary) score; ties keep the INPUT order. No LUID tie-break.
static func rank(candidates: Array) -> Array:
	var indexed: Array = []
	for i: int in candidates.size():
		var c: Dictionary = (candidates[i] as Dictionary).duplicate()
		c["original_order"] = i
		indexed.append(c)
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.primary != b.primary:
			return int(a.primary) < int(b.primary)
		if a.secondary != b.secondary:
			return int(a.secondary) < int(b.secondary)
		return int(a.original_order) < int(b.original_order))
	return indexed

## selector 3: first non-empty category in priority order (after Hunting/Looting reorder), not a union.
static func selector3(categories_by_priority: Array) -> Dictionary:
	for entry: Variant in categories_by_priority:
		if not (entry.candidates as Array).is_empty():
			return {"category": entry.category, "candidates": entry.candidates}
	return {"category": null, "candidates": []}

## Retention: a resolved front with no exclusion stops a fresh search even when re-selection fails.
static func retain_front(front_resolved: bool, exclusions: Array, reselect_eligible: bool) -> Dictionary:
	var retention: bool = front_resolved and exclusions.is_empty()
	return {"retention": retention, "new_search_blocked": retention, "reselect_succeeded": retention and reselect_eligible}

## A gated clear is a no-op; forceOID and state are preserved.
static func request_clear(state: Dictionary, gate_blocks: bool) -> Dictionary:
	if gate_blocks:
		return state.duplicate(true)
	var out: Dictionary = state.duplicate(true)
	out["previous"] = state.current
	out["current"] = null
	return out
