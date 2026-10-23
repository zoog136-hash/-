extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var world: TwilightWorld

func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	if not ok:
		failures.append(note)
		print("VFX_MAIN_FAIL ", note)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("VFX_MAIN_NOT_RUN renderer required")
		quit(2)
		return
	var output := OS.get_environment("TWILIGHT_VFX_MAIN_DIR")
	if output.is_empty(): output = "/tmp/twilight-vfx-main"
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world, "요정"), "actual class selection")
	world.save_timer = -100000
	world._set_map("escaros_01", false)
	check(world.active_map_id == "escaros_01", "actual Escaros map loaded")
	if not failures.is_empty(): quit(1); return
	world.level = 90
	world.mp = 9999
	world.hp = 999999
	world.equipped_items["weapon"] = {"name":"VFX 검증 활", "type":"활", "slot":"weapon"}
	world.player.clear_transform_visual()
	var catalog := world.original_skills.catalog
	var triple := catalog.record_for("트리플 애로우")
	catalog.learned[str(triple.id)] = 1
	for entry: Dictionary in world.quickslots: entry["auto"] = false
	world._on_quickslot_assignment_requested(0, "skill_auto", str(triple.id))
	# Use existing spawn counts; do not invent dense flags or inflate the map.
	for region: Dictionary in world.field_map.data.get("monster_spawn", []):
		if str(region.get("mode", "")) == "boss" or str(region.id) == "boss": continue
		var dense_landing := world.field_population._spawn_point(region)
		if dense_landing.is_finite():
			world.player.global_position = dense_landing
			break
	world.field_population.wake_clock = 0
	world.field_population._process(.1)
	var focus: TwilightMonster = null
	var dense_count := 0
	for slot: Dictionary in world.field_population.slots:
		var monster: TwilightMonster = slot.monster
		if is_instance_valid(monster) and not monster.dead:
			dense_count += 1
			if focus == null: focus = monster
	check(is_instance_valid(focus), "live existing Escaros monster")
	if focus == null: quit(1); return
	var landing := Vector2.INF
	for attempt: int in range(32):
		var candidate := world._random_walkable_position(focus.global_position, 55, 140)
		if candidate.is_finite() and world._has_line_of_sight_world(candidate, focus.global_position):
			landing = candidate
			break
	check(landing.is_finite(), "real walkable dense landing")
	if not landing.is_finite(): quit(1); return
	world.player.global_position = landing
	world.selected_monster = focus
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	# First exercise the production AUTO-quickslot entry in a stationary,
	# interruption-free window, then restore all AI for the live-map workload.
	world.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.player.velocity = Vector2.ZERO
	world.player.set_touch_vector(Vector2.ZERO)
	world.player.clear_click_path()
	for frame: int in range(12): await process_frame
	var phase_counts: Dictionary = {}
	world.original_skills.vfx.phase_started.connect(func(id: String, phase: String, _point: Vector2) -> void:
		if id == str(triple.id): phase_counts[phase] = int(phase_counts.get(phase, 0)) + 1)
	var controlled_before := int(world.original_skills.event_counts.get(str(triple.id), 0))
	check(world._run_auto_combat_quickslots(), "production AUTO-quickslot accepts learned bow skill")
	for frame: int in range(60): await process_frame
	var controlled_contacts := int(world.original_skills.event_counts.get(str(triple.id), 0)) - controlled_before
	check(controlled_contacts > 0, "stationary AUTO-quickslot reaches real damage callback")
	if controlled_contacts <= 0:
		var diagnostic := {"status":"FAIL", "phase_counts":phase_counts, "pending":not world.pending_attack.is_empty(),
			"motion_active":world.player.motion.active, "motion_elapsed":world.player.motion.attack_elapsed,
			"player_physics":world.player.is_physics_processing(), "target_dead":focus.dead, "target_life":focus.life_id,
			"stunned":world.player.is_stunned(), "feared":world.player.is_feared(), "silenced":world.player.is_silenced()}
		print("VFX_MAIN_CONTROL_DIAGNOSTIC ", JSON.stringify(diagnostic))
		quit(1)
		return
	root.get_texture().get_image().save_png(output.path_join("controlled-auto-contact.png"))
	world.set_process(true)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(true)
	world.player.set_auto_enabled(true)
	var samples: Array[float] = []
	var hits_before := int(world.original_skills.event_counts.get(str(triple.id), 0))
	var peak_effects := 0
	var peak_texture_bytes := 0
	var start := Time.get_ticks_usec()
	for frame: int in range(900):
		var before := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		samples.append((Time.get_ticks_usec() - before) / 1000.0)
		peak_effects = maxi(peak_effects, world.original_skills.vfx.live.size())
		peak_texture_bytes = maxi(peak_texture_bytes, world.original_skills.vfx.library.resident_rgba_bytes())
		if frame == 450:
			var transform := world._job_transform_record("요정")
			check(not transform.is_empty(), "existing transform record")
			if not transform.is_empty(): world._apply_transform_visual(transform)
		if frame in [120, 480, 720]: root.get_texture().get_image().save_png(output.path_join("escaros_%03d.png" % frame))
	var contacts := int(world.original_skills.event_counts.get(str(triple.id), 0)) - hits_before
	check(peak_effects <= 160 and peak_texture_bytes <= 48 * 1024 * 1024, "production visual limits retained")
	# Map transition uses the actual generation cancellation path.
	world._set_map("escaros_02", false)
	check(world.original_skills.vfx.live.is_empty() and world.combat_flights.flights.is_empty(), "actual map transition clears pending visual/flight state")
	samples.sort()
	var report := {"status":"PASS" if failures.is_empty() and contacts > 0 else "PARTIAL" if failures.is_empty() else "FAIL", "failures":failures,
		"renderer":RenderingServer.get_video_adapter_name(), "platform":OS.get_name(), "frames":samples.size(),
		"simulated_seconds_at_60_hz":15, "wall_seconds":(Time.get_ticks_usec()-start)/1000000.0,
		"median_frame_wall_ms":samples[450], "p95_frame_wall_ms":samples[855],
		"existing_monsters":dense_count, "controlled_auto_contacts":controlled_contacts, "live_autohunt_contacts":contacts, "peak_vfx":peak_effects,
		"skill_phase_counts":phase_counts,
		"peak_atlas_rgba_bytes":peak_texture_bytes, "android_device":"NOT_RUN", "long_duration_autohunt":"NOT_RUN"}
	var file := FileAccess.open(output.path_join("escaros-runtime.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("VFX_MAIN_RESULT ", JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
