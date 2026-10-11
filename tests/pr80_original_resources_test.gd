extends SceneTree

const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const MONSTERS = preload("res://scripts/monsters/monster_catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("PR80_ORIGINAL_RESOURCES_FAIL: ", label)

func _run() -> void:
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/pr80_original_asset_hashes.json"))
	var files: Dictionary = audit.get("files", {})
	check(files.size() == 528, "528 original image paths required")
	for relative: String in files:
		var path: String = "res://" + relative
		check(FileAccess.file_exists(path), "missing " + relative)
		check(FileAccess.get_sha256(path) == str(files[relative]), "hash " + relative)
		var texture: Texture2D = load(path) as Texture2D
		check(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "Godot texture " + relative)
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var monster_count: int = 0
	for row: Dictionary in MONSTERS.expand(db["몬스터"]):
		if not VISUALS.monster_binding(row).is_empty():
			monster_count += 1
			check(VISUALS.monster_texture(row) != null, "monster binding " + str(row.name))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var item_count: int = 0
	var ground_count: int = 0
	for row: Dictionary in catalog["아이템"]:
		var binding: Dictionary = VISUALS.item_binding(row)
		if not binding.is_empty():
			item_count += 1
			check(VISUALS.item_icon(row) != null, "item binding " + str(row.sourceId))
			check(VISUALS.item_icon(row, str(row.name), true) != null, "ground binding " + str(row.sourceId))
			if str(binding.get("ground_path", "")) != str(binding.get("path", "")):
				ground_count += 1
	check(monster_count == 132, "132 normal monster bindings required")
	check(item_count == 420, "420 current item bindings required")
	check(ground_count == 25, "25 dedicated ground item bindings required")
	if failures.is_empty():
		print("PR80_ORIGINAL_RESOURCES_OK png=528 monsters=132 items=420 ground=25 hashes_and_loaders=true")
	quit(0 if failures.is_empty() else 1)
