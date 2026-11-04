extends RefCounted
## User-authorized TWILIGHT policy, NOT an M coordinate/collision contract.
## Only the active, validated local Aden field is bound. Never alters its grid.
const FIELD = preload("res://scripts/maps/source_map_runtime_field.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const BODY = preload("res://scripts/maps/source_body_profile.gd")
const POLICY_ID = "TWILIGHT_LOCAL_ADEN_V1"
const MAX_CANDIDATES = 4096
const DEFAULTS = {"enabled": false, "end_inclusive": true, "search_order": "center_first"}
var settings_path: String = "user://auto_hunting_local_policy.json"
var settings: Dictionary = DEFAULTS.duplicate(true)
var problem: String = ""
var settings_loaded: bool = false

static func fail(code: String, reason: String) -> Dictionary:
	return {"ok": false, "code": code, "reason": reason, "policy": POLICY_ID}

static func valid_settings(value: Dictionary) -> bool:
	return value.get("enabled") is bool and value.get("end_inclusive") is bool and value.get("search_order") in ["center_first", "coordinate_order"]

func get_settings() -> Dictionary:
	if not settings_loaded:
		settings_loaded = true
		if FileAccess.file_exists(settings_path):
			var file := FileAccess.open(settings_path, FileAccess.READ)
			var parser := JSON.new()
			var parsed: Variant = null
			if file != null and file.get_length() <= 4096 and parser.parse(file.get_as_text()) == OK: parsed = parser.data
			if parsed is Dictionary and parsed.get("schema") == 1 and parsed.get("policy") == POLICY_ID and valid_settings(parsed):
				for key: String in DEFAULTS: settings[key] = parsed[key]
			else: problem = "자체 이동 설정을 읽을 수 없어 사용을 껐습니다"
	return settings.duplicate(true)

func update_settings(value: Dictionary) -> Dictionary:
	get_settings()
	if not valid_settings(value): return fail("INVALID_SETTINGS", "자체 이동 설정이 유효하지 않습니다")
	var next: Dictionary = {"schema": 1, "policy": POLICY_ID}
	for key: String in DEFAULTS: next[key] = value[key]
	var error: Error = WRITER.write(settings_path, next)
	if error != OK: return fail("SETTINGS_SAVE_FAILED", "설정 저장 실패 · 이전 설정을 유지합니다")
	for key: String in DEFAULTS: settings[key] = value[key]
	problem = ""
	return {"ok": true, "settings": get_settings()}

static func territory_bounds(territory: Dictionary, end_inclusive: bool) -> Rect2i:
	var start := Vector2i(int(territory.StartX), int(territory.StartY))
	var end := Vector2i(int(territory.EndX), int(territory.EndY))
	var size: Vector2i = end - start + (Vector2i.ONE if end_inclusive else Vector2i.ZERO)
	return Rect2i(start, size) if size.x > 0 and size.y > 0 else Rect2i()

static func source_cell(field: RefCounted, point: Vector2) -> Vector2i:
	return field.world_to_cell(point) + field.coordinates.origin

static func safe_point(world: Node, point: Vector2) -> bool:
	var field: RefCounted = world.get("field_map")
	if not point.is_finite() or not field.walkable(point) or not field.point_clear(point, BODY.FOOT_RADIUS): return false
	# Reuse the existing local teleport monster clearance, not a new body mask.
	if not bool(world.call("_teleport_landing_clear", point)): return false
	# Existing source-field reservations cover local NPC/portal/entry footprints.
	for reservation: Dictionary in field.reservations:
		var center := Vector2(float(reservation.center[0]), float(reservation.center[1]))
		if point.distance_squared_to(center) < pow(float(reservation.radius), 2): return false
	return true

static func find_cell(field: RefCounted, bounds: Rect2i, order: String, predicate: Callable) -> Dictionary:
	var supplied := Rect2i(field.coordinates.origin, field.coordinates.dimensions)
	var clipped: Rect2i = bounds.intersection(supplied)
	if clipped.size.x <= 0 or clipped.size.y <= 0: return fail("OUTSIDE_FIELD", "착지 범위가 현재 지형 밖에 있습니다")
	var tested: int = 0
	if order == "coordinate_order":
		for y: int in range(clipped.position.y, clipped.end.y):
			for x: int in range(clipped.position.x, clipped.end.x):
				var cell := Vector2i(x, y)
				var point: Vector2 = field.coordinates.to_world(Vector2(cell))
				tested += 1
				if predicate.call(point): return {"ok": true, "source_cell": cell, "destination": point, "tested": tested}
				if tested >= MAX_CANDIDATES: return fail("SEARCH_LIMIT", "착지 탐색 상한 안에서 안전한 셀을 찾지 못했습니다")
	else:
		# Bounded candidate ordering only, not a walking path or a passability edit.
		var center := clipped.position + Vector2i((clipped.size.x - 1) / 2, (clipped.size.y - 1) / 2)
		var queue: Array[Vector2i] = [center]
		var seen: Dictionary = {center: true}
		while tested < queue.size() and tested < MAX_CANDIDATES:
			var cell: Vector2i = queue[tested]
			var point: Vector2 = field.coordinates.to_world(Vector2(cell))
			tested += 1
			if predicate.call(point): return {"ok": true, "source_cell": cell, "destination": point, "tested": tested}
			for delta: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]:
				var next: Vector2i = cell + delta
				if clipped.has_point(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		if tested >= MAX_CANDIDATES and tested < clipped.size.x * clipped.size.y:
			return fail("SEARCH_LIMIT", "착지 탐색 상한 안에서 안전한 셀을 찾지 못했습니다")
	return fail("NO_SAFE_CELL", "착지 범위 안에 통행·몸체·점유 검사를 통과한 셀이 없습니다")

func assess(world: Node, definition: Dictionary) -> Dictionary:
	if not bool(definition.get("ok", false)): return definition
	var options: Dictionary = get_settings()
	if not problem.is_empty(): return fail("SETTINGS_CORRUPT", problem)
	if not options.enabled: return fail("LOCAL_POLICY_DISABLED", "TWILIGHT 자체 이동 사용을 켜면 현재 아덴에서 이동할 수 있습니다")
	if int(world.get("hp")) <= 0: return fail("DEAD", "쓰러진 상태에서는 이동할 수 없습니다")
	var player: Node = world.get("player")
	if player.is_stunned() or player.is_feared() or player.is_held() or not world.get("charge_skill").is_empty():
		return fail("MOVEMENT_STATE", "현재 행동 상태에서는 이동할 수 없습니다")
	if bool(world.get("source_save_blocked")) or not world.get("pending_map_save_record").is_empty():
		return fail("SAVE_GUARD", "현재 위치를 정상 저장한 뒤 이동해 주세요")
	var landing: Dictionary = definition.landing
	if int(landing.land.ID) != 4 or str(landing.land.AssetPath) != "Aden/":
		return fail("UNBOUND_LAND", "이 원본 지역에 대응하는 TWILIGHT 이동 지형은 아직 연결되지 않았습니다")
	var field: RefCounted = world.get("field_map")
	if world.get("active_map_id") != "aden_world" or field == null or field.get_script() != FIELD or not field.local_runtime:
		return fail("CURRENT_ADEN_ONLY", "이 자체 정책은 현재 아덴 지형 안에서만 사용할 수 있습니다")
	if int(field.runtime_record.source_map_id) != 4 or int(field.data.layout_revision) <= 0:
		return fail("FIELD_IDENTITY", "현재 아덴 지형의 신원을 확인할 수 없습니다")
	var bounds: Rect2i = territory_bounds(landing.territory, bool(options.end_inclusive))
	if bounds.size.x <= 0 or bounds.size.y <= 0: return fail("EMPTY_REGION", "선택한 끝 좌표 규칙에서는 착지 범위가 비어 있습니다")
	if bounds.has_point(source_cell(field, player.global_position)):
		return fail("ALREADY_THERE", "이미 이 착지 범위 안에 있습니다 · 비용을 소모하지 않습니다")
	var result: Dictionary = find_cell(field, bounds, str(options.search_order), func(point: Vector2) -> bool: return safe_point(world, point))
	if not bool(result.ok): return result
	# One chosen candidate per configured order. Use the production save route
	# guard (and its cache/search bound) rather than inventing a new pathfinder.
	if not bool(world.call("auto_hunting_destination_saveable", result.destination)):
		return fail("DESTINATION_SAVE_GUARD", "선택한 착지 셀의 기존 저장·재진입 경로 검사를 통과하지 못했습니다 · 다른 셀 선택 순서를 확인해 주세요")
	result["code"] = "READY"
	result["policy"] = POLICY_ID
	result["policy_options"] = options
	result["schedule_id"] = definition.schedule_id
	result["landing_link_id"] = definition.landing_link_id
	result["price"] = definition.price
	result["map_id"] = "aden_world"
	result["layout_revision"] = int(field.data.layout_revision)
	result["reason"] = "TWILIGHT 자체 정책 · 안전한 착지 셀 확인 · 원본 비용 %d 아데나" % int(definition.price)
	return result

static func save_fields(world: Node, quote: Dictionary) -> Dictionary:
	var field: RefCounted = world.get("field_map")
	var point: Vector2 = quote.destination
	return {"position": [point.x, point.y], "original_position": {
		"source_map_id": int(field.definition.source_map_id),
		"source": field.coordinates.source_components(point),
		"grid_sha256": str(field.definition.source_sha256)}}
