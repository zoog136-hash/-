extends "res://scripts/maps/playable_field.gd"
class_name OriginalPlayableField
const COORDINATES=preload("res://scripts/maps/source_coordinates.gd")
const SOURCE_NAV=preload("res://addons/twilight_l1j/twilight_source_navigation.gd")
const DIRECTIONS: Array[Vector2i]=[Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
const CACHE_LIMIT: int=64
var coordinates: OriginalMapCoordinates=COORDINATES.new()
var definition: Dictionary={}
var chunk_table: Dictionary={}
var nav_cache: Dictionary={}
var nav_used: Dictionary={}
var packs: Dictionary={}
var source_doors = preload("res://scripts/maps/source_doors.gd").new()
var overview: ImageTexture
var nav_reads: int=0
var failed_chunks: Dictionary={}

func configure_source(value: Dictionary) -> bool:
	if not bool(value.get("playable",false)) or value.navigation.profile!="A3_STATIC_EDGES": return false
	definition=value
	coordinates.configure(value.origin,value.dimensions)
	width=coordinates.dimensions.x
	height=coordinates.dimensions.y
	bounds=coordinates.canvas_bounds()
	for row: Array in value.navigation.chunks: chunk_table[Vector2i(int(row[0]),int(row[1]))]=row
	astar=AStarGrid2D.new()
	astar.region=Rect2i(0,0,1,1)
	astar.update()
	source_doors.configure(value.get("doors",[]),coordinates.origin)
	data={"map_id":value.map_id,"map_name":value.map_name,"short_name":"원본 통행 지도 · 이미지 미확보",
		"layout_revision":value.layout_revision,"spawn_position":[],"bounds":[0,0,bounds.size.x,bounds.size.y],
		"regions":[],"water":[],"roads":[],"surfaces":[],"npc_spawn":[],"monster_spawn":[],"portal":[],
		"camera":{"zoom":1.0,"offset":[0,-32],"follow_speed":8.0},"streaming":{"monster_sleep_distance":1600}}
	if str(value.map_id)=="l1_4": data.short_name="원본 통행 · 자체 제작 타일 v1"
	var spawn: Vector2=coordinates.to_world(Vector2(float(value.spawn_source[0]),float(value.spawn_source[1])))
	data.spawn_position=[spawn.x,spawn.y]
	for record: Dictionary in value.npc_spawns:
		var npc: Dictionary=record.duplicate(true)
		var p: Vector2=coordinates.to_world(Vector2(float(record.source_position[0]),float(record.source_position[1])))
		npc.position=[p.x,p.y]
		data.npc_spawn.append(npc)
	for row: Dictionary in value.portals:
		var p: Vector2=coordinates.to_world(Vector2(float(row.src_x),float(row.src_y)))
		data.portal.append({"id":"source_%d_%d_%d" % [int(value.source_map_id),int(row.src_x),int(row.src_y)],
			"name":str(row.get("note","원본 출입구")),"position":[p.x,p.y],"radius":9.0,
			"target_map":"l1_%d" % int(row.new_mapid),"target_source":[row.new_x,row.new_y],
			"min_level":row.get("min_level",0),"max_level":row.get("max_level",0)})
	for record: Dictionary in value.monster_spawns:
		if str(record.twilight_name).is_empty(): continue
		var row: Dictionary=record.source_row
		if int(row.get("count",0))<=0: continue
		var box: Rect2i=_source_spawn_rect(row)
		var p: Vector2=coordinates.to_world(Vector2(box.position)+Vector2(box.size)*0.5)
		data.monster_spawn.append({"id":"source_spawn_%d" % int(row.id),"max_count":int(row.count),
			"monster_types":[str(record.twilight_name)],"mode":"dense","source_rect":box,
			"rect":[p.x-48,p.y-48,96,96],"source_row":row,"source_name":record.source_name,
			"respawn_time":maxf(1,float(row.get("min_respawn_delay",60))),"roaming_radius":float(row.get("movement_distance",0))*26.83})
	preload("res://scripts/maps/source_gameplay.gd").apply(self)
	return walkable(spawn)

func _source_spawn_rect(row: Dictionary) -> Rect2i:
	if int(row.get("locx1",0))>0 and int(row.get("locx2",0))>=int(row.locx1):
		return Rect2i(int(row.locx1),int(row.locy1),int(row.locx2)-int(row.locx1)+1,int(row.locy2)-int(row.locy1)+1)
	var rx: int=maxi(0,int(row.get("randomx",0)))
	var ry: int=maxi(0,int(row.get("randomy",0)))
	return Rect2i(int(row.locx)-rx,int(row.locy)-ry,rx*2+1,ry*2+1)

func _chunk(key: Vector2i) -> PackedByteArray:
	if nav_cache.has(key): nav_used[key]=Time.get_ticks_usec(); return nav_cache[key]
	if not chunk_table.has(key) or failed_chunks.has(key): return PackedByteArray()
	var row: Array=chunk_table[key]
	var shard: int=int(row[4])
	if not packs.has(shard): packs[shard]=FileAccess.open("res://data/original_maps/navigation-%02d.bin" % shard,FileAccess.READ)
	var pack: FileAccess=packs[shard]
	if pack==null: failed_chunks[key]=true; return PackedByteArray()
	pack.seek(int(row[5]))
	var raw: PackedByteArray=pack.get_buffer(int(row[6])).decompress(int(row[2])*int(row[3])*2,FileAccess.COMPRESSION_DEFLATE)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(raw)
	if raw.size()!=int(row[2])*int(row[3])*2 or hash.finish().hex_encode()!=str(row[7]):
		failed_chunks[key]=true
		push_error("Original chunk integrity failure: "+str(definition.map_id))
		return PackedByteArray()
	if nav_cache.size()>=CACHE_LIMIT:
		var old: Vector2i=nav_cache.keys()[0]
		for other: Vector2i in nav_used:
			if int(nav_used[other])<int(nav_used[old]): old=other
		nav_cache.erase(old)
		nav_used.erase(old)
	nav_cache[key]=raw
	nav_used[key]=Time.get_ticks_usec()
	nav_reads+=1
	return raw

func in_bounds(cell: Vector2i) -> bool: return cell.x>=0 and cell.y>=0 and cell.x<width and cell.y<height
func value_at(cell: Vector2i, mask: bool=false) -> int:
	if not in_bounds(cell): return 0
	var key:=Vector2i(cell.x>>6,cell.y>>6)
	var raw: PackedByteArray=_chunk(key)
	if raw.is_empty(): return 0
	var row: Array=chunk_table[key]
	var cw: int=int(row[2])
	return int(raw[(cw*int(row[3]) if mask else 0)+(cell.y&63)*cw+(cell.x&63)])
func world_to_cell(p: Vector2) -> Vector2i: return coordinates.world_to_cell(p)
func cell_to_world(c: Vector2i) -> Vector2: return coordinates.cell_to_world(c)
func walkable(p: Vector2) -> bool: return value_at(world_to_cell(p),true)!=0
func point_clear(p: Vector2, _padding: float=24.0) -> bool: return walkable(p)
func nearest_cell(p: Vector2) -> Vector2i:
	var c: Vector2i=world_to_cell(p)
	if not in_bounds(c): return Vector2i(-1,-1)
	for radius: int in range(17):
		for dy: int in range(-radius,radius+1):
			for dx: int in range(-radius,radius+1):
				if absi(dx)!=radius and absi(dy)!=radius: continue
				var candidate: Vector2i=c+Vector2i(dx,dy)
				if value_at(candidate,true)!=0: return candidate
	return Vector2i(-1,-1)
func can_step(c: Vector2i, heading: int) -> bool:
	return heading>=0 and heading<8 and (value_at(c,true)&(1<<heading))!=0 and in_bounds(c+DIRECTIONS[heading]) and not source_doors.blocked(c,c+DIRECTIONS[heading])
func line_clear(from: Vector2, to: Vector2) -> bool:
	if not from.is_finite() or not to.is_finite(): return false
	# Keep DDA arithmetic in scalar doubles. Vector2 rounds local coordinates
	# to float32, splitting simultaneous crossings into two forbidden edges.
	var ax: float=(from.x/24.0-from.y/12.0+width)/2.0
	var ay: float=(from.x/24.0+from.y/12.0-width)/2.0
	var bx: float=(to.x/24.0-to.y/12.0+width)/2.0
	var by: float=(to.x/24.0+to.y/12.0-width)/2.0
	var cell:=Vector2i(floori(ax),floori(ay))
	var target:=Vector2i(floori(bx),floori(by))
	if value_at(cell,true)==0 or value_at(target,true)==0: return false
	var sx: int=int(signf(bx-ax))
	var sy: int=int(signf(by-ay))
	var tx: float=INF if sx==0 else (cell.x+(1 if sx>0 else 0)-ax)/(bx-ax)
	var ty: float=INF if sy==0 else (cell.y+(1 if sy>0 else 0)-ay)/(by-ay)
	var dx: float=INF if sx==0 else absf(1/(bx-ax))
	var dy: float=INF if sy==0 else absf(1/(by-ay))
	for step: int in range(mini(65536,absi(target.x-cell.x)+absi(target.y-cell.y)+2)):
		if cell==target: return true
		var offset:=Vector2i.ZERO
		if absf(tx-ty)<0.0000001: offset=Vector2i(sx,sy);tx+=dx;ty+=dy
		elif tx<ty: offset=Vector2i(sx,0);tx+=dx
		else: offset=Vector2i(0,sy);ty+=dy
		if not can_step(cell,DIRECTIONS.find(offset)): return false
		cell+=offset
	return false
func path(from: Vector2,to: Vector2) -> PackedVector2Array:
	var start: Vector2i=nearest_cell(from)
	var goal: Vector2i=nearest_cell(to)
	if start.x<0 or goal.x<0: return PackedVector2Array()
	if line_clear(from,to): return PackedVector2Array([to])
	var navigator := OriginalChunkNavigation.new()
	navigator.source=self
	navigator.loaded=true
	navigator.coordinates.configure(Vector2i(width,height),Vector2i.ZERO,Transform2D.IDENTITY)
	var result:=PackedVector2Array()
	for c: Vector2i in navigator.find_path(start,goal): result.append(cell_to_world(c))
	if result.size()>1 and line_clear(from,result[1]): result.remove_at(0)
	if not result.is_empty() and walkable(to) and line_clear(result[-1],to): result.append(to)
	return result
func region_at(p: Vector2) -> Dictionary:
	return {"id":"source_safe" if is_safe(p) else "source_field","name":data.map_name,"type":"safe" if is_safe(p) else "combat","color":"738e81"}
func is_safe(p: Vector2) -> bool: return (value_at(world_to_cell(p))&48)==16
func build_physics(parent: Node2D) -> StaticBody2D:
	var body:=StaticBody2D.new()
	body.name="OriginalSourceMotionGuard"
	body.collision_layer=4
	body.collision_mask=0
	parent.add_child(body)
	return body
func close() -> void: packs.clear(); nav_cache.clear(); nav_used.clear()
func source_spawn_active(region: Dictionary, player_position: Vector2) -> bool:
	var box: Rect2i=region.source_rect
	return Rect2(Vector2(box.position),Vector2(box.size)).grow(40).has_point(coordinates.to_source(player_position))
func sample_source_spawn(region: Dictionary, player_position: Vector2, random: RandomNumberGenerator) -> Vector2:
	var source: Vector2=coordinates.to_source(player_position)
	var box: Rect2i=(region.source_rect as Rect2i).intersection(Rect2i(Vector2i(source)-Vector2i(40,40),Vector2i(81,81)))
	if not box.has_area(): return Vector2.INF
	for attempt: int in range(96):
		var p: Vector2=coordinates.to_world(Vector2(random.randi_range(box.position.x,box.end.x-1),random.randi_range(box.position.y,box.end.y-1)))
		if walkable(p) and not is_safe(p): return p
	return Vector2.INF
func random_landing(random: RandomNumberGenerator, near: Vector2, min_distance: float=160.0,max_distance: float=INF) -> Vector2:
	var keys: Array=chunk_table.keys()
	for attempt: int in range(1500):
		var key: Vector2i=keys[random.randi_range(0,keys.size()-1)]
		var row: Array=chunk_table[key]
		var c: Vector2i=key*64+Vector2i(random.randi_range(0,int(row[2])-1),random.randi_range(0,int(row[3])-1))
		var p: Vector2=cell_to_world(c)
		if value_at(c,true)!=0 and p.distance_to(near)>=min_distance and p.distance_to(near)<=max_distance: return p
	return Vector2.INF

class OriginalChunkNavigation extends TwilightL1JSourceNavigation:
	var source: OriginalPlayableField
	func can_step(cell: Vector2i, heading: int) -> bool: return source.can_step(cell,heading)

func overview_texture() -> ImageTexture:
	if overview != null: return overview
	var image := Image.create(128,64,false,Image.FORMAT_RGBA8)
	for y: int in range(64):
		for x: int in range(128):
			var c: Vector2i = world_to_cell(Vector2((x+0.5)/128,(y+0.5)/64)*bounds.size)
			var attr: int = value_at(c)
			if value_at(c,true) != 0:
				image.set_pixel(x,y,Color("818864") if (attr&48)==16 else Color("576e5b"))
			elif attr != 0: image.set_pixel(x,y,Color("293233"))
	overview = ImageTexture.create_from_image(image)
	return overview
