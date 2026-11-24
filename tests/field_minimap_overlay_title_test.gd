extends SceneTree
const MINIMAP = preload("res://scripts/maps/field_minimap.gd")
var failures: Array[String] = []
var checks := 0

class NativeField extends OriginalPlayableField:
	var calls: int = 0
	func region_at(_p: Vector2) -> Dictionary:
		calls += 1
		return {"name":"discarded dynamic area","type":"safe"}

class LegacyField extends PlayableField:
	var calls: int = 0
	func region_at(p: Vector2) -> Dictionary:
		calls += 1
		return {"name":"테스트 구역","type":"safe" if p.x<0 else "combat"}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var map := MINIMAP.new()
	var native := NativeField.new()
	native.data = {"short_name":"몽환의 섬"}
	map.field = native
	check(map._overlay_title(Vector2.ZERO)=="몽환의 섬","original field still shows its identical short name")
	check(map._overlay_title(Vector2(40,30))=="몽환의 섬" and native.calls==0,"movement does not trigger discarded original region query")
	var legacy := LegacyField.new()
	map.field = legacy
	check(map._overlay_title(Vector2(-1,0))=="테스트 구역 · 안전","legacy safe suffix unchanged")
	check(map._overlay_title(Vector2(1,0))=="테스트 구역 · 사냥터" and legacy.calls==2,"legacy area still queries the current position")
	map.field = null
	check(map._overlay_title(Vector2.ZERO)=="지역 지도","missing field title unchanged")
	map.free()
	print("FIELD_MINIMAP_OVERLAY_TITLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if not failures.is_empty() else 0)
