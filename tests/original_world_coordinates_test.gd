extends SceneTree

const COORD = preload("res://scripts/maps/source_coordinates.gd")
const FIELD = preload("res://scripts/maps/source_field.gd")
const DOORS = preload("res://scripts/maps/source_doors.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("ORIGINAL_COORD_FAIL: "+message)

func _initialize() -> void:
	var coord = COORD.new()
	coord.configure([32768,32768],[64,64])
	for x: float in [0.001,0.9995,1.0005,31.499,63.999]:
		for y: float in [0.001,1.0005,32.9995,63.999]:
			var source: Array = [32768.0+x,32768.0+y]
			var pixel: Vector2 = coord.components_to_world(source)
			var grid: Vector2 = coord.world_to_grid(pixel)
			check(grid.distance_to(Vector2(x,y))<0.00003,"fractional local grid precision")
			check(coord.world_to_cell(pixel)==Vector2i(floori(x),floori(y)),"cell side of boundary")
			check(coord.components_to_world(coord.source_components(pixel)).distance_to(pixel)<0.001,"save roundtrip")
	# Reproduce an edge crossing smaller than float32 precision at source 32768.
	var field = FIELD.new()
	field.coordinates=coord
	field.width=64; field.height=64
	field.chunk_table[Vector2i.ZERO]=[0,0,64,64]
	var raw := PackedByteArray(); raw.resize(64*64*2)
	# West movement is permitted within both cells; east across their edge is blocked.
	raw[64*64+1+64]=64; raw[64*64+2+64]=64
	field.nav_cache[Vector2i.ZERO]=raw
	var before: Vector2=coord.components_to_world([32769.9995,32769.5])
	var after: Vector2=coord.components_to_world([32770.0005,32769.5])
	check(not field.line_clear(before,after),"subpixel east edge cannot disappear at large origin")
	check(field.line_clear(after,before),"verified west edge remains usable")
	field.close()
	# Directional dynamic doors must block both ways until explicitly opened.
	var door = DOORS.new()
	door.configure([{"id":999,"direction":0,"locx":32770,"locy":32770,
		"left_edge_location":32770,"right_edge_location":32772}],Vector2i(32768,32768))
	check(door.blocked(Vector2i(2,2),Vector2i(2,3)),"closed door south")
	check(door.blocked(Vector2i(2,3),Vector2i(2,2)),"closed door north")
	door.set_open(999,true)
	check(not door.blocked(Vector2i(2,2),Vector2i(2,3)),"open door south")
	check(not door.blocked(Vector2i(2,3),Vector2i(2,2)),"open door north")
	print("ORIGINAL_COORDINATES_OK checks=",checks) if failures.is_empty() else printerr(failures)
	quit(0 if failures.is_empty() else 1)
