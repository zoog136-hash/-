extends Control
class_name FieldMinimap

const COORD = preload("res://scripts/maps/world_coordinates.gd")
const REGION_GEOMETRY = preload("res://scripts/maps/map_region_geometry.gd")
const RASTER_CACHE = preload("res://scripts/maps/minimap_raster_cache.gd")
const GEOGRAPHY_CACHE = preload("res://scripts/maps/minimap_geography_cache.gd")
var geography_cache = GEOGRAPHY_CACHE.new()
var raster_cache = RASTER_CACHE.new()
var static_cache_enabled: bool = true
var static_only: bool = false
var source_overview: Texture2D
var world: Node
var field: PlayableField
var bounds := Rect2(0,0,1,1)
var clock: float = 0.0
var area := Rect2(9,27,204,136)

func configure(controller: Node, value: PlayableField) -> void:
	world = controller
	field = value
	geography_cache.configure(value)
	bounds = field.bounds if field != null else Rect2(Vector2.ZERO,world.world_size)
	source_overview = (field as OriginalPlayableField).overview_texture() if field is OriginalPlayableField else null
	if field is NativePngField: source_overview = field.overview_texture()
	if not static_only: raster_cache.invalidate()
	queue_redraw()

func _ready() -> void:
	if static_only:
		clip_contents = true
		set_process(false)
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = "클릭: 이동 경로 · 청록: 이동석 · 금색: 마을 · 빨강: 보스"

func set_static_cache_enabled(enabled: bool) -> void:
	static_cache_enabled = enabled
	queue_redraw()

func _process(delta: float) -> void:
	if not static_only and is_visible_in_tree(): raster_cache.prepare(self)
	clock -= delta
	if clock <= 0.0:
		clock = .12
		queue_redraw()

func _point(p: Vector2) -> Vector2:
	return COORD.world_to_minimap(p,bounds,area)

func _draw() -> void:
	if world == null: return
	if static_only:
		_draw_static()
		return
	_draw_frame()
	if static_cache_enabled and raster_cache.ready:
		draw_texture_rect(raster_cache.texture(), Rect2(raster_cache.logical_origin, raster_cache.logical_extent), false)
	else:
		_draw_static()
	_draw_dynamic()

func _draw_frame() -> void:
	# Keep text and translucent chrome in the main canvas at native DPI.
	draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
	var font: Font = get_theme_default_font()
	var heading: String = str(field.data.get("minimap",{}).get("title","ADEN  /  WORLD")) if field != null else "REGION  /  MAP"
	if field is OriginalPlayableField: heading = str(field.data.map_name)
	draw_string(font,Vector2(10,18),heading.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,204,12,Color("decfae"))

func _draw_static() -> void:
	draw_rect(area,Color("202e27"))
	if source_overview != null: draw_texture_rect(source_overview,area,false)
	if field != null:
		_draw_structure_geography()
		for surface: Dictionary in field.data.get("surfaces",[]):
			if field.data.has("hunting_paths") and field.data.has("world_geometry") and not surface.has("polygon"): continue
			if surface.has("polygon"):
				draw_colored_polygon(_map_polygon(surface),Color("56565b"))
				continue
			var a: Array = surface["rect"]
			var top: Vector2 = _point(Vector2(float(a[0]),float(a[1])))
			var end: Vector2 = _point(Vector2(float(a[0])+float(a[2]),float(a[1])+float(a[3])))
			draw_rect(Rect2(top,end-top),Color("56565b"))
		for region: Dictionary in field.data["regions"]:
			if region.has("polygon"):
				var polygon: PackedVector2Array = _map_polygon(region)
				draw_colored_polygon(polygon,Color(str(region.color),.2))
				continue
			var p: Vector2 = _point(COORD.array_vector(region["center"]))
			if field.data.has("hunting_paths"):
				_draw_hunting_region(region)
				continue
			var r: float = float(region["radius"])/bounds.size.x*area.size.x
			var color := Color(str(region["color"]),.3)
			draw_circle(p,r,color)
			draw_arc(p,r,0,TAU,24,Color(color,.5),1,true)
		for water: Dictionary in field.data["water"]:
			var points := PackedVector2Array()
			for p: Array in water["polygon"]:
				points.append(_point(COORD.array_vector(p)))
			draw_colored_polygon(points,Color(str(water.get("shallow_color","4c7e84"))))
		for road: Dictionary in field.data["roads"]:
			var points := PackedVector2Array()
			for p: Array in road["points"]:
				points.append(_point(COORD.array_vector(p)))
			draw_polyline(points,Color("b7a378"),1.7,true)
		for npc: Dictionary in field.data["npc_spawn"]:
			draw_circle(_point(COORD.array_vector(npc["position"])),2.0,Color("e6c16f"))
		for portal: Dictionary in field.data["portal"]:
			draw_circle(_point(COORD.array_vector(portal["position"])),3.0,Color("7fddd1"))
		for region: Dictionary in field.data["regions"]:
			if str(region["type"]) in ["safe","boss"]:
				draw_circle(_point(COORD.array_vector(region["center"])),3.0,Color("e6c16f") if str(region["type"])=="safe" else Color("dd7762"))
		_draw_boss_regions()
		_draw_hunting_obstacles()

func _draw_dynamic() -> void:
	var font: Font = get_theme_default_font()
	for monster: TwilightMonster in world.monsters_root.get_children():
		if monster.global_position.distance_squared_to(world.player.global_position) < 1600000:
			draw_circle(_point(monster.global_position),1.3,Color("d68b73"))
	var camera: Camera2D = world.player.camera
	var extent: Vector2 = get_viewport_rect().size / camera.zoom
	var top: Vector2 = _point(camera.get_screen_center_position()-extent*.5)
	var bottom: Vector2 = _point(camera.get_screen_center_position()+extent*.5)
	draw_rect(Rect2(top,bottom-top).intersection(area),Color(1,1,1,.18),false,1)
	var p: Vector2 = _point(world.player.global_position)
	var direction: Vector2 = [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT][world.player.facing]
	var side := Vector2(-direction.y,direction.x)
	draw_circle(p,5,Color("101a18"))
	draw_colored_polygon(PackedVector2Array([p+direction*6,p-direction*3+side*3,p-direction*3-side*3]),Color("faf0bb"))
	var title: String = "지역 지도"
	if field != null:
		var region: Dictionary = field.region_at(world.player.global_position)
		title = str(region["name"]) + (" · 안전" if str(region["type"])=="safe" else " · 사냥터")
		if field is OriginalPlayableField: title = str(field.data.short_name)
	draw_string(font,Vector2(9,181),title,HORIZONTAL_ALIGNMENT_LEFT,204,12,Color("d7ceba"))

func _map_polygon(record: Dictionary, key: String = "polygon") -> PackedVector2Array:
	var points := PackedVector2Array()
	for p: Vector2 in REGION_GEOMETRY.polygon(record,key): points.append(_point(p))
	return points

func _draw_structure_geography() -> void:
	if not field.data.has("world_geometry"): return
	var structure: Dictionary = field.data.world_geometry
	draw_rect(area,Color(str(structure.void_color)))
	for raw: Array in field.data.navigable_polygons:
		draw_colored_polygon(_map_polygon({"polygon":raw}),Color("64715d") if str(field.data.map_id)=="aden_world" else Color("777578"))
	for region: Dictionary in geography_cache.terrain:
		var points := PackedVector2Array()
		for p: Vector2 in region.polygon: points.append(_point(p))
		draw_colored_polygon(points,region.color)
	for shape: Dictionary in field.data.collision:
		if str(shape.kind)=="dungeon_pit": draw_colored_polygon(_map_polygon(shape,"points"),Color("090b10"))

func _draw_boss_regions() -> void:
	for spawn: Dictionary in field.data.get("monster_spawn",[]):
		if str(spawn.get("mode",""))!="boss": continue
		var raw_polygons: Array=[]
		if spawn.has("polygon"): raw_polygons=[spawn.polygon]
		elif spawn.has("polygons"): raw_polygons=spawn.polygons
		if raw_polygons.is_empty(): continue
		var cells: Array = field.spawn_cells.get(str(spawn.id),[])
		var stride: int = maxi(1,ceili(float(cells.size())/480.0))
		for i: int in range(0,cells.size(),stride):
			draw_circle(_point(field.cell_to_world(cells[i])),1.1,Color(.9,.35,.25,.45))
		for raw: Array in raw_polygons:
			if raw.size()<3: continue
			var points: PackedVector2Array=_map_polygon({"polygon":raw})
			points.append(points[0])
			draw_polyline(points,Color(.9,.35,.25,.7),1.0,true)

func _draw_hunting_region(region: Dictionary) -> void:
	if str(region.type)=="safe": return
	for polygon: PackedVector2Array in geography_cache.hunting.get(str(region.id),[]):
		var outline := PackedVector2Array()
		for p: Vector2 in polygon: outline.append(_point(p))
		draw_colored_polygon(outline,Color(str(region.color),.16))

func _draw_hunting_obstacles() -> void:
	if not field.data.has("hunting_paths"): return
	# Draw the same physical objects and boundary shapes used by walking.
	for obstacle: Dictionary in field.data.collision:
		if str(obstacle.get("placement_group",""))!="hunting_paths_v1": continue
		if obstacle.shape=="polygon":
			draw_colored_polygon(_map_polygon(obstacle,"points"),Color("30323b"))
		elif obstacle.shape=="circle" and obstacle.has("hunting_lane"):
			var radius: float=maxf(.55,float(obstacle.radius)/bounds.size.x*area.size.x)
			draw_circle(_point(COORD.array_vector(obstacle.center)),radius,Color("30323b"))

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.035,.045,.036,.93)
	style.border_color = Color("726448")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if pressed and area.has_point(event.position):
		world._set_click_destination(COORD.minimap_to_world(event.position,bounds,area))
		accept_event()
