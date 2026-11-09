extends RefCounted
## M112 (C04, C09; F112) Awakening key and M113 (C10; F113) LandAttribute water selection.
## DESIGN_NOT_RECOVERED_API.
## M112: the registered key leaf 01466320 writes PHYSICAL [grade(message+18), deck(message+14)];
##       the M104 reader compares SEMANTICALLY signed(deck) then signed(grade). Byte layout and
##       ordering are implemented separately; no uint64 compare, no JSON insertion order.
## M113: 0204B150 - first row with row+1C == current LandID (32-bit equality) AND row+20 == 11
##       selects Water enum2. Value is never read. A missing TABLE is not an empty table.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const WATER_ENUM := 2
const LAND_ATTRIBUTE_UNDERWATER := 11  # native spelling LandAttributeType_Underwarter
const M112_EVIDENCE := {"key_layout": C.EVIDENCE_CONFIRMED, "registry_current": C.EVIDENCE_CONDITIONAL}
const M113_EVIDENCE := {"selection": C.EVIDENCE_CONFIRMED, "producer_00872446": C.EVIDENCE_UNKNOWN, "pixels": C.EVIDENCE_UNKNOWN}

## ---------------- M112 ----------------

## 01466320: both loads happen before any store; out+0 = grade bits, out+4 = deck bits.
static func physical_key(message: Dictionary) -> PackedByteArray:
	var grade_bits: int = C.u32(int(message.grade))
	var deck_bits: int = C.u32(int(message.deck))
	var out := PackedByteArray()
	out.resize(8)
	out.encode_u32(0, grade_bits)
	out.encode_u32(4, deck_bits)
	return out

## 0139B940: the table's key callable (+78) must exist; missing -> 035FFE3D boundary, no key output.
static func table_key(table: Dictionary, message: Dictionary) -> Dictionary:
	if table.get("key_callable") == null:
		return {"key": null, "outcome": C.UNGUARDED_BOUNDARY}
	return {"key": physical_key(message)}

static func semantic_of(key_bytes: PackedByteArray) -> Array:
	return [key_bytes.decode_s32(4), key_bytes.decode_s32(0)]  # (deck, grade), signed

## Reader: rows are {"key": PackedByteArray(8), "effect_id": int} in native sorted order.
static func lookup_effect(rows: Array, deck: int, grade: int) -> Variant:
	var idx: int = C.lower_bound_exact(rows, func(r: Dictionary) -> Array: return semantic_of(r.key), [C.i32(deck), C.i32(grade)])
	return null if idx < 0 else rows[idx].effect_id

## Sort helper that follows the reader's semantic order (signed deck, then signed grade).
static func sort_semantic(rows: Array) -> Array:
	var out: Array = rows.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return C.lex_less(semantic_of(a.key), semantic_of(b.key)))
	return out

## Counter-model only: what a little-endian uint64 compare of the same 8 bytes would order by.
static func u64_view(key_bytes: PackedByteArray) -> int:
	return key_bytes.decode_u64(0)

## ---------------- M113 ----------------

## weather: {"blocks": {enum: {"active": bool, "stopping": bool}}, "trace": []}. A missing block is
## distinct from an inactive one. hooks.after_query: Callable(weather) runs at the query's shared
## cleanup (callbacks may re-enter), so the wrapper's second lookup can see a different state.
static func query_active(weather: Dictionary, which: int, hooks: Dictionary) -> bool:
	var block: Variant = (weather.blocks as Dictionary).get(which)
	var result: bool = block != null and bool(block.active)
	if hooks.has("after_query"):
		(hooks.after_query as Callable).call(weather)
	return result

static func start_wrapper(weather: Dictionary, which: int) -> void:
	(weather.trace as Array).append("start-requested")
	var block: Variant = (weather.blocks as Dictionary).get(which)  # independent lookup
	if block == null:
		(weather.trace as Array).append("start-body-skipped-missing-block")
		return
	if bool(block.active):
		(weather.trace as Array).append("start-body-already-active")
		return
	block["active"] = true
	(weather.trace as Array).append("start-body")

static func stop_wrapper(weather: Dictionary, which: int) -> void:
	(weather.trace as Array).append("stop-requested")
	var block: Variant = (weather.blocks as Dictionary).get(which)
	if block == null:
		(weather.trace as Array).append("stop-body-skipped-missing-block")
		return
	if not bool(block.active) or bool(block.get("stopping", false)):
		(weather.trace as Array).append("stop-body-inactive-or-stopping")
		return
	block["stopping"] = true
	(weather.trace as Array).append("stop-body")

## table: null (registry miss) or {"rows": [{"LandID", "LandAttributeTypeID", "Value", ...}]}.
static func select_water(table: Variant, land_bits: int, weather: Dictionary, hooks: Dictionary = {}) -> Dictionary:
	if table == null:
		# The original dereferences table+8/+10 with RCX=0. No if(!table) return exists.
		return {"matched": null, "outcome": C.UNGUARDED_BOUNDARY}
	var matched: Variant = null
	for row: Dictionary in table.rows:
		if C.u32(int(row.LandID)) == C.u32(land_bits) and C.u32(int(row.LandAttributeTypeID)) == LAND_ATTRIBUTE_UNDERWATER:
			matched = row
			break
	var active: bool = query_active(weather, WATER_ENUM, hooks)
	if matched != null:
		if active:
			return {"matched": matched, "request": "none_already_active"}
		start_wrapper(weather, WATER_ENUM)
		return {"matched": matched, "request": "start"}
	if not active:
		return {"matched": null, "request": "none_inactive"}
	stop_wrapper(weather, WATER_ENUM)
	return {"matched": null, "request": "stop"}

## Inherited M42 boundary (CONDITIONAL): packet190 never produces enum2 and stopAll excludes it.
static func m42_stop_all_touches(which: int) -> bool:
	return which != WATER_ENUM
