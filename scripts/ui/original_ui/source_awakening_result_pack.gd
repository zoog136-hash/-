extends RefCounted
## Earlier main UI addons omit this scene. The same installation contains
## the complete original UI. Read just the two scene records and five atlas
## records used by this result, then verify their original CSBs, pages and font.
const Pack = preload("res://scripts/ui/original_ui/source_pack.gd")
const Images = preload("res://scripts/ui/source523_image_assets.gd")
const INDEX = "res://data/ui/current523_awakening_result_index.json"
const REVIEW_INDEX = "res://data/ui/current523_awakening_review_index.json"
const SELECTION_SHA = "1db371078b85599ce124dee1c825ec088c43f00ab0abe61404a855934089e027"
const MEMBER = "UI/Change/Change_Upgrade_Skill_Awaken.csb"
const SOURCE_SHA = "a01d2719a91fb29a2d22fdf9e8680bf90f373ccd4db8962bbd566f639b5f28b8"
const REVIEW = "UI/CommonUi/Common_MessageBox.csb"
const REVIEW_SHA = "9ba302b365e5b5424033f0dcc358ee1cf2fd2d0fd34c442ea9621a8962c96c2a"

static func resolve(active: RefCounted, member: String = MEMBER) -> RefCounted:
	if member not in [MEMBER, REVIEW]: return null
	var expected: String = SOURCE_SHA if member == MEMBER else REVIEW_SHA
	if active != null and active.manifest.get("files", {}).get(member, {}).get("sha256") == expected and active.manifest.get("scenes", {}).has(member):
		return active
	var selection: Dictionary = Images.original_ui_selection(OS.get_cmdline_user_args(),
		OS.get_environment("TWILIGHT_SOURCE523_UI_ICONS"), OS.get_environment("TWILIGHT_SOURCE523_UI_ICONS_SHA256"))
	if selection.get("sha256") != SELECTION_SHA: return null
	var path: String = ProjectSettings.globalize_path(str(selection.get("path", "")))
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SELECTION_SHA: return null
	return read_installed(path.get_base_dir().path_join("complete_pack"), INDEX if member == MEMBER else REVIEW_INDEX)

static func read_installed(root: String, index_file: String = INDEX) -> RefCounted:
	if index_file not in [INDEX, REVIEW_INDEX]: return null
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_file))
	var file := FileAccess.open(root.path_join("original_ui.json"), FileAccess.READ)
	if not index is Dictionary or file == null or file.get_length() != index.manifest_bytes: return null
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
