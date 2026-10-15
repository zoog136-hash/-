extends "res://tests/run_original_based_transform_batch.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_BATCH_CAPTURE_DIR
## Additive visual-controller QA in actual Main. Only inspect_poses is overridden.
## Inherited input, equipment, weapon, incoming HP, real-clock death VFX, AI,
## floor drop and manual pickup assertions run unchanged before/after this stage.
## A fresh controller per direction/role drives the actual equipped player sprite
## through public inputs at 120Hz. Whole Main is paused while rendering holds a
## sampled state across frame_post_draw and PNG I/O. This is NOT wall-time game
## performance or an HP/death/loot command. No texture/animation/frame is assigned.

const TRANSFORM_TEMPORAL_MOTION = preload("res://scripts/animation/actor_motion.gd")
const TRANSFORM_TEMPORAL_STEP := 1.0 / 120.0
const TRANSFORM_TEMPORAL_ROLES := ["idle", "walk", "attack", "hit", "death"]
var transform_temporal_wall_start: int = 0
var transform_temporal_render := false

func transform_temporal_vec(value: Vector2) -> Array:
	return [value.x, value.y]

func transform_temporal_texture_token(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		return "%s|%s|%s" % [atlas.atlas.resource_path, str(atlas.region), str(atlas.margin)]
	return texture.resource_path if texture != null else "NULL"

func transform_temporal_texture(sprite: AnimatedSprite2D) -> Texture2D:
	if not sprite.sprite_frames.has_animation(sprite.animation): return null
	return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)

func transform_temporal_local_bounds(sprite: AnimatedSprite2D, texture: Texture2D) -> Rect2:
	var rectangle := Rect2(sprite.offset - texture.get_size() * 0.5 if sprite.centered else sprite.offset, texture.get_size())
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		rectangle = Rect2(rectangle.position + atlas.margin.position, atlas.region.size)
	return rectangle

func transform_temporal_invariants(profile: TwilightAnimationProfile, sprite: AnimatedSprite2D) -> Dictionary:
	return {"hp": world.hp, "effective_max_hp": world._effective_max_hp(), "gold": world.gold,
		"inventory_sha256": JSON.stringify(world.inventory).sha256_text(),
		"equipped_items_sha256": JSON.stringify(world.equipped_items).sha256_text(),
		"equipped_catalog_sha256": JSON.stringify(world.equipped_catalog).sha256_text(),
		"attack_interval": world._normal_attack_interval(), "weapon_type": world._current_weapon_type(),
		"player_move_speed": world.player.move_speed,
		"equipment_move_speed_multiplier": world.player.equipment_move_speed_multiplier,
		"attack_speed_multiplier": world.player.attack_speed_multiplier,
		"transform_active": world.player.transform_active, "profile_instance": profile.get_instance_id(),
		"profile_id": profile.profile_id, "frames_path": profile.frames_path,
		"profile_layout": profile.layout, "motion_style": profile.motion_style,
		"floating": profile.floating, "pixel_scale": profile.pixel_scale,
		"sprite_offset": transform_temporal_vec(profile.sprite_offset),
		"movement_fps": profile.movement_fps, "reference_speed": profile.reference_speed,
		"attack_hit_ratio": profile.attack_hit_ratio, "death_duration": profile.death_duration,
		"authored_motion_weight": profile.authored_motion_weight,
		"base_scale": transform_temporal_vec(sprite.get_meta("base_scale", Vector2.ONE)),
		"sprite_frames_instance": sprite.sprite_frames.get_instance_id(),
		"real_player_strikes": strikes.size(), "real_flights": world.combat_flights.flights.size()}

func transform_temporal_position_clear() -> bool:
	var original_center := center
	for radius: float in [0.0, 240.0, 400.0, 560.0, 720.0, 960.0, 1280.0, 1600.0]:
		for direction: int in [4, 3, 5, 2, 6, 0, 1, 7]:
			var point := original_center + screen_direction(direction) * radius
			if not route_clear(point, 220.0): continue
			var envelope := Rect2(point + Vector2(-220, -280), Vector2(440, 460))
			var covered := false
			for actor: Node in world.monsters_root.get_children():
				if actor is Node2D and (actor as Node2D).is_visible_in_tree() and (actor as Node2D).global_position.distance_to(point) < 400.0:
					covered = true
					break
			if covered: continue
			world.player.position = point
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			for prop: Node2D in world.field_renderer.faded:
				if prop is Sprite2D and prop.global_position.y + 16.0 > point.y - 160.0:
					if (prop.global_transform * (prop as Sprite2D).get_rect()).intersects(envelope):
						covered = true
						break
			if not covered:
				center = point
				report.transform_temporal.review_position = {"world": transform_temporal_vec(point),
					"offset_from_gameplay_center": transform_temporal_vec(point - original_center),
					"walkable_radius": 220.0, "other_actor_clear_radius": 400.0,
					"terrain_hidden_or_modified": false, "other_actors_hidden_or_modified": false}
				return true
	return false

func transform_temporal_unoccluded(bounds: Rect2) -> bool:
	for actor: Node in world.monsters_root.get_children():
		if not actor is TwilightMonster or not (actor as TwilightMonster).is_visible_in_tree(): continue
		var monster := actor as TwilightMonster
		if monster.sprite.texture == null: continue
		var other: Rect2 = monster.sprite.global_transform * monster.sprite.get_rect()
		if other.intersects(bounds): return false
	for prop: Node2D in world.field_renderer.faded:
		if prop is Sprite2D and prop.global_position.y + 16.0 > world.player.global_position.y:
			if (prop.global_transform * (prop as Sprite2D).get_rect()).intersects(bounds): return false
	return true

func transform_temporal_snapshot(sprite: AnimatedSprite2D, motion: TwilightActorMotion, seconds: float, proof: Dictionary) -> Dictionary:
	var texture := transform_temporal_texture(sprite)
	var size := texture.get_size() if texture != null else Vector2.ZERO
	var local_origin := sprite.offset - size * 0.5 if sprite.centered else sprite.offset
	var canonical_foot := local_origin + size * Vector2(0.5, 0.625)
	var source_foot := canonical_foot
	var role := str(sprite.animation).trim_suffix("_" + str(motion.facing8))
	if role in ["cast", "ranged_attack"]: role = "attack"
	var source_record_found := false
	for frame: Dictionary in proof.get("frames", []):
		if str(frame.get("role", "")) == role and str(frame.get("direction", "")) == COMPASS[motion.facing8] and int(frame.get("phase", -1)) == sprite.frame and texture is AtlasTexture:
			var atlas := texture as AtlasTexture
			var anchor: Array = frame.get("source_anchor", [])
			if anchor.size() == 2:
				source_foot = local_origin + atlas.margin.position + Vector2(float(anchor[0]), float(anchor[1])) - atlas.region.position
				source_record_found = true
			break
	var bounds := transform_temporal_local_bounds(sprite, texture) if texture != null else Rect2()
	var world_bounds: Rect2 = sprite.global_transform * bounds
	var canonical_world := sprite.to_global(canonical_foot)
	var actual_foot_world := sprite.to_global(source_foot)
	return {"simulation_seconds": seconds, "wall_microseconds": Time.get_ticks_usec() - transform_temporal_wall_start,
		"engine_process_frame": Engine.get_process_frames(), "render_frame": Engine.get_frames_drawn(),
		"state": motion.state, "resolved_key": motion._resolved_key, "resolved_role": motion._resolved_role,
		"animation": str(sprite.animation), "frame": sprite.frame, "frame_token": transform_temporal_texture_token(texture),
		"facing": motion.facing8, "attack_elapsed": motion.attack_elapsed, "visual_progress": motion.visual_progress,
		"hit_clock": motion.hit_clock, "death_clock": motion.death_clock, "state_clock": motion.state_clock, "gait": motion.gait,
		"body_root_world": transform_temporal_vec(world.player.global_position),
		"shadow_root_world": transform_temporal_vec(world.player.get_node("GroundShadow").global_position),
		"canonical_anchor_world": transform_temporal_vec(canonical_world),
		"source_anchor_world": transform_temporal_vec(actual_foot_world), "source_anchor_record_found": source_record_found,
		"sprite_position": transform_temporal_vec(sprite.position), "sprite_scale": transform_temporal_vec(sprite.scale),
		"sprite_rotation": sprite.rotation, "sprite_alpha": sprite.modulate.a, "flip_h": sprite.flip_h, "flip_v": sprite.flip_v,
		"visible_bounds_world": [world_bounds.position.x, world_bounds.position.y, world_bounds.size.x, world_bounds.size.y]}

func transform_temporal_capture(sprite: AnimatedSprite2D, sample: Dictionary, direction: int, role: String, phase: int, marker_frame: int) -> Dictionary:
	# No controller advance or node simulation occurs between this snapshot,
	# the actual post-draw readback and synchronous PNG write.
	var texture := transform_temporal_texture(sprite)
	check(transform_temporal_texture_token(texture) == str(sample.frame_token), "atomic actual transform temporal texture")
	check(str(sprite.animation) == str(sample.animation) and sprite.frame == int(sample.frame), "atomic actual transform temporal animation/frame")
	var image := root.get_texture().get_image()
	var screen_root := world.player.get_global_transform_with_canvas().origin
	var crop := Rect2i(Vector2i(screen_root.round()) - Vector2i(352, 496), Vector2i(704, 640))
	crop.position.x = clampi(crop.position.x, 0, image.get_width() - crop.size.x)
	crop.position.y = clampi(crop.position.y, 0, image.get_height() - crop.size.y)
	check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(crop), "actual Main contains full transform temporal review crop")
	var local_bounds := transform_temporal_local_bounds(sprite, texture)
	var visible: Rect2 = sprite.get_global_transform_with_canvas() * local_bounds
	check(Rect2(crop).encloses(visible), "whole actual transform body inside temporal crop")
	check(Rect2(Vector2.ZERO, Vector2(image.get_size())).encloses(visible), "whole transform body inside actual Main viewport")
	check(transform_temporal_unoccluded(sprite.global_transform * local_bounds), "whole transform temporal body has no foreground/actor occlusion")
	var stem := "temporal-%s-%s-%d" % [COMPASS[direction], role, phase]
	var path := captures.path_join(stem + ".png")
	check(not FileAccess.file_exists(path), "fresh transform temporal capture " + stem)
	if FileAccess.file_exists(path) or not Rect2i(Vector2i.ZERO, image.get_size()).encloses(crop): return {}
	check(image.get_region(crop).save_png(path) == OK, "actual Main transform temporal PNG " + stem)
	check(transform_temporal_texture_token(transform_temporal_texture(sprite)) == str(sample.frame_token), "PNG I/O holds exact transform controller frame")
	report.screenshots.append(stem + ".png")
	var evidence := {"path": path, "sha256": FileAccess.get_sha256(path), "simulation_seconds": sample.simulation_seconds,
		"wall_microseconds": sample.wall_microseconds, "render_frame": sample.render_frame,
		"animation": sample.animation, "frame": sample.frame, "frame_token": sample.frame_token,
		"viewport_crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y],
		"visible_body_viewport": [visible.position.x, visible.position.y, visible.size.x, visible.size.y],
		"screen_body_root": transform_temporal_vec(screen_root), "viewport_size": transform_temporal_vec(Vector2(image.get_size()))}
	if direction == 2 and ((role == "idle" and phase == 0) or (role == "attack" and phase == marker_frame) or (role == "death" and phase == sprite.sprite_frames.get_frame_count(sprite.animation) - 1)):
		var full_path := captures.path_join("viewport-" + stem + ".png")
		check(not FileAccess.file_exists(full_path), "fresh full Main transform temporal capture")
		if not FileAccess.file_exists(full_path):
			check(image.save_png(full_path) == OK, "unmodified full Main temporal viewport")
			evidence.full_viewport = {"path": full_path, "sha256": FileAccess.get_sha256(full_path)}
	return evidence

func transform_temporal_role(direction: int, role: String, sprite: AnimatedSprite2D, profile: TwilightAnimationProfile, origin: Vector2, proof: Dictionary) -> Dictionary:
	var before := transform_temporal_invariants(profile, sprite)
	var frames := sprite.sprite_frames
	var motion: TwilightActorMotion = TRANSFORM_TEMPORAL_MOTION.new()
	motion.profile = profile
	world.player.motion = motion
	var markers: Array[Dictionary] = []
	var marker_listener: Callable = func(sequence_value: int) -> void:
		markers.append({"sequence": sequence_value, "attack_elapsed": motion.attack_elapsed,
			"marker_seconds": motion.attack_duration * motion.attack_hit_ratio,
			"wall_microseconds": Time.get_ticks_usec() - transform_temporal_wall_start})
	motion.strike.connect(marker_listener)
	var aim := screen_direction(direction)
	motion.face(aim)
	var velocity_input := aim * profile.reference_speed * 0.75 if role == "walk" else Vector2.ZERO
	var expected_role := role
	if role == "attack":
		var style := str(subject_spec().style)
		motion.begin_attack(world.player.attack_visual_duration, aim, style, profile.marker_for(style))
		if style == "magic" and frames.has_animation("cast_" + str(direction)): expected_role = "cast"
		elif style == "bow" and frames.has_animation("ranged_attack_" + str(direction)): expected_role = "ranged_attack"
	elif role == "hit": motion.react(false, -aim)
	elif role == "death": motion.die()
	var key := expected_role + "_" + str(direction)
	check(frames.has_animation(key), "actual equipped transform native temporal track " + key)
	if not frames.has_animation(key): motion.strike.disconnect(marker_listener); return {}
	var count := frames.get_frame_count(key)
	var minima := {"idle": 2, "walk": 3, "attack": 3, "hit": 2, "death": 3}
	check(count >= int(minima[role]), "transform native temporal role minima " + key)
	var weight := 0.0
	for index: int in range(count): weight += frames.get_frame_duration(key, index)
	var loop_seconds := weight / frames.get_animation_speed(key)
	var duration := loop_seconds * 2.2
	if role == "walk": duration = float(count) / (profile.movement_fps * 0.75) * 2.2
	elif role == "attack": duration = motion.attack_duration + 0.15
	elif role == "hit": duration = motion.hit_duration + 0.15
	elif role == "death": duration = profile.death_duration + 0.05
	world.player.position = origin - velocity_input * duration * 0.5
	if role == "walk": check(route_clear(world.player.position, 0.0) and route_clear(origin + velocity_input * duration * 0.5, 0.0), "temporal controlled walk uses unchanged walkable terrain")
	var base_scale: Vector2 = sprite.get_meta("base_scale", Vector2.ONE)
	var result := {"direction": direction, "compass": COMPASS[direction], "role": role, "expected_key": key,
		"native_frames": count, "fresh_controller_instance": motion.get_instance_id(), "actual_player_instance": world.player.get_instance_id(),
		"actual_sprite_instance": sprite.get_instance_id(), "simulation_duration_seconds": duration,
		"controller_input_velocity": transform_temporal_vec(velocity_input), "controlled_position_is_not_gameplay_input": true,
		"loop_period_seconds": duration / 2.2 if role in ["idle", "walk"] else 0.0,
		"attack_duration": motion.attack_duration, "attack_hit_ratio": motion.attack_hit_ratio,
		"hit_duration": motion.hit_duration, "death_duration": profile.death_duration,
		"markers": markers, "native_sequence": [], "samples": [], "captures": [],
		"controller_step_columns": ["simulation_seconds", "wall_microseconds", "token_index", "root_x", "root_y", "source_foot_x", "source_foot_y", "scale_x", "scale_y", "alpha", "draw_synchronized"],
		"controller_steps": [], "step_tokens": [], "maximum_canvas_error_native_pixels": 0.0, "maximum_source_foot_error_native_pixels": 0.0}
	var seen: Dictionary = {}
	var token_indices: Dictionary = {}
	var phase_spans: Dictionary = {}
	var previous_root := world.player.global_position
	var last_key := ""
	var last_frame := -1
	var last_sample_time := -1.0
	var seconds := 0.0
	var final_sample: Dictionary = {}
	while true:
		if seconds > 0.0 and role == "walk": world.player.position += velocity_input * TRANSFORM_TEMPORAL_STEP
		motion.advance(0.0 if seconds == 0.0 else TRANSFORM_TEMPORAL_STEP, velocity_input)
		motion.apply(sprite, base_scale)
		world.player.camera.force_update_scroll()
		var sample := transform_temporal_snapshot(sprite, motion, seconds, proof)
		var changed := str(sample.resolved_key) != last_key or int(sample.frame) != last_frame
		var drawn := false
		if transform_temporal_render and (changed or seconds >= duration):
			var before_draw_token := str(sample.frame_token)
			await RenderingServer.frame_post_draw
			sample = transform_temporal_snapshot(sprite, motion, seconds, proof)
			check(str(sample.frame_token) == before_draw_token, "post-draw holds controller state without phase drift " + key)
			drawn = true
		if changed or seconds - last_sample_time >= 0.05 or seconds >= duration:
			if not transform_temporal_render: await process_frame
			sample = transform_temporal_snapshot(sprite, motion, seconds, proof)
			sample.draw_synchronized = drawn
			result.samples.append(sample)
			last_sample_time = seconds
		final_sample = sample
		var token := str(sample.animation) + "|" + str(sample.frame_token)
		if not token_indices.has(token):
			token_indices[token] = result.step_tokens.size()
			result.step_tokens.append({"animation": sample.animation, "frame": sample.frame, "frame_token": sample.frame_token})
		result.controller_steps.append([seconds, sample.wall_microseconds, token_indices[token], sample.body_root_world[0], sample.body_root_world[1],
			sample.source_anchor_world[0], sample.source_anchor_world[1], sample.sprite_scale[0], sample.sprite_scale[1], sample.sprite_alpha, drawn])
		check(world.player.motion == motion and sprite == active_sprite() and sprite.sprite_frames == frames, "actual selected player/controller/resource binding retained " + key)
		check(motion.facing8 == direction and upright(sprite) and not sprite.is_playing(), "production transform facing/upright/single clock " + key)
		check(world.player.global_position.is_finite() and sprite.position.is_finite() and sprite.scale.is_finite(), "finite transform temporal body/scale " + key)
		var expected_delta := velocity_input * TRANSFORM_TEMPORAL_STEP if seconds > 0.0 else Vector2.ZERO
		check((world.player.global_position - previous_root).distance_to(expected_delta) <= 0.005, "continuous transform controlled body root " + key)
		previous_root = world.player.global_position
		check(world.player.get_node("GroundShadow").global_position.is_equal_approx(world.player.global_position), "real player ground shadow retains physical root " + key)
		var texture := transform_temporal_texture(sprite)
		check(texture != null and texture is AtlasTexture, "real native AtlasTexture selected by production controller " + key)
		if texture != null:
			var native_canvas := texture.get_size() * sprite.scale / base_scale
			var canvas_error := native_canvas.distance_to(Vector2(256, 256))
			result.maximum_canvas_error_native_pixels = maxf(float(result.maximum_canvas_error_native_pixels), canvas_error)
			check(canvas_error <= 1.0, "unchanged normalized transform canvas within one native pixel " + key)
			var source_error := (Vector2(float(sample.source_anchor_world[0]), float(sample.source_anchor_world[1])) - world.player.global_position) / base_scale
			result.maximum_source_foot_error_native_pixels = maxf(float(result.maximum_source_foot_error_native_pixels), source_error.length())
			check(bool(sample.source_anchor_record_found), "actual controller phase has an independently recorded source anchor " + key)
			check(source_error.length() <= 1.00001, "actual source sole/root registration within one native pixel " + key)
			var visible := transform_temporal_local_bounds(sprite, texture)
			var canvas_origin := sprite.offset - texture.get_size() * 0.5 if sprite.centered else sprite.offset
			check(Rect2(canvas_origin, texture.get_size()).encloses(visible), "complete actual visible body remains inside normalized source canvas " + key)
			if changed: check(transform_temporal_unoccluded(sprite.global_transform * visible), "complete controller-selected transform body unobstructed " + key)
		if str(sample.resolved_key) == key:
			check(int(sample.frame) >= 0 and int(sample.frame) < count, "resolved transform native phase range " + key)
			if changed: result.native_sequence.append(int(sample.frame))
			var phase := int(sample.frame)
			if not phase_spans.has(phase): phase_spans[phase] = {"first": seconds, "last": seconds, "steps": 0}
			phase_spans[phase].last = seconds
			phase_spans[phase].steps += 1
			if not seen.has(phase):
				seen[phase] = seconds
				report.pose_samples.append({"track": key, "frame": phase, "simulation_seconds": seconds, "selected_by": "production advance/apply"})
				if transform_temporal_render: result.captures.append(transform_temporal_capture(sprite, sample, direction, role, phase, profile.hit_frame_for(expected_role)))
		last_key = str(sample.resolved_key)
		last_frame = int(sample.frame)
		if seconds >= duration: break
		seconds += TRANSFORM_TEMPORAL_STEP
	check(seen.size() == count and seen.has(0) and is_zero_approx(float(seen.get(0, -1.0))), "all native transform phases including phase0 observed from time0 " + key)
	for phase: int in range(count):
		check(seen.has(phase), "native transform temporal phase " + key + "/" + str(phase))
		if phase_spans.has(phase): check(float(phase_spans[phase].last) > float(phase_spans[phase].first), "native phase has positive simulated duration, not single frozen still " + key + "/" + str(phase))
	var sequence: Array = result.native_sequence
	for index: int in range(1, sequence.size()):
		var expected: int = (int(sequence[index - 1]) + 1) % count if role in ["idle", "walk"] else int(sequence[index - 1]) + 1
		check(int(sequence[index]) == expected, "continuous transform phases have no skip/reversal " + key)
	if role in ["idle", "walk"]: check(sequence.size() >= count * 2, "two continuous transform native loops " + key)
	elif role == "attack":
		check(markers.size() == 1, "one QA production controller marker without gameplay damage " + key)
		if not markers.is_empty(): check(float(markers[0].attack_elapsed) >= float(markers[0].marker_seconds) and float(markers[0].attack_elapsed) - float(markers[0].marker_seconds) <= TRANSFORM_TEMPORAL_STEP + 0.00001, "unchanged production controller strike timing " + key)
		check(str(final_sample.resolved_key) == "idle_" + str(direction), "transform attack returns to exact-facing idle")
	elif role == "hit": check(str(final_sample.resolved_key) == "idle_" + str(direction), "transform hit returns to exact-facing idle")
	elif role == "death": check(motion.dead and motion.state == "corpse" and int(final_sample.frame) == count - 1, "transform controller death holds final native corpse phase")
	result.seen_phase_times = seen
	result.phase_simulation_spans = phase_spans
	check(transform_temporal_invariants(profile, sprite) == before, "QA transform visual role preserves exact profile/stats/cadence/HP/inventory " + key)
	motion.strike.disconnect(marker_listener)
	return result

func inspect_poses() -> void:
	# This is the sole inherited override. Real callbacks and lifecycle functions
	# remain in the parent test and run after all original state is restored.
	release_inputs()
	await tick(60) # Let existing production combat labels/effects expire naturally.
	report.pose_samples = []
	transform_temporal_wall_start = Time.get_ticks_usec()
	transform_temporal_render = not captures.is_empty() and DisplayServer.get_name() != "headless"
	var sprite := active_sprite()
	var original_motion: TwilightActorMotion = world.player.motion
	var profile: TwilightAnimationProfile = original_motion.profile
	var original_profile_id := "transform:" + str(subject_spec().transform_id)
	check(world.player.transform_active and profile.profile_id == original_profile_id and profile.frames_path == subject_path(), "temporal stage uses exact actually equipped production transformation")
	var frames := sprite.sprite_frames
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(subject_path().get_base_dir().path_join("provenance.json")))
	check((proof.get("target_keys", []) as Array).has(original_profile_id), "temporal source provenance binds exact production transform")
	var reference: Dictionary = proof.get("reference", {})
	check(FileAccess.get_sha256(str(reference.get("path", ""))) == str(reference.get("sha256", "missing")), "original transform reference bytes unchanged during Main temporal stage")
	var original_stats := transform_temporal_invariants(profile, sprite)
	var original_center := center
	var original_position: Vector2 = world.player.position
	var original_camera_position: Vector2 = world.player.camera.position
	var original_camera_zoom: Vector2 = world.player.camera.zoom
	var original_world_mode: int = world.process_mode
	var original_player_mode: int = world.player.process_mode
	var original_sprite_mode: int = sprite.process_mode
	var original_physics: bool = world.player.is_physics_processing()
	var original_process: bool = world.player.is_processing()
	var original_fps := Engine.max_fps
	report.transform_temporal = {"scope": "Additive120Hz QA-clocked visual playback on actual equipped Main player; separate inherited gameplay/input/HP/death-VFX/AI/loot checks remain unchanged",
		"simulation_step_seconds": TRANSFORM_TEMPORAL_STEP, "roles": [], "actual_Main_scene": "Main.tscn",
		"map": "aden_world",
		"direct_texture_animation_frame_assignment": false, "private_clock_mutation": false,
		"fresh_controller_per_direction_role": true, "same_actual_player_and_equipped_sprite": true,
		"whole_main_simulation_paused_for_visual_stage": true, "gameplay_signal_subscriber_on_QA_controller": false,
		"HP_damage_death_loot_commands_in_visual_stage": false, "wall_time_performance_claim": false,
		"rendered_native_evidence": transform_temporal_render, "inherited_real_callback_death_VFX_is_separate": true,
		"stats_before": original_stats, "restoration": {}, "completed_added": 0}
	check(transform_temporal_position_clear(), "full transform temporal walking/body envelope is on unobstructed unchanged map")
	var review_origin := world.player.position
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.process_mode = Node.PROCESS_MODE_DISABLED
	if not transform_temporal_render: Engine.max_fps = 0
	for direction: int in range(8):
		for role: String in TRANSFORM_TEMPORAL_ROLES:
			report.transform_temporal.roles.append(await transform_temporal_role(direction, role, sprite, profile, review_origin, proof))
	world.player.motion = original_motion
	world.player.position = original_position
	world.player.camera.position = original_camera_position
	world.player.camera.zoom = original_camera_zoom
	center = original_center
	original_motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
	sprite.process_mode = original_sprite_mode as Node.ProcessMode
	world.player.process_mode = original_player_mode as Node.ProcessMode
	world.process_mode = original_world_mode as Node.ProcessMode
	world.player.set_physics_process(original_physics)
	world.player.set_process(original_process)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	Engine.max_fps = original_fps
	check(world.player.motion == original_motion and original_motion.profile == profile and sprite.sprite_frames == frames, "original real gameplay controller/profile/resource restored")
	check(world.player.position == original_position and world.player.camera.position == original_camera_position and world.player.camera.zoom == original_camera_zoom, "original actual player position/camera offset/zoom restored")
	check(world.process_mode == original_world_mode and world.player.process_mode == original_player_mode and sprite.process_mode == original_sprite_mode and world.player.is_physics_processing() == original_physics and world.player.is_processing() == original_process, "original scene/player/sprite process modes restored")
	check(transform_temporal_invariants(profile, sprite) == original_stats, "all temporal playback preserves exact original gameplay stats/profile/cadence/HP/inventory")
	report.transform_temporal.stats_after = transform_temporal_invariants(profile, sprite)
	report.transform_temporal.restoration = {"motion": true, "position": true, "camera_position_zoom": true, "process_modes": true, "existing_gameplay_callbacks_continue": true}
	var native_total := 0
	var rendered_total := 0
	for entry: Dictionary in report.transform_temporal.roles:
		native_total += int(entry.get("native_frames", 0))
		for evidence: Dictionary in entry.get("captures", []):
			if evidence.has("path"): rendered_total += 1
	check(native_total == int(proof.get("distinct_pixel_frames", -1)) and native_total in [104, 112], "every actual original native transform phase receives continuous controller coverage")
	check(report.pose_samples.size() == native_total, "native transform poses counted once without idle/alias inflation")
	if transform_temporal_render: check(rendered_total == native_total, "every native transform phase drawn/captured in actual Main")
	report.transform_temporal.native_phases = native_total
	report.transform_temporal.rendered_native_phases = rendered_total
	report.transform_temporal.wall_microseconds = Time.get_ticks_usec() - transform_temporal_wall_start
