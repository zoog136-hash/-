extends RefCounted
## Draw-local metadata memo: retain every observed subimage and its order.
## Never retains pack identities across redraws, replacement or validation.
static func identities(pack: RefCounted, refs: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for ref: int in refs:
		var tile_id: int=ref>>8
		if not result.has(tile_id):result[tile_id]=pack.source_usage_identity(tile_id)
	return result
