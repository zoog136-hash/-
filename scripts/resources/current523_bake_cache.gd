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
## Producers whose inputs are declared use producer_key() instead.
static func projection_key(name: String, source_sha256: String) -> String:
	return key([name, source_sha256, global_code_key()])

## Narrow key of a declared producer (current523_bake_producers.gd): the
## original identity (`source_key`), the producer's own `schema`, the bytes of
## exactly its transitive script/data inputs, this bake format and the engine
## version. An unrelated code change keeps it; any change of those inputs
## changes it. When the inputs cannot be established (unknown producer, file
## list out of date with the sources, a file that cannot be hashed) it is the
## global projection_key(), never a key without code. "" without an original.
const PRODUCERS = preload("res://scripts/resources/current523_bake_producers.gd")
const DEPENDENCIES = preload("res://scripts/resources/current523_bake_dependencies.gd")
const PRODUCER_KEY_FORMAT := "twilight.current523.producer-key.v1"
static var _producer_code: Dictionary = {}
## producer -> how its key was formed this run ("narrow:verified",
## "narrow:manifest" (sources not readable, e.g. exported as binary tokens),
## or "global:<reason>"), for start-up miss diagnostics.
static var producer_key_reasons: Dictionary = {}

static func producer_key(name: String, producer: String, schema: String, source_key: String) -> String:
	var code: String = producer_code_key(producer)
	if code.is_empty(): return projection_key(name, source_key)
	return producer_key_from(name, producer, schema, source_key, code)

## The key composition, separated so tests can feed synthetic inputs.
static func producer_key_from(name: String, producer: String, schema: String, source_key: String, code: String) -> String:
	return key([PRODUCER_KEY_FORMAT, name, producer, schema, source_key, engine_key(), SCHEMA, code])

static func engine_key() -> String:
	var version: Dictionary = Engine.get_version_info()
	return str(version.get("string","")) + "|" + str(version.get("hash",""))

## code_key() over the producer's declared inputs; "" (global key) when they
## cannot be established. Computed once per producer per run.
static func producer_code_key(producer: String) -> String:
	if _producer_code.has(producer): return _producer_code[producer]
	var result: Dictionary = producer_code(PRODUCERS.PRODUCERS.get(producer, {}))
	_producer_code[producer] = result.code
	producer_key_reasons[producer] = result.reason
	return result.code

## {code, reason} for one manifest entry {roots, ignore, files}. Where the
## sources are readable (editor, tests, text export) the scan must reproduce
## the declared list exactly; a stale list is refused, not trusted.
static func producer_code(entry: Dictionary, scheme: String = "res://", names: Variant = null) -> Dictionary:
	if entry.is_empty() or not entry.get("roots") is Array or not entry.get("files") is Array or (entry.files as Array).is_empty():
		return {"code": "", "reason": "global:unknown_producer"}
	var files := PackedStringArray(entry.files)
	var scan: Dictionary = DEPENDENCIES.closure(entry.roots, entry.get("ignore", []), scheme, names)
	var reason: String = "narrow:verified"
	if not (scan.unreadable as PackedStringArray).is_empty():
		# Exported scripts (binary tokens) cannot be scanned; only then is the
		# CI-verified list used as is (every root must be one of them).
		for root: Variant in entry.roots:
			if not (scan.unreadable as PackedStringArray).has(str(root)): return {"code": "", "reason": "global:partly_unreadable"}
		reason = "narrow:manifest"
	elif scan.files != files:
		return {"code": "", "reason": "global:manifest_stale"}
	var code: String = code_key(Array(files))
	if code.is_empty(): return {"code": "", "reason": "global:unhashable"}
	return {"code": code, "reason": reason}

## A baked projection payload {bytes, sha256, identity}; {} when absent/stale.
static func read_payload(name: String, value_key: String) -> Dictionary:
	var value: Variant = read(name, value_key)
	if not value is Dictionary or not value.get("bytes") is PackedByteArray or not value.get("sha256") is String or not value.get("identity") is Dictionary: return {}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(value.bytes)
	if hash.finish().hex_encode() != value.sha256: return {}
	return value

static func key(parts: Array) -> String:
	for part: Variant in parts:
		if not part is String or (part as String).is_empty(): return ""
	return ("|".join(PackedStringArray(parts))).sha256_text()

## The baked value for `name` when its key matches and its bytes verify; null otherwise.
static func read(name: String, expected_key: String) -> Variant:
	if expected_key.is_empty() or not FileAccess.file_exists(_meta(name)): return null
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(_meta(name)))
	if not meta is Dictionary or meta.get("schema") != SCHEMA or meta.get("key") != expected_key: return null
	if FileAccess.get_sha256(_data(name)) != str(meta.get("sha256", "")): return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_data(name))
	if bytes.size() != int(meta.get("bytes", -1)): return null
	return bytes_to_var(bytes)

static func write(name: String, value_key: String, value: Variant) -> bool:
	if value_key.is_empty(): return false
	DirAccess.make_dir_recursive_absolute(ROOT)
	var bytes: PackedByteArray = var_to_bytes(value)
	var file := FileAccess.open(_data(name) + ".part", FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	var stored: bool = file.get_error() == OK
	file.close()
	if not stored:
		DirAccess.remove_absolute(_data(name) + ".part")
		return false
	DirAccess.remove_absolute(_meta(name))
	if FileAccess.file_exists(_data(name)): DirAccess.remove_absolute(_data(name))
	if DirAccess.rename_absolute(_data(name) + ".part", _data(name)) != OK: return false
	var meta := FileAccess.open(_meta(name), FileAccess.WRITE)
	if meta == null: return false
	meta.store_string(JSON.stringify({"schema": SCHEMA, "key": value_key, "sha256": _sha(bytes), "bytes": bytes.size()}))
	meta.close()
	return true

## Where a file-format bake (written by its owner) lives.
static func data_path(name: String) -> String: return _data(name)

## Moves a finished `part` file into place and records its key and SHA256.
static func commit_file(name: String, value_key: String, part: String) -> bool:
	if value_key.is_empty(): return false
	DirAccess.remove_absolute(_meta(name))
	if FileAccess.file_exists(_data(name)): DirAccess.remove_absolute(_data(name))
	if DirAccess.rename_absolute(part, _data(name)) != OK: return false
	var meta := FileAccess.open(_meta(name), FileAccess.WRITE)
	if meta == null: return false
	meta.store_string(JSON.stringify({"schema": SCHEMA, "key": value_key, "sha256": FileAccess.get_sha256(_data(name)), "bytes": _size(_data(name))}))
	meta.close()
	return true

## The file of a file-format bake when its key matches and its bytes verify; "" otherwise.
static func verified_file(name: String, expected_key: String) -> String:
	if expected_key.is_empty() or not FileAccess.file_exists(_meta(name)): return ""
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(_meta(name)))
	if not meta is Dictionary or meta.get("schema") != SCHEMA or meta.get("key") != expected_key: return ""
	if _size(_data(name)) != int(meta.get("bytes", -1)) or FileAccess.get_sha256(_data(name)) != str(meta.get("sha256", "")): return ""
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
	if not stored or not commit_file(writer.name, writer.value_key, writer.part):
		DirAccess.remove_absolute(writer.part)
		return false
	return true

static func record_writer(name: String, value_key: String) -> RecordWriter:
	if value_key.is_empty(): return null
	DirAccess.make_dir_recursive_absolute(ROOT)
	var writer := RecordWriter.new()
	writer.part = _data(name) + ".part"
	writer.file = FileAccess.open(writer.part, FileAccess.WRITE)
	if writer.file == null: return null
	writer.name = name
	writer.value_key = value_key
	return writer

static func open_records(name: String, value_key: String) -> RecordFile:
	var path: String = verified_file(name, value_key)
	if path.is_empty(): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 8: return null
	file.seek(file.get_length() - 8)
	var index_position: int = file.get_64()
	if index_position < 0 or index_position >= file.get_length() - 8: return null
	file.seek(index_position)
	var index: Variant = file.get_var()
	if not index is Dictionary or index.get("schema") != SCHEMA or not index.get("ids") is PackedStringArray or not index.get("offsets") is PackedInt64Array: return null
	if (index.ids as PackedStringArray).size() != (index.offsets as PackedInt64Array).size(): return null
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
