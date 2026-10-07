extends SceneTree

const COORD = preload("res://scripts/maps/world_coordinates.gd")
var failures: Array[String] = []
var checks: int = 0
var world: TwilightWorld

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("REGION FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.save_timer = -10000
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string(world.FIELD_INDEX_PATH))
	var prefix: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="):
			prefix = argument.trim_prefix("--prefix=")
	check(world.maps.size()==25,"all original map IDs are preserved")
	var tested: int = 0
	var families: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	for entry: Dictionary in index:
		var id: String = str(entry["map_id"])
		if not id.begins_with(prefix):
			continue
		tested += 1
		world._set_map(id,false)
		world.field_population.set_process(false)
		for monster: TwilightMonster in world.monsters_root.get_children():
			monster.set_physics_process(false)
		await physics_frame
		await process_frame
		var field: PlayableField = world.field_map
		check(field != null and world.active_map_id==id,id+" loads as playable field")
		if field == null:
			continue
		var spawn: Vector2 = world.player.global_position
		check(field.bounds.size.x>=7168 and field.bounds.size.y>=6656,id+" expanded actual world bounds")
		check(field.walkable(spawn) and field.point_clear(spawn),id+" player spawn has clearance")
		check(field.is_safe(spawn),id+" entry is safe")
		check(world.player.collision_mask==4,id+" player physics mask")
		check(world.field_physics.get_child_count()==field.blockers.size(),id+" physics uses every authored blocker")
		check(world.player.camera.zoom==Vector2.ONE*.78,id+" gameplay camera scale")
		check(world.field_minimap.field==field and world.field_minimap.bounds==field.bounds,id+" minimap updates")
		check(world.field_renderer.chunks.size()<25 and world.field_renderer.visible_props<650,id+" scenery streaming bound")
		var cache: SubViewport = world.field_renderer.landmark_cache
		check(cache != null and cache.size.x*cache.size.y*4 <= 5*1024*1024,id+" active-map art cache stays within 5 MiB")
		var count: int = 0
		for region: Dictionary in field.data["monster_spawn"]:
			count += int(region["max_count"])
			check(not field.spawn_cells[str(region["id"])].is_empty(),id+" nonempty connected spawn area "+str(region["id"]))
			for i: int in range(8):
				var p: Vector2 = field.sample_spawn(str(region["id"]),rng)
				check(p.is_finite() and field.walkable(p) and field.point_clear(p) and not field.is_safe(p),id+" valid monster spawn")
		check(world.monsters_root.get_child_count()==count,id+" population matches region caps")
		for monster: TwilightMonster in world.monsters_root.get_children():
			var slot: Dictionary = world.field_population.slots[int(monster.get_meta("field_slot"))]
			var levels: Array = slot["region"]["level"]
			check(monster.monster_level>=int(levels[0]) and monster.monster_level<=int(levels[1]),id+" authored regional levels applied without DB mutation")
		for raw: Array in field.data["route_checks"]:
			var goal: Vector2 = COORD.array_vector(raw)
			var route: PackedVector2Array = field.path(spawn,goal)
			check(not route.is_empty(),id+" reach hunting room "+str(raw))
			for i: int in range(route.size()-1):
				check(field.line_clear(route[i],route[i+1]),id+" path respects walls and water")
		for portal: Dictionary in field.data["portal"]:
			var p: Vector2 = COORD.array_vector(portal["position"])
			check(field.walkable(p) and field.point_clear(p),id+" portal "+str(portal["id"])+" has clear visible footprint")
			check(not field.path(spawn,p).is_empty(),id+" portal accessible from entry")
			check(world.maps_by_id.has(str(portal["target_map"])),id+" portal target map exists")
		# Actual physics queries, not only AStar point flags.
		var query := PhysicsPointQueryParameters2D.new()
		query.position = spawn
		query.collision_mask = 4
		check(world.get_world_2d().direct_space_state.intersect_point(query).is_empty(),id+" physics spawn unblocked")
		for shape: Dictionary in field.blockers.slice(0,5):
			query.position = (shape["box"] as Rect2).get_center()
			if str(shape["shape"]) != "polygon":
				check(not world.get_world_2d().direct_space_state.intersect_point(query).is_empty(),id+" visible blocker exists in physics")
		for zoom: float in [.65,1.1]:
			world.player.camera.zoom = Vector2.ONE*zoom
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			await process_frame
			var goal: Vector2 = spawn+Vector2(96,0)
			var screen: Vector2 = COORD.world_to_screen(root,goal)
			check(COORD.screen_to_world(root,screen).distance_to(goal)<.02,id+" camera/world coordinate round trip")
			var touch := InputEventScreenTouch.new()
			touch.position = screen
			touch.pressed = true
			world._unhandled_input(touch)
			check(not world.player.click_path.is_empty() and world.player.click_path[-1].distance_to(goal)<1,id+" zoomed Android touch destination")
			world.player.clear_click_path()
		world.player.camera.zoom=Vector2.ONE*.78
		check(COORD.minimap_to_world(COORD.world_to_minimap(spawn,field.bounds,world.field_minimap.area),field.bounds,world.field_minimap.area).distance_to(spawn)<.01,id+" minimap round trip")
		check(world.use_field_portal("advance_waystone"),id+" intra-map teleport accepted")
		check(world.field_map==field and world.monsters_root.get_child_count()==count,id+" local teleport preserves map/population")
		check(field.walkable(world.player.global_position) and field.point_clear(world.player.global_position),id+" local teleport clear landing")
		check(world.use_field_portal("entry_waystone"),id+" local teleport returns to entry")
		world._set_click_destination(spawn+Vector2(96,0))
		for i: int in range(48):
			await physics_frame
		check(world.player.global_position.distance_to(spawn+Vector2(96,0))<10,id+" actual click movement")
		world.player.set_touch_vector(Vector2.RIGHT)
		for i: int in range(12):
			await physics_frame
		world.player.set_touch_vector(Vector2.ZERO)
		check(world.player.global_position.x>spawn.x+100,id+" actual joystick movement")
		world._save_game(true)
		var saved: Vector2 = world.player.global_position
		var saved_gold: int = world.gold
		world.player.global_position=spawn
		world._load_game(true)
		check(world.active_map_id==id and world.player.global_position.distance_to(saved)<1 and world.gold==saved_gold,id+" saved position/progression round trip")
		world.field_population.set_process(false)
		for monster: TwilightMonster in world.monsters_root.get_children():
			monster.set_physics_process(false)
		# Ensure every family can still move, attack, award XP and drop via real callbacks.
		var family: String = str(entry["family"])
		if not families.has(family):
			families[family]=true
			world._clear_monsters()
			var start: Vector2 = COORD.array_vector(world.field_map.data["route_checks"][0])
			var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
			world.monsters_root.add_child(monster)
			monster.global_position=start+Vector2(260,0)
			monster.setup({"name":"지역 전투 검사","lv":1,"hp":30,"atk":1},world.player,world,null)
			monster.collision_mask=4
			monster.set_physics_process(false)
			monster.died.connect(world._on_monster_died)
			world.player.global_position=start
			world.player.clear_click_path()
			world.player.set_auto_enabled(true)
			var xp: int = world.experience
			for i: int in range(300):
				await physics_frame
				if not is_instance_valid(monster):
					break
			check(world.player.global_position.x>start.x+80,family+" auto hunt approaches target")
			check(world.experience>xp,family+" existing combat/experience callback")
			world.player.set_auto_enabled(false)
		# Upgrade old overview saves safely: progression stays, obsolete position migrates.
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.SAVE_PATH))
		old.erase("map_layout_revision")
		old["position"]=[100,100]
		var file: FileAccess = FileAccess.open(world.SAVE_PATH,FileAccess.WRITE)
		file.store_string(JSON.stringify(old))
		file.close()
		world._load_game(true)
		check(world.active_map_id==id and world.player.global_position.distance_to(world._spawn_position())<1,id+" obsolete map position migrates to safe entry")
		var old_cache: WeakRef = weakref(world.field_renderer.landmark_cache)
		check(world.use_field_portal("aden_return") and world.active_map_id=="aden_world",id+" real intermap return portal")
		await process_frame
		check(old_cache.get_ref()==null,id+" leaving region releases its render cache")
		check(world.field_map != null and world.field_minimap.field==world.field_map,id+" world services refresh after portal")
		print("REGION CHECKED ",id)
	if prefix.is_empty():
		check(tested==24 and families.size()==5,"all 24 new maps and all five families tested")
	print("REGION maps=",tested," checks=",checks," families=",families.size())
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("WORLD_REGIONS_OK")
		quit(0)
	else:
		print("WORLD_REGIONS_FAILED: ",failures.size())
		quit(1)
