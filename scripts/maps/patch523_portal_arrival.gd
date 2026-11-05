extends RefCounted
## Read-only landing preflight. This does not move actors or authorize a portal.
const SPACE = "LINEAGEM_WORLD_SOURCE_CELLS_V1"
const FOOTPRINT = [Vector2(4,0), Vector2(-4,0), Vector2(0,4), Vector2(0,-4),
	Vector2(2.83,2.83), Vector2(-2.83,2.83), Vector2(2.83,-2.83), Vector2(-2.83,-2.83)]

static func held(contract: Dictionary, code: String, message: String) -> Dictionary:
	return {"landing_geometry_ok": false, "travel_enabled": false, "code": code, "reason": message, "contract": contract}

static func affirmed(value: Variant) -> bool:
	return value is bool and value

static func inspect(catalog: RefCounted, portal_id: int, field: RefCounted) -> Dictionary:
	if catalog == null: return held({}, "portal_missing", "현재 원본 포탈 선언을 확인할 수 없습니다.")
	var contract: Dictionary = catalog.portal_contract(portal_id)
	if contract.is_empty(): return held({}, "portal_missing", "현재 원본 포탈 선언을 확인할 수 없습니다.")
	if contract.arrival_kind != "EXACT_POINT":
		return held(contract, "arrival_region_policy_required", "원본은 도착 영역만 선언합니다. 도착점 선택 규칙이 필요합니다.")
	if field == null or not field.has_method("portal_geometry_contract"):
		return held(contract, "source_geometry_api_required", "목적 지역의 원본 좌표·지형 검증 API가 연결되지 않았습니다.")
	var identity: Variant = field.call("portal_geometry_contract")
	if not identity is Dictionary or identity.get("schema") != 1 or identity.get("source_snapshot") != "patch523" or identity.get("coordinate_space") != SPACE or identity.get("definition_manifest_sha256") != contract.manifest_sha256:
		return held(contract, "source_geometry_identity_mismatch", "지형의 누적523 원본·좌표계·정의 해시가 일치하지 않습니다.")
	if identity.get("land_id") != contract.target_namespace.land_id or identity.get("asset_path") != contract.target_namespace.asset_path:
		return held(contract, "destination_namespace_mismatch", "도착 Land/AssetPath와 현재 지형이 다릅니다.")
	# A local traversal/foot policy must be explicit; it is never M collision proof.
	if identity.get("collision_scope") != "EXPLICIT_LOCAL_POLICY" or str(identity.get("traversal_policy_id", "")).is_empty() or str(identity.get("actor_foot_policy_id", "")).is_empty() or not str(identity.get("geometry_sha256", "")).is_valid_hex_number(false) or str(identity.get("geometry_sha256", "")).length() != 64:
		return held(contract, "explicit_geometry_policy_required", "원본 지형 해시와 명시적인 자체 통행·발 기준 설정이 필요합니다.")
	for method: String in ["source_cell_supplied", "source_to_world", "world_to_source", "point_clear", "line_clear"]:
		if not field.has_method(method): return held(contract, "source_geometry_api_required", "목적 지형 API 누락: " + method)
	var at := Vector2(float(contract.declared_arrival[0]), float(contract.declared_arrival[1]))
	if not affirmed(field.call("source_cell_supplied", Vector2i(at))):
		return held(contract, "destination_chunk_missing", "명시 도착점의 원본 청크가 공급되지 않았습니다.")
	var projected: Variant = field.call("source_to_world", at)
	if not projected is Vector2 or not projected.is_finite(): return held(contract, "invalid_projection", "도착점 투영을 확인하지 못했습니다.")
	var roundtrip: Variant = field.call("world_to_source", projected)
	if not roundtrip is Vector2 or not roundtrip.is_finite() or roundtrip.distance_to(at) > 0.0001:
		return held(contract, "projection_roundtrip_mismatch", "투영 후 원본 도착 좌표가 달라집니다.")
	if not affirmed(field.call("point_clear", projected, 4.0)) or not affirmed(field.call("line_clear", projected, projected)):
		return held(contract, "destination_blocked", "명시 도착점의 바닥·점유를 통과하지 못했습니다.")
	for offset: Vector2 in FOOTPRINT:
		if not affirmed(field.call("line_clear", projected, projected + offset)):
			return held(contract, "destination_footprint_blocked", "도착점 주변의 현재 캐릭터 발 공간이 막혀 있습니다.")
	return {"landing_geometry_ok": true, "travel_enabled": false, "code": "landing_only_activation_unverified",
		"reason": "명시 도착점은 자체 통행 설정에서 착지 검사를 통과했습니다. 포탈 트리거·활성은 별도 확인이 필요합니다.",
		"contract": contract, "source_point": at, "world_point": projected,
		"geometry": identity.duplicate(true), "footprint_policy": "EXISTING_TWILIGHT_4PX; NOT_VERIFIED_M_ACTOR_FOOT"}
