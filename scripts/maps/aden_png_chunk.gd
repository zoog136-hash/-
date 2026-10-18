extends Node2D
## Same production chunk lifecycle and foot-based Y-sort as RemakeSourceRenderer.
## The compiler removes every reviewed foreground cut from the ground exactly.
var texture_cache: Dictionary
const LAYER_SHADER = preload("res://scripts/maps/png_layer.gdshader")

func texture(path: String) -> Texture2D:
	if texture_cache.has(path): return texture_cache[path]
	var image := Image.new()
	if image.load(path) != OK: return null
	var value: ImageTexture = ImageTexture.create_from_image(image)
	texture_cache[path] = value
	return value

func build_png(field: OriginalPlayableField, key: Vector2i, pack: RefCounted, region: Dictionary) -> void:
	y_sort_enabled = true
	set_meta("aden_png_verified",not bool(pack.get("review_active")))
	set_meta("source_png",true)
	set_meta("png_review",bool(pack.get("review_active")))
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
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if pack.get("ground_sampler") == "linear" else CanvasItem.TEXTURE_FILTER_NEAREST
	if ground.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR:
		var layer_material := ShaderMaterial.new()
		layer_material.shader = LAYER_SHADER
		ground.material = layer_material
	add_child(ground)
	if "--png-collision-overlay" in OS.get_cmdline_user_args():
		var overlay := SourceBoundaryOverlay.new()
		overlay.name = "OriginalCollisionOverlay";overlay.z_index = 50
		for y: int in range(key.y*32,mini((key.y+1)*32,field.height)):
			for x: int in range(key.x*32,mini((key.x+1)*32,field.width)):
				var cell := Vector2i(x,y)
				if field.value_at(cell,true) == 0: continue
				for heading: int in [0,2,4,6]:
					var open: bool = (field as RemakePlayableField).source_can_step(cell,heading) if field is RemakePlayableField else field.can_step(cell,heading)
					if not open: overlay.edges.append_array(field.coordinates.edge_points(cell,heading))
		if field is RemakePlayableField and field.png_review_footprints != null:
			for polygon: PackedVector2Array in field.png_review_footprints.polygons:
				var center := Vector2.ZERO
				for p: Vector2 in polygon: center += p
				var owner: Vector2i = field.world_to_cell(center/polygon.size())
				if Vector2i(owner.x/32,owner.y/32) != key: continue
				for i: int in range(polygon.size()): overlay.manual_edges.append_array(PackedVector2Array([polygon[i],polygon[(i+1)%polygon.size()]]))
		add_child(overlay)
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
		sprite.texture_filter = ground.texture_filter
		sprite.material = ground.material
		sprite.set_meta("png_cut_id",str(cut.id))
		sprite.set_meta("png_foot_image",cut.get("foot_image",[]))
		sprite.set_meta("collision_correspondence",cut.get("collision_correspondence","REVIEW_REQUIRED"))

class SourceBoundaryOverlay extends Node2D:
	var edges := PackedVector2Array()
	var manual_edges := PackedVector2Array()
	func _draw() -> void:
		if not edges.is_empty(): draw_multiline(edges,Color(1,.08,.1,.8),1.5,true)
		if not manual_edges.is_empty(): draw_multiline(manual_edges,Color(.05,.95,1,.95),2.0,true)
