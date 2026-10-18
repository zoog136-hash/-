extends Node2D
## First approval area only. Reuses source coordinates, streaming and physics.
## S32 image identities remain unverified; these are original TWILIGHT sprites.
const ROOT: String = "res://data/aden_giran_review/"
const ART: String = "res://assets/maps/aden_giran_review_v1/"
const REVIEW_RECT := Rect2i(928,672,128,192)
static var layout: Dictionary = {}
static var surfaces: PackedByteArray = PackedByteArray()
static var sprite_info: Array = []
static var atlas: Texture2D
static var ground_material: ShaderMaterial
static var initialization_attempted: bool = false
var actor: Node2D
var map: OriginalPlayableField
var roofs: Array[Dictionary] = []

static func applies(source: OriginalPlayableField, key: Vector2i) -> bool:
	if str(source.data.map_id) != "aden_world" or not REVIEW_RECT.has_point(key*32): return false
	if not initialization_attempted:
		initialization_attempted = true
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"layout.json"))
		if not value is Dictionary or value.get("source_cell_rect") != [928.0,672.0,128.0,192.0]:
			push_error("GIRAN_REVIEW invalid visual layout")
			return false
		surfaces = FileAccess.get_file_as_bytes(ROOT+"surfaces.bin")
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256); hash.update(surfaces)
		if surfaces.size() != REVIEW_RECT.size.x*REVIEW_RECT.size.y or hash.finish().hex_encode() != str(value.get("surface_sha256")):
			push_error("GIRAN_REVIEW visual surface hash mismatch")
			return false
		if FileAccess.get_sha256("res://data/map_remake/private/aden/definitions/aden_world.json") != str(value.get("source_definition_sha256")):
			push_error("GIRAN_REVIEW requires its recorded immutable Aden definition")
			return false
		layout = value
		sprite_info = JSON.parse_string(FileAccess.get_file_as_string(ART+"sprites.json")).sprites
		atlas = load(ART+"props.png")
		ground_material = ShaderMaterial.new()
		ground_material.shader = load(ART+"ground.gdshader")
		ground_material.set_shader_parameter("terrain_atlas",load(ART+"terrain.png"))
	return not layout.is_empty()

func build(value: OriginalPlayableField, key: Vector2i, _mat: ShaderMaterial, _profile: Dictionary, debug: bool) -> void:
	map = value
	actor = get_parent().player
	set_meta("giran_review",true)
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var covered: Dictionary = {}
	for flat: Variant in layout.covered_blocked_cells: covered[int(flat)] = true
	var garden: Dictionary = {}
	for flat: Variant in layout.garden_cells: garden[int(flat)] = true
	for y: int in range(key.y*32,(key.y+1)*32):
		for x: int in range(key.x*32,(key.x+1)*32):
			var cell := Vector2i(x,y)
			var opened: bool = map.value_at(cell,true) != 0
			var at: int = vertices.size()
			var kind: int = int(surfaces[(y-REVIEW_RECT.position.y)*REVIEW_RECT.size.x+x-REVIEW_RECT.position.x])
			for point: Vector2 in map.coordinates.cell_polygon(cell):
				vertices.append(point)
				uv.append(map.coordinates.world_to_grid(point)/14.0)
				colors.append((Color("327d5e") if opened else Color("bd424c")) if debug else Color(float(kind)/3.0,1,1,1))
			indices.append_array(PackedInt32Array([at,at+1,at+2,at,at+2,at+3]))
			if not debug and garden.has(y*map.width+x):
				for heading: int in [0,2,4,6]:
					var next: Vector2i = cell+map.DIRECTIONS[heading]
					if garden.has(next.y*map.width+next.x): continue
					var edge: PackedVector2Array = map.coordinates.edge_points(cell,heading)
					var curb: Sprite2D = _add_sprite(6 if (edge[1]-edge[0]).y<0 else 7,(edge[0]+edge[1])*.5,edge[0].distance_to(edge[1])*1.10)
					curb.scale.y *= .30
					curb.modulate = Color(1.5,1.5,1.4)
			if debug or not opened: continue
			for heading: int in [0,2,4,6]:
				if map.can_step(cell,heading): continue
				var next: Vector2i = cell+map.DIRECTIONS[heading]
				if covered.has(next.y*map.width+next.x): continue
				if map.value_at(next,true) != 0 and (next.y<y or (next.y==y and next.x<x)): continue
				var edge: PackedVector2Array = map.coordinates.edge_points(cell,heading)
				# Textured low coping marks still-unidentified source edges. It is
				# not presented as a recovered wall/tree/building classification.
				_add_sprite(6 if (edge[1]-edge[0]).y<0 else 7,(edge[0]+edge[1])*.5,edge[0].distance_to(edge[1])*1.10)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ground := MeshInstance2D.new()
	ground.name = "GiranTexturedSourceGround"
	ground.z_index = -20
	ground.mesh = mesh
	if not debug: ground.material = ground_material
	add_child(ground)
	if debug: return
	for record: Dictionary in layout.props:
		var p := Vector2(record.position[0],record.position[1])
		var foot_cell: Vector2i = map.world_to_cell(p)
		if Vector2i(floori(float(foot_cell.x)/32),floori(float(foot_cell.y)/32)) != key: continue
		var sprite: Sprite2D = _add_sprite(int(record.slot),p,float(record.width))
		if record.has("height"): sprite.scale.y = float(record.height)/sprite.texture.get_height()
		sprite.name = str(record.id)
		sprite.set_meta("source_box",record.source_box)
		if str(record.kind) in ["building","hall"]:
			var b: Array = record.source_box
			roofs.append({"sprite":sprite,"box":Rect2i(int(b[0]),int(b[1]),int(b[2]),int(b[3]))})
	set_process(not roofs.is_empty())

func _add_sprite(slot: int, point: Vector2, width: float) -> Sprite2D:
	var info: Dictionary = sprite_info[slot]
	var rect: Array = info.rect
	var part := AtlasTexture.new()
	part.atlas = atlas
	part.region = Rect2(rect[0],rect[1],rect[2],rect[3])
	var sprite := Sprite2D.new()
	sprite.texture = part
	sprite.centered = false
	sprite.offset = -Vector2(info.foot[0],info.foot[1])
	sprite.position = point
	sprite.scale = Vector2.ONE*width/float(rect[2])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	return sprite

func _process(_delta: float) -> void:
	if not is_instance_valid(actor): return
	var cell: Vector2i = map.world_to_cell(actor.global_position)
	for roof: Dictionary in roofs:
		# Reveal existing walkable house interiors. No navigation or collider
		# is carved to make a generated building fit.
		roof.sprite.modulate.a = .40 if (roof.box as Rect2i).has_point(cell) else 1.0
