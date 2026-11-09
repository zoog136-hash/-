extends RefCounted
## DESIGN_NOT_RECOVERED_API. Shared vocabulary and fixed-width integer helpers for
## the original-client contract adapter (handoff package 01-46, phases P0-P2).
## Nothing here is recovered original C++; every record is a new TWILIGHT type.

const EVIDENCE_CONFIRMED := "CONFIRMED_STATIC_BOUNDED"
const EVIDENCE_INFERRED := "INFERRED"
const EVIDENCE_UNVERIFIED := "UNVERIFIED"
const EVIDENCE_DESIGN := "DESIGN_NOT_RECOVERED_API"

const PAYLOAD_UNVERIFIED := "UNVERIFIED"
const RENDER_NOT_OBSERVED := "NOT_OBSERVED"

## The four ReadResult states of contract C03 plus the "not looked at yet" state.
const READ_MISSING := "Missing"
const READ_FAILED := "ReadFailed"
const READ_EMPTY := "EmptySuccess"
const READ_DECODED := "Decoded"
const READ_DECODE_FAILED := "DecodeFailed"

static func u8(value: int) -> int:
	return value & 0xFF

static func i8(value: int) -> int:
	var v: int = value & 0xFF
	return v - 0x100 if v >= 0x80 else v

static func u16(value: int) -> int:
	return value & 0xFFFF

static func i16(value: int) -> int:
	var v: int = value & 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v

static func u32(value: int) -> int:
	return value & 0xFFFFFFFF

static func i32(value: int) -> int:
	var v: int = value & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v

## Byte-wise ASCII tolower, as the original lookup does. Non-ASCII bytes are kept.
static func lower_ascii(text: String) -> String:
	var raw: PackedByteArray = text.to_utf8_buffer()
	for i: int in raw.size():
		if raw[i] >= 65 and raw[i] <= 90:
			raw[i] += 32
	return raw.get_string_from_utf8()

static func is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var f: float = value
		return is_finite(f) and f == floorf(f)
	return false
