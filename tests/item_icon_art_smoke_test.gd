extends SceneTree

const ART = preload("res://scripts/ui/item_icon_art.gd")
const INDEX_PATH = "res://data/catalog_image_index_v19.json"
const PROFILE_PATH = "res://data/item_icon_art_profiles_v1.json"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("ITEM_ICON_FAIL " + message)

func _verify() -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	check(records is Dictionary, "catalog image index remains valid")
	check(config is Dictionary, "art profile database remains valid")
	if not records is Dictionary or not config is Dictionary:
		quit(1)
		return
	var items: Dictionary = records.get("아이템", {})
	check(items.size() >= 2000, "full original item index remains available")
	check(bool(config.get("fidelity", {}).get("keep_original_asset", false)), "original asset is protected")
	for item_name: String in ["생명의 단검", "군터의 단도", "데스나이트의 불검"]:
		var path: String = str(items.get(item_name, ""))
		check(path.begins_with("res://assets/catalog/"), "original DB path exists: " + item_name)
		if path.is_empty() or not ResourceLoader.exists(path):
			failures.append("missing source icon: " + item_name)
			continue
		var original: Texture2D = load(path) as Texture2D
		var old_image: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var rare: Texture2D = ART.render(path, "희귀", item_name)
		var mythic: Texture2D = ART.render(path, "신화", item_name)
		check(original != null and rare != null and mythic != null, "textures load: " + item_name)
		if rare != null and mythic != null:
			check(rare.get_size() == Vector2(96, 96), "icon resolution: " + item_name)
			check(rare != mythic, "grade variant cache: " + item_name)
			check(ART.render(path, "희귀", item_name) == rare, "reuses icon cache: " + item_name)
		check(FileAccess.get_file_as_bytes(path) == old_image, "original PNG not modified: " + item_name)
	check(ART.render("res://missing.png") == null, "missing icon is safe")
	if failures.is_empty():
		print("ITEM_ICON_ART_OK checks=%d" % checks)
		quit(0)
	else:
		print("ITEM_ICON_ART_FAILED checks=%d failures=%d" % [checks, failures.size()])
		quit(1)
