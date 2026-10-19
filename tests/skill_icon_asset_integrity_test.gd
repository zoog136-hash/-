extends SceneTree
const SOURCE = "res://data/skills/styled_icon_provenance.json"
const CATALOG = preload("res://scripts/skills/skill_catalog.gd")

func _initialize() -> void:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not index is Dictionary or int(index.get("total",0)) != 125:
		_fail("Invalid skill icon manifest")
		return
	var icons: Array = index.get("records",[])
	if icons.size() != 125:
		_fail("Expected exactly 125 icon assignments")
		return
	var seen: Dictionary = {}
	for item: Variant in icons:
		if not item is Dictionary:
			_fail("Malformed icon record")
			return
		var id: String = str(item.get("skill_id",""))
		var path: String = str(item.get("icon",""))
		if seen.has(id) or path != "res://assets/skills/styled_icons/" + id + ".svg":
			_fail("Duplicate or unexpected skill image: " + id)
			return
		if not ResourceLoader.exists(path):
			_fail("Missing imported icon: " + id)
			return
		var texture: Texture2D = load(path) as Texture2D
		if texture == null or texture.get_width() != 64 or texture.get_height() != 64:
			_fail("Icon did not import as a 64x64 texture: " + id)
			return
		var preferred: String = CATALOG.preferred_icon_path({"id":id, "icon":"res://assets/skills/icons/" + id + ".svg"})
		var private_path: String = "res://assets/skills/private_icons/" + id + ".png"
		var expected: String = private_path if ResourceLoader.exists(private_path) else path
		if preferred != expected:
			_fail("Skill book / quickslot icon precedence changed: " + id)
			return
		seen[id] = true
	print("SKILL_ICON_125_TEXTURES_OK")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
