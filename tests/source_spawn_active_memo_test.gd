extends SceneTree
## source_field.source_spawn_active(): the player's source point is kept while
## the position and coordinate object are the same; every answer equals the
## direct computation, also after the position or the coordinates change.
const FIELD = preload("res://scripts/maps/source_field.gd")
const COORDINATES = preload("res://scripts/maps/source_coordinates.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SOURCE_SPAWN_ACTIVE_MEMO_FAIL: ", label)

func _direct(field: Object, region: Dictionary, position: Vector2) -> bool:
	var box: Rect2i = region.source_rect
	return Rect2(Vector2(box.position), Vector2(box.size)).grow(40).has_point(field.coordinates.to_source(position))

func _initialize() -> void:
	var field = FIELD.new()
	check(field.coordinates.configure([32000, 32000], [400, 400]), "test coordinates configure")
	var regions: Array = []
	for i: int in range(12):
		regions.append({"source_rect": Rect2i(32000 + i * 30, 32000 + (i % 4) * 50, 40, 60)})
	var positions: Array[Vector2] = [Vector2(0, 4800), Vector2(300, 4700), Vector2(300, 4700), Vector2(-900, 5200), Vector2(2400, 3000)]
	var same: bool = true
	for position: Vector2 in positions:
		for region: Dictionary in regions:
			if field.source_spawn_active(region, position) != _direct(field, region, position): same = false
	check(same, "every answer equals the direct source-point test")
	var active_before: int = 0
	for region: Dictionary in regions:
		if field.source_spawn_active(region, Vector2(0, 4800)): active_before += 1
	check(field._spawn_source_input == Vector2(0, 4800), "the last position's source point is kept")
	var replaced = COORDINATES.new()
	replaced.configure([31000, 31000], [400, 400])
	field.coordinates = replaced
	var after_replace: bool = true
	for region: Dictionary in regions:
		if field.source_spawn_active(region, Vector2(0, 4800)) != _direct(field, region, Vector2(0, 4800)): after_replace = false
	check(after_replace, "a replaced coordinate object is used at once")
	var source: String = FileAccess.get_file_as_string("res://scripts/maps/source_field.gd")
	var configure_at: int = source.find("func configure_source(")
	check(configure_at >= 0 and source.find("_spawn_source_input = Vector2.INF", configure_at) < source.find("coordinates.configure(value.origin", configure_at), "configure_source clears the kept point before configuring")
	if field is Node: field.free()
	print("SOURCE_SPAWN_ACTIVE_MEMO_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "active_regions": active_before}))
	quit(0 if failures.is_empty() else 1)
