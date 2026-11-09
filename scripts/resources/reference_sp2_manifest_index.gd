extends RefCounted
## Shared, storage-backed view of one pinned SP2 bank manifest (Lineage M style).
##
## The complete-client bank manifest is ~40 MB of JSON (tens of thousands of
## actors and raw members). Parsing it whole costs ~0.6 GB per parse, and every
## actor's bank used to parse it again. Here it is split once per device into
## per-actor and per-member records in user:// (keyed by the manifest SHA256
## and this code), and one opened index is shared by every bank in the process.
## Lookups return exactly what the parsed manifest held (same JSON values);
## top-level fields other than `actors`/`members` stay in memory.
## The split never substitutes for verification: the manifest bytes are checked
## against the caller's SHA256 before an index is built or reused.

const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const CODE: Array[String] = ["res://scripts/resources/reference_sp2_manifest_index.gd","res://scripts/resources/current523_bake_cache.gd"]
const SPLIT: Array[String] = ["actors","members"]

var top: Dictionary = {}
var registry_kinds: Dictionary = {} # "actors"/"members" -> typeof() of the parsed value
var _files: Dictionary = {} # registry -> BAKE.RecordFile
var _values: Dictionary = {} # registry -> parsed value (fallback when not split)

static var _shared: Dictionary = {} # manifest SHA256 -> index
static var _pins: Dictionary = {} # path -> [sha256, bytes, modified_time]

## The value the parsed manifest held under registry[key], or null when absent.
func lookup(registry: String, key: String) -> Variant:
	if _values.has(registry):
		var value: Variant = _values[registry]
		return (value as Dictionary).get(key) if value is Dictionary else null
	var records: Variant = _files.get(registry)
	return records.read(key) if records != null else null

func contains(registry: String, key: String) -> bool:
	if _values.has(registry):
		var value: Variant = _values[registry]
		return value is Dictionary and (value as Dictionary).has(key)
	var records: Variant = _files.get(registry)
	return records != null and records.has(key)

func registry_is_dictionary(registry: String) -> bool:
	return int(registry_kinds.get(registry, TYPE_NIL)) == TYPE_DICTIONARY

## True when the file at `path` has SHA256 `sha`. A file already verified in
## this process is not hashed again while its size and modification time are
## unchanged (any rewrite changes them and is hashed again).
static func pinned(path: String, sha: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var size: int = int(file.get_length())
	file.close()
	var modified: int = int(FileAccess.get_modified_time(path))
	var known: Variant = _pins.get(path)
	if known is Array and known[0] == sha and known[1] == size and known[2] == modified: return true
	var actual: String = FileAccess.get_sha256(path)
	if actual != sha:
		_pins.erase(path)
		return false
	_pins[path] = [sha, size, modified]
	return true

## {ok, index} for the manifest at `path` pinned to `expected`, or the same
## failures the whole-file reader reported.
static func open(path: String, expected: String, maximum: int, valid_sha: bool) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > maximum: return {"ok":false,"error":"Missing or oversized bank JSON: " + path}
	file.close()
	if not valid_sha or not pinned(path, expected): return {"ok":false,"error":"Bank JSON SHA256 mismatch: " + path}
	if _shared.has(expected): return {"ok":true,"index":_shared[expected]}
	var key: String = BAKE.key([expected, BAKE.code_key(CODE)])
	var index = new()
	if not index._open_bake(key):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.size() <= 0 or BAKE._sha(bytes) != expected: return {"ok":false,"error":"Bank JSON SHA256 mismatch: " + path}
		var built: Dictionary = index._build(bytes, key)
		if not built.ok: return built
	_shared[expected] = index
	return {"ok":true,"index":index}

func _open_bake(key: String) -> bool:
	var meta: Variant = BAKE.read("sp2_manifest_top", key)
	if not meta is Dictionary or not meta.get("top") is Dictionary or not meta.get("kinds") is Dictionary: return false
	var files: Dictionary = {}
	for registry: String in SPLIT:
		if int(meta.kinds.get(registry, TYPE_NIL)) != TYPE_DICTIONARY: continue
		var records = BAKE.open_records("sp2_manifest_" + registry, key)
		if records == null: return false
		files[registry] = records
	top = meta.top
	registry_kinds = meta.kinds
	_files = files
	return true

## Splits the verified bytes, streaming each actor/member record to storage.
## Falls back to one whole parse (kept in memory, same values) when the bytes
## are not a plain JSON object this scanner reads, or storage is unavailable.
func _build(bytes: PackedByteArray, key: String) -> Dictionary:
	var writers: Dictionary = {}
	for registry: String in SPLIT:
		var writer = BAKE.record_writer("sp2_manifest_" + registry, key)
		if writer == null: break
		writers[registry] = writer
	var split: Dictionary = _split(bytes, writers) if writers.size() == SPLIT.size() else {}
	var stored: bool = not split.is_empty()
	for registry: String in writers:
		if stored and split.kinds.has(registry): stored = BAKE.finish_records(writers[registry])
		else: writers[registry].abort()
	if stored: stored = BAKE.write("sp2_manifest_top", key, {"top":split.top,"kinds":split.kinds})
	if stored and _open_bake(key): return {"ok":true}
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary: return {"ok":false,"error":"Bank JSON is not an object."}
	top = {}
	registry_kinds = {}
	for name: Variant in value:
		if name in SPLIT:
			registry_kinds[name] = typeof(value[name])
			_values[name] = value[name]
		else: top[name] = value[name]
	return {"ok":true}

## {top, kinds} after streaming every member of the `actors`/`members` objects
## to `writers`, or {} when the bytes are not one JSON object whose members
## each parse on their own (or a registry is not an object). A later duplicate
## key wins, as in a whole parse.
static func _split(bytes: PackedByteArray, writers: Dictionary) -> Dictionary:
	var at: int = _space(bytes, 0)
	if at >= bytes.size() or bytes[at] != 123: return {}
	var top_values: Dictionary = {}
	var kinds: Dictionary = {}
	var members: Array = _members(bytes, at)
	if members.is_empty() or _space(bytes, members[0]) != bytes.size(): return {}
	for member: Array in members[1]:
		var name: Variant = _parse(bytes, member[0], member[1])
		if not name is String: return {}
		var start: int = member[2]
		var end: int = member[3]
		if name in SPLIT:
			if kinds.has(name) or bytes[start] != 123: return {} # rare: whole parse
			var inner: Array = _members(bytes, start)
			if inner.is_empty() or inner[0] != end: return {}
			for entry: Array in inner[1]:
				var entry_key: Variant = _parse(bytes, entry[0], entry[1])
				var parser := JSON.new()
				if not entry_key is String or parser.parse(bytes.slice(entry[2], entry[3]).get_string_from_utf8()) != OK: return {}
				writers[name].add(entry_key, parser.data)
			kinds[name] = TYPE_DICTIONARY
		else:
			var parser := JSON.new()
			if parser.parse(bytes.slice(start, end).get_string_from_utf8()) != OK: return {}
			top_values[name] = parser.data
	return {"top":top_values,"kinds":kinds}

static func _parse(bytes: PackedByteArray, start: int, end: int) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(bytes.slice(start, end).get_string_from_utf8()) == OK else null

## [end, [[key_start, key_end, value_start, value_end], ...]] for the object
## at `at` ('{'), or [] when it is not a well-formed object.
static func _members(bytes: PackedByteArray, at: int) -> Array:
	var result: Array = []
	var index: int = _space(bytes, at + 1)
	if index < bytes.size() and bytes[index] == 125: return [index + 1, result]
	while index < bytes.size():
		if bytes[index] != 34: return []
		var key_end: int = _string_end(bytes, index)
		if key_end < 0: return []
		var colon: int = _space(bytes, key_end)
		if colon >= bytes.size() or bytes[colon] != 58: return []
		var value_start: int = _space(bytes, colon + 1)
		var value_end: int = _value_end(bytes, value_start)
		if value_end < 0: return []
		result.append([index, key_end, value_start, value_end])
		index = _space(bytes, value_end)
		if index >= bytes.size(): return []
		if bytes[index] == 125: return [index + 1, result]
		if bytes[index] != 44: return []
		index = _space(bytes, index + 1)
	return []

static func _space(bytes: PackedByteArray, at: int) -> int:
	var index: int = at
	while index < bytes.size() and bytes[index] in [32, 9, 10, 13]: index += 1
	return index

static func _string_end(bytes: PackedByteArray, at: int) -> int:
	var index: int = at + 1
	while true:
		var quote: int = bytes.find(34, index)
		if quote < 0: return -1
		var slashes: int = 0
		var back: int = quote - 1
		while back > at and bytes[back] == 92:
			slashes += 1
			back -= 1
		if slashes % 2 == 0: return quote + 1
		index = quote + 1
	return -1

static func _value_end(bytes: PackedByteArray, at: int) -> int:
	if at >= bytes.size(): return -1
	var first: int = bytes[at]
	if first == 34: return _string_end(bytes, at)
	if first == 123 or first == 91:
		var depth: int = 0
		var index: int = at
		while index < bytes.size():
			var current: int = bytes[index]
			if current == 34:
				index = _string_end(bytes, index)
				if index < 0: return -1
				continue
			if current == 123 or current == 91: depth += 1
			elif current == 125 or current == 93:
				depth -= 1
				if depth == 0: return index + 1
			index += 1
		return -1
	var index: int = at
	while index < bytes.size() and not bytes[index] in [44, 125, 93, 32, 9, 10, 13]: index += 1
	return index if index > at else -1
