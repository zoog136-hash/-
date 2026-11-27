@tool
extends RefCounted
## Binary copies of selected, shipped JSON documents. An exported build can
## skip UTF-8 conversion and JSON parsing, and still use the active JSON when
## a companion is missing, damaged, or came from a different layered pack.
const PATHS := [
	"res://data/catalog_v19.json",
	"res://data/game_db_v17.json",
	"res://data/skills/master.json",
	"res://data/skills/official_roster.json",
	"res://data/collections/equipment_collections.json",
]
const CACHE_DIR := "res://prepared_startup/v1/"
const SHA_BYTES := 32
const HEADER_BYTES := 2 * SHA_BYTES + 4
const LIMIT := 16 * 1024 * 1024

static func read_json(path: String) -> Variant:
	if path in PATHS:
		var prepared: Variant = _read_companion(path)
		if prepared != null: return prepared
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func companion_path(path: String) -> String:
	return CACHE_DIR + path.trim_prefix("res://") + ".bin"

static func compile_json(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > LIMIT: return PackedByteArray()
	var source := file.get_buffer(file.get_length())
	var value: Variant = JSON.parse_string(source.get_string_from_utf8())
	if not (value is Dictionary or value is Array): return PackedByteArray()
	var data := var_to_bytes(value)
	if data.is_empty() or data.size() > LIMIT: return PackedByteArray()
	var compressed := data.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.is_empty() or compressed.size() > LIMIT: return PackedByteArray()
	var header := _sha(source)
	header.append_array(_sha(compressed))
	header.resize(HEADER_BYTES)
	header.encode_u32(2 * SHA_BYTES, data.size())
	header.append_array(compressed)
	return header

static func _read_companion(path: String) -> Variant:
	var file := FileAccess.open(companion_path(path), FileAccess.READ)
	if file == null: return null
	var length := file.get_length()
	if length <= HEADER_BYTES or length > HEADER_BYTES + LIMIT: return null
	var source_sha := file.get_buffer(SHA_BYTES)
	var body_sha := file.get_buffer(SHA_BYTES)
	var unpacked_size := file.get_32()
	if unpacked_size <= 0 or unpacked_size > LIMIT: return null
	if source_sha.hex_encode() != FileAccess.get_sha256(path): return null
	var compressed := file.get_buffer(length - HEADER_BYTES)
	if compressed.size() != length - HEADER_BYTES or _sha(compressed) != body_sha: return null
	var data := compressed.decompress(unpacked_size, FileAccess.COMPRESSION_ZSTD)
	if data.size() != unpacked_size: return null
	var value: Variant = bytes_to_var(data)
	return value if value is Dictionary or value is Array else null

static func _sha(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()
