extends "res://scripts/maps/remake_field.gd"
## New source IDs only in the first verified cohort. Existing fields are untouched.
const GRID = preload("res://scripts/maps/source_v1_grid.gd")
var raw_grid = GRID.new()
var runtime_record: Dictionary

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
	return raw_grid.can_step(cell,heading)

func can_step(cell: Vector2i, heading: int) -> bool:
	return source_can_step(cell,heading)

func close() -> void:
	raw_grid.bytes.clear()
	super.close()
