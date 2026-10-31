extends Control
class_name FieldMinimap

const COORD = preload("res://scripts/maps/world_coordinates.gd")
const REGION_GEOMETRY = preload("res://scripts/maps/map_region_geometry.gd")
const RASTER_CACHE = preload("res://scripts/maps/minimap_raster_cache.gd")
var source_overview: Texture2D
var boss_region_mesh: MultiMesh
var world: Node
var field: PlayableField
var bounds := Rect2(0,0,1,1)
var clock: float = 0.0
var area := Rect2(9,27,204,136)
# Map geometry is immutable while the minimap redraws at ~8 Hz.
var cached_structure_floor: Array[PackedVector2Array] = []
var cached_structure_zones: Array[Dictionary] = []
var cached_structure_pits: Array[PackedVector2Array] = []
var cached_hunting_polygons: Dictionary = {}
var cached_static_geometry_ready: bool = false
# Static terrain is drawn by this control only when the field or size changes.
# Moving markers live on a child overlay that alone redraws at ~8 Hz, so the
# hundreds of polygons/roads/portals are no longer re-submitted every tick.
var overlay: MinimapOverlay
var static_redraws: int = 0
var overlay_redraws: int = 0
# With a real renderer the static layer is rasterized once into a SubViewport
# texture, so each frame submits one textured quad instead of the ~2,000
# separate polygon/dot draw calls the retained canvas commands still cost.
# Headless runs (no renderer) and the brief build window draw directly.
var raster_cache = RASTER_CACHE.new()
var static_cache_enabled: bool = true
var static_only: bool = false
var static_generation: int = 0
var panel_style: StyleBoxFlat

class MinimapOverlay extends Control:
	var minimap: FieldMinimap
	func _draw() -> void:
		minimap._draw_dynamic(self)

func configure(controller: Node, value: PlayableField) -> void:
	world = controller
	field = value
	bounds = field.bounds if field != null else Rect2(Vector2.ZERO,world.world_size)
	source_overview = (field as OriginalPlayableField).overview_texture() if field is OriginalPlayableField else null
	if field is NativePngField: source_overview = field.overview_texture()
	_prepare_static_geometry()
	_cache_boss_markers()
	static_generation += 1
	raster_cache.invalidate()
	queue_redraw()
	if is_instance_valid(overlay): overlay.queue_redraw()
	call_deferred("_prepare_raster")

func set_static_cache_enabled(enabled: bool) -> void:
	static_cache_enabled = enabled
	if enabled: _prepare_raster()
	queue_redraw()

func _prepare_raster() -> void:
	if static_only or not static_cache_enabled or world == null or not is_inside_tree(): return
	raster_cache.prepare(self)

## Painter side: reuse the owner's prepared geometry for one raster build.
func adopt_static(owner: FieldMinimap) -> void:
	cached_structure_floor = owner.cached_structure_floor
	cached_structure_zones = owner.cached_structure_zones
	cached_structure_pits = owner.cached_structure_pits
	cached_hunting_polygons = owner.cached_hunting_polygons
	cached_static_geometry_ready = owner.cached_static_geometry_ready
	boss_region_mesh = owner.boss_region_mesh

func release_static() -> void:
	cached_structure_floor = []
	cached_structure_zones = []
	cached_structure_pits = []
	cached_hunting_polygons = {}
	boss_region_mesh = null

func _ready() -> void:
	if static_only:
		set_process(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	overlay = MinimapOverlay.new()
	overlay.name = "MinimapOverlay"
	overlay.minimap = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tooltip_text = "클릭: 이동 경로 · 청록: 이동석 · 금색: 마을 · 빨강: 보스"
	resized.connect(_prepare_raster)
	get_viewport().size_changed.connect(_prepare_raster)

func _process(delta: float) -> void:
	clock -= delta
	if clock <= 0.0:
		clock = .12
		if is_instance_valid(overlay): overlay.queue_redraw()
		else: queue_redraw()

func _point(p: Vector2) -> Vector2:
	return COORD.world_to_minimap(p,bounds,area)

func _draw() -> void:
	if world == null:
		return
	if static_only:
		_draw_static_layer()
		return
	draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
	if static_cache_enabled and raster_cache.ready and raster_cache.texture() != null:
		draw_texture_rect(raster_cache.texture(),Rect2(raster_cache.logical_origin,raster_cache.logical_extent),false)
	else:
		static_redraws += 1
		_draw_static_layer()
		# Never add the SubViewport while drawing; build after this frame.
		if static_cache_enabled and DisplayServer.get_name() != "headless": call_deferred("_prepare_raster")
	var font: Font = get_theme_default_font()
	var heading: String = str(field.data.get("minimap",{}).get("title","ADEN  /  WORLD")) if field != null else "REGION  /  MAP"
	if field is OriginalPlayableField: heading = str(field.data.map_name)
	draw_string(font,Vector2(10,18),heading.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,204,12,Color("decfae"))
	if not is_instance_valid(overlay): _draw_dynamic(self)

## Terrain, roads, markers and boss areas: everything that only changes with
## the field, its bounds or the control size. The heading stays direct text.
func _draw_static_layer() -> void:
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

## Moving markers and the region title, drawn on `canvas` (the overlay).
func _draw_dynamic(canvas: CanvasItem) -> void:
	if world == null:
		return
	overlay_redraws += 1
	var font: Font = get_theme_default_font()
	for child: Node in world.monsters_root.get_children():
		var monster: TwilightMonster = child as TwilightMonster
		if monster != null and monster.global_position.distance_squared_to(world.player.global_position) < 1600000:
			canvas.draw_circle(_point(monster.global_position),1.3,Color("d68b73"))
	var camera: Camera2D = world.player.camera
	var extent: Vector2 = get_viewport_rect().size / camera.zoom
	var top: Vector2 = _point(camera.get_screen_center_position()-extent*.5)
	var bottom: Vector2 = _point(camera.get_screen_center_position()+extent*.5)
	canvas.draw_rect(Rect2(top,bottom-top).intersection(area),Color(1,1,1,.18),false,1)
	var p: Vector2 = _point(world.player.global_position)
	var direction: Vector2 = [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT][world.player.facing]
	var side := Vector2(-direction.y,direction.x)
	canvas.draw_circle(p,5,Color("101a18"))
	canvas.draw_colored_polygon(PackedVector2Array([p+direction*6,p-direction*3+side*3,p-direction*3-side*3]),Color("faf0bb"))
	var title: String = "지역 지도"
	if field != null:
		var region: Dictionary = field.region_at(world.player.global_position)
		title = str(region["name"]) + (" · 안전" if str(region["type"])=="safe" else " · 사냥터")
		if field is OriginalPlayableField: title = str(field.data.short_name)
	canvas.draw_string(font,Vector2(9,181),title,HORIZONTAL_ALIGNMENT_LEFT,204,12,Color("d7ceba"))

func _map_polygon(record: Dictionary, key: String = "polygon") -> PackedVector2Array:
	var points := PackedVector2Array()
	for p: Vector2 in REGION_GEOMETRY.polygon(record,key): points.append(_point(p))
	return points

func _prepare_static_geometry() -> void:
	cached_structure_floor.clear()
	cached_structure_zones.clear()
	cached_structure_pits.clear()
	cached_hunting_polygons.clear()
	cached_static_geometry_ready = false
	if field == null: return
	if field.data.has("world_geometry"):
		var structure: Dictionary = field.data.world_geometry
		for raw: Array in field.data.navigable_polygons:
			cached_structure_floor.append(_map_polygon({"polygon":raw}))
		for zone: Dictionary in structure.terrain_zones:
			var zone_shape: PackedVector2Array = REGION_GEOMETRY.polygon(zone)
			for raw: Array in field.data.navigable_polygons:
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(zone_shape,REGION_GEOMETRY.polygon({"polygon":raw})):
					var mapped := PackedVector2Array()
					for p: Vector2 in clipped: mapped.append(_point(p))
					cached_structure_zones.append({"points":mapped, "color":Color(str(zone.tint))})
		for shape: Dictionary in field.data.collision:
			if str(shape.kind) == "dungeon_pit":
				cached_structure_pits.append(_map_polygon(shape,"points"))
	if field.data.has("hunting_paths"):
		for region: Dictionary in field.data.regions:
			if str(region.get("type","")) == "safe" or region.has("polygon"): continue
			var outlines: Array[PackedVector2Array] = []
			for spawn: Dictionary in field.data.get("monster_spawn",[]):
				if str(spawn.id) != str(region.id): continue
				var geometry: PackedVector2Array
				if spawn.has("polygon"):
					geometry = REGION_GEOMETRY.polygon(spawn)
				else:
					var a: Array = spawn.rect
					geometry = PackedVector2Array([Vector2(a[0],a[1]), Vector2(a[0]+a[2],a[1]), Vector2(a[0]+a[2],a[1]+a[3]), Vector2(a[0],a[1]+a[3])])
				for floor: PackedVector2Array in field.navigable_polygons:
					for clipped: PackedVector2Array in Geometry2D.intersect_polygons(geometry,floor):
						var outline := PackedVector2Array()
						for p: Vector2 in clipped: outline.append(_point(p))
						outlines.append(outline)
			cached_hunting_polygons[str(region.id)] = outlines
	cached_static_geometry_ready = true

func _draw_structure_geography() -> void:
	if not field.data.has("world_geometry"): return
	var structure: Dictionary = field.data.world_geometry
	draw_rect(area,Color(str(structure.void_color)))
	for outline: PackedVector2Array in cached_structure_floor:
		draw_colored_polygon(outline,Color("64715d") if str(field.data.map_id)=="aden_world" else Color("777578"))
	for entry: Dictionary in cached_structure_zones:
		draw_colored_polygon(entry.points,entry.color)
	for outline: PackedVector2Array in cached_structure_pits:
		draw_colored_polygon(outline,Color("090b10"))

func _cache_boss_markers() -> void:
	boss_region_mesh=null
	if not field is NativePngField or str(field.data.map_id)!="escaros_world":return
	# The same sampled floor dots previously submitted ~2,000 separate draws
	# every displayed frame. Geometry is static for the lifetime of this field.
	var positions:=PackedVector2Array()
	for spawn: Dictionary in field.data.get("monster_spawn",[]):
		if str(spawn.get("mode",""))!="boss" or (not spawn.has("polygon") and not spawn.has("polygons")):continue
		var cells: Array=field.spawn_cells.get(str(spawn.id),[])
		var stride: int=maxi(1,ceili(float(cells.size())/480.0))
		for i: int in range(0,cells.size(),stride):positions.append(_point(field.cell_to_world(cells[i])))
	if positions.is_empty():return
	var vertices:=PackedVector3Array()
	for i: int in range(16):
		var a:=Vector2.from_angle(TAU*i/16.0)*1.1
		var b:=Vector2.from_angle(TAU*(i+1)/16.0)*1.1
		vertices.append(Vector3.ZERO);vertices.append(Vector3(a.x,a.y,0));vertices.append(Vector3(b.x,b.y,0))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	boss_region_mesh=MultiMesh.new();boss_region_mesh.transform_format=MultiMesh.TRANSFORM_2D
	boss_region_mesh.use_colors=true;boss_region_mesh.mesh=mesh;boss_region_mesh.instance_count=positions.size()
	for i: int in range(positions.size()):
		boss_region_mesh.set_instance_transform_2d(i,Transform2D(0,positions[i]))
		boss_region_mesh.set_instance_color(i,Color(.9,.35,.25,.45))

func _draw_boss_regions() -> void:
	if boss_region_mesh!=null:draw_multimesh(boss_region_mesh,null)
	for spawn: Dictionary in field.data.get("monster_spawn",[]):
		if str(spawn.get("mode",""))!="boss": continue
		var raw_polygons: Array=[]
		if spawn.has("polygon"): raw_polygons=[spawn.polygon]
		elif spawn.has("polygons"): raw_polygons=spawn.polygons
		if raw_polygons.is_empty(): continue
		var cells: Array = field.spawn_cells.get(str(spawn.id),[])
		var stride: int = maxi(1,ceili(float(cells.size())/480.0))
		if boss_region_mesh==null:
			for i: int in range(0,cells.size(),stride):
				draw_circle(_point(field.cell_to_world(cells[i])),1.1,Color(.9,.35,.25,.45))
		for raw: Array in raw_polygons:
			if raw.size()<3: continue
			var points: PackedVector2Array=_map_polygon({"polygon":raw})
			points.append(points[0])
			draw_polyline(points,Color(.9,.35,.25,.7),1.0,true)

func _draw_hunting_region(region: Dictionary) -> void:
	if str(region.type)=="safe": return
	for outline: PackedVector2Array in cached_hunting_polygons.get(str(region.id),[]):
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
	if panel_style != null: return panel_style
	var style := StyleBoxFlat.new()
	panel_style = style
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
