extends SceneTree
## Run in a clean minimal project; the directory pack must be absent there.
const LOCATION = preload("res://scripts/maps/source_map_pack_location.gd")
func _initialize() -> void:
	var archive: String = OS.get_environment("SOURCE84_EXPORT_PROOF")
	if archive.is_empty(): printerr("SOURCE84_EXPORT_PROOF is required"); quit(1); return
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK", "")
	if FileAccess.file_exists(LOCATION.BUNDLED + "/index.json"):
		printerr("Cold proof must start without a directory pack"); quit(1); return
	if LOCATION.root_path() != LOCATION.USER or not ProjectSettings.load_resource_pack(archive, true):
		printerr("Missing-pack selection or PCK mount failed"); quit(1); return
	if LOCATION.root_path() != LOCATION.BUNDLED:
		printerr("Exported bundle was not discovered"); quit(1); return
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/source84_delivery_manifest.json"))
	var checked: int = 0
	for relative: String in spec.files:
		var path: String = LOCATION.BUNDLED + "/" + relative
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != spec.files[relative].sha256:
			printerr("Exported raw file missing or changed: ", relative); quit(1); return
		checked += 1
	var first: String = ""
	for relative: String in spec.files:
		if relative.begins_with("chunks/"): first = relative; break
	var bitmap := Image.new()
	if bitmap.load_webp_from_buffer(FileAccess.get_file_as_bytes(LOCATION.BUNDLED + "/" + first)) != OK:
		printerr("Exported source WebP decode failed"); quit(1); return
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK", "/missing-explicit-override")
	if LOCATION.root_path() != "/missing-explicit-override":
		printerr("Explicit missing input must not silently fall back"); quit(1); return
	print("SOURCE84_COLD_EXPORT_OK files=", checked, " raw_webp=", bitmap.get_size())
	quit(0)
