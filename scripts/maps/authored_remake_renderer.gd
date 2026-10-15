extends "res://scripts/maps/field_renderer.gd"
## The native-map adapter shares the existing art, markers and prop streaming.
## Collision remains the authored polygons, independent of these visual meshes.
var floor_stream: Node2D
var wall_records: Dictionary = {}
var wall_bounds: Dictionary = {}
var wall_chunks: Dictionary = {}
var wall_freed: int = 0
var collision_overlay: Node2D

func configure(value: PlayableField, actor: Node2D) -> void:
	super.configure(value,actor)
	collision_overlay=preload("res://scripts/maps/authored_collision_overlay.gd").new()
	collision_overlay.field=field;collision_overlay.z_index=30
	collision_overlay.hide();add_child(collision_overlay)

func set_visual_mode(requested: String) -> void:
	super.set_visual_mode(requested)
	if collision_overlay!=null: collision_overlay.visible=requested=="collision"

func _ground_material(index: int, alpha: float = 1.0, edge: bool = false) -> ShaderMaterial:
	var result: ShaderMaterial=super._ground_material(index,alpha,edge)
	var profile: Dictionary=(field as AuthoredRemakeField).remake_profile
	var slots: Array=profile.get("materials",[0,1,2,3])
	result.set_shader_parameter("material_slots",Vector4(slots[0],slots[1],slots[2],slots[3]))
	result.set_shader_parameter("remake_surface",int(profile.get("surface_pattern",0)))
	return result

func _build_reference_ground() -> void:
	var outside:=Polygon2D.new();outside.name="OutsideWorld"
	outside.polygon=_box_points(field.bounds)
	outside.color=Color(str(field.data.world_geometry.void_color));ground.add_child(outside)
	floor_stream=preload("res://scripts/maps/authored_surface_stream.gd").new()
	floor_stream.name="AuthoredFloorStream"
	floor_stream.configure(field,Callable(self,"_ground_material"));ground.add_child(floor_stream)

func _build_wall(shape: Dictionary) -> void:
	var kind: String=str(shape.kind)
	if kind=="dungeon_pit": super._build_wall(shape);return
	if kind not in ["dungeon_boundary","terrain_boundary","dungeon_wall","fortress_wall"]: return
	var points: PackedVector2Array
	if shape.has("rect"):
		var a: Array=shape.rect;points=_box_points(Rect2(a[0],a[1],a[2],a[3]))
	else: points=REGION_GEOMETRY.polygon(shape,"points")
	if points.size()<3: return
	var height: float=float(field.data.world_geometry.get("boundary_height",88))
	var tint:=Color(str(field.data.get("render_style",{}).get("wall_tint","555862")))
	var top:=PackedVector2Array();var foot: float=points[0].y
	for p: Vector2 in points: top.append(p-Vector2(0,height));foot=maxf(foot,p.y)
	_wall_polygon(top,foot,tint.lightened(.22))
	for i: int in range(points.size()):
		var a: Vector2=points[i];var b: Vector2=points[(i+1)%points.size()]
		var count: int=maxi(1,ceili(a.distance_to(b)/128.0))
		for j: int in range(count):
			var p: Vector2=a.lerp(b,float(j)/count);var q: Vector2=a.lerp(b,float(j+1)/count)
			_wall_polygon(PackedVector2Array([p,q,q-Vector2(0,height),p-Vector2(0,height)]),maxf(p.y,q.y),tint.darkened(.25 if q.x>p.x else .05))

func _wall_polygon(points: PackedVector2Array, foot: float, tint: Color) -> void:
	var box:=Rect2(points[0],Vector2.ZERO)
	for p: Vector2 in points: box=box.expand(p)
	var key:=Vector2i((box.get_center()/1024.0).floor())
	if not wall_records.has(key): wall_records[key]=[];wall_bounds[key]=box
	wall_bounds[key]=(wall_bounds[key] as Rect2).merge(box)
	wall_records[key].append({"points":points,"foot":foot,"tint":tint})

func refresh_visible() -> void:
	super.refresh_visible()
	var viewport: Viewport=get_viewport()
	var a: Vector2=COORD.screen_to_world(viewport,Vector2.ZERO)
	var b: Vector2=COORD.screen_to_world(viewport,viewport.get_visible_rect().size)
	var view:=Rect2(a,b-a)
	if not view.has_point(player.global_position): view.position=player.global_position-view.size*.5
	view=view.grow(float(field.data.streaming.margin))
	if floor_stream!=null: floor_stream.refresh(view)
	var wanted: Dictionary={}
	for key: Vector2i in wall_records:
		if not (wall_bounds[key] as Rect2).intersects(view): continue
		wanted[key]=true
		if wall_chunks.has(key): continue
		var node:=Node2D.new();node.y_sort_enabled=true
		node.name="Wall_%d_%d" % [key.x,key.y]
		var rows: Dictionary={}
		for record: Dictionary in wall_records[key]:
			var y: float=record.foot
			if not rows.has(y): rows[y]={"vertices":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}
			var group: Dictionary=rows[y];var offset: int=group.vertices.size()
			for p: Vector2 in record.points: group.vertices.append(p-Vector2(0,y));group.colors.append(record.tint)
			for i: int in Geometry2D.triangulate_polygon(record.points): group.indices.append(i+offset)
		for y: float in rows:
			var group: Dictionary=rows[y]
			if group.indices.is_empty(): continue
			var mesh:=MeshInstance2D.new();mesh.position.y=y
			mesh.mesh=ROAD_SURFACE_MESH._mesh(group.vertices,group.colors,group.indices)
			mesh.material=_ground_material(2);node.add_child(mesh)
		add_child(node);wall_chunks[key]=node
	for key: Vector2i in wall_chunks.keys():
		if wanted.has(key): continue
		var node: Node=wall_chunks[key];remove_child(node);node.queue_free()
		wall_chunks.erase(key);wall_freed+=1
	if field is AuthoredRemakeField and field.collision_stream!=null: field.collision_stream.refresh()
