extends Node2D
## Clip the existing authored polygons into visible batched meshes. World-space
## vertices keep texture phase identical across chunk boundaries and revisits.
var surfaces: Array = []
var chunks: Dictionary = {}
var materials: Callable
var bounds: Rect2
var step: float = 1024.0
var freed_chunks: int = 0
var built_chunks: int = 0
var overview: bool = false

func configure(field: PlayableField, material_factory: Callable) -> void:
	materials=material_factory;bounds=field.bounds
	for points: PackedVector2Array in field.navigable_polygons:
		_append(points,int(field.data.world_geometry.floor_material),Color.WHITE)
		for zone: Dictionary in field.data.world_geometry.terrain_zones:
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(points,preload("res://scripts/maps/map_region_geometry.gd").polygon(zone)):
				_append(piece,int(zone.material),Color(str(zone.tint)).lightened(.28))

func _append(points: PackedVector2Array, index: int, tint: Color) -> void:
	if points.size()<3: return
	var box:=Rect2(points[0],Vector2.ZERO)
	for p: Vector2 in points: box=box.expand(p)
	surfaces.append({"points":points,"bounds":box,"material":index,"tint":tint})

func refresh(view: Rect2) -> void:
	var wanted_step: float=1024.0
	while ceilf(view.size.x/wanted_step+2)*ceilf(view.size.y/wanted_step+2)>49:
		wanted_step*=2
	if step!=wanted_step:
		for node: Node in chunks.values(): remove_child(node);node.queue_free()
		freed_chunks+=chunks.size();chunks.clear();step=wanted_step
	overview=step>1024
	var wanted: Dictionary={}
	var clipped: Rect2=view.intersection(bounds)
	if clipped.has_area():
		var lo:=Vector2i((clipped.position/step).floor())
		var hi:=Vector2i((clipped.end/step).floor())
		for y: int in range(lo.y,hi.y+1):
			for x: int in range(lo.x,hi.x+1):
				var key:=Vector2i(x,y);wanted[key]=true
				if not chunks.has(key): _load(key)
	for key: Vector2i in chunks.keys():
		if wanted.has(key): continue
		var node: Node=chunks[key];remove_child(node);node.queue_free()
		chunks.erase(key);freed_chunks+=1

func _load(key: Vector2i) -> void:
	var box:=Rect2(Vector2(key)*step,Vector2.ONE*step)
	var clip:=PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])
	var groups: Dictionary={}
	for surface: Dictionary in surfaces:
		if not (surface.bounds as Rect2).intersects(box): continue
		var index: int=surface.material
		if not groups.has(index): groups[index]={"vertices":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}
		var group: Dictionary=groups[index]
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(surface.points,clip):
			var triangles: PackedInt32Array=Geometry2D.triangulate_polygon(piece)
			var offset: int=group.vertices.size()
			group.vertices.append_array(piece)
			for p: Vector2 in piece: group.colors.append(surface.tint)
			for i: int in triangles: group.indices.append(i+offset)
	var node:=Node2D.new();node.name="Floor_%d_%d" % [key.x,key.y]
	for index: int in groups:
		var group: Dictionary=groups[index]
		if group.indices.is_empty(): continue
		var mesh:=MeshInstance2D.new()
		mesh.mesh=preload("res://scripts/maps/road_surface_mesh.gd")._mesh(group.vertices,group.colors,group.indices)
		mesh.material=materials.call(index);node.add_child(mesh)
	add_child(node);chunks[key]=node;built_chunks+=1

func chunk_signature(key: Vector2i) -> String:
	if not chunks.has(key): return ""
	var values: Array=[]
	for mesh: MeshInstance2D in chunks[key].get_children():
		values.append(mesh.mesh.surface_get_arrays(0))
	return var_to_bytes(values).hex_encode().sha256_text()
