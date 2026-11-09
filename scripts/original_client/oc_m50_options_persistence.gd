extends RefCounted
## M50 v2 (C16, R50). DESIGN_NOT_RECOVERED_API. Option load/save as the original orders it.
## Fallback is taken ONLY when the primary is absent; empty/corrupt primary does not retry.
## A late field-conversion failure keeps the earlier in-place mutations (no rollback).
## Save is serialize -> open -> write -> flush -> close; a post-open stream error still ends on the
## normal path with true. That is NOT a durable/atomic save; a checked atomic save would be a new
## DESIGN, not original behaviour, and is not provided here.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

## primary/fallback: {"present": bool, "content": "ok"|"empty"|"corrupt"|"syntax_error", "fields": Array}
## each field: {"name": String, "value": Variant, "convertible": bool}
static func load_options(options: Dictionary, primary: Dictionary, fallback: Dictionary, migration_save_ok: bool) -> Dictionary:
	var out: Dictionary = options.duplicate(true)
	var trace: Array = []
	var source: Dictionary = primary
	var used: String = "primary"
	if not bool(primary.get("present", false)):
		trace.append("primary_absent_try_fallback")
		source = fallback
		used = "fallback"
		if not bool(fallback.get("present", false)):
			return V.rec("OptionLoad", "M50", V.NOT_DESCRIBED, {"options": out, "trace": trace, "fallback_attempted": true, "return_bool": null})
	var content: String = str(source.get("content", ""))
	if used == "primary" and (content == "empty" or content == "corrupt"):
		trace.append("primary_unusable_no_fallback_retry")
		return V.rec("OptionLoad", "M50", V.CONFIRMED, {"options": out, "trace": trace, "fallback_attempted": false, "return_bool": null})
	if content == "syntax_error":
		trace.append("syntax_parse_failed_no_field_applied")
		return V.rec("OptionLoad", "M50", V.CONFIRMED, {"options": out, "trace": trace, "fallback_attempted": used == "fallback", "conversion_failed": false, "return_bool": null})
	var conversion_failed: bool = false
	for field: Dictionary in source.get("fields", []):
		if not bool(field.get("convertible", true)):
			conversion_failed = true
			trace.append("field_conversion_failed:" + str(field.name))
			break
		out[field.name] = field.value
		trace.append("applied_in_place:" + str(field.name))
	var result := {"options": out, "trace": trace, "fallback_attempted": used == "fallback", "conversion_failed": conversion_failed, "rolled_back": false}
	if used == "fallback" and not conversion_failed:
		trace.append("migration_save:" + ("ok" if migration_save_ok else "false"))
		# Migration save failing does not turn the fallback load result into false.
		result["return_bool"] = true
	else:
		result["return_bool"] = null if conversion_failed else true
	return V.rec("OptionLoad", "M50", V.CONFIRMED, result)

static func save_options(open_ok: bool, post_open_stream_error: bool) -> Dictionary:
	var trace: Array = ["serialize", "open"]
	if not open_ok:
		return V.rec("OptionSave", "M50", V.CONFIRMED, {"trace": trace, "return_bool": false, "durable_guaranteed": false})
	trace.append_array(["write", "flush", "close"])
	return V.rec("OptionSave", "M50", V.CONFIRMED, {"trace": trace, "return_bool": true, "stream_error_seen": post_open_stream_error, "durable_guaranteed": false, "atomic_guaranteed": false})

## R50 / C04-T02: the embedded payload ADDRESS is row+8; it is not a pointer loaded from row+8.
static func payload_address(row_address: int) -> Dictionary:
	return V.rec("PayloadAddress", "M50", V.CONFIRMED, {"payload_address": row_address + 0x08, "dereference_row_plus_8": false})
