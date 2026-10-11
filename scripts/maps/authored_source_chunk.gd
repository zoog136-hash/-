extends Node2D
## User-authorized replacement art. Source geometry is authoritative; materials
## and small obstacles are authored interpretations, NOT recovered tile IDs.
var cell_count: int = 0
var prop_count: int = 0
var source_pair_cells: int = 0
const CORNERS = [Vector2(-24,0),Vector2(0,-12),Vector2(24,0),Vector2(0,12)]

func configure(source: OriginalPlayableField, key: Vector2i, terrain: Dictionary,
		material: ShaderMaterial, props: Array[AtlasTexture]) -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var floor_bytes := PackedByteArray()
	if not terrain.is_empty(): floor_bytes = Marshalls.base64_to_raw(str(terrain.floor_bytes))
	for y: int in range(key.y*64,mini((key.y+1)*64,source.height)):
		for x: int in range(key.x*64,mini((key.x+1)*64,source.width)):
			var cell := Vector2i(x,y)
			var raw: int = source.value_at(cell)
			var opened: bool = source.value_at(cell,true)!=0
			var safe: bool = (raw&48)==16
			# Navigation cannot distinguish water, roofs or walls. Never invent
			# those source meanings: all solid areas use a neutral rocky material.
			var kind: int = 3 if not opened else (1 if safe else (2 if (raw&48)==32 else 0))
			var seed_value: int = x*31+y*17
			var at_floor: int = ((y&63)*128+(x&63)*2)*4
			if at_floor+7<floor_bytes.size():
				# Retain S32 pair boundaries as subtle surface variation, never
				# claim an unknown source ID means a specific material.
				seed_value = int(floor_bytes[at_floor])+floor_bytes.decode_u16(at_floor+1)*7
				source_pair_cells+=1
			var p: Vector2 = source.cell_to_world(cell)
			var at: int = vertices.size()
			for corner: Vector2 in CORNERS:
				vertices.append(p+corner)
				uvs.append(source.coordinates.world_to_grid(p+corner)/10.0)
				colors.append(Color(float(kind)/3.0,float(posmod(seed_value,29))/28.0,0.72 if not opened else 1.0,1))
			indices.append_array(PackedInt32Array([at,at+1,at+2,at,at+2,at+3]))
			cell_count+=1
			if not opened and x%3==0 and y%3==0 and prop_count<96:
				var near_open: bool = false
				for direction: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					if source.value_at(cell+direction,true)!=0: near_open=true; break
				if near_open:
					var sprite := Sprite2D.new()
					var prop: int = (2+posmod(x+y,2)) if safe else posmod(x+y,2)
					sprite.texture=props[prop]
					sprite.scale=Vector2.ONE*(64.0/props[prop].get_width())
					sprite.position=p+Vector2(0,-18)
					sprite.z_index=1
					sprite.set_meta("source_blocked_cell",cell)
					add_child(sprite)
					prop_count+=1
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance2D.new()
	node.mesh=mesh
	node.material=material
	add_child(node)
