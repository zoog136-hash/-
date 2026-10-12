extends SceneTree
## Build a verified, disposable navigation cache from the actual runtime inputs.
const FIELD = preload("res://scripts/maps/playable_field.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/maps/navigation"))
	var paths: Array[String] = ["res://data/maps/aden_field.json"]
	var catalog: Dictionary={}
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")):
		paths.append(str(entry.path))
	for path: String in paths:
		var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		definition.navigation["use_baked_cache"]=false
		var field := FIELD.new()
		var started: int = Time.get_ticks_msec()
		field.configure(CATALOG.apply_map(definition))
		var snapshot: Dictionary = field.navigation_snapshot()
		var packed: PackedByteArray = var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_GZIP)
		var output: String = "res://data/maps/navigation/"+str(definition.map_id)+".nav"
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_buffer(packed)
		file.close()
		catalog[str(definition.map_id)]={"baked_signature":snapshot.signature,"baked_cache_path":output,
			"baked_sha256":FileAccess.get_sha256(output),"source_path":path}
		print("NAV_BAKED ",definition.map_id," bytes=",packed.size()," ms=",Time.get_ticks_msec()-started)
	var index_file := FileAccess.open("res://data/maps/navigation/catalog.json",FileAccess.WRITE)
	index_file.store_string(JSON.stringify(catalog,"  ")+"\n")
	index_file.close()
	print("NAV_BAKE_OK ",paths.size())
	quit(0)
