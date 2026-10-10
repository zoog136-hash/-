extends RefCounted
class_name TwilightL1JRuntimeAssets
## Reviewed, content-addressed visual overrides. Game IDs/stats/save data are never written.
const PATH: String = "res://data/l1j/live_visual_bindings.json"
static var _loaded: bool = false
static var _enabled: bool = true
static var _items: Dictionary = {}
static var _names: Dictionary = {}
static var _monsters: Dictionary = {}
static var _textures: Dictionary = {}

static func reset() -> void:
	_loaded = false
	_items.clear()
	_names.clear()
	_monsters.clear()
	_textures.clear()

static func set_enabled(value: bool) -> void:
	_enabled = value

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(PATH): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not value is Dictionary or int(value.get("schema", 0)) != 1: return
	if not bool(value.get("enabled", false)): return
	var item_records: Variant = value.get("items", [])
	var monster_records: Variant = value.get("monsters", [])
	if not item_records is Array or not monster_records is Array: return
	for raw: Variant in item_records:
		if not raw is Dictionary: continue
		var record: Dictionary = raw
		var id: String = str(record.get("game_source_id", ""))
		var name_value: String = str(record.get("game_name", ""))
		if id.is_empty() or name_value.is_empty() or _items.has(id) or _names.has(name_value): continue
		if not str(record.get("source_candidate_id", "")).begins_with("ext:"): continue
		_items[id] = record.duplicate(true)
		_names[name_value] = record.duplicate(true)
	for raw: Variant in monster_records:
		if not raw is Dictionary: continue
		var record: Dictionary = raw
		var name_value: String = str(record.get("game_name", ""))
		if name_value.is_empty() or _monsters.has(name_value): continue
		if not str(record.get("source_candidate_id", "")).begins_with("ext:a3:npc:"): continue
		_monsters[name_value] = record.duplicate(true)

static func _texture(path: String, digest: String) -> Texture2D:
	if not _enabled or not path.begins_with("res://assets/l1j/verified/"): return null
	if path.contains("..") or path.contains("\\") or digest.length() != 64 or not digest.is_valid_hex_number(false): return null
	var key: String = path + "|" + digest
	if _textures.has(key): return _textures[key] as Texture2D
	# Exported PCK/APK images are remapped to .ctex; original PNG bytes may be absent.
	# Preserve a separately exported source-byte record to keep the hash gate intact.
	var raw_path: String = path if FileAccess.file_exists(path) else "res://data/l1j/verified_bytes/%s.l1jpng" % digest
	if not FileAccess.file_exists(raw_path) or FileAccess.get_sha256(raw_path) != digest: return null
	var result: Texture2D = null
	if path.begins_with("res://assets/l1j/verified/monsters/"):
		# Some existing spawn records have no visual material. Prepare display alpha here
		# so all spawn paths work, while keeping the audited original bytes untouched.
		var portrait := Image.new()
		if portrait.load_png_from_buffer(FileAccess.get_file_as_bytes(raw_path)) != OK: return null
		portrait.convert(Image.FORMAT_RGBA8)
		_clear_border_background(portrait)
		result = ImageTexture.create_from_image(portrait)
		result.resource_path = path
	elif ResourceLoader.exists(path): result = load(path) as Texture2D
	else:
		var pixels := Image.new()
		if pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(raw_path)) != OK: return null
		result = ImageTexture.create_from_image(pixels)
		result.resource_path = path
	if result != null: _textures[key] = result
	return result

static func _clear_border_background(pixels: Image) -> void:
	# The source viewer includes a dark grey vignette, not a single flat black key.
	# Flood only low neutral values connected to the border; enclosed details survive.
	var width: int = pixels.get_width()
	var height: int = pixels.get_height()
	var pending: Array[Vector2i] = []
	for x: int in range(width):
		pending.append(Vector2i(x,0))
		pending.append(Vector2i(x,height-1))
	for y: int in range(1,height-1):
		pending.append(Vector2i(0,y))
		pending.append(Vector2i(width-1,y))
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height: continue
		var color: Color = pixels.get_pixelv(point)
		var high: float = maxf(maxf(color.r,color.g),color.b)
		var low: float = minf(minf(color.r,color.g),color.b)
		if color.a == 0.0 or high >= 0.16 or high-low > 0.02: continue
		color.a = 0.0
		pixels.set_pixelv(point,color)
		pending.append(point+Vector2i.LEFT)
		pending.append(point+Vector2i.RIGHT)
		pending.append(point+Vector2i.UP)
		pending.append(point+Vector2i.DOWN)

static func item_binding(record: Dictionary, name_value: String = "") -> Dictionary:
	_ensure()
	if not _enabled: return {}
	var name_key: String = str(record.get("name", name_value))
	var source: String = str(record.get("sourceId", ""))
	# A named physical instance still resolves to the existing game item name.
	if not source.is_empty():
		var matched: Dictionary = _items.get(source, {})
		return matched if str(matched.get("game_name", "")) == name_key else {}
	return _names.get(name_key, {})

static func item_icon(record: Dictionary, name_value: String) -> Texture2D:
	var binding: Dictionary = item_binding(record, name_value)
	return _texture(str(binding.get("inventory_texture", "")), str(binding.get("inventory_sha256", "")))

static func ground_icon(record: Dictionary, name_value: String) -> Texture2D:
	var binding: Dictionary = item_binding(record, name_value)
	return _texture(str(binding.get("ground_texture", "")), str(binding.get("ground_sha256", "")))

static func monster_texture(record: Dictionary) -> Texture2D:
	_ensure()
	var binding: Dictionary = _monsters.get(str(record.get("name", "")), {})
	return _texture(str(binding.get("texture", "")), str(binding.get("sha256", "")))

static func is_verified_monster(record: Dictionary, texture: Texture2D) -> bool:
	return texture != null and monster_texture(record) == texture
