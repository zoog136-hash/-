extends SceneTree
## Gameplay checks for the placed art, rather than sprite-count completion.
var failures: Array[String] = []
var checks: int = 0
var metrics: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("OBJECT_PLACEMENT_FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -10000
	world.player.set_auto_enabled(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 111084
	for id: String in ["aden_world","oman_01"]:
		world._set_map(id,false)
		world.portal_cooldown = 10000
		world.field_population.set_process(false)
		world.player.set_physics_process(false)
		for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
		await physics_frame
		var field: PlayableField = world.field_map
		var origin: Vector2 = world.player.global_position
		var access_checks: int = 0
		var footprints: Dictionary = {}
		for c: Dictionary in field.data.collision:
			if c.has("placement_id"): footprints[str(c.placement_id)] = c
		for r: Dictionary in field.data.props:
			if not r.has("placement_id"): continue
			var position := Vector2(r.position[0],r.position[1])
			check(field.inside_navigable_area(position),id+" object on land/floor "+str(r.placement_id))
			if r.has("access_point"):
				var entrance := Vector2(r.access_point[0],r.access_point[1])
				check(field.point_clear(entrance,field.clearance) and field.walkable(entrance),id+" building entrance clear "+str(r.placement_id))
				check(not field.path(origin,entrance).is_empty(),id+" building entrance connected "+str(r.placement_id))
				access_checks += 1
			if footprints.has(str(r.placement_id)):
				var c: Dictionary = footprints[str(r.placement_id)]
				var point: Vector2
				if str(c.shape)=="circle": point = Vector2(c.center[0],c.center[1])
				else: point = Vector2(c.rect[0]+c.rect[2]*.5,c.rect[1]+c.rect[3]*.5)
				check(not field.point_clear(point,0),id+" visible obstacle blocks navigation "+str(r.placement_id))
				# The real physics body must cover the same footprint as AStar.
				var query := PhysicsPointQueryParameters2D.new()
				query.position = point
				query.collision_mask = 4
				check(not world.get_world_2d().direct_space_state.intersect_point(query).is_empty(),id+" matching physical obstacle "+str(r.placement_id))
		for npc: Dictionary in field.data.npc_spawn:
			var point := Vector2(npc.position[0],npc.position[1])
			check(field.point_clear(point) and field.walkable(point),id+" service NPC accessible "+str(npc.id))
			check(not field.path(origin,point).is_empty(),id+" service NPC route "+str(npc.id))
		for portal: Dictionary in field.data.portal:
			var point := Vector2(portal.position[0],portal.position[1])
			check(field.point_clear(point) and not field.path(origin,point).is_empty(),id+" portal remains usable "+str(portal.id))
		for region: Dictionary in field.data.monster_spawn:
			for i: int in range(10):
				var point: Vector2 = field.sample_spawn(str(region.id),rng)
				check(point.is_finite() and field.walkable(point) and field.point_clear(point) and not field.is_safe(point),id+" spawn avoids placed objects "+str(region.id))
		world.player.global_position = origin
		world.field_renderer.refresh_visible()
		var peak: int = 0
		for entry: Array in field.data.route_checks:
			world.player.global_position = Vector2(entry[0],entry[1])
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			peak = maxi(peak,world.field_renderer.visible_props)
			check(world.field_renderer.chunks.size()<=49,id+" streaming stays local")
		check(access_checks>=60 if id=="aden_world" else footprints.size()>100,id+" substantial playable object placement")
		metrics.append({"map_id":id,"building_access_checks":access_checks,"physical_obstacles":footprints.size(),
			"peak_active_props_at_routes":peak,"new_art_files":0})
	var output: String = "res://docs/object-placement-20261011/evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output+"/validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"maps":metrics},"  "))
	file.close()
	world.queue_free()
	await process_frame
	print("REFERENCE_OBJECT_PLACEMENT_OK " if failures.is_empty() else "REFERENCE_OBJECT_PLACEMENT_FAILED ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
