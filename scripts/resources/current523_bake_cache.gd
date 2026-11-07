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

static func key(parts: Array) -> String:
	for part: Variant in parts:
		if not part is String or (part as String).is_empty(): return ""
	return ("|".join(PackedStringArray(parts))).sha256_text()

## The baked value for `name` when its key matches and its bytes verify; null otherwise.
static func read(name: String, expected_key: String) -> Variant:
	if expected_key.is_empty(): return null
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
	if expected_key.is_empty(): return ""
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(_meta(name)))
	if not meta is Dictionary or meta.get("schema") != SCHEMA or meta.get("key") != expected_key: return ""
	if _size(_data(name)) != int(meta.get("bytes", -1)) or FileAccess.get_sha256(_data(name)) != str(meta.get("sha256", "")): return ""
	return _data(name)

static func _size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return int(file.get_length()) if file != null else -1

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
