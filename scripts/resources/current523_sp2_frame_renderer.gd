extends RefCounted
## Same SP2 pixel policy as current523_sp2_decoder.render(), with one little-
## endian packed RGBA write per sample. Keep the decoder file unchanged: its
## bytes key the installed device parse cache, even when only render changes.
## Parsing, placement and geometry validation remain with that decoder. This
## limited render implementation is checked byte-for-byte against its oracle.
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

static func render(parsed: Dictionary, group_index: int, frame_index: int, options: Dictionary = {}) -> Dictionary:
	var started: int = FRAME_HITCH.now()
	var result: Dictionary = _render(parsed, group_index, frame_index, options)
	FRAME_HITCH.detail("sp2.pixel_render", started)
	return result

static func _render(parsed: Dictionary,group_index: int,frame_index: int,options: Dictionary = {}) -> Dictionary:
	if not parsed.get("ok",false): return DECODER._fail("Cannot render an invalid SP2 parse.")
	var alpha: String = str(options.get("alpha_policy","opaque_samples"))
	var rgb: String = str(options.get("rgb_policy","bit_replication"))
	if alpha not in ["opaque_samples","index0_transparent"]: return DECODER._fail("Unknown estimated alpha policy.")
	if rgb not in ["bit_replication","linear"]: return DECODER._fail("Unknown estimated RGB policy.")
	var groups: Array = parsed.get("groups",[])
	if group_index < 0 or group_index >= groups.size(): return DECODER._fail("SP2 stored group index is out of range.")
	var group: Dictionary = groups[group_index]
	if frame_index < 0 or frame_index >= group.frames.size(): return DECODER._fail("SP2 frame index is out of range.")
	var frame: Dictionary = group.frames[frame_index]
	var bounds: Rect2i = frame.bounds
	var geometry: Dictionary = DECODER._frame_geometry(frame,group.blocks)
	if not geometry.ok: return geometry
	# Every sample must land on the canvas (parse checked the bounds rule).
	if not geometry.empty and (bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.size.x * bounds.size.y > DECODER.MAX_CANVAS_PIXELS or not bounds.encloses(geometry.extent)):
		return DECODER._fail("SP2 samples fall outside the frame canvas.")
	if geometry.empty:
		return {"ok":true,"error":"","image":Image.create(1,1,false,Image.FORMAT_RGBA8),"offset":bounds.position,"bounds":bounds,"empty":true,"estimated":true,"alpha_policy":alpha,"rgb_policy":rgb}
	var palette: PackedInt32Array = parsed.palette
	var colors := PackedInt64Array()
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
		colors.append(red | (green << 8) | (blue << 16) | ((0 if alpha == "index0_transparent" and index == 0 else 255) << 24))
	var pixels := PackedByteArray()
	pixels.resize(bounds.size.x * bounds.size.y * 4)
	# Every stored covered sample overwrites in reference order, including index0.
	# Type bytes are preserved but do not select invented opacity/blend equations.
	for ref: Dictionary in frame.refs:
		var block: Dictionary = group.blocks[int(ref.index)]
		var origin: Vector2i = DECODER._placement(ref,block) - bounds.position
		var runs: PackedInt32Array = block.runs
		var indices: PackedByteArray = block.indices
		for run: int in range(0,runs.size(),4):
			var destination: int = ((origin.y + runs[run + 1]) * bounds.size.x + origin.x + runs[run]) * 4
			for sample: int in range(runs[run + 3]):
				pixels.encode_u32(destination, colors[int(indices[runs[run + 2] + sample])])
				destination += 4
	return {"ok":true,"error":"","image":Image.create_from_data(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8,pixels),"offset":bounds.position,"bounds":bounds,"empty":false,"estimated":true,"alpha_policy":alpha,"rgb_policy":rgb}
