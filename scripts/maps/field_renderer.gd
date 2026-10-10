extends Node2D
class_name FieldRenderer

const COORD = preload("res://scripts/maps/world_coordinates.gd")
const GROUND_SHADER = preload("res://assets/maps/aden/ground.gdshader")
const WATER_SHADER = preload("res://assets/maps/aden/water.gdshader")
const LANDMARK = preload("res://scripts/maps/field_landmark.gd")
const LANDMARK_SHADER = preload("res://assets/maps/landmark_cache.gdshader")
const VISUAL_STYLE = preload("res://scripts/maps/visual_style_policy.gd")
const LANDMARK_BAKE_SCALE: float = 1.5
const LANDMARK_CELL: Vector2 = Vector2(256,256)
const LANDMARK_ORIGIN: Vector2 = Vector2(128,224)
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
var landmark_textures: Dictionary = {}
var landmark_cache: SubViewport
var landmark_material: ShaderMaterial
var ground_materials: Dictionary = {}
var terrain: Texture2D
var buckets: Dictionary = {}
var chunks: Dictionary = {}
var ground: Node2D
var terrain_root: Node2D
var stream_clock: float = 0.0
var faded: Array[Node2D] = []
var visible_props: int = 0
var chunk_size: float = 1024.0
var visual_mode: String = VISUAL_STYLE.TWILIGHT
var npc_visuals: Array[Sprite2D] = []

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
	_build_landmark_cache()
	_build_markers()
	_apply_visual_mode()
	refresh_visible()

func set_visual_mode(requested: String) -> void:
	visual_mode = VISUAL_STYLE.normalize(requested)
	_apply_visual_mode()

func _apply_visual_mode() -> void:
	# Only CanvasItem modulation / ground shader appearance changes here.
	# No field map navigation, collision, portal or actor coordinates touched.
	if is_instance_valid(terrain_root):
		terrain_root.modulate = VISUAL_STYLE.ground_tint(visual_mode)
	for raw: Variant in chunks.values():
		if raw is Node2D and is_instance_valid(raw):
			(raw as Node2D).modulate = VISUAL_STYLE.prop_tint(visual_mode)
	for npc: Sprite2D in npc_visuals:
		if is_instance_valid(npc):
			npc.modulate = VISUAL_STYLE.npc_render_tint(str(npc.get_meta("npc_role","")),visual_mode)
	if field != null:
		for raw: Variant in ground_materials.values():
			if raw is ShaderMaterial:
				_style_material(raw as ShaderMaterial)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_WM_WINDOW_FOCUS_IN] and is_instance_valid(landmark_cache):
		# Repaint the small active-map atlas if a mobile graphics context resumes.
		_request_landmark_cache_render()

func _request_landmark_cache_render() -> void:
	landmark_cache.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not RenderingServer.frame_post_draw.is_connected(_freeze_landmark_cache):
		RenderingServer.frame_post_draw.connect(_freeze_landmark_cache,CONNECT_ONE_SHOT)

func _freeze_landmark_cache() -> void:
	# Publish completion on the node after drawing. The one-shot callback keeps
	# the lifecycle observable without adding a per-frame polling task.
	if is_instance_valid(landmark_cache):
		landmark_cache.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _landmark_key(record: Dictionary) -> String:
	return str(record["kind"])+"|"+str(record.get("color",field.data.get("render_style",{}).get("accent","8abed4")))

func _build_landmark_cache() -> void:
	var styles: Dictionary = {}
	for record: Dictionary in field.data["props"]:
		if not textures.has(str(record["kind"])):
			styles[_landmark_key(record)] = record
	if styles.is_empty():
		return
	# One atlas for the active map (3-7 cells in current maps), not one render
	# target per object or a permanent cache of all 25 maps. Each styled drawing
	# is rasterized once; hundreds of instances share its cached Sprite2D cell.
	var columns: int = mini(4,styles.size())
	var rows: int = ceili(float(styles.size())/columns)
	landmark_cache = SubViewport.new()
	landmark_cache.name = "LandmarkAtlas"
	landmark_cache.size = Vector2i(LANDMARK_CELL*Vector2(columns,rows)*LANDMARK_BAKE_SCALE)
	landmark_cache.transparent_bg = true
	landmark_cache.disable_3d = true
	landmark_cache.gui_disable_input = true
	landmark_cache.world_2d = World2D.new()
	landmark_cache.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(landmark_cache)
	landmark_material = ShaderMaterial.new()
	landmark_material.shader = LANDMARK_SHADER
	var index: int = 0
	for key: String in styles:
		var record: Dictionary = styles[key]
		var cell: Vector2 = Vector2(index%columns,index/columns)*LANDMARK_CELL
		var drawing: FieldLandmark = LANDMARK.new()
		drawing.kind = str(record["kind"])
		drawing.accent = Color(str(record.get("color",field.data.get("render_style",{}).get("accent","8abed4"))))
		drawing.stone = Color(str(field.data.get("render_style",{}).get("prop_tint","817e89")))
		drawing.stone_texture = terrain
		drawing.position = (cell+LANDMARK_ORIGIN)*LANDMARK_BAKE_SCALE
		drawing.scale = Vector2.ONE*LANDMARK_BAKE_SCALE
		landmark_cache.add_child(drawing)
		var texture := AtlasTexture.new()
		texture.atlas = landmark_cache.get_texture()
		texture.region = Rect2(cell*LANDMARK_BAKE_SCALE,LANDMARK_CELL*LANDMARK_BAKE_SCALE)
		texture.filter_clip = true
		landmark_textures[key] = texture
		index += 1
	_request_landmark_cache_render()

func _ground_material(index: int, alpha: float = 1.0, edge: bool = false) -> ShaderMaterial:
	var key := Vector3(float(index),alpha,1.0 if edge else 0.0)
	if ground_materials.has(key):
		return ground_materials[key] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("terrain", terrain)
	material.set_shader_parameter("material_index", float(index))
	material.set_shader_parameter("opacity", alpha)
	material.set_shader_parameter("edge_fade",edge)
	_style_material(material)
	ground_materials[key] = material
	return material

func _polygon(points: PackedVector2Array, index: int, alpha: float = 1.0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.material = _ground_material(index,alpha)
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
	line.material = _ground_material(index,alpha,true)
	ground.add_child(line)

func _build_ground() -> void:
	_select_layer("Ground")
	_polygon(_box_points(field.bounds),int(field.data["background"].get("base_material",0)))
	for surface: Dictionary in field.data.get("surfaces", []):
		# Same world-space material is already visible through the wall complement.
		# Redrawing every overlapping room/corridor costs fill rate without changing
		# a single pixel. Keep explicit surfaces for distinct materials/tints only.
		if int(surface.get("material",2)) == int(field.data["background"].get("base_material",0)) and not surface.has("tint"):
			continue
		var a: Array = surface["rect"]
		var box := Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3]))
		var poly: Polygon2D = _polygon(_box_points(box),int(surface.get("material",2)))
		if surface.has("tint"):
			poly.modulate = Color(str(surface["tint"]))
	_select_layer("Road")
	# Soft multiple road shoulders blend earth into vegetation.
	for road: Dictionary in field.data["roads"]:
		for shoulder: int in [48,28,12,0]:
			_road(road["points"],float(road["width"])+shoulder*2,int(road.get("material",1)),(.16 if shoulder>0 else .94)*float(road.get("opacity",1.0)))
	# Courtyards and farming plots use separate material layers.
	_select_layer("GroundDetail")
	if int(field.data.get("schema_version",1)) == 1:
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
		bank.material = _ground_material(1)
		ground.add_child(bank)
		var poly := Polygon2D.new()
		poly.polygon = points
		var material := ShaderMaterial.new()
		material.shader = WATER_SHADER
		if water.has("deep_color"):
			material.set_shader_parameter("deep_color",Color(str(water["deep_color"])))
			material.set_shader_parameter("shallow_color",Color(str(water["shallow_color"])))
		poly.material = material
		ground.add_child(poly)
	_select_layer("Bridge")
	for bridge: Dictionary in field.data["bridges"]:
		var a: Array = bridge["rect"]
		var box := Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3]))
		_polygon(_box_points(box.grow(15)),1)
		_polygon(_box_points(box),2)
		if box.size.y > box.size.x:
			for x: float in [box.position.x,box.end.x]:
				var rail := Line2D.new()
				rail.points = PackedVector2Array([Vector2(x,box.position.y),Vector2(x,box.end.y)])
				rail.width = 15
				rail.default_color = Color("aaa38b")
				ground.add_child(rail)
				for y: int in range(int(box.position.y),int(box.end.y),52):
					var block: Polygon2D = _polygon(_box_points(Rect2(x-11,y,20,49)),2)
					block.modulate = Color(.68,.68,.62,1)
			continue
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
	_select_layer("Wall")
	for shape: Dictionary in field.data["collision"]:
		if str(shape["kind"]) not in ["dungeon_wall","fortress_wall"]:
			continue
		var a: Array = shape["rect"]
		var box := Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3]))
		var stone_color := Color(str(field.data.get("render_style",{}).get("wall_tint","55505e")))
		var wall: Polygon2D = _polygon(_box_points(box),2)
		wall.modulate = stone_color
		var rim := Line2D.new()
		rim.points = _box_points(box)
		rim.closed = true
		rim.width = 8
		rim.default_color = stone_color.lightened(.14)
		ground.add_child(rim)
		var shade := Line2D.new()
		shade.points = PackedVector2Array([Vector2(box.position.x,box.end.y-5),Vector2(box.end.x,box.end.y-5)])
		shade.width = 14
		shade.default_color = Color(0,0,0,.38)
		ground.add_child(shade)

func _style_material(material: ShaderMaterial) -> void:
	var style: Dictionary = field.data.get("render_style",{})
	material.set_shader_parameter("wild_ground",bool(style.get("wild_ground",true)))
	material.set_shader_parameter("palette",Color(str(style.get("palette","ffffff"))) * VISUAL_STYLE.palette_tint(visual_mode))
	material.set_shader_parameter("saturation",float(style.get("saturation",1.0)) * VISUAL_STYLE.saturation_multiplier(visual_mode))
	material.set_shader_parameter("brightness_lift",float(style.get("brightness_lift",0.0)))

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
		var npc_role: String = str(npc.get("role","guide"))
		var tex: Texture2D = load(VISUAL_STYLE.npc_class_art(npc_role)) as Texture2D
		var part := AtlasTexture.new()
		part.atlas = tex
		part.region = Rect2(0,0,148,116)
		sprite.texture = part
		sprite.position = p
		sprite.offset = Vector2(0,-52)
		sprite.scale = Vector2.ONE*.78
		sprite.set_meta("npc_role",npc_role)
		sprite.modulate = VISUAL_STYLE.npc_render_tint(npc_role,visual_mode)
		add_child(sprite)
		npc_visuals.append(sprite)
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
	for sprite: Node2D in faded:
		if not is_instance_valid(sprite):
			continue
		var size: Vector2 = sprite.get_meta("visual_size",Vector2(80,140)) as Vector2
		var p: Vector2 = player.global_position
		var behind: bool = p.y < sprite.position.y + 16 and p.y > sprite.position.y - size.y*.83 and absf(p.x-sprite.position.x)<size.x*.34
		var target_alpha: float = float(field.data["foreground"]["fade_alpha"]) if behind else 1.0
		if not is_equal_approx(sprite.modulate.a,target_alpha):
			sprite.modulate.a = move_toward(sprite.modulate.a,target_alpha,delta*4)

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
			if not chunks.has(key) and field.bounds.intersects(Rect2(Vector2(key)*chunk_size,Vector2.ONE*chunk_size)):
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
		for sprite: Node2D in node.get_children():
			if sprite.has_meta("occluder"):
				faded.append(sprite)

func _load_chunk(key: Vector2i) -> void:
	var node := Node2D.new()
	node.name = "Chunk_%d_%d" % [key.x,key.y]
	node.y_sort_enabled = true
	node.modulate = VISUAL_STYLE.prop_tint(visual_mode)
	add_child(node)
	chunks[key] = node
	_scatter_chunk_groundcover(node,key)
	for record: Dictionary in buckets.get(key, []):
		var kind: String = str(record["kind"])
		if not textures.has(kind):
			var accent := Sprite2D.new()
			accent.texture = landmark_textures[_landmark_key(record)]
			accent.material = landmark_material
			accent.position = COORD.array_vector(record["position"])
			accent.offset = (LANDMARK_CELL*.5-LANDMARK_ORIGIN)*LANDMARK_BAKE_SCALE
			var prop_scale: float = float(record.get("scale",1.0))
			accent.scale = Vector2.ONE*prop_scale/LANDMARK_BAKE_SCALE
			accent.set_meta("prop_kind",kind)
			accent.set_meta("visual_size",LANDMARK.VISUAL_SIZES.get(kind,Vector2(110,160))*prop_scale)
			if kind in ["crystal","obelisk","arch","banner"]:
				accent.set_meta("occluder",true)
			if kind in ["rubble","rune"]:
				accent.z_index = -8
			node.add_child(accent)
			_scatter_ambient_details(node, record, kind)
			continue
		var sprite := Sprite2D.new()
		sprite.texture = textures[kind]
		sprite.set_meta("prop_kind",kind)
		sprite.position = COORD.array_vector(record["position"])
		var tex_size: Vector2 = sprite.texture.get_size()
		sprite.offset = Vector2(0,-tex_size.y*.46)
		var scale_value: float = float(HEIGHTS[kind])*float(record["scale"])/tex_size.y
		sprite.scale = Vector2.ONE*scale_value
		sprite.set_meta("visual_size",tex_size*sprite.scale.abs())
		sprite.flip_h = bool(record.get("flip",false))
		var tint: float = .93 + fmod(sprite.position.x*.007+sprite.position.y*.011,.12)
		sprite.modulate = Color(tint,tint,tint,1)
		if field.data.has("render_style"):
			sprite.modulate *= Color(str(field.data["render_style"].get("prop_tint","ffffff")))
		if kind in ["oak","oak2","pine","birch","house","tower","market","pillar"]:
			sprite.set_meta("occluder",true)
		if kind in ["grass","bush"]:
			sprite.z_index = -8
		node.add_child(sprite)
		_scatter_ambient_details(node, record, kind)

# Map-wide authored-atlas accents, not just around objects. Previously empty
# dungeon floor chunks had zero props and consequently zero new visible pixels.
# Preserve all collision, source map, tile, navigation and spawn coordinates.
func _scatter_chunk_groundcover(parent: Node2D, key: Vector2i) -> void:
	var origin: Vector2 = Vector2(key) * chunk_size
	var local_bounds := Rect2(origin,Vector2.ONE*chunk_size)
	if not local_bounds.intersects(field.bounds): return
	var cover_layer := Node2D.new()
	cover_layer.name = "GroundCoverLayer"
	cover_layer.z_index = -10
	parent.add_child(cover_layer)
	var style: Dictionary = field.data.get("render_style", {})
	var wilderness: bool = bool(style.get("wild_ground",true))
	var field_id: String = str(field.data.get("map_id",field.data.get("id",field.data.get("name",""))))
	var frozen: bool = field_id.contains("albino")
	var volcanic: bool = field_id.contains("escaros")
	var random := RandomNumberGenerator.new()
	random.seed = absi(key.x*73856093 + key.y*19349663 + field_id.hash()) + 101
	var count: int = 68 if wilderness else (49 if frozen else 58)
	for index: int in range(count):
		var position_value: Vector2 = origin + Vector2(random.randf_range(8.0,chunk_size-8.0),random.randf_range(8.0,chunk_size-8.0))
		if not field.bounds.has_point(position_value) or not field.point_clear(position_value,4.0): continue
		var decoration_kind: String = "grass" if wilderness and random.randf() < .72 else ("rock" if random.randf() > .45 else "rocks")
		var source_texture: Texture2D = textures.get(decoration_kind) as Texture2D
		if source_texture == null: continue
		var marker := Sprite2D.new()
		marker.name = "GroundCover"
		marker.texture = source_texture
		marker.position = position_value
		marker.offset = Vector2(0,-source_texture.get_height()*.34)
		var target_height: float = random.randf_range(37.0,73.0) if wilderness else random.randf_range(34.0,63.0)
		marker.scale = Vector2.ONE * target_height / maxf(1.0,source_texture.get_height())
		marker.rotation = random.randf_range(-.20,.20)
		marker.flip_h = random.randf() > .5
		if frozen:
			marker.modulate = Color(random.randf_range(.73,.92),random.randf_range(.80,.99),1.0,.66)
		elif volcanic:
			marker.modulate = Color(random.randf_range(.55,.78),random.randf_range(.43,.60),random.randf_range(.34,.49),.73)
		elif wilderness:
			marker.modulate = Color(random.randf_range(.60,.91),random.randf_range(.72,.99),random.randf_range(.47,.67),.78)
		else:
			var shade: float = random.randf_range(.54,.79)
			marker.modulate = Color(shade,shade*.98,shade*1.03,.75)
		# One dedicated draw layer stays under actors/props and counts as one
		# streamed decoration group, not dozens of gameplay props.
		cover_layer.add_child(marker)

# Purely visual ground cover: reuse the existing licensed-in-project prop atlas
# and exact world positions without ever modifying tiles, paths or collision.
# Deterministic local seeds prevent foliage popping into new random positions
# whenever a chunk streams out and back in.
func _scatter_ambient_details(parent: Node2D, record: Dictionary, kind: String) -> void:
	if kind not in ["oak","oak2","pine","birch","rocks","rock","bush","grass","rubble","ruin_wall","arch","pillar"]:
		return
	var anchor: Vector2 = COORD.array_vector(record["position"])
	var seed_value: int = int(absf(anchor.x * 19.0 + anchor.y * 31.0)) + kind.hash()
	var random := RandomNumberGenerator.new()
	random.seed = absi(seed_value) + 3
	var wilderness: bool = bool(field.data.get("render_style", {}).get("wild_ground", true))
	for index: int in range(2):
		if random.randf() < 0.30: continue
		var offset := Vector2(random.randf_range(-98.0,98.0),random.randf_range(-50.0,65.0))
		var position_value: Vector2 = anchor + offset
		if not field.bounds.has_point(position_value) or not field.point_clear(position_value, 5.0):
			continue
		var decoration_kind: String = "grass" if wilderness and random.randf() > 0.35 else ("rock" if wilderness else "rocks")
		var texture: Texture2D = textures.get(decoration_kind) as Texture2D
		if texture == null: continue
		var little := Sprite2D.new()
		little.name = "FoliageDetail"
		little.texture = texture
		little.position = position_value
		little.offset = Vector2(0.0, -texture.get_height() * .35)
		var detail_height: float = random.randf_range(18.0,35.0) if wilderness else random.randf_range(13.0,28.0)
		little.scale = Vector2.ONE * detail_height / maxf(1.0, texture.get_height())
		little.rotation = random.randf_range(-.10,.10)
		little.flip_h = random.randf() > .5
		little.modulate = Color(random.randf_range(.68,.90),random.randf_range(.71,.96),random.randf_range(.58,.80),.90) if wilderness else Color(.72,.72,.69,.74)
		little.z_index = -9
		parent.add_child(little)

func _select_layer(layer_name: String) -> void:
	ground = Node2D.new()
	ground.name = layer_name
	terrain_root.add_child(ground)
