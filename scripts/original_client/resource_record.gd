extends RefCounted
## C04 / P1. DESIGN_NOT_RECOVERED_API. Current JSON rows, protobuf field kinds and
## native layout evidence are kept as separate things. A safe-language struct is a
## DESIGN choice and never copies native offsets into field order.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")

static func make_record(qualified_type: String, key: Variant, fields: Dictionary, source_json_hash: String) -> Dictionary:
	return {"record": "ResourceRecord", "design_status": VOCAB.EVIDENCE_DESIGN, "qualified_type": qualified_type,
		"key": key, "fields": fields, "source_json_hash": source_json_hash}

## offsets are hex in the source notation; here they are plain ints (0x48 == 72).
static func make_layout_evidence(payload_offsets: Dictionary, row_stride: int, payload_bias: int, lookup_return_basis: String, status: String) -> Dictionary:
	return {"record": "NativeLayoutEvidence", "design_status": VOCAB.EVIDENCE_DESIGN, "payload_offsets": payload_offsets,
		"row_stride": row_stride, "payload_bias": payload_bias, "lookup_return_basis": lookup_return_basis, "status": status}

## Layout evidence stated by the approved contract (C04). Offsets are payload-relative.
static func approved_layouts() -> Dictionary:
	var ev: String = VOCAB.EVIDENCE_CONFIRMED
	return {
		"lineage.resource.Land": make_layout_evidence({"ID": 0x20, "AssetPath": 0x18}, 0x48, 0x8, "entry_plus_bias_returns_payload", ev),
		"lineage.resource.DescData": make_layout_evidence({"Description": 0x10}, 0x28, 0x8, "entry_plus_bias_returns_payload", ev),
		"lineage.resource.SpellClass": make_layout_evidence({"DescID": 0x1C, "EffectDescID": 0x90}, 0x100, 0x8, "entry_plus_bias_returns_payload", ev),
	}

## C04-T01: the network lineage.Land and the resource lineage.resource.Land share a
## short name only. They must never be joined by id/channel/AssetPath.
static func join_guard(left_qualified: String, right_qualified: String) -> Dictionary:
	if left_qualified == right_qualified:
		return {"allowed": true, "reason": "same qualified name"}
	return {"allowed": false, "reason": "QUALIFIED_NAME_MISMATCH", "left": left_qualified, "right": right_qualified}

## C04-T02: converting a payload-relative offset to an entry-relative one needs the
## pointer basis the caller really holds. Unknown basis is never auto-filled.
static func entry_relative_offset(payload_offset: int, payload_bias: int, pointer_basis: String) -> Dictionary:
	if pointer_basis == "payload":
		return {"status": "OK", "entry_offset": payload_offset + payload_bias, "basis": pointer_basis}
	if pointer_basis == "entry":
		return {"status": "OK", "entry_offset": payload_offset, "basis": pointer_basis}
	return {"status": "UNRESOLVED_POINTER_BASIS", "entry_offset": null, "basis": pointer_basis}

## C04-T03: protobuf descriptor Type enum (e.g. 14 = ENUM) is NOT a wire type.
## Standard protobuf mapping (public protobuf specification, not from the handoff ZIP).
const WIRE_TYPE_BY_DESCRIPTOR_TYPE := {
	1: 1, 2: 5, 3: 0, 4: 0, 5: 0, 6: 1, 7: 5, 8: 0, 9: 2, 11: 2, 12: 2,
	13: 0, 14: 0, 15: 5, 16: 1, 17: 0, 18: 0,
}

static func wire_type_for_descriptor(descriptor_type_enum: int) -> Dictionary:
	if WIRE_TYPE_BY_DESCRIPTOR_TYPE.has(descriptor_type_enum):
		return {"status": "OK", "descriptor_type_enum": descriptor_type_enum, "wire_type": WIRE_TYPE_BY_DESCRIPTOR_TYPE[descriptor_type_enum]}
	return {"status": "UNSUPPORTED_DESCRIPTOR_TYPE", "descriptor_type_enum": descriptor_type_enum, "wire_type": null}

static func is_valid_wire_type(wire_type: int) -> bool:
	return wire_type >= 0 and wire_type <= 5
