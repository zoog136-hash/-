extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const ADEN_COMBAT_QA = preload("res://tests/qa_aden_source_combat_positions.gd")

## Diagnostic populations use real AI, hit signals, AUTO, projectiles and existing art.
## Controlled HP avoids deaths changing the population during a short sample.
const OUTPUT = "user://presentation-benchmark"
const WARMUP_FRAMES: int = 60
const SAMPLE_FRAMES: int = 180
var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func _clear(world: TwilightWorld) -> void:
	world.player.set_auto_enabled(false)
	world.player.clear_click_path()
	world._clear_combat_actions()
	world.selected_monster = null
	world.auto_target = null
	world.auto_stuck_time = 0.0
	world.auto_repath_timer = 0.0
	world.auto_attack_timer = 0.0
	for mob: TwilightMonster in world.monsters_root.get_children():
		world.field_population.release(mob)
		world.monsters_root.remove_child(mob)
		mob.queue_free()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	# Every population starts in a fresh playable world. Previous samples
	# must not deplete ammunition, retain pickup/skill state, or deactivate AUTO
	# for the next measurement. Actual combat mechanics and hit checks remain.
	var report: Dictionary = {"adapter":RenderingServer.get_video_adapter_name(), "samples":[],
		"note":"32/96/192 controlled-HP actors, hunt vs one existing cone boss with adds; 60 warmup + 180 sampled frames. Real AI/AUTO/flight callbacks. Software GL, no device FPS guarantee."}
	var capture_enabled: bool = DisplayServer.get_name() != "headless"
	report["rendered"] = capture_enabled
	for scenario: int in range(6):
		var world: TwilightWorld = load("res://Main.tscn").instantiate()
		var metered: bool = ResourceLoader.exists("res://tests/qa_combat_hud_world.gd")
		if metered: world.set_script(load("res://tests/qa_combat_hud_world.gd"))
		root.add_child(world)
		if not CLASS_QA.enter_game(world):
			push_error("Rendered gameplay class confirmation failed")
			quit(1)
			return
		world.save_timer = -10000
		world.rng.seed = 20261009
		world._set_map("aden_world", false)
		world.field_population.set_process(false)
		var combat_pair: Dictionary = ADEN_COMBAT_QA.find_source_combat_pair(world.field_map as RemakePlayableField, world.rng)
		if combat_pair.is_empty():
			push_error("No real reachable, non-safe source-grid combat pair for 32/96/192 crowd verification")
			quit(1)
			return
		var point: Vector2 = combat_pair["player"]
		var anchor_point: Vector2 = combat_pair["monster"]
		var population: int = [32, 96, 192][scenario % 3]
		var mode: String = "hunt" if scenario < 3 else "boss"
		_clear(world)
		await process_frame
		world.player.global_position = point
		# Each measured population starts with a fresh player combat state.
		# Stun/fear carried from the previous crowd would suppress real AUTO.
		world.player.clear_status_effects()
		world.player.set_touch_vector(Vector2.ZERO)
		world.player.velocity = Vector2.ZERO
		world.player.cancel_attack()
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.field_renderer.refresh_visible()
		world.hp = 999999
		world.mp = 999999
		# These long, multi-population stress samples test sustained combat.
		# Supply finite, test-only ammunition per independent scenario; the
		# production ammo-consumption / AUTO-off behavior remains unchanged.
		world.inventory["화살"] = 10000
		world.inventory["총알"] = 10000
		var tested_ammo: String = world._current_ammo_name()
		var ammo_before: int = int(world.inventory.get(tested_ammo, 0)) if not tested_ammo.is_empty() else 0
		var hits: Array[int] = [0]
		var auto_drops: Array[Dictionary] = []
		world.player.auto_toggled.connect(func(enabled: bool) -> void:
			if not enabled:
				auto_drops.append({
					"ammo": world._current_ammo_name(),
					"ammo_remaining": int(world.inventory.get(world._current_ammo_name(), 0)),
					"manual_input": world.player.touch_vector,
					"keyboard_input": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
					"position": world.player.global_position
				})
		)
		var anchor: TwilightMonster = null
		var anchor_index: int = 1 if mode == "boss" else 0
		var normal_records: Array = world.monster_db.filter(func(r: Dictionary) -> bool: return not preload("res://scripts/loot_drop.gd").is_boss_record(r))
		for index: int in range(population):
			# Use the same active DB order in the baseline and changed checkout.
			# Controlled HP/stats keep the population fixed; appearance and attack
			# cadence/rigs are the actual runtime catalog, not placeholder art.
			var boss_slot: bool = mode == "boss" and index == 0
			var record: Dictionary = (normal_records[index % normal_records.size()] as Dictionary).duplicate(true)
			if boss_slot:
				for candidate: Dictionary in world.monster_db:
					if str(candidate.name) == "드레이크": record = candidate.duplicate(true); break
			record.merge({"hp":999999,"atk":3,"lv":1,"ac":0},true)
			if not boss_slot: record.attack_type = ["melee","ranged","magic"][index%3]
			if record.has("ai") and not boss_slot:
				record.ai = {"aggressive":true,"aggro_radius":600,"leash_distance":900}
			var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
			world.monsters_root.add_child(mob)
			mob.setup(record, world.player, world, world._monster_texture(record))
			mob.attack_cooldown = mob.attack_interval*float(index)/float(population)
			# Synthetic alternating combat modes intentionally use matching visual
			# weapons for crowd QA while retaining each species body and intervals.
			var rig: Node = mob.get("species_visual")
			if is_instance_valid(rig) and not boss_slot:
				rig.visual = rig.visual.duplicate(true)
				rig.visual.weapon = ["sword","bow","staff"][index%3]
			var angle: float = TAU * float(index) / float(population)
			# Retain a visible, reachable real combat target near the player
			# while the remaining 31/95/191 actual AI actors load the scene.
			# Separating their initial positions avoids a collision pile-up
			# that previously starved player strikes at the 192-actor sample.
			if index == anchor_index:
				mob.global_position = anchor_point
				anchor = mob
			else:
				mob.global_position = point + Vector2.from_angle(angle) * (185.0 + float(index % 6) * 38.0)
			mob.home_position = mob.global_position
			if mode == "boss" and index == 0: mob.special_cooldown = .05
			mob.died.connect(world._on_monster_died)
			mob.player_hit.connect(world._on_player_hit)
			mob.player_hit.connect(func(_mob: TwilightMonster, _damage: int, _kind: String) -> void: hits[0] += 1)
			mob.selected.connect(world._select_monster)
		world.player.set_auto_enabled(true)
		world.auto_target = anchor
		world.selected_monster = anchor
		# Assert the real combat prerequisites before measuring 300/360 frames;
		# do not relax source edges, attack distance or actual damage counters.
		if not world._has_line_of_sight_world(world.player.global_position, anchor.global_position) or not world._target_in_current_weapon_range(anchor):
			push_error("Aden crowd source-grid target is not visible/in weapon range: " + JSON.stringify(combat_pair))
			quit(1)
			return
		# This is the real AUTO attack path, not synthetic damage or fake hits.
		# Report any remaining failure with enough state to diagnose it.
		var times: Array[float] = []
		var process_times: Array[float] = []
		var physics_times: Array[float] = []
		var peak_flights: int = 0
		var peak_nodes: int = 0
		for frame: int in range(WARMUP_FRAMES+SAMPLE_FRAMES):
			if frame==WARMUP_FRAMES and metered: world.call("reset_hud_counts")
			var start: int = Time.get_ticks_usec()
			await process_frame
			if frame >= WARMUP_FRAMES:
				times.append(float(Time.get_ticks_usec() - start) / 1000.0)
				process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			peak_flights = maxi(peak_flights, world.combat_flights.flights.size())
			peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if capture_enabled:
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			if image == null or image.is_empty() or image.save_png(OUTPUT + "/" + mode + "-" + str(population) + ".png") != OK:
				failed = true
				push_error("Crowd capture failed " + str(population))
		# Unexpected AUTO cancellation is a real test failure, not a reason to
		# repeatedly force AUTO on and manufacture a pass.
		if not world.player.auto_enabled:
			failed = true
			print("CROWD_AUTO_OFF ",JSON.stringify({"mode":mode,"population":population,"events":auto_drops}))
		var ammo_after: int = int(world.inventory.get(tested_ammo, 0)) if not tested_ammo.is_empty() else 0
		if not tested_ammo.is_empty() and (ammo_after < 0 or ammo_after > ammo_before):
			failed = true
			push_error("Crowd ammo accounting invalid: " + tested_ammo + " before=" + str(ammo_before) + " after=" + str(ammo_after))
		var damage_hits: int = 0
		for mob: TwilightMonster in world.monsters_root.get_children(): damage_hits += mob.damage_hit_count
		if hits[0] == 0 or damage_hits == 0:
			failed = true
			push_error("Crowd had no real combat " + str(population) + " auto=" + str(world.player.auto_enabled) + " stunned=" + str(world.player.is_stunned()) + " feared=" + str(world.player.is_feared()) + " anchor_valid=" + str(is_instance_valid(anchor)) + " hits=" + str(hits[0]) + "/" + str(damage_hits))
		times.sort()
		process_times.sort()
		physics_times.sort()
		var sample: Dictionary = {"population":population, "mode":mode, "frames":times.size(), "median_ms":times[times.size() / 2],
			"p95_ms":times[int(times.size() * 0.95)], "process_p95_ms":process_times[int(process_times.size() * 0.95)],
			"physics_p95_ms":physics_times[int(physics_times.size() * 0.95)], "peak_nodes":peak_nodes,
			"monster_released_hits":hits[0], "player_landed_hits":damage_hits, "ammo_name":tested_ammo, "ammo_before":ammo_before, "ammo_after":ammo_after, "ammo_spent":ammo_before-ammo_after, "peak_flights":peak_flights,
			"vfx_high_water":world.combat_vfx.high_water, "orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}
		if metered: sample["hud_work"] = world.call("hud_counts")
		_clear(world)
		# An active impact/number/death pose may still have its normal lifetime.
		# Give the real VFX process loop bounded frames to release the pool;
		# do not forcibly clear it or mask a genuine lifecycle leak.
		var vfx_settle_frames: int = 0
		while not world.combat_vfx.active.is_empty() and vfx_settle_frames < 120:
			await process_frame
			vfx_settle_frames += 1
		sample["vfx_settle_frames"] = vfx_settle_frames
		sample["vfx_returned"] = world.combat_vfx.active.is_empty() and world.combat_vfx.available.size() == world.combat_vfx.CAPACITY
		sample["flights_returned"] = world.combat_flights.flights.is_empty() and world.combat_flights.available.size() <= world.combat_flights.MAX_POOL
		if not sample.vfx_returned or not sample.flights_returned: failed = true
		report.samples.append(sample)
		print("CROWD_SAMPLE ", JSON.stringify(sample))
		world.queue_free()
		await process_frame
	var file: FileAccess = FileAccess.open(OUTPUT + "/performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(("PRESENTATION_BENCHMARK_RENDER_OK" if capture_enabled else "PRESENTATION_BENCHMARK_SIMULATION_OK") if not failed else "PRESENTATION_BENCHMARK_FAILED")
	quit(1 if failed else 0)
