extends "res://scripts/maps/source_renderer.gd"
## Opt-in 2D source-topology sample. No original S32/tile artwork is invented.
const CHUNK_SIZE: int = 32
var sample_floor: Texture2D
var sample_center: Vector2i = Vector2i(-999,-999)
var sample_debug: bool = false

func configure(value: PlayableField, actor: Node2D) -> void:
	field = value
	source = value as OriginalPlayableField
	player = actor
	y_sort_enabled = true
	authored_art_enabled = false
	var atlas: Texture2D = load("res://assets/maps/aden/terrain.png")
	var crop := AtlasTexture.new()
	crop.atlas = atlas
	crop.region = Rect2(0,atlas.get_height()/2.0,atlas.get_width()/2.0,atlas.get_height()/2.0)
	sample_floor = crop
	refresh_visible()

func refresh_visible() -> void:
	if source == null or not is_instance_valid(player):
		return
	var cell: Vector2i = source.world_to_cell(player.global_position)
	var center := Vector2i(cell.x/CHUNK_SIZE,cell.y/CHUNK_SIZE)
	if center == sample_center:
		_refresh_markers()
		return
	sample_center = center
	var needed: Dictionary = {}
	for dy: int in range(-1,2):
		for dx: int in range(-1,2):
			var key: Vector2i = center+Vector2i(dx,dy)
			if key.x<0 or key.y<0 or key.x*CHUNK_SIZE>=source.width or key.y*CHUNK_SIZE>=source.height:
				continue
			needed[key] = true
			if chunks.has(key):
				continue
			var node := SampleChunk.new()
			node.name = "OmanSource_%d_%d" % [key.x,key.y]
			node.y_sort_enabled = true
			add_child(node)
			node.build(source,key,sample_floor,sample_debug)
			chunks[key] = node
	for key: Vector2i in chunks.keys():
		if needed.has(key):
			continue
		var old: Node = chunks[key]
		remove_child(old)
		old.queue_free()
		chunks.erase(key)
	_refresh_markers()

func set_visual_mode(mode: String) -> void:
	sample_debug = mode == "collision"
	for node: Node in chunks.values():
		node.queue_free()
	chunks.clear()
	sample_center = Vector2i(-999,-999)
	refresh_visible()

class SampleChunk extends Node2D:
	func build(map: OriginalPlayableField,key: Vector2i,texture: Texture2D,debug: bool) -> void:
		var ground := StoneGround.new()
		ground.z_index = -8
		ground.texture = texture
		ground.debug = debug
		add_child(ground)
		var corners: Array[Vector2] = [Vector2(-24,0),Vector2(0,-12),Vector2(24,0),Vector2(0,12)]
		for y: int in range(key.y*32,mini((key.y+1)*32,map.height)):
			for x: int in range(key.x*32,mini((key.x+1)*32,map.width)):
				var cell := Vector2i(x,y)
				if map.value_at(cell,true) == 0:
					continue
				var p: Vector2 = map.cell_to_world(cell)
				ground.cells.append(p)
				ground.variations.append(float((x*73856093 ^ y*19349663)&15)/15.0)
				for edge: int in range(4):
					var heading: int = edge*2
					if map.can_step(cell,heading):
						continue
					var next: Vector2i = cell+map.DIRECTIONS[heading]
					# A shared closed edge is authored once; exterior edges remain closed.
					if map.value_at(next,true)!=0 and (next.y<cell.y or (next.y==cell.y and next.x<cell.x)):
						continue
					var a: Vector2 = p+corners[edge]
					var b: Vector2 = p+corners[(edge+1)%4]
					var rail := IronBoundary.new()
					rail.position = (a+b)*0.5
					rail.a = a-rail.position
					rail.b = b-rail.position
					rail.pillar = (x+y+edge)%5==0
					rail.debug = debug
					rail.set_meta("source_closed_edge",[x,y,heading])
					add_child(rail)
		ground.queue_redraw()

class StoneGround extends Node2D:
	var texture: Texture2D
	var cells: Array[Vector2] = []
	var variations: Array[float] = []
	var debug: bool = false
	func _draw() -> void:
		var uv := PackedVector2Array([Vector2(0,0.5),Vector2(0.5,0),Vector2(1,0.5),Vector2(0.5,1)])
		for i: int in range(cells.size()):
			var p: Vector2 = cells[i]
			var corners := PackedVector2Array([p+Vector2(-24,0),p+Vector2(0,-12),p+Vector2(24,0),p+Vector2(0,12)])
			var shade: float = 0.47+variations[i]*0.11
			var tint := Color(shade,shade*0.96,shade*0.83)
			if debug:
				tint = Color(0.28,0.52,0.46)
			draw_polygon(corners,PackedColorArray([tint,tint,tint,tint]),uv,texture)
			if debug:
				draw_polyline(PackedVector2Array([corners[0],corners[1],corners[2],corners[3],corners[0]]),Color(0.1,0.24,0.22,0.5),0.6,true)

class IronBoundary extends Node2D:
	var a: Vector2
	var b: Vector2
	var pillar: bool = false
	var debug: bool = false
	func _draw() -> void:
		if debug:
			draw_line(a,b,Color(0.95,0.28,0.18),3.0,true)
			return
		var up := Vector2(0,-38)
		draw_line(a+Vector2(3,5),b+Vector2(3,5),Color(0,0,0,0.55),12.0,true)
		draw_line(a,b,Color(0.12,0.11,0.095),9.0,true)
		draw_line(a+Vector2(0,-5),b+Vector2(0,-5),Color(0.35,0.32,0.25),5.0,true)
		for t: float in [0.0,0.25,0.5,0.75,1.0]:
			var p: Vector2 = a.lerp(b,t)
			draw_line(p+Vector2(0,-7),p+up,Color(0.16,0.15,0.125),2.8,true)
			draw_line(p+Vector2(1,-7),p+up+Vector2(1,0),Color(0.42,0.38,0.28),0.8,true)
			draw_colored_polygon(PackedVector2Array([p+up+Vector2(0,-6),p+up+Vector2(-2.5,0),p+up+Vector2(2.5,0)]),Color(0.38,0.34,0.26))
		draw_line(a+up,b+up,Color(0.43,0.39,0.3),3.3,true)
		draw_line(a+Vector2(0,-17),b+Vector2(0,-17),Color(0.2,0.18,0.14),2.8,true)
		if pillar:
			draw_colored_polygon(PackedVector2Array([Vector2(-6,0),Vector2(-6,-49),Vector2(0,-53),Vector2(6,-49),Vector2(6,0),Vector2(0,4)]),Color(0.25,0.23,0.2))
			draw_line(Vector2(0,-52),Vector2(0,3),Color(0.42,0.38,0.3),2.0,true)
			draw_line(Vector2(-7,-49),Vector2(0,-54),Color(0.55,0.49,0.37),2.0,true)
