extends RefCounted
## The existing stored-pixel coverage hypothesis, decoded without a PNG file.
## Native M geometry, alpha flags and compositing remain unverified.
const MAX_SOURCE_BYTES = 8 * 1024 * 1024
const ATLAS_BYTES = 384 * 384 * 4
const SECTION_NAMES = ["header", "palette", "flags", "descriptors", "indices"]
var problem: String = ""

func _fail(message: String) -> PackedByteArray:
	problem = message
	return PackedByteArray()

## `display`: after the pinned coverage check, apply the block-flag display
## alpha (see display_alpha) to the returned copy.
func decode_rgba(compressed: PackedByteArray, row: Dictionary, display: bool = false) -> PackedByteArray:
	problem = ""
	if not _uint(row.get("source_bytes"), MAX_SOURCE_BYTES) or int(row.source_bytes) < 1 or compressed.size() != int(row.source_bytes) or not _sha(row.get("source_sha256")) or _hash(compressed) != row.source_sha256:
		return _fail("Original TI2 size or digest mismatch")
	if not _uint(row.get("decoded_bytes"), MAX_SOURCE_BYTES) or int(row.decoded_bytes) < 4:
		return _fail("Decoded TI2 size is outside its allocation bound")
	# The compiler proves complete Brotli input consumption before publishing.
	# Its caller-pinned compressed SHA binds this bounded native decompression
	# to those exact bytes; no unbounded dynamic decompression is used here.
	var decoded: PackedByteArray = compressed.decompress(int(row.decoded_bytes), FileAccess.COMPRESSION_BROTLI)
	if decoded.size() != int(row.decoded_bytes): return _fail("Brotli TI2 output differs from the expected bounded size")
	return decode_raw_rgba(decoded, row, display)

func decode_raw_rgba(decoded: PackedByteArray, row: Dictionary, display: bool = false) -> PackedByteArray:
	problem = ""
	if not _raw_identity(decoded, row): return _fail("Decoded TI2 metadata, digest or section mismatch")
	var header: int = decoded.decode_u32(0)
	if header != int(row.raw_header_u32) or (header & 4095) != int(row.blocks) or (header & 4096) == 0:
		return _fail("Unsupported TI2 raw header or physical block count")
	var physical_count: int=int(row.blocks)
	var position: int = 4
	var palette_count: int = int(decoded[position])
	position += 1
	if palette_count == 0: palette_count = 256
	if palette_count != int(row.palette_colors) or position + palette_count * 2 > decoded.size():
		return _fail("TI2 palette count or size mismatch")
	var palette: PackedByteArray = decoded.slice(position, position + palette_count * 2)
	if _hash(palette) != row.palette_u16le_sha256: return _fail("Unsigned TI2 palette digest mismatch")
	var colors := PackedInt64Array()
	colors.resize(palette_count)
	for index: int in range(palette_count):
		var word: int = palette.decode_u16(index * 2)
		var red: int = word >> 11
		var green: int = (word >> 5) & 63
		var blue: int = word & 31
		red = (red << 3) | (red >> 2)
		green = (green << 2) | (green >> 4)
		blue = (blue << 3) | (blue >> 2)
		# encode_u32 writes these four bytes as RGBA8; all stored indices,
		# including zero/black/white, receive coverage alpha255.
		colors[index] = red | (green << 8) | (blue << 16) | (255 << 24)
	position += palette_count * 2
	if position != int(row.raw_sections.flags.offset) or position + physical_count > decoded.size():
		return _fail("TI2 palette/flag boundary mismatch")
	var flags: PackedByteArray = decoded.slice(position, position + physical_count)
	position += physical_count
	var descriptor_end: int = int(row.raw_sections.descriptors.offset) + int(row.raw_sections.descriptors.bytes)
	if position != int(row.raw_sections.descriptors.offset): return _fail("TI2 descriptor start mismatch")
	var blocks: Array[Dictionary] = []
	var stored_pixels: int = 0
	for frame: int in range(physical_count):
		var flag: int = flags[frame]
		var x_origin: int = 0
		var y_origin: int = 0
		var commands := PackedInt32Array()
		var pixel_count: int = 288 if (flag & 64) != 0 else 0
		if (flag & 64) == 0:
			if position + 3 > descriptor_end: return _fail("Truncated TI2 descriptor header")
			x_origin = decoded[position]
			y_origin = decoded[position + 1]
			var command_count: int = decoded[position + 2]
			position += 3
			if position + command_count * 2 > descriptor_end: return _fail("Truncated unsigned TI2 span commands")
			commands.resize(command_count)
			for command: int in range(command_count):
				var word: int = decoded.decode_u16(position)
				position += 2
				commands[command] = word
				pixel_count += (word >> 5) & 31
		stored_pixels += pixel_count
		if stored_pixels > 256 * 576: return _fail("TI2 index count exceeds supported coverage storage")
		blocks.append({"flag":flag, "x":x_origin, "y":y_origin, "commands":commands, "pixels":pixel_count})
	if position != descriptor_end or position != int(row.raw_sections.indices.offset) or stored_pixels != int(row.stored_pixels) or position + stored_pixels != decoded.size():
		return _fail("TI2 descriptors/index boundary or consumption mismatch")
	var rgba := PackedByteArray()
	rgba.resize(ATLAS_BYTES)
	rgba.fill(0)
	# The display copy is written in the same pass (one palette table per
	# flag rule), so the coverage pin is still checked on untouched bytes.
	var shown := PackedByteArray()
	var tables: Array[PackedInt64Array] = []
	if display:
		shown.resize(ATLAS_BYTES)
		shown.fill(0)
		tables = display_tables(colors)
	for frame: int in range(physical_count):
		var block: Dictionary = blocks[frame]
		var table: PackedInt64Array = tables[display_rule(int(block.flag))] if display else colors
		var atlas_x: int = (frame % 16) * 24
		var atlas_y: int = (frame >> 4) * 24
		var pixel_end: int = position + int(block.pixels)
		if (int(block.flag) & 64) != 0:
			for y: int in range(23):
				var width: int = (y + 1) * 2 if y < 12 else (23 - y) * 2
				var x_start: int = 0 if (int(block.flag) & 1) != 0 else 24 - width
				var destination: int = ((atlas_y + y) * 384 + atlas_x + x_start) * 4
				for x: int in range(width):
					var palette_index: int = decoded[position]
					position += 1
					if palette_index >= palette_count: return _fail("TI2 stored index exceeds unsigned palette")
					rgba.encode_u32(destination + x * 4, colors[palette_index])
					if display: shown.encode_u32(destination + x * 4, table[palette_index])
		else:
			var x_origin: int = int(block.x)
			var x_base: int = x_origin
			var y: int = int(block.y)
			var occupied := PackedByteArray()
			occupied.resize(24 * 24)
			occupied.fill(0)
			for word: int in block.commands:
				var count: int = (word >> 5) & 31
				var row_step: int = (word >> 10) & 31
				var x: int = x_base + (word & 31)
				if count > 0:
					if x + count > 24 or y >= 24: return _fail("Candidate TI2 span exceeds the existing24x24 coverage canvas")
					var destination: int = ((atlas_y + y) * 384 + atlas_x + x) * 4
					for column: int in range(count):
						var location: int = y * 24 + x + column
						if occupied[location] != 0: return _fail("Duplicate candidate TI2 canvas write")
						occupied[location] = 1
						var palette_index: int = decoded[position]
						position += 1
						if palette_index >= palette_count: return _fail("TI2 stored index exceeds unsigned palette")
						rgba.encode_u32(destination + column * 4, colors[palette_index])
						if display: shown.encode_u32(destination + column * 4, table[palette_index])
				# Each command advances from its own x/count. Positive row_step
				# resets x to the raw origin; commands are never grouped as RLE rows.
				if row_step > 0:
					y += row_step
					x_base = x_origin
				else:
					x_base = x + count
		if position != pixel_end: return _fail("TI2 span/index consumption mismatch")
	if position != decoded.size(): return _fail("Unconsumed decoded TI2 bytes")
	if _hash(rgba) != row.atlas_rgba_sha256: return _fail("Runtime TI2 coverage RGBA differs from the pinned interpretation")
	return shown if display else rgba

## Which display rule a block flag selects: 0 opaque, 1 half (bit 4),
## 2 brightness (bit 16), 3 darkness (bit 32, wins over bit 16).
static func display_rule(flag: int) -> int:
	if (flag & 32) != 0: return 3
	if (flag & 16) != 0: return 2
	if (flag & 4) != 0: return 1
	return 0

## The RGBA8 palette (alpha 255) once per display rule.
static func display_tables(colors: PackedInt64Array) -> Array[PackedInt64Array]:
	var tables: Array[PackedInt64Array] = [colors]
	for rule: int in [1, 2, 3]:
		var table := PackedInt64Array()
		table.resize(colors.size())
		for index: int in colors.size():
			var color: int = colors[index]
			table[index] = (color & 0xFFFFFF) | (display_alpha_of(color & 255, (color >> 8) & 255, (color >> 16) & 255, rule) << 24)
		tables.append(table)
	return tables

## One covered pixel's display alpha (8-bit RGB expanded from RGB565).
static func display_alpha_of(red8: int, green8: int, blue8: int, rule: int) -> int:
	if rule == 0: return 255
	if rule == 1: return 128
	var red: int = red8 >> 3
	var green: int = green8 >> 2
	var blue: int = blue8 >> 3
	var rgb555: int = (red << 10) | ((green >> 1) << 5) | blue
	var brightness: int = maxi(red, maxi(green >> 1, blue))
	var alpha: int = ((31 - brightness) if rule == 3 else brightness) * 255 / 31
	if rgb555 in [0, 0x0421, 0x7fff, 0x7fe0] or alpha < 8: return 0
	return alpha

## The reviewed TI2 block-flag display alpha, the same rule the 508 tile tools
## apply (tools/map_restore/base508_ti2.py render(display_alpha=True)):
## flag bit 16 → alpha from brightness, bit 32 → alpha from darkness (pure
## black/white/0x0421/0x7fe0 and alpha < 8 drop out), else bit 4 → half alpha.
## Colors stay the original RGB565 values; only stored (covered) pixels change.
## Without it these translucent fog/water/shadow blocks draw as opaque patches.
## Per-pixel reference; decode_rgba(display=true) gives the same bytes in one pass.
static func display_alpha(rgba: PackedByteArray, flags: PackedByteArray) -> void:
	for frame: int in range(mini(flags.size(), 256)):
		var flag: int = flags[frame]
		if (flag & 52) == 0: continue
		var atlas_x: int = (frame % 16) * 24
		var atlas_y: int = (frame >> 4) * 24
		for y: int in range(24):
			var row_start: int = ((atlas_y + y) * 384 + atlas_x) * 4
			for x: int in range(24):
				var at: int = row_start + x * 4
				if rgba[at + 3] == 0: continue
				rgba[at + 3] = display_alpha_of(rgba[at], rgba[at + 1], rgba[at + 2], display_rule(flag))

static func _raw_identity(decoded: PackedByteArray, row: Dictionary) -> bool:
	if not _uint(row.get("decoded_bytes"), MAX_SOURCE_BYTES) or int(row.decoded_bytes) < 4 or decoded.size() != int(row.decoded_bytes) or not _sha(row.get("decoded_sha256")) or _hash(decoded) != row.decoded_sha256: return false
	if not _uint(row.get("raw_header_u32"), 4294967295) or not _uint(row.get("blocks"), 256) or int(row.blocks) < 1 or row.get("raw_decoded_roundtrip") != true: return false
	var size: Variant = row.get("atlas_size")
	if not size is Array or size.size() != 2 or not _uint(size[0], 384) or not _uint(size[1], 384) or int(size[0]) != 384 or int(size[1]) != 384: return false
	if not _uint(row.get("palette_colors"), 256) or int(row.palette_colors) < 1 or not _uint(row.get("stored_pixels"), 256 * 576) or not _sha(row.get("palette_u16le_sha256")) or not _sha(row.get("atlas_rgba_sha256")): return false
	var sections: Variant = row.get("raw_sections")
	if not sections is Dictionary or sections.size() != SECTION_NAMES.size(): return false
	var end: int = 0
	for name: String in SECTION_NAMES:
		var section: Variant = sections.get(name)
		if not section is Dictionary or not _uint(section.get("offset"), MAX_SOURCE_BYTES) or int(section.offset) != end or not _uint(section.get("bytes"), MAX_SOURCE_BYTES) or not _sha(section.get("sha256")): return false
		end += int(section.bytes)
		if end > decoded.size() or _hash(decoded.slice(int(section.offset), end)) != section.sha256: return false
	return end == decoded.size() and int(sections.header.bytes) == 4 and int(sections.palette.bytes) == 1 + int(row.palette_colors) * 2 and int(sections.flags.bytes) == int(row.blocks) and int(sections.indices.bytes) == int(row.stored_pixels)

static func _uint(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= float(maximum) and float(value) == floor(float(value))

static func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if not "0123456789abcdef".contains(character): return false
	return true

static func _hash(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not data.is_empty(): context.update(data)
	return context.finish().hex_encode()
