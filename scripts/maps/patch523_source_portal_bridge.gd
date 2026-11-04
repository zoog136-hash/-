extends RefCounted
## Optional consumer of PR232's public Main API; no terrain or travel owner here.
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const METHODS = ["current523_aden_source_portals", "current523_aden_source_portal_context", "use_current523_aden_source_portal"]
var busy: bool = false

static func property(object: Object, name: String, fallback: Variant = null) -> Variant:
	for spec: Dictionary in object.get_property_list():
		if spec.name == name: return object.get(name)
	return fallback

static func fingerprint(value: Dictionary) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func flag(value: Variant, expected: bool) -> bool:
	return value is bool and value == expected

static func point(value: Variant) -> Vector2:
	if not value is Array or value.size() != 2: return Vector2.INF
	for component: Variant in value:
		if not LINKS._integer(component) or absf(float(component)) > 2147480000: return Vector2.INF
	return Vector2(float(value[0]), float(value[1]))

static func held(contract: Dictionary, code: String, reason: String) -> Dictionary:
	return {"request_enabled": false, "travel_enabled": false, "code": code, "reason": reason, "contract": contract, "receipt": {}}

static func endpoint(info: Variant, at: Vector2, support: Variant) -> bool:
	# Consume the field's policy verdict, not its raw attribute interpretation.
	if not support is Dictionary or not support.get("member") is String or not support.member.begins_with("Map/Aden/") or not support.member.ends_with(".s32") or not support.get("sha256") is String or support.sha256.length() != 64 or not support.sha256.is_valid_hex_number(false): return false
	return info is Dictionary and support is Dictionary and support.get("s32_member_verified") is bool and support.s32_member_verified and info.get("status") == "allowed" and info.get("walkable") is bool and info.walkable and info.get("source_cell") == Vector2i(at) and info.get("member") == support.get("member") and info.get("source_sha256") == support.get("sha256")

static func inspect(world: Node, catalog: RefCounted, id: int) -> Dictionary:
	if not is_instance_valid(world) or catalog == null or not catalog.has_method("portal_contract"): return held({}, "portal_missing", "현재 원본 포탈 선언을 확인할 수 없습니다.")
	var contract: Dictionary = catalog.portal_contract(id)
	if contract.is_empty(): return held({}, "portal_missing", "현재 원본 포탈 선언을 확인할 수 없습니다.")
	for method: String in METHODS:
		if not world.has_method(method): return held(contract, "source_runtime_api_required", "원본 소스 필드 런타임이 이 실행본에 연결되지 않았습니다.")
	var field: Variant = property(world, "field_map")
	if not field is RefCounted or not flag(field.get_meta("current523_source_field", false), true) or not flag(property(field, "loaded", false), true) or not flag(property(world, "current523_aden_play_active", false), true):
		return held(contract, "source_field_inactive", "원본 S32 소스 필드 모드에서만 사용할 수 있습니다.")
	if not field.has_method("source_cell_info") or not field.has_method("world_to_cell"):
		return held(contract, "source_field_api_required", "원본 소스 셀 검사 API가 없습니다.")
	var list: Variant = world.call(METHODS[0])
	var context: Variant = world.call(METHODS[1], id)
	if not list is Array or not context is Dictionary or context.is_empty(): return held(contract, "runtime_contract_missing", "소스 필드의 포탈 계약이 없습니다.")
	var matching: Array = []
	for row: Variant in list:
		if not row is Dictionary: return held(contract, "runtime_contract_invalid", "소스 포탈 목록이 올바르지 않습니다.")
		if row.get("id") == id: matching.append(row)
	if matching.size() != 1 or fingerprint(matching[0]) != fingerprint(context):
		return held(contract, "runtime_contract_changed", "소스 포탈 목록과 선택 계약이 다릅니다. 새로고침하세요.")
	var declaration: Dictionary = contract.declaration
	if context.get("portal") != declaration.portal or context.get("target_territory") != declaration.target_territory or context.get("target_land") != declaration.target_land or point(context.get("source_position")) != point(contract.source_point):
		return held(contract, "declaration_mismatch", "현재 누적523 포탈 선언과 런타임 계약이 다릅니다.")
	if contract.target_namespace.land_id != 4 or contract.target_namespace.asset_path != "Aden/":
		return held(contract, "target_land_unavailable", "다른 Land의 실제 소스 필드가 연결되지 않았습니다.")
	if contract.arrival_kind != "EXACT_POINT": return held(contract, "arrival_region_policy_required", "도착 영역의 선택 규칙이 없어 보류합니다.")
	if point(context.get("landing_position")) != point(contract.declared_arrival):
		return held(contract, "declared_arrival_mismatch", "런타임 도착점이 원본 명시 도착점과 다릅니다.")
	if not flag(context.get("activation_candidate"), true) or not flag(context.get("raw_endpoint_match"), true) or not context.get("matched_raw_record_ids") is Array or context.matched_raw_record_ids.size() != 1:
		return held(contract, "endpoint_evidence_incomplete", "원문 양끝 근거가 부족하거나 불일치하여 보류합니다.")
	var start: Vector2 = point(contract.source_point)
	var target: Vector2 = point(contract.declared_arrival)
	if not endpoint(field.call("source_cell_info", Vector2i(start)), start, context.get("source_support")) or not endpoint(field.call("source_cell_info", Vector2i(target)), target, context.get("target_support")):
		return held(contract, "endpoint_policy_blocked", "현재 자체 통행에서 양끝 소스 셀을 확인하지 못했습니다.")
	var actor: Variant = property(world, "player")
	var coordinates: Variant = property(field, "coordinates")
	if not actor is Node2D or not coordinates is RefCounted or not property(coordinates, "origin") is Vector2i:
		return held(contract, "actor_source_unavailable", "현재 캐릭터의 원본 소스 셀을 확인하지 못했습니다.")
	var cell: Variant = field.call("world_to_cell", actor.global_position)
	if not cell is Vector2i or cell + coordinates.origin != Vector2i(start):
		return held(contract, "actor_not_at_declared_portal", "선언된 정확한 출발 셀에서 사용해 주세요.")
	var charge: Variant = property(world, "charge_skill")
	if int(property(world, "hp", 0)) <= 0 or not flag(property(actor, "auto_enabled"), false) or not flag(property(actor, "movement_locked"), false) or not charge is Dictionary or not charge.is_empty() or float(property(world, "portal_cooldown", 1.0)) > 0:
		return held(contract, "actor_state_blocked", "현재 캐릭터 상태에서는 포탈을 사용할 수 없습니다.")
	for method: String in ["is_stunned", "is_held", "is_feared"]:
		if not actor.has_method(method) or not flag(actor.call(method), false): return held(contract, "actor_state_blocked", "현재 캐릭터 상태에서는 포탈을 사용할 수 없습니다.")
	return {"request_enabled": true, "travel_enabled": false, "code": "explicit_runtime_request_ready", "reason": "양끝 자체 통행과 정확한 출발 셀을 확인했습니다. 사용 시 소스 런타임이 다시 검사합니다.", "contract": contract,
		"receipt": {"portal_id":id, "field_id":field.get_instance_id(), "context_sha256":fingerprint(context), "manifest_sha256":catalog.manifest_sha256}}

func request(world: Node, catalog: RefCounted, receipt: Dictionary) -> Dictionary:
	if busy: return {"ok":false, "reason":"포탈 요청을 처리 중입니다."}
	if not LINKS._integer(receipt.get("portal_id")): return {"ok":false, "reason":"포탈을 다시 선택해 주세요."}
	var state: Dictionary = inspect(world, catalog, int(receipt.portal_id))
	if not state.request_enabled: return {"ok":false, "reason":state.reason, "code":state.code}
	if state.receipt != receipt: return {"ok":false, "reason":"소스 필드 또는 포탈 계약이 변경됐습니다. 새로고침하세요.", "code":"stale_selection"}
	var field: RefCounted = world.field_map
	var position: Vector2 = world.player.global_position
	busy = true
	var result: Variant = world.call(METHODS[2], int(receipt.portal_id))
	busy = false
	if result is bool and result: return {"ok":true, "reason":"소스 런타임이 원문 포탈 요청을 완료했습니다."}
	# The runtime owns rollback. Do not overwrite its safe-return state here.
	var restored: bool = world.field_map == field and world.player.global_position == position
	var reason: String = str(property(world, "current523_aden_play_problem", ""))
	if reason.is_empty(): reason = "소스 런타임이 포탈 요청을 완료하지 못했습니다."
	return {"ok":false, "reason":reason, "code":"runtime_rejected" if restored else "runtime_changed_state_on_failure", "position_preserved":restored}
