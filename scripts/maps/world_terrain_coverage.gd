extends RefCounted
## Whole-map, TWILIGHT-authored terrain geometry. Not original art restoration.
## Two triangulated ground layers, each with smooth world-coordinate biome weights.
## Static meshes do not reroll on prop chunk unloads and have no collision.
const CELL_SIZE: float = 512.0

static func material_pair(family: String) -> Vector2i:
	match family:
		"oman", "domination": return Vector2i(1, 3)
		"escaros": return Vector2i(2, 1)
		"albino": return Vector2i(2, 3)
		"faith": return Vector2i(1, 3)
		_: return Vector2i(3, 1)

static func build(bounds: Rect2, map_id: String, family: String, materials: Callable) -> Node2D:
	var root := Node2D.new()
	root.name = "TerrainCoverage"
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return root
	var regional := FastNoiseLite.new()
	regional.seed = absi(map_id.hash() % 2147483646) + 1
	regional.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	regional.frequency = 0.00054
	regional.fractal_type = FastNoiseLite.FRACTAL_FBM
	regional.fractal_octaves = 3
	var detail := FastNoiseLite.new()
	detail.seed = (regional.seed + 7919) % 2147483647
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = 0.0018
	var pair: Vector2i = material_pair(family)
	var cols: int = ceili(bounds.size.x / CELL_SIZE)
	var rows: int = ceili(bounds.size.y / CELL_SIZE)
	for layer: int in range(2):
		var vertices := PackedVector2Array()
		var colors := PackedColorArray()
		for y: int in range(rows):
			for x: int in range(cols):
				var x0: float = bounds.position.x + float(x) * CELL_SIZE
				var y0: float = bounds.position.y + float(y) * CELL_SIZE
				var x1: float = minf(bounds.end.x, x0 + CELL_SIZE)
				var y1: float = minf(bounds.end.y, y0 + CELL_SIZE)
				var a := Vector2(x0, y0)
				var b := Vector2(x1, y0)
				var c := Vector2(x1, y1)
				var d := Vector2(x0, y1)
				# Shared corner positions and shared noise eliminate cell seams.
				for p: Vector2 in [a, b, c, a, c, d]:
					vertices.append(p)
					var n: float = regional.get_noise_2d(p.x, p.y)
					n += detail.get_noise_2d(p.x, p.y) * 0.27
					var alpha: float = 0.0
					if layer == 0:
						alpha = smoothstep(-0.30, 0.42, n) * 0.80
					else:
						alpha = (1.0 - smoothstep(-0.40, 0.35, n)) * 0.65
					colors.append(Color(1.0, 1.0, 1.0, alpha))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var drawing := MeshInstance2D.new()
		drawing.name = "Biome_%d" % layer
		drawing.mesh = mesh
		drawing.material = materials.call(pair.x if layer == 0 else pair.y)
		drawing.set_meta("world_coverage", true)
		drawing.set_meta("map_id", map_id)
		root.add_child(drawing)
	return root
