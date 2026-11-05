extends SceneTree
const NAV = preload("res://scripts/maps/host_portal_navigation.gd")
var failures: Array[String] = []
var checks: int = 0

class NativeRules extends RefCounted:
	static func canonical(mid: String) -> String: return "aden_world" if mid == "old_alias" else mid
class Actor extends Node2D:
	var auto_enabled: bool = false
	var movement_locked: bool = false
	var stun: bool = false
	var held: bool = false
	var feared: bool = false
	var click_path := PackedVector2Array([Vector2(8,9)])
	func is_stunned() -> bool: return stun
	func is_held() -> bool: return held
	func is_feared() -> bool: return feared
	func set_manual_click_path(path: PackedVector2Array, _target: Vector2) -> void: click_path = path
class Field extends RefCounted:
	var data: Dictionary = {"layout_revision": 1, "portal": [{"id": "known", "name": "existing", "position": [100,0], "radius": 20, "target_map": "aden_world"}]}
	var clear: bool = true
	func point_clear(_point: Vector2, _radius: float) -> bool: return clear
	func line_clear(_from: Vector2, _to: Vector2) -> bool: return clear
class Pickup extends RefCounted:
	var cancelled: int = 0
	func cancel() -> void: cancelled += 1
class Driver extends Node:
	const NATIVE_PNG = NativeRules
	var active_map_id: String = "aden_world"
	var field_map: RefCounted = Field.new()
	var player: Actor = Actor.new()
	var maps_by_id: Dictionary = {"aden_world": {}}
	var hp: int = 100
	var charge_skill: Dictionary = {}
	var manual_route_pending_target := Vector2(99,98)
	var loot_pickup: RefCounted = Pickup.new()
	var path := PackedVector2Array([Vector2(20,0), Vector2(100,0)])
	func find_world_path(_from: Vector2, _to: Vector2) -> PackedVector2Array: return path

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("HOST_PORTAL_FAIL: ", label)
func preserved(world: Driver, receipt: Dictionary, label: String) -> void:
	var original: PackedVector2Array = world.player.click_path.duplicate()
	var pending: Vector2 = world.manual_route_pending_target
	check(not NAV.walk_to(world, receipt).ok, label)
	check(world.player.click_path == original and world.manual_route_pending_target == pending and world.loot_pickup.cancelled == 0 and world.player.position == Vector2.ZERO, label + " preserves movement/pickup/position")
func _initialize() -> void:
	var world := Driver.new()
	root.add_child(world); world.add_child(world.player)
	var receipt: Dictionary = NAV.capture(world, world.field_map.data.portal[0])
	for state: String in ["auto_enabled", "movement_locked", "stun", "held", "feared"]:
		world.player.set(state, true); preserved(world, receipt, state); world.player.set(state, false)
	world.hp = 0; preserved(world, receipt, "dead"); world.hp = 100
	world.charge_skill = {"active": true}; preserved(world, receipt, "charging"); world.charge_skill = {}
	world.path = PackedVector2Array(); preserved(world, receipt, "unreachable")
	world.path = PackedVector2Array([Vector2(85,0)]); preserved(world, receipt, "stop tolerance would end on trigger boundary")
	world.path = PackedVector2Array([Vector2.INF]); preserved(world, receipt, "non-finite route")
	world.path = PackedVector2Array([Vector2(20,0),Vector2(100,0)])
	world.field_map.clear = false; preserved(world, receipt, "blocked route"); world.field_map.clear = true
	world.field_map.data.portal.append({"id": "other", "position": [50,0], "radius": 10, "target_map": "aden_world"})
	preserved(world, receipt, "stale trigger graph")
	receipt = NAV.capture(world, world.field_map.data.portal[0]); preserved(world, receipt, "other trigger intercepts segment")
	world.field_map.data.portal[1].position = [50,14]
	receipt = NAV.capture(world, world.field_map.data.portal[0]); preserved(world, receipt, "waypoint corridor grazes another trigger")
	world.field_map.data.portal.pop_back()
	world.field_map.data.portal.append(world.field_map.data.portal[0].duplicate(true))
	receipt = NAV.capture(world, world.field_map.data.portal[0]); preserved(world, receipt, "duplicate portal identity")
	world.field_map.data.portal.pop_back()
	world.field_map.data.portal[0].source_m_portal_id = 327
	receipt = NAV.capture(world, world.field_map.data.portal[0]); preserved(world, receipt, "unknown native M trigger cannot use host route")
	world.field_map.data.portal[0].erase("source_m_portal_id")
	world.field_map.data.portal[0].position = [true,0]
	receipt = NAV.capture(world, world.field_map.data.portal[0]); preserved(world, receipt, "invalid position")
	world.field_map.data.portal[0].position = [100,0]
	world.field_map.data.portal[0].target_map = "missing"
	receipt = NAV.capture(world, world.field_map.data.portal[0]); preserved(world, receipt, "unknown destination")
	world.field_map.data.portal[0].target_map = "old_alias"
	world.field_map.data.portal[0].target_position = [200,0]
	world.field_map.data.portal[0].target_layout_revision = 0
	receipt = NAV.capture(world, world.field_map.data.portal[0]); preserved(world, receipt, "stale same-map arrival layout")
	world.field_map.data.portal[0].target_layout_revision = 1
	world.field_map.data.portal[0].target_position = [INF,0]
	receipt = NAV.capture(world, world.field_map.data.portal[0]); preserved(world, receipt, "invalid same-map arrival")
	world.field_map.data.portal[0].target_position = [200,0]
	receipt = NAV.capture(world, world.field_map.data.portal[0])
	var result: Dictionary = NAV.walk_to(world, receipt)
	check(result.ok and world.player.click_path == world.path, "existing canonical host target installs normal movement path")
	check(world.player.position == Vector2.ZERO and world.manual_route_pending_target == Vector2.INF and world.loot_pickup.cancelled == 1, "success queues walking without teleport and clears old deferred route")
	world.queue_free()
	print("HOST_PORTAL_NAVIGATION_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
