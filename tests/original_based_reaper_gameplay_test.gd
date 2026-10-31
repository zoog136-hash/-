extends "res://tests/pr100_direction_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.
## Production class/equipment/input/attack/respawn paths. Explicit pose sampling
## and controlled incoming damage are reported separately from real attacks.
func subject_path() -> String: return "res://assets/actors/eight_direction/original_based/reaper_female/SpriteFrames.tres"
func subject_spec() -> Dictionary: return {"job":"사신", "appearance":3, "transform_id":"412", "name":"배틀 사이드", "type":"사이드", "style":"slash", "magic":false}

## The catalog record may pin a newer reviewed SpriteFrames for this transform
## (animation_profile.frames_path, e.g. a run-locomotion revision). Production
## binding to either the original subject or that pinned revision is valid.
func production_subject_paths(transform: Dictionary) -> Array[String]:
	var paths: Array[String] = [subject_path()]
	var pinned: String = str(transform.get("animation_profile", {}).get("frames_path", ""))
	if not pinned.is_empty() and pinned not in paths: paths.append(pinned)
	return paths

## Production locomotion may present an authored RUN where a set has no WALK.
func locomotion_track(frames: SpriteFrames, direction: int) -> String:
	var walk: String = "walk_" + str(direction)
	if frames.has_animation(walk) and frames.get_frame_count(walk) > 0: return walk
	return "run_" + str(direction)

func run() -> void:
	var spec := subject_spec()
	var profile_id := "transform:" + str(spec.transform_id)
	out = OS.get_environment("TWILIGHT_PR100_REPORT")
	if out.is_empty(): out = "user://original-based-reaper-gameplay.json"
	captures = OS.get_environment("TWILIGHT_PR100_CAPTURE_DIR")
	if not captures.is_empty():
		check(DisplayServer.get_name() != "headless", "capture uses actual rendered Main")
		if DisplayServer.get_name() == "headless": captures = ""
		else: DirAccess.make_dir_recursive_absolute(captures)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world, spec.job), "production subject class entry")
	world.hud.class_selected.emit(spec.appearance)
	world.hud._hide_aux_panels()
	world.save_timer = -10000.
	world.rng.seed = 20261013
	world._set_map("aden_world", false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	center = find_clearing()
	check(center.is_finite(), "production map eight-direction clearing")
	if not center.is_finite(): await finish(); return
	world.player.set_auto_enabled(false)
	world.player.position = center
	world.player.camera.zoom = Vector2(2.2, 2.2)
	world.player.camera.position = Vector2(0, -32)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.player.attack_strike.connect(player_strike)
	physics_frame.connect(trace_flights)
	var weapon: Dictionary = world._find_catalog_item_record(spec.name)
	check(not weapon.is_empty(), "existing DB weapon")
	world._equip_or_acquire_item(weapon, true)
	check(world._current_weapon_type() == spec.type, "production subject weapon equipment")
	var transform: Dictionary = {}
	for record: Dictionary in world.catalog_db["변신"]:
		if str(record.get("sourceId", "")) == spec.transform_id: transform = record; break
	check(not transform.is_empty(), "existing subject transformation")
	world._equip_catalog("변신", transform)
	await tick(14)
	check(world.player.motion.profile.profile_id == profile_id and world.player.motion.profile.frames_path in production_subject_paths(transform), "production transform binds own authored image")
	report.scope = "original-based " + profile_id + ", actual Main/equipment/input/weapon/respawn"
	report.setup = {"scene":"Main.tscn", "map":"aden_world", "transform":str(spec.transform_id), "weapon":spec.name,
		"qa_positioning":true, "stats_overridden":false, "background_spawn_slots_paused":true,
		"incoming_damage":"controlled production hit and poison-tick callbacks; not an AI attack sample"}
	var interval: float = world._normal_attack_interval()
	await player_case(spec, true)
	world._equip_catalog("변신", {})
	await tick(14)
	check(not world.player.transform_active, "transform removal restores base")
	world._equip_catalog("변신", transform)
	await tick(14)
	check(world.player.transform_active and world.player.motion.profile.profile_id == profile_id and is_equal_approx(interval, world._normal_attack_interval()), "transform roundtrip preserves original identity and cadence")
	await inspect_poses()
	await incoming_and_death()
	await finish()

func inspect_poses() -> void:
	report.pose_samples = []
	world.player.position = center
	world.player.set_physics_process(false)
	var sprite := active_sprite()
	var frames: SpriteFrames = sprite.sprite_frames
	var base_scale: Vector2 = sprite.get_meta("base_scale", Vector2.ONE)
	for direction: int in range(8):
		for role: String in ["idle", "walk", "attack", "hit", "death"]:
			var track: String = locomotion_track(frames, direction) if role == "walk" else role + "_" + str(direction)
			check(frames.has_animation(track), "authored role " + track)
			for index: int in range(frames.get_frame_count(track)):
				sprite.animation = track
				sprite.frame = index
				var texture: Texture2D = frames.get_frame_texture(track, index)
				sprite.scale = base_scale * Vector2(256, 256) / texture.get_size()
				check(upright(sprite), "sample stays upright " + track)
				check((texture.get_size() * sprite.scale / base_scale).is_equal_approx(Vector2(256, 256)), "constant displayed pose canvas " + track)
				report.pose_samples.append({"track":track, "frame":index})
				if OS.get_environment("TWILIGHT_ORIGINAL_POSE_CAPTURE") != "0":
					await capture("authored-%s-%s-%d" % [COMPASS[direction], role, index])
	world.player.motion.advance(.2, Vector2.ZERO)
	world.player.motion.apply(sprite, base_scale)
	world.player.set_physics_process(true)

func incoming_and_death() -> void:
	report.incoming = []
	for direction: int in range(8):
		world.player.position = center
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.player.cancel_attack()
		world.player.clear_click_path()
		world.player.motion.face(screen_direction(direction))
		await tick(8)
		normal.position = center + screen_direction(direction) * 60.
		var probe := RandomNumberGenerator.new()
		var seed_value := 1
		while true:
			probe.seed = seed_value
			if probe.randf() < world._monster_hit_chance(normal, "melee"): break
			seed_value += 1
		world.rng.seed = seed_value
		var hp_before: int = world.hp
		world._on_player_hit(normal, 1, "melee")
		await tick()
		check(world.hp < hp_before and world.hp > 0, "controlled hit reaches production HP handler " + COMPASS[direction])
		check(active_sprite().animation == "hit_" + str(direction), "actual incoming damage displays directional hit " + COMPASS[direction])
		await capture("incoming-" + COMPASS[direction])
		await tick(14)
		check(active_sprite().animation == "idle_" + str(direction), "incoming hit returns to same idle " + COMPASS[direction])
		var sprite := active_sprite()
		var frames: SpriteFrames = sprite.sprite_frames
		var displayed_canvas: Vector2 = frames.get_frame_texture(sprite.animation, sprite.frame).get_size() * sprite.scale
		var old_position: Vector2 = world.player.global_position
		world._on_player_poison_tick(world.hp)
		var death: Dictionary = {}
		for entry: Dictionary in world.combat_vfx.active:
			if str(entry.kind) == "death": death = entry
		check(not death.is_empty(), "production lethal poison emits corpse " + COMPASS[direction])
		if death.is_empty(): continue
		check(str(death.animation) == "death_" + str(direction), "corpse retains exact facing " + COMPASS[direction])
		check((death.point as Vector2).is_equal_approx(old_position), "corpse stays at actual death position")
		check(world.hp == world._effective_max_hp() and world.player.transform_active, "production respawn restores HP and retains transform")
		# Keep the death location in the real viewport while the live player is
		# already at the normal spawn. No death animation or gameplay clock override.
		world.player.camera.position = center - world.player.position + Vector2(0, -32)
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		var death_frames: Array[int] = []
		var death_captures: Array[Dictionary] = []
		var death_samples: Array[Dictionary] = []
		var death_deadline: int = Time.get_ticks_msec() + 3000
		# CombatVFX advances in _process, independently of the physics clock.
		# Observe every render/process update instead of polling physics ticks;
		# retain the real lifetime and the requirement to see every real frame.
		while not death.is_empty() and Time.get_ticks_msec() < death_deadline:
			if captures.is_empty(): await process_frame
			else: await RenderingServer.frame_post_draw
			if death.is_empty(): break
			var frame_index: int = world.combat_vfx._death_frame_at_age(death)
			var texture: Texture2D = frames.get_frame_texture(str(death.animation), frame_index)
			var draw_scale: Vector2 = world.combat_vfx._death_draw_scale(death, texture)
			check((texture.get_size() * draw_scale).is_equal_approx(displayed_canvas), "corpse preserves live displayed size")
			check(((death.offset as Vector2) + Vector2(0, texture.get_height() / 8.) * draw_scale).length() < .01, "corpse preserves foot anchor")
			if frame_index not in death_frames:
				death_frames.append(frame_index)
				death_samples.append({"frame":frame_index, "age":float(death.age), "duration":float(death.duration), "pose_duration":float(death.pose_duration)})
				if not captures.is_empty():
					# Synchronous PNG compression can consume an entire short VFX
					# phase on software rendering. Read the actual frame now, but
					# write it only after the unchanged production clock completes.
					death_captures.append({"name":"death-%s-%d" % [COMPASS[direction], frame_index],
						"image":root.get_texture().get_image()})
		check(death_frames == [0, 1, 2], "real VFX clock displays all death frames " + COMPASS[direction] + " observed=" + str(death_frames))
		check(death.is_empty(), "corpse lifetime ends and returns pool record")
		for sample: Dictionary in death_captures:
			check((sample.image as Image).save_png(captures.path_join(str(sample.name) + ".png")) == OK, "actual Main screenshot " + str(sample.name))
			report.screenshots.append(str(sample.name) + ".png")
		report.incoming.append({"compass":COMPASS[direction], "hp_before":hp_before, "death_frames":death_frames, "respawn_hp":world.hp,
			"death_clock_samples":death_samples, "observation_clock":"process_frame" if captures.is_empty() else "frame_post_draw",
			"png_written_after_vfx_clock":not captures.is_empty()})
		world.player.camera.position = Vector2(0, -32)
