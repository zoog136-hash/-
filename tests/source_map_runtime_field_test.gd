extends SceneTree
const RUNTIME=preload("res://scripts/maps/source_map_runtime.gd")
const GRID=preload("res://scripts/maps/source_v1_grid.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE77_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var field: RemakePlayableField=RUNTIME.load_field("source_77")
	check(field!=null,"real full-resolution pack, raw grid, reviewed probes and entry")
	if field==null:quit(1);return
	check(field.data.monster_spawn.is_empty(),"no automatic new monster spawns")
	var start:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	var gate:=Vector2(field.data.portal[0].position[0],field.data.portal[0].position[1])
	check(field.point_clear(start,4),"entry foot clearance")
	check(field.point_clear(gate,4),"return gate foot clearance")
	check(not field.path(start,gate).is_empty(),"return path reachable")
	check(field.data.portal[0].target_map=="aden_world","return uses current Aden entry, no stale source0,0")
	var oracle_path: String=OS.get_environment("TWILIGHT_SOURCE77_EDGE_ORACLE")
	if not oracle_path.is_empty():
		var oracle: PackedByteArray=FileAccess.get_file_as_bytes(oracle_path)
		check(oracle.size()==field.width*field.height,"producer 3.80c reference edge oracle size")
		var matches: bool=oracle.size()==field.width*field.height
		if matches:
			for y: int in range(field.height):
				for x: int in range(field.width):
					for h: int in range(8):
						if field.raw_grid.edge(Vector2i(x,y),h)!=((oracle[y*field.width+x]&(1<<h))!=0):matches=false
		check(matches,"all 131072 directional queries match supplied 3.80c reference")
	var loaded: Dictionary={"map_id":"source_77","position":[start.x,start.y],"source_map84_layouts":RUNTIME.saved_layouts(),
		"original_position":{"source_map_id":77,"grid_sha256":field.definition.source_sha256,"source":field.coordinates.source_components(start)},
		"ground_drops":[{"id":"retained-physical-id","map_id":"source_77","position":[gate.x,gate.y],"quantity":3}],
		"monster_world":{"bosses":{"faith_01:reaper":{"hp":777,"phase":"alive","position":[1,2],"home":[3,4]}}}}
	var original: Dictionary=loaded.duplicate(true)
	check(RUNTIME.validate_save(loaded).is_empty(),"player and ground drop coordinates validate together")
	check(RUNTIME.validate_save(JSON.parse_string(JSON.stringify(loaded))).is_empty(),"real JSON float-number identities retain integer revision precision")
	check(loaded==original,"validation preserves physical item, quantity, old boss HP and all original fields")
	var bad: Dictionary=loaded.duplicate(true);bad.source_map84_layouts.source_77.layout_revision=1
	check(not RUNTIME.validate_save(bad).is_empty(),"unknown old layout cannot silently reuse pixels")
	bad=loaded.duplicate(true);bad.ground_drops[0].position=[-10000,-10000]
	check(not RUNTIME.validate_save(bad).is_empty(),"blocked drop prevents partial restore")
	bad=loaded.duplicate(true);bad.erase("source_map84_layouts")
	check(not RUNTIME.validate_save(bad).is_empty(),"missing coordinate identity fails closed")
	bad=loaded.duplicate(true);bad.original_position.source=[0,0]
	check(not RUNTIME.validate_save(bad).is_empty(),"mismatched dual coordinate representations fail before live mutation")
	bad=loaded.duplicate(true);bad.ground_drops="corrupt"
	check(not RUNTIME.validate_save(bad).is_empty(),"malformed drop container fails closed without script exceptions")
	bad=loaded.duplicate(true);bad.monster_world={"bosses":{"source_77:existing":{"position":[-10000,-10000],"home":[]}}}
	check(not RUNTIME.validate_save(bad).is_empty(),"persisted monster positions fail before live state mutation")
	bad.map_id="faith_01";bad.ground_drops=[]
	check(not RUNTIME.validate_save(bad).is_empty(),"inactive-map monster positions also require verified layout and landing")
	bad=loaded.duplicate(true);bad.monster_world=17
	check(not RUNTIME.validate_save(bad).is_empty(),"malformed monster container fails without script exceptions")
	check(not RUNTIME.validate_save({"map_id":"source_280","ground_drops":[]}).is_empty(),"future unverified map save cannot fall back and be overwritten")
	for mid: String in RUNTIME.policy():
		var other: RemakePlayableField=RUNTIME.load_field(mid)
		check(other!=null,"individually reviewed entry, probes, source origin and return path: "+mid)
		if other!=null:other.close()
	check(RUNTIME.validate_save({"map_id":"faith_01","position":[1,2],"ground_drops":[]}).is_empty(),"protected save remains on existing path")
	var back: Array=field.coordinates.source_components(start)
	check(absf(float(back[0])-32765.5)<.001 and absf(float(back[1])-32843.5)<.001,"cell-center roundtrip")
	var parent:=Node2D.new();root.add_child(parent)
	var player:=CharacterBody2D.new();player.name="Player";player.collision_layer=1;player.collision_mask=4
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=4;shape.shape=circle;player.add_child(shape)
	parent.add_child(player);player.position=start
	field.build_physics(parent)
	await physics_frame;await physics_frame
	var wall_start: Vector2=field.coordinates.to_world(Vector2(32764,32838))
	var wall_end: Vector2=field.coordinates.to_world(Vector2(32765,32838))
	player.position=wall_start;field.collision_stream.last_cell=Vector2i(-999,-999);field.collision_stream.refresh()
	await physics_frame;await physics_frame
	check(field.walkable(wall_start) and not field.walkable(wall_end),"reviewed staircase hole has solid destination")
	check(player.test_move(player.global_transform,wall_end-wall_start),"actual 4px player body collides with staircase boundary")
	check(not parent.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(wall_start,wall_end,4)).is_empty(),"actual collision ray hits same staircase boundary")
	player.position=start
	var direction: Vector2=(gate-start).normalized()
	for i: int in range(8):
		player.velocity=direction*60
		player.move_and_slide()
		await physics_frame
	check(field.point_clear(player.global_position,3.9),"actual movement retains foot clearance")
	parent.queue_free();await process_frame
	field.close()
	print("SOURCE77_FIELD_", "OK" if failures.is_empty() else "FAILED"," checks=",checks)
	quit(0 if failures.is_empty() else 1)
