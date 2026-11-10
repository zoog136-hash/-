extends RefCounted
## Generic caller-pinned current M523 TI2 subset, independent of Land/AssetPath.
## This is stored-pixel coverage only; native M alpha/compositing remain UNKNOWN.
const MANIFEST_NAME = "tilepack523.json"
const MAX_CACHED_ATLASES = 32
const MAX_SOURCE_BYTES = 8 * 1024 * 1024
const MAX_PNG_BYTES = 2 * 1024 * 1024
const MAX_METADATA_BYTES = 64 * 1024 * 1024
const MAX_TILES = 20000
const TI2_DECODER = preload("res://scripts/maps/current523_ti2_decoder.gd")
const SEMANTICS = {"geometry":"CANDIDATE_24X24", "palette":"CANDIDATE_RGB565", "coverage_alpha":"STORED_255_UNSTORED_0", "runtime_alpha":"UNKNOWN", "coordinates":"UNKNOWN", "projection":"UNKNOWN", "layers":"UNKNOWN", "movement":"UNKNOWN", "collision":"UNKNOWN"}
var problem: String = ""
var loaded: bool = false
var atlas_loads: int = 0
var _root: String = ""
var _manifest_sha256: String = ""
var _atlas_storage: String = "png"
var _tiles: Dictionary = {}
## After the first verified load the tile rows live in a device-local record
## bake (keyed by the manifest pin and this script) and are read when an atlas
## is decoded; only each tile's block count stays in memory. The manifest
## bytes are still hash-checked on every load.
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
static var bake_enabled: bool = true
var _records: RefCounted
var _blocks: Dictionary = {}
var _cache: Dictionary = {}
var _recent: Array[int] = []

func _fail(message: String) -> bool:
	problem = message
	return false

func load_pack(directory: String, expected_manifest_sha256: String) -> bool:
	loaded = false
	_root = ""
	_manifest_sha256 = ""
	_atlas_storage = "png"
	_tiles.clear()
	_blocks.clear()
	_records = null
	_cache.clear()
	_recent.clear()
	problem = ""
	atlas_loads = 0
	if not _sha(expected_manifest_sha256): return _fail("A caller-pinned generic TI2 manifest SHA256 is required")
	var file := FileAccess.open(directory.path_join(MANIFEST_NAME), FileAccess.READ)
	if file == null or file.get_length() < 2 or file.get_length() > MAX_METADATA_BYTES:
		return _fail("Missing or oversized generic TI2 manifest")
	var encoded: PackedByteArray = file.get_buffer(file.get_length())
	if _hash(encoded) != expected_manifest_sha256: return _fail("Generic TI2 manifest differs from caller SHA256 pin")
	var bake_name: String = "current523_tile_pack_" + expected_manifest_sha256.left(16)
	var bake_key: String = BAKE.key(["current523_tile_pack.v1", expected_manifest_sha256, BAKE.code_key(["res://scripts/maps/current523_tile_pack.gd"])]) if bake_enabled else ""
	var baked: RefCounted = BAKE.open_records(bake_name, bake_key) if not bake_key.is_empty() else null
	if baked != null:
		var meta: Variant = baked.read("meta")
		if meta is Dictionary and meta.get("blocks") is Dictionary and meta.get("atlas_storage") in ["png", "runtime_ti2"] and not meta.blocks.is_empty():
			_root = directory
			_atlas_storage = meta.atlas_storage
			_blocks = meta.blocks
			_records = baked
			_manifest_sha256 = expected_manifest_sha256
			loaded = true
			return true
	var parsed: Variant = JSON.parse_string(encoded.get_string_from_utf8())
	encoded = PackedByteArray()
	if not parsed is Dictionary: return _fail("Invalid generic TI2 manifest")
	if not _uint(parsed.get("schema"), 1) or int(parsed.schema) != 1 or parsed.get("kind") != "current523_ti2_subset_pack" or parsed.get("edition") != "LineageM" or not _uint(parsed.get("cumulative_version"), 523) or int(parsed.cumulative_version) != 523 or parsed.get("source_root") != "Tile/":
		return _fail("Generic TI2 pack must be current M cumulative523")
	if parsed.get("status") != "DISPLAY_HYPOTHESIS_COVERAGE_V1" or parsed.get("semantics") != SEMANTICS or parsed.get("raw_decoded_roundtrip") != true or parsed.get("delivery_status") != "PRIVATE_LOCAL_ONLY":
		return _fail("Unsupported generic TI2 coverage or delivery claim")
	var storage: Variant = parsed.get("atlas_storage", "png")
	if not storage is String or storage not in ["png", "runtime_ti2"]: return _fail("Unsupported generic TI2 atlas storage")
	if not _sha(parsed.get("input_inventory_sha256")) or not _sha(parsed.get("input_source_inventory_sha256")) or not _sha(parsed.get("raw_model_inventory_sha256")) or not _uint(parsed.get("input_source_count"), MAX_TILES) or not _uint(parsed.get("source_count"), MAX_TILES) or int(parsed.source_count) < 1 or int(parsed.input_source_count) < int(parsed.source_count):
		return _fail("Invalid generic TI2 source inventory identity")
	var rows: Variant = parsed.get("tiles")
	if not rows is Array or rows.size() != int(parsed.source_count): return _fail("Generic TI2 subset count mismatch")
	var candidate: Dictionary = {}
	var source_lines: Array[String] = []
	var rgba_lines: Array[String] = []
	for value: Variant in rows:
		if not value is Dictionary or not _uint(value.get("tile_id"), 16777215): return _fail("Invalid literal TI2 ID")
		var id: int = int(value.tile_id)
		var member: String = "Tile/" + str(id) + ".ti2"
		if candidate.has(id) or value.get("member") != member or value.get("original_path") != "originals/" + member:
			return _fail("Unsafe or duplicate generic TI2 path")
		for field: String in ["source_sha256", "decoded_sha256", "atlas_rgba_sha256", "palette_u16le_sha256"]:
			if not _sha(value.get(field)): return _fail("Invalid generic TI2 digest")
		if storage == "png":
			if value.get("atlas_path") != "atlases/" + str(id) + ".png" or not _sha(value.get("atlas_sha256")) or not _uint(value.get("atlas_bytes"), MAX_PNG_BYTES) or int(value.atlas_bytes) < 33: return _fail("Unsupported generic TI2 PNG storage")
		else:
			for field: String in ["atlas_path", "atlas_bytes", "atlas_sha256"]:
				if value.has(field): return _fail("Runtime TI2 storage cannot declare a PNG resource")
		if not _uint(value.get("source_bytes"), MAX_SOURCE_BYTES) or int(value.source_bytes) < 1 or not supported_layout(value) or not _raw_evidence(value):
			return _fail("Unsupported generic TI2 raw or atlas layout")
		if not _provenance(value.get("provenance"), value.source_sha256): return _fail("TI2 member lacks exact current523 selection provenance")
		candidate[id] = value.duplicate(true)
		source_lines.append(member + "\t" + str(int(value.source_bytes)) + "\t" + str(value.source_sha256) + "\n")
		rgba_lines.append(member + "\t" + str(value.atlas_rgba_sha256) + "\n")
	source_lines.sort()
	rgba_lines.sort()
	if "".join(source_lines).sha256_text() != parsed.get("source_inventory_sha256"): return _fail("Generic TI2 source inventory mismatch")
	if "".join(rgba_lines).sha256_text() != parsed.get("atlas_rgba_inventory_sha256"): return _fail("Generic TI2 coverage inventory mismatch")
	if int(parsed.input_source_count) == int(parsed.source_count) and parsed.input_source_inventory_sha256 != parsed.source_inventory_sha256: return _fail("Whole input and included source inventories disagree")
	_root = directory
	_atlas_storage = storage
	_tiles = candidate
	for id: int in candidate: _blocks[id] = int(candidate[id].blocks)
	_manifest_sha256 = expected_manifest_sha256
	loaded = true
	if not bake_key.is_empty():
		var writer: RefCounted = BAKE.record_writer(bake_name, bake_key)
		if writer != null:
			for id: int in candidate: writer.add("t:%d" % id, candidate[id])
			writer.add("meta", {"atlas_storage":storage, "blocks":_blocks})
			if BAKE.finish_records(writer):
				var records: RefCounted = BAKE.open_records(bake_name, bake_key)
				if records != null:
					_records = records
					_tiles = {}
	return true

func _row(tile_id: int) -> Dictionary:
	return _records.read("t:%d" % tile_id) if _records != null else _tiles[tile_id]

func verified_identity() -> Dictionary:
	return {"root":_root,"manifest_sha256":_manifest_sha256} if loaded else {}

func matches_manifest(directory: String, expected_sha256: String) -> bool:
	if not loaded or directory!=_root or expected_sha256!=_manifest_sha256: return false
	var file:=FileAccess.open(directory.path_join(MANIFEST_NAME),FileAccess.READ)
	if file==null or file.get_length()<2 or file.get_length()>MAX_METADATA_BYTES: return false
	return _hash(file.get_buffer(file.get_length()))==expected_sha256

func has_tile(tile_id: int) -> bool:
	return loaded and _blocks.has(tile_id)

func source_usage_identity(tile_id: int) -> Dictionary:
	if not has_tile(tile_id):return {}
	var row: Dictionary=_row(tile_id)
	return {"member":row.member,"bytes":int(row.source_bytes),"sha256":row.source_sha256}

func has_subimage(tile_id: int, frame8bit: int) -> bool:
	return has_tile(tile_id) and frame8bit>=0 and frame8bit<int(_blocks[tile_id])

func texture_for(tile_id: int) -> Texture2D:
	problem = ""
	if not has_tile(tile_id):
		_fail("Unresolved original Tile/" + str(tile_id) + ".ti2")
		return null
	if _cache.has(tile_id):
		_recent.erase(tile_id)
		_recent.append(tile_id)
		return _cache[tile_id]
	var row: Dictionary = _row(tile_id)
	var source := FileAccess.open(_root.path_join(str(row.original_path)), FileAccess.READ)
	if source == null or source.get_length() != int(row.source_bytes):
		_fail("Missing or wrong-sized original TI2")
		return null
	var compressed: PackedByteArray = source.get_buffer(int(row.source_bytes))
	if _hash(compressed) != row.source_sha256:
		_fail("Original TI2 digest mismatch")
		return null
	var image: Image
	if _atlas_storage == "runtime_ti2":
		var decoder = TI2_DECODER.new()
		# Coverage is checked against its pin first; the drawn atlas then
		# carries the TI2 block flags' display alpha.
		var rgba: PackedByteArray = decoder.decode_rgba(compressed, row, true)
		if rgba.size() != 384 * 384 * 4:
			_fail(decoder.problem)
			return null
		image = Image.create_from_data(384, 384, false, Image.FORMAT_RGBA8, rgba)
	else:
		var png := FileAccess.open(_root.path_join(str(row.atlas_path)), FileAccess.READ)
		if png == null or png.get_length() != int(row.atlas_bytes):
			_fail("Missing or wrong-sized generic coverage atlas")
			return null
		var encoded: PackedByteArray = png.get_buffer(int(row.atlas_bytes))
		if _hash(encoded) != row.atlas_sha256:
			_fail("Generic coverage PNG digest mismatch")
			return null
		if not bounded_png_header(encoded):
			_fail("Generic coverage PNG header exceeds supported layout")
			return null
		image = Image.new()
		if image.load_png_from_buffer(encoded) != OK or image.get_size() != Vector2i(384, 384):
			_fail("Invalid generic coverage atlas image")
			return null
		image.convert(Image.FORMAT_RGBA8)
		if _hash(image.get_data()) != row.atlas_rgba_sha256:
			_fail("Generic coverage decoded RGBA digest mismatch")
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

static func source_rect(frame8bit: int) -> Rect2:
	if frame8bit < 0 or frame8bit > 255: return Rect2()
	return Rect2((frame8bit % 16) * 24, floori(float(frame8bit) / 16.0) * 24, 24, 24)

static func supported_layout(row: Dictionary) -> bool:
	var size: Variant = row.get("atlas_size")
	return _uint(row.get("blocks"), 256) and int(row.blocks) >= 1 and size is Array and size.size() == 2 and _uint(size[0], 384) and _uint(size[1], 384) and int(size[0]) == 384 and int(size[1]) == 384

static func bounded_png_header(encoded: PackedByteArray) -> bool:
	if encoded.size() < 33 or encoded.size() > MAX_PNG_BYTES or encoded.slice(0, 16) != PackedByteArray([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82]): return false
	var width: int = (int(encoded[16]) << 24) | (int(encoded[17]) << 16) | (int(encoded[18]) << 8) | int(encoded[19])
	var height: int = (int(encoded[20]) << 24) | (int(encoded[21]) << 16) | (int(encoded[22]) << 8) | int(encoded[23])
	return width == 384 and height == 384 and encoded[24] == 8 and encoded[25] == 6 and encoded[26] == 0 and encoded[27] == 0 and encoded[28] == 0

static func _raw_evidence(row: Dictionary) -> bool:
	if not _uint(row.get("decoded_bytes"), MAX_SOURCE_BYTES) or int(row.decoded_bytes) < 4 or not _uint(row.get("raw_header_u32"), 4294967295) or (int(row.raw_header_u32) & 4095) != int(row.get("blocks",0)) or (int(row.raw_header_u32) & 4096) == 0 or row.get("raw_decoded_roundtrip") != true:
		return false
	if not _uint(row.get("stored_pixels"), 256 * 576) or not _uint(row.get("palette_colors"), 256) or int(row.palette_colors) < 1: return false
	var sections: Variant = row.get("raw_sections")
	if not sections is Dictionary or sections.size() != 5: return false
	var end: int = 0
	for name: String in ["header", "palette", "flags", "descriptors", "indices"]:
		var section: Variant = sections.get(name)
		if not section is Dictionary or not _uint(section.get("offset"), MAX_SOURCE_BYTES) or int(section.offset) != end or not _uint(section.get("bytes"), MAX_SOURCE_BYTES) or not _sha(section.get("sha256")): return false
		end += int(section.bytes)
	return end == int(row.decoded_bytes) and int(sections.header.bytes) == 4 and int(sections.palette.bytes) == 1 + 2 * int(row.palette_colors) and int(sections.flags.bytes) == int(row.blocks) and int(sections.indices.bytes) == int(row.stored_pixels)

static func _provenance(value: Variant, source_sha256: String) -> bool:
	if not value is Dictionary or value.get("edition") != "LineageM" or not _uint(value.get("snapshot_version"), 523) or int(value.snapshot_version) != 523 or value.get("current_selection_verified") != true or not _uint(value.get("selection_version"), 523) or int(value.selection_version) < 1: return false
	if value.get("expected_member_sha256") != source_sha256 or not _sha(value.get("source_dat_sha256")) or not _sha(value.get("current_selected_dat_sha256")): return false
	if value.source_dat_sha256 != value.current_selected_dat_sha256:
		var proof: Variant = value.get("current_member_identity_proof")
		if not proof is Dictionary or proof.get("kind") != "EXACT_CURRENT523_MEMBER_SHA256" or proof.get("member_sha256") != source_sha256 or not _sha(proof.get("current_index_sha256")) or proof.current_index_sha256 == "0".repeat(64): return false
	var container: Variant = value.get("container")
	var evidence: Variant = value.get("evidence_level")
	if not container is String or not evidence is String or evidence.is_empty() or evidence.length() > 256: return false
	if not container.begins_with("Client/Data/Tile") or not container.ends_with(".dat"): return false
	var number: String = container.trim_prefix("Client/Data/Tile").trim_suffix(".dat")
	return not number.is_empty() and number[0] != "0" and number.is_valid_int() and str(number.to_int()) == number and number.to_int() > 0

static func _uint(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= float(maximum) and float(value) == floor(float(value))

static func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if not "0123456789abcdef".contains(character): return false
	return true

static func _hash(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
