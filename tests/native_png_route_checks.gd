extends RefCounted
## The hunting suite's real geometry/body obligations on reviewed PNG floors.
## Exact grid physics and source rendering have additional exhaustive suites.
static func run(tree: SceneTree,world: TwilightWorld) -> Dictionary:
	var field: NativePngField=world.field_map
	var result: Dictionary={"checks":0,"failures":[],"metric":{}}
	var verify:=func(ok: bool,label: String) -> void:
		result.checks+=1
		if not ok: result.failures.append(str(field.data.map_id)+" "+label)
	var spawn: Vector2=world._spawn_position()
	verify.call(field.png_manifest.get("native_pixel_scale")==1,"original PNG pixel scale explicit")
	verify.call(not field.data.collision_scope.is_empty(),"manual collision review scope explicit")
	verify.call(field.walkable(spawn) and field.point_clear(spawn,4),"actual entry foot clearance")
	verify.call(world.field_minimap.field==field,"minimap shares reviewed native geometry")
	verify.call(world.field_physics.name=="NativePngCollision" and world.field_physics.get_child_count()>4,"actual bounded grid and external canvas physics installed")
	for raw: Array in field.data.route_checks:
		var target:=Vector2(raw[0],raw[1])
		var path: PackedVector2Array=field.path(spawn,target)
		verify.call(field.walkable(target) and not path.is_empty(),"reviewed route remains connected "+str(raw))
		for i: int in range(1,path.size()): verify.call(field.line_clear(path[i-1],path[i]),"route respects native obstacle corners")
	for service: Dictionary in field.data.portal+field.data.npc_spawn:
		var p:=Vector2(service.position[0],service.position[1])
		verify.call(field.point_clear(p,4) and not field.path(spawn,p).is_empty(),"connected native entrance/NPC "+str(service.id))
	var rng:=RandomNumberGenerator.new();rng.seed=121084
	for region: Dictionary in field.data.monster_spawn:
		verify.call(field.spawn_cells.get(str(region.id),[]).size()>=int(region.max_count),"native encounter capacity "+str(region.id))
		for i: int in range(8):
			var p: Vector2=field.sample_spawn(str(region.id),rng)
			verify.call(p.is_finite() and field.walkable(p) and field.point_clear(p,4) and field.spawn_contains(region,p) and not field.is_safe(p),"spawn inside reviewed source region")
	var selected: Dictionary={}
	for blocker: Dictionary in field.blockers:
		if not selected.is_empty(): break
		var box: Rect2=blocker.box
		for direction: Vector2 in [Vector2.RIGHT,Vector2.DOWN]:
			var reach: float=box.size.dot(direction)*.5+32
			var a: Vector2=box.get_center()-direction*reach
			var b: Vector2=box.get_center()+direction*reach
			if not field.walkable(a) or not field.walkable(b) or not field.point_clear(a,4) or not field.point_clear(b,4) or field.line_clear(a,b): continue
			var path: PackedVector2Array=field.path(a,b)
			if path.is_empty(): continue
			var length: float=0;var previous: Vector2=a
			for point: Vector2 in path: length+=previous.distance_to(point);previous=point
			if length>a.distance_to(b)*1.2 and length<1600:
				selected={"from":a,"to":b,"path":path,"length":length};break
	if selected.is_empty():
		# A traced floor may exclude an obstacle in its boundary instead of
		# adding a redundant blocker row. Require the same REAL closed shortcut
		# and connected physical detour in that grid; never invent a test wall.
		for y: int in range(field.height):
			if not selected.is_empty(): break
			for x: int in range(field.width):
				if not selected.is_empty(): break
				var cell:=Vector2i(x,y)
				if field.astar.is_point_solid(cell): continue
				var a: Vector2=field.cell_to_world(cell)
				if not field.point_clear(a,4): continue
				for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
					var edge: Vector2i=cell+direction
					if not field.astar.is_in_boundsv(edge) or not field.astar.is_point_solid(edge): continue
					for stride: int in range(2,25):
						var goal: Vector2i=cell+direction*stride
						if not field.astar.is_in_boundsv(goal) or field.astar.is_point_solid(goal): continue
						var b: Vector2=field.cell_to_world(goal)
						if not field.point_clear(b,4) or field.line_clear(a,b): continue
						var path: PackedVector2Array=field.path(a,b)
						if path.is_empty(): continue
						var length: float=0;var previous: Vector2=a
						for point: Vector2 in path: length+=previous.distance_to(point);previous=point
						if length>a.distance_to(b)*1.2 and length<1600:
							selected={"from":a,"to":b,"path":path,"length":length};break
					if not selected.is_empty(): break
	verify.call(not selected.is_empty(),"actual native obstacle/floor boundary blocks shortcut with a connected detour")
	var walked: float=0
	if not selected.is_empty():
		var a: Vector2=selected.from;var b: Vector2=selected.to
		var previous: Vector2=a
		for point: Vector2 in selected.path:
			verify.call(field.line_clear(previous,point),"detour respects native walls");previous=point
		world.player.global_position=a;await tree.physics_frame;await tree.physics_frame
		verify.call(not world.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(a,b,4)).is_empty(),"actual native physics blocks shortcut ray")
		world.player.set_physics_process(true);world.player.set_touch_vector(a.direction_to(b))
		Engine.time_scale=3.0
		for i: int in range(30): await tree.physics_frame
		verify.call((world.player.global_position-a).dot(a.direction_to(b))<a.distance_to(b)*.65,"manual input cannot cross original obstacle")
		world.player.set_touch_vector(Vector2.ZERO);world.player.global_position=a
		world.player.clear_click_path();world._set_click_destination(b);previous=a
		for i: int in range(240):
			await tree.physics_frame
			var point: Vector2=world.player.global_position
			walked+=previous.distance_to(point);previous=point
			if i%10==0: verify.call(field.point_clear(point,3.5),"actual foot clears native obstacle on detour")
			if point.distance_to(b)<6: break
		Engine.time_scale=1.0
		verify.call(world.player.global_position.distance_to(b)<12,"actual click completes native obstacle detour")
		verify.call(walked>a.distance_to(b)*1.1,"actual body takes the longer native route")
		world.player.set_physics_process(false);world.player.clear_click_path()
	result.metric={"map_id":world.active_map_id,"art_map_id":field.data.map_id,"geometry":"MANUALLY_REVIEWED_NATIVE_PNG_FLOORS","original_M_coordinates_recovered":false,"physical_detour_walk":walked,"checks":result.checks}
	return result
