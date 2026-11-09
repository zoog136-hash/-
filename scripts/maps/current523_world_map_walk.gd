extends RefCounted
## Consumes an already converted M source point through the existing OWN field
## path and player manual-navigation APIs. Pixel/UI conversion belongs to caller.
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const COORDINATES = preload("res://scripts/maps/source_coordinates.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const KIND: String = "CURRENT523_WORLD_MAP_WALK_V1"
const GEOGRAPHY: String = "CURRENT523_S32_OWN_SOURCE_FIELD_V1"
const WALK_PROFILE: String = "CURRENT523_S32_OWN_ALLOWLIST_V1"
## The field's client rule (S32 attribute bit0). Walking still goes through
## the field's own point_clear/find_world_path, which apply whichever rule the
## field was opened with.
const CLIENT_WALK_PROFILE: String = "CURRENT523_S32_CLIENT_ATTR_BIT0_V1"

## Actual playable source fields are RefCounted, not scene Nodes.
## This is an ephemeral stale-input identity, never a saved movement authority.
static func ticket(world: Node, field: RefCounted) -> Dictionary:
	var context: Dictionary = _context(world, field)
	if context.is_empty(): return {}
	var actor: Node2D = context.actor
	var controller: RefCounted = context.controller
	var coordinates: RefCounted = context.coordinates
	var route: Variant = _property(actor, "click_path")
	var index: Variant = _property(actor, "path_index")
	var manual: Variant = _property(actor, "manual_navigation")
	var pending: Variant = _property(world, "manual_route_pending_target")
	var selections: Variant = _property(context.interactions, "selections")
	if not route is PackedVector2Array or not index is int or index < 0 or not manual is bool or not pending is Vector2 or not selections is Array: return {}
	var coordinate_identity: Dictionary = {}
	for key: String in ["origin", "dimensions", "basis_x", "basis_y", "translation", "determinant"]:
		coordinate_identity[key] = _property(coordinates, key)
	var pending_attack: Variant = _property(world, "pending_attack", {})
	if not pending_attack is Dictionary: return {}
	return {
		"kind": KIND,
		"world_instance": world.get_instance_id(),
		"controller_instance": controller.get_instance_id(),
		"field_instance": field.get_instance_id(),
		"actor_instance": actor.get_instance_id(),
		"renderer_instance": _identity(context.renderer),
		"physics_instance": _identity(context.physics),
		"provider_instance": _identity(context.provider),
		"definition_generation": _property(controller, "_portal_definition_generation"),
		"source_manifest_sha256": context.settings.source_manifest_sha256,
		"active_map_id": _property(world, "active_map_id"),
		"native_land": context.native_land.duplicate(true),
		"source_asset": _property(field, "source_asset"),
		"field_definition": context.definition.duplicate(true),
		"source_bounds": context.source_bounds,
		"navigation_policy": context.policy.duplicate(true),
		"controller_settings": context.settings.duplicate(true),
		"coordinates_instance": coordinates.get_instance_id(),
		"coordinates": coordinate_identity,
		"actor_position": actor.global_position,
		"click_path": route.duplicate(),
		"path_index": index,
		"manual_navigation": manual,
		"manual_route_pending_target": pending,
		"loot_owner_instance": _identity(context.loot),
		"loot_mode": _property(context.loot, "mode"),
		"loot_target": _property(context.loot, "target_id"),
		"loot_selection": _property(context.loot, "selected_id"),
		"pending_ground_pickup": _identity(_property(world, "pending_ground_pickup")),
		"interaction_owner_instance": _identity(context.interactions),
		"selections": selections.duplicate(true),
		"selected_monster": _identity(_property(world, "selected_monster")),
		"auto_target": _identity(_property(world, "auto_target")),
		"combat_generation": _property(world, "combat_generation"),
		"pending_attack": pending_attack.duplicate(true)
	}

static func request(world: Node, field: RefCounted, source_components: Array, held_ticket: Dictionary) -> Dictionary:
	if not _current(world, field, held_ticket): return _stale()
	var context: Dictionary = _context(world, field)
	var problem: String = _movement_problem(world, context.actor, context.controller)
	if not problem.is_empty(): return _reject("actor_state_blocked", problem)
	if not _components(source_components):
		return _failed_destination(world, field, held_ticket, "invalid_source_point", "선택한 원문 좌표가 올바르지 않습니다.")
	var source_cell := Vector2i(floori(float(source_components[0])), floori(float(source_components[1])))
	if not context.source_bounds.has_point(source_cell):
		return _failed_destination(world, field, held_ticket, "outside_source_bounds", "선택한 원문 좌표가 현재 필드 범위 밖입니다.")
	# Keep the supplied scalar components. No cell centering, nearest-floor
	# replacement or alternate projection is introduced by this consumer.
	var target_value: Variant = context.coordinates.call("components_to_world", source_components)
	if not target_value is Vector2 or not target_value.is_finite():
		return _failed_destination(world, field, held_ticket, "invalid_world_point", "원문 목적지의 현재 필드 좌표를 확인할 수 없습니다.")
	var target: Vector2 = target_value
	if field.call("point_clear", target, 4.0) != true:
		return _failed_destination(world, field, held_ticket, "destination_blocked", "선택한 원문 목적지가 현재 자체 통행에서 차단됩니다.")
	var route_value: Variant = world.call("find_world_path", context.actor.global_position, target)
	if not route_value is PackedVector2Array or route_value.is_empty() or route_value[route_value.size() - 1] != target:
		return _failed_destination(world, field, held_ticket, "exact_route_unavailable", "선택한 원문 목적지까지 확인된 보행 경로가 없습니다.")
	var route: PackedVector2Array = route_value
	for point: Vector2 in route:
		if not point.is_finite():
			return _failed_destination(world, field, held_ticket, "invalid_route", "현재 보행 경로의 좌표를 확인할 수 없습니다.")
	# Both route success and failure recheck before any transient owner changes.
	if not _current(world, field, held_ticket): return _stale()
	problem = _movement_problem(world, context.actor, context.controller)
	if not problem.is_empty(): return _reject("actor_state_blocked", problem)
	_clear_intent_owners(world, context)
	context.actor.call("set_manual_click_path", route, target)
	return {"ok": true, "requested": true, "stale": false, "route_cancelled": false, "state_preserved": false, "target": target, "source_components": source_components.duplicate(), "path_points": route.size(), "reason": "선택한 원문 목적지로 걸어갑니다."}

static func _context(world: Node, field: RefCounted) -> Dictionary:
	if world == null or not is_instance_valid(world) or world.is_queued_for_deletion() or not world.is_inside_tree() or not world.has_method("find_world_path"): return {}
	if field == null or not is_instance_valid(field) or field.get_script() != FIELD: return {}
	if field.get_meta("current523_source_field", false) != true or field.get_meta("current523_generic_field", false) != true or _property(field, "loaded") != true: return {}
	if _property(world, "field_map") != field or _property(world, "current523_aden_play_active") != true or _property(world, "current523_aden_review_active", false) != false: return {}
	var controller: Variant = _property(world, "_current523_aden_play_controller")
	if not controller is RefCounted or not is_instance_valid(controller) or _property(controller, "active") != true or _property(controller, "source_owned") != true or _property(controller, "_source_field") != field: return {}
	var world_ref: Variant = _property(controller, "_world_ref")
	if not world_ref is WeakRef or world_ref.get_ref() != world: return {}
	var settings: Variant = _property(controller, "settings")
	var generation: Variant = _property(controller, "_portal_definition_generation")
	var provider: Variant = _property(controller, "_source_portal_provider")
	if not settings is Dictionary or settings.get("navigation_profile") != OPTIONS.GENERIC or not generation is int or generation < 0 or not provider is RefCounted or not is_instance_valid(provider): return {}
	if not _sha(settings.get("source_manifest_sha256")) or _property(field, "catalog_sha256") != settings.source_manifest_sha256: return {}
	var definition: Variant = _property(field, "definition")
	var native_land: Variant = _property(field, "native_land")
	var policy: Variant = _property(field, "policy")
	var source_bounds: Variant = _property(field, "source_bounds")
	if not definition is Dictionary or definition.get("geographic_contract") != GEOGRAPHY or definition.get("source_manifest_sha256") != settings.source_manifest_sha256: return {}
	if not native_land is Dictionary or native_land.is_empty() or native_land.get("ID") != settings.get("native_land_id") or not policy is Dictionary or not policy.get("profile") in [WALK_PROFILE, CLIENT_WALK_PROFILE]: return {}
	if not source_bounds is Rect2i or not source_bounds.has_area() or not _property(field, "source_asset") is String: return {}
	var coordinates: Variant = _property(field, "coordinates")
	if not coordinates is RefCounted or not is_instance_valid(coordinates) or coordinates.get_script() != COORDINATES or _property(coordinates, "valid") != true: return {}
	if not coordinates.has_method("components_to_world") or not field.has_method("point_clear"): return {}
	var actor: Variant = _property(world, "player")
	if not actor is Node2D or not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree() or actor.get_parent() != world or not actor.global_position.is_finite(): return {}
	for method: String in ["set_manual_click_path", "clear_click_path", "is_stunned", "is_held", "is_feared"]:
		if not actor.has_method(method): return {}
	var renderer: Variant = _property(controller, "_renderer")
	var physics: Variant = _property(controller, "_source_physics")
	if not _live_node(renderer) or not _live_node(physics) or _property(world, "field_renderer") != renderer or _property(world, "field_physics") != physics: return {}
	var loot: Variant = _property(world, "loot_pickup")
	var interactions: Variant = _property(world, "world_interactions")
	if not loot is Object or not is_instance_valid(loot) or not loot.has_method("cancel") or _property(loot, "world") != world or _property(loot, "player") != actor: return {}
	if not _live_node(interactions) or not interactions.has_method("cancel_gesture") or not interactions.has_method("clear_selection") or _property(interactions, "world") != world: return {}
	return {"actor": actor, "controller": controller, "coordinates": coordinates, "settings": settings, "definition": definition, "native_land": native_land, "policy": policy, "source_bounds": source_bounds, "provider": provider, "renderer": renderer, "physics": physics, "loot": loot, "interactions": interactions}

static func _movement_problem(world: Node, actor: Node2D, controller: RefCounted) -> String:
	var hp: Variant = _property(world, "hp")
	var motion: Variant = _property(actor, "motion")
	var charge: Variant = _property(world, "charge_skill")
	if not (hp is int or hp is float) or not is_finite(float(hp)) or hp <= 0 or not motion is Object or not is_instance_valid(motion) or _property(motion, "dead") != false:
		return "현재 생존 상태에서는 지도 목적지로 걸어갈 수 없습니다."
	for key: String in ["movement_locked", "auto_enabled", "source_523_movement_blocked"]:
		if _property(actor, key) != false: return "현재 이동 상태에서는 지도 목적지로 걸어갈 수 없습니다."
	for method: String in ["is_stunned", "is_held", "is_feared"]:
		if actor.call(method) != false: return "현재 상태 효과로 지도 목적지 보행을 시작할 수 없습니다."
	if not charge is Dictionary or not charge.is_empty() or _property(controller, "_source_travel_busy") != false or _property(controller, "saving_prior_snapshot") != false or _property(world, "auto_hunting_move_in_progress", false) != false:
		return "기존 이동 처리가 끝난 뒤 지도 목적지를 선택해 주세요."
	var recovery: Variant = _property(world, "death_recovery")
	if not recovery is Object or not is_instance_valid(recovery) or not recovery.has_method("blocked") or recovery.call("blocked") != false:
		return "기존 사망 복구 처리가 끝난 뒤 지도 목적지를 선택해 주세요."
	# The player's normal motion loop already honors this existing owner.
	var star: Variant = _property(world, "halphas_star")
	if star is Object and is_instance_valid(star):
		var combat: Variant = _property(star, "combat")
		if not combat is Object or not is_instance_valid(combat) or not combat.has_method("frozen"):
			return "기존 이동 상태 소유자를 확인할 수 없습니다."
		var star_charge: Variant = _property(combat, "charge")
		if combat.call("frozen", actor) != false or not star_charge is Dictionary or not star_charge.is_empty():
			return "기존 이동 제한이나 돌진 처리가 끝난 뒤 지도 목적지를 선택해 주세요."
	return ""

static func _failed_destination(world: Node, field: RefCounted, held_ticket: Dictionary, code: String, reason: String) -> Dictionary:
	if not _current(world, field, held_ticket): return _stale()
	var context: Dictionary = _context(world, field)
	var problem: String = _movement_problem(world, context.actor, context.controller)
	if not problem.is_empty(): return _reject("actor_state_blocked", problem)
	_clear_intent_owners(world, context)
	context.actor.call("clear_click_path")
	context.actor.set("velocity", Vector2.ZERO)
	var result: Dictionary = _reject(code, reason)
	result["route_cancelled"] = true
	result["state_preserved"] = false
	return result

static func _clear_intent_owners(world: Node, context: Dictionary) -> void:
	context.loot.call("cancel")
	world.set("manual_route_pending_target", Vector2.INF)
	context.interactions.call("cancel_gesture")
	context.interactions.call("clear_selection")
	var hud: Variant = _property(world, "hud")
	if hud is Object and is_instance_valid(hud) and hud.has_method("clear_target"): hud.call("clear_target")

static func _current(world: Node, field: RefCounted, held_ticket: Dictionary) -> bool:
	if held_ticket.is_empty() or held_ticket.get("kind") != KIND: return false
	var current: Dictionary = ticket(world, field)
	return not current.is_empty() and current == held_ticket

static func _components(value: Array) -> bool:
	if value.size() != 2: return false
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component)) > 2147480000: return false
	return true

static func _sha(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

static func _live_node(value: Variant) -> bool:
	return value is Node and is_instance_valid(value) and not value.is_queued_for_deletion() and value.is_inside_tree()

static func _identity(value: Variant) -> int:
	return value.get_instance_id() if value is Object and is_instance_valid(value) else 0

static func _property(target: Object, property_name: String, fallback: Variant = null) -> Variant:
	if target == null or not is_instance_valid(target): return fallback
	for entry: Dictionary in target.get_property_list():
		if str(entry.get("name", "")) == property_name: return target.get(property_name)
	return fallback

static func _stale() -> Dictionary:
	var result: Dictionary = _reject("stale_identity", "지도·원문 정의·캐릭터 위치 또는 기존 이동 의도가 바뀌었습니다. 지도를 새로 열어 주세요.")
	result["stale"] = true
	result["refresh_required"] = true
	return result

static func _reject(code: String, reason: String) -> Dictionary:
	return {"ok": false, "requested": false, "stale": false, "route_cancelled": false, "state_preserved": true, "code": code, "reason": reason}

