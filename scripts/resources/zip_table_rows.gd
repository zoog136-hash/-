extends RefCounted
## Reads one original table ("content/<Table>.json" in the pinned 523 ZIP) a
## few MB at a time instead of as one string and one parsed document. A 50 MB
## table parsed whole takes about ten times its size in memory (UTF-32 text
## plus dictionaries) for a moment; callers that need a few hundred rows keep
## only those.
##
## Each window holds whole rows and goes through the same JSON parser, so the
## kept rows are exactly the rows a whole-document parse gives. Only the
## pack's "rows" layout (one row object per 4-space indented block, LF or CRLF,
## optional BOM) is walked this way; any other layout is parsed whole.
const WINDOW_BYTES := 1024 * 1024

## {"ok", "rows": kept rows in table order, "count": all rows, "duplicate":
## whether `key_field` repeats anywhere in the table, "missing": whether some
## row lacks `key_field`, "values": the `collect_field` value of every row that
## has it (PackedInt64Array, only when asked)}.
## Kept rows: every row when `keep_all`, else rows whose int(key) is in `wanted`.
## With `digest`, the result also has "sha256": the member bytes' SHA256 hex.
static func scan(archive: ZIPReader, table: String, key_field: String = "ID", wanted: Dictionary = {}, collect_field: String = "", keep_all: bool = false, digest: bool = false) -> Dictionary:
	var path: String = "content/" + table + ".json"
	if not archive.file_exists(path): return {"ok":false, "rows":[], "count":0, "duplicate":false, "missing":false, "values":PackedInt64Array()}
	var bytes: PackedByteArray = archive.read_file(path)
	var sha256: String = ""
	if digest:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		sha256 = hashing.finish().hex_encode()
	var state: Dictionary = {"rows":[], "count":0, "duplicate":false, "missing":false, "ids":PackedInt64Array(), "values":PackedInt64Array()}
	var walked: bool = _walk(bytes, state, key_field, wanted, collect_field, keep_all)
	if not walked:
		state = {"rows":[], "count":0, "duplicate":false, "missing":false, "ids":PackedInt64Array(), "values":PackedInt64Array()}
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8().trim_prefix("﻿"))
		bytes = PackedByteArray()
		var rows: Variant = document.get("rows", []) if document is Dictionary else []
		if rows is Array: _take(rows, state, key_field, wanted, collect_field, keep_all)
	# Repeated keys anywhere in the table: one sorted integer array instead of
	# a dictionary of every key (a few MB instead of tens for 300k rows).
	var ids: PackedInt64Array = state.ids
	ids.sort()
	for index: int in range(1, ids.size()):
		if ids[index] == ids[index - 1]:
			state.duplicate = true
			break
	state.ids = PackedInt64Array()
	var result: Dictionary = {"ok":true, "rows":state.rows, "count":state.count, "duplicate":state.duplicate, "missing":state.missing, "values":state.values}
	if digest: result["sha256"] = sha256
	return result

static func _take(rows: Array, state: Dictionary, key_field: String, wanted: Dictionary, collect_field: String, keep_all: bool) -> void:
	for row: Variant in rows:
		state.count += 1
		if not row is Dictionary:
			state.missing = true
			continue
		var key: Variant = row.get(key_field)
		if key != null:
			var id: int = int(key)
			state.ids.append(id)
			if keep_all or wanted.has(id): state.rows.append(row)
		else:
			state.missing = true
			if keep_all: state.rows.append(row)
		if not collect_field.is_empty() and row.get(collect_field) != null: state.values.append(int(row[collect_field]))

static func _walk(bytes: PackedByteArray, state: Dictionary, key_field: String, wanted: Dictionary, collect_field: String, keep_all: bool) -> bool:
	var start: int = 3 if bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf else 0
	var head: String = bytes.slice(start, mini(bytes.size(), start + 64)).get_string_from_utf8()
	var nl: String = "\r\n" if head.begins_with("{\r\n") else "\n"
	if not head.begins_with("{" + nl + "  \"rows\": [" + nl + "    {" + nl): return false
	var row_end: String = nl + "    }," + nl
	var position: int = bytes.find(0x5b, start) + 1
	while position < bytes.size():
		var last: bool = position + WINDOW_BYTES >= bytes.size()
		var window_end: int = bytes.size() if last else bytes.rfind(10, position + WINDOW_BYTES) + 1
		if window_end <= position: return false
		var text: String = bytes.slice(position, window_end).get_string_from_utf8()
		var cut: int = text.rfind(nl + "  ]") if last else text.rfind(row_end)
		if cut < 0: return false
		var body: String = text.substr(0, cut + (0 if last else nl.length() + 5))
		position += text.substr(0, cut + (0 if last else row_end.length())).to_utf8_buffer().size()
		var rows: Variant = JSON.parse_string("[" + body + "]")
		if not rows is Array: return false
		_take(rows, state, key_field, wanted, collect_field, keep_all)
		if last: break
	return true
