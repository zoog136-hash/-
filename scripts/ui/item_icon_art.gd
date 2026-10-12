extends RefCounted

# Compatibility entrypoint. Keep native pixels, alpha, aspect ratio and resolution.
# Grade chrome belongs to the parent slot; animated highlights use ItemVisual.
static func item_icon(record: Dictionary, name_value: String, index: Dictionary) -> Texture2D:
	var path: String = str(record.get("image_path", ""))
	if path.is_empty() and str(record.get("sourceId", "")).is_empty():
		path = str(index.get(name_value, ""))
	return render(path)

static func render(path: String, _grade: String = "일반", _name: String = "") -> Texture2D:
	if not path.begins_with("res://assets/") or path.contains("..") or path.contains("\\") or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
