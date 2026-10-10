extends SceneTree

var world: TwilightWorld
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("GROUND_LOOT FAIL: ", message)

func age(view: Button) -> void:
	view.set("visible_since", Time.get_ticks_msec() - 900)

func clear() -> void:
	world.player.set_auto_enabled(false)
	world.loot_pickup.cancel()
	world._clear_drops()
	world._clear_combat_actions()
	world.player.clear_click_path()

func point_at(radius: float) -> Vector2:
	for i: int in range(32):
		var point: Vector2 = world.player.global_position + Vector2.from_angle(float(i) * TAU / 32) * radius
		if not world._is_walkable_world(point): continue
		var path: PackedVector2Array = world.find_world_path(world.player.global_position, point)
		if path.size() > 1 and path[path.size() - 1].distance_to(point) < 50: return point
	return world.player.global_position

func walk_until_empty(limit: int = 360) -> int:
	var frames: int = 0
	while not world.ground_loot.views.is_empty() and frames < limit:
		world._process(1.0 / 60.0)
		await physics_frame
		frames += 1
	return frames

func pointer(view: Button, use_touch: bool) -> void:
	var point: Vector2 = view.get_global_transform_with_canvas() * (view.size * 0.5)
	for pressed_value: bool in [true, false]:
		if use_touch:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = point
			touch.pressed = pressed_value
			root.push_input(touch, true)
		else:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.position = point
			mouse.pressed = pressed_value
			root.push_input(mouse, true)

func _run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.save_timer = -10000
	world.field_population.set_process(false)
	world._clear_monsters()
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550,4300)))
	var origin: Vector2 = world.player.global_position
	var before: int = int(world.inventory.get("HP 물약", 0))
	var view: Button = world._spawn_ground_drop("HP 물약", origin)
	check(view != null and world.ground_loot.records.size() == 1, "spawn creates an authoritative world record")
	check(int(world.inventory.get("HP 물약", 0)) == before, "spawn never grants inventory")
	check(not world._collect_ground_drop(view), "minimum visual lifetime prevents instant collection")
	view.pressed.emit()
	check(world.loot_pickup.selected_id == str(view.get_meta("id")), "first click selects ID")
	check(world.loot_pickup.overlay.visible and int(world.inventory.get("HP 물약", 0)) == before, "selection shows name and grade without grant")
	age(view)
	world.loot_pickup.pickup_button.pressed.emit()
	check(int(world.inventory.get("HP 물약", 0)) == before + 1, "pickup button grants nearby item")
	check(world.drops_root.get_child_count() == 0, "collection removes sprite and effects synchronously")
	check(not world._collect_ground_drop(view), "stale ID cannot grant twice")
	clear()

	# Every grade uses actual DB images when available; forced generation occurs
	# only in this development test, with the real probability table untouched.
	for grade: String in TwilightDropVisual.GRADES:
		var pool: Array = world.loot_catalog["equipment_by_grade"][grade]
		check(not pool.is_empty(), "available equipment grade " + grade)
		if pool.is_empty(): continue
		view = world._spawn_ground_drop(str(pool[0]), origin)
		var visual: TwilightDropVisual = view.get("visual")
		check(str(view.get_meta("grade")) == grade, "grade uses drop catalog " + grade)
		check(visual.rank == TwilightDropVisual.GRADES.find(grade), "correct beam threshold " + grade)
		check(visual.texture != null or not world.catalog_image_index["아이템"].has(str(pool[0])), "uses actual image or fallback " + grade)
		check(world._is_walkable_world(view.get_meta("world_position")), "drop is on walkable terrain " + grade)
		for other: Button in world.ground_loot.views.values():
			if other != view: check((other.get_meta("world_position") as Vector2).distance_to(view.get_meta("world_position")) >= 35.9, "simultaneous drops spread without overlapping")
	check(TwilightDropVisual.COLORS[2] == Color("3b99ff"), "Rare blue")
	check(TwilightDropVisual.COLORS[3] == Color("ff5360"), "Hero red")
	check(TwilightDropVisual.COLORS[4] == Color("bd79ff"), "Legendary purple")
	check(TwilightDropVisual.COLORS[5] == Color("ffd450"), "Mythic gold")
	check(TwilightDropVisual.COLORS[6] == Color("4cf9cf"), "Unique emerald")
	clear()

	# Walk with the real CharacterBody2D physics, never teleport to the item.
	var distant: Vector2 = point_at(240)
	view = world._spawn_ground_drop("HP 물약", distant, 3)
	age(view)
	before = int(world.inventory.get("HP 물약", 0))
	view.pressed.emit()
	view.pressed.emit()
	check(world.loot_pickup.mode == "manual" and not world.player.click_path.is_empty(), "reclick starts manual path")
	check(int(world.inventory.get("HP 물약", 0)) == before, "distant reclick cannot bypass radius")
	await walk_until_empty()
	check(world.player.global_position.distance_to(origin) > 100, "manual pickup physically walks")
	check(int(world.inventory.get("HP 물약", 0)) == before + 3, "quantity granted after real manual walk")
	check(world.loot_pickup.mode == "idle", "manual path finishes cleanly")
	clear()
	world.player.global_position = origin

	# Pickup order: current hunt, then distance, then grade on tied distance.
	var near: Button = world._spawn_ground_drop("HP 물약", point_at(100))
	var far: Button = world._spawn_ground_drop("HP 물약", point_at(260), 1, world.ground_loot.begin_hunt_batch())
	age(near); age(far)
	world.player.set_auto_enabled(true)
	check(world._run_auto_ground_pickup(), "AUTO starts collection")
	check(world.loot_pickup.target_id == str(far.get_meta("id")), "current kill batch takes precedence")
	world.player.set_auto_enabled(false)
	check(world.loot_pickup.target_id.is_empty() and world.player.click_path.is_empty(), "AUTO OFF immediately clears pickup path")
	clear()
	world.player.global_position = origin
	var auto_items: Array[Button] = []
	for radius: float in [180.0, 280.0, 360.0]:
		view = world._spawn_ground_drop("HP 물약", point_at(radius))
		age(view)
		auto_items.append(view)
	before = int(world.inventory.get("HP 물약", 0))
	world.player.set_auto_enabled(true)
	check(world._run_auto_ground_pickup(), "AUTO acquires first distant drop")
	check(world.loot_pickup.target_id == str(auto_items[0].get_meta("id")), "nearest item first without kill batch")
	await walk_until_empty(600)
	check(world.ground_loot.views.is_empty(), "AUTO sequentially collects all three")
	check(int(world.inventory.get("HP 물약", 0)) == before + 3, "three drops produce exactly three inventory grants")
	check(world.player.global_position.distance_to(origin) > 100, "AUTO walks using existing physics")
	check(world.player.auto_enabled, "AUTO remains on for combat resumption")
	check(world.loot_pickup.scan_count < 30, "scan frequency is bounded during movement")
	clear()
	world.player.global_position = origin

	# A stuck actor must stop retrying this ID and let the hunt continue.
	view = world._spawn_ground_drop("HP 물약", point_at(240))
	age(view)
	world.player.set_auto_enabled(true)
	world._run_auto_ground_pickup()
	var blocked_id: String = str(view.get_meta("id"))
	world.loot_pickup.stuck_time = 2.3
	check(not world._run_auto_ground_pickup(), "stuck target does not hold AUTO forever")
	check(world.loot_pickup.blocked.has(blocked_id), "stuck ID receives a retry cooldown")
	check(world.ground_loot.valid_view(view), "skipping unreachable loot leaves it on the ground")
	world.loot_pickup.clock += 16
	world.loot_pickup.scan_time = 0
	world._run_auto_ground_pickup()
	world._set_click_destination(point_at(130))
	check(not world.player.auto_enabled and world.loot_pickup.target_id.is_empty(), "manual move cancels automatic pickup")
	clear()

	# Identity, inaccessible endpoints, priority ties and vanished selections.
	world.player.global_position = origin
	view = world._spawn_ground_drop("HP 물약", origin)
	age(view)
	var true_id: String = str(view.get_meta("id"))
	view.set_meta("id", "nonexistent")
	check(not world._collect_ground_drop(view), "unknown ID cannot grant inventory")
	view.set_meta("id", true_id)
	view.pressed.emit()
	world.ground_loot.records[true_id]["expires_at"] = Time.get_unix_time_from_system() - 1
	world.ground_loot.tick(0.5)
	world.loot_pickup.tick(0.1)
	check(world.loot_pickup.selected_id.is_empty() and not world.loot_pickup.overlay.visible, "expired selection cancels and hides pickup panel")
	clear()
	var impossible: Button = world._spawn_ground_drop("HP 물약", point_at(220))
	var impossible_id: String = str(impossible.get_meta("id"))
	var impossible_point: Vector2 = impossible.get_meta("world_position")
	var center_cell: Vector2i = world._world_to_cell(impossible_point)
	var changed_cells: Dictionary = {}
	for y: int in range(-3,4):
		for x: int in range(-3,4):
			var cell: Vector2i = center_cell + Vector2i(x,y)
			if world.astar.is_in_boundsv(cell):
				changed_cells[cell] = world.astar.is_point_solid(cell)
				world.astar.set_point_solid(cell, true)
	world.player.set_auto_enabled(true)
	check(not world._run_auto_ground_pickup(), "inaccessible endpoint is skipped")
	check(world.loot_pickup.blocked.has(impossible_id), "inaccessible ID is throttled")
	for cell: Vector2i in changed_cells.keys(): world.astar.set_point_solid(cell, changed_cells[cell])
	clear()
	var common_name: String = str(world.loot_catalog["equipment_by_grade"]["일반"][0])
	var unique_name: String = str(world.loot_catalog["equipment_by_grade"]["유일"][0])
	var lower: Button = world._spawn_ground_drop(common_name, origin + Vector2(90,0))
	var higher: Button = world._spawn_ground_drop(unique_name, origin - Vector2(90,0))
	var higher_id: String = str(higher.get_meta("id"))
	world.ground_loot.records[higher_id]["position"] = [origin.x - 90, origin.y]
	check(world.loot_pickup._priority(higher_id, str(lower.get_meta("id"))), "same-distance priority favors higher grade")
	clear()

	# Save all maps; retain IDs and real-time expiry; discard collected/duplicate
	# entries. Loading does not modify inventory.
	world.player.global_position = origin
	view = world._spawn_ground_drop("HP 물약", origin, 2)
	var saved_id: String = str(view.get_meta("id"))
	var saved_time: float = world.ground_loot.records[saved_id]["expires_at"]
	var original_map: String = world.active_map_id
	var second_map: String = str(world.maps[1]["id"])
	world._set_map(second_map, false)
	world.field_population.set_process(false)
	check(world.ground_loot.records.has(saved_id) and not world.ground_loot.views.has(saved_id), "map change hides old loot while retaining record")
	world._spawn_ground_drop("HP 물약", world.player.global_position)
	var saved: Array = world._ground_drops_snapshot()
	check(saved.size() == 2, "snapshot covers two maps")
	before = int(world.inventory.get("HP 물약", 0))
	world._save_game(true)
	world._clear_drops()
	world._load_game(true)
	world.field_population.set_process(false)
	check(world.ground_loot.records.size() == 2 and int(world.inventory.get("HP 물약", 0)) == before, "real save file restores two maps without grant")
	world._set_map(original_map, false)
	world.field_population.set_process(false)
	check(world.ground_loot.views.has(saved_id), "returning to region restores same ID")
	check(absf(float(world.ground_loot.records[saved_id]["expires_at"]) - saved_time) < 0.01, "travel/load do not reset expiry")
	world.player.global_position = origin
	view = world.ground_loot.views[saved_id]
	age(view)
	check(world._collect_ground_drop(view), "restored item can be picked up once")
	world._save_game(true)
	world._load_game(true)
	world.field_population.set_process(false)
	check(not world.ground_loot.records.has(saved_id), "collected item does not resurrect after save/load")
	var duplicate: Array = saved.duplicate(true)
	duplicate.append(duplicate[0].duplicate(true))
	duplicate[0]["state"] = "collected"
	duplicate[1]["expires_at"] = Time.get_unix_time_from_system() - 1
	world._restore_ground_drops(duplicate)
	check(world.ground_loot.records.size() == 1, "restore ignores collected and expired entries")
	world._restore_ground_drops([saved[0], saved[0]])
	check(world.ground_loot.records.size() == 1, "duplicate persisted IDs deduplicate")
	world.ground_loot.records[saved_id]["expires_at"] = Time.get_unix_time_from_system() - 1
	world.ground_loot.tick(0.5)
	check(world.ground_loot.records.is_empty() and world.drops_root.get_child_count() == 0, "10-minute expiry removes item and effects")
	clear()
	world.player.global_position = origin

	# Native mouse/touch through viewport GUI dispatch at different camera zooms.
	for viewport_size: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1920,1080)]:
		root.size = viewport_size
		await process_frame
		for zoom: float in [0.8, 1.3]:
			world.player.camera.zoom = Vector2.ONE * zoom
			world.player.camera.position_smoothing_enabled = false
			world.player.camera.force_update_scroll()
			await process_frame
			for use_touch: bool in [false, true]:
				view = world._spawn_ground_drop("HP 물약", origin + Vector2(35,0))
				age(view)
				before = int(world.inventory.get("HP 물약", 0))
				await process_frame
				pointer(view, use_touch)
				check(world.loot_pickup.selected_id == str(view.get_meta("id")), "input selects at viewport %s zoom %s touch %s" % [viewport_size,zoom,use_touch])
				check(int(world.inventory.get("HP 물약", 0)) == before, "first pointer interaction only selects")
				pointer(view, use_touch)
				check(int(world.inventory.get("HP 물약", 0)) == before + 1, "second pointer interaction collects once")
				clear()
				view = world._spawn_ground_drop("HP 물약", origin + Vector2(35,0))
				age(view)
				await process_frame
				pointer(view, use_touch)
				pointer(world.loot_pickup.pickup_button, use_touch)
				check(int(world.inventory.get("HP 물약", 0)) == before + 2, "pickup button supports viewport %s zoom %s touch %s" % [viewport_size,zoom,use_touch])
				clear()
	root.size = Vector2i(1280,720)
	world.player.camera.zoom = Vector2.ONE

	# Deterministic original-rate boss roll: discovered seed yields exactly
	# three equipment rolls and one potion when those grades are explicitly listed; no runtime rates are substituted.
	# Original deterministic grade seed is preserved, but strict per-monster
	# loot pools now require an explicit item for every rolled grade.
	var boss_drop_pool: Array[String] = ["HP 물약"]
	for grade: String in ["일반", "고급", "희귀", "영웅", "전설", "신화", "유일"]:
		var choices: Array = world.loot_catalog["equipment_by_grade"].get(grade, [])
		if not choices.is_empty():
			boss_drop_pool.append(str(choices[0]))
	var boss: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(boss)
	boss.setup({"name":"드랍 검증 보스", "is_boss":true, "hp":100, "drop":boss_drop_pool}, world.player, world, null)
	boss.global_position = origin
	boss.set_physics_process(false)
	world.rng.seed = 146103
	before = int(world.inventory.get("HP 물약", 0))
	world._roll_drop(boss)
	check(world.ground_loot.records.size() == 4, "boss original-rate seed spawns 3 equipment plus 1 potion")
	check(int(world.inventory.get("HP 물약", 0)) == before, "boss roll deposits only on ground")
	clear()
	world._clear_monsters()
	world.player.global_position = origin
	world.equipped_items.weapon = {"name":"테스트 활", "type":"활", "slot":"weapon", "attackKind":"ranged", "attackRangeCells":10, "ammo":"화살"}
	world.inventory["화살"] = 1000
	world.attack_power = 10000
	world.dex_stat = 100
	world.hp = 100000
	world.quickslots = []
	var live: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(live)
	live.setup({"name":"연속 사냥 검증", "hp":1, "atk":1, "ac":0, "is_boss":true, "drop":boss_drop_pool}, world.player, world, null)
	live.global_position = point_at(230)
	live.set_physics_process(false)
	live.died.connect(func(monster: TwilightMonster) -> void:
		world.rng.seed = 146103
		world._on_monster_died(monster))
	world.auto_target = live
	world.selected_monster = live
	world.auto_attack_timer = 0
	world.rng.seed = 146103
	before = int(world.inventory.get("HP 물약", 0))
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var xp_before: int = world.experience
	var gold_before: int = world.gold
	world.player.set_auto_enabled(true)
	for i: int in range(360):
		world._process(1.0 / 60.0)
		await physics_frame
		if world.drops_root.get_child_count() > 0: break
	check(world.drops_root.get_child_count() > 0, "real ranged AUTO attack kills and creates ground loot")
	check(int(world.inventory.get("HP 물약", 0)) == before, "real ranged kill does not grant before pickup")
	check(world.ground_loot.records.size() == 4, "real death retains three independent equipment rolls and one potion roll")
	check(world.experience > xp_before and world.gold > gold_before, "real death retains experience and adena")
	var expected_grants: Dictionary = {}
	for record: Dictionary in world.ground_loot.records.values():
		var item_name: String = str(record["item_name"])
		expected_grants[item_name] = int(expected_grants.get(item_name, 0)) + int(record["quantity"])
		check(int(world.inventory.get(item_name, 0)) == int(inventory_before.get(item_name, 0)), "real drop remains ungranted before walking " + item_name)
		check(world.ground_loot.views.has(str(record["id"])), "real drop creates a visible ID-backed view")
	var chase: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(chase)
	chase.setup({"name":"다음 사냥 대상", "hp":999999, "atk":1, "ac":0}, world.player, world, null)
	chase.global_position = point_at(320)
	chase.set_physics_process(false)
	await walk_until_empty(720)
	check(world.ground_loot.views.is_empty() and world.player.global_position.distance_to(origin) > 80, "real kill loot is collected by walking")
	check(chase.damage_hit_count == 0, "all remaining drops precede the next attack")
	for item_name: String in expected_grants:
		check(int(world.inventory.get(item_name, 0)) == int(inventory_before.get(item_name, 0)) + int(expected_grants[item_name]), "real AUTO batch grants exactly once " + item_name)
	var resumed: bool = false
	for i: int in range(180):
		world._process(1.0 / 60.0)
		await physics_frame
		if not world.pending_attack.is_empty() or chase.hp < chase.max_hp:
			resumed = true
			break
	check(resumed and world.player.auto_enabled, "AUTO resumes attack against next monster after pickup")
	clear()
	world.queue_free()
	await process_frame
	print("GROUND_LOOT_SYSTEM checks=", checks)
	if failures.is_empty():
		print("GROUND_LOOT_SYSTEM_OK: movement, GUI input, effects, IDs, AUTO, save and maps")
		quit(0)
	else:
		print("GROUND_LOOT_SYSTEM_FAILED: ", failures.size())
		quit(1)
