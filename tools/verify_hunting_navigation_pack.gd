extends SceneTree
## The new cache binaries must remain readable inside a native Godot PCK.
const FIELD = preload("res://scripts/maps/playable_field.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIELD.NAVIGATION_CATALOG_PATH))
	var pack := PCKPacker.new()
	var output: String="user://hunting-navigation.pck"
	if pack.pck_start(output)!=OK or pack.add_file(FIELD.NAVIGATION_CATALOG_PATH,FIELD.NAVIGATION_CATALOG_PATH)!=OK:
		push_error("HUNTING_NAV_PACK_FAILED start/catalog")
		quit(1)
		return
	for entry: Dictionary in catalog.values():
		if pack.add_file(str(entry.baked_cache_path),str(entry.baked_cache_path))!=OK:
			push_error("HUNTING_NAV_PACK_FAILED cache")
			quit(1)
			return
	if pack.flush()!=OK or not ProjectSettings.load_resource_pack(output,true):
		push_error("HUNTING_NAV_PACK_FAILED mount")
		quit(1)
		return
	FIELD.navigation_snapshots.clear()
	FIELD.navigation_order.clear()
	FIELD.navigation_files.clear()
	var checks: int=0
	for id: String in catalog:
		var entry: Dictionary=catalog[id]
		if FileAccess.get_sha256(str(entry.baked_cache_path))!=str(entry.baked_sha256):
			push_error("HUNTING_NAV_PACK_FAILED SHA "+id)
			quit(1)
			return
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(entry.source_path)))
		var field := FIELD.new()
		field.configure(CATALOG.apply_map(data))
		if not field.navigation_cache_hit or not field.walkable(Vector2(data.spawn_position[0],data.spawn_position[1])):
			push_error("HUNTING_NAV_PACK_FAILED read "+id)
			quit(1)
			return
		checks+=1
	print("HUNTING_NAV_PACK_OK ",checks," packed maps")
	quit(0)
