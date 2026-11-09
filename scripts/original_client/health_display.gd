extends RefCounted
## C22 / P5. DESIGN_NOT_RECOVERED_API. Health percentages and overhead state. Received
## values and the display clamp are different things; server health maths is not here.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const PAYLOAD_MAX_HP := 0x1C
const PAYLOAD_HP := 0x20
const PAYLOAD_MAX_MP := 0x24
const PAYLOAD_MP := 0x28
const OVERHEAD_ROW_PAYLOAD := 8
const OVERHEAD_ID_OFFSET := 0x20

static func make_input(identity: Variant, raw_hp: int, max_hp: int, raw_mp: int, max_mp: int, source_event: String) -> Dictionary:
	return {"record": "HealthDisplayInput", "design_status": VOCAB.EVIDENCE_DESIGN, "identity": identity, "raw_hp": raw_hp, "max_hp": max_hp,
		"raw_mp": raw_mp, "max_mp": max_mp, "source_event": source_event}

## General percent: signed32(current * 100) / max, integer division truncating toward zero.
## A zero maximum is the original's undefended boundary and is refused here (DESIGN).
@warning_ignore("integer_division")
static func raw_percent(current: int, maximum: int) -> Dictionary:
	var max32: int = VOCAB.i32(maximum)
	if max32 == 0:
		return {"status": "ZERO_MAX_REJECTED_DESIGN", "percent": null}
	var scaled: int = VOCAB.i32(current * 100)
	if scaled == -2147483648 and max32 == -1:
		return {"status": "IDIV_OVERFLOW_REJECTED_DESIGN", "percent": null}
	return {"status": "OK", "percent": scaled / max32}

## NpcHpMp: the HP branch is guarded by maxMP > 0 and divides by maxHP. maxMP 0 gives 0%.
static func npc_hp_percent(raw_hp: int, max_hp: int, max_mp: int) -> Dictionary:
	if max_mp <= 0:
		return {"status": "OK", "hp_percent": 0}
	var result: Dictionary = raw_percent(raw_hp, max_hp)
	return {"status": result.status, "hp_percent": result.percent}

## Executable side: the raw 32-bit value is zero-extended to a float; the library clamps
## the displayed value to 0..100. A negative raw percent therefore becomes a huge positive
## number and clamps to 100, which is not the same as clamping the signed value to 0.
static func display_percent(raw_percent_value: int) -> Dictionary:
	var zero_extended: int = raw_percent_value & 0xFFFFFFFF
	return {"zero_extended": zero_extended, "display": clampf(float(zero_extended), 0.0, 100.0),
		"signed_clamp_would_be": clampf(float(raw_percent_value), 0.0, 100.0)}

## The overhead keeps the last raw percent, written BEFORE the node lookup. A repeat of the
## same raw percent does not look the node up again, even if the node has appeared since.
static func overhead_update(state: Dictionary, raw_percent_value: int, node_present_now: bool) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	if out.get("raw_percent_cache") == raw_percent_value:
		out["lookup_performed"] = false
		return out
	out["raw_percent_cache"] = raw_percent_value
	out["lookup_performed"] = true
	out["node_presence"] = node_present_now
	return out
