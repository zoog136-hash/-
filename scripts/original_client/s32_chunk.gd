extends RefCounted
## C12 / P3. DESIGN_NOT_RECOVERED_API. Bounded reader for the parts of an S32 chunk the
## approved contract fixes: 8192 u32 floor refs, u16 cover count + 6-byte covers, 8192 u16
## attributes, the group section and the optional tail. Everything is little-endian. The
## sections whose meaning is unconfirmed are kept as opaque bytes with their offsets.
## Truncation and negative counts are DESIGN safety errors, not original behaviour.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const CELLS := 8192
const HALF_COLUMNS := 128
const FLOOR_SENTINEL := 0xFFFFFFFF
const FALLBACK_BASE := 0x8CBB

static func _u16(bytes: PackedByteArray, p: int) -> int:
	return bytes[p] | (bytes[p + 1] << 8)

static func _u32(bytes: PackedByteArray, p: int) -> int:
	return bytes[p] | (bytes[p + 1] << 8) | (bytes[p + 2] << 16) | (bytes[p + 3] << 24)

static func _i32(bytes: PackedByteArray, p: int) -> int:
	return VOCAB.i32(_u32(bytes, p))

static func _error(status: String, section: String, offset: int) -> Dictionary:
	return {"ok": false, "status": status, "section": section, "offset": offset}

## floor + cover + attribute prefix. Returns the offsets so original bytes stay locatable.
static func read_prefix(bytes: PackedByteArray) -> Dictionary:
	var floor_bytes: int = CELLS * 4
	if bytes.size() < floor_bytes + 2:
		return _error("TRUNCATED", "floor_or_cover_count", bytes.size())
	var floors: Array = []
	for i: int in CELLS:
		floors.append(_u32(bytes, i * 4))
	var cover_count: int = _u16(bytes, floor_bytes)
	var covers_at: int = floor_bytes + 2
	var attributes_at: int = covers_at + cover_count * 6
	if bytes.size() < attributes_at + CELLS * 2:
		return _error("TRUNCATED", "covers_or_attributes", bytes.size())
	var covers: Array = []
	for i: int in cover_count:
		covers.append(bytes.slice(covers_at + i * 6, covers_at + i * 6 + 6))
	var attributes: Array = []
	for i: int in CELLS:
		attributes.append(_u16(bytes, attributes_at + i * 2))
	var end: int = attributes_at + CELLS * 2
	return {"ok": true, "status": "OK", "floor_refs": floors, "covers": covers, "attributes": attributes,
		"offsets": {"floor": 0, "cover_count": floor_bytes, "covers": covers_at, "attributes": attributes_at, "end": end},
		"remaining": bytes.slice(end), "remaining_offset": end}

## One half-cell. The sentinel floor is replaced by 0x8CBB + (halfColumn & 1), but the
## attribute array that follows overrides the attribute 1 the replacement implies, so the
## sentinel alone never proves a cell is blocked.
static func cell(chunk: Dictionary, index: int) -> Dictionary:
	if index < 0 or index >= CELLS:
		return {"ok": false, "status": "INDEX_OUT_OF_RANGE"}
	var floor_ref: int = chunk.floor_refs[index]
	var column: int = index % HALF_COLUMNS
	var attr: int = chunk.attributes[index]
	if floor_ref == FLOOR_SENTINEL:
		return {"ok": true, "status": "OK", "fallback_floor": true, "replacement_value": FALLBACK_BASE + (column & 1),
			"attribute": attr, "attribute_overrides_sentinel": true}
	return {"ok": true, "status": "OK", "fallback_floor": false, "tile_id": (floor_ref >> 8) & 0xFFFFFF, "block": floor_ref & 0xFF,
		"tile_member": "Tile/%d.ti2" % ((floor_ref >> 8) & 0xFFFFFF), "attribute": attr}

## i32 group count, then groups of u16 id, u16 partCount and partCount 7-byte parts.
static func read_groups(bytes: PackedByteArray, offset: int) -> Dictionary:
	if offset < 0 or bytes.size() < offset + 4:
		return _error("TRUNCATED", "group_count", offset)
	var count: int = _i32(bytes, offset)
	if count < 0:
		return _error("NEGATIVE_COUNT", "group_count", offset)
	var p: int = offset + 4
	var groups: Array = []
	for g: int in count:
		if bytes.size() < p + 4:
			return _error("TRUNCATED", "group_header", p)
		var group_id: int = _u16(bytes, p)
		var part_count: int = _u16(bytes, p + 2)
		p += 4
		if bytes.size() < p + part_count * 7:
			return _error("TRUNCATED", "group_parts", p)
		var parts: Array = []
		for i: int in part_count:
			parts.append(bytes.slice(p + i * 7, p + i * 7 + 7))
		p += part_count * 7
		groups.append({"id": group_id, "part_count": part_count, "parts": parts})
	return {"ok": true, "status": "OK", "groups": groups, "end_offset": p}

## Optional tail: W; low 15 bits are the count and bit 15 selects the extended 10-byte
## record instead of the 6-byte one. Coordinate = (2*X - 32768, Y); SpriteID is signed 16.
## The extra u32 of the extended record is kept raw: its meaning is not confirmed. Leftover
## bytes are opaque trailing bytes. An empty or absent tail does not clear an earlier tail.
static func read_tail(bytes: PackedByteArray, offset: int) -> Dictionary:
	if offset < 0 or offset >= bytes.size():
		return {"ok": true, "status": "NO_TAIL", "records": [], "extended": false, "trailing_bytes": PackedByteArray(), "clears_existing_tail": false}
	if bytes.size() < offset + 2:
		return _error("TRUNCATED", "tail_word", offset)
	var word: int = _u16(bytes, offset)
	var count: int = word & 0x7FFF
	var extended: bool = (word & 0x8000) != 0
	var size: int = 10 if extended else 6
	var p: int = offset + 2
	if bytes.size() < p + count * size:
		return _error("TRUNCATED", "tail_records", p)
	var records: Array = []
	for i: int in count:
		var at: int = p + i * size
		var record := {"x": 2 * _u16(bytes, at) - 32768, "y": _u16(bytes, at + 2), "sprite_id": VOCAB.i16(_u16(bytes, at + 4))}
		if extended:
			record["extra_u32_raw"] = _u32(bytes, at + 6)
		records.append(record)
	p += count * size
	return {"ok": true, "status": "OK", "records": records, "extended": extended, "count": count, "end_offset": p,
		"trailing_bytes": bytes.slice(p), "clears_existing_tail": false}
