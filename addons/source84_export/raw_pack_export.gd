@tool
extends EditorExportPlugin
const ROOT = "res://external_map_packs/source84_v3/"
const MANIFEST = "res://data/maps/source84_delivery_manifest.json"

func _get_name() -> String:
	return "Source84PrivateRawPack"

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	_export_supplied_effects()
	if not FileAccess.file_exists(ROOT + "index.json"):
		push_warning("SOURCE84_NOT_BUNDLED: restore tracked source84_v3 files and use tools/source84_delivery.py export for a complete-map build")
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

func _export_supplied_effects() -> void:
	var root := "res://assets/external_spx/similar_skills/"
	var manifest: String = root + "manifest.json"
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	if not spec is Dictionary or spec.get("effects", {}).size() != 91:
		push_error("SKILL_EFFECT_EXPORT_REJECTED: supplied resource inventory absent")
		return
	var files: Dictionary = {}
	for row: Dictionary in spec.effects.values():
		var name: String = str(row.atlas)
		if name != name.get_file() or FileAccess.get_sha256(root + name) != str(row.sha256):
			push_error("SKILL_EFFECT_EXPORT_REJECTED: " + name)
			return
		files[name] = true
	for name: String in files:
		add_file(root + name, FileAccess.get_file_as_bytes(root + name), false)
	add_file(manifest, FileAccess.get_file_as_bytes(manifest), false)
	print("SKILL_EFFECT_RAW_EXPORT files=", files.size(), " plus manifest")
