extends RefCounted
## DESIGN_NOT_RECOVERED_API. Shared vocabulary for the M47-M81 design modules (reference
## package "client 01-123", baseline_01_81). Evidence levels use the package's own words.
## Nothing here is recovered original C++; every record is a new TWILIGHT type. The original
## binary is never executed, loaded or emulated by these modules.
const SPELL = preload("res://scripts/original_client/spell_ui_numeric.gd")

const DESIGN := "DESIGN_NOT_RECOVERED_API"
const CONFIRMED := "CONFIRMED_BOUNDED_STATIC"
const CONDITIONAL := "CONDITIONAL"
const UNKNOWN := "UNKNOWN"
## A value this design layer refuses because the original does not defend against it.
const REJECTED := "DESIGN_REJECTED_UNDEFENDED_INPUT"
## A branch the package does not describe. The design layer reports it instead of inventing it.
const NOT_DESCRIBED := "BRANCH_NOT_DESCRIBED_BY_PACKAGE"

static func rec(record: String, module: String, evidence: String, fields: Dictionary) -> Dictionary:
	var out := {"record": record, "module": module, "design_status": DESIGN, "evidence": evidence}
	out.merge(fields, true)
	return out

static func f32(value: float) -> float:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_float(0, value)
	return raw.decode_float(0)

static func f32_bits(value: float) -> int:
	return SPELL.f32_bits(value)

static func i32(value: int) -> int:
	var v: int = value & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v

static func u32(value: int) -> int:
	return value & 0xFFFFFFFF

static func i16(value: int) -> int:
	var v: int = value & 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v

## signed int64 -> binary32 in ONE rounding (CVTSI2SS qword). Going through binary64 first can
## give a different value; that two-step path is kept only as a contrast helper below.
static func i64_to_f32_direct(value: int) -> float:
	if value >= 0:
		return SPELL.u64_to_f32(value)
	# -INT64_MIN wraps to itself; as an unsigned pattern that is 2^63, which is exact in binary32.
	return -SPELL.u64_to_f32(-value)

## Contrast only: int64 -> binary64 -> binary32 (double rounding). Not the client's path.
static func i64_to_f32_via_f64(value: int) -> float:
	return f32(float(value))

static func _add_mod(a: int, b: int, m: int) -> int:
	# a, b in [0, m), m > 0; no signed overflow.
	return a - (m - b) if a >= m - b else a + b

## Unsigned 64-bit remainder of a raw 64-bit pattern by a positive divisor (< 2^63).
static func u64_mod(bits: int, divisor: int) -> int:
	if bits >= 0:
		return bits % divisor
	var low: int = (bits & 0x7FFFFFFFFFFFFFFF) % divisor
	var two62: int = (1 << 62) % divisor
	var two63: int = _add_mod(two62, two62, divisor)
	return _add_mod(low, two63, divisor)
