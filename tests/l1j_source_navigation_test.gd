extends SceneTree
const NAV = preload("res://addons/twilight_l1j/twilight_source_navigation.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("L1J_SOURCE_NAV_FAIL: ", message)

func _run() -> void:
	var navigation: TwilightL1JSourceNavigation = NAV.new()
	check(not navigation.can_step(Vector2i.ZERO,2), "unconfigured source cannot affect movement")
	check(not navigation.configure(99998,Vector2i(3,3),Vector2i.ZERO,Transform2D.IDENTITY), "missing data rejected")
	var file := FileAccess.open("user://nav-reference.bin",FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0,0,0,0,3,0,0,0,0]))
	file.close()
	# Use an explicit in-memory synthetic attribute layer; no real source paths overwritten.
	navigation.attributes._raw = PackedByteArray([0,0,0,0,3,0,0,0,0])
	navigation.attributes._dimensions = Vector2i(3,3)
	navigation.attributes._source_id = 99998
	navigation.coordinates.configure(Vector2i(3,3),Vector2i(32704,32704),Transform2D(Vector2(64,0),Vector2(0,64),-Vector2(32704,32704)*64))
	navigation.dimensions = Vector2i(3,3)
	navigation.loaded = true
	check(navigation.can_step(Vector2i(1,1),0), "north edge belongs to source tile bit 2")
	check(navigation.can_step(Vector2i(1,1),2), "east edge belongs to source tile bit 1")
	check(not navigation.can_step(Vector2i(1,1),4), "south edge belongs to destination bit 2")
	check(not navigation.can_step(Vector2i(1,1),6), "west edge belongs to destination bit 1")
	check(not navigation.can_step(Vector2i(1,1),1), "diagonal blocked when both corner routes are closed")
	check(not navigation.can_step(Vector2i(-1,1),2), "outside source bounds rejected")
	check(not navigation.can_step(Vector2i(1,1),8), "invalid heading rejected")
	check(navigation.find_path(Vector2i(1,1),Vector2i(2,1)).size() == 2, "source edge path")
	check(navigation.find_path(Vector2i(1,1),Vector2i(0,2)).is_empty(), "unreachable source cell")
	check(navigation.find_path(Vector2i(1,1),Vector2i(2,1),1).is_empty(), "search memory budget enforced")
	var world: Vector2 = navigation.coordinates.cell_to_world(Vector2i(1,1))
	check(world == Vector2(96,96) and navigation.coordinates.world_to_cell(world) == Vector2i(1,1), "absolute L1J coordinates align with world pixel origin")
	check(not navigation.configure(99998,Vector2i(3,3),Vector2i.ZERO,Transform2D(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)), "singular projection rejected")
	check(not navigation.loaded and not navigation.can_step(Vector2i(1,1),2), "failed reconfiguration clears previous movement layer")
	print("L1J_SOURCE_NAV_OK " if failures.is_empty() else "L1J_SOURCE_NAV_FAIL ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
