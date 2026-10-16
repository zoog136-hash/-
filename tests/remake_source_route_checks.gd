extends RefCounted
## Equivalent route obligations for A3 edges instead of authored prop rows.
## Called by the existing all-map hunting suite; no assertions are skipped.
static func run(tree: SceneTree,world: TwilightWorld) -> Dictionary:
	var field: RemakePlayableField=world.field_map
	var result: Dictionary={"checks":0,"failures":[],"metric":{}}
	var verify:=func(ok: bool,label: String) -> void:
		result.checks+=1
		if not ok: result.failures.append(str(field.data.map_id)+" "+label)
	var spawn:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	verify.call(field.definition.edition_status=="A3_PC_TOPOLOGY_CURRENT_M_UNVERIFIED","source edition explicit")
	verify.call(field.definition.corner_policy=="no_corner_cut","source corner policy")
	verify.call(field.walkable(spawn) and field.point_clear(spawn),"entry foot clearance")
	verify.call(world.field_minimap.field==field,"minimap shares source geometry")
	verify.call(is_instance_valid(field.collision_stream) and field.collision_stream.chunks.size()<=9,"bounded actual physics chunks")
	for service: Dictionary in field.data.portal+field.data.npc_spawn:
		var p:=Vector2(service.position[0],service.position[1])
		verify.call(field.point_clear(p) and not field.path(spawn,p).is_empty(),"connected service "+str(service.id))
	var rng:=RandomNumberGenerator.new();rng.seed=121084
	for region: Dictionary in field.data.monster_spawn:
		verify.call(field.region_cells[str(region.id)].size()>=int(region.max_count),"source spawn capacity "+str(region.id))
		for i: int in range(8):
			var p: Vector2=field.sample_spawn(str(region.id),rng)
			verify.call(p.is_finite() and field.point_clear(p) and not field.is_safe(p) and field.remake_region_contains(str(region.id),p),"spawn inside source region")
	var selected: Dictionary={}
	var origin: Vector2i=field.world_to_cell(spawn)
	for dy: int in range(-24,25,2):
		if not selected.is_empty(): break
		for dx: int in range(-24,25,2):
			if not selected.is_empty(): break
			var c: Vector2i=origin+Vector2i(dx,dy)
			if field.value_at(c,true)==0: continue
			var a: Vector2=field.cell_to_world(c)
			for heading: int in [0,2,4,6]:
				if not selected.is_empty(): break
				if field.can_step(c,heading): continue
				for stride: int in range(1,5):
					var b: Vector2=field.cell_to_world(c+field.DIRECTIONS[heading]*stride)
					if not field.point_clear(b) or field.line_clear(a,b): continue
					var path: PackedVector2Array=field.path(a,b)
					if path.is_empty(): continue
					var length: float=0;var previous: Vector2=a
					for p: Vector2 in path: length+=previous.distance_to(p);previous=p
					if length>a.distance_to(b)*1.2 and length<1000:
						selected={"from":a,"to":b,"length":length,"path":path};break
	verify.call(not selected.is_empty(),"real blocked shortcut and connected detour")
	var walked: float=0
	if not selected.is_empty():
		var a: Vector2=selected.from;var b: Vector2=selected.to
		var previous: Vector2=a
		for p: Vector2 in selected.path:
			verify.call(field.line_clear(previous,p),"detour respects source edges");previous=p
		world.player.global_position=a;field.collision_stream.refresh()
		await tree.physics_frame;await tree.physics_frame
		world.player.set_physics_process(true);world.player.set_touch_vector(a.direction_to(b))
		Engine.time_scale=3.0
		for i: int in range(30): await tree.physics_frame
		verify.call((world.player.global_position-a).dot(a.direction_to(b))<a.distance_to(b)*0.65,"actual manual motion cannot cross wall")
		world.player.set_touch_vector(Vector2.ZERO);world.player.global_position=a
		world.player.clear_click_path();world._set_click_destination(b)
		Engine.time_scale=3.0;previous=a
		for i: int in range(180):
			await tree.physics_frame
			var p: Vector2=world.player.global_position
			walked+=previous.distance_to(p);previous=p
			if i%10==0: verify.call(field.point_clear(p,3.5),"actual foot clears walls along detour")
			if p.distance_to(b)<6: break
		Engine.time_scale=1.0
		verify.call(world.player.global_position.distance_to(b)<12,"actual click movement completes detour")
		verify.call(walked>a.distance_to(b)*1.1,"actual route is longer than blocked shortcut")
		world.player.set_physics_process(false);world.player.clear_click_path()
	result.metric={"map_id":field.data.map_id,"geometry":"A3_PC_SOURCE_EDGES","original_M_coordinates_recovered":false,
		"physical_detour_walk":walked,"physics_chunks":field.collision_stream.chunks.size(),"checks":result.checks}
	return result
