extends "res://scripts/maps/source_renderer.gd"
class_name RemakeSourceRenderer
## PR108 ground/edge streaming generalized to data-driven source coordinates.
## Existing TWILIGHT art, no random pillars or inferred iron fences.
const CHUNK_SIZE: int = 32
const MAX_CHUNKS: int = 49
const GIRAN_REVIEW = preload("res://scripts/maps/aden_giran_review/chunk.gd")
const ADEN_WORLD_VISUALS = preload("res://scripts/maps/aden_world_visuals/chunk.gd")
const PNG_PACK = preload("res://scripts/maps/aden_png_pack.gd")
const PNG_CHUNK = preload("res://scripts/maps/aden_png_chunk.gd")
var png_pack: RefCounted
var png_textures: Dictionary = {}
var debug_collision: bool = false
var render_profile: Dictionary = {}
var floor_material: ShaderMaterial
var stream_build_usec: int = 0
var built_chunks: int = 0
var freed_chunks: int = 0
var rendered_door_states: Dictionary = {}

func configure(value: PlayableField, actor: Node2D) -> void:
	field = value
	source = value as OriginalPlayableField
	player = actor
	y_sort_enabled = true
	if str(source.data.map_id) == "aden_world":
		png_pack = PNG_PACK.new()
		var pack_path: String = OS.get_environment("TWILIGHT_ADEN_PNG_PACK")
		if pack_path.is_empty(): pack_path = "user://aden_png"
		png_pack.configure(pack_path,source)
		png_textures = png_pack.textures
	var backdrop := Polygon2D.new()
	backdrop.name = "MapVoid"
	backdrop.z_index = -30
	var bounds: Rect2 = source.bounds
	backdrop.polygon = PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	backdrop.color = Color("090d10")
	add_child(backdrop)
	render_profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/remake_render_profiles.json")).maps.get(str(source.data.map_id),{})
	reference_profile = render_profile
	terrain = load("res://assets/maps/reference_expansion_v2/terrain.png")
	floor_material = ShaderMaterial.new()
	floor_material.shader = load("res://assets/maps/authored_mainland_v1/terrain.gdshader")
	floor_material.set_shader_parameter("atlas",terrain)
	floor_material.set_shader_parameter("atlas_grid",4.0)
	var slots: Array = render_profile.get("materials",[4,5,4,7])
	floor_material.set_shader_parameter("material_slots",Vector4(slots[0],slots[1],slots[2],slots[3]))
	if str(render_profile.get("floor_style","")) == "pr108_cracked_flagstones":
		# Reuse the exact PR108 authored atlas; no new image generation or source
		# object classification is implied by this floor-material selection.
		floor_material.shader = load("res://assets/maps/remake/pr108_flagstones.gdshader")
		floor_material.set_shader_parameter("floor_atlas",load(str(render_profile.floor_atlas)))
	ground_materials["source_floor"] = floor_material
	refresh_visible()

func refresh_visible() -> void:
	if source == null or not is_instance_valid(player): return
	# A door changes both its visible boundary and the physical segment stream.
	# Source bytes stay immutable; only these derived visible batches are rebuilt.
	if rendered_door_states != source.source_doors.opened:
		rendered_door_states=source.source_doors.opened.duplicate()
		for chunk: Node in chunks.values(): remove_child(chunk);chunk.queue_free();freed_chunks+=1
		chunks.clear()
	var rect: Rect2 = get_viewport_rect()
	var transform: Transform2D = get_canvas_transform().affine_inverse()
	var needed: Dictionary = {}
	var lower := Vector2i(2147480000,2147480000)
	var upper := Vector2i(-2147480000,-2147480000)
	for corner: Vector2 in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var c: Vector2i = source.world_to_cell(transform*corner)
		lower = lower.min(c)
		upper = upper.max(c)
	# Include vertical structures just outside the camera. Bound distant zooms.
	lower = Vector2i(maxi(0,floori(float(lower.x)/CHUNK_SIZE)-1),maxi(0,floori(float(lower.y)/CHUNK_SIZE)-1))
	upper = Vector2i(mini((source.width-1)/CHUNK_SIZE,floori(float(upper.x)/CHUNK_SIZE)+1),mini((source.height-1)/CHUNK_SIZE,floori(float(upper.y)/CHUNK_SIZE)+1))
	var keys: Array[Vector2i] = []
	var focus: Vector2i = source.world_to_cell(player.global_position)
	for y: int in range(lower.y,upper.y+1):
		for x: int in range(lower.x,upper.x+1): keys.append(Vector2i(x,y))
	keys.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return (a*CHUNK_SIZE-focus).length_squared()<(b*CHUNK_SIZE-focus).length_squared())
	var start: int = Time.get_ticks_usec()
	for key: Vector2i in keys.slice(0,MAX_CHUNKS):
		needed[key] = true
		if chunks.has(key): continue
		# Source Aden has a separate visual layer. Other maps keep their renderer;
		# all maps retain the verified collision/navigation stream.
		var chunk: Node2D
		var png_region: Dictionary = png_pack.region_for(key) if png_pack != null and not debug_collision else {}
		if not png_region.is_empty(): chunk = PNG_CHUNK.new()
		elif ADEN_WORLD_VISUALS.applies(source,key): chunk = ADEN_WORLD_VISUALS.new()
		elif GIRAN_REVIEW.applies(source,key): chunk = GIRAN_REVIEW.new()
		else: chunk = RemakeChunk.new()
		chunk.name = "SourceChunk_%d_%d" % [key.x,key.y]
		chunk.y_sort_enabled = true
		add_child(chunk)
		if not png_region.is_empty():
			chunk.texture_cache = png_textures
			chunk.build_png(source,key,png_pack,png_region)
		else: chunk.build(source,key,floor_material,render_profile,debug_collision)
		chunks[key] = chunk
		built_chunks += 1
	for key: Vector2i in chunks.keys():
		if needed.has(key): continue
		remove_child(chunks[key]); chunks[key].queue_free(); chunks.erase(key)
		freed_chunks += 1
	stream_build_usec = maxi(stream_build_usec,Time.get_ticks_usec()-start)
	_refresh_markers()
	if source is RemakePlayableField and is_instance_valid(source.collision_stream): source.collision_stream.refresh()

func set_visual_mode(mode: String) -> void:
	var collision: bool = mode == "collision"
	if collision == debug_collision: return
	debug_collision = collision
	for chunk: Node in chunks.values(): remove_child(chunk); chunk.queue_free()
	chunks.clear()
	refresh_visible()

class RemakeChunk extends Node2D:
	func build(map: OriginalPlayableField,key: Vector2i,mat: ShaderMaterial,profile: Dictionary,debug: bool) -> void:
		var vertices := PackedVector2Array()
		var uv := PackedVector2Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		var rows: Dictionary = {}
		var pr108_floor: bool = str(profile.get("floor_style","")) == "pr108_cracked_flagstones"
		var atlas_grid := Vector2(8,4)
		var diamond_uv := PackedVector2Array([Vector2(0,0.5),Vector2(0.5,0),Vector2(1,0.5),Vector2(0.5,1)])
		for y: int in range(key.y*32,mini((key.y+1)*32,map.height)):
			for x: int in range(key.x*32,mini((key.x+1)*32,map.width)):
				var cell := Vector2i(x,y)
				var open: bool = map.value_at(cell,true)!=0
				var polygon: PackedVector2Array = map.coordinates.cell_polygon(cell)
				var at: int = vertices.size()
				var kind: float = 0.0 if open else 1.0
				var shade: float = float(profile.get("floor_light",0.80)) if open else 0.15
				var variant: int = (x*73856093 ^ y*19349663)&31
				if pr108_floor and open: shade += float(variant%7)*0.015
				for corner: int in range(polygon.size()):
					var point: Vector2 = polygon[corner]
					vertices.append(point)
					var grid: Vector2 = map.coordinates.world_to_grid(point)
					uv.append((Vector2(variant%8,variant/8)+diamond_uv[corner])/atlas_grid if pr108_floor else grid/6.0)
					# Continuous vertex light, including across chunk borders.
					var light: float = 0.5+0.22*sin(grid.x*0.043+grid.y*0.071)
					colors.append((Color("327d5e") if open else Color("302026")) if debug else Color(kind,light,shade,1))
				indices.append_array(PackedInt32Array([at,at+1,at+2,at,at+2,at+3]))
				if not open: continue
				for heading: int in [0,2,4,6]:
					if map.can_step(cell,heading): continue
					var next: Vector2i = cell+map.DIRECTIONS[heading]
					if map.value_at(next,true)!=0 and (next.y<y or (next.y==y and next.x<x)): continue
					var edge: PackedVector2Array = map.coordinates.edge_points(cell,heading)
					var foot: Vector2 = (edge[0]+edge[1])*0.5
					var row: int = roundi(foot.y)
					if not rows.has(row): rows[row] = []
					rows[row].append(edge)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var ground := MeshInstance2D.new()
		ground.name = "BatchedGround"
		ground.z_index = -20
		ground.mesh = mesh
		if not debug: ground.material = mat
		add_child(ground)
		for row: int in rows:
			var boundary := BoundaryRow.new()
			boundary.position.y = row
			boundary.debug = debug
			boundary.wall_height = float(profile.get("unclassified_boundary_height",12))
			boundary.segments = rows[row]
			add_child(boundary)

class BoundaryRow extends Node2D:
	## Equal-foot-height batches preserve Y sorting against existing actors.
	## Unknown source edges get restrained stone ledges, not invented rail IDs.
	var segments: Array = []
	var wall_height: float = 12
	var debug: bool = false
	func _draw() -> void:
		for edge: PackedVector2Array in segments:
			var a: Vector2 = edge[0]-position
			var b: Vector2 = edge[1]-position
			if debug: draw_line(a,b,Color("ed624e"),2.0,true); continue
			var up := Vector2(0,-wall_height)
			draw_colored_polygon(PackedVector2Array([a,b,b+Vector2(0,5),a+Vector2(0,5)]),Color("0b0e10"))
			draw_colored_polygon(PackedVector2Array([a,b,b+up,a+up]),Color("303332") if b.y<a.y else Color("252a29"))
			draw_line(a+up,b+up,Color("67675c"),2.0,true)
			draw_line(a+up+Vector2(0,2),b+up+Vector2(0,2),Color("454a43"),1.5,true)
			draw_line(a,b,Color("141b1a"),1.8,true)
			var middle: Vector2 = a.lerp(b,0.5)
			draw_line(middle,middle+up,Color("171c1c"),1.3,true)
