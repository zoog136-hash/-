extends RefCounted
## Locally installed, individually reviewed source appearances. No gameplay fields.
const MANIFEST_PATH = "res://data/source_transform_visuals.json"
static var entries: Dictionary = {}

static func configure(profile: Resource, kind: String, record: Dictionary) -> void:
	if kind != "transform" or str(record.get("grade", "")) not in ["일반", "고급", "희귀", "영웅", "전설"]: return
	if entries.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary: entries = parsed.get("entries", {})
	var entry: Dictionary = entries.get(profile.profile_id, {})
	if entry.is_empty() or str(record.get("name", "")) != str(entry.get("name", "")) or str(record.get("grade", "")) != str(entry.get("grade", "")): return
	var path: String = str(entry.get("frames_path", ""))
	if not ResourceLoader.exists(path): return
	# Retain layout, projectile/hit/collision offsets, timing and hit markers.
	# Baphomet already uses directional8; changing layout would change projectiles.
	if str(profile.layout) != str(entry.get("required_layout", "")): return
	profile.frames_path = path
	profile.animation_names = {}
	profile.pixel_scale = float(entry.pixel_scale)
	profile.sprite_offset = Vector2(float(entry.sprite_offset[0]), float(entry.sprite_offset[1]))
	profile.color_tint = Color.WHITE
	profile.authored_motion_weight = 0.0
