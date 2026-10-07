extends Node2D
class_name FieldRenderer

const COORD = preload("res://scripts/maps/world_coordinates.gd")
const GROUND_SHADER = preload("res://assets/maps/aden/ground.gdshader")
const WATER_SHADER = preload("res://assets/maps/aden/water.gdshader")
# Atlas regions are measured from the generated source, not assumed to be a grid.
const REGIONS: Dictionary = {
	"oak":Rect2(0,0,390,388), "oak2":Rect2(390,0,273,388),
	"pine":Rect2(665,0,286,386), "birch":Rect2(952,0,302,389),
	"rocks":Rect2(0,388,390,260), "rock":Rect2(391,395,264,255),
	"wall":Rect2(656,408,403,244), "pillar":Rect2(1060,386,194,271),
	"house":Rect2(0,650,389,308), "tower":Rect2(390,647,274,330),
	"waystone":Rect2(665,671,285,303), "market":Rect2(950,670,304,300),
	"grass":Rect2(0,976,387,278), "bush":Rect2(390,984,273,270),
	"crates":Rect2(665,1013,286,241), "statue":Rect2(961,934,293,320)
}
const HEIGHTS: Dictionary = {"oak":310.0,"oak2":285.0,"pine":335.0,"birch":285.0,"rocks":115.0,"rock":110.0,"wall":128.0,"pillar":195.0,"house":290.0,"tower":330.0,"waystone":118.0,"market":205.0,"grass":52.0,"bush":66.0,"crates":65.0,"statue":178.0}
var field: PlayableField
var player: Node2D
var atlas: Texture2D
var textures: Dictionary = {}
var terrain: Texture2D
var buckets: Dictionary = {}
var chunks: Dictionary = {}
var ground: Node2D
var terrain_root: Node2D
var stream_clock: float = 0.0
var faded: Array[Sprite2D] = []
var visible_props: int = 0
var chunk_size: float = 1024.0

func configure(value: PlayableField, actor: Node2D) -> void:
	field = value
	player = actor
	y_sort_enabled = true
	atlas = load(str(field.data["foreground"]["prop_atlas"])) as Texture2D
	terrain = load(str(field.data["background"]["material_atlas"])) as Texture2D
	for kind: String in REGIONS:
		var tex := AtlasTexture.new()
		tex.atlas = atlas
		tex.region = REGIONS[kind]
		tex.filter_clip = true
		textures[kind] = tex
	terrain_root = Node2D.new()
	terrain_root.name = "Terrain"
	terrain_root.z_index = -20
	add_child(terrain_root)
	_build_ground()
	chunk_size = float(field.data["streaming"]["chunk_size"])
	for record: Dictionary in field.data["props"]:
		var key := Vector2i((COORD.array_vector(record["position"]) / chunk_size).floor())
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(record)
	_build_markers()
	refresh_visible()

func _polygon(points: PackedVector2Array, index: int, alpha: float = 1.0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("terrain", terrain)
	material.set_shader_parameter("material_index", float(index))
	material.set_shader_parameter("opacity", alpha)
	poly.material = material
	ground.add_child(poly)
	return poly

func _box_points(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])

func _road(points: Array, width: float, index: int, alpha: float) -> void:
	var line := Line2D.new()
	line.texture = terrain
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	for p: Array in points:
		line.add_point(COORD.array_vector(p))
	line.width = width
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.round_precision = 12
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("terrain",terrain)
	material.set_shader_parameter("material_index",float(index))
	material.set_shader_parameter("opacity",alpha)
	material.set_shader_parameter("edge_fade",true)
	line.material = material
	ground.add_child(line)

func _build_ground() -> void:
	_select_layer("Ground")
	_polygon(_box_points(field.bounds),0)
	_select_layer("Road")
	# Soft multiple road shoulders blend earth into vegetation.
	for road: Dictionary in field.data["roads"]:
		for shoulder: int in [48,28,12,0]:
			_road(road["points"],float(road["width"])+shoulder*2,1,.16 if shoulder>0 else .94)
	# Courtyards and farming plots use separate material layers.
	_select_layer("GroundDetail")
	_courtyard(Rect2(820,3480,1380,1280))
	_courtyard(Rect2(7430,2240,950,990))
	_courtyard(Rect2(10120,1150,770,870))
	for row: int in range(9):
		_road([[880,4900+row*38],[1820,4900+row*38]],22,1,.8)
	_select_layer("Water")
	for water: Dictionary in field.data["water"]:
		var points := PackedVector2Array()
		for p: Array in water["polygon"]:
			points.append(COORD.array_vector(p))
		var bank := Line2D.new()
		bank.points = points
		bank.closed = true
		bank.width = 55
		bank.default_color = Color(.78,.83,.70,1)
		bank.texture = terrain
		bank.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		var bank_material := ShaderMaterial.new()
		bank_material.shader = GROUND_SHADER
		bank_material.set_shader_parameter("terrain",terrain)
		bank_material.set_shader_parameter("material_index",1.0)
		bank.material = bank_material
		ground.add_child(bank)
		var poly := Polygon2D.new()
		poly.polygon = points
		var material := ShaderMaterial.new()
		material.shader = WATER_SHADER
		poly.material = material
		ground.add_child(poly)
	_select_layer("Bridge")
	for bridge: Dictionary in field.data["bridges"]:
		var a: Array = bridge["rect"]
		var box := Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3]))
		_polygon(_box_points(box.grow(15)),1)
		_polygon(_box_points(box),2)
		for y: float in [box.position.y,box.end.y]:
			var shadow := Polygon2D.new()
			shadow.polygon = _box_points(Rect2(box.position.x,y+9,box.size.x,14))
			shadow.color = Color(0.04,.07,.05,.46)
			ground.add_child(shadow)
			var rail := Line2D.new()
			rail.points = PackedVector2Array([Vector2(box.position.x,y),Vector2(box.end.x,y)])
			rail.width = 15
			rail.default_color = Color("aaa38b")
			ground.add_child(rail)
			for x: int in range(int(box.position.x),int(box.end.x),52):
				var block: Polygon2D = _polygon(_box_points(Rect2(x,y-11,49,20)),2)
				block.modulate = Color(.68,.68,.62,1)
				var cap: Polygon2D = _polygon(_box_points(Rect2(x,y-15,49,7)),2)
				cap.modulate = Color(1.15,1.12,.98,1)

func _courtyard(box: Rect2) -> void:
	for radius: float in [1.13,1.05,1.0]:
		var points := PackedVector2Array()
		for i: int in range(32):
			var angle: float = i*TAU/32.0
			var irregular: float = 1.0 + sin(i*2.1)*.028
			points.append(box.get_center()+Vector2(cos(angle),sin(angle))*box.size*.5*radius*irregular)
		_polygon(points,2,.18 if radius>1.0 else .72)

func _build_markers() -> void:
	_select_layer("Teleport")
	for portal: Dictionary in field.data["portal"]:
		var p: Vector2 = COORD.array_vector(portal["position"])
		var ring := Line2D.new()
		ring.width = 2.8
		ring.default_color = Color(.44,.87,.8,.85)
		for i: int in range(49):
			var angle: float = TAU*i/48.0
			ring.add_point(p+Vector2(cos(angle)*49,sin(angle)*25))
		ground.add_child(ring)
		_label(str(portal["name"]),p+Vector2(-90,-148),Color("9ae4d3"))
	for npc: Dictionary in field.data["npc_spawn"]:
		var p: Vector2 = COORD.array_vector(npc["position"])
		var sprite := Sprite2D.new()
		var tex: Texture2D = load("res://assets/sprites/classes/warrior.png") as Texture2D
		var part := AtlasTexture.new()
		part.atlas = tex
		part.region = Rect2(0,0,148,116)
		sprite.texture = part
		sprite.position = p
		sprite.offset = Vector2(0,-52)
		sprite.scale = Vector2.ONE*.78
		add_child(sprite)
		_label(str(npc["name"]),p+Vector2(-90,-107),Color("dfc58a"))

func _label(text_value: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = Vector2(180,26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color("1b241c"))
	label.add_theme_constant_override("outline_size",4)
	label.z_index = 15
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _process(delta: float) -> void:
	stream_clock -= delta
	if stream_clock <= 0.0:
		stream_clock = .15
		refresh_visible()
	for sprite: Sprite2D in faded:
		if not is_instance_valid(sprite):
			continue
		var size: Vector2 = sprite.texture.get_size()*sprite.scale.abs()
		var p: Vector2 = player.global_position
		var behind: bool = p.y < sprite.position.y + 16 and p.y > sprite.position.y - size.y*.83 and absf(p.x-sprite.position.x)<size.x*.34
		sprite.modulate.a = move_toward(sprite.modulate.a,float(field.data["foreground"]["fade_alpha"]) if behind else 1.0,delta*4)

func refresh_visible() -> void:
	var viewport: Viewport = get_viewport()
	var a: Vector2 = COORD.screen_to_world(viewport,Vector2.ZERO)
	var b: Vector2 = COORD.screen_to_world(viewport,viewport.get_visible_rect().size)
	var view := Rect2(a,b-a)
	# During initial map load the camera may not have updated its transform yet.
	if not view.has_point(player.global_position):
		view.position = player.global_position-view.size*.5
	view = view.grow(float(field.data["streaming"]["margin"]))
	var wanted: Dictionary = {}
	var lo := Vector2i((view.position/chunk_size).floor())
	var hi := Vector2i((view.end/chunk_size).floor())
	for y: int in range(lo.y,hi.y+1):
		for x: int in range(lo.x,hi.x+1):
			var key := Vector2i(x,y)
			wanted[key] = true
			if not chunks.has(key) and buckets.has(key):
				_load_chunk(key)
	for key: Vector2i in chunks.keys():
		if not wanted.has(key):
			var node: Node2D = chunks[key]
			remove_child(node)
			node.queue_free()
			chunks.erase(key)
	faded.clear()
	visible_props = 0
	for node: Node2D in chunks.values():
		visible_props += node.get_child_count()
		for sprite: Sprite2D in node.get_children():
			if sprite.has_meta("occluder"):
				faded.append(sprite)

func _load_chunk(key: Vector2i) -> void:
	var node := Node2D.new()
	node.name = "Chunk_%d_%d" % [key.x,key.y]
	node.y_sort_enabled = true
	add_child(node)
	chunks[key] = node
	for record: Dictionary in buckets[key]:
		var kind: String = str(record["kind"])
		var sprite := Sprite2D.new()
		sprite.texture = textures[kind]
		sprite.set_meta("prop_kind",kind)
		sprite.position = COORD.array_vector(record["position"])
		var tex_size: Vector2 = sprite.texture.get_size()
		sprite.offset = Vector2(0,-tex_size.y*.46)
		var scale_value: float = float(HEIGHTS[kind])*float(record["scale"])/tex_size.y
		sprite.scale = Vector2.ONE*scale_value
		sprite.flip_h = bool(record.get("flip",false))
		var tint: float = .93 + fmod(sprite.position.x*.007+sprite.position.y*.011,.12)
		sprite.modulate = Color(tint,tint,tint,1)
		if kind in ["oak","oak2","pine","birch","house","tower","market","pillar"]:
			sprite.set_meta("occluder",true)
		if kind in ["grass","bush"]:
			sprite.z_index = -8
		node.add_child(sprite)

func _select_layer(layer_name: String) -> void:
	ground = Node2D.new()
	ground.name = layer_name
	terrain_root.add_child(ground)
