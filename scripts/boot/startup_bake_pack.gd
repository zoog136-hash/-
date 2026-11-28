extends RefCounted
## An optional, release-pinned seed of the game's own first-run bakes.
## No saves, configuration, originals or executable resources are mounted.
const PIN_PATH := "res://startup_bake_pin.json"
const REUSE_PATH := "res://startup_bake_reuse.json"
const REUSE_SCHEMA := "twilight.current523.startup-bake-reuse.v1"
const FOLDER := "startup_bakes"
const INDEX := "startup_bakes.json"
const SCHEMA := "twilight.current523.startup-bakes.v1"
const CHUNK := 1024 * 1024
const MAX_INDEX := 256 * 1024
const MAX_FILES := 700
const MAX_PAYLOAD := 1536 * 1024 * 1024

static var _root := ""
static var _files: Dictionary = {}
static var _installed_index := ""
static var _reuse: Dictionary = {}

var _zip: ZIPReader
var _target := ""
var _manifest: PackedByteArray
var _entries: Dictionary
var _names: Array
var _file_index := 0
var _chunk_index := 0
var _length := 0
var _key := ""
var _written := 0
var _total := 0
var _output: FileAccess
var _digest: HashingContext
var done := false
var problem := ""

static func _sha(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

static func pin() -> Dictionary:
	var file := FileAccess.open(PIN_PATH, FileAccess.READ)
	if file == null or file.get_length() < 2 or file.get_length() > 4096: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary or not _sha(value.get("archive_sha256")) or not _sha(value.get("index_sha256")): return {}
	if not _size_ok(value.get("archive_bytes")): return {}
	return value

static func _size_ok(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value == floorf(float(value)) and value > 0 and value <= MAX_PAYLOAD

static func _hash(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()

static func _decode(bytes: PackedByteArray, expected: String) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_INDEX or _hash(bytes) != expected: return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("schema") != SCHEMA or not parsed.get("files") is Dictionary: return {}
	var files: Dictionary = parsed.files
	if files.is_empty() or files.size() > MAX_FILES: return {}
	var total: int = 0
	for key: String in files:
		if not key.is_valid_identifier() or key.length() > 180: return {}
		var entry: Variant = files[key]
		if not entry is Dictionary or not _sha(entry.get("key")) or not _sha(entry.get("sha256")): return {}
		var length: Variant = entry.get("bytes")
		if not _size_ok(length): return {}
		total += int(length)
		if total > MAX_PAYLOAD: return {}
	return files

## The manifest is a resource of the new release. The release builder only
## lists entries whose independently produced output bytes match a pinned older
## archive. A device still needs the current producer key and verified bytes.
static func _decode_reuse(bytes: PackedByteArray, source: String) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_INDEX or not _sha(source): return {}
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	var version: Dictionary = Engine.get_version_info()
	var engine := str(version.get("string", "")) + "|" + str(version.get("hash", ""))
	if not value is Dictionary or value.get("schema") != REUSE_SCHEMA or value.get("engine") != engine: return {}
	if value.get("source") != source or not value.get("files") is Dictionary: return {}
	var index: Variant = value.get("index_sha256")
	if not index is String or (not index.is_empty() and not _sha(index)): return {}
	var files: Dictionary = value.files
	if files.size() > MAX_FILES: return {}
	for name: String in files:
		var row: Variant = files[name]
		if not name.is_valid_identifier() or name.length() > 180 or not row is Dictionary: return {}
		if not _sha(row.get("previous_key")) or not _sha(row.get("key")) or row.previous_key == row.key: return {}
		if not _sha(row.get("sha256")) or not _size_ok(row.get("bytes")): return {}
	return {"index_sha256": index, "files": files}

static func reusable(name: String, previous: Dictionary, current_key: String) -> bool:
	var row: Variant = (_reuse.get("files", {}) as Dictionary).get(name)
	return row is Dictionary and row.key == current_key and row.previous_key == previous.get("key") \
		and row.sha256 == previous.get("sha256") and row.bytes == previous.get("bytes")

## The installed pack selection owns this path. Nothing is extracted
## at startup. Every consumer still requests its original, code-keyed bake.
static func select(base: String, expected: String, source: String = "") -> void:
	_root = ""
	_files = {}
	_installed_index = ""
	_reuse = {}
	if base.is_empty(): return
	# Device caches can be proven independently of the optional seed pin.
	var proof := FileAccess.open(REUSE_PATH, FileAccess.READ)
	if proof != null and proof.get_length() <= MAX_INDEX:
		_reuse = _decode_reuse(proof.get_buffer(proof.get_length()), source)
	if not _sha(expected): return
	var directory := base.path_join(FOLDER).path_join(expected)
	var file := FileAccess.open(directory.path_join(INDEX), FileAccess.READ)
	if file == null or file.get_length() > MAX_INDEX: return
	_files = _decode(file.get_buffer(file.get_length()), expected)
	if not _files.is_empty():
		_root = directory
		_installed_index = expected

static func entry(name: String, key: String) -> Dictionary:
	if _root.is_empty(): return {}
	var meta: Variant = _files.get(name)
	if not meta is Dictionary: return {}
	var reused: bool = meta.key != key
	# Only a proof generated against this authenticated installed index
	# can change its keys. A device-cache proof has an empty index.
	if reused and (_reuse.get("index_sha256") != _installed_index or not reusable(name, meta, key)): return {}
	return {"meta": meta, "path": _root.path_join(name + ".bin"), "reused": reused}

## The caller hashes the installer-owned ZIP copy before opening it.
func begin(path: String, base: String, installed_pin: Dictionary, archive_sha: String) -> bool:
	if not _sha(archive_sha) or installed_pin.get("archive_sha256") != archive_sha or not _sha(installed_pin.get("index_sha256")): return false
	_zip = ZIPReader.new()
	if _zip.open(path) != OK: return false
	_manifest = _zip.read_file(INDEX)
	var expected: String = installed_pin.index_sha256
	_entries = _decode(_manifest, expected)
	if _entries.is_empty(): return false
	_target = base.path_join(FOLDER).path_join(expected)
	if DirAccess.make_dir_recursive_absolute(_target) != OK: return false
	_names = _entries.keys()
	for row: Dictionary in _entries.values(): _total += int(row.bytes)
	return true

func progress_text() -> String:
	return "시작 데이터 설치 중 · %d / %d MB" % [_written >> 20, _total >> 20]

## One bounded decompression/write per step. A published manifest only
## references authenticated files. Each replacement is atomic on restart.
func advance() -> void:
	if done or not problem.is_empty(): return
	if _file_index == _names.size():
		var pending := _target.path_join(INDEX + ".part")
		var file := FileAccess.open(pending, FileAccess.WRITE)
		if file == null: _fail("index_open"); return
		var saved := file.store_buffer(_manifest) and file.get_error() == OK
		file.close()
		if not saved or DirAccess.rename_absolute(pending, _target.path_join(INDEX)) != OK: _fail("index_write"); return
		done = true
		return
	if _output == null:
		_key = _names[_file_index]
		_length = int(_entries[_key].bytes)
		_chunk_index = 0
		_output = FileAccess.open(_target.path_join(_key + ".part"), FileAccess.WRITE)
		if _output == null: _fail("data_open"); return
		_digest = HashingContext.new()
		_digest.start(HashingContext.HASH_SHA256)
	var chunk := _zip.read_file("data/%s/%d" % [_key, _chunk_index])
	var count := mini(CHUNK, _length - _chunk_index * CHUNK)
	if chunk.size() != count or _digest.update(chunk) != OK or not _output.store_buffer(chunk) or _output.get_error() != OK:
		_fail("data_write"); return
	_written += count
	_chunk_index += 1
	if _chunk_index * CHUNK < _length: return
	_output.close()
	_output = null
	if _digest.finish().hex_encode() != _entries[_key].sha256 or DirAccess.rename_absolute(_target.path_join(_key + ".part"), _target.path_join(_key + ".bin")) != OK:
		_fail("data_verify"); return
	_key = ""
	_file_index += 1

func _fail(reason: String) -> void:
	problem = reason
	close()

func close() -> void:
	if _zip != null:
		_zip.close()
		_zip = null
	if _output != null:
		_output.close()
		_output = null
	if not _target.is_empty():
		if not _key.is_empty(): DirAccess.remove_absolute(_target.path_join(_key + ".part"))
		DirAccess.remove_absolute(_target.path_join(INDEX + ".part"))
