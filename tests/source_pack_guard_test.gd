extends SceneTree
const TRAVEL=preload("res://scripts/maps/source_travel.gd")
var failures: Array[String]=[]
func _initialize() -> void:
	var path: String="user://broken-source-pack.json"
	for data: String in ["{", "null", "[]", "{}", '{"schema":2,"maps":"invalid"}', '{"schema":2,"maps":[null,4,"x",{}]}']:
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(data);file.close()
		if not TRAVEL.catalog_entries(path).is_empty(): failures.append("Malformed catalog activated")
		if TRAVEL.load_field({"id":"l1_4","source_definition":path})!=null: failures.append("Malformed definition activated")
	if failures.is_empty(): print("SOURCE_PACK_GUARD_OK 12 malformed pack checks")
	else: printerr("SOURCE_PACK_GUARD_FAIL: ",failures)
	quit(0 if failures.is_empty() else 1)
