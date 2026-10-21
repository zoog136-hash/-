extends SceneTree
## CODE equivalence only: exact reviewed polygon union, including bucket edges.
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=20261020
	for mid: String in REGISTRY.plan().maps:
		var spec: Dictionary=REGISTRY.plan().maps[mid]
		var field:=NativePngField.new();field.index_walk_polygons(spec.walk_polygons)
		var exact: Array[PackedVector2Array]=[]
		var probes: Array[Vector2]=[]
		var box:=Rect2(Vector2(spec.spawn[0],spec.spawn[1]),Vector2.ZERO)
		for raw: Array in spec.walk_polygons:
			var polygon:=PackedVector2Array()
			for raw_point: Array in raw:
				var point:=Vector2(raw_point[0],raw_point[1]);polygon.append(point);box=box.expand(point)
				for offset: Vector2 in [Vector2.ZERO,Vector2(.01,.01),Vector2(-.01,-.01)]: probes.append(point+offset)
			exact.append(polygon)
		for i: int in range(1000): probes.append(box.position+Vector2(rng.randf(),rng.randf())*box.size)
		for y: int in range(floori(box.position.y/512),ceili(box.end.y/512)+1):
			for x: int in range(floori(box.position.x/512),ceili(box.end.x/512)+1): probes.append(Vector2(x,y)*512)
		for point: Vector2 in probes:
			var expected: bool=false
			for polygon: PackedVector2Array in exact:
				if Geometry2D.is_point_in_polygon(point,polygon): expected=true;break
			checks+=1
			if field.inside_navigable_area(point)!=expected: failures.append(mid+" polygon union mismatch at "+str(point))
	print("NATIVE_POLYGON_INDEX_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"CODE_EQUIVALENCE_ONLY_NO_PNG_RUNTIME_CLAIM"}))
	quit(0 if failures.is_empty() else 1)
