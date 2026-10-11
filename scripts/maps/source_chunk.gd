extends Node2D
class_name OriginalSourceChunk
## Source-byte collision diagram. These diamonds are not reconstructed artwork.
var source: OriginalPlayableField
var terrain: Dictionary={}
var renderer: Node
var object_markers: int=0
var original_tiles: int=0
func configure(value: OriginalPlayableField, key: Vector2i,layers: Dictionary,controller: Node) -> void:
	source=value
	terrain=layers
	renderer=controller
	z_index=-20
	var vertices:=PackedVector2Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	for y: int in range(key.y*64,mini((key.y+1)*64,source.height)):
		for x: int in range(key.x*64,mini((key.x+1)*64,source.width)):
			var c:=Vector2i(x,y)
			var raw: int=source.value_at(c)
			var open: bool=source.value_at(c,true)!=0
			if raw==0 and not open: continue
			var color:=Color("3e5046") if open else Color("202827")
			if (raw&48)==16: color=Color("65705a")
			elif (raw&48)==32: color=Color("6b5247")
			var p: Vector2=source.cell_to_world(c)
			var at: int=vertices.size()
			vertices.append_array(PackedVector2Array([p+Vector2(-24,0),p+Vector2(0,-12),p+Vector2(24,0),p+Vector2(0,12)]))
			colors.append_array(PackedColorArray([color,color,color,color]))
			indices.append_array(PackedInt32Array([at,at+1,at+2,at,at+2,at+3]))
	if not vertices.is_empty():
		var arrays: Array=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_INDEX]=indices
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node:=MeshInstance2D.new()
		node.mesh=mesh
		add_child(node)
	_build_markers()
	queue_redraw()
func _build_markers() -> void:
	if terrain.is_empty(): return
	var points: Array[Vector2]=[]
	var origin:=Vector2i(int(terrain.origin[0]),int(terrain.origin[1]))
	for group: Dictionary in terrain.objects:
		for row: Array in group.tiles:
			points.append(source.coordinates.half_tile_position(origin,int(row[0]),int(row[1]))+Vector2(12,12))
	object_markers=points.size()
	if points.is_empty(): return
	var quad:=QuadMesh.new()
	quad.size=Vector2(2,2)
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_2D
	mm.use_colors=true
	mm.mesh=quad
	mm.instance_count=points.size()
	for i: int in range(points.size()):
		mm.set_instance_transform_2d(i,Transform2D(0,points[i]))
		mm.set_instance_color(i,Color(0.8,0.64,0.35,0.55))
	var node:=MultiMeshInstance2D.new()
	node.multimesh=mm
	add_child(node)
func _draw() -> void:
	original_tiles=0
	if terrain.is_empty(): return
	var origin:=Vector2i(int(terrain.origin[0]),int(terrain.origin[1]))
	var raw: PackedByteArray=Marshalls.base64_to_raw(str(terrain.floor_bytes))
	for y: int in range(64):
		for x: int in range(128):
			var at: int=(y*128+x)*4
			var texture: Texture2D=renderer.tile_texture(raw.decode_u16(at+1),int(raw[at]))
			if texture!=null:
				draw_texture(texture,source.coordinates.half_tile_position(origin,x,y))
				original_tiles+=1
	for row: Array in terrain.covers:
		var texture: Texture2D=renderer.tile_texture(int(row[3]),int(row[2]))
		if texture!=null: draw_texture(texture,source.coordinates.half_tile_position(origin,int(row[0]),int(row[1])))
