extends RefCounted
class_name TwilightExternalA2Bridge

# Optional privately-installed visual pack. The game remains playable without it.
# No external SQL, executable, client binaries or save data are loaded at runtime.
const MANIFEST_PATH: String = "res://data/external_l1j/a2_bridge_v1.json"
const ROOT: String = "res://assets/external_l1j/"
const MAX_CACHE: int = 128
static var _loaded: bool = false
static var _items: Dictionary = {}
static var _monsters: Dictionary = {}
static var _textures: Dictionary = {}
static var _order: Array[String] = []

static func reset() -> void:
	_loaded = false
	_items.clear()
	_monsters.clear()
	_textures.clear()
	_order.clear()

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary: return
	var manifest: Dictionary = parsed as Dictionary
	if int(manifest.get("schema", 0)) != 1 or not bool(manifest.get("enabled", false)): return
	if manifest.get("items") is Dictionary: _items = manifest.get("items", {})
	if manifest.get("monsters") is Dictionary: _monsters = manifest.get("monsters", {})

static func stats() -> Dictionary:
	_ensure()
	return {"ready": not _items.is_empty() or not _monsters.is_empty(),
		"item_names": _items.size(), "monster_names": _monsters.size()}

static func _texture(group: String, name_value: String) -> Texture2D:
	_ensure()
	var source: Dictionary = _items if group == "items" else _monsters
	var entry_value: Variant = source.get(name_value.strip_edges(), {})
	if not entry_value is Dictionary: return null
	var entry: Dictionary = entry_value as Dictionary
	var graphic_id: String = str(entry.get("graphic_id", ""))
	if graphic_id.is_empty() or not graphic_id.is_valid_int() or graphic_id.begins_with("-"): return null
	var expected: String = ROOT + group + "/" + graphic_id + ".png"
	if str(entry.get("path", "")) != expected or not ResourceLoader.exists(expected): return null
	if _textures.has(expected):
		_order.erase(expected)
		_order.append(expected)
		return _textures[expected] as Texture2D
	var image: Texture2D = load(expected) as Texture2D
	if image == null: return null
	_textures[expected] = image
	_order.append(expected)
	while _order.size() > MAX_CACHE:
		_textures.erase(_order.pop_front())
	return image

static func item_icon(record: Dictionary, fallback_name: String = "") -> Texture2D:
	var value: String = str(record.get("name", fallback_name))
	return _texture("items", value)

static func monster_texture(record: Dictionary) -> Texture2D:
	return _texture("monsters", str(record.get("name", "")))
