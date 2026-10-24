extends RefCounted

# Aden's current source renderer nests real Sprite2D props in streamed chunks.
# Its inherited legacy `faded` list does not inventory those sprites. Inspect
# the visible scene tree, with actual offsets/scales/AtlasTexture rectangles.
# Conservatively reject overlap at any draw depth; never hide or move terrain.
static func clear_bounds(renderer: Node, world_bounds: Rect2) -> bool:
	if not is_instance_valid(renderer): return false
	var pending: Array[Node] = [renderer]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children(): pending.append(child)
		if not node is Sprite2D: continue
		var sprite := node as Sprite2D
		if not sprite.is_visible_in_tree() or sprite.texture == null: continue
		var local: Rect2 = sprite.get_rect()
		if sprite.texture is AtlasTexture:
			var atlas := sprite.texture as AtlasTexture
			local = Rect2(local.position + atlas.margin.position, atlas.region.size)
		if (sprite.global_transform * local).intersects(world_bounds): return false
	return true
