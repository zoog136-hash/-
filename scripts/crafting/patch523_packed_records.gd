extends RefCounted
## Column-packed store of JSON-like records, used only while the equipment
## rules model is compiled (cold bake).
##
## A parsed JSON record costs several KB as a Dictionary (every key and value
## is its own String and hash entry); ~30,000 registered catalog identities
## were ~200 MB that way. Here records that share a shape (same keys in the
## same order, same value kind per key) share the key names and keep their
## values in packed columns; repeated strings and nested values are stored
## once. fetch() returns a fresh Dictionary equal to the record that was
## added: same keys, key order, values and value types (nested Arrays and
## Dictionaries are deep copies). Records that cannot be packed (not a
## Dictionary, a non-String key) and records added with pack=false are kept
## as they are and returned as the same value.

const KIND_FLOAT: int = 0
const KIND_STRING: int = 1
const KIND_BOOL: int = 2
const KIND_OTHER: int = 3
## Distinct values interned per column before interning stops for that column.
const INTERN_LIMIT: int = 512

class Shape extends RefCounted:
	var columns := PackedStringArray()
	var kinds := PackedInt32Array()
	var data: Array = []
	var intern: Array = []
	var index: Dictionary = {}

var _shapes: Array = []
var _signatures: Dictionary = {}
var _shape_of := PackedInt32Array()
var _row_of := PackedInt32Array()
var _loose: Array = []

func size() -> int:
	return _shape_of.size()

func packed_count() -> int:
	return _shape_of.size() - _loose.size()

func shape_count() -> int:
	return _shapes.size()

static func _kind(value: Variant) -> int:
	match typeof(value):
		TYPE_FLOAT: return KIND_FLOAT
		TYPE_STRING: return KIND_STRING
		TYPE_BOOL: return KIND_BOOL
	return KIND_OTHER

## Adds one record and returns its handle (0, 1, 2, ... in add order).
func add(record: Variant, pack: bool = true) -> int:
	var handle: int = _shape_of.size()
	var signature: String = ""
	if pack and record is Dictionary:
		var parts := PackedStringArray()
		for key: Variant in record:
			if not key is String:
				pack = false
				break
			parts.append(key)
			parts.append(str(_kind(record[key])))
		if pack: signature = "\u001f".join(parts)
	else: pack = false
	if not pack:
		_shape_of.append(-1)
		_row_of.append(_loose.size())
		_loose.append(record)
		return handle
	var shape: Shape
	if _signatures.has(signature): shape = _shapes[_signatures[signature]]
	else:
		shape = Shape.new()
		for key: String in record:
			var kind: int = _kind(record[key])
			shape.index[key] = shape.columns.size()
			shape.columns.append(key)
			shape.kinds.append(kind)
			if kind == KIND_FLOAT: shape.data.append(PackedFloat64Array())
			elif kind == KIND_STRING: shape.data.append(PackedStringArray())
			elif kind == KIND_BOOL: shape.data.append(PackedByteArray())
			else: shape.data.append([])
			shape.intern.append({} if kind in [KIND_STRING,KIND_OTHER] else null)
		_signatures[signature] = _shapes.size()
		_shapes.append(shape)
	var position: int = 0
	var row: int = 0
	for key: String in record:
		var value: Variant = record[key]
		var kind: int = shape.kinds[position]
		if kind == KIND_STRING: value = _interned(shape, position, value, value)
		elif kind == KIND_BOOL: value = 1 if value else 0
		elif kind == KIND_OTHER and shape.intern[position] != null and (value is Dictionary or value is Array): value = _interned(shape, position, var_to_bytes(value), value)
		# Packed arrays held in a Variant are shared, so this grows in place.
		row = shape.data[position].size()
		shape.data[position].append(value)
		position += 1
	_shape_of.append(int(_signatures[signature]))
	_row_of.append(row)
	return handle

static func _interned(shape: Shape, position: int, key: Variant, value: Variant) -> Variant:
	var seen: Variant = shape.intern[position]
	if seen == null: return value
	if (seen as Dictionary).has(key): return seen[key]
	if (seen as Dictionary).size() >= INTERN_LIMIT:
		shape.intern[position] = null
		return value
	seen[key] = value
	return value

## The record added as `handle` (a fresh Dictionary for packed records).
func fetch(handle: int) -> Variant:
	var shape_index: int = _shape_of[handle]
	var row: int = _row_of[handle]
	if shape_index < 0: return _loose[row]
	var shape: Shape = _shapes[shape_index]
	var result: Dictionary = {}
	for position: int in shape.columns.size():
		result[shape.columns[position]] = _value(shape, position, row)
	return result

## fetch(handle).get(key, default) without building the record.
func field(handle: int, key: String, default: Variant = null) -> Variant:
	var shape_index: int = _shape_of[handle]
	var row: int = _row_of[handle]
	if shape_index < 0:
		var loose: Variant = _loose[row]
		return (loose as Dictionary).get(key, default) if loose is Dictionary else default
	var shape: Shape = _shapes[shape_index]
	if not shape.index.has(key): return default
	return _value(shape, int(shape.index[key]), row)

## Presence is distinct from a present null value, as in Dictionary.has().
func has_field(handle: int, key: String) -> bool:
	var shape_index: int = _shape_of[handle]
	if shape_index < 0:
		var loose: Variant = _loose[_row_of[handle]]
		return loose is Dictionary and loose.has(key)
	return (_shapes[shape_index] as Shape).index.has(key)

static func _value(shape: Shape, position: int, row: int) -> Variant:
	var value: Variant = shape.data[position][row]
	var kind: int = shape.kinds[position]
	if kind == KIND_BOOL: return value != 0
	if kind == KIND_OTHER and (value is Dictionary or value is Array): return value.duplicate(true)
	return value

func clear() -> void:
	_shapes.clear()
	_signatures.clear()
	_shape_of = PackedInt32Array()
	_row_of = PackedInt32Array()
	_loose.clear()
