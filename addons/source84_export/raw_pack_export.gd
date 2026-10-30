@tool
extends EditorExportPlugin
const ROOT = "res://external_map_packs/source84_v3/"
const MANIFEST = "res://data/maps/source84_delivery_manifest.json"

func _get_name() -> String:
	return "Source84PrivateRawPack"

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	if not FileAccess.file_exists(ROOT + "index.json"):
		push_warning("SOURCE84_NOT_BUNDLED: install the private pack and use tools/source84_delivery.py export for a complete-map build")
		return
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	# Check all bytes before adding any raw map files. The offline build wrapper
	# also rejects missing/damaged inputs before invoking the exporter.
	for relative: String in spec.files:
		var row: Dictionary = spec.files[relative]
		var source: String = ROOT + relative
		if relative.contains("..") or relative.begins_with("/") or not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != row.sha256:
			push_error("SOURCE84_EXPORT_REJECTED: " + relative)
			return
	for relative: String in spec.files:
		add_file(ROOT + relative, FileAccess.get_file_as_bytes(ROOT + relative), false)
	print("SOURCE84_RAW_EXPORT files=", spec.total_files, " bytes=", spec.total_bytes)
