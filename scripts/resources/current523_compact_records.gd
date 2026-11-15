extends RefCounted
## Read-only view of a current523_bake_cache record file (same file, same
## records, same has()/read() answers) whose in-memory ID index is packed.
##
## current523_bake_cache.open_records() keeps a Dictionary of String ID ->
## file offset. The 523 image pack index has ~190,000 IDs ("a:<id>",
## "c:<table>:<id>", "m:<path>", ...): 41.7 MB resident in the real pack
## (Godot Strings are 4 bytes per character plus a Dictionary entry each).
## Here every ID is stored once as UTF-8 in one byte array, with an
## open-addressing hash table of entry numbers: ~45 bytes per ID.
## A later duplicate ID wins, as in open_records().
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")

var file: FileAccess
var _blob := PackedByteArray() # unique IDs, UTF-8, one after another
var _starts := PackedInt32Array() # entry i = _blob[_starts[i], _starts[i + 1])
var _offsets := PackedInt64Array()
var _table := PackedInt32Array() # entry number + 1; 0 = empty slot
var _mask: int = 0

## Same checks and failures as current523_bake_cache.open_records().
static func open(name: String, value_key: String) -> RefCounted:
	var path: String = BAKE.verified_file(name, value_key)
	if path.is_empty(): return null
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null or handle.get_length() < 8:
		BAKE.LOG.io(name, "index", "corrupt")
		return null
	handle.seek(handle.get_length() - 8)
	var index_position: int = handle.get_64()
	if index_position < 0 or index_position >= handle.get_length() - 8:
		BAKE.LOG.io(name, "index", "corrupt")
		return null
	handle.seek(index_position)
	var index: Variant = handle.get_var()
	if not index is Dictionary or index.get("schema") != BAKE.SCHEMA or not index.get("ids") is PackedStringArray or not index.get("offsets") is PackedInt64Array:
		BAKE.LOG.io(name, "index", "schema_changed" if index is Dictionary and index.get("schema") != BAKE.SCHEMA else "corrupt")
		return null
	if (index.ids as PackedStringArray).size() != (index.offsets as PackedInt64Array).size():
		BAKE.LOG.io(name, "index", "corrupt")
		return null
	var records: RefCounted = load("res://scripts/resources/current523_compact_records.gd").new()
	records.file = handle
	records._build(index.ids, index.offsets)
	return records

func _build(ids: PackedStringArray, offsets: PackedInt64Array) -> void:
	var capacity: int = 8
	while capacity < ids.size() * 2: capacity <<= 1
	_table.resize(capacity)
	_table.fill(0)
	_mask = capacity - 1
	_starts.append(0)
	for position: int in ids.size():
		var id: String = ids[position]
		var bytes: PackedByteArray = id.to_utf8_buffer()
		var slot: int = id.hash() & _mask
		while true:
			var entry: int = _table[slot]
			if entry == 0:
				_blob.append_array(bytes)
				_starts.append(_blob.size())
				_offsets.append(offsets[position])
				_table[slot] = _offsets.size()
				break
			if _same(entry - 1, bytes):
				_offsets[entry - 1] = offsets[position]
				break
			slot = (slot + 1) & _mask

func _same(entry: int, bytes: PackedByteArray) -> bool:
	var start: int = _starts[entry]
	return _starts[entry + 1] - start == bytes.size() and _blob.slice(start, start + bytes.size()) == bytes

func _find(id: String) -> int:
	if _offsets.is_empty(): return -1
	var bytes: PackedByteArray = id.to_utf8_buffer()
	var slot: int = id.hash() & _mask
	while true:
		var entry: int = _table[slot]
		if entry == 0: return -1
		if _same(entry - 1, bytes): return entry - 1
		slot = (slot + 1) & _mask
	return -1

func size() -> int:
	return _offsets.size()

func has(id: String) -> bool:
	return _find(id) >= 0

func read(id: String) -> Variant:
	var entry: int = _find(id)
	if entry < 0: return null
	file.seek(_offsets[entry])
	return file.get_var()
