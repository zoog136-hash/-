extends SceneTree

const METER = preload("res://tests/qa_combat_hud_world.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	world.set_script(METER)
	root.add_child(world)
	if not CLASS_QA.enter_game(world): quit(1); return
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_auto_enabled(false)
	world.player.set_physics_process(false)
	world.quickslots = []
	world.save_timer = -100000
	# Compare only HP-changing strikes; real stat procs have their own regression.
	for index: int in range(world.skills_db.size()-1,-1,-1):
		var skill: Dictionary = world.skills_db[index]
		if world._is_passive_skill(skill) and world.SKILL_RULES.passive_trigger(skill)=="on_damaged":
			world.skills_db.remove_at(index)
	world.player.global_position = Vector2(3550,4300)
	for mob: TwilightMonster in world.monsters_root.get_children(): mob.set_physics_process(false)
	var attacker: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(attacker)
	var record: Dictionary = world.monster_db[0].duplicate(true)
	record.merge({"hp":999999, "lv":1, "critical_rate":0}, true)
	attacker.setup(record, world.player, world, world._monster_texture(record))
	attacker.global_position = world.player.global_position + Vector2(40,0)
	attacker.set_physics_process(false)
	var samples: Array = []
	for panel_open: bool in [false, true]:
		world.hud._close_workspace()
		if panel_open: world.hud.open_character()
		world.rng.seed = 20261009
		world.max_hp = 20000
		world.hp = 20000
		world.mp = 100
		world._update_hud()
		world.call("reset_hud_counts")
		var strikes: Array[float] = []
		var ticks: Array[float] = []
		var start: int = Time.get_ticks_usec()
		for frame: int in range(32):
			for index: int in range(6):
				var hit_start: int = Time.get_ticks_usec()
				world._on_player_hit(attacker,37,["melee","ranged","magic"][(frame*6+index)%3])
				strikes.append(float(Time.get_ticks_usec()-hit_start)/1000.)
			var tick_start: int = Time.get_ticks_usec()
			world._process(1./60.)
			ticks.append(float(Time.get_ticks_usec()-tick_start)/1000.)
		var elapsed: float = float(Time.get_ticks_usec()-start)/1000.
		strikes.sort(); ticks.sort()
		var sample: Dictionary = world.call("hud_counts")
		sample.merge({"panel_open":panel_open,"incoming_strikes":192,"simulated_frames":32,
			"elapsed_ms":elapsed,"hit_p95_ms":strikes[int(strikes.size()*.95)],
			"tick_p95_ms":ticks[int(ticks.size()*.95)],"hp_after":world.hp,
			"hud_hp":world.hud.hp_bar.value,"hud_max_hp":world.hud.hp_bar.max_value},true)
		samples.append(sample)
		print("COMBAT_HUD_SAMPLE ",JSON.stringify(sample))
	DirAccess.make_dir_recursive_absolute("user://combat-hud-review")
	var file: FileAccess = FileAccess.open("user://combat-hud-review/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":samples,"note":"Deterministic 192 incoming melee/ranged/magic strikes over 32 manually advanced frames. Measures HUD and real damage path, not full crowd FPS."},"\t"))
	file.close()
	world.queue_free()
	await process_frame
	print("COMBAT_HUD_BENCHMARK_OK")
	quit()
