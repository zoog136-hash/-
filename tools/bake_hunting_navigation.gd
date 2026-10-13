extends SceneTree
## Build a verified, disposable navigation cache from the actual runtime inputs.
const FIELD = preload("res://scripts/maps/playable_field.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error("NAV_BAKE_FAILED: " + message)
	quit(1)

func run() -> void:
	var directory: String = ProjectSettings.globalize_path("res://data/maps/navigation")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		fail("cannot create navigation directory")
		return
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json"))
	if not index is Array or index.size() != 24:
		fail("expected 24 regional maps plus Aden")
		return
	var paths: Array[String] = ["res://data/maps/aden_field.json"]
	var catalog: Dictionary = {}
	for entry: Dictionary in index:
		paths.append(str(entry.path))
	for path: String in paths:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or not parsed.has("navigation"):
			fail("invalid source map: " + path)
			return
		var definition: Dictionary = parsed
		if catalog.has(str(definition.map_id)):
			fail("duplicate map: " + str(definition.map_id))
			return
		definition.navigation["use_baked_cache"] = false
		var field := FIELD.new()
		var started: int = Time.get_ticks_msec()
		field.configure(CATALOG.apply_map(definition))
		var snapshot: Dictionary = field.navigation_snapshot()
		if snapshot.reachable.size() != field.width * field.height or snapshot.reachable.is_empty():
			fail("invalid navigation dimensions: " + str(definition.map_id))
			return
		var packed: PackedByteArray = var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_GZIP)
		var output: String = "res://data/maps/navigation/" + str(definition.map_id) + ".nav"
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			fail("cannot write " + output)
			return
		file.store_buffer(packed)
		file.flush()
		var status: Error = file.get_error()
		file.close()
		if status != OK or packed.is_empty() or FileAccess.get_file_as_bytes(output) != packed:
			fail("incomplete navigation cache: " + output)
			return
		catalog[str(definition.map_id)] = {"baked_signature":snapshot.signature,"baked_cache_path":output,
			"baked_sha256":FileAccess.get_sha256(output),"source_path":path}
		print("NAV_BAKED ",definition.map_id," bytes=",packed.size()," ms=",Time.get_ticks_msec()-started)
	# Publish the index only after every map was successfully generated.
	var index_file: FileAccess = FileAccess.open("res://data/maps/navigation/catalog.json", FileAccess.WRITE)
	if index_file == null:
		fail("cannot write navigation catalog")
		return
	index_file.store_string(JSON.stringify(catalog,"  ") + "\n")
	index_file.flush()
	var index_status: Error = index_file.get_error()
	index_file.close()
	if index_status != OK:
		fail("incomplete navigation catalog")
		return
	print("NAV_BAKE_OK ",catalog.size())
	quit(0)
