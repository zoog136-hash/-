extends SceneTree
const GEOMETRY=preload("res://scripts/maps/map_region_geometry.gd")
const PNG=preload("res://scripts/maps/native_png_registry.gd")
const SPAWNS=preload("res://scripts/monsters/native_png_spawns.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=20261024
	var plan: Dictionary=PNG.plan()
	for mid: String in plan.maps:
		var spec: Dictionary=plan.maps[mid]
		var regions: Array=spec.get("regions",[]).duplicate(true)
		regions.append_array(SPAWNS.build(mid,spec,spec.get("portals",[])))
		for raw: Dictionary in regions:
			var prepared: Dictionary=GEOMETRY.prepare(raw)
			var probes: Array[Vector2]=[]
			var polygons: Array=raw.get("polygons",[raw.polygon] if raw.has("polygon") else [])
			var box:=Rect2(Vector2.ZERO,Vector2.ONE)
			var first: bool=true
			for polygon: Array in polygons:
				for index: int in range(polygon.size()):
					var point:=Vector2(polygon[index][0],polygon[index][1])
					if first:box=Rect2(point,Vector2.ZERO);first=false
					box=box.expand(point)
					for offset: Vector2 in [Vector2.ZERO,Vector2(.01,.01),Vector2(-.01,-.01)]:probes.append(point+offset)
					var other: Array=polygon[(index+1)%polygon.size()]
					probes.append(point.lerp(Vector2(other[0],other[1]),.5))
			for i: int in range(100):probes.append(box.grow(2).position+Vector2(rng.randf(),rng.randf())*box.grow(2).size)
			for point: Vector2 in probes:
				checks+=1
				if GEOMETRY.contains(raw,point)!=GEOMETRY.contains(prepared,point):failures.append(mid+" "+str(raw.get("id",""))+" "+str(point))
	print("PREPARED_REGION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
