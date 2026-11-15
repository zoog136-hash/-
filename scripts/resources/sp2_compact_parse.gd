extends RefCounted
## Packed form of one current523_sp2_decoder.parse() result, for the shared
## SP2 store (reference_sp2_asset_service) that every 523 monster/NPC bank uses.
##
## Measured (headless, 301 real 523 members): the decoder's Dictionary form is
## ~3.1 MB per member in memory, but only ~0.4 MB of it is data. 364k reference
## Dictionaries took 262 MB and 353k block Dictionaries 549 MB; raw+body bytes
## (read by nobody after parsing) another 100 MB. This form keeps the same
## values in packed arrays:
##   frame.refs        PackedInt32Array, REF_STRIDE ints per reference in the
##                     stored order: a, b, type, index, raw_reference_word
##   group.block_table PackedInt32Array, BLOCK_STRIDE ints per block in stored
##                     order: x, y, run_start, run_end, index_base,
##                     sample_count, empty, sample_bounds x, y, w, h
##   group.runs        every block's runs (x, y, sample offset, count) as parsed
##   group.indices     every block's palette indices, block after block
## Frames keep their Dictionary fields (bounds, raw_bounds, empty, ...) and the
## top level keeps palette/mask/counts, so selection code reads them as before.
## Pixels come from current523_sp2_frame_renderer.render(), which renders this
## form byte-for-byte like the decoder (tests/current523_sp2_frame_renderer_test).
## The decoder and its device parse cache are unchanged (same parse key).
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const SCHEMA := "sp2_compact_parse_v1"
const REF_STRIDE: int = 5
const BLOCK_STRIDE: int = 11

static func is_compact(parsed: Dictionary) -> bool:
	return parsed.get("compact") == SCHEMA

## The packed form of a successful parse; anything else is returned as is.
static func from_parse(parsed: Dictionary) -> Dictionary:
	if not parsed.get("ok", false) or is_compact(parsed): return parsed
	var groups: Array = []
	for group: Dictionary in parsed.groups:
		var table := PackedInt32Array()
		var runs := PackedInt32Array()
		var indices := PackedByteArray()
		var blocks: Array = group.blocks
		table.resize(blocks.size() * BLOCK_STRIDE)
		var at: int = 0
		for block: Dictionary in blocks:
			var start: int = runs.size()
			runs.append_array(block.runs)
			var base: int = indices.size()
			indices.append_array(block.indices)
			var bounds: Rect2i = block.sample_bounds
			table[at] = int(block.x); table[at + 1] = int(block.y)
			table[at + 2] = start; table[at + 3] = runs.size(); table[at + 4] = base
			table[at + 5] = int(block.sample_count); table[at + 6] = 1 if block.empty else 0
			table[at + 7] = bounds.position.x; table[at + 8] = bounds.position.y
			table[at + 9] = bounds.size.x; table[at + 10] = bounds.size.y
			at += BLOCK_STRIDE
		var frames: Array = []
		for frame: Dictionary in group.frames:
			var refs := PackedInt32Array()
			var source: Array = frame.refs
			refs.resize(source.size() * REF_STRIDE)
			var r: int = 0
			for ref: Dictionary in source:
				refs[r] = int(ref.a); refs[r + 1] = int(ref.b); refs[r + 2] = int(ref.type)
				refs[r + 3] = int(ref.index); refs[r + 4] = int(ref.raw_reference_word)
				r += REF_STRIDE
			var packed: Dictionary = {}
			for key: Variant in frame:
				if key != "refs": packed[key] = frame[key]
			packed["refs"] = refs
			frames.append(packed)
		groups.append({"bit":group.bit,"frames":frames,"block_table":table,"runs":runs,"indices":indices})
	var result: Dictionary = {}
	for key: Variant in parsed:
		if key not in ["groups", "raw", "body"]: result[key] = parsed[key]
	result["groups"] = groups
	result["compact"] = SCHEMA
	return result

## Placement of one reference on its block (decoder _placement, same floor-half).
static func placement(a: int, b: int, x: int, y: int) -> Vector2i:
	var half: int = floori(float(a) / 2.0)
	return Vector2i(24 * (b + a - half) + x, 12 * (b - half) + y)

## decoder._frame_geometry() for the packed form: same checks and messages.
static func frame_geometry(frame: Dictionary, group: Dictionary) -> Dictionary:
	var table: PackedInt32Array = group.block_table
	var count: int = table.size() / BLOCK_STRIDE
	var refs: PackedInt32Array = frame.refs
	var extent := Rect2i()
	var has_samples: bool = false
	var sample_count: int = 0
	for r: int in range(0, refs.size(), REF_STRIDE):
		var index: int = refs[r + 3]
		if index < 0 or index >= count: return DECODER._fail("SP2 block reference %d exceeds %d blocks." % [index,count])
		var o: int = index * BLOCK_STRIDE
		sample_count += table[o + 5]
		if sample_count > DECODER.MAX_SAMPLES: return DECODER._fail("SP2 frame sample limit exceeded.")
		if table[o + 6] != 0: continue
		var current := Rect2i(table[o + 7], table[o + 8], table[o + 9], table[o + 10])
		current.position += placement(refs[r], refs[r + 1], table[o], table[o + 1])
		extent = extent.merge(current) if has_samples else current
		has_samples = true
	return {"ok":true,"error":"","empty":not has_samples,"sample_count":sample_count,"extent":extent}

## Packed payload bytes (same meaning as sp2_parsed_payload.bytes_of: buffers
## only, not container overhead).
static func bytes_of(parsed: Dictionary) -> int:
	var total: int = (parsed.get("palette", PackedInt32Array()) as PackedInt32Array).size() * 4
	for group: Dictionary in parsed.get("groups", []):
		total += ((group.block_table as PackedInt32Array).size() + (group.runs as PackedInt32Array).size()) * 4 + (group.indices as PackedByteArray).size()
		for frame: Dictionary in group.frames:
			total += ((frame.refs as PackedInt32Array).size() + (frame.raw_bounds as PackedInt32Array).size()) * 4
	return total
