extends "res://scripts/maps/remake_field.gd"
## Reviewed source fields; replacements retain the existing authored gameplay roster.
const GRID = preload("res://scripts/maps/source_v1_grid.gd")
const MIGRATION = preload("res://scripts/maps/source_map_save_migration.gd")
var raw_grid = GRID.new()
var runtime_record: Dictionary
var entry_reach:=PackedByteArray()
var entry_cells:=PackedInt32Array()

func configure_runtime(record: Dictionary, policy: Dictionary, art: RefCounted) -> bool:
	runtime_record=record
	var spec: Dictionary=record.collision
	var packed: PackedByteArray=FileAccess.get_file_as_bytes(art.root_path+"/"+str(spec.file))
	if FileAccess.get_sha256(art.root_path+"/"+str(spec.file))!=spec.sha256:return false
	var raw: PackedByteArray=packed.decompress_dynamic(16000000,FileAccess.COMPRESSION_GZIP)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	if hash.finish().hex_encode()!=spec.raw_sha256:return false
	if not raw_grid.configure(int(record.source_map_id),spec.bounds,Vector2i(spec.width,spec.height),raw):return false
	if raw_grid.origin!=Vector2i(record.origin_source[0],record.origin_source[1]):return false
	if not raw_grid.restrict_to_artwork(record.chunks):return false
	width=raw_grid.width;height=raw_grid.height
	# Exact source cell-center projection used by the supplied client chunks.
	if not coordinates.configure([raw_grid.origin.x,raw_grid.origin.y],[width,height],{"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,768]}):return false
	bounds=coordinates.canvas_bounds()
	definition={"source_map_id":record.source_map_id,"source_sha256":spec.raw_sha256,"map_id":record.target_map_id,
		"rules":{"escapable":1},"getback":[],"layout_revision":policy.layout_revision}
	var spawn: Vector2=coordinates.to_world(Vector2(policy.entry_source[0],policy.entry_source[1]))
	var portal_point: Vector2=coordinates.to_world(Vector2(policy.return_source[0],policy.return_source[1]))
	data={"map_id":record.target_map_id,"map_name":record.korean_name,"short_name":record.korean_name,
		"layout_revision":policy.layout_revision,"spawn_position":[spawn.x,spawn.y],
		"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],
		"camera":{"zoom":1.0,"offset":[0,-32],"follow_speed":8.0},"regions":[],"water":[],"roads":[],"surfaces":[],
		"npc_spawn":[],"monster_spawn":[],"streaming":{"monster_sleep_distance":1600},
		"portal":[{"id":"source%d_verified_return" % int(record.source_map_id),"name":"아덴으로 귀환","position":[portal_point.x,portal_point.y],"radius":18.0,"target_map":"aden_world"}]}
	astar=AStarGrid2D.new();astar.region=Rect2i(0,0,1,1);astar.update()
	reservations=[{"center":[spawn.x,spawn.y],"radius":64.0}]
	png_game_pack=art
	set_meta("source_map84",true)
	for point: Array in policy.walk_probes:
		if not point_clear(coordinates.to_world(Vector2(point[0],point[1])),4.0):return false
	for point: Array in policy.solid_probes:
		if walkable(coordinates.to_world(Vector2(point[0],point[1]))):return false
	return point_clear(spawn,4.0) and point_clear(portal_point,4.0) and not path(spawn,portal_point).is_empty()

func value_at(cell: Vector2i, mask: bool=false) -> int:
	return raw_grid.mask(cell) if mask else raw_grid.tile(cell)

func source_can_step(cell: Vector2i, heading: int) -> bool:
	return heading>=0 and heading<8 and (raw_grid.mask(cell)&(1<<heading))!=0

func can_step(cell: Vector2i, heading: int) -> bool:
	return source_can_step(cell,heading)

func preserve_gameplay(previous: RemakePlayableField, legacy: Dictionary) -> bool:
	var source_data: Dictionary=previous.data
	var occupied: Array=[]
	var staged: Dictionary={}
	for category: String in ["npc_spawn","portal"]:
		staged[category]=source_data[category].duplicate(true)
		for row: Dictionary in staged[category]:
			var p: Vector2=MIGRATION.choose(row.position,self,legacy,occupied,80.0)
			if not p.is_finite():return false
			row.position=[p.x,p.y];occupied.append(p)
	staged.monster_spawn=source_data.monster_spawn.duplicate(true)
	var next_cells: Dictionary={}
	_build_entry_reach()
	for region: Dictionary in staged.monster_spawn:
		var cells:=PackedInt32Array()
		for flat: int in previous.region_cells.get(str(region.id),PackedInt32Array()):
			var source_cell: Vector2i=Vector2i(flat%previous.width,flat/previous.width)+previous.coordinates.origin
			var local: Vector2i=source_cell-coordinates.origin
			var p: Vector2=cell_to_world(local)
			if in_bounds(local) and entry_reach[local.y*width+local.x]!=0 and point_clear(p,4.0):cells.append(local.y*width+local.x)
		if cells.size()<int(region.max_count):return false
		cells.sort();next_cells[str(region.id)]=cells
		var old_rect: Array=region.rect
		var corner: Vector2=MIGRATION.converted([old_rect[0],old_rect[1]],self,legacy)
		if not corner.is_finite():return false
		region.rect=[corner.x,corner.y,old_rect[2],old_rect[3]]
		region.source_cells=Array(cells)
		region.layout_revision=int(data.layout_revision)
	for key: String in staged:data[key]=staged[key]
	region_cells=next_cells
	reservations=[{"center":data.spawn_position,"radius":64.0}]
	for row: Dictionary in data.npc_spawn+data.portal:reservations.append({"center":row.position,"radius":64.0})
	return true

func gameplay_snapshot() -> Dictionary:
	return {"npc_spawn":data.npc_spawn.duplicate(true),"portal":data.portal.duplicate(true),"monster_spawn":data.monster_spawn.duplicate(true),
		"region_cells":region_cells.duplicate(true),"reservations":reservations.duplicate(true)}

func restore_gameplay(snapshot: Dictionary) -> void:
	for key: String in ["npc_spawn","portal","monster_spawn"]:data[key]=snapshot[key].duplicate(true)
	region_cells=snapshot.region_cells.duplicate(true);reservations=snapshot.reservations.duplicate(true)

func _build_entry_reach() -> void:
	if not entry_reach.is_empty():return
	entry_reach.resize(width*height);entry_reach.fill(0)
	var start: Vector2i=world_to_cell(Vector2(data.spawn_position[0],data.spawn_position[1]))
	entry_cells.append(start.y*width+start.x);entry_reach[start.y*width+start.x]=1
	var head: int=0
	while head<entry_cells.size():
		var flat: int=entry_cells[head];head+=1
		var c:=Vector2i(flat%width,flat/width)
		for h: int in [0,2,4,6]:
			if not source_can_step(c,h):continue
			var next: Vector2i=c+DIRECTIONS[h]
			var key: int=next.y*width+next.x
			if entry_reach[key]!=0:continue
			entry_reach[key]=1;entry_cells.append(key)

func random_landing(random: RandomNumberGenerator, near: Vector2, min_distance: float=160.0,max_distance: float=INF) -> Vector2:
	_build_entry_reach()
	for attempt: int in range(160):
		var flat: int=entry_cells[random.randi_range(0,entry_cells.size()-1)]
		var p: Vector2=cell_to_world(Vector2i(flat%width,flat/width))
		if p.distance_to(near)>=min_distance and p.distance_to(near)<=max_distance and point_clear(p,4):return p
	return Vector2.INF

func close() -> void:
	raw_grid.bytes.clear()
	raw_grid.masks.clear();raw_grid.width=0;raw_grid.height=0
	entry_reach.clear();entry_cells.clear()
	super.close()
