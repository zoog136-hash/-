extends Node2D
## Same production chunk lifecycle and foot-based Y-sort as RemakeSourceRenderer.
## The compiler removes every reviewed foreground cut from the ground exactly.
var texture_cache: Dictionary

func texture(path: String) -> Texture2D:
	if texture_cache.has(path): return texture_cache[path]
	var image := Image.new()
	if image.load(path) != OK: return null
	var value: ImageTexture = ImageTexture.create_from_image(image)
	texture_cache[path] = value
	return value

func build_png(field: OriginalPlayableField, key: Vector2i, pack: RefCounted, region: Dictionary) -> void:
	y_sort_enabled = true
	set_meta("aden_png_verified",true)
	set_meta("layer_provenance","composite ground; manually reviewed cuts; source collision/navigation; water not separated")
	var ground_texture: Texture2D = texture(pack.root_path.path_join(region.file))
	var mapping: Transform2D = region.transform
	var origin := Vector2(region.image_origin[0],region.image_origin[1])
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for corner: Vector2i in [key*32,key*32+Vector2i(32,0),(key+Vector2i.ONE)*32,key*32+Vector2i(0,32)]:
		var point: Vector2 = field.coordinates.grid_to_world(corner.x,corner.y)
		vertices.append(point);uv.append((mapping*point-origin)/ground_texture.get_size())
	var arrays: Array = [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices;arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ground := MeshInstance2D.new();ground.name = "Ground";ground.z_index = -20
	ground.mesh = mesh;ground.texture = ground_texture
	add_child(ground)
	var inverse: Transform2D = mapping.affine_inverse()
	for cut: Dictionary in region.cuts:
		var foot := Vector2(cut.foot_world[0],cut.foot_world[1])
		var cell: Vector2i = field.world_to_cell(foot)
		if Vector2i(cell.x/32,cell.y/32) != key: continue
		var sprite := Sprite2D.new();sprite.name = "Foreground_"+str(cut.id)
		sprite.texture = texture(pack.root_path.path_join(cut.file));sprite.centered = false
		var at := Vector2(cut.image_origin[0],cut.image_origin[1])
		# The node origin is the real world foot. Image offset is separate so
		# sorting does not accidentally use the roof's top-left pixel.
		sprite.transform = Transform2D(inverse.x,inverse.y,foot)
		sprite.offset = at-mapping*foot
		sprite.set_meta("layer","Foreground");add_child(sprite)
