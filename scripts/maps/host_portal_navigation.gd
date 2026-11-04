extends RefCounted
## Navigate to an existing host trigger. This never supplies an M Portal mapping.
# Existing TwilightPlayer._click_path_velocity stops within five host pixels.
const HOST_STOP_DISTANCE: float = 5.0

static func denied(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func graph_key(field: RefCounted) -> String:
	return JSON.stringify(field.data.get("portal", []), "", true, true).sha256_text()

static func capture(world: Node, portal: Dictionary) -> Dictionary:
	if world.field_map == null: return {}
	return {"map_id": str(world.active_map_id), "field_id": world.field_map.get_instance_id(),
		"revision": world.field_map.data.get("layout_revision", -1), "graph": graph_key(world.field_map), "portal": portal.duplicate(true)}

static func point(value: Variant) -> Vector2:
	if not value is Array or value.size() != 2: return Vector2.INF
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)): return Vector2.INF
	return Vector2(float(value[0]), float(value[1]))

static func inspect(world: Node, receipt: Dictionary) -> Dictionary:
	if world.field_map == null or not is_instance_valid(world.player): return denied("현재 지역을 확인할 수 없습니다.")
	if receipt.get("map_id") != str(world.active_map_id) or receipt.get("field_id") != world.field_map.get_instance_id() or receipt.get("revision") != world.field_map.data.get("layout_revision", -1) or receipt.get("graph") != graph_key(world.field_map):
		return denied("지역 또는 이동석이 변경됐습니다. 목록을 새로고침하세요.")
	if not receipt.get("portal") is Dictionary: return denied("이동석 정보가 올바르지 않습니다.")
	var portal: Dictionary = receipt.portal
	var matches: int = 0
	for current: Dictionary in world.field_map.data.get("portal", []):
		if str(current.get("id", "")) == str(portal.get("id", "")):
			matches += 1
			if current != portal: return denied("이동석 정보가 변경됐습니다.")
	if matches != 1 or str(portal.get("id", "")).is_empty(): return denied("이동석 연결을 확인할 수 없습니다.")
	if portal.has("SourceLandID") or portal.has("source_m_portal_id") or portal.get("source_snapshot", "") in ["base508", "patch523"]:
		return denied("원본 M 포탈의 작동 규칙은 아직 확인되지 않았습니다.")
	var at: Vector2 = point(portal.get("position"))
	var radius: Variant = portal.get("radius")
	if not at.is_finite() or not (radius is int or radius is float) or not is_finite(float(radius)) or float(radius) <= HOST_STOP_DISTANCE:
		return denied("이동석의 접근 위치를 확인할 수 없습니다.")
	var destination: String = world.NATIVE_PNG.canonical(str(portal.get("target_map", "")))
	if not world.maps_by_id.has(destination): return denied("목적 지역이 현재 게임에 연결되지 않았습니다.")
	if destination == str(world.active_map_id) and portal.has("target_position"):
		var arrival: Vector2 = point(portal.target_position)
		if portal.get("target_layout_revision", -1) != world.field_map.data.get("layout_revision", -1) or not arrival.is_finite() or not world.field_map.point_clear(arrival, 4.0):
			return denied("이동석의 도착 위치를 현재 지역에서 확인하지 못했습니다.")
	if world.hp <= 0 or world.player.is_stunned() or world.player.is_held() or world.player.is_feared() or world.player.movement_locked or not world.charge_skill.is_empty():
		return denied("지금은 이동할 수 없습니다.")
	if world.player.auto_enabled: return denied("자동사냥을 중지한 뒤 이동하세요.")
	return {"ok": true, "reason": "기존 통행 경로로 이동하고, 도착 후 기존 이동석이 작동합니다.", "portal": portal, "position": at, "radius": float(radius)}

static func walk_to(world: Node, receipt: Dictionary) -> Dictionary:
	var state: Dictionary = inspect(world, receipt)
	if not state.ok: return state
	var path: PackedVector2Array = world.find_world_path(world.player.global_position, state.position)
	if path.is_empty() or not path[-1].is_finite() or path[-1].distance_to(state.position) + HOST_STOP_DISTANCE >= float(state.radius):
		return denied("이동석의 작동 반경 안으로 들어가는 경로를 찾지 못했습니다.")
	var previous: Vector2 = world.player.global_position
	for waypoint: Vector2 in path:
		if not waypoint.is_finite() or not world.field_map.point_clear(waypoint, 4.0) or not world.field_map.line_clear(previous, waypoint):
			return denied("현재 통행 경계에서 안전한 경로를 확인하지 못했습니다.")
		for other: Dictionary in world.field_map.data.get("portal", []):
			if str(other.get("id", "")) == str(state.portal.id): continue
			var center: Vector2 = point(other.get("position"))
			var radius: Variant = other.get("radius")
			if not center.is_finite() or not (radius is int or radius is float) or not is_finite(float(radius)) or float(radius) <= 0.0:
				return denied("경로 주변 이동석의 작동 범위를 확인하지 못했습니다.")
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, previous, waypoint)
			# Waypoints may be skipped within the existing five-pixel stop
			# tolerance. Keep that corridor clear; do not change trigger radii.
			if closest.distance_to(center) <= float(radius) + HOST_STOP_DISTANCE: return denied("다른 이동석이 먼저 작동할 수 있는 경로입니다.")
		previous = waypoint
	# Planning and every rejection above are read-only. Commit only the same
	# manual movement state used by ordinary clicks; arrival uses existing code.
	world.loot_pickup.cancel()
	world.manual_route_pending_target = Vector2.INF
	world.player.set_manual_click_path(path, state.position)
	return {"ok": true, "reason": "이동석으로 이동합니다: " + str(state.portal.get("name", state.portal.id)), "waypoints": path.size()}
