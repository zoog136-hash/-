extends RefCounted
## C06 and the selection part of C08 / P2. DESIGN_NOT_RECOVERED_API.
## SPR ordinal, tuple dot-before/dot-after, file group and direction are different
## numbers. Nothing here decodes an SP2 payload; payload facts arrive from the
## caller, and without them the selection stays UNVERIFIED.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const FALLBACK_WORD0 := 0xFFFF

## Client action key = low32(int16(sprite) * 173 + action).
static func action_key(sprite_id: int, action: int) -> int:
	return VOCAB.u32(VOCAB.i16(sprite_id) * 173 + action)

## Whole remap is applied once to a file request. It is not followed recursively.
static func apply_whole_remap(request_id: int, remap: Dictionary) -> Dictionary:
	if remap.has(request_id):
		return {"request_id": request_id, "mapped_id": int(remap[request_id]), "remap_applied": true, "recursion": "NOT_FOLLOWED"}
	return {"request_id": request_id, "mapped_id": request_id, "remap_applied": false, "recursion": "NOT_FOLLOWED"}

## low16 = u16(word0 + (directional ? direction : 0)); file_b = low16 & 0xFFF8;
## asset direction = low16 & 7.
static func sp2_group(word0: int, directional: bool, direction: int) -> Dictionary:
	var low16: int = VOCAB.u16(word0 + (direction if directional else 0))
	return {"low16": low16, "file_b": low16 & 0xFFF8, "direction": low16 & 7}

static func primary_name(mapped_id: int, file_b: int) -> String:
	return "Sprite/%d-%d.sp2" % [mapped_id, file_b]

## Simple helper 01C78EE0: direction outside 0..7 clamps to 0. The actor path
## 01C8F2D0 has no such clamp; DESIGN only flags the domain, it does not clamp.
static func simple_path_direction(direction: int) -> int:
	return direction if (direction >= 0 and direction <= 7) else 0

static func actor_path_direction_domain(direction: int) -> String:
	return "NORMAL_0_7" if (direction >= 0 and direction <= 7) else "OUTSIDE_NORMAL_DOMAIN_NO_ORIGINAL_CLAMP"

## C06-T03: an explicit alias A=S copies S's action only if S's descriptor exists at
## that moment, and never replaces an existing first definition.
static func alias_descriptor(table: Dictionary, dest_sprite: int, source_sprite: int, action: int) -> Dictionary:
	var source_key: int = action_key(source_sprite, action)
	var dest_key: int = action_key(dest_sprite, action)
	if not table.has(source_key):
		return {"created": false, "diagnostic": "SOURCE_ALIAS_NOT_YET_DEFINED", "dest_key": dest_key, "source_key": source_key}
	if table.has(dest_key):
		return {"created": false, "diagnostic": "FIRST_DEFINITION_KEPT", "dest_key": dest_key, "source_key": source_key}
	var copy: Dictionary = (table[source_key] as Dictionary).duplicate(true)
	copy["origin"] = "explicit_alias"
	table[dest_key] = copy
	return {"created": true, "diagnostic": "", "dest_key": dest_key, "source_key": source_key}

## C08: dot-after WORD -> low8 -> signed8 -> unsigned range check against the SP2
## frame vector. Out of range picks the last frame; an empty vector picks the
## default frame. Meaningful only for a non-empty, valid vector.
static func picture_selection(dot_after_word: int, frame_count: int) -> Dictionary:
	var picture_u8: int = VOCAB.u8(dot_after_word)
	var picture_i8: int = VOCAB.i8(dot_after_word)
	if frame_count <= 0:
		return {"picture_u8": picture_u8, "picture_i8": picture_i8, "chosen_frame": null, "status": "EMPTY_FRAMES_DEFAULT_FRAME"}
	var as_unsigned: int = VOCAB.u32(picture_i8)
	if as_unsigned >= frame_count:
		return {"picture_u8": picture_u8, "picture_i8": picture_i8, "chosen_frame": frame_count - 1, "status": "CLAMPED_TO_LAST"}
	return {"picture_u8": picture_u8, "picture_i8": picture_i8, "chosen_frame": as_unsigned, "status": "OK"}

## C08-T02: an SPR ordinal at or past the count is null (InvalidOrdinal). It is NOT
## clamped to the last SPR frame.
static func spr_ordinal_lookup(count: int, ordinal: int) -> Dictionary:
	if ordinal < 0 or ordinal >= count:
		return {"status": "InvalidOrdinal", "ordinal": null}
	return {"status": "OK", "ordinal": ordinal}

## C08-T04: a direction number is not the packed vector index. A missing direction
## is null with no automatic fallback to direction 0.
static func packed_direction_index(direction_mask: int, direction: int) -> Dictionary:
	if direction < 0 or direction > 7 or (direction_mask & (1 << direction)) == 0:
		return {"status": "MissingDirection", "direction": direction, "packed_index": null}
	var below: int = direction_mask & ((1 << direction) - 1)
	var index: int = 0
	while below != 0:
		index += below & 1
		below >>= 1
	return {"status": "OK", "direction": direction, "packed_index": index}

static func make_selection(fields: Dictionary) -> Dictionary:
	var out := {
		"record": "SpriteSelection",
		"design_status": VOCAB.EVIDENCE_DESIGN,
		"actor_sprite_i16": null, "action_i32": null, "ordinal_i8": null, "input_direction": null,
		"body_request_u16": null, "mapped_file_u16": null, "file_b_u16": null, "asset_direction": null,
		"picture_i8": null, "source_frame_id": null, "status": "UNRESOLVED",
	}
	out.merge(fields, true)
	return out

## Resolves one actor body selection and returns provenance with it.
## input: {actor_sprite, action, ordinal, direction, word0, directional, body_request,
##         remap (Dictionary), dot_after_word (optional), frame_count (optional)}
static func resolve_selection(input: Dictionary) -> Dictionary:
	var sprite: int = VOCAB.i16(int(input.get("actor_sprite", 0)))
	var action: int = int(input.get("action", 0))
	var direction: int = int(input.get("direction", 0))
	var word0: int = int(input.get("word0", 0))
	var provenance: Array = ["action_key=%d" % action_key(sprite, action)]
	var base := {"actor_sprite_i16": sprite, "action_i32": action, "ordinal_i8": VOCAB.i8(int(input.get("ordinal", 0))),
		"input_direction": direction, "body_request_u16": VOCAB.u16(int(input.get("body_request", 0)))}
	if VOCAB.u16(word0) == FALLBACK_WORD0:
		# Fallback helper path: never resolved as a plain file number 65535.
		provenance.append("word0_FFFF_actor_fallback_helper_path")
		base["status"] = "FALLBACK_HELPER_PATH"
		base["payload_status"] = VOCAB.PAYLOAD_UNVERIFIED
		base["provenance"] = provenance
		return make_selection(base)
	var remap: Dictionary = apply_whole_remap(VOCAB.u16(int(input.get("body_request", 0))), input.get("remap", {}))
	provenance.append("whole_remap_once:%d->%d" % [remap.request_id, remap.mapped_id])
	var group: Dictionary = sp2_group(word0, bool(input.get("directional", false)), direction)
	provenance.append("low16=%d file_b=%d asset_direction=%d" % [group.low16, group.file_b, group.direction])
	provenance.append("actor_direction_domain=" + actor_path_direction_domain(direction))
	base["mapped_file_u16"] = remap.mapped_id
	base["file_b_u16"] = group.file_b
	base["asset_direction"] = group.direction
	base["primary_name"] = primary_name(remap.mapped_id, group.file_b)
	base["fallback_name"] = null
	base["fallback_status"] = "2500_RANGE_FOLDER_RULE_NOT_IN_HANDOFF_JSON"
	if input.has("dot_after_word") and input.has("frame_count"):
		var picture: Dictionary = picture_selection(int(input.dot_after_word), int(input.frame_count))
		base["picture_i8"] = picture.picture_i8
		base["source_frame_id"] = picture.chosen_frame
		base["frame_count"] = int(input.frame_count)
		base["payload_status"] = "CALLER_SUPPLIED_FRAME_COUNT"
		provenance.append("picture:" + str(picture.status))
	else:
		base["frame_count"] = null
		base["payload_status"] = VOCAB.PAYLOAD_UNVERIFIED
	base["render_status"] = VOCAB.RENDER_NOT_OBSERVED
	base["status"] = "FILE_SELECTED"
	base["provenance"] = provenance
	return make_selection(base)
