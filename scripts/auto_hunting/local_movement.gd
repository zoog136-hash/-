extends RefCounted
## User-authorized TWILIGHT policy, NOT an M coordinate/collision contract.
## Only explicitly bound active fields are used. Never alters their grids.
const FIELD = preload("res://scripts/maps/source_map_runtime_field.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const BODY = preload("res://scripts/maps/source_body_profile.gd")
const POLICY_ID = "TWILIGHT_LOCAL_ADEN_V1"
const MAX_CANDIDATES = 4096
const ACTOR_BUFFER = 64.0 # Existing source_map_runtime_field.preserve_gameplay reservation radius.
const GEM_KEY = "다이아" # Currency4.DescID729861 -> DescData_Korean, exact source label.
const LAND_BINDINGS = {4:{"map_id":"aden_world","asset_path":"Aden/","local_required":true},
	35:{"map_id":"source_35","asset_path":"35/","local_required":false}}
const DEFAULTS = {"enabled": false, "end_inclusive": true, "search_order": "center_first", "gem_wallet_enabled": false, "allow_entry_area": false}
var settings_path: String = "user://auto_hunting_local_policy.json"
var settings: Dictionary = DEFAULTS.duplicate(true)
var problem: String = ""
var settings_loaded: bool = false

static func fail(code: String, reason: String) -> Dictionary:
	return {"ok": false, "code": code, "reason": reason, "policy": POLICY_ID}

static func valid_settings(value: Dictionary) -> bool:
	return value.get("enabled") is bool and value.get("end_inclusive") is bool and value.get("search_order") in ["center_first", "coordinate_order"] and value.get("gem_wallet_enabled", false) is bool and value.get("allow_entry_area", false) is bool

func get_settings() -> Dictionary:
	if not settings_loaded:
		settings_loaded = true
		if FileAccess.file_exists(settings_path):
			var file := FileAccess.open(settings_path, FileAccess.READ)
			var parser := JSON.new()
			var parsed: Variant = null
			if file != null and file.get_length() <= 4096 and parser.parse(file.get_as_text()) == OK: parsed = parser.data
			if parsed is Dictionary and (parsed.get("schema") == 1 or parsed.get("schema") == 2 or parsed.get("schema") == 3) and parsed.get("policy") == POLICY_ID and valid_settings(parsed):
				for key: String in DEFAULTS: settings[key] = parsed.get(key, DEFAULTS[key])
			else: problem = "자체 이동 설정을 읽을 수 없어 사용을 껐습니다"
	return settings.duplicate(true)

func update_settings(value: Dictionary) -> Dictionary:
	get_settings()
	if not valid_settings(value): return fail("INVALID_SETTINGS", "자체 이동 설정이 유효하지 않습니다")
	var next: Dictionary = {"schema": 3, "policy": POLICY_ID}
	for key: String in DEFAULTS: next[key] = value.get(key, settings[key])
	var error: Error = WRITER.write(settings_path, next)
	if error != OK: return fail("SETTINGS_SAVE_FAILED", "설정 저장 실패 · 이전 설정을 유지합니다")
	for key: String in DEFAULTS: settings[key] = next[key]
	problem = ""
	return {"ok": true, "settings": get_settings()}

func gem_wallet(world: Node) -> Dictionary:
	if not bool(get_settings().gem_wallet_enabled): return fail("GEM_WALLET_DISABLED", "자체 다이아 잔액 연결을 켜 주세요 · 원본 Gem ID4")
	var value: Variant = world.get("inventory").get(GEM_KEY, 0)
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 9007199254740991.0 or float(value) != floorf(float(value)):
		return fail("INVALID_GEM_WALLET", "다이아 보유량을 확인할 수 없어 소모를 차단했습니다")
	if bool(world.call("_item_locked", GEM_KEY)): return fail("GEM_LOCKED", "인벤토리에서 잠근 다이아는 소모하지 않습니다")
	for item: Dictionary in world.get("item_instances").values():
		if str(item.get("name", "")) == GEM_KEY: return fail("GEM_INSTANCE_GUARD", "물리 아이템으로 저장된 다이아는 잔액으로 소모하지 않습니다")
	return {"ok": true, "balance": int(value), "key": GEM_KEY}

static func cost_override(world: Node, quote: Dictionary) -> Dictionary:
	if int(quote.currency_id) == 1: return {"gold": int(world.get("gold")) - int(quote.price)}
	var inventory: Dictionary = world.get("inventory").duplicate(true)
	var remaining: int = int(inventory.get(GEM_KEY, 0)) - int(quote.price)
	if remaining == 0: inventory.erase(GEM_KEY)
	else: inventory[GEM_KEY] = remaining
	return {"inventory": inventory}

static func territory_bounds(territory: Dictionary, end_inclusive: bool) -> Rect2i:
	var start := Vector2i(int(territory.StartX), int(territory.StartY))
	var end := Vector2i(int(territory.EndX), int(territory.EndY))
	var size: Vector2i = end - start + (Vector2i.ONE if end_inclusive else Vector2i.ZERO)
	return Rect2i(start, size) if size.x > 0 and size.y > 0 else Rect2i()

static func source_cell(field: RefCounted, point: Vector2) -> Vector2i:
	return field.world_to_cell(point) + field.coordinates.origin

static func safe_point(world: Node, point: Vector2, allow_entry_area: bool = false) -> bool:
	var field: RefCounted = world.get("field_map")
	if not point.is_finite() or not field.walkable(point) or not field.point_clear(point, BODY.FOOT_RADIUS): return false
	# Reuse the existing local teleport monster clearance, not a new body mask.
	if not bool(world.call("_teleport_landing_clear", point)): return false
	# Existing reservations include the entry/authored actors. Source NPCs are
	# appended after the frozen gameplay snapshot without adding reservations,
	# so also check the actual installed coordinate records with the same buffer.
	for reservation: Dictionary in field.reservations:
		var center := Vector2(float(reservation.center[0]), float(reservation.center[1]))
		if point.distance_squared_to(center) >= pow(float(reservation.radius), 2): continue
		var spawn: Array = field.data.get("spawn_position", [])
		var entry_only: bool = allow_entry_area and spawn.size() == 2 and center == Vector2(float(spawn[0]),float(spawn[1])) and float(reservation.radius) == ACTOR_BUFFER
		if not entry_only: return false
	for category: String in ["npc_spawn", "portal"]:
		for actor: Dictionary in field.data.get(category, []):
			var center := Vector2(float(actor.position[0]), float(actor.position[1]))
			var radius: float = maxf(ACTOR_BUFFER, float(actor.get("radius", 0)) + BODY.FOOT_RADIUS) if category == "portal" else ACTOR_BUFFER
			if point.distance_squared_to(center) < radius * radius: return false
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
	if not options.enabled: return fail("LOCAL_POLICY_DISABLED", "TWILIGHT 자체 이동 사용을 켜 주세요")
	if int(world.get("hp")) <= 0: return fail("DEAD", "쓰러진 상태에서는 이동할 수 없습니다")
	var player: Node = world.get("player")
	if player.is_stunned() or player.is_feared() or player.is_held() or not world.get("charge_skill").is_empty():
		return fail("MOVEMENT_STATE", "현재 행동 상태에서는 이동할 수 없습니다")
	if bool(world.get("source_save_blocked")) or not world.get("pending_map_save_record").is_empty():
		return fail("SAVE_GUARD", "현재 위치를 정상 저장한 뒤 이동해 주세요")
	var landing: Dictionary = definition.landing
	var land_id: int = int(landing.land.ID)
	if not LAND_BINDINGS.has(land_id) or str(landing.land.AssetPath) != str(LAND_BINDINGS[land_id].asset_path):
		return fail("UNBOUND_LAND", "이 원본 지역에 대응하는 TWILIGHT 이동 지형은 아직 연결되지 않았습니다")
	var binding: Dictionary = LAND_BINDINGS[land_id]
	var field: RefCounted = world.get("field_map")
	if world.get("active_map_id") != str(binding.map_id) or field == null or field.get_script() != FIELD or (bool(binding.local_required) and not field.local_runtime):
		return fail("CURRENT_FIELD_ONLY", "현재 지도 안의 이동만 지원합니다 · 다른 지도는 기존 이동 경로로 먼저 입장해 주세요")
	if int(field.runtime_record.source_map_id) != land_id or int(field.data.layout_revision) <= 0:
		return fail("FIELD_IDENTITY", "현재 원본 지형의 신원을 확인할 수 없습니다")
	var bounds: Rect2i = territory_bounds(landing.territory, bool(options.end_inclusive))
	if bounds.size.x <= 0 or bounds.size.y <= 0: return fail("EMPTY_REGION", "선택한 끝 좌표 규칙에서는 착지 범위가 비어 있습니다")
	if bounds.has_point(source_cell(field, player.global_position)):
		return fail("ALREADY_THERE", "이미 이 착지 범위 안에 있습니다 · 비용을 소모하지 않습니다")
	var result: Dictionary = find_cell(field, bounds, str(options.search_order), func(point: Vector2) -> bool: return safe_point(world, point, bool(options.allow_entry_area)))
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
	for key: String in ["currency_id", "currency_name", "currency_asset_id", "currency_label"]: result[key] = definition[key]
	result["map_id"] = str(binding.map_id)
	result["layout_revision"] = int(field.data.layout_revision)
	result["reason"] = "TWILIGHT 자체 정책 · 안전한 착지 셀 확인 · 원본 비용 %d %s" % [int(definition.price), str(definition.currency_label)]
	return result

static func save_fields(world: Node, quote: Dictionary) -> Dictionary:
	var field: RefCounted = world.get("field_map")
	var point: Vector2 = quote.destination
	return {"position": [point.x, point.y], "original_position": {
		"source_map_id": int(field.definition.source_map_id),
		"source": field.coordinates.source_components(point),
		"grid_sha256": str(field.definition.source_sha256)}}
