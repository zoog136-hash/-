extends RefCounted
## M48 (C03/C05/C07/C08). DESIGN_NOT_RECOVERED_API. current525 resource-corpus records. The
## counts describe the surveyed current525 corpus only; they are not an all-version source DB,
## not a native decode success and not a missing-file count. Prefix-only SP2 keeps its suffix
## bytes (hash) but is never filled with interpreted frames.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

const CURRENT525_COUNTS := {"dat": 753, "canonical_resources": 91465, "direct_spr": 30,
	"sp2": 74656, "sp2_complete": 72034, "sp2_prefix_only": 2621, "sp2_unsupported_non_fe": 1,
	"ti2": 8513, "ti2_eof_pass": 8512, "s32": 8296}
const KNOWN_EXCEPTIONS := {
	"Sprite/28708-15.sp2": {"kind": "SP2_UNSUPPORTED_NON_FE"},
	"Tile/5668.ti2": {"kind": "TI2_PIXEL_SHORT", "short_bytes": 19296, "crc_and_identity_match": true},
}
const SP2_PREFIX_BYTES := 5

## first_byte: the first byte of the decompressed SP2 payload (the parser expects 0xFE).
static func classify_sp2(path: String, first_byte: int, prefix_parsed: bool, fully_parsed: bool, payload_sha256: String) -> Dictionary:
	var base := {"path": path, "payload_sha256": payload_sha256, "bytes_preserved": true}
	if first_byte != 0xFE:
		base.merge({"class": "SP2_UNSUPPORTED_NON_FE", "frames": null, "interpreted": false})
		return V.rec("Sp2CorpusEntry", "M48", V.CONFIRMED, base)
	if fully_parsed:
		base.merge({"class": "SP2_COMPLETE", "interpreted": true})
		return V.rec("Sp2CorpusEntry", "M48", V.CONFIRMED, base)
	if prefix_parsed:
		base.merge({"class": "SP2_PREFIX_ONLY", "interpreted_prefix_bytes": SP2_PREFIX_BYTES, "suffix_meaning": V.UNKNOWN, "frames": null, "blocks": null, "interpreted": false})
		return V.rec("Sp2CorpusEntry", "M48", V.CONFIRMED, base)
	base.merge({"class": "SP2_NOT_CLASSIFIED", "frames": null, "interpreted": false})
	return V.rec("Sp2CorpusEntry", "M48", V.UNKNOWN, base)

static func known_exception(path: String) -> Dictionary:
	return KNOWN_EXCEPTIONS.get(path, {})

## Internal consistency of the recorded counts (no invented totals).
static func counts_consistent(counts: Dictionary) -> Dictionary:
	var sp2_sum: int = int(counts.sp2_complete) + int(counts.sp2_prefix_only) + int(counts.sp2_unsupported_non_fe)
	var ti2_exceptions: int = 0
	for path: String in KNOWN_EXCEPTIONS:
		if str(KNOWN_EXCEPTIONS[path].kind).begins_with("TI2_"):
			ti2_exceptions += 1
	var ti2_sum: int = int(counts.ti2_eof_pass) + ti2_exceptions
	return {"sp2_parts_match": sp2_sum == int(counts.sp2), "ti2_parts_match": ti2_sum == int(counts.ti2)}

## C08-T02: P12 virtual selections whose computed name is absent from the manifest are not a
## count of missing files.
static func p12_manifest_absent(virtual_pairs: int) -> Dictionary:
	return V.rec("P12AbsentPairs", "M48", V.CONFIRMED, {"virtual_name_pairs": virtual_pairs, "missing_file_count": null,
		"reason": "virtual selection/computed name pair, not an observed missing file"})
