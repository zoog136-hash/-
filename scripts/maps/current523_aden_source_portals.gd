extends RefCounted
## Private native M declarations plus exact individual S32 endpoint evidence.
## Movement decisions use the application's explicit source-field policy.
const CONTRACT_SHA256 = "350176c5a55d349ec1b4e0b861b29b48499c9b5c32471c89b3ef86d03ea19767"
const INVENTORY_SHA256 = "e236f89849bcc6fc618feb13046c077adff59f909ad376b408c9b24fafc3288c"
const NATIVE_INPUT_SHA256 = {
	"Land": "8778d18d8c23a0ccb0a555f495e056987796232c616dec805dfb4c4d633b0ef9",
	"Portal": "af434065337cfd2b8c3fab9887ce5d3569ce6651d122a05288769d487df78a45",
	"Territories": "2ef6e702e46204f8fd233ede612890ec20eadbbd16189bc02b04df3a58f4cc3b",
}
const MAX_CONTRACT_BYTES = 1024 * 1024
var loaded: bool = false
var problem: String = ""
var _portals: Dictionary = {}

func _fail(message: String) -> bool:
	problem = message
	return false

static func _hash(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()

static func _uint(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0.0 and float(value) <= float(maximum)

static func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _uint(value[0], 65535) and _uint(value[1], 65535)

func load_contract(path: String) -> bool:
	loaded = false
	problem = ""
	_portals.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail("Missing private Aden source portal contract")
	if file.get_length() <= 0 or file.get_length() > MAX_CONTRACT_BYTES: return _fail("Invalid Aden portal contract size")
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if _hash(bytes) != CONTRACT_SHA256: return _fail("Aden portal contract SHA256 mismatch")
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary: return _fail("Invalid Aden portal contract")
	if value.get("schema") != 1 or value.get("edition") != "LineageM" or value.get("cumulative_version") != 523 or value.get("land_id") != 4 or value.get("asset_path") != "Aden/" or value.get("source_inventory_sha256") != INVENTORY_SHA256 or value.get("delivery_status") != "PRIVATE_LOCAL_ONLY":
		return _fail("Aden portal source identity mismatch")
	var inputs: Variant = value.get("native_inputs")
	if not inputs is Dictionary: return _fail("Missing native portal input identities")
	for table: String in NATIVE_INPUT_SHA256:
		if not inputs.get(table) is Dictionary or inputs[table].get("sha256") != NATIVE_INPUT_SHA256[table]:
			return _fail("Native portal input identity mismatch: " + table)
	var entries: Variant = value.get("portals")
	if not entries is Array or entries.size() != 93: return _fail("Expected all 93 native Land4 portal declarations")
	var candidate: Dictionary = {}
	for entry: Variant in entries:
		if not entry is Dictionary or not _uint(entry.get("id"), 2147483647) or not _point(entry.get("source_position")):
			return _fail("Invalid native portal endpoint")
		var id: int = int(entry.id)
		if candidate.has(id) or not entry.get("portal") is Dictionary or entry.portal.get("ID") != id or entry.portal.get("SourceLandID") != 4:
			return _fail("Invalid or duplicate native portal ID")
		if entry.portal.get("SourceX") != entry.source_position[0] or entry.portal.get("SourceY") != entry.source_position[1]:
			return _fail("Native source portal coordinate mismatch")
		if entry.get("activation_eligible") != false: return _fail("Portal contract must retain runtime endpoint checks")
		if entry.get("activation_candidate") == true:
			if not _point(entry.get("landing_position")) or entry.get("raw_endpoint_match") != true or not entry.get("matched_raw_record_ids") is Array or entry.matched_raw_record_ids.size() != 1:
				return _fail("Missing raw portal endpoint match")
			if not entry.get("target_land") is Dictionary or entry.target_land.get("ID") != 4 or entry.target_land.get("AssetPath") != "Aden/":
				return _fail("Portal target source Land unavailable")
			for endpoint: String in ["source_support", "target_support"]:
				if not entry.get(endpoint) is Dictionary or entry[endpoint].get("s32_member_verified") != true:
					return _fail("Missing verified portal endpoint source")
		candidate[id] = entry.duplicate(true)
	_portals = candidate
	loaded = true
	return true

func portal(id: int) -> Dictionary:
	return _portals[id].duplicate(true) if loaded and _portals.has(id) else {}

func portal_context(id: int) -> Dictionary:
	return portal(id)

func portal_evidence() -> Array:
	var result: Array = []
	if not loaded: return result
	var ids: Array = _portals.keys()
	ids.sort()
	for id: int in ids:
		result.append(_portals[id].duplicate(true))
	return result

func portals_at(source_cell: Vector2i) -> Array:
	var result: Array = []
	if not loaded: return result
	for id: int in _portals:
		var entry: Dictionary = _portals[id]
		if source_cell == Vector2i(int(entry.source_position[0]), int(entry.source_position[1])):
			result.append(entry.duplicate(true))
	return result

static func _endpoint_clear(info: Dictionary, position: Vector2i, support: Dictionary) -> bool:
	if info.get("status") != "allowed" or info.get("walkable") != true or info.get("member") != support.member or info.get("source_sha256") != support.sha256 or info.get("source_cell") != position:
		return false
	var attributes: Variant = info.get("raw_pair")
	var floor_refs: Variant = info.get("floor_pair")
	if not attributes is Array or attributes.size() != 2 or not floor_refs is Array or floor_refs.size() != 2:
		return false
	# The source field owns the configured local attribute policy. Reapplying a
	# default allowlist here would reject a separately authorized custom profile.
	for word: Variant in attributes:
		if not _uint(word, 65535): return false
	for reference: Variant in floor_refs:
		if not _uint(reference, 4294967295) or int(reference) == 4294967295: return false
	return true

func activation_target(id: int, current_source_cell: Vector2i, source_field: RefCounted) -> Dictionary:
	# This function authorizes no costs and moves no actor. The caller receives a
	# target only after both actual endpoints pass the explicit application policy.
	if not loaded or not _portals.has(id): return {"ok": false, "reason": "portal_contract_unavailable"}
	var entry: Dictionary = _portals[id]
	if entry.get("activation_candidate") != true: return {"ok": false, "reason": "portal_endpoint_evidence_incomplete", "blockers": entry.get("blockers", []).duplicate()}
	var start := Vector2i(int(entry.source_position[0]), int(entry.source_position[1]))
	var target := Vector2i(int(entry.landing_position[0]), int(entry.landing_position[1]))
	if current_source_cell != start: return {"ok": false, "reason": "actor_not_at_declared_portal"}
	if source_field == null or not source_field.has_method("source_cell_info"):
		return {"ok": false, "reason": "source_field_unavailable"}
	var source_info: Variant = source_field.source_cell_info(start)
	if not source_info is Dictionary or not _endpoint_clear(source_info, start, entry.source_support):
		return {"ok": false, "reason": "source_endpoint_blocked"}
	var target_info: Variant = source_field.source_cell_info(target)
	if not target_info is Dictionary or not _endpoint_clear(target_info, target, entry.target_support):
		return {"ok": false, "reason": "target_endpoint_blocked"}
	return {"ok": true, "portal_id": id, "source_position": start, "target_position": target,
		"source_info": source_info, "target_info": target_info, "native_m_rules_verified": false}
