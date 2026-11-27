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
const STARTUP_BAKES := preload("res://scripts/boot/startup_bake_pack.gd")

## Storage-failure policy of the first-run device bakes.
##
## Some producers are only bounded in memory because their result lives on
## storage (equipment rules catalog identities/runtime, item templates, big
## definition tables). When storage fails there are two possible policies:
##   resident fallback  the producer keeps the whole result in memory (the
##                      former behaviour; fine on desktop and CI).
##   disk-required      any writer create / append / commit / reopen / index
##                      failure is an explicit failure of that producer: no
##                      whole-result resident recompile, the previously
##                      accepted state stays as it was, the consumer is not
##                      activated, the cause and "retry on the next start" are
##                      reported, and only the producer's own unfinished .part
##                      file is removed (never an original, a save or another
##                      producer's file).
## Default: disk-required on Android and iOS (the low-memory targets, where
## the resident fallback is exactly the unbounded path that gets the process
## killed), resident fallback elsewhere, so desktop and CI behave as before.
## Physical memory is deliberately not part of the default: it would make the
## same build behave differently between CI machines.
## TWILIGHT_BAKE_DISK_REQUIRED=1 / =0 forces the policy (tests, diagnosis).
const DISK_REQUIRED_ENV := "TWILIGHT_BAKE_DISK_REQUIRED"
static func disk_required() -> bool:
	var forced: String = OS.get_environment(DISK_REQUIRED_ENV)
	if forced == "1": return true
	if forced == "0": return false
	return OS.get_name() in ["Android", "iOS"]

## Bakes whose last write on this run failed: name -> {op, reason}. A later
## successful write of the same name removes it. Only real storage failures
## (never "no_key": no original installed). Read by the boot notice.
static var store_failures: Dictionary = {}

## Test-only fault injection (never set in production): "<bake name>|<stage>"
## with stage "create" (record_writer), "append:<n>" (the n-th record write),
## "write" (write()), "commit" (publishing the finished file), "reopen"
## (open_records returns nothing) or "index" (the reopened index lacks its
## last record); while publishing a new generation also "verify" (the moved
## file does not read back), "meta" (the new metadata cannot be written) and
## "swap" (the metadata cannot replace the current one). It fails the same
## step the storage would fail.
static var fault: String = ""
static func _fault(name: String, stage: String) -> bool:
	return not fault.is_empty() and fault == name + "|" + stage

static func _failed(name: String, op: String, reason: String, fields: Dictionary = {}) -> void:
	store_failures[name] = {"op": op, "reason": reason}
	LOG.io(name, op, reason, fields)

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
	var entry := _checked_entry(name, expected_key)
	if entry.is_empty(): return null
	var meta: Dictionary = entry.meta
	var file := FileAccess.open(entry.path, FileAccess.READ)
	if file == null or file.get_length() != int(meta.get("bytes", -1)):
		LOG.cache(name, "verify_fail")
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if bytes.size() != int(meta.get("bytes", -1)) or _sha(bytes) != str(meta.get("sha256", "")):
		LOG.cache(name, "verify_fail")
		return null
	LOG.cache(name, "hit", {"bytes": bytes.size(), "seed": entry.get("seed", false)})
	return bytes_to_var(bytes)

## Local atomic generations have priority. A missing or outdated one can
## read a pinned startup seed at the exact key the original reader requested.
## Writers and cleanup keep using the local bake directory exclusively.
static func _checked_entry(name: String, expected_key: String, report: bool = true) -> Dictionary:
	if expected_key.is_empty():
		if report: LOG.cache(name, "no_key")
		return {}
	var reason := "missing"
	if FileAccess.file_exists(_meta(name)):
		var meta: Variant = _meta_value(name)
		reason = "corrupt"
		if meta is Dictionary:
			if meta.get("schema") != SCHEMA: reason = "schema_changed"
			elif meta.get("key") != expected_key: reason = "key_changed"
			else:
				var path := _data_for(name, meta)
				if not path.is_empty(): return {"meta": meta, "path": path}
	var seed := STARTUP_BAKES.entry(name, expected_key)
	if not seed.is_empty():
		seed["seed"] = true
		return seed
	if report: LOG.cache(name, reason)
	return {}

static func _meta_checked(name: String, expected_key: String) -> Variant:
	return _checked_entry(name, expected_key).get("meta")

static func write(name: String, value_key: String, value: Variant) -> bool:
	if value_key.is_empty():
		LOG.io(name, "write", "no_key")
		return false
	DirAccess.make_dir_recursive_absolute(ROOT)
	var bytes: PackedByteArray = var_to_bytes(value)
	var file := FileAccess.open(_data(name) + ".part", FileAccess.WRITE)
	if file == null:
		_failed(name, "write", "open_fail")
		return false
	var stored: bool = file.store_buffer(bytes) and file.get_error() == OK and not _fault(name, "write")
	file.close()
	if not stored:
		DirAccess.remove_absolute(_data(name) + ".part")
		_failed(name, "write", "write_fail", {"bytes": bytes.size()})
		return false
	return _publish(name, value_key, _data(name) + ".part", "write", bytes.size(), _sha(bytes))

## Where a file-format bake (written by its owner) lives: the current
## generation's data file (the legacy fixed name when none is recorded).
## Owners write their unfinished file next to it as data_path(name)+".part".
static func data_path(name: String) -> String:
	var path: String = _data_for(name, _meta_value(name))
	return path if not path.is_empty() else _data(name)

## Publishes a finished `part` file as the bake's new generation with its key
## and SHA256 (see _publish()).
static func commit_file(name: String, value_key: String, part: String) -> bool:
	if value_key.is_empty():
		LOG.io(name, "commit", "no_key")
		return false
	var size: int = _size(part)
	var digest: String = FileAccess.get_sha256(part) if size >= 0 else ""
	if _fault(name, "commit") or digest.is_empty():
		DirAccess.remove_absolute(part)
		_failed(name, "commit", "rename_fail")
		return false
	return _publish(name, value_key, part, "commit", size, digest)

## Replaces the bake with a new generation without ever losing the accepted
## one first. The finished part is moved to its own generation file and read
## back (size and SHA256); the new metadata - the only pointer readers follow
## - is written beside the current one, read back, and then replaces it in a
## single rename. Until that rename the previously accepted metadata and data
## are untouched, and any failure removes only the new generation's own
## files. A kept older cache stays under its own key, so a reader asking for a
## different key still misses: it is never used as the current data. Only
## after the swap are the superseded generation and stale leftovers removed.
static func _publish(name: String, value_key: String, part: String, op: String, size: int, digest: String) -> bool:
	var file_name: String = _generation_name(name)
	var target: String = ROOT + "/" + file_name
	if DirAccess.rename_absolute(part, target) != OK:
		DirAccess.remove_absolute(part)
		_failed(name, op, "rename_fail", {"bytes": size})
		return false
	if _fault(name, "verify") or _size(target) != size or FileAccess.get_sha256(target) != digest:
		DirAccess.remove_absolute(target)
		_failed(name, op, "verify_fail", {"bytes": size})
		return false
	var text: String = JSON.stringify({"schema": SCHEMA, "key": value_key, "sha256": digest, "bytes": size, "file": file_name})
	var meta_part: String = _meta(name) + ".part"
	var meta: FileAccess = null
	if not _fault(name, "meta"): meta = FileAccess.open(meta_part, FileAccess.WRITE)
	var meta_stored: bool = meta != null and meta.store_string(text) and meta.get_error() == OK
	if meta != null: meta.close()
	if not meta_stored or FileAccess.get_file_as_string(meta_part) != text:
		DirAccess.remove_absolute(meta_part)
		DirAccess.remove_absolute(target)
		_failed(name, op, "meta_fail", {"bytes": size})
		return false
	var previous: String = _data_for(name, _meta_value(name))
	if _fault(name, "swap") or DirAccess.rename_absolute(meta_part, _meta(name)) != OK:
		DirAccess.remove_absolute(meta_part)
		DirAccess.remove_absolute(target)
		_failed(name, op, "swap_fail", {"bytes": size})
		return false
	# The new generation is current: remove what it superseded.
	if not previous.is_empty() and previous != target: DirAccess.remove_absolute(previous)
	if FileAccess.file_exists(_data(name)): DirAccess.remove_absolute(_data(name))
	_remove_generations(name, file_name)
	store_failures.erase(name)
	LOG.io(name, op, "ok", {"bytes": size})
	return true

## "<name>.g<16 hex>.bin": a fresh generation file name for this bake.
static func _generation_name(name: String) -> String:
	return name + ".g" + Crypto.new().generate_random_bytes(8).hex_encode() + ".bin"

static func _is_generation(name: String, file_name: String) -> bool:
	if not file_name.begins_with(name + ".g") or not file_name.ends_with(".bin"): return false
	var token: String = file_name.trim_prefix(name + ".g").trim_suffix(".bin")
	return token.length() == 16 and token.is_valid_hex_number()

## The data file the metadata points to: its generation file, or the legacy
## fixed name for metadata written before generations existed; "" when the
## recorded file is not one of this bake's generation names.
static func _data_for(name: String, meta: Variant) -> String:
	if not meta is Dictionary or not (meta as Dictionary).has("file"): return _data(name)
	var file_name: Variant = meta.file
	if not file_name is String or not _is_generation(name, file_name): return ""
	return ROOT + "/" + file_name

static func _meta_value(name: String) -> Variant:
	if not FileAccess.file_exists(_meta(name)): return null
	return JSON.parse_string(FileAccess.get_file_as_string(_meta(name)))

## Removes this bake's generation files (and their unfinished parts) except `keep`.
static func _remove_generations(name: String, keep: String) -> void:
	var dir := DirAccess.open(ROOT)
	if dir == null: return
	for file_name: String in dir.get_files():
		var base: String = file_name.trim_suffix(".part")
		if base != keep and _is_generation(name, base): DirAccess.remove_absolute(ROOT + "/" + file_name)

## The file of a file-format bake when its key matches and its bytes verify; "" otherwise.
## True when a bake with this key and its declared size is present (no hash:
## a cheap "already compiled" test; readers still verify the bytes).
static func present(name: String, expected_key: String) -> bool:
	var entry := _checked_entry(name, expected_key, false)
	return not entry.is_empty() and _size(entry.path) == int(entry.meta.get("bytes", -2))

static func verified_file(name: String, expected_key: String) -> String:
	var entry := _checked_entry(name, expected_key)
	if entry.is_empty(): return ""
	var path: String = entry.path
	var size: int = _size(path)
	if size != int(entry.meta.get("bytes", -1)) or FileAccess.get_sha256(path) != str(entry.meta.get("sha256", "")):
		LOG.cache(name, "missing" if size < 0 else "verify_fail")
		return ""
	LOG.cache(name, "hit", {"bytes": size, "seed": entry.get("seed", false)})
	return path

static func _size(path: String) -> int:
	if path.is_empty(): return -1
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
	## False once a record could not be written; finish_records() then fails
	## (a short write is never committed as a complete file).
	var ok: bool = true
	## Injected fault (tests only), see `fault`.
	var fault_at: int = -1
	func add(id: String, value: Variant) -> void:
		positions.append(file.get_position())
		ids.append(id)
		if not file.store_var(value) or file.get_error() != OK or ids.size() == fault_at: ok = false
	func abort() -> void:
		file.close()
		DirAccess.remove_absolute(part)

static func finish_records(writer: RecordWriter) -> bool:
	var file: FileAccess = writer.file
	var index_position: int = file.get_position()
	var stored: bool = file.store_var({"schema": SCHEMA, "ids": writer.ids, "offsets": writer.positions})
	stored = file.store_64(index_position) and stored
	stored = stored and writer.ok and file.get_error() == OK
	file.close()
	if not stored: _failed(writer.name, "finish", "write_fail", {"records": writer.ids.size()})
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
	writer.file = null if _fault(name, "create") else FileAccess.open(writer.part, FileAccess.WRITE)
	if writer.file == null:
		_failed(name, "open_writer", "open_fail")
		return null
	writer.name = name
	writer.value_key = value_key
	if fault.begins_with(name + "|append:"): writer.fault_at = int(fault.trim_prefix(name + "|append:"))
	return writer

static func open_records(name: String, value_key: String) -> RecordFile:
	if _fault(name, "reopen"):
		LOG.io(name, "index", "open_fail")
		return null
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
	if _fault(name, "index") and not records.offsets.is_empty(): records.offsets.erase(index.ids[(index.ids as PackedStringArray).size() - 1])
	return records

static func clear(name: String) -> void:
	var current: String = _data_for(name, _meta_value(name))
	DirAccess.remove_absolute(_meta(name))
	if not current.is_empty(): DirAccess.remove_absolute(current)
	DirAccess.remove_absolute(_data(name))
	_remove_generations(name, "")

static func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

static func _meta(name: String) -> String: return ROOT + "/" + name + ".json"
static func _data(name: String) -> String: return ROOT + "/" + name + ".bin"
