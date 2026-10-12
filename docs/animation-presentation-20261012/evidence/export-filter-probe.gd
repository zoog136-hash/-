extends SceneTree
func _initialize() -> void:
	var ok: bool = ProjectSettings.load_resource_pack("/workspace/evidence/animation-export-check.pck", false)
	var files: Array[String] = ["res://data/animation_presentation.json", "res://data/visuals/runtime_manifest.json"]
	for path: String in files: ok = ok and FileAccess.file_exists(path)
	ok = ok and ResourceLoader.exists("res://Main.tscn")
	for path: String in ["res://docs/animation-presentation-20261012/inventory.json", "res://docs/animation-presentation-20261012/evidence/gallery/cone-0.png", "res://docs/animation-presentation-20261012/evidence/motion/after.mp4"]:
		ok = ok and not FileAccess.file_exists(path)
	var texture: Texture2D = load("res://assets/catalog_motion/transform/393.webp")
	ok = ok and texture != null
	print("ANIMATION_EXPORT_FILTER_OK gameplay/config/art preserved; review artifacts excluded" if ok else "ANIMATION_EXPORT_FILTER_FAILED")
	quit(0 if ok else 1)
