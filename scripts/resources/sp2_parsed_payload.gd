extends RefCounted
## Allocated packed-buffer payload of current523_sp2_decoder.parse().
## A lower bound, NOT Dictionary/Array/Variant overhead, allocator memory,
## renderer/GPU memory or RSS. Do not serialize the parse just to measure it.
## The decoder/cache retain every source field; accounting stays external.

static func bytes_of(parsed: Dictionary) -> int:
	var raw: PackedByteArray=parsed.get("raw",PackedByteArray())
	var body: PackedByteArray=parsed.get("body",PackedByteArray())
	# The decoder assigns raw itself to body for an FE input (copy on write).
	# A Brotli input has a separate decompressed FE body and both buffers count.
	var total: int=body.size()+(raw.size() if not raw.is_empty() and raw[0]!=254 else 0)
	var palette: PackedInt32Array=parsed.get("palette",PackedInt32Array())
	total+=palette.size()*4
	for group: Dictionary in parsed.get("groups",[]):
		for frame: Dictionary in group.frames:
			var bounds: PackedInt32Array=frame.raw_bounds
			total+=bounds.size()*4
		for block: Dictionary in group.blocks:
			var commands: PackedInt32Array=block.commands
			var runs: PackedInt32Array=block.runs
			var indices: PackedByteArray=block.indices
			total+=(commands.size()+runs.size())*4+indices.size()
	return total
