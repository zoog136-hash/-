extends RefCounted
## M56 v2, M61, M62, M63, M65 (C09/C13). DESIGN_NOT_RECOVERED_API. Actor death/polymorph state
## step, packet sprite width, effect duplicate suppression, special-attack selector arithmetic and
## pending actor materialization. Selecting or creating an effect is not a displayed result.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

# ---- M56 -------------------------------------------------------------------------------
const EVENT_2F8 := 0x2F8
const EVENT_9DD := 0x9DD

## Q56-M1: after virtual+108, AL nonzero returns to the epilogue BEFORE the buff read; only zero
## goes on. The meaning of virtual+108 is not fixed.
static func buff_gate(al: int) -> String:
	return "EPILOGUE_BEFORE_BUFF_READ" if (al & 0xFF) != 0 else "PROCESS_BUFF"

## Q56-M3: desired/filtered are copied first. state2 live-clears and jumps past BOTH normal-path
## events 2F8 and 9DD; desired is kept. Receiving the packet never means reconcile is complete.
static func apply_desired(actor: Dictionary, desired: Array, filtered: Array, state: int) -> Dictionary:
	var out: Dictionary = actor.duplicate(true)
	out["desired"] = desired.duplicate()
	out["filtered"] = filtered.duplicate()
	var events: Array = []
	var evidence: String = V.CONFIRMED
	if state == 2:
		out["live"] = []
	else:
		events = [EVENT_2F8, EVENT_9DD]
		evidence = V.CONDITIONAL
	return V.rec("ActorDesiredApply", "M56", evidence, {"actor": out, "events": events, "reconcile_complete": false})

# ---- M61 -------------------------------------------------------------------------------
const CONSTANTDATA_CANDIDATE_20889 := 20889

## Packet sprite input is narrowed to signed16 (65536 -> 0). That is a width example, not the final
## sprite after downstream remap, nor proof that a display used it.
static func packet_sprite_low16(value: int) -> Dictionary:
	return V.rec("PacketSprite16", "M61", V.CONFIRMED, {"stored_i16": V.i16(value), "final_sprite": V.UNKNOWN, "displayed": V.UNKNOWN})

# ---- M62 -------------------------------------------------------------------------------
## EffectDelayManager is duplicate suppression keyed by SpriteID + packed source position. It is not
## a delayed player: an admitted request is not postponed. When keys expire is not in this package,
## so `forget()` is an explicit DESIGN operation.
static func delay_make() -> Dictionary:
	return {"record": "EffectDelayManager", "module": "M62", "design_status": V.DESIGN, "keys": {}}

static func delay_admit(manager: Dictionary, sprite_id: int, packed_source_pos: int) -> Dictionary:
	var out: Dictionary = manager.duplicate(true)
	var key: String = "%d@%d" % [sprite_id, packed_source_pos]
	if out.keys.has(key):
		return {"manager": out, "admitted": false, "suppressed": true, "delayed": false}
	out.keys[key] = true
	return {"manager": out, "admitted": true, "suppressed": false, "delayed": false}

static func delay_forget(manager: Dictionary, sprite_id: int, packed_source_pos: int) -> Dictionary:
	var out: Dictionary = manager.duplicate(true)
	out.keys.erase("%d@%d" % [sprite_id, packed_source_pos])
	out["forget_is_design"] = true
	return out

# ---- M63 -------------------------------------------------------------------------------
const ELEMENT_STRIDE := 0x28
const SPRITE_ID_OFFSET := 0x18

## Unsigned 64-bit remainder, then MOVSXD of its low 32 bits as the element index.
## index_bits: raw 64-bit pattern. A zero count is rejected: the original does not defend it.
static func special_attack_select(index_bits: int, count_u64: int) -> Dictionary:
	if count_u64 <= 0:
		return V.rec("SpecialAttackSelect", "M63", V.REJECTED, {"reason": "count 0 (or >= 2^63) not modelled"})
	var rem: int = V.u64_mod(index_bits, count_u64)
	var idx: int = V.i32(rem)
	return V.rec("SpecialAttackSelect", "M63", V.CONFIRMED, {"remainder_u64": rem, "address_index_i32": idx,
		"sprite_id_byte_offset": idx * ELEMENT_STRIDE + SPRITE_ID_OFFSET, "in_bounds_guaranteed": false})

# ---- M65 -------------------------------------------------------------------------------
## Tick removes the pending node whatever the materializer returns; LUID/OID fallback is cleared
## only on a normal non-null return. The materializer touches actor+F0 without a null check, so a
## null actor is rejected here instead of being "safely" modelled. outcome: "nonnull"|"null" is an
## external oracle, not an observed OOM-safe execution.
static func materialize_tick(pending: Array, node_id: Variant, actor_present: bool, outcome: String, fallback_ids: Dictionary) -> Dictionary:
	if not actor_present:
		return V.rec("MaterializeTick", "M65", V.REJECTED, {"reason": "materializer reads actor+F0 without a null guard", "pending": pending, "fallback_ids": fallback_ids})
	var p: Array = pending.duplicate()
	p.erase(node_id)
	var f: Dictionary = fallback_ids.duplicate()
	if outcome == "nonnull":
		f.clear()
	return V.rec("MaterializeTick", "M65", V.CONFIRMED, {"pending": p, "fallback_ids": f, "pending_removed": true,
		"fallback_cleared": outcome == "nonnull", "null_outcome_is_external_oracle": outcome == "null"})
