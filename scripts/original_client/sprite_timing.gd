extends RefCounted
## C07 / P2. DESIGN_NOT_RECOVERED_API. Stored SPR delay and per-frame effective
## delay with explicit width/sign. Inputs outside the confirmed normal domain are
## rejected or flagged by this DESIGN layer; the original does not defend them.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const DEFAULT_FPS := 24
const NORMAL_RATE := 1000000
const AUTO_ACTION_SOURCE_FIRST := 4

## stored delay = low16(u32(raw * 1000) / u32(FPS)). FPS 0 is rejected here (DESIGN).
static func stored_delay(raw: int, fps: int) -> Dictionary:
	var divisor: int = VOCAB.u32(fps)
	if divisor == 0:
		return {"status": "FPS_ZERO_REJECTED", "delay_u16_ms": null}
	@warning_ignore("integer_division")
	var quotient: int = VOCAB.u32(raw * 1000) / divisor
	return {"status": "OK", "delay_u16_ms": VOCAB.u16(quotient)}

## entries: [{"raw":int} | {"code110_fps":int}]. A code-110 FPS change affects only
## the frames after it; already stored delays are never rewritten.
static func store_delays(entries: Array, default_fps: int = DEFAULT_FPS) -> Array:
	var fps: int = default_fps
	var delays: Array = []
	for entry: Variant in entries:
		if entry is Dictionary and entry.has("code110_fps"):
			fps = int(entry["code110_fps"])
		elif entry is Dictionary and entry.has("raw"):
			delays.append(stored_delay(int(entry["raw"]), fps))
	return delays

## per-frame delay = signed IDIV(low32(delay * 1000000), runtime_rate), then the
## actor+178 bucket shift. Only buckets 0 and 1 (no shift) are confirmed normal.
static func effective_delay(stored_delay_ms: int, rate: int, bucket: int) -> Dictionary:
	var rate_i32: int = VOCAB.i32(rate)
	if rate_i32 == 0:
		return {"status": "RATE_ZERO_REJECTED", "delay_ms": null}
	if bucket < 0 or bucket >= 2:
		return {"status": "BUCKET_SHIFT_UNVERIFIED", "delay_ms": null}
	var scaled: int = VOCAB.i32(VOCAB.u16(stored_delay_ms) * 1000000)
	if scaled == -2147483648 and rate_i32 == -1:
		return {"status": "IDIV_OVERFLOW_REJECTED", "delay_ms": null}
	var normal_domain: bool = VOCAB.u16(stored_delay_ms) * 1000000 <= 0x7FFFFFFF and rate_i32 > 0
	@warning_ignore("integer_division")
	var delay: int = scaled / rate_i32
	return {"status": "OK" if normal_domain else "OUTSIDE_NORMAL_DOMAIN_COMPAT_VALUE", "delay_ms": delay}

## C07-T03: automatic descriptors for actions 46..49 and 50..53 take 4..7 as source
## and exist only when the destination is absent. Descriptor +8 of an automatic
## descriptor is a sprite id and is never read back as FPS.
static func auto_source_action(dest_action: int) -> int:
	if dest_action >= 46 and dest_action <= 53:
		return AUTO_ACTION_SOURCE_FIRST + ((dest_action - 46) % 4)
	return -1

static func descriptor_plus8_meaning(descriptor: Dictionary) -> Dictionary:
	if str(descriptor.get("origin", "")).begins_with("auto"):
		return {"meaning": "SPRITE_ID", "fps_derivable": false}
	return {"meaning": "STORED_DELAY_OR_FPS_PER_DESCRIPTOR_KIND", "fps_derivable": true}

## C07-T04: one callback advances the ordinal by 1. At the end the ordinal is
## normally 0; action 96 picks max(count-1, 0). The callback then returns false.
## This is not an unconditional loop and not an SP2 last-frame clamp.
static func advance_ordinal(ordinal: int, count: int, action: int) -> Dictionary:
	var next: int = ordinal + 1
	if next < count:
		return {"ordinal": next, "continues": true, "at_end": false}
	var end_ordinal: int = maxi(count - 1, 0) if action == 96 else 0
	return {"ordinal": end_ordinal, "continues": false, "at_end": true}
