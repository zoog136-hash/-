extends "res://tests/original_based_transform_temporal_main_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR122_GAIT_CAPTURE_DIR
# Source-only, single-direction authoring preview. This never invokes the production
# importer or approves source identity, opposite support, all8views or run.
const PREVIEW_FIXTURE := "res://docs/remake/evidence/pr122-remaining106/batch07/reaper-male-E-preview.json"
const PREVIEW_STEP := 1.0 / 120.0
var preview_fixture: Dictionary = {}
var preview_rows: Array[Dictionary] = []
var preview_direction := 0

func preview_track() -> String:
	return str(preview_fixture.get("role", "walk")) + "_" + str(preview_direction)

func preview_baseline_track() -> String:
	return "walk_" + str(preview_direction)

func transform_temporal_position_clear() -> bool:
	if super.transform_temporal_position_clear(): return true
	# Keep the same220px walkability,440x460 body envelope and400px actor
	# exclusion as the shared helper. Renewed shorelines need denser search.
	var original_center := center
	for radius: int in range(0, 3280, 80):
		for heading: int in range(64):
			var point := original_center + Vector2.from_angle(TAU * float(heading) / 64.0) * float(radius)
			if not route_clear(point, 220.0): continue
			var covered := false
			for actor: Node in world.monsters_root.get_children():
				if actor is Node2D and (actor as Node2D).is_visible_in_tree() and (actor as Node2D).global_position.distance_to(point) < 400.0:
					covered = true
					break
			if covered: continue
			world.player.position = point
			world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			var envelope := Rect2(point + Vector2(-220, -280), Vector2(440, 460))
			if not RENDERED_PROP_QA.clear_bounds(world.field_renderer, envelope): continue
			for prop: Node2D in world.field_renderer.faded:
				if prop is Sprite2D and prop.global_position.y + 16.0 > point.y - 160.0:
					if (prop.global_transform * (prop as Sprite2D).get_rect()).intersects(envelope):
						covered = true
						break
			if covered: continue
			center = point
			report.transform_temporal.review_position = {"world": transform_temporal_vec(point),
				"walkable_radius": 220, "other_actor_clear_radius": 400, "body_envelope": [440, 460],
				"terrain_hidden_or_modified": false, "other_actors_hidden_or_modified": false, "dense_search_only": true}
			return true
	return false

func subject_path() -> String:
	return str(preview_fixture.get("original_resource", "res://assets/actors/eight_direction/original_based/reaper_male/SpriteFrames.tres"))

func preview_token(texture: Texture2D) -> String:
	if texture is AtlasTexture and (texture as AtlasTexture).atlas.has_meta("pr122_source_sha256"):
		var atlas := texture as AtlasTexture
		return "%s|%s|%s" % [str(atlas.atlas.get_meta("pr122_source_sha256")), str(atlas.region), str(atlas.margin)]
	return transform_temporal_texture_token(texture)

func preview_preservation() -> void:
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(preview_fixture.source_preservation_manifest)))
	var entries: Array = proof.get("preserved_files", proof.get("files", []))
	check(not entries.is_empty(), "original production preservation manifest is nonempty")
	for entry: Dictionary in entries:
		var path := "res://" + str(entry.path)
		check(FileAccess.file_exists(path) and FileAccess.get_sha256(path) == str(entry.sha256), "original production bytes preserved " + path)

func preview_frames(original: SpriteFrames) -> SpriteFrames:
	var candidate := SpriteFrames.new()
	candidate.clear_all()
	for track: String in original.get_animation_names():
		candidate.add_animation(track)
		candidate.set_animation_loop(track, original.get_animation_loop(track))
		candidate.set_animation_speed(track, original.get_animation_speed(track))
		for phase: int in range(original.get_frame_count(track)):
			candidate.add_frame(track, original.get_frame_texture(track, phase), original.get_frame_duration(track, phase))
	if candidate.has_animation(preview_track()):
		candidate.clear(preview_track())
	else:
		candidate.add_animation(preview_track())
		candidate.set_animation_loop(preview_track(), true)
		candidate.set_animation_speed(preview_track(), original.get_animation_speed(preview_baseline_track()))
	var tokens: Dictionary = {}
	for entry: Dictionary in preview_fixture.frames:
		var path := str(entry.file)
		check(FileAccess.get_sha256(path) == str(entry.source_sha256), "unchanged authored whole PNG " + path)
		var image := Image.load_from_file(path)
		check(image != null and not image.is_empty(), "real source PNG decoded " + path)
		if image == null or image.is_empty(): continue
		var geometry: Dictionary = entry.geometry
		# JSON numbers decode as floats; compare exact numeric dimensions rather
		# than Array element types (int1536 versus float1536.0).
		check(float(image.get_width()) == float(geometry.image_size[0])
			and float(image.get_height()) == float(geometry.image_size[1]), "exact source dimensions " + path)
		var texture := ImageTexture.create_from_image(image)
		texture.set_meta("pr122_source_sha256", str(entry.source_sha256))
		var frame: Dictionary = geometry.frames[0]
		var region: Array = frame.region
		var margin: Array = frame.margin
		if str(preview_fixture.role) == "run":
			margin = entry.ground_registration.margin
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
		atlas.margin = Rect2(float(margin[0]), float(margin[1]), float(margin[2]), float(margin[3]))
		atlas.filter_clip = true
		var token := preview_token(atlas)
		check(not tokens.has(token), "each candidate frame binds a distinct real PNG/region")
		tokens[token] = true
		candidate.add_frame(preview_track(), atlas)
	check(candidate.get_frame_count(preview_track()) == 6 and original.get_frame_count(preview_baseline_track()) == int(preview_fixture.get("baseline_walk_frames", 2)), "six directional candidates and unchanged original native track")
	candidate.set_meta("twilight_canvas_size", Vector2(256, 256))
	for track: String in original.get_animation_names():
		if track == preview_track(): continue
		check(candidate.get_frame_count(track) == original.get_frame_count(track), "all other native counts preserved " + track)
		for phase: int in range(original.get_frame_count(track)):
			check(candidate.get_frame_texture(track, phase) == original.get_frame_texture(track, phase)
				and candidate.get_frame_duration(track, phase) == original.get_frame_duration(track, phase), "unchanged original texture and duration " + track + "/" + str(phase))
	return candidate

func preview_capture(stem: String, sprite: AnimatedSprite2D) -> Dictionary:
	var token := preview_token(transform_temporal_texture(sprite))
	var phase := sprite.frame
	await RenderingServer.frame_post_draw
	check(preview_token(transform_temporal_texture(sprite)) == token and sprite.frame == phase, "draw and source metadata held atomically " + stem)
	var texture := transform_temporal_texture(sprite)
	var visible: Rect2 = sprite.get_global_transform_with_canvas() * transform_temporal_local_bounds(sprite, texture)
	check(root.get_visible_rect().encloses(visible), "complete source body in actual Main viewport " + stem)
	check(transform_temporal_unoccluded(sprite.global_transform * transform_temporal_local_bounds(sprite, texture)), "actual streamed map and actors do not cover source " + stem)
	var image := root.get_texture().get_image()
	var screen_root := world.player.get_global_transform_with_canvas().origin
	var crop := Rect2i(Vector2i(screen_root.round()) - Vector2i(352, 496), Vector2i(704, 640))
	crop.position.x = clampi(crop.position.x, 0, image.get_width() - crop.size.x)
	crop.position.y = clampi(crop.position.y, 0, image.get_height() - crop.size.y)
	check(Rect2(crop).encloses(visible), "whole visible source remains inside fixed diagnostic window " + stem)
	var path := captures.path_join(stem + ".png")
	check(not FileAccess.file_exists(path), "capture never overwrites " + stem)
	if FileAccess.file_exists(path): return {}
	check(image.get_region(crop).save_png(path) == OK, "actual Main readback saved " + stem)
	var result := {"path": path, "sha256": FileAccess.get_sha256(path), "phase": phase, "token": token,
		"root_world": transform_temporal_vec(world.player.global_position),
		"visible_viewport": [visible.position.x, visible.position.y, visible.size.x, visible.size.y],
		"crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y],
		"viewport": [image.get_width(), image.get_height()], "camera_zoom": transform_temporal_vec(world.player.camera.zoom)}
	if stem.ends_with("1_00-0"):
		var full := captures.path_join(stem + "-full.png")
		check(not FileAccess.file_exists(full) and image.save_png(full) == OK, "original complete Main viewport " + stem)
		result.full_viewport = {"path": full, "sha256": FileAccess.get_sha256(full)}
	return result

func preview_role(label: String, frames: SpriteFrames, profile: TwilightAnimationProfile, ratio: float) -> Dictionary:
	var sprite := active_sprite()
	sprite.sprite_frames = frames
	var base_scale: Vector2 = sprite.get_meta("base_scale", Vector2.ONE)
	var motion := TRANSFORM_TEMPORAL_MOTION.new()
	motion.profile = profile
	world.player.motion = motion
	motion.face(screen_direction(preview_direction))
	var expected_track := preview_baseline_track() if label.begins_with("original") else preview_track()
	var count := frames.get_frame_count(expected_track)
	var velocity_ratio := ratio * float(preview_fixture.get("velocity_ratio", 1.0))
	var velocity_input := screen_direction(preview_direction) * profile.reference_speed * velocity_ratio
	var duration := float(count) / (profile.movement_fps * velocity_ratio) * 2.2
	var start := center - velocity_input * duration * 0.5
	var result := {"mode": label, "speed_ratio": ratio, "frames": count, "movement_fps": profile.movement_fps,
		"cycle_seconds": float(count) / (profile.movement_fps * velocity_ratio), "velocity_ratio": velocity_ratio,
		"expected_track": expected_track, "samples": [], "native_sequence": [], "captures": []}
	var seen: Dictionary = {}
	var prior := -1
	for step: int in range(int(ceil(duration / PREVIEW_STEP)) + 1):
		var seconds := minf(float(step) * PREVIEW_STEP, duration)
		world.player.position = start + velocity_input * seconds
		motion.advance(0.0 if step == 0 else PREVIEW_STEP, velocity_input)
		motion.apply(sprite, base_scale)
		var texture := transform_temporal_texture(sprite)
		check(sprite.animation == expected_track and motion.facing8 == preview_direction and upright(sprite) and not sprite.is_playing(), "production controller owns source direction/frame clock " + label)
		if str(preview_fixture.role) == "run": check(motion.state == "run", "production controller selects genuine run state " + label)
		check(texture != null and texture is AtlasTexture, "real full source atlas selected " + label)
		if texture == null: break
		var canvas_error := (texture.get_size() * sprite.scale / base_scale).distance_to(Vector2(256, 256))
		check(canvas_error <= 1.0, "unchanged normalized canvas within one native pixel " + label)
		var local_origin := sprite.offset - texture.get_size() * 0.5 if sprite.centered else sprite.offset
		var foot := sprite.to_global(local_origin + texture.get_size() * Vector2(0.5, 0.625))
		check(((foot - world.player.global_position) / base_scale).length() <= 1.00001, "nominal authored root registration within one native pixel " + label)
		check(route_clear(world.player.position, 0.0), "unchanged map route at every simulation step " + label)
		result.samples.append({"seconds": seconds, "phase": sprite.frame, "root": transform_temporal_vec(world.player.position),
			"canvas_error": canvas_error, "token": preview_token(texture)})
		if sprite.frame != prior:
			result.native_sequence.append(sprite.frame)
			prior = sprite.frame
		if not seen.has(sprite.frame):
			seen[sprite.frame] = true
			world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			var stem := "%s-%s-%d" % [label, ("%.2f" % ratio).replace(".", "_"), sprite.frame]
			result.captures.append(await preview_capture(stem, sprite))
	check(seen.size() == count, "every native source frame rendered at speed " + label + "/" + str(ratio))
	for index: int in range(1, result.native_sequence.size()):
		check(int(result.native_sequence[index]) == (int(result.native_sequence[index - 1]) + 1) % count, "chronological cyclic native frame order " + label)
	return result

func preview_actual_input(candidate: SpriteFrames, profile: TwilightAnimationProfile, original_motion: TwilightActorMotion) -> Dictionary:
	# Real Input -> player physics -> collision movement -> production controller.
	# Readbacks hold only the currently observed frame, with no performance claim.
	var sprite := active_sprite()
	var original_frames := sprite.sprite_frames
	var original_profile := world.player.transform_profile
	sprite.sprite_frames = candidate
	world.player.transform_profile = profile
	original_motion.profile = profile
	world.player.motion = original_motion
	world.player.cancel_attack()
	world.player.clear_click_path()
	world.player.position = center - screen_direction(preview_direction) * 100.0
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	var before := world.player.position
	var result := {"scope": "real production Input/physics; isolated " + str(COMPASS[preview_direction]) + " candidate", "physics_ticks": 48,
		"input_actions": ACTIONS[preview_direction], "direction_index": preview_direction,
		"samples": [], "captures": [], "native_sequence": [], "wall_time_performance_claim": false}
	var seen: Dictionary = {}
	var prior := -1
	for action: String in ACTIONS[preview_direction]: Input.action_press(action)
	for step: int in range(48):
		await tick()
		if sprite.animation != preview_track(): continue
		check(upright(sprite) and world.player.motion.facing8 == preview_direction, "real input keeps selected direction and upright source")
		if str(preview_fixture.role) == "run": check(world.player.motion.state == "run", "real keyboard selects dedicated run without gameplay speed changes")
		check(route_clear(world.player.position, 0.0), "real input remains on unchanged walkable map")
		result.samples.append({"tick": step, "phase": sprite.frame, "root": transform_temporal_vec(world.player.position),
			"animation": str(sprite.animation), "token": preview_token(transform_temporal_texture(sprite))})
		if sprite.frame != prior:
			result.native_sequence.append(sprite.frame)
			prior = sprite.frame
		if not seen.has(sprite.frame):
			seen[sprite.frame] = true
			var prior_mode: int = world.process_mode
			world.process_mode = Node.PROCESS_MODE_DISABLED
			world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			result.captures.append(await preview_capture("actual-input-" + str(sprite.frame), sprite))
			world.process_mode = prior_mode as Node.ProcessMode
	release_inputs()
	var displacement := world.player.position - before
	check(displacement.length() > 10.0 and displacement.normalized().dot(screen_direction(preview_direction)) > 0.995, "real production input moves physical player in selected direction")
	check(seen.size() == 6, "all six real source frames actually drawn during production keyboard movement")
	result.displacement = transform_temporal_vec(displacement)
	result.observed_native_frames = seen.size()
	world.player.transform_profile = original_profile
	original_motion.profile = original_profile
	sprite.sprite_frames = original_frames
	await tick(6)
	return result

func run() -> void:
	out = OS.get_environment("TWILIGHT_PR122_GAIT_REPORT")
	captures = OS.get_environment("TWILIGHT_PR122_GAIT_CAPTURE_DIR")
	check(OS.get_environment("TWILIGHT_PR122_GAIT_ISOLATED") == "1" and active_save_files().is_empty(), "explicit fresh isolated user environment")
	check(not out.is_empty() and not captures.is_empty() and not FileAccess.file_exists(out) and not DirAccess.dir_exists_absolute(captures), "fresh non-overwriting report and capture paths")
	check(DisplayServer.get_name() != "headless", "actual OpenGL Main viewport required")
	if not failures.is_empty(): print("PR122_REAPER_GAIT_PREVIEW_REFUSED " + JSON.stringify(failures)); quit(1); return
	DirAccess.make_dir_recursive_absolute(captures)
	var fixture_path := OS.get_environment("TWILIGHT_PR122_GAIT_FIXTURE")
	if fixture_path.is_empty(): fixture_path = PREVIEW_FIXTURE
	preview_fixture = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(bool(preview_fixture.prototype_only) and not bool(preview_fixture.production_applied) and not bool(preview_fixture.final_model_approval), "unapproved source preview cannot promote to production")
	check(str(preview_fixture.key) in ["transform:258", "transform:288"], "only the two representative locomotion source identities")
	preview_direction = COMPASS.find(str(preview_fixture.get("direction", "")))
	check(preview_direction >= 0 and str(preview_fixture.get("role", "")) in ["walk", "run"], "explicit canonical locomotion direction")
	if str(preview_fixture.role) == "run":
		check(str(preview_fixture.get("ground_registration_contract", "")) == "QA_ONLY_BOUNDED_AIRBORNE_V1"
			and float(preview_fixture.get("velocity_ratio", 0.0)) == 1.5, "explicit QA-only run ground registration and genuine run speed")
	if not failures.is_empty(): print("PR122_REAPER_GAIT_PREVIEW_REFUSED " + JSON.stringify(failures)); quit(1); return
	preview_preservation()
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world, str(preview_fixture.get("job", "사신"))), "real Main production class entry")
	world.hud.class_selected.emit(3)
	world.hud._hide_aux_panels()
	world.save_timer = -10000.0
	world.rng.seed = 20261013
	world._set_map("aden_world", false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	world.player.set_auto_enabled(false)
	var weapon: Dictionary = world._find_catalog_item_record("배틀 사이드")
	check(not weapon.is_empty(), "existing DB scythe equipment")
	world._equip_or_acquire_item(weapon, true)
	var transform: Dictionary = {}
	for record: Dictionary in world.catalog_db["변신"]:
		if "transform:" + str(record.get("sourceId", "")) == str(preview_fixture.key): transform = record; break
	check(not transform.is_empty(), "existing representative transformation DB identity")
	world._equip_catalog("변신", transform)
	await tick(14)
	center = find_clearing()
	check(center.is_finite(), "real map clearing exists")
	if not center.is_finite(): await finish(); return
	report.transform_temporal = {}
	check(transform_temporal_position_clear(), "entire walk and source body envelope clear on unchanged map")
	var deadline := Time.get_ticks_msec() + 5000
	while not world.hud.message_label.text.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(world.hud.message_label.text.is_empty(), "normal equipment notice expires without hiding HUD")
	var sprite := active_sprite()
	var original_motion: TwilightActorMotion = world.player.motion
	var original_profile: TwilightAnimationProfile = original_motion.profile
	var original_frames: SpriteFrames = sprite.sprite_frames
	var original_transform_profile: TwilightAnimationProfile = world.player.transform_profile
	check(original_profile.profile_id == str(preview_fixture.key) and original_profile.frames_path == subject_path(), "real equipped original representative body")
	var candidate := preview_frames(original_frames)
	var candidate_profile := original_profile.duplicate(true) as TwilightAnimationProfile
	# Six genuine source candidates share the original total cycle duration.
	# This presentation-only local clone is never saved or applied to 7other views.
	var baseline_frames := original_frames.get_frame_count(preview_baseline_track())
	candidate_profile.movement_fps = original_profile.movement_fps * 6.0 / float(baseline_frames)
	check(is_equal_approx(6.0 / candidate_profile.movement_fps, float(baseline_frames) / original_profile.movement_fps), "total cycle duration preserved with genuinely new phase inputs")
	var original_stats := transform_temporal_invariants(original_profile, sprite)
	var original_world_mode: int = world.process_mode
	var original_player_mode: int = world.player.process_mode
	var original_sprite_mode: int = sprite.process_mode
	report.scope = str(preview_fixture.key) + " " + str(COMPASS[preview_direction]) + " " + str(preview_fixture.role) + " source authoring: actual Main controller playback, not final identity/gait/8view/combat/device approval"
	report.source_preview = {"prototype_only": true, "production_applied": false, "completed_added": 0,
		"direction": COMPASS[preview_direction], "role": preview_fixture.role, "direction_index": preview_direction, "track": preview_track(),
		"scene": "Main.tscn", "map": "aden_world", "normal_camera_zoom": transform_temporal_vec(world.player.camera.zoom),
		"QA_clock_hz": 120, "wall_time_performance_claim": false, "terrain_hidden_or_modified": false,
		"visual_quality": "HOLD: original model/gear proportions, near-far cycle, full8walk and8run tracks not approved", "modes": [], "baseline_frames": baseline_frames}
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.process_mode = Node.PROCESS_MODE_DISABLED
	var original_label := "original" + str(baseline_frames)
	for label: String in [original_label, "candidate6"]:
		for ratio: float in [0.75, 1.0, 1.5]:
			report.source_preview.modes.append(await preview_role(label, original_frames if label == original_label else candidate,
				original_profile if label == original_label else candidate_profile, ratio))
	world.player.motion = original_motion
	world.player.transform_profile = original_transform_profile
	sprite.sprite_frames = original_frames
	world.player.position = center
	original_motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
	sprite.process_mode = original_sprite_mode as Node.ProcessMode
	world.player.process_mode = original_player_mode as Node.ProcessMode
	world.process_mode = original_world_mode as Node.ProcessMode
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	report.source_preview.actual_input = await preview_actual_input(candidate, candidate_profile, original_motion)
	check(transform_temporal_invariants(original_profile, sprite) == original_stats, "original gameplay stats/profile/cadence/HP/inventory and controller restored")
	preview_preservation()
	report.source_preview.restored_original_controller_profile_frames = true
	report.source_preview.Android_real_device = "NOT_RUN"
	await finish()
