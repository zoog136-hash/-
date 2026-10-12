extends SceneTree
const TRAVEL = preload("res://scripts/maps/source_travel.gd")
var failures: Array[String]=[]

func _initialize() -> void:
	if not FileAccess.file_exists("res://data/original_maps/catalog.json"):
		print("ORIGINAL_MAP_CATALOG_SKIP: private source pack not installed"); quit(0); return
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_maps/catalog.json"))
	var enabled: int=0
	var preserved: int=0
	for row: Dictionary in catalog.maps:
		preserved+=1
		var field=TRAVEL.load_field(row)
		if not bool(row.playable):
			if field!=null: failures.append("Unverified/empty map activated "+str(row.id)); field.close()
			continue
		if field==null: failures.append("Cannot load delivered map "+str(row.id)); continue
		enabled+=1
		var source:=Vector2(float(field.definition.spawn_source[0]),float(field.definition.spawn_source[1]))
		var pixel: Vector2=field.coordinates.to_world(source)
		if not field.walkable(pixel): failures.append("Invalid spawn "+str(row.id))
		if field.cell_to_world(field.world_to_cell(pixel)).distance_to(pixel)>0.01: failures.append("Origin mismatch "+str(row.id))
		if field.nav_cache.size()>field.CACHE_LIMIT: failures.append("Cache bound "+str(row.id))
		field.close()
	var recovered: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/l1j/recovered_maps/source_maps.json"))
	if preserved!=recovered.maps.size() or enabled!=998: failures.append("Unexpected preserved/activated counts")
	print("ORIGINAL_MAP_CATALOG_RESULT preserved=",preserved," loaded_with_valid_spawn=",enabled," failures=",failures)
	if failures.is_empty(): print("ORIGINAL_MAP_CATALOG_OK")
	else: printerr("ORIGINAL_MAP_CATALOG_FAIL: ",failures)
	quit(0 if failures.is_empty() else 1)
