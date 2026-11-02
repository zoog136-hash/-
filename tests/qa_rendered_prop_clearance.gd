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

static func registered_source_ground(renderer: Node, sprite: Sprite2D) -> bool:
	if renderer.get_script() != preload("res://scripts/maps/source_map_runtime_renderer.gd"): return false
	if sprite.get_parent() != renderer or sprite.centered: return false
	var source = renderer
	for key: Variant in source.chunks:
		if source.chunks[key] != sprite: continue
		var index: int = int(key)
		if index < 0 or index >= source.record.chunks.size() or index >= 4096: return false
		if sprite.z_index != -4096 + index: return false
		var effective_z: int = sprite.z_index
		var current: CanvasItem = sprite
		while current.z_as_relative and current.get_parent() is CanvasItem:
			current = current.get_parent() as CanvasItem
			effective_z += current.z_index
		if effective_z >= 0: return false
		var row: Dictionary = source.record.chunks[index]
		return sprite.position == Vector2(row.position[0],row.position[1])
	return false

static func clear_bounds(renderer: Node, world_bounds: Rect2) -> bool:
	if not is_instance_valid(renderer): return false
	var pending: Array[Node] = [renderer]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children(): pending.append(child)
		if not node is Sprite2D: continue
		var sprite := node as Sprite2D
		if not sprite.is_visible_in_tree() or sprite.texture == null: continue
		if registered_native_ground(renderer, sprite) or registered_source_ground(renderer,sprite): continue
		var local: Rect2 = sprite.get_rect()
		if sprite.texture is AtlasTexture:
			var atlas := sprite.texture as AtlasTexture
			local = Rect2(local.position + atlas.margin.position, atlas.region.size)
		if (sprite.global_transform * local).intersects(world_bounds): return false
	return true
