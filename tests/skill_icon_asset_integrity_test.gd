extends SceneTree
const SOURCE = "res://data/skills/styled_icon_provenance.json"

func _initialize() -> void:
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not json is Dictionary or int(json.get("total",0)) != 125:
		push_error("Expected 125 icon records")
		quit(1)
		return
	var icons: Array = json.get("records",[])
	if icons.size() != 125:
		push_error("Expected 125 registered icon paths")
		quit(1)
		return
	var seen: Dictionary = {}
	for item: Variant in icons:
		if not item is Dictionary:
			push_error("Invalid icon record")
			quit(1)
			return
		var id: String = str(item.get("skill_id",""))
		var path: String = str(item.get("icon",""))
		if seen.has(id) or path != "res://assets/skills/styled_icons/" + id + ".svg" or not ResourceLoader.exists(path):
			push_error("Missing or duplicate skill image: " + id)
			quit(1)
			return
		seen[id] = true
	print("SKILL_ICON_125_INTEGRITY_PASS")
	quit(0)
