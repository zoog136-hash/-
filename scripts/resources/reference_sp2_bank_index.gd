extends RefCounted
## Cold actor-bank preparation uses the existing verified record format.
## Keep the shared manifest reader and its code identity for definition-table
## consumers and installed bakes.
const INDEX = preload("res://scripts/resources/reference_sp2_manifest_index.gd")
const BAKE = INDEX.BAKE
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

static func open(path: String, expected: String, maximum: int, valid_sha: bool) -> Dictionary:
	var shared: RefCounted = INDEX._shared.get(expected)
	if shared != null:
		# The reader already has this verified pin. One size probe also
		# establishes existence; a changed stamp uses the full reader again.
		var pin: Variant = INDEX._pins.get(path)
		if valid_sha and pin is Array and pin[0] == expected and pin[1] > 0 and pin[1] <= maximum:
			if FileAccess.get_size(path) == pin[1] and FileAccess.get_modified_time(path) == pin[2]:
				return {"ok":true,"index":shared}
		return INDEX.open(path,expected,maximum,valid_sha)
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > maximum:
		return {"ok":false,"error":"Missing or oversized bank JSON: " + path}
	file.close()
	if not valid_sha or not INDEX.pinned(path,expected):
		return {"ok":false,"error":"Bank JSON SHA256 mismatch: " + path}
	var key: String = BAKE.key([expected,BAKE.code_key(INDEX.CODE)])
	var index := INDEX.new()
	if not index._open_bake(key):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty() or BAKE._sha(bytes) != expected:
			return {"ok":false,"error":"Bank JSON SHA256 mismatch: " + path}
		var started: int = FRAME_HITCH.now()
		# An empty bake key uses the original whole-JSON fallback directly.
		var built: Dictionary = {"ok":true} if _bake_registries(index,bytes,key) else index._build(bytes,"")
		FRAME_HITCH.detail("sp2.index_build",started)
		if not built.ok:return built
	INDEX._shared[expected] = index
	return {"ok":true,"index":index}

static func _bake_registries(index: RefCounted, bytes: PackedByteArray, key: String) -> bool:
	var writers: Dictionary = {}
	for registry: String in INDEX.SPLIT:
		var writer = BAKE.record_writer("sp2_manifest_" + registry,key)
		if writer == null:break
		writers[registry] = writer
	var split: Dictionary = _split_once(bytes,writers) if writers.size() == INDEX.SPLIT.size() else {}
	var stored: bool = not split.is_empty()
	for registry: String in writers:
		if stored and split.kinds.has(registry):stored = BAKE.finish_records(writers[registry])
		else:writers[registry].abort()
	if not stored:return false
	return BAKE.write("sp2_manifest_top",key,{"top":split.top,"kinds":split.kinds}) and index._open_bake(key)

## Read the registry's member boundaries as soon as its top-level key is
## seen. The regular reader first scans past the whole value, then repeats
## that walk to find each actor or member. Individual values still use JSON.
static func _split_once(bytes: PackedByteArray, writers: Dictionary) -> Dictionary:
	var at: int = INDEX._space(bytes,0)
	if at >= bytes.size() or bytes[at] != 123:return {}
	var cursor: int = INDEX._space(bytes,at + 1)
	var top: Dictionary = {}
	var kinds: Dictionary = {}
	var parser := JSON.new()
	while cursor < bytes.size() and bytes[cursor] == 34:
		var key_end: int = INDEX._string_end(bytes,cursor)
		if key_end < 0:return {}
		var name: Variant = INDEX._parse(bytes,cursor,key_end)
		if not name is String:return {}
		var colon: int = INDEX._space(bytes,key_end)
		if colon >= bytes.size() or bytes[colon] != 58:return {}
		var start: int = INDEX._space(bytes,colon + 1)
		if start >= bytes.size():return {}
		var end: int
		if name in INDEX.SPLIT:
			if kinds.has(name) or bytes[start] != 123:return {}
			end = _write_registry(bytes,start,writers[name],parser)
			if end < 0:return {}
			kinds[name] = TYPE_DICTIONARY
		else:
			end = INDEX._value_end(bytes,start)
			if end < 0:return {}
			if parser.parse(bytes.slice(start,end).get_string_from_utf8()) != OK:return {}
			top[name] = parser.data
		cursor = INDEX._space(bytes,end)
		if cursor >= bytes.size():return {}
		if bytes[cursor] == 125:break
		if bytes[cursor] != 44:return {}
		cursor = INDEX._space(bytes,cursor + 1)
		if cursor >= bytes.size() or bytes[cursor] != 34:return {}
	if cursor >= bytes.size() or bytes[cursor] != 125 or INDEX._space(bytes,cursor + 1) != bytes.size():return {}
	return {"top":top,"kinds":kinds}

## Stream each verified member into the existing record writer. Only the
## current value is retained while finding the next member's boundary.
static func _write_registry(bytes: PackedByteArray, start: int, writer: RefCounted, parser: JSON) -> int:
	var cursor: int = INDEX._space(bytes,start + 1)
	if cursor < bytes.size() and bytes[cursor] == 125:return cursor + 1
	while cursor < bytes.size() and bytes[cursor] == 34:
		var key_end: int = INDEX._string_end(bytes,cursor)
		if key_end < 0 or parser.parse(bytes.slice(cursor,key_end).get_string_from_utf8()) != OK or not parser.data is String:return -1
		var key: String = parser.data
		var colon: int = INDEX._space(bytes,key_end)
		if colon >= bytes.size() or bytes[colon] != 58:return -1
		var value_start: int = INDEX._space(bytes,colon + 1)
		var end: int = INDEX._value_end(bytes,value_start)
		if end < 0 or parser.parse(bytes.slice(value_start,end).get_string_from_utf8()) != OK:return -1
		writer.add(key,parser.data)
		cursor = INDEX._space(bytes,end)
		if cursor >= bytes.size():return -1
		if bytes[cursor] == 125:return cursor + 1
		if bytes[cursor] != 44:return -1
		cursor = INDEX._space(bytes,cursor + 1)
	return -1
