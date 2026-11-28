extends RefCounted
## Read a verified scene scope from the installed complete 523 UI.
const Pack = preload("res://scripts/ui/original_ui/source_pack.gd")
const Images = preload("res://scripts/ui/source523_image_assets.gd")
const SELECTION_SHA = "1db371078b85599ce124dee1c825ec088c43f00ab0abe61404a855934089e027"
const MANIFEST_SHA = "121efdebdb481b6630972507aabba4ed434972795f38266ac86525495d4d2eb5"

static func open_selected(index_file: String) -> RefCounted:
	var selection: Dictionary = Images.original_ui_selection(OS.get_cmdline_user_args(),
		OS.get_environment("TWILIGHT_SOURCE523_UI_ICONS"), OS.get_environment("TWILIGHT_SOURCE523_UI_ICONS_SHA256"))
	if selection.get("sha256") != SELECTION_SHA: return null
	var path: String = ProjectSettings.globalize_path(str(selection.get("path", "")))
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SELECTION_SHA: return null
	return read_installed(path.get_base_dir().path_join("complete_pack"), index_file)

static func read_installed(root: String, index_file: String) -> RefCounted:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_file))
	if not index is Dictionary or index.get("source_manifest_sha256") != MANIFEST_SHA: return null
	var file := FileAccess.open(root.path_join("original_ui.json"), FileAccess.READ)
	if file == null or file.get_length() != index.manifest_bytes: return null
	var subset: Dictionary = {"schema":"twilight-original-ui-v1", "blockers":[], "scenes":{}, "atlases":{}, "files":index.files}
	for section: String in ["scenes", "atlases"]:
		for member: String in index[section]:
			var entry: Array = index[section][member]
			file.seek(int(entry[0]))
			var bytes: PackedByteArray = file.get_buffer(int(entry[1]))
			if bytes.size() != int(entry[1]) or Pack._sha256(bytes) != entry[2]: return null
			var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if not value is Dictionary: return null
			subset[section][member] = value
	file.close()
	if not Pack.MANIFEST.verify(subset, root).is_empty(): return null
	var result := Pack.new()
	result._adopt(subset, root, FileAccess.get_sha256(index_file))
	return result
