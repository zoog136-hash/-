extends "res://tests/pr100_direction_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.
## Exercise newly authored art through production Main/Monster/AI/combat/loot.
## The inherited checks cover actual chase, contact and lifecycle; the sampling
## below records all authored poses in this same game viewport for visual review.

func subject_name() -> String: return "늑대인간"
func subject_folder() -> String: return "werewolf"
func subject_job() -> String: return "기사"
func prepare_lifecycle() -> void: pass
func lifecycle_attempt_limit() -> int:
	# High-level regional actors have 1680/2325 HP. Let the real equipped
	# weapon finish the fight; retain their original HP, armor and hit chance.
	return 200 if is_instance_valid(normal) and normal.max_hp > 1000 else 30

func run() -> void:
	var subject := OS.get_environment("TWILIGHT_ORIGINAL_SUBJECT")
	if subject.is_empty(): subject = subject_name()
	out = OS.get_environment("TWILIGHT_PR100_REPORT")
	if out.is_empty(): out = "user://original-based-monster-gameplay.json"
	captures = OS.get_environment("TWILIGHT_PR100_CAPTURE_DIR")
	if not captures.is_empty():
		check(DisplayServer.get_name() != "headless", "capture uses actual rendered Main")
		if DisplayServer.get_name() == "headless": captures = ""
		else: DirAccess.make_dir_recursive_absolute(captures)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world, subject_job()), "actual class entry")
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
	world.player.camera.zoom = Vector2(2.6, 2.6)
	world.player.camera.position = Vector2(0, -32)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	await tick(16)
	normal = db_actor(subject)
	check(normal != null, "original-based target exists in production DB")
	if normal == null: await finish(); return
	check(normal.motion.profile.frames_path == "res://assets/actors/eight_direction/original_based/" + subject_folder() + "/SpriteFrames.tres", "production profile resolves original-based resource")
	check(normal.motion.frame_source != null, "production Sprite2D uses authored SpriteFrames")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/actors/eight_direction/original_based/" + subject_folder() + "/provenance.json"))
	check((proof.target_keys as Array).has("monster:" + subject), "subject is an explicitly reviewed original-image binding")
	check(world._monster_texture(record_for(subject)).resource_path == str(proof.reference.path), "production portrait lookup retains this exact original source")
	report.scope = "original-based " + subject_folder() + ", actual Main and production AI/combat/lifecycle"
	report.setup = {"scene":"Main.tscn", "map":"aden_world", "normal":subject, "qa_positioning":true,
		"job":subject_job(), "stats_overridden":false, "background_spawn_slots_paused":true, "normal_is_existing_population_actor":false}
	await monster_case()
	# Snapshot the real production texture regions at all role/frame/direction
	# combinations. This pose sampling is labelled separately from the AI test.
	report.pose_samples = []
	world.player.position = center + Vector2(-100, 0)
	world.player.camera.position = Vector2(100, -32)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	normal.position = center + Vector2(24, 0)
	for direction: int in range(8):
		for role: String in ["idle", "walk", "attack", "hit", "death"]:
			var track: String = role + "_" + str(direction)
			var frames: SpriteFrames = normal.motion.frame_source
			check(frames.has_animation(track), "authored role " + track)
			for index: int in range(frames.get_frame_count(track)):
				normal.sprite.texture = frames.get_frame_texture(track, index)
				if frames.has_meta("twilight_canvas_size"):
					normal.sprite.scale = normal.animation_base_scale * Vector2(256, 256) / normal.sprite.texture.get_size()
				check(upright(normal.sprite), "sample stays upright " + track)
				check((normal.sprite.texture.get_size() * normal.sprite.scale / normal.animation_base_scale).is_equal_approx(Vector2(256, 256)), "constant displayed pose canvas " + track)
				report.pose_samples.append({"track":track, "frame":index})
				if OS.get_environment("TWILIGHT_ORIGINAL_POSE_CAPTURE") != "0":
					await capture("authored-%s-%s-%d" % [COMPASS[direction], role, index])
	# End the explicit pose inspection before exercising live combat again.
	normal.motion.advance(.2, Vector2.ZERO)
	normal.motion.apply(normal.sprite, normal.animation_base_scale)
	# The production normal-monster drop is probabilistic. Select a real RNG
	# seed that yields a drop, without replacing the drop table or award path.
	var probe := RandomNumberGenerator.new()
	var drop_seed := 1
	while drop_seed < 1000:
		probe.seed = drop_seed
		if not world.LOOT_DROP.roll_detailed(normal.drop_items, normal.is_boss, world.loot_catalog, probe, normal.monster_name).is_empty(): break
		drop_seed += 1
	check(drop_seed < 1000, "real production drop seed found")
	report.setup.drop_rng_seed = drop_seed
	normal.died.disconnect(world._on_monster_died)
	normal.died.connect(func(_actor: TwilightMonster) -> void: world.rng.seed = drop_seed)
	normal.died.connect(world._on_monster_died)
	prepare_lifecycle()
	await lifecycle_case()
	await finish()
