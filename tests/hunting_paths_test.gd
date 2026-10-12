extends SceneTree
## Main scene, real collision shapes, real player movement on every map.
var failures: Array[String] = []
var checks: int = 0
var metrics: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("HUNTING_PATH_FAIL "+label)

func vector(raw: Array) -> Vector2: return Vector2(raw[0],raw[1])
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.set_process(false)
	world.save_timer=-10000
	world.player.set_auto_enabled(false)
	var entries: Array=[{"map_id":"aden_world"}]
	entries.append_array(JSON.parse_string(FileAccess.get_file_as_string(world.FIELD_INDEX_PATH)))
	var rng := RandomNumberGenerator.new()
	rng.seed=121084
	for entry: Dictionary in entries:
		var id: String=str(entry.map_id)
		var began: int=Time.get_ticks_msec()
		world._set_map(id,false)
		world.portal_cooldown=10000
		world.player.set_physics_process(false)
		world.field_population.set_process(false)
		for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
		await physics_frame
		var field: PlayableField=world.field_map
		var spawn: Vector2=vector(field.data.spawn_position)
		var paths: Dictionary=field.data.get("hunting_paths",{})
		check(paths.get("version",0)==1,id+" actual pathway data active")
		check(paths.get("verification","")=="reference_style_local_approximation",id+" source precision explicit")
		check(field.navigable_polygons.size()>0,id+" nonrectangular floor controls walking")
		check(world.field_physics.get_child_count()==field.blockers.size(),id+" every blocker becomes actual physics")
		check(world.field_minimap.field==field,id+" minimap shares actual obstacles")
		check(field.walkable(spawn) and field.point_clear(spawn),id+" entry remains clear")
		for point: Array in field.data.route_checks:
			var route: PackedVector2Array=field.path(spawn,vector(point))
			check(not route.is_empty(),id+" original hunting destination remains connected "+str(point))
			for i: int in range(1,route.size()): check(field.line_clear(route[i-1],route[i]),id+" safe route segment")
		for service: Dictionary in field.data.portal+field.data.npc_spawn:
			var p: Vector2=vector(service.position)
			check(field.walkable(p) and field.point_clear(p) and not field.path(spawn,p).is_empty(),id+" functional entrance/NPC "+str(service.id))
		for region: Dictionary in field.data.monster_spawn:
			check(not field.spawn_cells[str(region.id)].is_empty(),id+" connected spawn area "+str(region.id))
			if str(region.get("mode",""))=="dense":
				check(field.spawn_cells[str(region.id)].size()>=int(region.max_count),id+" dense spawn area retains full cap capacity")
			for i: int in range(8):
				var p: Vector2=field.sample_spawn(str(region.id),rng)
				check(p.is_finite() and field.walkable(p) and field.point_clear(p) and not field.is_safe(p),id+" spawn clear of new objects")
		var footprints: Dictionary={}
		for obstacle: Dictionary in field.data.collision:
			if obstacle.has("hunting_lane"): footprints[str(obstacle.id)]=obstacle
		var query := PhysicsPointQueryParameters2D.new()
		query.collision_mask=4
		for prop: Dictionary in field.data.props:
			if not prop.has("hunting_lane"): continue
			var p: Vector2=vector(prop.position)
			check(footprints.has(str(prop.id)) and vector(footprints[str(prop.id)].center)==p,id+" object and collision share footprint")
			check(not field.point_clear(p,0),id+" object blocks navigation")
			query.position=p
			check(not world.get_world_2d().direct_space_state.intersect_point(query).is_empty(),id+" object blocks actual physics")
		var selected: Dictionary={}
		var detours: int=0
		for probe: Dictionary in paths.get("detour_probes",[]):
			var a: Vector2=vector(probe.from)
			var b: Vector2=vector(probe.to)
			var route: PackedVector2Array=field.path(a,b)
			check(not field.line_clear(a,b),id+" hunting row blocks shortcut "+str(probe.lane))
			check(not route.is_empty(),id+" alternate entrance connects both sides "+str(probe.lane))
			var length: float=0
			var previous: Vector2=a
			for p: Vector2 in route:
				length+=previous.distance_to(p)
				check(field.line_clear(previous,p),id+" detour segment usable")
				previous=p
			if length>a.distance_to(b)*1.2:
				detours+=1
				if selected.is_empty() and field.point_clear(a,field.clearance) and field.point_clear(b,field.clearance): selected=probe
		check(detours>0,id+" objects force real detours, not just decoration")
		check(not selected.is_empty(),id+" valid body movement probe")
		var walked: float=0
		var frames: int=0
		var walk_trace: Array=[]
		if not selected.is_empty():
			var a: Vector2=vector(selected.from)
			var b: Vector2=vector(selected.to)
			world.player.global_position=a
			world.player.clear_click_path()
			world.player.set_physics_process(true)
			world.player.set_touch_vector(a.direction_to(b))
			Engine.time_scale=3.0
			for i: int in range(45): await physics_frame
			check((world.player.global_position-a).dot(a.direction_to(b))<a.distance_to(b)*.65,id+" direct manual movement cannot cross row")
			world.player.set_touch_vector(Vector2.ZERO)
			world.player.global_position=a
			world._set_click_destination(b)
			var previous: Vector2=a
			Engine.time_scale=6.0
			for i: int in range(420):
				await physics_frame
				frames+=1
				var p: Vector2=world.player.global_position
				walked+=previous.distance_to(p)
				previous=p
				if i%3==0: walk_trace.append([p.x,p.y])
				if i%15==0: check(field.point_clear(p,12),id+" physical detour stays outside objects")
				if p.distance_to(b)<12: break
			Engine.time_scale=1.0
			check(world.player.global_position.distance_to(b)<24,id+" real click movement reaches opposite side")
			check(walked>a.distance_to(b)*1.1,id+" actual body takes longer route")
			world.player.set_physics_process(false)
			world.player.clear_click_path()
		metrics.append({"map_id":id,"family":field.data.get("family","aden"),"lanes":paths.get("lanes",[]).size(),
			"physical_hunting_objects":footprints.size(),"verified_detours":detours,"actual_walk_distance":walked,
			"actual_walk_frames":frames,"actual_walk_trace":walk_trace,"movement_probe":selected,
			"elapsed_ms":Time.get_ticks_msec()-began,"navigation_cache":field.navigation_cache_hit})
		print("HUNTING_MAP_CHECKED ",id," detours=",detours," walked=",walked)
	var output: String="res://docs/hunting-paths-20261012/evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output+"/validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"maps":metrics,"checks":checks,"failures":failures,
		"original_coordinates_recovered":false,"physical_movement_maps":metrics.size()},"  "))
	file.close()
	world.queue_free()
	await process_frame
	print("HUNTING_PATHS_OK " if failures.is_empty() else "HUNTING_PATHS_FAILED ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
