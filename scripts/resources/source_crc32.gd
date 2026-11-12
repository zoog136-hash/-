extends RefCounted
## IEEE CRC32, exactly the received-member receipt domain used by SP2 banks.
## Slicing eight bytes per GDScript iteration reduces cold verification work.
## The fixed tables occupy 16 KiB of packed integers; no input is retained.
static var _tables := PackedInt64Array()

static func _prepare() -> void:
	if not _tables.is_empty(): return
	_tables.resize(8 * 256)
	for index: int in range(256):
		var value: int = index
		for bit: int in range(8): value = (value >> 1) ^ (0xedb88320 if (value & 1) != 0 else 0)
		_tables[index] = value
	for slice_index: int in range(1, 8):
		for index: int in range(256):
			var value: int = _tables[(slice_index - 1) * 256 + index]
			_tables[slice_index * 256 + index] = _tables[value & 255] ^ (value >> 8)

static func hex_digest(bytes: PackedByteArray) -> String:
	_prepare()
	var tables: PackedInt64Array = _tables
	var value: int = 0xffffffff
	var offset: int = 0
	var length: int = bytes.size()
	while offset + 8 <= length:
		var low: int = bytes.decode_u32(offset) ^ value
		var high: int = bytes.decode_u32(offset + 4)
		value = tables[1792 + (low & 255)] ^ tables[1536 + ((low >> 8) & 255)] ^ tables[1280 + ((low >> 16) & 255)] ^ tables[1024 + (low >> 24)] ^ tables[768 + (high & 255)] ^ tables[512 + ((high >> 8) & 255)] ^ tables[256 + ((high >> 16) & 255)] ^ tables[high >> 24]
		offset += 8
	while offset < length:
		value = tables[(value ^ bytes[offset]) & 255] ^ (value >> 8)
		offset += 1
	return "%08x" % ((value ^ 0xffffffff) & 0xffffffff)
