extends RefCounted
class_name TwilightVisualManifest

# One identity-based, bounded loader for locally produced catalog animation
# atlases and reviewed original monster families. No gameplay data is mutated.
const PATH := "res://data/visuals/runtime_manifest.json"
const LIMIT := 12 # atlas textures are larger than portrait icons
static var _loaded: bool = false
static var _data: Dictionary = {}
static var _frames: Dictionary = {}
static var _order: Array[String] = []
static var _textures: Dictionary = {}
static var _texture_order: Array[String] = []
static var _missing: Dictionary = {}

static func reset() -> void:
	_loaded = false
	_data.clear()
	_frames.clear()
	_order.clear()
	_textures.clear()
	_texture_order.clear()
	_missing.clear()

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and int(parsed.get("schema", 0)) == 1:
		_data = parsed

static func record(key: String) -> Dictionary:
	_ensure()
	var value: Variant = (_data.get("catalog", {}) as Dictionary).get(key, {})
	return value as Dictionary if value is Dictionary else {}

static func _safe(path: String) -> bool:
	return path.begins_with("res://assets/") and not path.contains("..") and not path.contains("\\")

static func _texture(path: String) -> Texture2D:
	if not _safe(path): return null
	if _textures.has(path):
		_texture_order.erase(path)
		_texture_order.append(path)
		return _textures[path] as Texture2D
	if not ResourceLoader.exists(path):
		_missing[path] = "missing texture"
		return null
	var result: Texture2D = load(path) as Texture2D
	if result == null: return null
	_textures[path] = result
	_texture_order.append(path)
	while _texture_order.size() > LIMIT:
		_textures.erase(_texture_order.pop_front())
	return result

static func catalog_frames(key: String) -> SpriteFrames:
	if _frames.has(key):
		_order.erase(key)
		_order.append(key)
		return _frames[key] as SpriteFrames
	var info: Dictionary = record(key)
	if info.is_empty(): return null
	var texture: Texture2D = _texture(str(info.get("atlas", "")))
	var cell: Variant = info.get("cell", [])
	var tracks: Variant = info.get("tracks", [])
	if texture == null or not cell is Array or cell.size() != 2 or not tracks is Array: return null
	var width: int = int(cell[0])
	var height: int = int(cell[1])
	if width <= 0 or height <= 0 or width > 512 or height > 512: return null
	var result := SpriteFrames.new()
	result.remove_animation("default")
	for raw: Variant in tracks:
		if not raw is Dictionary: return null
		var track: Dictionary = raw
		var name_value: String = str(track.get("name", ""))
		var row: int = int(track.get("row", -1))
		var count: int = int(track.get("count", 0))
		if name_value.is_empty() or result.has_animation(name_value) or row < 0 or count < 2 or count > 32: return null
		if count * width > texture.get_width() or (row + 1) * height > texture.get_height(): return null
		result.add_animation(name_value)
		result.set_animation_speed(name_value, clampf(float(track.get("fps", 8.0)), 1.0, 60.0))
		result.set_animation_loop(name_value, bool(track.get("loop", false)))
		for column: int in range(count):
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(column * width, row * height, width, height)
			frame.filter_clip = true
			result.add_frame(name_value, frame)
	if result.get_animation_names().is_empty(): return null
	result.set_meta("twilight_visual_key", key)
	result.set_meta("twilight_authored_parts", true)
	_frames[key] = result
	_order.append(key)
	while _order.size() > LIMIT:
		_frames.erase(_order.pop_front())
	return result

static func monster_binding(game_record: Dictionary) -> Dictionary:
	_ensure()
	# Bosses never inherit a normal family's appearance, even when a template
	# or silhouette in the old catalog was shared.
	if preload("res://scripts/loot_drop.gd").is_boss_record(game_record): return {}
	var value: Variant = (_data.get("monsters", {}) as Dictionary).get(str(game_record.get("name", "")), {})
	return value as Dictionary if value is Dictionary else {}

static func monster_texture(game_record: Dictionary) -> Texture2D:
	var info: Dictionary = monster_binding(game_record)
	var reviewed_name: String = str(info.get("verified_game_name", ""))
	if not reviewed_name.is_empty():
		var previous: Texture2D = preload("res://addons/twilight_l1j/twilight_runtime_assets.gd").monster_texture({"name":reviewed_name})
		if previous != null: return previous
	return _texture(str(info.get("path", "")))

static func item_binding(game_record: Dictionary, fallback_name: String = "") -> Dictionary:
	_ensure()
	var entries: Dictionary = _data.get("items", {})
	var id: String = str(game_record.get("sourceId", ""))
	var value: Variant = entries.get(id, {}) if not id.is_empty() else {}
	if not id.is_empty():
		if value is Dictionary and not value.is_empty() and str(value.get("name", "")) == str(game_record.get("name", fallback_name)):
			return value as Dictionary
		return {}
	# Name-only starting consumables have no sourceId. The builder only emits
	# non-conflicting reviewed names, never strips enchantment or regional names.
	var names: Dictionary = _data.get("item_names", {})
	var source: String = str(names.get(str(game_record.get("name", fallback_name)), ""))
	value = entries.get(source, {})
	return value as Dictionary if value is Dictionary else {}

static func item_icon(game_record: Dictionary, fallback_name: String = "", ground: bool = false) -> Texture2D:
	var info: Dictionary = item_binding(game_record, fallback_name)
	return _texture(str(info.get("ground_path" if ground else "path", "")))

static func stats() -> Dictionary:
	_ensure()
	return {"catalog": (_data.get("catalog", {}) as Dictionary).size(),
		"monsters": (_data.get("monsters", {}) as Dictionary).size(),
		"items": (_data.get("items", {}) as Dictionary).size(),
		"frame_cache": _frames.size(), "texture_cache": _textures.size(),
		"missing": _missing.duplicate()}
