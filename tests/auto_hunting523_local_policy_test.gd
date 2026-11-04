extends SceneTree
## Synthetic geometry verifies the local policy, not original M passability.
const POLICY = preload("res://scripts/auto_hunting/local_movement.gd")
const COORDINATES = preload("res://scripts/maps/source_coordinates.gd")
class TestField extends RefCounted:
	var coordinates = COORDINATES.new()
	func world_to_cell(point: Vector2) -> Vector2i: return coordinates.world_to_cell(point)
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("AUTO_HUNT_LOCAL_FAIL: ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var field := TestField.new()
	check(field.coordinates.configure([10,20],[100,100]), "synthetic coordinate fixture configured")
	var territory := {"StartX":11,"StartY":21,"EndX":12,"EndY":22}
	var inclusive: Rect2i = POLICY.territory_bounds(territory, true)
	var exclusive: Rect2i = POLICY.territory_bounds(territory, false)
	check(inclusive.has_point(Vector2i(12,22)) and not exclusive.has_point(Vector2i(12,22)), "endpoint interpretation explicit")
	check(inclusive.size == Vector2i(2,2) and exclusive.size == Vector2i.ONE, "source endpoints never normalized in place")
	for order: String in ["center_first", "coordinate_order"]:
		var result: Dictionary = POLICY.find_cell(field,inclusive,order,func(p:Vector2)->bool: return POLICY.source_cell(field,p)==Vector2i(12,22))
		check(result.ok and result.source_cell==Vector2i(12,22) and result.tested==4, order+" reaches safe boundary cell")
		check(result.destination==field.coordinates.to_world(Vector2(12,22)), "actor foot uses existing cell center")
		var blocked: Dictionary = POLICY.find_cell(field,exclusive,order,func(_p:Vector2)->bool: return false)
		check(blocked.code=="NO_SAFE_CELL", "no escape outside half-open region")
		var limited: Dictionary = POLICY.find_cell(field,Rect2i(10,20,100,100),order,func(_p:Vector2)->bool: return false)
		check(limited.code=="SEARCH_LIMIT", "bounded candidate work")
	var outside: Dictionary = POLICY.find_cell(field,Rect2i(200,200,2,2),"center_first",func(_p:Vector2)->bool:return true)
	check(outside.code=="OUTSIDE_FIELD", "region outside supplied field rejected")
	var clipped: Dictionary = POLICY.find_cell(field,Rect2i(8,18,4,4),"coordinate_order",func(_p:Vector2)->bool:return true)
	check(clipped.ok and clipped.source_cell==Vector2i(10,20), "intersection never selects unsupplied cell")
	check(territory=={"StartX":11,"StartY":21,"EndX":12,"EndY":22}, "original rectangle preserved")
	check(POLICY.territory_bounds({"StartX":1,"StartY":1,"EndX":1,"EndY":1},false).size==Vector2i.ZERO,"empty exclusive rectangle fails closed")
	var policy = POLICY.new()
	policy.settings_path="user://local-policy-unit.json"
	check(not policy.get_settings().enabled, "new user keeps movement disabled until own-policy opt in")
	var value := {"enabled":true,"end_inclusive":false,"search_order":"coordinate_order"}
	check(policy.update_settings(value).ok, "policy settings saved atomically")
	var reopened=POLICY.new(); reopened.settings_path=policy.settings_path
	check(reopened.get_settings()==value,"settings survive new instance")
	var sha: String=FileAccess.get_sha256(policy.settings_path)
	check(not policy.update_settings({"enabled":true}).ok and FileAccess.get_sha256(policy.settings_path)==sha, "invalid settings preserve disk bytes")
	policy.settings_path="user://absent-policy-directory/config.json"
	check(not policy.update_settings({"enabled":false,"end_inclusive":true,"search_order":"center_first"}).ok and policy.get_settings()==value,"failed config write preserves active options")
	var damaged:=FileAccess.open("user://local-policy-corrupt.json",FileAccess.WRITE);damaged.store_string("{");damaged.close()
	var corrupt=POLICY.new();corrupt.settings_path="user://local-policy-corrupt.json"
	check(not corrupt.get_settings().enabled and not corrupt.problem.is_empty(),"corrupt settings safely disable without parse errors")
	print("AUTO_HUNT_LOCAL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_geometry":true}))
	quit(0 if failures.is_empty() else 1)
