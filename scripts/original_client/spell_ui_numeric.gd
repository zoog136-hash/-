extends RefCounted
## C21 / P5. DESIGN_NOT_RECOVERED_API. Spell timers, remaining-time arithmetic and the
## progress-action decision, with binary32/binary64 steps kept explicit. A uint64 is held
## in a signed GDScript int as its raw 64-bit pattern.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")

static func f32_bits(value: float) -> int:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_float(0, value)
	return raw.decode_u32(0)

static func f32_from_bits(bits: int) -> float:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_u32(0, bits)
	return raw.decode_float(0)

static func hex8(bits: int) -> String:
	return "%08X" % bits

## uint64 -> binary32 DIRECTLY, round to nearest even. Going through binary64 first gives a
## different value for some inputs and is not what the client does.
static func u64_to_f32(value: int) -> float:
	if value >= 0 and value < (1 << 24):
		return float(value)
	# Bit length of the unsigned pattern (64 when bit 63 is set).
	var length: int = 64
	if value >= 0:
		length = 0
		var probe: int = value
		while probe != 0:
			probe >>= 1
			length += 1
	var shift: int = length - 24
	var mantissa: int
	var remainder: int
	if value < 0:
		var low63: int = value & 0x7FFFFFFFFFFFFFFF
		mantissa = (1 << 23) | (low63 >> shift)
		remainder = low63 & ((1 << shift) - 1)
	else:
		mantissa = value >> shift
		remainder = value & ((1 << shift) - 1)
	var half: int = 1 << (shift - 1)
	if remainder > half or (remainder == half and (mantissa & 1) == 1):
		mantissa += 1
	return float(mantissa) * pow(2.0, float(shift))

## uint64 -> binary64 with a single rounding.
static func u64_to_f64(value: int) -> float:
	var high: int = (value >> 32) & 0xFFFFFFFF
	var low: int = value & 0xFFFFFFFF
	return float(high) * 4294967296.0 + float(low)

## duration: uint64 -> binary32 directly, then / 1000 in binary32.
static func duration_seconds_bits(remaining_u64: int) -> Dictionary:
	var as_f32: float = u64_to_f32(remaining_u64)
	var seconds: float = f32_from_bits(f32_bits(as_f32 / 1000.0))
	return {"u24_bits": hex8(f32_bits(as_f32)), "duration_bits": hex8(f32_bits(seconds))}

## percent: each uint64 -> binary64, DIVSD, MULSD 100, then binary32. Multiply-first differs.
static func cooldown_percent_bits(remaining_u64: int, total_u64: int) -> Dictionary:
	var quotient: float = u64_to_f64(remaining_u64) / u64_to_f64(total_u64)
	return {"percent_f32_bits": hex8(f32_bits(quotient * 100.0))}

static func cooldown_percent_bits_multiply_first(remaining_u64: int, total_u64: int) -> String:
	return hex8(f32_bits(u64_to_f64(remaining_u64) * 100.0 / u64_to_f64(total_u64)))

## remaining is stored as a qword, but the update compares signed low32(old) - low32(delta) to 0.
static func remaining_after(old_qword: int, delta_qword: int) -> Dictionary:
	var diff: int = VOCAB.i32((old_qword & 0xFFFFFFFF) - (delta_qword & 0xFFFFFFFF))
	return {"signed_low32": diff, "expired": diff <= 0}

## Active map: unique insert. A duplicate neither overwrites the timeout nor the icon.
static func active_insert(active: Dictionary, spell_id: int, timeout: int, icon: int) -> Dictionary:
	if active.has(spell_id):
		return {"active": active, "inserted": false}
	var out: Dictionary = active.duplicate(true)
	out[spell_id] = {"timeout": timeout, "icon": icon}
	return {"active": out, "inserted": true}

## Timeout: the whole map is visited and events published first, then the erase pass runs.
## An explicit removal erases first and then publishes the event.
static func timeout_pass(active: Dictionary, expired_ids: Array) -> Dictionary:
	var events: Array = []
	for id: Variant in active:
		if id in expired_ids:
			events.append({"event": "timeout", "spell": id})
	var kept: Dictionary = {}
	for id: Variant in active:
		if not (id in expired_ids):
			kept[id] = active[id]
	return {"events_published_before_erase": events, "active": kept}

static func explicit_remove(active: Dictionary, spell_id: int) -> Dictionary:
	var kept: Dictionary = active.duplicate(true)
	kept.erase(spell_id)
	return {"order": ["erase", "event"], "event": {"event": "removed", "spell": spell_id}, "active": kept}

## Progress action replacement on tag 100.
## existing_type: "ProgressFromTo" | "OtherAction" | "None".
static func progress_transition(existing_type: String, existing_remaining: int, new_duration: int, maintain_ok: bool, create_succeeds: bool, node_present: bool, timer_present: bool, node_hidden: bool) -> Dictionary:
	var stop: bool = false
	if existing_type == "ProgressFromTo":
		if existing_remaining >= new_duration:
			return {"stop_by_tag_called": false, "new_action_created": false, "show": false, "returned_early": true}
		stop = true
	elif existing_type == "OtherAction":
		stop = false # the dynamic cast fails: create without stopping
	if not maintain_ok and existing_type == "ProgressFromTo":
		stop = true
	if not create_succeeds:
		return {"stop_by_tag_called": stop, "new_action_created": false, "show": false, "returned_early": false}
	var show: bool = node_present and timer_present
	return {"stop_by_tag_called": stop, "new_action_created": true, "show": show and not node_hidden, "returned_early": false}
