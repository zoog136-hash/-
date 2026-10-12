extends SceneTree
const GEOMETRY = preload("res://scripts/maps/map_region_geometry.gd")
var failures: Array[String] = []
var checks: int = 0
var metrics: Array[Dictionary] = []
var before_metrics: Array[Dictionary] = []
var world: TwilightWorld

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("WORLD_STRUCTURE_FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for filename: String in ["pr84_aden_layout1.json","pr84_oman_layout2.json"]:
		var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+filename))
		var field: PlayableField = preload("res://scripts/maps/playable_field.gd").new()
		field.configure(definition)
		var count: int = 0
		for value: int in field.reachable: count+=1 if value!=0 else 0
		before_metrics.append({"map_id":definition.map_id,"bounds":definition.bounds,"reachable_cells":count,
			"reachable_area_world_pixels":count*field.cell_size*field.cell_size})
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.save_timer = -10000
	world.max_hp = 1000000
	world.hp = 1000000
	world.player.set_auto_enabled(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 841101
	for id: String in ["aden_world","oman_01"]:
		var began: int = Time.get_ticks_msec()
		world._set_map(id,false)
		world.portal_cooldown = 10000
		world.field_population.set_process(false)
		for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
		await physics_frame
		var field: PlayableField = world.field_map
		var spawn: Vector2 = world.player.global_position
		check(field.data.layout_revision==3,id+" new layout active in real game")
		check(field.navigable_polygons.size()>0,id+" whole-map contour controls navigation")
		check(world.field_renderer.terrain_root.get_node_or_null("Ground/ReferenceGeography")!=null,id+" geometry renderer active")
		check(field.walkable(spawn) and field.point_clear(spawn),id+" clear entry")
		check(not field.walkable(Vector2(20,field.bounds.end.y-20)),id+" ocean/void inaccessible")
		check(world.field_minimap.bounds==field.bounds,id+" minimap shares actual extent")
		for ref: Vector2 in [Vector2(150,130),Vector2(290,165),Vector2(450,230)]:
			check(GEOMETRY.world_to_reference(GEOMETRY.reference_to_world(ref,field.data),field.data).distance_to(ref)<.01,id+" reference coordinate round trip")
		for point: Array in field.data.route_checks:
			var p := Vector2(point[0],point[1])
			check(field.walkable(p),id+" reference destination walkable "+str(point))
			var path: PackedVector2Array = field.path(spawn,p)
			check(not path.is_empty(),id+" connected long route "+str(point))
			for i: int in range(1,path.size()): check(field.line_clear(path[i-1],path[i]),id+" route respects contour and blockers")
		for portal: Dictionary in field.data.portal:
			var p := Vector2(portal.position[0],portal.position[1])
			check(field.walkable(p) and field.point_clear(p),id+" portal footprint "+str(portal.id))
			check(not field.path(spawn,p).is_empty(),id+" reachable portal "+str(portal.id))
		for region: Dictionary in field.data.monster_spawn:
			check(not field.spawn_cells[str(region.id)].is_empty(),id+" spawn sector connected "+str(region.id))
			for i: int in range(24):
				var p: Vector2 = field.sample_spawn(str(region.id),rng)
				check(p.is_finite() and field.spawn_contains(region,p) and field.walkable(p) and field.point_clear(p) and not field.is_safe(p),id+" polygon spawn validity "+str(region.id))
			if str(region.get("mode",""))=="boss":
				check(region.map_id==id and region.has("patrol_region") and region.has("verification_status"),id+" boss schema linked")
				check(region.verification_status.exact_spawn_area=="unverified",id+" unknown original boss coordinates remain explicit")
		var reachable_count: int = 0
		for b: int in field.reachable: reachable_count += 1 if b!=0 else 0
		metrics.append({"map_id":id,"bounds":field.data.bounds,"reachable_cells":reachable_count,
			"reachable_area_world_pixels":reachable_count*field.cell_size*field.cell_size,
			"load_ms":Time.get_ticks_msec()-began,"source_server_map_id":field.data.structure_reference.source_server_map_id,
			"absolute_scale_status":field.data.structure_reference.absolute_scale_status})
		# Real CharacterBody2D motion, not merely an AStar result.
		var destination: Vector2 = spawn+Vector2(128,0)
		world._set_click_destination(destination)
		for i: int in range(80): await physics_frame
		check(world.player.global_position.distance_to(destination)<16,id+" actual click movement")
		# Walk between geographically separated places using the real body/path.
		# Accelerate game time; do not teleport or replace collision queries.
		var far: Array = field.data.route_checks[2 if id=="aden_world" else 4]
		var goal := Vector2(far[0],far[1])
		world._set_click_destination(goal)
		var walked: float = 0.0
		var previous: Vector2 = world.player.global_position
		var frames: int = 0
		Engine.time_scale = 10.0
		for i: int in range(2500):
			await physics_frame
			frames+=1
			walked+=previous.distance_to(world.player.global_position)
			previous=world.player.global_position
			if i%60==0: check(field.walkable(previous) and field.point_clear(previous,12),id+" long walk stays on usable terrain")
			if previous.distance_to(goal)<32: break
		Engine.time_scale = 1.0
		check(previous.distance_to(goal)<64,id+" actual long-distance arrival")
		check(walked>10000 if id=="aden_world" else walked>4500,id+" meaningful exploration distance")
		metrics[-1]["actual_walk_distance_pixels"]=walked
		metrics[-1]["physics_frames"]=frames
		metrics[-1]["walk_game_time_scale"]=10
		world._save_game(true)
		var saved: Vector2 = world.player.global_position
		world._load_game(true)
		check(world.active_map_id==id and world.player.global_position.distance_to(saved)<1,id+" layout save round trip")
	world._set_map("oman_01",false)
	world.field_population.set_process(false)
	var query := PhysicsPointQueryParameters2D.new()
	query.position = GEOMETRY.reference_to_world(Vector2(128,157),world.field_map.data)
	query.collision_mask = 4
	await physics_frame
	check(not world.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"Oman reference pit has physical collision")
	var bosses: Array = world.monsters_root.get_children().filter(func(m: Node)->bool:return m.is_boss)
	check(bosses.size()==1 and bosses[0].monster_name=="왜곡의 제니스 퀸","correct Oman 1F boss actor and one live instance")
	if not bosses.is_empty():
		check(not world.field_population.destination_allowed(bosses[0],Vector2(-100,-100)),"boss patrol cannot escape contour")
	check(world.use_field_portal("next") and world.active_map_id=="oman_02","Oman next-floor connection")
	check(world.use_field_portal("previous") and world.active_map_id=="oman_01","Oman return-floor connection")
	check(world.use_field_portal("previous") and world.active_map_id=="aden_world","tower physical exit returns to approach")
	check(world.field_map.walkable(world.player.global_position),"Aden gate landing walkable")
	check(world.use_field_portal("oman_gate") and world.active_map_id=="oman_01","Aden approach enters reconstructed whole floor")
	var output: String = "res://docs/world-structure-20261011/evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output+"/validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"metrics":metrics,"before_metrics":before_metrics},"  "))
	file.close()
	world.queue_free()
	await process_frame
	print("WORLD_STRUCTURE_OK " if failures.is_empty() else "WORLD_STRUCTURE_FAILED ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
