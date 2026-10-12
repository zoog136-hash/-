extends RefCounted
## Visual road coverage over the existing map coordinates; never navigation.
## A single sampled coverage field per material prevents translucent overlaps
## at junctions, acute bends and closed loops. Uncovered cells remain empty.
const MAX_CELL: float = 32.0
const CORE_OPACITY: float = 0.94

static func build(roads: Array, bounds: Rect2, materials: Callable) -> Node2D:
	var root := Node2D.new()
	root.name = "RoadNetwork"
	if not bounds.has_area():
		return root
	var groups: Dictionary = {}
	for road: Dictionary in roads:
		var width: float = float(road.get("width", 0.0))
		var opacity: float = clampf(float(road.get("opacity", 1.0)), 0.0, 1.0)
		var points: Array = road.get("points", [])
		if width <= 0.0 or opacity <= 0.0 or points.size() < 2:
			continue
		var index: int = int(road.get("material", 1))
		if not groups.has(index):
			groups[index] = {"segments": [], "cell": MAX_CELL}
		var group: Dictionary = groups[index]
		group.cell = minf(float(group.cell), maxf(4.0, width * 0.25))
		var shoulder: float = minf(48.0, width * 0.24)
		for i: int in range(1, points.size()):
			var a := Vector2(float(points[i - 1][0]), float(points[i - 1][1]))
			var b := Vector2(float(points[i][0]), float(points[i][1]))
			if a.distance_squared_to(b) < 0.0001:
				continue
			group.segments.append({"a": a, "b": b, "half_width": width * 0.5,
				"shoulder": shoulder, "opacity": opacity * CORE_OPACITY})
	for index: int in groups:
		var group: Dictionary = groups[index]
		var mesh: ArrayMesh = _road_mesh(group.segments, bounds, float(group.cell))
		if mesh == null:
			continue
		var drawing := MeshInstance2D.new()
		drawing.name = "RoadMaterial_%d" % index
		drawing.mesh = mesh
		drawing.material = materials.call(index)
		drawing.set_meta("road_material", index)
		drawing.set_meta("cell_size", float(group.cell))
		root.add_child(drawing)
	return root

static func _road_mesh(segments: Array, bounds: Rect2, cell: float) -> ArrayMesh:
	# Index only cells near a segment. Whole-map grids would waste geometry and
	# fill rate on large empty regions, especially around long diagonal roads.
	var cells: Dictionary = {}
	var lower := Vector2i((bounds.position / cell).floor())
	var upper := Vector2i((bounds.end / cell).ceil()) - Vector2i.ONE
	for segment: Dictionary in segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var radius: float = float(segment.half_width) + float(segment.shoulder) * 1.15
		var lo := Vector2i(((a.min(b) - Vector2.ONE * radius) / cell).floor()).max(lower)
		var hi := Vector2i(((a.max(b) + Vector2.ONE * radius) / cell).floor()).min(upper)
		for y: int in range(lo.y, hi.y + 1):
			for x: int in range(lo.x, hi.x + 1):
				var key := Vector2i(x, y)
				var center: Vector2 = (Vector2(key) + Vector2.ONE * 0.5) * cell
				if center.distance_to(Geometry2D.get_closest_point_to_segment(center, a, b)) <= radius + cell * 0.708:
					cells[key] = true
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var vertex_ids: Dictionary = {}
	for key: Vector2i in cells:
		var quad := PackedInt32Array()
		var visible: bool = false
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
			var corner: Vector2i = key + offset
			if not vertex_ids.has(corner):
				var p: Vector2 = (Vector2(corner) * cell).clamp(bounds.position, bounds.end)
				var alpha: float = _coverage(p, segments)
				vertex_ids[corner] = vertices.size()
				vertices.append(p)
				colors.append(Color(1.0, 1.0, 1.0, alpha))
			var vertex: int = int(vertex_ids[corner])
			quad.append(vertex)
			visible = visible or colors[vertex].a > 0.0001
		if visible:
			indices.append_array(PackedInt32Array([quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]))
	if indices.is_empty():
		return null
	return _mesh(vertices, colors, indices)

static func _coverage(p: Vector2, segments: Array) -> float:
	# World-space wear is stable through chunk streaming and shared vertices.
	var wear: float = sin(p.x * 0.037 + sin(p.y * 0.021) * 1.7) * 0.065
	wear += sin(p.y * 0.053 + p.x * 0.017) * 0.045
	var alpha: float = 0.0
	for segment: Dictionary in segments:
		var half_width: float = segment.half_width
		var shoulder: float = segment.shoulder
		var distance: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, segment.a, segment.b))
		var coverage: float = 1.0 - smoothstep(half_width - shoulder * 0.45,
			half_width + shoulder, distance + wear * shoulder)
		alpha = maxf(alpha, coverage * float(segment.opacity))
	return alpha

static func plaza(box: Rect2, material: Material) -> MeshInstance2D:
	# Preserve the three authored courtyard footprints and their worn-edge shader.
	var drawing := MeshInstance2D.new()
	drawing.name = "WeatheredCourtyard"
	drawing.material = material
	if not box.has_area():
		return drawing
	var vertices := PackedVector2Array([box.get_center()])
	var colors := PackedColorArray([Color.WHITE])
	var indices := PackedInt32Array()
	for i: int in range(64):
		var angle: float = float(i) * TAU / 64.0
		vertices.append(box.get_center() + Vector2(cos(angle), sin(angle)) * box.size * 0.5 * 1.13)
		colors.append(Color.WHITE)
		indices.append_array(PackedInt32Array([0, i + 1, (i + 1) % 64 + 1]))
	drawing.mesh = _mesh(vertices, colors, indices)
	return drawing

static func _mesh(vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
