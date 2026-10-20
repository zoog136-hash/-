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

func combat_start(field: PlayableField, random: RandomNumberGenerator) -> Vector2:
	# Scenery now occupies some former hard-coded combat offsets. Both actors
	# must start on usable terrain; retain the real movement/kill/XP assertions.
	var candidates: Array[Vector2] = []
	for raw: Array in field.data.route_checks: candidates.append(COORD.array_vector(raw))
	for region: Dictionary in field.data.monster_spawn:
		for i: int in range(16): candidates.append(field.sample_spawn(str(region.id),random))
	for start: Vector2 in candidates:
		var target: Vector2 = start+Vector2(260,0)
		if start.is_finite() and field.walkable(start) and field.walkable(target) and field.point_clear(start,field.clearance) and field.point_clear(target,field.clearance) and field.line_clear(start,target):
			return start
	return Vector2.INF

func check_population_levels(id: String, field: PlayableField, catalog: Dictionary) -> void:
	for monster: TwilightMonster in world.monsters_root.get_children():
		var slot: Dictionary = world.field_population.slots[int(monster.get_meta("field_slot"))]
		var region: Dictionary = slot.region
		var variants: Dictionary = region.get("variants", {})
		var source_name: String = monster.monster_name
		for name: String in region.monster_types:
			if str(variants.get(name, {}).get("name", name)) == monster.monster_name:
				source_name = name
				break
		check(region.monster_types.has(source_name) and catalog.has(source_name), id+" actor belongs to its current regional roster: "+source_name)
		if not catalog.has(source_name): continue
		var record: Dictionary = catalog[source_name]
		var variant: Dictionary = variants.get(source_name, {})
		var expected: int = maxi(1, int(variant.get("level", record.get("lv", record.get("level", 1)))))
		check(monster.monster_level == expected, id+" actor uses its authored variant or catalog level: "+source_name)
		# The renewed layout changes rosters without changing creature stats. Its
		# old broad level range describes the historical roster, not new members.
		# Explicit authored variants still have to satisfy their regional range.
		if variant.has("level") or not field.data.has("spawn_layout_revision"):
			var levels: Array = region["level"]
			check(monster.monster_level>=int(levels[0]) and monster.monster_level<=int(levels[1]), id+" authored regional levels applied without DB mutation")

func check_authored_variant(entry: Dictionary, catalog: Dictionary) -> bool:
	# Keep exercising the original per-region override through real population
	# spawning, even when current production rosters no longer use variants.
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(entry.path)))
	for region: Dictionary in definition.monster_spawn:
		var variants: Dictionary = region.get("variants", {})
		for name: String in region.monster_types:
			var variant: Dictionary = variants.get(name, {})
			if not variant.has("level") or not catalog.has(name): continue
			var probe_region: Dictionary = region.duplicate(true)
			probe_region["monster_types"] = [name]
			probe_region.erase("weights")
			var probe: Dictionary = {"region":probe_region, "index":0, "slot_id":world.field_population.slots.size(), "monster":null, "remaining":0.0}
			world.field_population._spawn_slot(probe)
			check(is_instance_valid(probe.monster), str(entry.map_id)+" original authored variant spawns through real population")
			if is_instance_valid(probe.monster):
				var monster: TwilightMonster = probe.monster
				monster.set_physics_process(false)
				var levels: Array = region.level
				check(monster.monster_level == int(variant.level) and monster.monster_level>=int(levels[0]) and monster.monster_level<=int(levels[1]), str(entry.map_id)+" original authored variant level and regional range remain exact")
				monster.queue_free()
				await process_frame
			return true
	return false

func _run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.save_timer = -10000
	var database_before: Array = world.monster_db.duplicate(true)
	var catalog_before: Dictionary = {}
	for record: Dictionary in database_before: catalog_before[str(record.name)] = record
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string(world.FIELD_INDEX_PATH))
	var prefix: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="):
			prefix = argument.trim_prefix("--prefix=")
	for assertion: Dictionary in preload("res://tests/map_catalog_assertions.gd").checks(world):
		check(bool(assertion.ok),str(assertion.label))
	var tested: int = 0
	var authored_variant_probes: int = 0
	var families: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	for entry: Dictionary in index:
		var id: String = str(entry["map_id"])
		if not id.begins_with(prefix):
			continue
		tested += 1
		var started_ms: int = Time.get_ticks_msec()
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
		check(field.bounds.size==Vector2(entry.bounds[2],entry.bounds[3]),id+" actual world bounds match registered map")
		check(field.walkable(spawn) and field.point_clear(spawn),id+" player spawn has clearance")
		check(field.is_safe(spawn),id+" entry is safe")
		check(world.player.collision_mask==4,id+" player physics mask")
		check(preload("res://tests/streamed_field_physics.gd").intact(world),id+" exact authored collision footprints and all required streamed buckets")
		check(world.player.camera.zoom==Vector2.ONE*.78,id+" gameplay camera scale")
		check(world.field_minimap.field==field and world.field_minimap.bounds==field.bounds,id+" minimap updates")
		check(world.field_renderer.chunks.size()<25 and world.field_renderer.visible_props<650,id+" scenery streaming bound")
		var cache: SubViewport = world.field_renderer.landmark_cache
		check(cache != null and cache.size.x*cache.size.y*4 <= 5*1024*1024,id+" active-map art cache stays within 5 MiB")
		var count: int = 0
		var eager_count: int = 0
		for region: Dictionary in field.data["monster_spawn"]:
			count += int(region["max_count"])
			if str(region.get("mode","normal"))!="dense": eager_count += int(region["max_count"])
			check(not field.spawn_cells[str(region["id"])].is_empty(),id+" nonempty connected spawn area "+str(region["id"]))
			for i: int in range(8):
				var p: Vector2 = field.sample_spawn(str(region["id"]),rng)
				check(p.is_finite() and field.walkable(p) and field.point_clear(p) and not field.is_safe(p),id+" valid monster spawn")
		check(world.monsters_root.get_child_count()==eager_count and world.field_population.slots.size()==count,id+" ordinary population fills caps; distant dense slots stay dormant")
		check_population_levels(id,field,catalog_before)
		check(world.monster_db == database_before,id+" spawning preserves the entire monster database")
		print("REGION TIMING ",id," before_routes_ms=",Time.get_ticks_msec()-started_ms)
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
		# Visit the same physical probe points through the real stream. Far
		# buckets are intentionally absent until an actor is near them.
		var collision_probe_origin: Vector2 = world.player.global_position
		var collision_probe_physics: bool = world.player.is_physics_processing()
		world.player.set_physics_process(false)
		for shape: Dictionary in field.blockers.slice(0,5):
			query.position = (shape["box"] as Rect2).get_center()
			if str(shape["shape"]) != "polygon":
				if field is AuthoredRemakeField:
					world.player.global_position = query.position
					field.collision_stream.refresh()
					await physics_frame
					await process_frame
					check(preload("res://tests/streamed_field_physics.gd").intact(world),id+" probe retains exact physical shapes and complete active coverage")
				check(not world.get_world_2d().direct_space_state.intersect_point(query).is_empty(),id+" visible blocker exists in physics")
		world.player.global_position = collision_probe_origin
		if field is AuthoredRemakeField:
			field.collision_stream.refresh()
			await physics_frame
			await process_frame
		world.player.set_physics_process(collision_probe_physics)
		for zoom: float in [.65,1.1]:
			world.player.camera.zoom = Vector2.ONE*zoom
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			await process_frame
			var goal: Vector2 = spawn+Vector2(96,0)
			var screen: Vector2 = COORD.world_to_screen(root,goal)
			check(COORD.screen_to_world(root,screen).distance_to(goal)<.02,id+" camera/world coordinate round trip")
			# Native gesture dispatch waits for touch release before moving.
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = screen
			touch.pressed = true
			world._unhandled_input(touch)
			var release := InputEventScreenTouch.new()
			release.index = 0
			release.position = screen
			release.pressed = false
			world.world_interactions._input(release)
			check(world.world_interactions.pointer == -2,id+" touch gesture released")
			check(not world.player.click_path.is_empty() and world.player.click_path[-1].distance_to(goal)<1,id+" zoomed Android touch destination")
			world.player.clear_click_path()
		world.player.camera.zoom=Vector2.ONE*.78
		check(COORD.minimap_to_world(COORD.world_to_minimap(spawn,field.bounds,world.field_minimap.area),field.bounds,world.field_minimap.area).distance_to(spawn)<.01,id+" minimap round trip")
		check(world.use_field_portal("advance_waystone"),id+" intra-map teleport accepted")
		check(world.field_map==field and world.monsters_root.get_child_count()==eager_count,id+" local teleport preserves map/population")
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
		print("REGION TIMING ",id," before_save_ms=",Time.get_ticks_msec()-started_ms)
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
			var start: Vector2 = combat_start(field,rng)
			check(start.is_finite(),family+" combat actors have a connected clear lane")
			if not start.is_finite(): continue
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
		world.field_population.set_process(false)
		if await check_authored_variant(entry,catalog_before): authored_variant_probes += 1
		check(world.monster_db == database_before,id+" combat, reload and authored overrides preserve the entire monster database")
		var old_cache: WeakRef = weakref(world.field_renderer.landmark_cache)
		check(world.use_field_portal("aden_return") and world.active_map_id=="aden_world",id+" real intermap return portal")
		await process_frame
		check(old_cache.get_ref()==null,id+" leaving region releases its render cache")
		check(world.field_map != null and world.field_minimap.field==world.field_map,id+" world services refresh after portal")
		print("REGION TIMING ",id," full_ms=",Time.get_ticks_msec()-started_ms)
		print("REGION CHECKED ",id)
	if prefix.is_empty():
		check(tested==24 and families.size()==5,"all 24 new maps and all five families tested")
		check(authored_variant_probes==23,"all 23 maps with original authored level variants exercise real population overrides")
	print("REGION maps=",tested," checks=",checks," families=",families.size()," authored_variant_probes=",authored_variant_probes)
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("WORLD_REGIONS_OK")
		quit(0)
	else:
		print("WORLD_REGIONS_FAILED: ",failures.size())
		quit(1)
