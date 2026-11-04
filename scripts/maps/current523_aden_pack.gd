extends RefCounted
## Raw current523 M sources. Storage indices are never world coordinates.
const INVENTORY_SHA256 = "e236f89849bcc6fc618feb13046c077adff59f909ad376b408c9b24fafc3288c"
const MAX_SOURCE_BYTES = 8 * 1024 * 1024
const SECTION_NAMES = ["floor", "covers", "attributes", "objects", "opacity", "declared", "tail"]
const UNKNOWN_SEMANTICS = ["coordinates", "projection", "movement", "collision", "height", "regions", "zones", "safety_combat", "drawing_order"]
var loaded: bool = false
var problem: String = ""
var _root: String = ""
var _members: Dictionary = {}

func _fail(message: String) -> bool:
	problem = message
	return false

static func _uint(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0.0 and float(value) <= float(maximum)

static func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for c: String in value:
		if not c in "0123456789abcdef": return false
	return true

static func _member_name(value: Variant) -> bool:
	if not value is String or not value.begins_with("Map/Aden/"): return false
	var basename: String = value.trim_prefix("Map/Aden/")
	if not basename.ends_with(".s32") or basename.length() > 128 or basename.length() <= 4: return false
	for c: String in basename.trim_suffix(".s32"):
		if not c in "0123456789abcdefABCDEF": return false
	return true

func load_pack(directory: String) -> bool:
	# Failed replacement leaves no partially accepted source registry.
	loaded = false
	_members.clear()
	_root = ""
	problem = ""
	var manifest_file := FileAccess.open(directory.path_join("aden523.json"), FileAccess.READ)
	if manifest_file == null: return _fail("Missing current523 Aden source pack")
	if manifest_file.get_length() > 4 * 1024 * 1024: return _fail("Oversized Aden manifest")
	var value: Variant = JSON.parse_string(manifest_file.get_as_text())
	if not value is Dictionary: return _fail("Invalid Aden manifest")
	for field: String in ["schema", "cumulative_version", "land_id", "source_count"]:
		if not _uint(value.get(field), 10000): return _fail("Invalid numeric source identity")
	if value.get("schema") != 1 or value.get("edition") != "LineageM" or value.get("cumulative_version") != 523 or value.get("land_id") != 4 or value.get("asset_path") != "Aden/" or value.get("source_root") != "Map/Aden/":
		return _fail("Aden current523 source identity mismatch")
	var declaration: Variant = value.get("land_declaration")
	if not declaration is Dictionary or not _uint(declaration.get("ID"), 10000) or declaration.get("ID") != 4 or declaration.get("AssetPath") != "Aden/" or value.get("delivery_status") != "PRIVATE_LOCAL_ONLY":
		return _fail("Invalid Aden declaration or private delivery status")
	var semantics: Variant = value.get("semantics")
	if not semantics is Dictionary: return _fail("Missing source interpretation boundary")
	for key: String in UNKNOWN_SEMANTICS:
		if semantics.get(key) != "UNKNOWN": return _fail("Unsupported Aden interpretation: " + key)
	for interpretation: Variant in semantics.values():
		if interpretation != "UNKNOWN": return _fail("Unsupported additional Aden interpretation")
	var entries: Variant = value.get("members")
	if value.get("source_count") != 677 or not entries is Array or entries.size() != 677:
		return _fail("Expected the complete 677-member current523 Aden inventory")
	var candidate: Dictionary = {}
	var lines: Array[String] = []
	for item: Variant in entries:
		if not item is Dictionary or not _member_name(item.get("member")): return _fail("Invalid literal Aden source member")
		var member: String = item.member
		if candidate.has(member): return _fail("Duplicate Aden source member")
		if item.get("path") != "originals/" + member or item.get("source_path") != member: return _fail("Aden source path mismatch")
		if not _uint(item.get("bytes"), MAX_SOURCE_BYTES) or int(item.bytes) < 49158 or not _sha(item.get("sha256")):
			return _fail("Invalid Aden source size or digest")
		if not _validate_sections(item): return false
		candidate[member] = item.duplicate(true)
		lines.append(member + "\t" + str(int(item.bytes)) + "\t" + str(item.sha256) + "\n")
	lines.sort()
	var inventory: String = "".join(lines).sha256_text()
	if inventory != INVENTORY_SHA256 or value.get("source_inventory_sha256") != INVENTORY_SHA256:
		return _fail("Stale or changed current523 Aden inventory")
	for metadata: Dictionary in candidate.values():
		var source_file := FileAccess.open(directory.path_join(str(metadata.path)), FileAccess.READ)
		if source_file == null or source_file.get_length() != int(metadata.bytes):
			return _fail("Missing or wrong-sized Aden source: " + str(metadata.member))
	# Metadata registration is cheap; exact file hashes are checked on every read.
	# Do not claim that unconsumed members or a rendered map were verified here.
	_members = candidate
	_root = directory
	loaded = true
	return true

func _validate_sections(item: Dictionary) -> bool:
	var sections: Variant = item.get("sections")
	if not sections is Dictionary or sections.size() != SECTION_NAMES.size(): return _fail("Invalid raw source sections")
	var cursor: int = 0
	for name: String in SECTION_NAMES:
		var section: Variant = sections.get(name)
		if not section is Dictionary or not _uint(section.get("offset"), MAX_SOURCE_BYTES) or not _uint(section.get("bytes"), MAX_SOURCE_BYTES) or not _sha(section.get("sha256")):
			return _fail("Invalid raw source section: " + name)
		if int(section.offset) != cursor: return _fail("Noncontiguous raw source sections")
		cursor += int(section.bytes)
		if cursor > int(item.bytes): return _fail("Source section exceeds member")
		if name in ["floor", "attributes", "tail"] and section.has("count"):
			return _fail("Unexpected count in fixed or opaque source section")
		if name == "tail" and int(section.bytes) > 1024 * 1024: return _fail("Oversized opaque tail")
		if name in ["covers", "objects", "opacity", "declared"]:
			var header: int = 2 if name == "covers" else 4
			var stride: int = 6 if name == "covers" else (5 if name == "opacity" else 4)
			var limit: int = 262144 if name == "opacity" else 65535
			if not _uint(section.get("count"), limit) or not _uint(section.get("records_offset"), MAX_SOURCE_BYTES) or int(section.records_offset) != int(section.offset) + header:
				return _fail("Invalid raw record count or offset")
			var expected_bytes: int = header + stride * int(section.count)
			if name == "objects":
				if not _uint(section.get("part_count"), 262144) or not _uint(item.get("object_part_count"), 262144) or int(section.part_count) != int(item.object_part_count) or int(section.part_count) > int(section.count) * 65535:
					return _fail("Invalid raw object part count")
				expected_bytes += 7 * int(section.part_count)
			if int(section.bytes) != expected_bytes: return _fail("Raw section count and byte size disagree")
	if cursor != int(item.bytes) or int(sections.floor.bytes) != 32768 or int(sections.attributes.bytes) != 16384:
		return _fail("Raw source section sizes mismatch")
	if not _uint(item.get("attribute_offset"), MAX_SOURCE_BYTES) or int(item.attribute_offset) != int(sections.attributes.offset) or item.get("attribute_sha256") != sections.attributes.sha256:
		return _fail("Raw attribute identity mismatch")
	if not _uint(item.get("core_end"), MAX_SOURCE_BYTES) or int(item.core_end) != int(sections.tail.offset): return _fail("Raw tail offset mismatch")
	return true

func source_members() -> Array:
	var result: Array = _members.keys() if loaded else []
	result.sort()
	return result

func source_metadata(member: String) -> Dictionary:
	return _members[member].duplicate(true) if loaded and _members.has(member) else {}

func read_member(member: String) -> Dictionary:
	problem = ""
	if not loaded or not _members.has(member):
		_fail("Aden source member is not registered")
		return {}
	var metadata: Dictionary = _members[member]
	var file := FileAccess.open(_root.path_join(str(metadata.path)), FileAccess.READ)
	if file == null or file.get_length() != int(metadata.bytes):
		_fail("Missing or wrong-sized Aden source: " + member)
		return {}
	var bytes: PackedByteArray = file.get_buffer(int(metadata.bytes))
	if bytes.size() != int(metadata.bytes) or _hash(bytes) != metadata.sha256:
		_fail("Aden source hash mismatch: " + member)
		return {}
	var observed: Dictionary = scan_sections(bytes)
	if observed.is_empty():
		_fail("Malformed Aden source: " + member)
		return {}
	var result: Dictionary = {"member": member, "source_sha256": metadata.sha256, "source_bytes": bytes.size(), "sections": {}}
	for name: String in SECTION_NAMES:
		var section: Dictionary = metadata.sections[name]
		var actual: Dictionary = observed[name]
		if actual.offset != int(section.offset) or actual.bytes != int(section.bytes) or (name in ["covers", "objects", "opacity", "declared"] and actual.get("count") != int(section.count)):
			_fail("Aden source structure mismatch: " + name)
			return {}
		var raw: PackedByteArray = bytes.slice(int(section.offset), int(section.offset) + int(section.bytes))
		if _hash(raw) != section.sha256:
			_fail("Aden source section hash mismatch: " + name)
			return {}
		result.sections[name] = raw
	if metadata.has("object_part_count") and observed.objects.object_part_count != int(metadata.object_part_count):
		_fail("Aden object part count mismatch")
		return {}
	return result

static func _hash(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()

static func scan_sections(bytes: PackedByteArray) -> Dictionary:
	# Independently scan count headers in Godot before exposing any source bytes.
	# These are storage records; no world transform or movement mask is applied.
	var length: int = bytes.size()
	if length < 49158 or length > MAX_SOURCE_BYTES: return {}
	var out: Dictionary = {"floor": {"offset": 0, "bytes": 32768}}
	var cursor: int = 32768
	var start: int = cursor
	var count: int = bytes.decode_u16(cursor)
	cursor += 2
	if count > (length - cursor) / 6: return {}
	cursor += count * 6
	out.covers = {"offset": start, "bytes": cursor - start, "count": count}
	if cursor + 16384 + 4 > length: return {}
	out.attributes = {"offset": cursor, "bytes": 16384}
	cursor += 16384
	start = cursor
	count = bytes.decode_u32(cursor)
	cursor += 4
	if count > 65535 or count > (length - cursor) / 4: return {}
	var parts: int = 0
	for _group: int in range(count):
		if cursor + 4 > length: return {}
		var part_count: int = bytes.decode_u16(cursor + 2)
		cursor += 4
		parts += part_count
		if parts > 262144 or part_count > (length - cursor) / 7: return {}
		cursor += part_count * 7
	out.objects = {"offset": start, "bytes": cursor - start, "count": count, "object_part_count": parts}
	for name: String in ["opacity", "declared"]:
		if cursor + 4 > length: return {}
		start = cursor
		count = bytes.decode_u32(cursor)
		cursor += 4
		var stride: int = 5 if name == "opacity" else 4
		var limit: int = 262144 if name == "opacity" else 65535
		if count > limit or count > (length - cursor) / stride: return {}
		cursor += count * stride
		out[name] = {"offset": start, "bytes": cursor - start, "count": count}
	if length - cursor > 1024 * 1024: return {}
	out.tail = {"offset": cursor, "bytes": length - cursor}
	return out
