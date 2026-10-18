extends "res://tests/original_based_pose_review_helper.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_TEMPORAL_CAPTURE_DIR
## Additive QA-clocked playback in the real Main scene. This is NOT the AI,
## combat, damage, loot or wall-time performance test. Those remain separate.
## Fresh real DB actors receive production MotionController inputs; only
## advance()/apply() choose their Sprite2D texture. No atlas pose is assigned.
## Every 120Hz simulation step is checked and logged. Rich observations occur
## every 0.05 simulation seconds AND on every native frame change. Draws on
## native texture changes/start/end wait for frame_post_draw with the controller
## held, so PNG and
## metadata describe the same draw, even when PNG I/O is slower than a hit.

const TEMPORAL_STEP := 1.0 / 120.0
const TEMPORAL_ROLES := ["idle", "walk", "attack", "hit", "death"]
var temporal_case: Dictionary = {}
var temporal_results: Array[Dictionary] = []
var temporal_report_path := ""
var temporal_capture_root := ""
var temporal_render := false
var temporal_wall_start: int = 0
var temporal_original_max_fps: int = 60
var temporal_player_bounds := Rect2()

func subject_name() -> String: return str(temporal_case.get("name", ""))
func subject_folder() -> String: return str(temporal_case.get("folder", ""))

func _pose_review_motion_clear(origin: Vector2) -> bool:
	# A clear stationary pose can sit beside an impassable renewed-map cell.
	# Select the location against the unchanged two-loop walk of every actual
	# direction before playback; the endpoint and per-native draw assertions
	# below remain mandatory. Never shorten the travel or bypass map physics.
	var frames: SpriteFrames = normal.motion.frame_source
	if frames == null or normal.motion.profile.movement_fps <= 0.0: return false
	for direction: int in range(8):
		var track := "walk_" + str(direction)
		if not frames.has_animation(track): return false
		var duration := float(frames.get_frame_count(track)) / (normal.motion.profile.movement_fps * 0.75) * 2.2
		var half_travel := screen_direction(direction) * normal.motion.profile.reference_speed * 0.75 * duration * 0.5
		var start := origin - half_travel
		var finish := origin + half_travel
		if not route_clear(start, 0.0) or not route_clear(finish, 0.0): return false
		if not world.field_map.line_clear(start, finish): return false
		for point: Vector2 in [start, origin, finish]:
			var body := Rect2(point + Vector2(-128, -160), Vector2(256, 176))
			if not preload("res://tests/qa_rendered_prop_clearance.gd").clear_bounds(world.field_renderer, body): return false
			for other: Node in world.monsters_root.get_children():
				if other == normal or not other is Node2D or not (other as Node2D).is_visible_in_tree(): continue
				if point.distance_squared_to((other as Node2D).global_position) < 192.0 * 192.0: return false
	return true

func temporal_safe_name(value: String) -> bool:
	if value.is_empty(): return false
	for letter: String in value:
		if not letter in "abcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true

func temporal_save_files() -> Array[String]:
	var found: Array[String] = []
	for filename: String in DirAccess.get_files_at("user://"):
		if filename.begins_with("twilight_") and filename.contains("_save"): found.append(filename)
	return found

func temporal_preserve_generated_saves(slug: String) -> void:
	var names := temporal_save_files()
	if names.is_empty(): return
	var destination := "user://temporal-preserved/" + slug
	check(not DirAccess.dir_exists_absolute(destination), "fresh generated-save preservation path " + slug)
	for filename: String in names:
		check(filename.begins_with("twilight_v20_save.json"), "only known generated case saves may move " + filename)
	if not failures.is_empty(): return
	check(DirAccess.make_dir_recursive_absolute(destination) == OK, "generated-save preservation directory")
	for filename: String in names:
		var source := "user://" + filename
		var digest := FileAccess.get_sha256(source)
		var target := destination.path_join(filename)
		check(DirAccess.rename_absolute(source, target) == OK, "preserve generated case save " + filename)
		check(FileAccess.get_sha256(target) == digest, "preserved generated save bytes " + filename)

func temporal_cases() -> Array[Dictionary]:
	var paths := OS.get_environment("TWILIGHT_PR100_TEMPORAL_CONFIGS")
	if paths.is_empty(): paths = OS.get_environment("TWILIGHT_PR100_TEMPORAL_CONFIG")
	if paths.is_empty(): paths = "res://tests/fixtures/pr100_temporal_smoke.json"
	var cases: Array[Dictionary] = []
	var slugs: Dictionary = {}
	for config_path: String in paths.split(";", false):
		var parser := JSON.new()
		check(FileAccess.file_exists(config_path) and parser.parse(FileAccess.get_file_as_string(config_path)) == OK, "valid temporal fixture " + config_path)
		if not parser.data is Dictionary or not parser.data.get("cases") is Array:
			check(false, "temporal fixture contains cases array " + config_path)
			continue
		for value: Variant in parser.data.cases:
			if not value is Dictionary:
				check(false, "temporal case is a dictionary")
				continue
			var spec: Dictionary = value
			var valid := not str(spec.get("name", "")).is_empty() and temporal_safe_name(str(spec.get("folder", ""))) and temporal_safe_name(str(spec.get("slug", "")))
			check(valid, "temporal case has subject and safe folder/slug")
			if not valid: continue
			check(not slugs.has(spec.slug), "unique temporal slug " + str(spec.slug))
			slugs[spec.slug] = true
			check(ResourceLoader.exists("res://assets/actors/eight_direction/original_based/" + str(spec.folder) + "/SpriteFrames.tres"), "existing authored resource " + str(spec.folder))
			cases.append(spec.duplicate(true))
	check(not cases.is_empty() and cases.size() <= 40, "temporal batch contains 1 to 40 subjects")
	return cases

func temporal_vec(value: Vector2) -> Array: return [value.x, value.y]

func temporal_stats(actor: TwilightMonster) -> Dictionary:
	return {"hp": actor.hp, "max_hp": actor.max_hp, "level": actor.monster_level,
		"attack": actor.attack_power, "defense": actor.defense_value, "armor_class": actor.armor_class,
		"move_speed": actor.move_speed, "attack_type": actor.attack_type, "attack_interval": actor.attack_interval,
		"visual_height": actor.visual_height, "floating": actor.motion.profile.floating,
		"profile_id": actor.motion.profile.profile_id, "frames_path": actor.motion.profile.frames_path,
		"motion_style": actor.motion.profile.motion_style, "hit_ratio": actor.motion.profile.attack_hit_ratio}

func temporal_texture_token(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		return "%s|%s|%s" % [atlas.atlas.resource_path, str(atlas.region), str(atlas.margin)]
	return texture.resource_path if texture != null else "NULL"

func temporal_snapshot(actor: TwilightMonster, simulation_seconds: float, proof: Dictionary) -> Dictionary:
	var motion := actor.motion
	var key: String = motion._resolved_key
	var index := -1
	if motion.frame_source != null and motion.frame_source.has_animation(key):
		for candidate: int in range(motion.frame_source.get_frame_count(key)):
			if motion.frame_source.get_frame_texture(key, candidate) == actor.sprite.texture:
				index = candidate
				break
	var size := actor.sprite.texture.get_size() if actor.sprite.texture != null else Vector2.ZERO
	var foot: Array = proof.get("foot", [128, 160])
	var cell: Array = proof.get("cell", [256, 256])
	var ratio := Vector2(float(foot[0]) / float(cell[0]), float(foot[1]) / float(cell[1]))
	var foot_local := actor.sprite.get_rect().position + size * ratio
	var bounds := actor.sprite.get_rect()
	if actor.sprite.texture is AtlasTexture:
		var texture := actor.sprite.texture as AtlasTexture
		bounds = Rect2(bounds.position + texture.margin.position, texture.region.size)
	var world_bounds: Rect2 = actor.sprite.global_transform * bounds
	return {"simulation_seconds": simulation_seconds,
		"wall_microseconds": Time.get_ticks_usec() - temporal_wall_start,
		"engine_process_frame": Engine.get_process_frames(), "render_frame": Engine.get_frames_drawn(),
		"state": motion.state, "resolved_key": key, "resolved_role": motion._resolved_role,
		"frame": index, "frame_token": temporal_texture_token(actor.sprite.texture),
		"facing": motion.facing8, "attack_elapsed": motion.attack_elapsed,
		"visual_progress": motion.visual_progress, "hit_clock": motion.hit_clock,
		"death_clock": motion.death_clock, "state_clock": motion.state_clock, "gait": motion.gait,
		"body_root_world": temporal_vec(actor.global_position),
		"ground_shadow_root_world": temporal_vec(actor.get_node("GroundShadow").global_position),
		"authored_anchor_world": temporal_vec(actor.sprite.to_global(foot_local)),
		"sprite_position": temporal_vec(actor.sprite.position), "sprite_scale": temporal_vec(actor.sprite.scale),
		"sprite_rotation": actor.sprite.rotation, "sprite_alpha": actor.sprite.modulate.a,
		"flip_h": actor.sprite.flip_h, "flip_v": actor.sprite.flip_v,
		"visible_bounds_world": [world_bounds.position.x, world_bounds.position.y, world_bounds.size.x, world_bounds.size.y]}

func temporal_capture(actor: TwilightMonster, sample: Dictionary, slug: String, direction: int, role: String, phase: int) -> Dictionary:
	# Caller already waited for frame_post_draw, and no advance/apply occurs
	# between the sampled metadata and this synchronous viewport readback.
	var image := root.get_texture().get_image()
	var after_token := temporal_texture_token(actor.sprite.texture)
	check(after_token == str(sample.frame_token), "atomic draw metadata/texture " + role + str(direction) + "/" + str(phase))
	var directory := temporal_capture_root.path_join(slug)
	var stem := "%s-%s-%d" % [COMPASS[direction], role, phase]
	var screen_root: Vector2 = actor.get_global_transform_with_canvas().origin
	# Fixed source-pixel viewport window per pose: resizing for contact sheets
	# happens only in the diagnostic helper, uniformly across all poses.
	# The crab's original raised pincer reaches beyond 576x480 even though
	# its complete body is inside the unchanged 1280x720 Main viewport.
	# Enlarge only this diagnostic window, retaining the full-body guard.
	var crop_rect := Rect2i(Vector2i(screen_root.round()) - Vector2i(352, 496), Vector2i(704, 640))
	# Keep the fixed-size diagnostic window inside the viewport when a walk
	# approaches its edge. Independently require the complete visible sprite
	# rectangle to fit, so this never conceals clipped source/body pixels.
	crop_rect.position.x = clampi(crop_rect.position.x, 0, image.get_width() - crop_rect.size.x)
	crop_rect.position.y = clampi(crop_rect.position.y, 0, image.get_height() - crop_rect.size.y)
	check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(crop_rect), "actual viewport contains temporal crop " + stem)
	if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(crop_rect): return {}
	var content_rect := actor.sprite.get_rect()
	if actor.sprite.texture is AtlasTexture:
		var atlas := actor.sprite.texture as AtlasTexture
		content_rect = Rect2(content_rect.position + atlas.margin.position, atlas.region.size)
	var visible_rect: Rect2 = actor.sprite.get_global_transform_with_canvas() * content_rect
	check(Rect2(crop_rect).encloses(visible_rect), "complete rendered body is inside diagnostic crop " + stem)
	var body_world: Rect2 = actor.sprite.global_transform * content_rect
	check(not temporal_player_bounds.intersects(body_world), "QA player cannot occlude actual temporal body " + stem)
	check(preload("res://tests/qa_rendered_prop_clearance.gd").clear_bounds(world.field_renderer, body_world),
		"actual streamed terrain cannot occlude any native temporal body " + stem)
	var path := directory.path_join(stem + ".png")
	check(not FileAccess.file_exists(path), "temporal evidence does not overwrite " + stem)
	if FileAccess.file_exists(path): return {}
	check(image.get_region(crop_rect).save_png(path) == OK, "actual viewport temporal crop " + stem)
	var evidence := {"path": path, "sha256": FileAccess.get_sha256(path),
		"viewport_crop": [crop_rect.position.x, crop_rect.position.y, crop_rect.size.x, crop_rect.size.y],
		"visible_body_viewport": [visible_rect.position.x, visible_rect.position.y, visible_rect.size.x, visible_rect.size.y],
		"viewport_size": temporal_vec(Vector2(image.get_size())), "screen_body_root": temporal_vec(screen_root),
		"simulation_seconds": sample.simulation_seconds, "wall_microseconds": sample.wall_microseconds,
		"render_frame": sample.render_frame, "resolved_key": sample.resolved_key, "frame": sample.frame,
		"frame_token": sample.frame_token}
	var representative := direction == 2 and ((role == "idle" and phase == 0) or (role == "attack" and phase == actor.motion.profile.hit_frame_for(str(sample.resolved_role))) or (role == "death" and phase == actor.motion.frame_source.get_frame_count(str(sample.resolved_key)) - 1))
	if representative:
		var full_path := directory.path_join("viewport-" + stem + ".png")
		check(not FileAccess.file_exists(full_path), "full viewport evidence does not overwrite " + stem)
		if not FileAccess.file_exists(full_path):
			check(image.save_png(full_path) == OK, "original full Main viewport " + stem)
			evidence.full_viewport = {"path": full_path, "sha256": FileAccess.get_sha256(full_path)}
	return evidence

func temporal_role(direction: int, role: String, origin: Vector2, proof: Dictionary) -> Dictionary:
	normal = db_actor(subject_name())
	if normal == null: return {}
	var actor := normal
	actor.position = origin
	var stats_before := temporal_stats(actor)
	var motion := actor.motion
	var frames := motion.frame_source
	check(frames != null and actor.sprite is Sprite2D, "fresh DB actor uses production Sprite2D/frame source")
	if frames == null: actor.queue_free(); await process_frame; return {}
	# This validator provides controller inputs, not a combat command. Keep
	# the fresh actor's actual HP/stats unchanged and suppress its combat signal
	# subscriber, while observing the authoritative strike signal itself.
	var release := Callable(actor, "_release_attack")
	if motion.strike.is_connected(release): motion.strike.disconnect(release)
	var markers: Array[Dictionary] = []
	motion.strike.connect(func(sequence_value: int) -> void:
		markers.append({"sequence": sequence_value, "attack_elapsed": motion.attack_elapsed,
			"marker_seconds": motion.attack_duration * motion.attack_hit_ratio,
			"wall_microseconds": Time.get_ticks_usec() - temporal_wall_start}))
	var aim := screen_direction(direction)
	motion.face(aim)
	var velocity_input := aim * motion.profile.reference_speed * 0.75 if role == "walk" else Vector2.ZERO
	var expected_role := role
	if role == "attack":
		var kind := actor.current_attack_type()
		var style: String = motion.profile.motion_style if kind == "melee" else ("magic" if kind == "magic" else "bow")
		motion.begin_attack(minf(0.68, actor.attack_interval * 0.75), aim, style, motion.profile.marker_for(style))
		if style == "magic" and frames.has_animation("cast_" + str(direction)): expected_role = "cast"
		elif style == "bow" and frames.has_animation("ranged_attack_" + str(direction)): expected_role = "ranged_attack"
	elif role == "hit": motion.react(false, -aim)
	elif role == "death": motion.die()
	var expected_key := expected_role + "_" + str(direction)
	check(frames.has_animation(expected_key), "native temporal track " + expected_key)
	if not frames.has_animation(expected_key): actor.queue_free(); await process_frame; return {}
	var count := frames.get_frame_count(expected_key)
	var weight := 0.0
	for index: int in range(count): weight += frames.get_frame_duration(expected_key, index)
	var loop_seconds := weight / frames.get_animation_speed(expected_key)
	var duration := loop_seconds * 2.2
	if role == "walk": duration = float(count) / (motion.profile.movement_fps * 0.75) * 2.2
	elif role == "attack": duration = motion.attack_duration + 0.15
	elif role == "hit": duration = motion.hit_duration + 0.15
	elif role == "death": duration = motion.profile.death_duration + 0.05
	if role == "walk":
		actor.position = origin - velocity_input * duration * 0.5
		check(route_clear(actor.position, 0.0) and route_clear(origin + velocity_input * duration * 0.5, 0.0), "QA walk endpoints retain existing walkable map")
	var role_result := {"compass": COMPASS[direction], "direction": direction, "role": role,
		"expected_key": expected_key, "native_frames": count, "fresh_actor_instance": actor.get_instance_id(),
		"controller_input_velocity": temporal_vec(velocity_input), "duration_seconds": duration,
		"attack_duration": motion.attack_duration, "attack_hit_ratio": motion.attack_hit_ratio,
		"profile_death_duration": motion.profile.death_duration, "hit_duration": motion.hit_duration,
		"loop_period_seconds": duration / 2.2 if role in ["idle", "walk"] else 0.0,
		"stats_before": stats_before, "samples": [], "native_sequence": [], "captures": [], "markers": markers,
		"animation_base_scale": temporal_vec(actor.animation_base_scale), "maximum_canvas_error_native_pixels": 0.0,
		"canvas_error_tolerance_native_pixels": 1.0,
		"step_columns": ["simulation_seconds", "wall_microseconds", "token_index", "body_root_x", "body_root_y",
			"authored_anchor_x", "authored_anchor_y", "sprite_offset_x", "sprite_offset_y", "scale_x", "scale_y", "rotation", "alpha", "facing", "draw_synchronized"],
		"step_tokens": [], "controller_steps": []}
	var token_indices: Dictionary = {}
	var seen: Dictionary = {}
	var last_index := -1
	var last_key := ""
	var last_sample_time := -1.0
	var simulation_seconds := 0.0
	var final_sample: Dictionary = {}
	var previous_root := actor.global_position
	var anchor_offsets: Array[Vector2] = []
	while true:
		if simulation_seconds > 0.0 and role == "walk": actor.position += velocity_input * TEMPORAL_STEP
		var active_velocity := velocity_input
		motion.advance(0.0 if simulation_seconds == 0.0 else TEMPORAL_STEP, active_velocity)
		motion.apply(actor.sprite, actor.animation_base_scale)
		var sample := temporal_snapshot(actor, simulation_seconds, proof)
		var key_changed := str(sample.resolved_key) != last_key or int(sample.frame) != last_index
		var draw_synchronized := false
		if temporal_render and (key_changed or simulation_seconds >= duration):
			await RenderingServer.frame_post_draw
			sample = temporal_snapshot(actor, simulation_seconds, proof)
			draw_synchronized = true
		if key_changed or simulation_seconds - last_sample_time >= 0.05 or simulation_seconds >= duration:
			# Advance/check/log every 120Hz step; hold for a real draw only
			# at actual texture transitions and the playback endpoint.
			# No native phase can skip the renderer or hide behind PNG I/O.
			if not temporal_render: await process_frame
			sample = temporal_snapshot(actor, simulation_seconds, proof)
			sample.draw_synchronized = draw_synchronized
			role_result.samples.append(sample)
			last_sample_time = simulation_seconds
		final_sample = sample
		var token: String = str(sample.resolved_key) + "|" + str(sample.frame_token)
		if not token_indices.has(token):
			token_indices[token] = role_result.step_tokens.size()
			role_result.step_tokens.append({"resolved_key": sample.resolved_key, "frame": sample.frame, "frame_token": sample.frame_token})
		role_result.controller_steps.append([simulation_seconds, sample.wall_microseconds, token_indices[token],
			sample.body_root_world[0], sample.body_root_world[1], sample.authored_anchor_world[0], sample.authored_anchor_world[1],
			sample.sprite_position[0], sample.sprite_position[1], sample.sprite_scale[0], sample.sprite_scale[1],
			sample.sprite_rotation, sample.sprite_alpha, sample.facing, draw_synchronized])
		check(sample.facing == direction and not sample.flip_h and not sample.flip_v, "production facing/no mirror " + expected_key)
		check(actor.sprite.scale.is_finite() and actor.sprite.scale.x > 0.0 and actor.sprite.scale.y > 0.0 and is_finite(actor.sprite.rotation), "finite upright scale " + expected_key)
		check(actor.global_position.is_finite() and actor.sprite.position.is_finite(), "finite temporal body root " + expected_key)
		var expected_delta := velocity_input * TEMPORAL_STEP if simulation_seconds > 0.0 else Vector2.ZERO
		check((actor.global_position - previous_root).distance_to(expected_delta) <= 0.005, "continuous controlled body root within world-coordinate float precision " + expected_key)
		check(actor.get_node("GroundShadow").global_position.is_equal_approx(actor.global_position), "ground shadow remains on physical body root " + expected_key)
		previous_root = actor.global_position
		var native_size := actor.sprite.texture.get_size() * actor.sprite.scale / actor.animation_base_scale
		if frames.has_meta("twilight_canvas_size"):
			var canvas_error := native_size.distance_to(Vector2(frames.get_meta("twilight_canvas_size")))
			role_result.maximum_canvas_error_native_pixels = maxf(float(role_result.maximum_canvas_error_native_pixels), canvas_error)
			# Imported authored profiles have weight0: their art owns deformation,
			# and controller stretch is identity. Observed float roundoff is below
			# 0.00007 native pixels; allow <=1 pixel, not a registration claim.
			check(canvas_error <= 1.0, "production virtual canvas scale remains within one native pixel " + expected_key)
		anchor_offsets.append(Vector2(float(sample.authored_anchor_world[0]), float(sample.authored_anchor_world[1])) - actor.global_position)
		if str(sample.resolved_key) == expected_key:
			check(int(sample.frame) >= 0 and int(sample.frame) < count, "actual texture belongs to resolved native track " + expected_key)
			if key_changed: role_result.native_sequence.append(int(sample.frame))
			if not seen.has(int(sample.frame)):
				seen[int(sample.frame)] = sample.simulation_seconds
				if temporal_render: role_result.captures.append(temporal_capture(actor, sample, str(temporal_case.slug), direction, role, int(sample.frame)))
		last_index = int(sample.frame)
		last_key = str(sample.resolved_key)
		if simulation_seconds >= duration: break
		simulation_seconds += TEMPORAL_STEP
	check(seen.size() == count, "all native phases observed through production controller " + expected_key)
	for phase: int in range(count): check(seen.has(phase), "temporal native phase " + expected_key + "/" + str(phase))
	var native_sequence: Array = role_result.native_sequence
	for index: int in range(1, native_sequence.size()):
		var expected: int = (int(native_sequence[index - 1]) + 1) % count if role in ["idle", "walk"] else int(native_sequence[index - 1]) + 1
		check(int(native_sequence[index]) == expected, "native phase progression has no skip/reversal " + expected_key)
	if role in ["idle", "walk"]:
		check(native_sequence.size() >= count * 2, "two continuous native loops " + expected_key)
	elif role == "attack":
		check(markers.size() == 1, "one production motion strike marker " + expected_key)
		if not markers.is_empty(): check(float(markers[0].attack_elapsed) >= float(markers[0].marker_seconds) and float(markers[0].attack_elapsed) - float(markers[0].marker_seconds) <= TEMPORAL_STEP + 0.00001, "production marker timing preserved " + expected_key)
		check(str(final_sample.resolved_key) == "idle_" + str(direction), "attack returns to same-facing idle")
	elif role == "hit": check(str(final_sample.resolved_key) == "idle_" + str(direction), "hit returns to same-facing idle")
	elif role == "death": check(motion.dead and motion.state == "corpse" and int(final_sample.frame) == count - 1, "death holds native final frame through corpse state")
	role_result.seen_phase_times = seen
	var anchor_min := Vector2.INF
	var anchor_max := -Vector2.INF
	for value: Vector2 in anchor_offsets:
		anchor_min = anchor_min.min(value)
		anchor_max = anchor_max.max(value)
	role_result.authored_anchor_offset_range = {"minimum": temporal_vec(anchor_min), "maximum": temporal_vec(anchor_max)}
	check((anchor_max - anchor_min).length() < maxf(12.0, actor.visual_height * 0.2), "bounded continuous authored support/hover projection " + expected_key)
	role_result.stats_after = temporal_stats(actor)
	check(role_result.stats_before == role_result.stats_after, "QA temporal inputs preserve actual actor stats/presentation " + expected_key)
	actor.queue_free()
	await process_frame
	return role_result

func temporal_position_player_clear(origin: Vector2) -> bool:
	# The inherited prop/monster clearing helper intentionally omits the player.
	# A long body's walk can otherwise pass behind the nearby shield. Place the
	# unchanged real player on walkable ground outside the review envelope and
	# compensate only its camera offset, retaining the same map/camera view.
	var camera_focus := origin + Vector2(-24, -32)
	var review_envelope := Rect2(origin + Vector2(-220, -260), Vector2(440, 400))
	var sprite := active_sprite()
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var size := texture.get_size()
	var local_rect := Rect2(sprite.offset - size * 0.5 if sprite.centered else sprite.offset, size)
	for direction: int in [4, 0, 6, 2, 5, 7, 3, 1]:
		var point := origin + screen_direction(direction) * 512.0
		if not route_clear(point, 0.0): continue
		world.player.position = point
		var bounds: Rect2 = sprite.global_transform * local_rect
		bounds = bounds.grow(16.0)
		if bounds.intersects(review_envelope): continue
		temporal_player_bounds = bounds
		world.player.camera.position = camera_focus - point
		report.setup.player_review_clearance = {"player_position": temporal_vec(point),
			"player_visible_bounds_world": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"review_envelope_world": [review_envelope.position.x, review_envelope.position.y, review_envelope.size.x, review_envelope.size.y],
			"player_walkable": true, "player_hidden_or_modified": false, "camera_focus": temporal_vec(camera_focus)}
		return true
	return false

func temporal_run_case(spec: Dictionary) -> void:
	var case_checks_before := checks
	var case_failures_before := failures.size()
	temporal_case = spec
	pose_review_positioned = false
	report.setup = {}
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world, "기사"), "temporal actual Main class entry")
	world.hud._hide_aux_panels()
	world.save_timer = -10000.0
	world.rng.seed = 20261015
	world._set_map("aden_world", false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	center = find_clearing()
	check(center.is_finite(), "existing map temporal clearing")
	if not center.is_finite(): world.queue_free(); await process_frame; return
	world.player.set_auto_enabled(false)
	world.player.clear_click_path()
	world.player.position = center + Vector2(-100, 0)
	world.player.camera.zoom = Vector2(2.6, 2.6)
	world.player.camera.position = Vector2(100, -32)
	normal = db_actor(subject_name())
	if normal == null: world.queue_free(); await process_frame; return
	normal.position = center + Vector2(24, 0)
	check(_position_visible_pose_review(), "temporal review position has no foreground/other actor cover")
	var origin := normal.position
	check(temporal_position_player_clear(origin), "QA player presentation is outside complete temporal walk/body envelope")
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	var expected_path := "res://assets/actors/eight_direction/original_based/" + subject_folder() + "/SpriteFrames.tres"
	check(normal.motion.profile.frames_path == expected_path, "actual DB profile uses reviewed subject resource")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_path.get_base_dir().path_join("provenance.json")))
	check((proof.get("target_keys", []) as Array).has("monster:" + subject_name()), "exact target is bound in production provenance")
	var binding := verify_reference_binding(subject_name(), proof)
	var setup_stats := temporal_stats(normal)
	normal.queue_free()
	await process_frame
	# Pause unrelated Main simulation; retain its actual map, streamed props,
	# camera, actors and HUD. This test supplies visual-controller inputs only.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var result := {"name": subject_name(), "folder": subject_folder(), "slug": spec.slug,
		"scene": "Main.tscn", "map": "aden_world", "review_position": report.setup.get("pose_review", {}),
		"player_review_clearance": report.setup.get("player_review_clearance", {}),
		"reference_binding": binding, "production_profile": setup_stats, "roles": [],
		"scope": "QA-clocked continuous production MotionController playback on fresh DB actors in actual Main; AI/combat/lifecycle and real wall-time performance excluded",
		"simulation_step_seconds": TEMPORAL_STEP, "whole_main_simulation_paused": true,
		"direct_texture_assignment": false, "combat_signal_subscriber_suppressed": true,
		"hp_damage_death_or_loot_commands": false, "fresh_actor_per_direction_role": true}
	if temporal_render: check(DirAccess.make_dir_recursive_absolute(temporal_capture_root.path_join(str(spec.slug))) == OK, "temporal case capture directory")
	for direction: int in range(8):
		for role: String in TEMPORAL_ROLES:
			result.roles.append(await temporal_role(direction, role, origin, proof))
	var case_path := temporal_report_path.get_basename() + "-cases/" + str(spec.slug) + ".json"
	check(DirAccess.make_dir_recursive_absolute(case_path.get_base_dir()) == OK, "temporal case report directory")
	check(not FileAccess.file_exists(case_path), "temporal case report does not overwrite")
	result.checks = checks - case_checks_before
	result.failures = failures.slice(case_failures_before)
	var file := FileAccess.open(case_path, FileAccess.WRITE) if not FileAccess.file_exists(case_path) else null
	check(file != null, "temporal case report writable")
	if file != null: file.store_string(JSON.stringify(result, "\t")); file.close()
	var captures_count := 0
	var native_count := 0
	for entry: Dictionary in result.roles:
		for captured: Dictionary in entry.get("captures", []):
			if captured.has("path"): captures_count += 1
		native_count += int(entry.get("native_frames", 0))
	temporal_results.append({"name": subject_name(), "slug": spec.slug, "report": case_path,
		"report_sha256": FileAccess.get_sha256(case_path), "roles": result.roles.size(), "native_phases": native_count,
		"rendered_native_phases": captures_count, "reference_binding": binding})
	world.queue_free()
	await process_frame
	world = null
	normal = null
	temporal_preserve_generated_saves(str(spec.slug))
	print("PR100_TEMPORAL_CASE " + JSON.stringify(temporal_results.back()))

func run() -> void:
	temporal_wall_start = Time.get_ticks_usec()
	temporal_original_max_fps = Engine.max_fps
	temporal_render = DisplayServer.get_name() != "headless"
	if not temporal_render: Engine.max_fps = 0
	temporal_report_path = OS.get_environment("TWILIGHT_PR100_TEMPORAL_REPORT")
	# tools/test_project.py already supplies an isolated XDG_DATA_HOME and a
	# per-test persistent report path. Reuse that evidence destination without
	# requiring changes to the existing full-suite harness.
	if temporal_report_path.is_empty() and not OS.get_environment("TWILIGHT_PR100_REPORT").is_empty():
		temporal_report_path = OS.get_environment("TWILIGHT_PR100_REPORT").get_basename() + ".temporal.json"
	if temporal_report_path.is_empty(): temporal_report_path = "user://pr100-temporal.json"
	temporal_capture_root = OS.get_environment("TWILIGHT_PR100_TEMPORAL_CAPTURE_DIR")
	var isolated_marker := OS.get_environment("TWILIGHT_PR100_TEMPORAL_ISOLATED") == "1"
	var isolated_full_suite := not OS.get_environment("TWILIGHT_PR100_REPORT").is_empty()
	check(isolated_marker or isolated_full_suite, "explicit isolated temporal invocation or existing full-suite harness")
	var xdg := OS.get_environment("XDG_DATA_HOME")
	var windows_path := OS.has_feature("windows")
	var isolated_home: bool = preload("res://tests/qa_isolated_user_path.gd").contains_user_directory(OS.get_user_data_dir(), xdg, windows_path)
	if windows_path:
		# Every Windows user-directory root must name the same isolated directory.
		var root_path := xdg.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
		var roaming := OS.get_environment("APPDATA").replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
		var local := OS.get_environment("LOCALAPPDATA").replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
		isolated_home = isolated_home and roaming == root_path and local == root_path
	check(isolated_home, "temporal user directory belongs to the explicitly isolated platform-specific root")
	check(temporal_save_files().is_empty(), "existing user saves refuse temporal test")
	check(not FileAccess.file_exists(temporal_report_path), "temporal report does not overwrite")
	if FileAccess.file_exists(temporal_report_path):
		Engine.max_fps = temporal_original_max_fps
		quit(1)
		return
	if temporal_render:
		if temporal_capture_root.is_empty(): temporal_capture_root = temporal_report_path.get_basename() + "-captures"
		check(DirAccess.make_dir_recursive_absolute(temporal_capture_root) == OK, "temporal capture root writable")
	else: check(temporal_capture_root.is_empty(), "headless smoke does not claim rendered evidence")
	var cases := temporal_cases()
	if failures.is_empty():
		for spec: Dictionary in cases:
			await temporal_run_case(spec)
			if not failures.is_empty(): break
	var summary := {"scope": "Additive QA-clocked continuous native playback in actual Main; separate unchanged AI/combat/lifecycle tests required",
		"clock": "all120Hz production advance/apply steps checked/logged; rich samples at20Hz plusnativechanges; actualdraw onnativechanges/start/end held across frame_post_draw and PNG I/O",
		"simulation_step_seconds": TEMPORAL_STEP, "wall_microseconds": Time.get_ticks_usec() - temporal_wall_start,
		"rendered": temporal_render, "wall_time_performance_claim": false, "cases": temporal_results,
		"checks": checks, "failures": failures, "user_directory": OS.get_user_data_dir(),
		"capture_root": temporal_capture_root, "direct_texture_assignment": false,
		"production_game_or_guard_changes": false, "completed_added": 0}
	DirAccess.make_dir_recursive_absolute(temporal_report_path.get_base_dir())
	var file := FileAccess.open(temporal_report_path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(summary, "\t")); file.close()
	else: failures.append("Cannot write temporal summary")
	Engine.max_fps = temporal_original_max_fps
	print("PR100_TEMPORAL_MAIN_RESULT " + JSON.stringify({"cases": temporal_results.size(), "checks": checks, "failures": failures, "report": temporal_report_path, "rendered": temporal_render}))
	if failures.is_empty(): print("PR100_TEMPORAL_MAIN_OK")
	quit(0 if failures.is_empty() else 1)
