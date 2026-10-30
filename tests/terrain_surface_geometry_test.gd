extends SceneTree
const COVERAGE = preload("res://scripts/maps/world_terrain_coverage.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("TERRAIN_SURFACE_FAIL: "+label)

func material(_index: int) -> ShaderMaterial:
	return ShaderMaterial.new()

func _initialize() -> void:
	var paths: Array[String] = []
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")):
		paths.append(str(entry.path))
	for path: String in paths:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var a: Array = data.bounds
		var bounds := Rect2(a[0],a[1],a[2],a[3])
		var drawing: Node2D = COVERAGE.build(bounds,str(data.map_id),str(data.get("family","")),Callable(self,"material"))
		var repeat: Node2D = COVERAGE.build(bounds,str(data.map_id),str(data.get("family","")),Callable(self,"material"))
		check(drawing.get_child_count()==2,str(data.map_id)+" two material fields")
		var count: int = 0
		for layer: int in range(drawing.get_child_count()):
			var mesh: ArrayMesh = drawing.get_child(layer).mesh
			var arrays: Array = mesh.surface_get_arrays(0)
			var copy: Array = repeat.get_child(layer).mesh.surface_get_arrays(0)
			var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			check(vertices==copy[Mesh.ARRAY_VERTEX] and colors==copy[Mesh.ARRAY_COLOR],str(data.map_id)+" reload deterministic")
			var unique: Dictionary = {}
			var inside: bool = true
			for p: Vector2 in vertices:
				unique[p] = true
				inside = inside and p.x>=bounds.position.x and p.y>=bounds.position.y and p.x<=bounds.end.x and p.y<=bounds.end.y
			check(unique.size()==vertices.size(),str(data.map_id)+" shared vertices, no duplicate seams")
			check(inside,str(data.map_id)+" no geometry outside bounds")
			check(vertices.has(bounds.position) and vertices.has(bounds.end),str(data.map_id)+" includes map corners")
			var area: float = 0.0
			var valid: bool = indices.size()%3==0
			for index: int in indices: valid = valid and index>=0 and index<vertices.size()
			check(valid,str(data.map_id)+" valid indexed triangles")
			if valid:
				for i: int in range(0,indices.size(),3):
					var p: Vector2 = vertices[indices[i]]
					var q: Vector2 = vertices[indices[i+1]]
					var r: Vector2 = vertices[indices[i+2]]
					area += (q-p).cross(r-p)*0.5
			check(absf(area-bounds.get_area())<1.0,str(data.map_id)+" entire map area covered without flipped triangles")
			check(vertices.size()<indices.size()/2,str(data.map_id)+" compact shared mesh")
			count += vertices.size()
		print("TERRAIN_SURFACE_MAP ",data.map_id," vertices=",count)
		drawing.free()
		repeat.free()
	var empty: Node2D = COVERAGE.build(Rect2(),"empty","",Callable(self,"material"))
	check(empty.get_child_count()==0,"empty map has no mesh")
	empty.free()
	check(paths.size()==25,"all current maps enumerated")
	print("TERRAIN_SURFACE_OK " if failures.is_empty() else "TERRAIN_SURFACE_FAILED ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
