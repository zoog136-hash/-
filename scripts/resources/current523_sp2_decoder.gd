extends RefCounted
## Current523 byte parser and ESTIMATED commandwise preview, never client verification.
## Storage evidence: handoff objective_decoder_checks/all989_direct_M_model_QA.json
## (989 EOFs / 17,054 nonempty half-open extents; 72 grouped-row counterexamples).
## Palette, group bits, raw bounds, reference order/types and commands are retained.
## Frame bounds: most frames store half-open bounds (x2/y2 exclusive) that the
## samples fill exactly. Some 523 files (e.g. the male knight 15270) mix in
## frames whose stored x2/y2 is the last sample pixel (end-inclusive) and a few
## half-open frames with blank rows above the samples. Each nonempty frame must
## end exactly on its stored end under one of the two readings and keep every
## sample inside; anything else is rejected. The canvas covers the samples.
## RGB expansion, alpha and overwrite compositing remain configurable estimates.
const MAX_INPUT_BYTES = 2 * 1024 * 1024
const MAX_BODY_BYTES = 32 * 1024 * 1024
const MAX_DIMENSION = 4096
const MAX_CANVAS_PIXELS = 16 * 1024 * 1024
const MAX_SAMPLES = 16 * 1024 * 1024
const MAX_REFERENCES = 131072
const MAX_BLOCKS = 65536
const MAX_COMMANDS = 1024 * 1024
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

class Reader:
	extends RefCounted
	var data: PackedByteArray
	var position: int = 0
	var error: String = ""
	func _init(bytes: PackedByteArray) -> void: data = bytes
	func need(count: int) -> bool:
		if not error.is_empty(): return false
		if count < 0 or count > data.size() - position:
			error = "Truncated SP2 at byte %d (need %d)." % [position,count]
			return false
		return true
	func u8() -> int:
		if not need(1): return 0
		var value: int = data[position]
		position += 1
		return value
	func s8() -> int:
		var value: int = u8()
		return value - 256 if value >= 128 else value
	func u16() -> int:
		if not need(2): return 0
		var value: int = data.decode_u16(position)
		position += 2
		return value
	func s16() -> int:
		var value: int = u16()
		return value - 65536 if value >= 32768 else value
	func s32() -> int:
		if not need(4): return 0
		var value: int = data.decode_s32(position)
		position += 4
		return value
	func take(count: int) -> PackedByteArray:
		if not need(count): return PackedByteArray()
		var value: PackedByteArray = data.slice(position,position + count)
		position += count
		return value

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message,"estimated":true}

static func parse(raw: PackedByteArray) -> Dictionary:
	var started: int = FRAME_HITCH.now()
	FRAME_HITCH.count("sp2.decoder_input_bytes", raw.size())
	var result: Dictionary = _parse(raw)
	FRAME_HITCH.detail("sp2.decoder_total", started)
	FRAME_HITCH.count("sp2.decoder_ok" if result.ok else "sp2.decoder_reject")
	return result

static func _parse(raw: PackedByteArray) -> Dictionary:
	if raw.is_empty() or raw.size() > MAX_INPUT_BYTES:
		return _fail("SP2 input must contain 1 to %d bytes." % MAX_INPUT_BYTES)
	var body: PackedByteArray = raw
	if raw[0] != 254:
		var decompress_started: int = FRAME_HITCH.now()
		# Godot4.7's dynamic Brotli loop does not stop on NEEDS_MORE_INPUT.
		# Use its bounded one-shot codec to reject incomplete streams safely.
		# https://github.com/godotengine/godot/blob/4.7/core/io/compression.cpp#L230-L257
		# Suppress only expected native codec diagnostics; restore synchronously.
		var previous_errors: bool = Engine.print_error_messages
		Engine.print_error_messages = false
		body = raw.decompress(MAX_BODY_BYTES,FileAccess.COMPRESSION_BROTLI)
		Engine.print_error_messages = previous_errors
		FRAME_HITCH.detail("sp2.decoder_brotli", decompress_started)
	if body.size() < 2 or body.size() > MAX_BODY_BYTES or body[0] != 254:
		return _fail("Invalid, incomplete or oversized Brotli/FE SP2 body.")
	FRAME_HITCH.count("sp2.decoder_body_bytes", body.size())
	var marker: int = body[1]
	var layouts: Array = [1,3] if marker == 1 else [256 if marker == 0 else marker]
	var passed: Array[Dictionary] = []
	var errors: Array[String] = []
	for entries: int in layouts:
		var candidate: Dictionary = _parse_candidate(body,entries)
		if candidate.ok: passed.append(candidate)
		else: errors.append(str(candidate.error))
	if passed.size() != 1:
		return _fail("SP2 palette marker %d has %d complete valid layouts: %s" % [marker,passed.size(),"; ".join(errors)])
	var parsed: Dictionary = passed[0]
	parsed["raw"] = raw
	parsed["body"] = body
	parsed["palette_marker"] = marker
	parsed["estimated"] = true
	return parsed

static func _parse_candidate(body: PackedByteArray,entries: int) -> Dictionary:
	var started: int = FRAME_HITCH.now()
	var result: Dictionary = _parse_candidate_measured(body, entries)
	FRAME_HITCH.detail("sp2.decoder_candidate", started)
	return result

static func _parse_candidate_measured(body: PackedByteArray,entries: int) -> Dictionary:
	var metadata_started: int = FRAME_HITCH.now()
	var reader := Reader.new(body)
	if reader.u8() != 254: return _fail("Missing FE header.")
	reader.u8()
	if not reader.need(entries * 2 + 1): return _fail(reader.error)
	var palette := PackedInt32Array()
	for _entry: int in range(entries): palette.append(reader.u16())
	var mask: int = reader.u8()
	if mask == 0: return _fail("SP2 group mask is empty.")
	var groups: Array[Dictionary] = []
	var total_refs: int = 0
	var total_blocks: int = 0
	var total_commands: int = 0
	var total_samples: int = 0
	var frame_count: int = 0
	var nonempty_count: int = 0
	for bit: int in range(8):
		if (mask & (1 << bit)) == 0: continue
		var frames: Array[Dictionary] = []
		var count: int = reader.u8()
		for _frame: int in range(count):
			if not reader.need(10): return _fail(reader.error)
			var raw_bounds := PackedInt32Array([reader.s16(),reader.s16(),reader.s16(),reader.s16()])
			var bounds := Rect2i(raw_bounds[0],raw_bounds[1],raw_bounds[2] - raw_bounds[0],raw_bounds[3] - raw_bounds[1])
			var ref_count: int = reader.u16()
			total_refs += ref_count
			if total_refs > MAX_REFERENCES: return _fail("SP2 reference limit exceeded.")
			if not reader.need(ref_count * 5): return _fail(reader.error)
			var aa: PackedByteArray = reader.take(ref_count)
			var bb: PackedByteArray = reader.take(ref_count)
			var types: PackedByteArray = reader.take(ref_count)
			var refs: Array[Dictionary] = []
			var index: int = 0
			for ref: int in range(ref_count):
				var raw_word: int = reader.u16()
				var delta: int = raw_word - 65536 if raw_word >= 32768 else raw_word
				index = raw_word if ref == 0 else ((index + delta + 1) & 65535)
				refs.append({"a":aa[ref] - 256 if aa[ref] >= 128 else aa[ref],"b":bb[ref] - 256 if bb[ref] >= 128 else bb[ref],"type":int(types[ref]),"index":index,"raw_reference_word":raw_word})
			frames.append({"bounds":bounds,"raw_bounds":raw_bounds,"refs":refs})
		var block_count: int = reader.s32()
		total_blocks += block_count
		if not reader.error.is_empty(): return _fail(reader.error)
		if block_count < 0 or total_blocks > MAX_BLOCKS: return _fail("Invalid SP2 block count.")
		if not reader.need(block_count * 3): return _fail(reader.error)
		var blocks: Array[Dictionary] = []
		for _block: int in range(block_count):
			if not reader.need(3): return _fail(reader.error)
			var bx: int = reader.u8()
			var by: int = reader.u8()
			var command_count: int = reader.u8()
			total_commands += command_count
			if total_commands > MAX_COMMANDS: return _fail("SP2 command limit exceeded.")
			if not reader.need(command_count * 2): return _fail(reader.error)
			var commands := PackedInt32Array()
			for _command: int in range(command_count): commands.append(reader.u16())
			blocks.append({"x":bx,"y":by,"commands":commands})
		groups.append({"bit":bit,"frames":frames,"blocks":blocks})
	FRAME_HITCH.detail("sp2.decoder_metadata", metadata_started)
	FRAME_HITCH.count("sp2.decoder_blocks", total_blocks)
	FRAME_HITCH.count("sp2.decoder_commands", total_commands)
	FRAME_HITCH.count("sp2.decoder_references", total_refs)
	# All groups' metadata precede all groups' palette-index streams.
	for group: Dictionary in groups:
		var samples_started: int = FRAME_HITCH.now()
		for block: Dictionary in group.blocks:
			var decoded: Dictionary = _read_block(reader,block,palette.size())
			if not decoded.ok: return decoded
			total_samples += int(block.sample_count)
			if total_samples > MAX_SAMPLES: return _fail("SP2 sample limit exceeded.")
		FRAME_HITCH.detail("sp2.decoder_samples", samples_started)
		var geometry_started: int = FRAME_HITCH.now()
		for frame: Dictionary in group.frames:
			var geometry: Dictionary = _frame_geometry(frame,group.blocks)
			if not geometry.ok: return geometry
			frame["empty"] = geometry.empty
			frame["sample_count"] = geometry.sample_count
			frame["sample_extent"] = geometry.extent
			frame_count += 1
			if not geometry.empty: nonempty_count += 1
		FRAME_HITCH.detail("sp2.decoder_geometry", geometry_started)
	if not reader.error.is_empty(): return _fail(reader.error)
	if reader.position != body.size(): return _fail("Trailing SP2 bytes: %d." % (body.size() - reader.position))
	var all_exact: bool = true
	var bounds_started: int = FRAME_HITCH.now()
	for group: Dictionary in groups:
		for frame: Dictionary in group.frames:
			if frame.empty: continue
			var rule: String = frame_bounds_rule(frame.bounds,frame.sample_extent)
			if rule.is_empty(): return _fail("SP2 sample extent does not match native half-open bounds (nor end-inclusive bounds).")
			frame["bounds_rule"] = rule
			if rule != "half_open": all_exact = false
			if rule == "end_inclusive":
				var stored: Rect2i = frame.bounds
				frame["bounds"] = Rect2i(stored.position,stored.size + Vector2i.ONE)
			elif rule == "half_open_overflow" or rule == "end_inclusive_overflow":
				# The samples start before the stored origin: the canvas grows to
				# cover every sample the frame references (nothing is clipped).
				var anchored: Rect2i = frame.bounds
				if rule == "end_inclusive_overflow": anchored = Rect2i(anchored.position,anchored.size + Vector2i.ONE)
				frame["bounds"] = anchored.merge(frame.sample_extent)
			var bounds: Rect2i = frame.bounds
			if bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.size.x > MAX_DIMENSION or bounds.size.y > MAX_DIMENSION or bounds.size.x * bounds.size.y > MAX_CANVAS_PIXELS:
				return _fail("SP2 native frame bounds exceed the canvas limit.")
	FRAME_HITCH.detail("sp2.decoder_bounds", bounds_started)
	FRAME_HITCH.count("sp2.decoder_samples", total_samples)
	return {"ok":true,"error":"","palette":palette,"mask":mask,"groups":groups,"frame_count":frame_count,"nonempty_count":nonempty_count,"sample_count":total_samples,"bounds_rule":"half_open" if all_exact else "per_frame"}

## "half_open": the samples fill the stored bounds exactly (the long-standing
## rule). "half_open_margin": they end exactly on the stored half-open end with
## blank rows/columns before them. "end_inclusive": they end exactly on the
## stored x2/y2 pixel. "*_overflow": the same end, but the samples start
## before the stored origin. "" when none holds.
static func frame_bounds_rule(stored: Rect2i,extent: Rect2i) -> String:
	if extent == stored: return "half_open"
	if extent.end == stored.end and stored.encloses(extent): return "half_open_margin"
	var inclusive := Rect2i(stored.position,stored.size + Vector2i.ONE)
	if extent.end == inclusive.end and inclusive.encloses(extent): return "end_inclusive"
	# A few frames (e.g. two death frames of the ogre 1020) end exactly on the
	# stored end but start above/left of the stored origin. The end anchor still
	# identifies the reading; a frame whose end matches neither stays rejected.
	if extent.end == stored.end and extent.position.x <= stored.position.x and extent.position.y <= stored.position.y: return "half_open_overflow"
	if extent.end == inclusive.end and extent.position.x <= stored.position.x and extent.position.y <= stored.position.y: return "end_inclusive_overflow"
	return ""

static func _read_block(reader: Reader,block: Dictionary,palette_size: int) -> Dictionary:
	var commands: PackedInt32Array = block.commands
	# A block's sample bytes are contiguous. Keep the exact per-command bounds
	# check (including truncation position/count), but copy the range only once.
	var sample_start: int = reader.position
	var sample_count: int = 0
	var runs := PackedInt32Array() # Repeated x, y, sample-offset, sample-count.
	runs.resize(commands.size() * 4)
	var run_size: int = 0
	var xx: int = 0
	var yy: int = 0
	var has_samples: bool = false
	var extent := Rect2i()
	for word: int in commands:
		xx += word & 31
		var count: int = (word >> 5) & 31
		var step: int = word >> 10
		if not reader.need(count): return _fail(reader.error)
		reader.position += count
		if count > 0:
			runs[run_size] = xx
			runs[run_size + 1] = yy
			runs[run_size + 2] = sample_count
			runs[run_size + 3] = count
			run_size += 4
			sample_count += count
			var run_bounds := Rect2i(xx,yy,count,1)
			extent = extent.merge(run_bounds) if has_samples else run_bounds
			has_samples = true
		if step > 0:
			yy += step
			xx = 0
		else:
			xx += count
	runs.resize(run_size)
	var indices: PackedByteArray = reader.data.slice(sample_start, reader.position)
	# Palette range for the whole block at once (native scans) instead of a
	# GDScript loop over every sample; the first offending sample in stream
	# order is reported exactly as before.
	if palette_size < 256 and not indices.is_empty():
		for value: int in range(palette_size, 256):
			if indices.has(value):
				for sample: int in indices:
					if sample >= palette_size: return _fail("Palette index %d exceeds %d entries." % [sample,palette_size])
	block["indices"] = indices
	block["runs"] = runs
	block["sample_count"] = indices.size()
	block["sample_bounds"] = extent
	block["empty"] = not has_samples
	return {"ok":true,"error":""}

static func _placement(ref: Dictionary,block: Dictionary) -> Vector2i:
	# Arithmetic floor-half, including negative odd a; integer / truncates instead.
	var half: int = floori(float(ref.a) / 2.0)
	return Vector2i(24 * (int(ref.b) + int(ref.a) - half) + int(block.x),12 * (int(ref.b) - half) + int(block.y))

static func _frame_geometry(frame: Dictionary,blocks: Array[Dictionary]) -> Dictionary:
	var extent := Rect2i()
	var has_samples: bool = false
	var sample_count: int = 0
	for ref: Dictionary in frame.refs:
		var index: int = int(ref.index)
		if index < 0 or index >= blocks.size(): return _fail("SP2 block reference %d exceeds %d blocks." % [index,blocks.size()])
		var block: Dictionary = blocks[index]
		sample_count += int(block.sample_count)
		if sample_count > MAX_SAMPLES: return _fail("SP2 frame sample limit exceeded.")
		if block.empty: continue
		var current: Rect2i = block.sample_bounds
		current.position += _placement(ref,block)
		extent = extent.merge(current) if has_samples else current
		has_samples = true
	return {"ok":true,"error":"","empty":not has_samples,"sample_count":sample_count,"extent":extent}

static func render(parsed: Dictionary,group_index: int,frame_index: int,options: Dictionary = {}) -> Dictionary:
	if not parsed.get("ok",false): return _fail("Cannot render an invalid SP2 parse.")
	var alpha: String = str(options.get("alpha_policy","opaque_samples"))
	var rgb: String = str(options.get("rgb_policy","bit_replication"))
	if alpha not in ["opaque_samples","index0_transparent"]: return _fail("Unknown estimated alpha policy.")
	if rgb not in ["bit_replication","linear"]: return _fail("Unknown estimated RGB policy.")
	var groups: Array = parsed.get("groups",[])
	if group_index < 0 or group_index >= groups.size(): return _fail("SP2 stored group index is out of range.")
	var group: Dictionary = groups[group_index]
	if frame_index < 0 or frame_index >= group.frames.size(): return _fail("SP2 frame index is out of range.")
	var frame: Dictionary = group.frames[frame_index]
	var bounds: Rect2i = frame.bounds
	var geometry: Dictionary = _frame_geometry(frame,group.blocks)
	if not geometry.ok: return geometry
	# Every sample must land on the canvas (parse checked the bounds rule).
	if not geometry.empty and (bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.size.x * bounds.size.y > MAX_CANVAS_PIXELS or not bounds.encloses(geometry.extent)):
		return _fail("SP2 samples fall outside the frame canvas.")
	if geometry.empty:
		return {"ok":true,"error":"","image":Image.create(1,1,false,Image.FORMAT_RGBA8),"offset":bounds.position,"bounds":bounds,"empty":true,"estimated":true,"alpha_policy":alpha,"rgb_policy":rgb}
	var palette: PackedInt32Array = parsed.palette
	var colors := PackedByteArray()
	for index: int in range(palette.size()):
		var word: int = palette[index]
		var red: int = (word >> 11) & 31
		var green: int = (word >> 5) & 63
		var blue: int = word & 31
		if rgb == "bit_replication":
			red = (red << 3) | (red >> 2)
			green = (green << 2) | (green >> 4)
			blue = (blue << 3) | (blue >> 2)
		else:
			red = red * 255 / 31
			green = green * 255 / 63
			blue = blue * 255 / 31
		colors.append_array(PackedByteArray([red,green,blue,0 if alpha == "index0_transparent" and index == 0 else 255]))
	var pixels := PackedByteArray()
	pixels.resize(bounds.size.x * bounds.size.y * 4)
	# Every stored covered sample overwrites in reference order, including index0.
	# Type bytes are preserved but do not select invented opacity/blend equations.
	for ref: Dictionary in frame.refs:
		var block: Dictionary = group.blocks[int(ref.index)]
		var origin: Vector2i = _placement(ref,block) - bounds.position
		var runs: PackedInt32Array = block.runs
		var indices: PackedByteArray = block.indices
		for run: int in range(0,runs.size(),4):
			var destination: int = ((origin.y + runs[run + 1]) * bounds.size.x + origin.x + runs[run]) * 4
			for sample: int in range(runs[run + 3]):
				var color: int = int(indices[runs[run + 2] + sample]) * 4
				pixels[destination] = colors[color]
				pixels[destination + 1] = colors[color + 1]
				pixels[destination + 2] = colors[color + 2]
				pixels[destination + 3] = colors[color + 3]
				destination += 4
	return {"ok":true,"error":"","image":Image.create_from_data(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8,pixels),"offset":bounds.position,"bounds":bounds,"empty":false,"estimated":true,"alpha_policy":alpha,"rgb_policy":rgb}
