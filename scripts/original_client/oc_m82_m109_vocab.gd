extends RefCounted
## DESIGN_NOT_RECOVERED_API. Shared labels and fixed-width helpers for the M82-M109 DESIGN
## modules (reference package 01-123, extensions 82-109). Nothing here is recovered original
## C++ or a recovered signature. Every record built by these modules is a new TWILIGHT type.
const DESIGN := "DESIGN_NOT_RECOVERED_API"
## Evidence levels exactly as the package spells them.
const CONFIRMED := "CONFIRMED_BOUNDED_STATIC"
const CONDITIONAL := "CONDITIONAL"
const UNKNOWN := "UNKNOWN"
## Results that are requests, never observed GPU/driver/pixel outcomes.
const NOT_OBSERVED := "NOT_OBSERVED"
## A design-layer refusal: the original has no defence for this input. It is flagged here; it
## is never turned into a "safe" original behaviour.
const REJECTED_UNDEFENDED := "REJECTED_INPUT_NOT_DEFENDED_BY_ORIGINAL_DESIGN"

static func u32(v: int) -> int:
	return v & 0xFFFFFFFF

static func i32(v: int) -> int:
	var x: int = v & 0xFFFFFFFF
	return x - 0x100000000 if x >= 0x80000000 else x

static func i8(v: int) -> int:
	var x: int = v & 0xFF
	return x - 0x100 if x >= 0x80 else x

static func i16(v: int) -> int:
	var x: int = v & 0xFFFF
	return x - 0x10000 if x >= 0x8000 else x

## Arithmetic shift right of a signed 32-bit value.
static func sar32(v: int, n: int) -> int:
	return i32(v) >> n

## Round a value to IEEE binary32 (round to nearest even). One f64 operation on binary32
## operands followed by this rounding equals the binary32 operation (+,-,*,/), so chaining it
## per operation reproduces binary32 arithmetic for finite values.
static func f32(x: float) -> float:
	var a := PackedFloat32Array([x])
	return a[0]

static func f32_bits(x: float) -> int:
	var b := PackedFloat32Array([x]).to_byte_array()
	return b.decode_u32(0)

## CVTTSS2SI: truncation toward zero.
static func trunc_to_int(x: float) -> int:
	return int(x)

## 64-bit wrapping multiply (done in 32-bit halves so the result never depends on signed
## overflow behaviour of the host).
static func mul_u64(a: int, b: int) -> int:
	var al: Array[int] = [a & 0xFFFF, (a >> 16) & 0xFFFF, (a >> 32) & 0xFFFF, (a >> 48) & 0xFFFF]
	var bl: Array[int] = [b & 0xFFFF, (b >> 16) & 0xFFFF, (b >> 32) & 0xFFFF, (b >> 48) & 0xFFFF]
	var acc: Array[int] = [0, 0, 0, 0]
	for i: int in 4:
		for j: int in 4 - i:
			acc[i + j] += al[i] * bl[j]
	var out: int = 0
	var carry: int = 0
	for k: int in 4:
		var v: int = acc[k] + carry
		out |= (v & 0xFFFF) << (16 * k)
		carry = v >> 16
	return out

static func hex_to_bytes(h: String) -> PackedByteArray:
	return h.hex_decode()

static func sha256_bytes(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode()

static func sha256_text(t: String) -> String:
	return sha256_bytes(t.to_utf8_buffer())
