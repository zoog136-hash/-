extends SceneTree
## Compare the optimized short-move path with the previous exact foot samples.
## Synthetic geometry proves collision equivalence, not device FPS or map art.
const FIELD = preload("res://scripts/maps/native_png_field.gd")
var checks: int = 0
var failures: Array[String] = []

class CountedField extends NativePngField:
	var raster_queries: int = 0
	func walkable(point: Vector2) -> bool:
		raster_queries += 1
		return super.walkable(point)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func previous_line_clear(field: NativePngField, from: Vector2, to: Vector2) -> bool:
	var steps: int = maxi(1, ceili(from.distance_to(to) / 2.0))
	for index: int in range(steps + 1):
		var point: Vector2 = from.lerp(to, float(index) / steps)
		if not field.walkable(point) or not field.point_clear(point, 4.0): return false
		for offset: Vector2 in FIELD.LANDING_BODY_OFFSETS:
			if not field.walkable(point + offset): return false
	return true

func _initialize() -> void:
	var field := CountedField.new()
	var polygon: Array = [[0,0],[1024,0],[1024,768],[640,768],[640,1024],[0,1024]]
	field.index_walk_polygons([polygon])
	field.configure({"map_id":"motion_cost_fixture", "bounds":[0,0,1024,1024],
		"navigation":{"cell_size":16,"clearance":4,"use_baked_cache":false},
		"spawn_position":[80,80], "navigable_polygons":[polygon], "monster_spawn":[],
		"collision":[{"shape":"rect","rect":[320,240,32,400]},
			{"shape":"circle","center":[740,340],"radius":45},
			{"shape":"polygon","points":[[140,480],[220,520],[180,600]]}]})
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	for index: int in range(2400):
		var from := Vector2(rng.randf_range(-8,1032), rng.randf_range(-8,1032))
		var distance: float = rng.randf_range(0,8) if index % 3 != 0 else rng.randf_range(20,180)
		var to: Vector2 = from + Vector2.from_angle(rng.randf_range(-PI,PI)) * distance
		check(field.line_clear(from,to) == previous_line_clear(field,from,to), "random segment %d" % index)
	# Include exact cell seams, body radius offsets, degenerate segments and
	# diagonals whose bounding box contains a blocker outside the actual line.
	for x: int in range(16,1024,16):
		for margin: float in [-4.001,-4.0,-3.999,0.0,3.999,4.0,4.001]:
			var from := Vector2(float(x)+margin, 240+margin)
			for delta: Vector2 in [Vector2.ZERO,Vector2(3,3),Vector2(-5,2)]:
				check(field.line_clear(from,from+delta) == previous_line_clear(field,from,from+delta), "cell seam %s %s" % [from,delta])
	var a := Vector2(80,80)
	var b := Vector2(83,82)
	field.raster_queries = 0
	check(previous_line_clear(field,a,b), "reference open movement")
	var before: int = field.raster_queries
	field.raster_queries = 0
	check(field.line_clear(a,b), "optimized open movement")
	check(field.raster_queries == 0 and before >= 18, "open short movement avoids repeated per-offset raster calls")
	var obstacle: Vector2i = field.world_to_cell(b)
	field.astar.set_point_solid(obstacle,true)
	check(not field.line_clear(a,b), "new solid cell is observed immediately")
	field.astar.set_point_solid(obstacle,false)
	check(field.line_clear(a,b), "reopened solid cell is observed immediately")
	var repetitions: int = 4000
	var started: int = Time.get_ticks_usec()
	for _index: int in range(repetitions): previous_line_clear(field,a,b)
	var previous_usec: int = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	for _index: int in range(repetitions): field.line_clear(a,b)
	var optimized_usec: int = Time.get_ticks_usec()-started
	print("NATIVE_PNG_MOTION_COST_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"short_move_reference_usec":previous_usec,"short_move_optimized_usec":optimized_usec,
		"repetitions":repetitions,"scope":"synthetic_collision_equivalence_not_device_fps"}))
	quit(0 if failures.is_empty() else 1)
