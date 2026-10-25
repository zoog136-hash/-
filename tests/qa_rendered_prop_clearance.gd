extends RefCounted

# Aden's current source renderer nests real Sprite2D props in streamed chunks.
# Its inherited legacy `faded` list does not inventory those sprites. Inspect
# the visible scene tree, with actual offsets/scales/AtlasTexture rectangles.
# Native ground is below the actors; all actual props remain conservative.
static func registered_native_ground(renderer: Node, sprite: Sprite2D) -> bool:
	if not renderer is NativePngRenderer: return false
	if sprite.get_parent() != renderer or sprite.z_index != -20: return false
	if sprite.has_meta("native_foreground"): return false
	if not sprite.has_meta("source_file") or not sprite.has_meta("source_position"): return false
	var native: NativePngRenderer = renderer as NativePngRenderer
	var source: String = str(sprite.get_meta("source_file"))
	# Split foreground uses suffixed keys and must never qualify as the base tile.
	return not source.is_empty() and native.chunks.get(source) == sprite

static func clear_bounds(renderer: Node, world_bounds: Rect2) -> bool:
	if not is_instance_valid(renderer): return false
	var pending: Array[Node] = [renderer]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children(): pending.append(child)
		if not node is Sprite2D: continue
		var sprite := node as Sprite2D
		if not sprite.is_visible_in_tree() or sprite.texture == null: continue
		if registered_native_ground(renderer, sprite): continue
		var local: Rect2 = sprite.get_rect()
		if sprite.texture is AtlasTexture:
			var atlas := sprite.texture as AtlasTexture
			local = Rect2(local.position + atlas.margin.position, atlas.region.size)
		if (sprite.global_transform * local).intersects(world_bounds): return false
	return true
