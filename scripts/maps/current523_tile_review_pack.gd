extends RefCounted
## Only the reproducible coverage display hypothesis is accepted here.
## Native M alpha, geometry and compositing remain unverified.
const SOURCE_INVENTORY = "b80c592b894b84a265e6f72739af77a78b96b26d6e3ee7ca0a441e0a41c79fab"
const RGBA_INVENTORY = "e84e7a7402c500f100dfe916eea4c7e52af18ba0c24a2e290a8e1dce11be0b2f"
const MAX_CACHED_ATLASES = 32
const SEMANTICS = {"geometry":"CANDIDATE_24X24", "palette":"CANDIDATE_RGB565", "coverage_alpha":"STORED_255_UNSTORED_0", "runtime_alpha":"UNKNOWN", "coordinates":"UNKNOWN", "projection":"UNKNOWN", "layers":"UNKNOWN", "movement":"UNKNOWN", "collision":"UNKNOWN"}
const RAW = preload("res://scripts/maps/current523_aden_pack.gd")
var problem: String = ""
var loaded: bool = false
var atlas_loads: int = 0
var _root: String = ""
var _tiles: Dictionary = {}
var _cache: Dictionary = {}
var _recent: Array[int] = []

func _fail(message: String) -> bool:
	problem = message
	return false

func load_pack(directory: String) -> bool:
	loaded = false
	_tiles.clear()
	_cache.clear()
	_recent.clear()
	problem = ""
	atlas_loads = 0
	_root = ""
	var file := FileAccess.open(directory.path_join("tiles523.json"), FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024: return _fail("Missing or oversized current523 tile review manifest")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return _fail("Invalid current523 tile review manifest")
	for key: String in ["schema", "cumulative_version", "land_id", "source_count"]:
		if not RAW._uint(parsed.get(key), 10000): return _fail("Invalid tile review identity")
	if parsed.schema != 1 or parsed.get("edition") != "LineageM" or parsed.cumulative_version != 523 or parsed.land_id != 4 or parsed.get("asset_path") != "Aden/" or parsed.get("source_root") != "Tile/" or parsed.source_count != 2866:
		return _fail("Tile review pack is not current523 Aden")
	if parsed.get("status") != "DISPLAY_HYPOTHESIS_COVERAGE_V1" or parsed.get("semantics") != SEMANTICS:
		return _fail("Unsupported tile display interpretation")
	if parsed.get("delivery_status") != "PRIVATE_LOCAL_ONLY": return _fail("Unverified tile pack delivery status")
	var rows: Variant = parsed.get("tiles")
	if not rows is Array or rows.size() != 2866: return _fail("Incomplete Aden tile review inventory")
	var candidate: Dictionary = {}
	var source_lines: Array[String] = []
	var rgba_lines: Array[String] = []
	for value: Variant in rows:
		if not value is Dictionary or not RAW._uint(value.get("tile_id"), 16777215): return _fail("Invalid raw tile ID")
		var id: int = int(value.tile_id)
		var member: String = "Tile/" + str(id) + ".ti2"
		if candidate.has(id) or value.get("member") != member or value.get("original_path") != "originals/" + member or value.get("atlas_path") != "atlases/" + str(id) + ".png":
			return _fail("Invalid or duplicate original tile path")
		for field: String in ["source_sha256", "decoded_sha256", "atlas_sha256", "atlas_rgba_sha256"]:
			if not RAW._sha(value.get(field)): return _fail("Invalid tile digest")
		if not RAW._uint(value.get("source_bytes"), 8 * 1024 * 1024) or int(value.source_bytes) < 1 or not RAW._uint(value.get("decoded_bytes"), 8 * 1024 * 1024) or not supported_layout(value):
			return _fail("Unsupported tile atlas layout")
		candidate[id] = value.duplicate(true)
		source_lines.append(member + "\t" + str(int(value.source_bytes)) + "\t" + str(value.source_sha256) + "\n")
		rgba_lines.append(member + "\t" + str(value.atlas_rgba_sha256) + "\n")
	source_lines.sort()
	rgba_lines.sort()
	if "".join(source_lines).sha256_text() != SOURCE_INVENTORY or parsed.get("source_inventory_sha256") != SOURCE_INVENTORY:
		return _fail("Stale or modified current523 tile source selection")
	if "".join(rgba_lines).sha256_text() != RGBA_INVENTORY or parsed.get("atlas_rgba_inventory_sha256") != RGBA_INVENTORY:
		return _fail("Modified coverage atlas interpretation")
	_root = directory
	_tiles = candidate
	loaded = true
	return true

func has_tile(tile_id: int) -> bool:
	return loaded and _tiles.has(tile_id)

func source_usage_identity(tile_id: int) -> Dictionary:
	if not has_tile(tile_id):return {}
	var row: Dictionary=_tiles[tile_id]
	return {"member":row.member,"bytes":int(row.source_bytes),"sha256":row.source_sha256}

func texture_for(tile_id: int) -> Texture2D:
	problem = ""
	if not has_tile(tile_id):
		_fail("Unresolved original Tile/" + str(tile_id) + ".ti2")
		return null
	if _cache.has(tile_id):
		_recent.erase(tile_id)
		_recent.append(tile_id)
		return _cache[tile_id]
	var row: Dictionary = _tiles[tile_id]
	var source := FileAccess.open(_root.path_join(str(row.original_path)), FileAccess.READ)
	if source == null or source.get_length() != int(row.source_bytes):
		_fail("Missing or wrong-sized original TI2")
		return null
	var source_bytes: PackedByteArray = source.get_buffer(int(row.source_bytes))
	if RAW._hash(source_bytes) != row.source_sha256:
		_fail("Original TI2 digest mismatch")
		return null
	var png := FileAccess.open(_root.path_join(str(row.atlas_path)), FileAccess.READ)
	if png == null or png.get_length() < 8 or png.get_length() > 2 * 1024 * 1024:
		_fail("Missing or oversized coverage atlas")
		return null
	var encoded: PackedByteArray = png.get_buffer(png.get_length())
	if RAW._hash(encoded) != row.atlas_sha256:
		_fail("Coverage atlas PNG digest mismatch")
		return null
	if not bounded_png_header(encoded):
		_fail("Coverage atlas PNG header exceeds the supported layout")
		return null
	var image := Image.new()
	if image.load_png_from_buffer(encoded) != OK or image.get_size() != Vector2i(384, 384):
		_fail("Invalid coverage atlas image")
		return null
	image.convert(Image.FORMAT_RGBA8)
	if RAW._hash(image.get_data()) != row.atlas_rgba_sha256:
		_fail("Coverage atlas pixels differ from the reviewed byte interpretation")
		return null
	var texture := ImageTexture.create_from_image(image)
	atlas_loads += 1
	_cache[tile_id] = texture
	_recent.append(tile_id)
	while _recent.size() > MAX_CACHED_ATLASES:
		_cache.erase(_recent.pop_front())
	return texture

func cache_size() -> int:
	return _cache.size()

static func source_rect(subimage: int) -> Rect2:
	return Rect2((subimage % 16) * 24, floori(float(subimage) / 16.0) * 24, 24, 24)

static func supported_layout(row: Dictionary) -> bool:
	var size: Variant = row.get("atlas_size")
	return RAW._uint(row.get("blocks"), 256) and int(row.blocks) == 256 and size is Array and size.size() == 2 and RAW._uint(size[0], 384) and RAW._uint(size[1], 384) and int(size[0]) == 384 and int(size[1]) == 384

static func bounded_png_header(encoded: PackedByteArray) -> bool:
	if encoded.size() < 33 or encoded.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]): return false
	if encoded.slice(8, 16) != PackedByteArray([0, 0, 0, 13, 73, 72, 68, 82]): return false
	var width: int = (int(encoded[16]) << 24) | (int(encoded[17]) << 16) | (int(encoded[18]) << 8) | int(encoded[19])
	var height: int = (int(encoded[20]) << 24) | (int(encoded[21]) << 16) | (int(encoded[22]) << 8) | int(encoded[23])
	return width == 384 and height == 384 and encoded[24] == 8 and encoded[25] == 6
