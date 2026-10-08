extends SceneTree

## Diagnostic populations use real AI, hit signals, AUTO, projectiles and existing art.
## Controlled HP avoids deaths changing the population during a short sample.
const OUTPUT = "user://combat-crowd-review"
var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func _clear(world: TwilightWorld) -> void:
	world.player.set_auto_enabled(false)
	world.player.clear_click_path()
	world._clear_combat_actions()
	world.selected_monster = null
	for mob: TwilightMonster in world.monsters_root.get_children():
		world.field_population.release(mob)
		world.monsters_root.remove_child(mob)
		mob.queue_free()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.save_timer = -10000
	world.rng.seed = 20261009
	world._set_map("aden_world", false)
	world.field_population.set_process(false)
	var point: Vector2 = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550, 4300)))
	var report: Dictionary = {"adapter":RenderingServer.get_video_adapter_name(), "samples":[],
		"note":"32/96/192 controlled-HP monsters, real combat; software GL runner, not a PC GPU FPS guarantee"}
	var capture_enabled: bool = DisplayServer.get_name() != "headless"
	report["rendered"] = capture_enabled
	for population: int in [32, 96, 192]:
		_clear(world)
		await process_frame
		world.player.global_position = point
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.field_renderer.refresh_visible()
		world.hp = 999999
		world.mp = 999999
		var hits: Array[int] = [0]
		for index: int in range(population):
			var record: Dictionary = {"name":"군집 검증 " + str(index), "hp":999999, "atk":3,
				"lv":1, "ac":0, "attack_type":["melee", "ranged", "magic"][index % 3]}
			var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
			world.monsters_root.add_child(mob)
			mob.setup(record, world.player, world, world._monster_texture(record))
			var angle: float = TAU * float(index) / float(population)
			mob.global_position = point + Vector2.from_angle(angle) * (45.0 + float(index % 6) * 38.0)
			mob.home_position = mob.global_position
			mob.died.connect(world._on_monster_died)
			mob.player_hit.connect(world._on_player_hit)
			mob.player_hit.connect(func(_mob: TwilightMonster, _damage: int, _kind: String) -> void: hits[0] += 1)
			mob.selected.connect(world._select_monster)
		world.player.set_auto_enabled(true)
		var times: Array[float] = []
		var process_times: Array[float] = []
		var physics_times: Array[float] = []
		var peak_flights: int = 0
		var peak_nodes: int = 0
		for frame: int in range(180):
			var start: int = Time.get_ticks_usec()
			await process_frame
			if frame >= 30:
				times.append(float(Time.get_ticks_usec() - start) / 1000.0)
				process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			peak_flights = maxi(peak_flights, world.combat_flights.flights.size())
			peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if capture_enabled:
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			if image == null or image.is_empty() or image.save_png(OUTPUT + "/crowd-" + str(population) + ".png") != OK:
				failed = true
				push_error("Crowd capture failed " + str(population))
		var damage_hits: int = 0
		for mob: TwilightMonster in world.monsters_root.get_children(): damage_hits += mob.damage_hit_count
		if hits[0] == 0 or damage_hits == 0:
			failed = true
			push_error("Crowd had no real combat " + str(population))
		times.sort()
		process_times.sort()
		physics_times.sort()
		var sample: Dictionary = {"population":population, "frames":times.size(), "median_ms":times[times.size() / 2],
			"p95_ms":times[int(times.size() * 0.95)], "process_p95_ms":process_times[int(process_times.size() * 0.95)],
			"physics_p95_ms":physics_times[int(physics_times.size() * 0.95)], "peak_nodes":peak_nodes,
			"monster_released_hits":hits[0], "player_landed_hits":damage_hits, "peak_flights":peak_flights,
			"vfx_high_water":world.combat_vfx.high_water, "orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}
		_clear(world)
		await process_frame
		sample["vfx_returned"] = world.combat_vfx.active.is_empty() and world.combat_vfx.available.size() == world.combat_vfx.CAPACITY
		sample["flights_returned"] = world.combat_flights.flights.is_empty() and world.combat_flights.available.size() <= world.combat_flights.MAX_POOL
		if not sample.vfx_returned or not sample.flights_returned: failed = true
		report.samples.append(sample)
		print("CROWD_SAMPLE ", JSON.stringify(sample))
	var file: FileAccess = FileAccess.open(OUTPUT + "/performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	world.queue_free()
	await process_frame
	print(("COMBAT_CROWD_RENDER_OK" if capture_enabled else "COMBAT_CROWD_SIMULATION_OK") if not failed else "COMBAT_CROWD_FAILED")
	quit(1 if failed else 0)
