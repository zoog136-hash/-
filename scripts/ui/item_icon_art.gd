extends RefCounted

# Compatibility entrypoint for old record image_path links. Every picture under
# res://assets/ is retired (no self-made or pre-523 art; an older install may
# still carry the files), so these old links never produce a texture. Original
# 523 item pictures come from Source523 image routes (ItemVisual).
static func item_icon(_record: Dictionary, _name_value: String, _index: Dictionary) -> Texture2D:
	return null

static func render(_path: String, _grade: String = "일반", _name: String = "") -> Texture2D:
	return null
