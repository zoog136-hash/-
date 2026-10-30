extends SceneTree
const PNG=preload("res://scripts/maps/native_png_registry.gd")
class ScalarNative extends NativePngField:
	# Independent pre-optimization full-canvas raster algorithm.
	func _rasterize_navigable_floor() -> void:
		for y: int in range(height):
			for x: int in range(width):
				var cell:=Vector2i(x,y)
				if not inside_navigable_area(cell_to_world(cell)):astar.set_point_solid(cell)
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("NATIVE_RASTER_FAIL ",label)
func run() -> void:
	var plan: Dictionary=PNG.plan()
	var compared_cells: int=0
	for mid: String in ["aden_world","faith_01","faith_03","faith_04","escaros_world"]:
		var actual: NativePngField=PNG.load_field(mid)
		check(actual!=null,mid+" verified pack loads")
		if actual==null:continue
		var scalar:=ScalarNative.new();scalar.configure_png(mid,plan,actual.png_manifest,actual.png_root)
		var a: Dictionary=actual.navigation_snapshot();var b: Dictionary=scalar.navigation_snapshot()
		compared_cells+=actual.width*actual.height
		check(a.solid_runs==b.solid_runs,mid+" every solid/walkable cell identical")
		check(a.reachable==b.reachable,mid+" full reachability bytes identical")
		check(a.spawn_cells==b.spawn_cells,mid+" full spawn candidates and order identical")
		check(not PlayableField.navigation_snapshots.has(actual.geometry_signature()),mid+" disabled native cache retains no unused snapshot")
	print("NATIVE_RASTER_RESULT ",JSON.stringify({"checks":checks,"compared_cells":compared_cells,"failures":failures}));quit(0 if failures.is_empty() else 1)
