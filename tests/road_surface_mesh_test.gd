extends SceneTree
## Geometry acceptance: intersections, loop interiors, route coverage, bounds.
## Runs without imported art; the companion render test exercises the real game.
const ROADS = preload("res://scripts/maps/road_surface_mesh.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ROAD_MESH_FAIL: " + label)

func material(_index: int) -> Material:
	return CanvasItemMaterial.new()

func probe(drawing: MeshInstance2D) -> Dictionary:
	var arrays: Array = drawing.mesh.surface_get_arrays(0)
	var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var buckets: Dictionary = {}
	for i: int in range(0, indices.size(), 3):
		var a: Vector2 = points[indices[i]]
		var b: Vector2 = points[indices[i + 1]]
		var c: Vector2 = points[indices[i + 2]]
		var lo := Vector2i((a.min(b).min(c) / 64.0).floor())
		var hi := Vector2i((a.max(b).max(c) / 64.0).floor())
		for y: int in range(lo.y, hi.y + 1):
			for x: int in range(lo.x, hi.x + 1):
				var key := Vector2i(x, y)
				if not buckets.has(key): buckets[key] = []
				buckets[key].append(i)
	return {"points": points, "colors": colors, "indices": indices, "buckets": buckets}

func alpha_at(data: Dictionary, p: Vector2) -> float:
	var points: PackedVector2Array = data.points
	var colors: PackedColorArray = data.colors
	var indices: PackedInt32Array = data.indices
	var result: float = 0.0
	for i: int in data.buckets.get(Vector2i((p / 64.0).floor()), []):
		var a: Vector2 = points[indices[i]]
		var b: Vector2 = points[indices[i + 1]]
		var c: Vector2 = points[indices[i + 2]]
		var determinant: float = (b - a).cross(c - a)
		if absf(determinant) < 0.0001: continue
		var v: float = (p - a).cross(c - a) / determinant
		var w: float = (b - a).cross(p - a) / determinant
		if v < -0.00001 or w < -0.00001 or v + w > 1.00001: continue
		result = maxf(result, colors[indices[i]].a * (1.0 - v - w) + colors[indices[i + 1]].a * v + colors[indices[i + 2]].a * w)
	return result

func synthetic() -> void:
	var bounds := Rect2(-512, -512, 1024, 1024)
	var horizontal: Dictionary = {"width": 128, "opacity": 0.6, "points": [[-400, 0], [400, 0]]}
	var crossing: Array = [horizontal, {"width": 128, "opacity": 0.6, "points": [[0, -400], [0, 400]]}]
	var network: Node2D = ROADS.build(crossing, bounds, material)
	check(network.get_child_count() == 1, "junction shares one material draw")
	var data: Dictionary = probe(network.get_child(0))
	# ArrayMesh stores vertex colors at 8-bit precision on this renderer.
	check(absf(alpha_at(data, Vector2(0.7, 1.3)) - 0.564) <= 1.0 / 255.0, "intersection never darkens from alpha stacking")
	check(alpha_at(data, Vector2(250, 1.3)) > 0.55, "straight and intersection have same opacity")
	check(alpha_at(data, Vector2(430, 0)) > 0.5, "round road endpoint remains covered")
	check(alpha_at(data, Vector2(0, 220)) > 0.55, "connected branch remains covered")
	check(alpha_at(data, Vector2(220, 220)) == 0.0, "outside junction stays unpainted")
	var a0: float = alpha_at(data, Vector2(250, 48))
	var a1: float = alpha_at(data, Vector2(250, 72))
	var a2: float = alpha_at(data, Vector2(250, 104))
	check(a0 > a1 and a1 > a2 and a2 < 0.03, "shoulder fades from road to ground")
	var repeated: Node2D = ROADS.build(crossing + crossing, bounds, material)
	check(repeated.get_child(0).mesh.surface_get_arrays(0) == network.get_child(0).mesh.surface_get_arrays(0), "duplicate routes do not repaint the surface")
	network.free()
	repeated.free()
	var ring: Node2D = ROADS.build([{"width": 96, "points": [[-300, -300], [300, -300], [300, 300], [-300, 300], [-300, -300]]}], bounds, material)
	data = probe(ring.get_child(0))
	check(alpha_at(data, Vector2.ZERO) == 0.0, "loop interior is a real hole")
	check(alpha_at(data, Vector2(300, 300)) > 0.9, "loop corner stays connected")
	ring.free()
	var sharp: Node2D = ROADS.build([{"width": 80, "points": [[-400, 0], [0, 0], [0, 0], [-380, 30]]}], bounds, material)
	data = probe(sharp.get_child(0))
	check(alpha_at(data, Vector2.ZERO) > 0.9, "acute reversal and duplicate point have no gap")
	check(alpha_at(data, Vector2(180, 0)) == 0.0, "acute reversal has no miter spike")
	sharp.free()
	var empty: Node2D = ROADS.build([{"width": 80, "points": [[1, 1], [1, 1]]}, {"width": 0, "points": [[0, 0], [10, 10]]}], bounds, material)
	check(empty.get_child_count() == 0, "degenerate roads produce no invalid triangles")
	empty.free()
	var narrow: Node2D = ROADS.build([{"width": 22, "opacity": 0.8, "points": [[0, 0], [400, 0]]}], bounds, material)
	data = probe(narrow.get_child(0))
	check(alpha_at(data, Vector2(213, 0)) > 0.74, "narrow farming furrow retains continuous center")
	check(alpha_at(data, Vector2(213, 40)) == 0.0, "narrow furrow does not fill neighboring rows")
	narrow.free()
	var plaza: MeshInstance2D = ROADS.plaza(Rect2(820, 3480, 1380, 1280), material(2))
	data = probe(plaza)
	check(alpha_at(data, Vector2(1510, 4120)) > 0.99, "plaza center has no fan hole")
	check(alpha_at(data, Vector2(800, 3420)) == 0.0, "plaza retains elliptical footprint")
	plaza.free()

func all_maps() -> void:
	var count: int = 0
	var route_count: int = 0
	for filename: String in DirAccess.get_files_at("res://data/maps"):
		if not filename.ends_with(".json"): continue
		var definition: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + filename))
		if not definition is Dictionary or not definition.has("map_id"): continue
		# Only authored road geometry maps carry the bounds/roads schema.
		if not definition.has("bounds") or not definition.has("roads"): continue
		var before: String = JSON.stringify(definition)
		var b: Array = definition.bounds
		var bounds := Rect2(b[0], b[1], b[2], b[3])
		var network: Node2D = ROADS.build(definition.roads, bounds, material)
		var id: String = definition.map_id
		check(network.get_child_count() > 0 if not definition.roads.is_empty() else network.get_child_count()==0,id + " authored road coverage; open floors require no invented roads")
		var probes: Dictionary = {}
		var total_vertices: int = 0
		for child: MeshInstance2D in network.get_children():
			var data: Dictionary = probe(child)
			probes[int(child.get_meta("road_material"))] = data
			var valid: bool = true
			for p: Vector2 in data.points:
				valid = valid and p.is_finite() and bounds.grow(0.01).has_point(p)
			check(valid, id + " finite vertices clipped to map bounds")
			check(data.points.size() == data.colors.size(), id + " every vertex has coverage")
			total_vertices += data.points.size()
		for road: Dictionary in definition.roads:
			var data: Dictionary = probes[int(road.get("material", 1))]
			var expected: float = float(road.get("opacity", 1.0)) * 0.94 * 0.9
			var route_ok: bool = true
			for i: int in range(1, road.points.size()):
				var a := Vector2(road.points[i - 1][0], road.points[i - 1][1])
				var z := Vector2(road.points[i][0], road.points[i][1])
				for t: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
					var p: Vector2 = a.lerp(z, t)
					if bounds.has_point(p): route_ok = route_ok and alpha_at(data, p) >= expected
			check(route_ok, id + "/" + str(road.id) + " entire centerline sampled")
			route_count += 1
		check(JSON.stringify(definition) == before, id + " source map data preserved")
		check(total_vertices < 80000, id + " sparse road geometry budget")
		print("ROAD_MESH_MAP ", id, " vertices=", total_vertices)
		network.free()
		count += 1
	check(count == 25, "all 25 TWILIGHT maps tested")
	print("ROAD_MESH_ROUTES ", route_count)

func run() -> void:
	synthetic()
	all_maps()
	print("ROAD_MESH_OK " if failures.is_empty() else "ROAD_MESH_FAILED ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
