extends SceneTree
## Real Main, isolated saves, existing production services and source physics.
## --capture requires a rendering display. No reference image enters the game.
const REGISTRY = preload("res://scripts/maps/aden_remake_registry.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const COORD = preload("res://scripts/maps/world_coordinates.gd")
var world: TwilightWorld
var failures: Array[String] = []
var checks: int = 0
var output: String = "user://giran-review"
var capture: bool = false
var screenshots: Array[Dictionary] = []
var movement: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("GIRAN_FAIL ",message)

func frames(count: int = 4) -> void:
	for frame: int in range(count): await process_frame

func place(cell: Vector2i) -> void:
	var field: RemakePlayableField = world.field_map
	var candidate: Vector2i = field.nearest_cell(field.cell_to_world(cell))
	world.player.global_position = field.cell_to_world(candidate)
	world.player.velocity = Vector2.ZERO
	world.player.clear_click_path()
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	field.collision_stream.refresh()
	world.field_renderer.refresh_visible()

func picture(name: String, cell: Vector2i, zoom_value: float = 1.0) -> void:
	place(cell)
	world.hud._close_workspace()
	world.player.camera.zoom = Vector2.ONE*zoom_value
	world.player.camera.force_update_scroll()
	await frames(6)
	if not capture: return
	if DisplayServer.get_name() == "headless":
		check(false,"capture requires real graphics display")
		return
	await RenderingServer.frame_post_draw
	var path: String = output+"/"+name+".png"
	check(root.get_texture().get_image().save_png(path) == OK,"PNG "+name)
	screenshots.append({"file":name+".png","source_cell":[cell.x,cell.y],
		"actual_position":[world.player.global_position.x,world.player.global_position.y],
		"viewport":[root.size.x,root.size.y],"zoom":zoom_value,
		"camera_offset":[world.player.camera.position.x,world.player.camera.position.y],
		"engine":Engine.get_version_info().string,"display":DisplayServer.get_name()})

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--capture": capture = true
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY.ROOT+"definitions/aden_world.json"))
	check(REGISTRY.valid_definition(definition),"real JSON coordinates accepted without changing immutable pack")
	for mutation: String in ["fractional_origin","wrong_dimensions","fractional_basis","wrong_hash"]:
		var invalid: Dictionary = definition.duplicate(true)
		match mutation:
			"fractional_origin": invalid.origin[0] += .25
			"wrong_dimensions": invalid.dimensions[1] -= 1
			"fractional_basis": invalid.coordinate_mapping.basis_x[0] += .25
			"wrong_hash": invalid.source_sha256 = "0".repeat(64)
		check(not REGISTRY.valid_definition(invalid),"reject "+mutation)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world),"actual character confirmation")
	world.save_timer = -100000
	world.set_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	if not world.field_map is RemakePlayableField:
		check(false,"production Main loaded source Aden field")
		finish(); return
	var field: RemakePlayableField = world.field_map
	check(field.width == 2048 and field.height == 1536 and field.chunk_table.size() == 768,"full original grid retained")
	check(world.use_field_portal("town_waystone"),"existing Gludin to Giran portal")
	check(field.world_to_cell(world.player.global_position).distance_to(Vector2i(981,750)) < 4,"existing portal Giran landing")
	await picture("giran-plaza-play",Vector2i(981,740))
	var review_chunks: int = 0
	for node: Node in world.field_renderer.chunks.values():
		if bool(node.get_meta("giran_review",false)): review_chunks += 1
	check(review_chunks > 0,"production renderer uses separate Giran visual chunks")
	check(world.field_physics == field.collision_stream,"existing common source collision stream retained")
	await picture("giran-buildings-play",Vector2i(979,733),.85)
	await picture("giran-north-gate-play",Vector2i(1015,722),.85)
	await picture("giran-south-field-play",Vector2i(983,828),.85)

	# Physical pushing into the central source monument, not merely a mask test.
	var wall_start := Vector2i(-1,-1)
	var wall_target := Vector2i(-1,-1)
	for y: int in range(744,752):
		for x: int in range(978,986):
			var cell := Vector2i(x,y)
			if not field.point_clear(field.cell_to_world(cell)): continue
			for heading: int in [0,2,4,6]:
				var next: Vector2i = cell+field.DIRECTIONS[heading]
				if field.value_at(next,true) == 0 and not field.can_step(cell,heading):
					wall_start = cell; wall_target = next; break
			if wall_start.x >= 0: break
		if wall_start.x >= 0: break
	check(wall_start.x >= 0,"source monument has a testable blocked edge")
	if wall_start.x >= 0:
		place(wall_start)
		# Stream replacement queues old shapes for deletion. Let the physics
		# server synchronize before querying its newly installed shape batch.
		for frame: int in range(3): await physics_frame
		var start: Vector2 = world.player.global_position
		var target: Vector2 = field.cell_to_world(wall_target)
		var direction: Vector2 = (target-start).normalized()
		var ray := PhysicsRayQueryParameters2D.create(start,target,4)
		check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"physics ray hits exact source boundary")
		world.player.set_touch_vector(direction)
		var traversed_only_open: bool = true
		for frame: int in range(32):
			await physics_frame
			traversed_only_open = traversed_only_open and field.walkable(world.player.global_position)
		world.player.set_touch_vector(Vector2.ZERO)
		movement["wall_push"] = {"from":[start.x,start.y],"to":[world.player.global_position.x,world.player.global_position.y],"blocked_cell":[wall_target.x,wall_target.y],"physics_ticks":32}
		check(field.world_to_cell(world.player.global_position) != wall_target and field.walkable(world.player.global_position),"real character cannot enter source monument")
		# Tangential sliding around a finite wall can travel farther than the
		# blocked center's projection. Check every actual traversed cell instead.
		check(traversed_only_open,"every physics tick remains on open source cells while pushing")
	place(Vector2i(981,740))
	var start: Vector2 = world.player.global_position
	var destination: Vector2 = start
	for heading: int in [0,2,4,6]:
		var candidate: Vector2 = field.cell_to_world(field.world_to_cell(start)+field.DIRECTIONS[heading]*6)
		if field.line_clear(start,candidate): destination = candidate; break
	check(destination != start,"plaza has a source walking corridor")
	world.player.set_touch_vector((destination-start).normalized())
	for frame: int in range(20): await physics_frame
	world.player.set_touch_vector(Vector2.ZERO)
	check(world.player.global_position.distance_to(start)>12 and field.point_clear(world.player.global_position),"production player moves across plaza")
	movement["plaza_distance"] = world.player.global_position.distance_to(start)

	# Desktop injection of Android-shaped events; this is NOT Android device QA.
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size
		place(Vector2i(981,740))
		await frames()
		var target: Vector2 = field.cell_to_world(Vector2i(982,740))
		var screen: Vector2 = COORD.world_to_screen(root,target)
		var down := InputEventScreenTouch.new()
		down.index = 0; down.position = screen; down.pressed = true
		world._unhandled_input(down)
		var up := InputEventScreenTouch.new()
		up.index = 0; up.position = screen; up.pressed = false
		world.world_interactions._input(up)
		check(not world.player.click_path.is_empty(),"touch path at "+str(size))
		world.player.clear_click_path()
	root.size = Vector2i(1280,720)

	for npc: Dictionary in field.data.npc_spawn:
		if not str(npc.id).begins_with("giran_"): continue
		var point := Vector2(npc.position[0],npc.position[1])
		world.player.global_position = point
		world._set_click_destination(point)
		var expected: String = {"shop":"npc_shop","warehouse":"warehouse","teleport":"teleport"}[str(npc.role)]
		check(world.hud.workspace.visible and world.hud.active_section == expected,"existing NPC UI "+str(npc.id))
		if str(npc.role) == "shop":
			world.gold = 100000
			var before: int = int(world.inventory.get("HP 물약",0))
			var price: int = world.SHOP_CATALOG.price_for("HP 물약")
			world._buy_shop_bulk("HP 물약",1)
			check(int(world.inventory.get("HP 물약",0)) == before+1 and world.gold == 100000-price,"actual Giran shop transaction")
		if str(npc.role) == "warehouse":
			var before: int = int(world.inventory.get("HP 물약",0))
			world._warehouse_transfer("HP 물약",1,"deposit","")
			check(int(world.inventory.get("HP 물약",0)) == before-1,"actual Giran warehouse deposit")
			world._warehouse_transfer("HP 물약",1,"withdraw","")
			check(int(world.inventory.get("HP 물약",0)) == before,"actual Giran warehouse withdrawal")
		world.hud._close_workspace()
	check(world.use_field_portal("ruin_waystone"),"existing Giran return portal")
	check(field.world_to_cell(world.player.global_position).x < 300,"return portal lands in original western town")
	check(world.use_field_portal("town_waystone"),"Giran portal round trip")
	place(Vector2i(981,740))
	var saved: Vector2 = world.player.global_position
	world._save_game(true)
	world.player.global_position += Vector2(100,0)
	world._load_game(true)
	check(world.field_map is RemakePlayableField and world.player.global_position.distance_to(saved)<.1,"actual source-coordinate save/reload")
	field = world.field_map
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)

	# Existing A3-adapted monster/boss systems, exercised without adding graphics
	# or changing rosters outside Giran. Timers are advanced in this isolated QA.
	var normal: Dictionary = {}
	var boss_slot: Dictionary = {}
	for slot: Dictionary in world.field_population.slots:
		if not is_instance_valid(slot.monster): continue
		if str(slot.region.get("mode","")) == "boss" and boss_slot.is_empty(): boss_slot = slot
		elif str(slot.region.get("mode","")) != "boss" and normal.is_empty(): normal = slot
	check(not normal.is_empty() and not boss_slot.is_empty(),"existing live monster and boss slots")
	if not normal.is_empty():
		var monster: TwilightMonster = normal.monster
		var before_inventory: Dictionary = world.inventory.duplicate(true)
		monster.take_damage(99999999)
		check(monster.dead and float(normal.remaining)>0 and world.inventory==before_inventory,"monster death uses cooldown and ground-drop path")
		world.field_population._process(float(normal.remaining)+.1)
		check(is_instance_valid(normal.monster) and not normal.monster.dead,"existing monster respawn after advanced timer")
	if not boss_slot.is_empty():
		var boss: TwilightMonster = boss_slot.monster
		var hp: int = boss.hp
		boss.take_damage(5)
		check(boss.hp < hp,"production boss damage callback")
		boss.take_damage(99999999)
		var director: TwilightBossDirector = world.field_population.boss_director
		var state: Dictionary = director.state_for("aden_world",boss_slot.region)
		check(str(state.phase)=="cooldown" and float(state.ready_at)>Time.get_unix_time_from_system(),"boss death records future wall-clock cooldown")
		world.field_population._spawn_slot(boss_slot)
		check(not is_instance_valid(boss_slot.monster) or boss_slot.monster.dead,"boss cannot respawn before deadline")
		state.ready_at = Time.get_unix_time_from_system()-1
		boss_slot.remaining = 0.0
		world.field_population._spawn_slot(boss_slot)
		check(is_instance_valid(boss_slot.monster) and not boss_slot.monster.dead,"boss respawns after simulated deadline")
		world.field_population._spawn_slot(boss_slot)
		var alive: int = 0
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.id)==str(boss_slot.region.id) and is_instance_valid(slot.monster) and not slot.monster.dead: alive += 1
		check(alive==1,"one living boss in existing region")
	await picture("giran-collision",Vector2i(981,740))
	world.field_renderer.set_visual_mode("collision")
	await picture("giran-source-collision",Vector2i(981,740))
	world.field_renderer.set_visual_mode("reference")
	await picture("giran-final-play",Vector2i(981,740))
	check(field.nav_cache.size()<=field.CACHE_LIMIT and world.field_renderer.chunks.size()<=49,"bounded common navigation and graphics streams")
	finish()

func finish() -> void:
	var report: Dictionary = {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,
		"failures":failures,"screenshots":screenshots,"movement":movement,
		"android_device":"NOT_RUN","android_gpu_performance":"NOT_RUN",
		"manual_long_boss_fight":"NOT_RUN","original_s32_art":"NOT_RUN",
		"exact_original_camera_calibration":"NOT_RUN","visual_fidelity":"REQUIRES_USER_REVIEW",
		"scope":"actual Main, existing source field, physics, services, portals, save and simulated respawn deadlines"}
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t"));file.close()
	print("GIRAN_RESULT ",JSON.stringify(report))
	if is_instance_valid(world): world.queue_free()
	quit(0 if failures.is_empty() else 1)
