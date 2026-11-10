extends RefCounted
## Device-local bake of results derived from the installed original 523.
##
## Mobile games ship data already compiled and only read it at runtime. The
## original 523 is private and installed by the player, so TWILIGHT compiles
## it once on the device and keeps the result here, keyed by everything the
## result depends on: the derived inputs' SHA256 and the SHA256 of the
## compiling scripts. Any mismatch, missing script hash or damaged file is a
## miss and the result is compiled again; a bake is never a substitute for
## the original (no original installed -> no key -> nothing is read).
## Files live only in user:// and are never part of the repository.

const ROOT := "user://current523_bake"
## Boot progress record: every lookup below logs hit/miss with its reason and
## every write logs its result (one short line each; never changes outcomes).
const LOG := preload("res://scripts/boot/boot_progress_log.gd")
const SCHEMA := "twilight.current523.bake.v1"

## SHA256 over the scripts' file hashes; "" when any script cannot be hashed
## (then nothing is baked or read).
static func code_key(paths: Array) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for path: String in paths:
		var digest: String = FileAccess.get_sha256(path)
		if digest.is_empty() and path.ends_with(".gd"): digest = FileAccess.get_sha256(path + "c")
		if digest.is_empty(): return ""
		hash.update((path + ":" + digest + "\n").to_utf8_buffer())
	return hash.finish().hex_encode()

## SHA256 over every file under res://scripts and res://data (paths and
## contents). Bakes whose producer depends on many modules use this, so any
## code or data change at all invalidates them. Computed once per run.
static var _global_code: String = ""
static func global_code_key() -> String:
	if not _global_code.is_empty(): return _global_code
	var files: PackedStringArray = []
	for root: String in ["res://scripts","res://data"]: _collect(root, files)
	files.sort()
	_global_code = code_key(Array(files)) if not files.is_empty() else ""
	return _global_code

static func _collect(directory: String, files: PackedStringArray) -> void:
	var dir := DirAccess.open(directory)
	if dir == null: return
	for name: String in dir.get_files(): files.append(directory.path_join(name))
	for name: String in dir.get_directories():
		if not name.begins_with("."): _collect(directory.path_join(name), files)

## Key for a projection derived only from the verified original and this
## game's code/data (every file under res://scripts and res://data).
static func projection_key(name: String, source_sha256: String) -> String:
	return key([name, source_sha256, global_code_key()])

## A baked projection payload {bytes, sha256, identity}; {} when absent/stale.
static func read_payload(name: String, value_key: String) -> Dictionary:
	var value: Variant = read(name, value_key)
	if value == null: return {}
	if not value is Dictionary or not value.get("bytes") is PackedByteArray or not value.get("sha256") is String or not value.get("identity") is Dictionary:
		LOG.io(name, "payload", "corrupt")
		return {}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(value.bytes)
	if hash.finish().hex_encode() != value.sha256:
		LOG.io(name, "payload", "verify_fail")
		return {}
	return value

static func key(parts: Array) -> String:
	for part: Variant in parts:
		if not part is String or (part as String).is_empty(): return ""
	return ("|".join(PackedStringArray(parts))).sha256_text()

## The baked value for `name` when its key matches and its bytes verify; null otherwise.
static func read(name: String, expected_key: String) -> Variant:
	var meta: Variant = _meta_checked(name, expected_key)
	if meta == null: return null
	if FileAccess.get_sha256(_data(name)) != str(meta.get("sha256", "")):
		LOG.cache(name, "verify_fail")
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_data(name))
	if bytes.size() != int(meta.get("bytes", -1)):
		LOG.cache(name, "verify_fail")
		return null
	LOG.cache(name, "hit", {"bytes": bytes.size()})
	return bytes_to_var(bytes)

## The bake's metadata when its schema and key match; null (logged with the
## miss reason) otherwise. Same conditions as before, only told apart.
static func _meta_checked(name: String, expected_key: String) -> Variant:
	if expected_key.is_empty():
		LOG.cache(name, "no_key")
		return null
	if not FileAccess.file_exists(_meta(name)):
		LOG.cache(name, "missing")
		return null
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(_meta(name)))
	if not meta is Dictionary:
		LOG.cache(name, "corrupt")
		return null
	if meta.get("schema") != SCHEMA:
		LOG.cache(name, "schema_changed")
		return null
	if meta.get("key") != expected_key:
		LOG.cache(name, "key_changed")
		return null
	return meta

static func write(name: String, value_key: String, value: Variant) -> bool:
	if value_key.is_empty():
		LOG.io(name, "write", "no_key")
		return false
	DirAccess.make_dir_recursive_absolute(ROOT)
	var bytes: PackedByteArray = var_to_bytes(value)
	var file := FileAccess.open(_data(name) + ".part", FileAccess.WRITE)
	if file == null:
		LOG.io(name, "write", "open_fail")
		return false
	file.store_buffer(bytes)
	var stored: bool = file.get_error() == OK
	file.close()
	if not stored:
		DirAccess.remove_absolute(_data(name) + ".part")
		LOG.io(name, "write", "write_fail", {"bytes": bytes.size()})
		return false
	DirAccess.remove_absolute(_meta(name))
	if FileAccess.file_exists(_data(name)): DirAccess.remove_absolute(_data(name))
	if DirAccess.rename_absolute(_data(name) + ".part", _data(name)) != OK:
		LOG.io(name, "write", "rename_fail", {"bytes": bytes.size()})
		return false
	var meta := FileAccess.open(_meta(name), FileAccess.WRITE)
	if meta == null:
		LOG.io(name, "write", "meta_fail", {"bytes": bytes.size()})
		return false
	meta.store_string(JSON.stringify({"schema": SCHEMA, "key": value_key, "sha256": _sha(bytes), "bytes": bytes.size()}))
	meta.close()
	LOG.io(name, "write", "ok", {"bytes": bytes.size()})
	return true

## Where a file-format bake (written by its owner) lives.
static func data_path(name: String) -> String: return _data(name)

## Moves a finished `part` file into place and records its key and SHA256.
static func commit_file(name: String, value_key: String, part: String) -> bool:
	if value_key.is_empty():
		LOG.io(name, "commit", "no_key")
		return false
	DirAccess.remove_absolute(_meta(name))
	if FileAccess.file_exists(_data(name)): DirAccess.remove_absolute(_data(name))
	if DirAccess.rename_absolute(part, _data(name)) != OK:
		LOG.io(name, "commit", "rename_fail")
		return false
	var meta := FileAccess.open(_meta(name), FileAccess.WRITE)
	if meta == null:
		LOG.io(name, "commit", "meta_fail")
		return false
	var size: int = _size(_data(name))
	meta.store_string(JSON.stringify({"schema": SCHEMA, "key": value_key, "sha256": FileAccess.get_sha256(_data(name)), "bytes": size}))
	meta.close()
	LOG.io(name, "commit", "ok", {"bytes": size})
	return true

## The file of a file-format bake when its key matches and its bytes verify; "" otherwise.
static func verified_file(name: String, expected_key: String) -> String:
	var meta: Variant = _meta_checked(name, expected_key)
	if meta == null: return ""
	var size: int = _size(_data(name))
	if size != int(meta.get("bytes", -1)) or FileAccess.get_sha256(_data(name)) != str(meta.get("sha256", "")):
		LOG.cache(name, "missing" if size < 0 else "verify_fail")
		return ""
	LOG.cache(name, "hit", {"bytes": size})
	return _data(name)

static func _size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return int(file.get_length()) if file != null else -1

## Keyed values on storage, read one at a time (offset indexed).
class RecordFile extends RefCounted:
	var file: FileAccess
	var offsets: Dictionary = {}
	func has(id: String) -> bool: return offsets.has(id)
	func read(id: String) -> Variant:
		if not offsets.has(id): return null
		file.seek(int(offsets[id]))
		return file.get_var()

static func write_records(name: String, value_key: String, ids: PackedStringArray, values: Array) -> bool:
	if value_key.is_empty() or ids.size() != values.size(): return false
	var writer := record_writer(name, value_key)
	if writer == null: return false
	for index: int in ids.size(): writer.add(ids[index], values[index])
	return finish_records(writer)

## Streams keyed values into a record bake one at a time (a later duplicate
## ID wins on read); finish_records() commits it, abort() discards it.
class RecordWriter extends RefCounted:
	var file: FileAccess
	var part: String
	var name: String
	var value_key: String
	var ids := PackedStringArray()
	var positions := PackedInt64Array()
	func add(id: String, value: Variant) -> void:
		positions.append(file.get_position())
		ids.append(id)
		file.store_var(value)
	func abort() -> void:
		file.close()
		DirAccess.remove_absolute(part)

static func finish_records(writer: RecordWriter) -> bool:
	var file: FileAccess = writer.file
	var index_position: int = file.get_position()
	file.store_var({"schema": SCHEMA, "ids": writer.ids, "offsets": writer.positions})
	file.store_64(index_position)
	var stored: bool = file.get_error() == OK
	file.close()
	if not stored: LOG.io(writer.name, "finish", "write_fail", {"records": writer.ids.size()})
	if not stored or not commit_file(writer.name, writer.value_key, writer.part):
		DirAccess.remove_absolute(writer.part)
		return false
	return true

static func record_writer(name: String, value_key: String) -> RecordWriter:
	if value_key.is_empty():
		LOG.io(name, "open_writer", "no_key")
		return null
	DirAccess.make_dir_recursive_absolute(ROOT)
	var writer := RecordWriter.new()
	writer.part = _data(name) + ".part"
	writer.file = FileAccess.open(writer.part, FileAccess.WRITE)
	if writer.file == null:
		LOG.io(name, "open_writer", "open_fail")
		return null
	writer.name = name
	writer.value_key = value_key
	return writer

static func open_records(name: String, value_key: String) -> RecordFile:
	var path: String = verified_file(name, value_key)
	if path.is_empty(): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 8:
		LOG.io(name, "index", "corrupt")
		return null
	file.seek(file.get_length() - 8)
	var index_position: int = file.get_64()
	if index_position < 0 or index_position >= file.get_length() - 8:
		LOG.io(name, "index", "corrupt")
		return null
	file.seek(index_position)
	var index: Variant = file.get_var()
	if not index is Dictionary or index.get("schema") != SCHEMA or not index.get("ids") is PackedStringArray or not index.get("offsets") is PackedInt64Array:
		LOG.io(name, "index", "schema_changed" if index is Dictionary and index.get("schema") != SCHEMA else "corrupt")
		return null
	if (index.ids as PackedStringArray).size() != (index.offsets as PackedInt64Array).size():
		LOG.io(name, "index", "corrupt")
		return null
	var records := RecordFile.new()
	records.file = file
	for position: int in (index.ids as PackedStringArray).size(): records.offsets[index.ids[position]] = index.offsets[position]
	return records

static func clear(name: String) -> void:
	DirAccess.remove_absolute(_meta(name))
	DirAccess.remove_absolute(_data(name))

static func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

static func _meta(name: String) -> String: return ROOT + "/" + name + ".json"
static func _data(name: String) -> String: return ROOT + "/" + name + ".bin"
