extends SceneTree
# Isolated Main-scene melee -> on_hit proc -> VFX capture. No forced proc rolls,
# altered probabilities, inflated target HP, or direct VFX emit calls.
const QA = preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("LIGHTNING_COMBAT_FAIL " + label)
func run() -> void:
	seed(1531025)
	var output := OS.get_environment("TWILIGHT_LIGHTNING_COMBAT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world, "뇌신"), "actual class selection")
	world.save_timer = -100000
	world._set_map("escaros_01", false)
	check(world.active_map_id == "escaros_01", "actual Escaros map loaded")
	if not failures.is_empty(): quit(1); return
	world.level = 90
	world.mp = 9999
	world.hp = 999999
	# Use this class's existing equipment and unchanged melee attack markers.
	world.player.clear_transform_visual()
	var catalog := world.original_skills.catalog
	var thunder := catalog.record_for("썬더 볼트")
	var chain := catalog.record_for("체인 라이트닝")
	for skill: Dictionary in [thunder,chain]: catalog.learned[str(skill.id)] = 1
	for entry: Dictionary in world.quickslots: entry["auto"] = false
	# Use existing spawn counts; do not invent dense flags or inflate the map.
	for region: Dictionary in world.field_map.data.get("monster_spawn", []):
		if str(region.get("mode", "")) == "boss" or str(region.id) == "boss": continue
		var dense_landing := world.field_population._spawn_point(region)
		if dense_landing.is_finite():
			world.player.global_position = dense_landing
			break
	world.field_population.wake_clock = 0
	world.field_population._process(.1)
	var population_was_processing := world.field_population.is_processing()
	world.field_population.set_process(false)
	var monster_physics: Dictionary = {}
	for monster: Node in world.monsters_root.get_children():
		monster_physics[monster.get_instance_id()] = monster.is_physics_processing()
		monster.set_physics_process(false)
	var focus: TwilightMonster = null
	var landing := Vector2.INF
	var dense_count := 0
	var rejected_projectile_paths := 0
	for slot: Dictionary in world.field_population.slots:
		var monster: TwilightMonster = slot.monster
		if is_instance_valid(monster) and not monster.dead: dense_count += 1
	# The production flight checks its actual chest-to-hit path against terrain.
	# Foot-to-foot visibility alone can select a shot that correctly hits a wall.
	for slot: Dictionary in world.field_population.slots:
		var monster: TwilightMonster = slot.monster
		if not is_instance_valid(monster) or monster.dead: continue
		for attempt: int in range(24):
			var candidate := world._random_walkable_position(monster.global_position, 28, 54)
			if not candidate.is_finite() or not world._has_line_of_sight_world(candidate, monster.global_position): continue
			var origin := candidate + world.player.motion.profile.projectile_offset(candidate.direction_to(monster.global_position))
			if not world._has_line_of_sight_world(origin, monster.combat_hit_position()):
				rejected_projectile_paths += 1
				continue
			focus = monster
			landing = candidate
			break
		if is_instance_valid(focus): break
	check(is_instance_valid(focus) and landing.is_finite(), "existing target with a real unobstructed projectile path")
	if focus == null or not landing.is_finite(): quit(1); return
	world.player.global_position = landing
	world.selected_monster = focus
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()

	world.hud._close_workspace()
	world.player.face_target(focus.global_position)
	world.player.set_auto_enabled(true)
	var first_contact: int = -1
	var captured: bool = false
	var frame_times: Array[float] = []
	var peak_live: int = 0
	var peak_bytes: int = 0
	var observed: Array[Dictionary] = []
	world.original_skills.vfx.phase_started.connect(func(id: String, phase: String, point: Vector2) -> void:
		if id in [str(thunder.id),str(chain.id)] and phase == "impact": observed.append({"id":id,"point":str(point),"physics_frame":Engine.get_physics_frames()})
	)
	for frame: int in range(360):
		var before := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		frame_times.append((Time.get_ticks_usec()-before) / 1000.0)
		peak_live = maxi(peak_live, world.original_skills.vfx.live.size())
		peak_bytes = maxi(peak_bytes, world.original_skills.vfx.library.resident_rgba_bytes())
		if not observed.is_empty() and first_contact < 0: first_contact = frame
		if first_contact >= 0 and frame >= first_contact + 3 and not captured:
			root.get_texture().get_image().save_png(output.path_join("actual-lightning-contact.png"))
			captured = true
	check(not observed.is_empty(), "unchanged on-hit probabilities produced actual lightning")
	world._set_map("escaros_02", false)
	check(world.original_skills.vfx.live.is_empty() and world.combat_flights.flights.is_empty(), "map change clears all pending visual and combat flights")
	check(world.original_skills.vfx.library.resident_rgba_bytes() == 0, "map change releases both generated and existing atlas pins")
	frame_times.sort()
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"platform":OS.get_name(),"frames":frame_times.size(),"on_hit_lightning_events":observed,"peak_vfx":peak_live,"peak_atlas_rgba_bytes":peak_bytes,"median_frame_ms":frame_times[frame_times.size()/2],"p95_frame_ms":frame_times[int(frame_times.size()*.95)],"android":"NOT_RUN","fixture":"existing Main actors and melee markers, unchanged passive proc chances; isolated save; other monster AI frozen"}
	var file := FileAccess.open(output.path_join("combat.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("LIGHTNING_COMBAT_RESULT ",JSON.stringify({"failures":failures,"events":observed.size(),"peak_vfx":peak_live,"peak_bytes":peak_bytes}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
