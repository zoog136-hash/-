extends SceneTree
## Export effective gameplay records without running a second game or altering DBs.
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
func _initialize() -> void:
	var result: Dictionary = {}
	var entries: Array = [{"path":"res://data/maps/aden_field.json"}]
	entries.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")))
	for entry: Dictionary in entries:
		var field: Dictionary = CATALOG.apply_map(JSON.parse_string(FileAccess.get_file_as_string(entry.path)))
		result[str(field.map_id)] = field
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty(): printerr("Supply an output JSON path after --"); quit(2); return
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print("EFFECTIVE_MAP_LAYOUTS_EXPORTED ",result.size())
	quit()
