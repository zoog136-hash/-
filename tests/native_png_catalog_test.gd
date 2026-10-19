extends SceneTree
const REGISTRY = preload("res://scripts/maps/native_png_registry.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("NATIVE_PNG_CATALOG_FAIL: "+label)
func _initialize() -> void:
	var plan: Dictionary=REGISTRY.plan()
	check(plan.maps.size()==6,"three Albino, one continuous Escaros and two temples")
	check(plan.maps.balrog_temple.name=="발록의 시전","user supplied 99111 name retained exactly")
	check(plan.maps.yahee_temple.name=="야히의신전","user supplied 99112 name retained exactly")
	for source: Dictionary in plan.sources.values():
		check(source.server_map_id==null and source.collision_data_id==null,"PNG number never becomes server/collision ID")
		check(str(source.sha256).length()==64 and source.decoded,"original byte provenance recorded")
	var baseline: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps_v18.json"))
	var ids: Array=baseline.map(func(row: Dictionary) -> String: return str(row.id))
	check(ids.size()==25 and ids.has("albino_04"),"all 25 original persistent IDs retained")
	for prefix: String in ["albino_","escaros_"]:
		for floor: int in range(1,5 if prefix=="albino_" else 6):
			check(ids.has(prefix+"%02d"%floor),"legacy ID remains loadable: "+prefix+str(floor))
	check(REGISTRY.catalog_entries().size()==(3 if REGISTRY.enabled() else 0),"native catalog is isolated until full terrain/spawn review")
	print("NATIVE_PNG_CATALOG_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"CODE_REGRESSION_NOT_PNG_RUNTIME"}))
	quit(0 if failures.is_empty() else 1)
