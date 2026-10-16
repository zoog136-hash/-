extends Node2D
## Full source-grid visual expansion. Physics and approved Giran inputs are read-only.
const ROOT := "res://data/aden_world_visuals/"
const ART := "res://assets/maps/aden_world_visuals_v1/"
const APPROVED := "res://assets/maps/aden_giran_review_v1/"
const GIRAN_RECT := Rect2i(928,672,128,192)
static var manifest: Dictionary = {}
static var sprites: Array = []
static var textures: Array[Texture2D] = []
static var sprite_materials: Array[ShaderMaterial] = []
static var ground_material: ShaderMaterial
static var attempted: bool = false
static var garden: Dictionary = {}
static var prop_reads: int = 0
var roofs: Array[Dictionary] = []
var actor: Node2D
var source: OriginalPlayableField

static func applies(field: OriginalPlayableField, _key: Vector2i) -> bool:
	if str(field.data.map_id) != "aden_world": return false
	if not attempted:
		attempted = true
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
		if not data is Dictionary or data.get("dimensions") != [2048.0,1536.0]:
			push_error("ADEN_VISUAL invalid manifest"); return false
		if FileAccess.get_sha256("res://data/map_remake/private/aden/definitions/aden_world.json") != str(data.source_definition_sha256):
			push_error("ADEN_VISUAL immutable source definition changed"); return false
		if FileAccess.get_sha256(ROOT+"materials.png") != str(data.material_sha256):
			push_error("ADEN_VISUAL material lookup SHA mismatch"); return false
		manifest = data
		textures.append(load(APPROVED+"props.png"))
		textures.append(load(ART+"structures.png"))
		textures.append(load(ART+"nature.png"))
		textures.append(load(ART+"landmarks.png"))
		sprites.append_array(JSON.parse_string(FileAccess.get_file_as_string(APPROVED+"sprites.json")).sprites)
		var regional: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART+"sprites.json"))
		sprites.append_array(regional.structures)
		sprites.append_array(regional.nature)
		sprites.append_array(regional.landmarks)
		for name: String in ["structures","nature","landmarks"]:
			var ids: Texture2D = load(ART+name+"_ids.png")
			for slot: int in range(4 if name=="landmarks" else 16):
				var isolated := ShaderMaterial.new()
				isolated.shader = load("res://scripts/maps/aden_world_visuals/sprite.gdshader")
				isolated.set_shader_parameter("sprite_ids",ids)
				isolated.set_shader_parameter("sprite_id",float(slot+1))
				sprite_materials.append(isolated)
		var giran: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/aden_giran_review/layout.json"))
		for flat: Variant in giran.garden_cells: garden[int(flat)] = true
		ground_material = ShaderMaterial.new()
		ground_material.shader = load("res://scripts/maps/aden_world_visuals/ground.gdshader")
		ground_material.set_shader_parameter("material_map",load(ROOT+"materials.png"))
		ground_material.set_shader_parameter("approved_terrain",load(APPROVED+"terrain.png"))
		ground_material.set_shader_parameter("regional_terrain",load(ART+"terrain.png"))
	return not manifest.is_empty()

func build(field: OriginalPlayableField, key: Vector2i, _mat: ShaderMaterial, _profile: Dictionary, debug: bool) -> void:
	source = field
	actor = get_parent().player
	set_meta("aden_world_visuals",true)
	set_meta("giran_review",GIRAN_RECT.has_point(key*32))
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	if debug:
		for y: int in range(key.y*32,(key.y+1)*32):
			for x: int in range(key.x*32,(key.x+1)*32):
				var at: int = vertices.size()
				for point: Vector2 in field.coordinates.cell_polygon(Vector2i(x,y)):
					vertices.append(point);uv.append(field.coordinates.world_to_grid(point))
					colors.append(Color("327d5e") if field.value_at(Vector2i(x,y),true)!=0 else Color("bd424c"))
				indices.append_array(PackedInt32Array([at,at+1,at+2,at,at+2,at+3]))
	else:
		# One textured source-coordinate quad; lookup covers every immutable cell.
		for cell: Vector2 in [Vector2(key*32),Vector2(key*32+Vector2i(32,0)),Vector2((key+Vector2i.ONE)*32),Vector2(key*32+Vector2i(0,32))]:
			vertices.append(field.coordinates.grid_to_world(cell.x,cell.y));uv.append(cell);colors.append(Color.WHITE)
		indices.append_array(PackedInt32Array([0,1,2,0,2,3]))
	var arrays: Array = [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices;arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors;arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ground := MeshInstance2D.new();ground.name = "AdenContinuousTexturedGround"
	ground.z_index = -20;ground.mesh = mesh
	if not debug: ground.material = ground_material
	add_child(ground)
	if debug: return
	# Only the six source-observed Giran garden strips keep their approved curb.
	if GIRAN_RECT.has_point(key*32):
		for y: int in range(key.y*32,(key.y+1)*32):
			for x: int in range(key.x*32,(key.x+1)*32):
				if not garden.has(y*field.width+x): continue
				for heading: int in [0,2,4,6]:
					var next: Vector2i = Vector2i(x,y)+field.DIRECTIONS[heading]
					if garden.has(next.y*field.width+next.x): continue
					var edge: PackedVector2Array = field.coordinates.edge_points(Vector2i(x,y),heading)
					var curb: Sprite2D = add_sprite(6 if (edge[1]-edge[0]).y<0 else 7,(edge[0]+edge[1])*.5,edge[0].distance_to(edge[1])*1.10)
					curb.scale.y *= .22;curb.modulate = Color(1.5,1.5,1.4)
	var path: String = ROOT+"props/%d_%d.json" % [key.x,key.y]
	if FileAccess.file_exists(path):
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path));prop_reads += 1
		if not records is Array: push_error("ADEN_VISUAL invalid prop chunk "+path);return
		for p: Array in records:
			var sprite: Sprite2D = add_sprite(int(p[0]),Vector2(p[1],p[2]),float(p[3]))
			if float(p[4])>0: sprite.scale.y = float(p[4])/sprite.texture.get_height()
			sprite.set_meta("placement_kind",str(p[6]));sprite.set_meta("s32_tile_id",int(p[7]))
			if str(p[6]) in ["building","hall","fortified_structure"]:
				var b: Array = p[5]
				roofs.append({"sprite":sprite,"box":Rect2i(int(b[0]),int(b[1]),int(b[2]),int(b[3]))})
	set_process(not roofs.is_empty())

func add_sprite(slot: int, point: Vector2, width: float) -> Sprite2D:
	var info: Dictionary = sprites[slot];var r: Array = info.rect
	var texture := AtlasTexture.new();texture.atlas = textures[slot/16]
	texture.region = Rect2(r[0],r[1],r[2],r[3])
	var sprite := Sprite2D.new();sprite.texture = texture;sprite.centered = false
	sprite.offset = -Vector2(info.foot[0],info.foot[1])
	sprite.position = point;sprite.scale = Vector2.ONE*width/float(r[2])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if slot>=16: sprite.material = sprite_materials[slot-16]
	add_child(sprite);return sprite

func _process(_delta: float) -> void:
	if not is_instance_valid(actor): return
	var cell: Vector2i = source.world_to_cell(actor.global_position)
	for roof: Dictionary in roofs: roof.sprite.modulate.a = .40 if (roof.box as Rect2i).has_point(cell) else 1.0
