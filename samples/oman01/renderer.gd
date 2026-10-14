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
	sample_floor = load("res://samples/oman01/assets/oman01_flagstones.png")
	if sample_floor == null:
		push_error("Oman 1F floor atlas unavailable; refuse placeholder fallback")
		return
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
				ground.variations.append(float((x*73856093 ^ y*19349663)&31)/31.0)
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
					var wall_line: int = y if edge == 0 else x
					rail.kind = "fence" if edge < 2 and ((wall_line*173+101)&15)<9 else ("masonry" if edge < 2 else "curb")
					rail.pillar = ((x*7+y*5+edge)%11)==0
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
		if texture == null: return
		for i: int in range(cells.size()):
			var p: Vector2 = cells[i]
			var idx: int = clampi(int(variations[i]*31.0),0,31)
			var uv := Rect2(float((idx%8)*96),float((idx/8)*48),96,48)
			var shade: float = 0.83 + float(idx%7)*0.015
			var tint := Color(shade,shade,shade*0.95)
			if debug: tint = Color(0.27,0.58,0.46)
			draw_texture_rect_region(texture,Rect2(p-Vector2(24,12),Vector2(48,24)),uv,tint)
			if debug:
				var c:=PackedVector2Array([p+Vector2(-24,0),p+Vector2(0,-12),p+Vector2(24,0),p+Vector2(0,12),p+Vector2(-24,0)])
				draw_polyline(c,Color(0.12,0.23,0.19,0.5),0.7,true)

class IronBoundary extends Node2D:
	## Visual representation ONLY. Movement collision remains the A3 directional map.
	## Wall material types are TWILIGHT reference-inspired art, not exact M prop IDs.
	var a: Vector2
	var b: Vector2
	var kind: String = "curb"
	var pillar: bool = false
	var debug: bool = false

	func _draw() -> void:
		if debug:
			draw_line(a,b,Color(0.95,0.28,0.18),3.0,true)
			return
		var foot:=Vector2(0,7)
		draw_colored_polygon(PackedVector2Array([a,b,b+foot,a+foot]),Color("1a201f"))
		draw_line(a+foot,b+foot,Color("080b0d"),2,true)
		draw_line(a,b,Color("505147"),2.8,true)
		draw_line(a+Vector2(0,-2),b+Vector2(0,-2),Color("777260"),.9,true)
		if kind=="curb":
			if pillar: _rubble(a.lerp(b,.5))
			return
		if kind=="masonry":
			var up:=Vector2(0,-34)
			draw_colored_polygon(PackedVector2Array([a,b,b+up,a+up]),Color("282f2e"))
			draw_line(a+up,b+up,Color("716f5c"),2.5,true)
			draw_line(a+Vector2(0,-17),b+Vector2(0,-17),Color("101616"),1.5,true)
			for part: float in [0.2,0.52,0.84]:
				var pos:=a.lerp(b,part)
				draw_line(pos+Vector2(0,-17),pos+Vector2(0,-34),Color("151b1b"),1.1,true)
		else:
			draw_line(a+Vector2(0,-38),b+Vector2(0,-38),Color("394241"),3.5,true)
			for i: int in range(6):
				var p:=a.lerp(b,float(i)/5.0)
				var up:=Vector2(0,-39-float((i*5)%4))
				draw_line(p,p+up,Color("111719"),3.5,true)
				draw_line(p+Vector2(1,0),p+up+Vector2(1,0),Color("46514a"),.8,true)
				draw_colored_polygon(PackedVector2Array([p+up,p+up+Vector2(-2,-4),p+up+Vector2(2,-4)]),Color("394039"))
			draw_line(a+Vector2(0,-15),b+Vector2(0,-15),Color("323d3b"),2.7,true)
			draw_line(a+Vector2(0,-29),b+Vector2(0,-29),Color("0e1414"),2.0,true)
		if pillar:
			var p:Vector2=a.lerp(b,.48)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-6,2),p+Vector2(6,2),p+Vector2(5,-38),p+Vector2(0,-43),p+Vector2(-6,-38)]),Color("2c3432"))
			draw_line(p+Vector2(-6,-38),p+Vector2(0,-43),Color("676956"),2,true)
			draw_line(p+Vector2(-3,-35),p+Vector2(-3,2),Color("596055"),1.1,true)
			draw_rect(Rect2(p+Vector2(-7,-1),Vector2(14,6)),Color("44473e"),true)

	func _rubble(pos: Vector2)->void:
		draw_colored_polygon(PackedVector2Array([pos+Vector2(-8,1),pos+Vector2(6,1),pos+Vector2(10,-5),pos+Vector2(-5,-9)]),Color("323a37"))
		draw_line(pos+Vector2(-5,-9),pos+Vector2(10,-5),Color("6b6b59"),1.4,true)
