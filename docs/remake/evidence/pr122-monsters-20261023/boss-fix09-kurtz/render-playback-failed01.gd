extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")
const CANDIDATE = "res://docs/remake/evidence/pr122-monsters-20261023/boss-fix09-kurtz/candidate.json"
const DIRECTIONS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(512, 384)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.12, 0.15, 0.18)
	backdrop.size = Vector2(512,384)
	root.add_child(backdrop)
	var floor_line := Line2D.new()
	floor_line.add_point(Vector2(0,280))
	floor_line.add_point(Vector2(512,280))
	floor_line.default_color = Color(0.45,0.53,0.50)
	floor_line.width = 1
	root.add_child(floor_line)
	var foot_marker := Line2D.new()
	foot_marker.add_point(Vector2(256,260))
	foot_marker.add_point(Vector2(256,300))
	foot_marker.default_color = Color(0.35,0.45,0.40)
	foot_marker.width = 1
	root.add_child(foot_marker)
	var caption := Label.new()
	caption.position = Vector2(12,12)
	root.add_child(caption)
	var capture_dir := OS.get_environment("KURTZ_R003_CAPTURE_DIR")
	assert(not capture_dir.is_empty())
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var captures: Array = []
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE))
	var actor: Dictionary = candidate.actors["monster:커츠"]
	assert(actor.native_track_count == 17 and actor.native_pose_count == 58)
	assert(actor.missing_required_tracks.size() == 16)
	assert(not actor.production_connected and not actor.detailed_completed)
	var textures: Dictionary = {}
	for track: Dictionary in actor.tracks:
		var path: String = "res://" + str(track.texture)
		if not textures.has(path):
			var im: Image = Image.load_from_file(path)
			assert(im != null and not im.is_empty())
			var texture := ImageTexture.create_from_image(im)
			texture.take_over_path(path)
			textures[path] = texture
	var profile: Resource = load(actor.native_profile)
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(profile is Profile and frames != null)
	assert(frames.get_animation_names().size() == 17)
	assert(frames.get_meta("twilight_canvas_size") == Vector2(256, 256))
	assert(bool(frames.get_meta("twilight_native_locomotion_staging")))
	for excluded: Dictionary in actor.excluded_prior_tracks:
		assert(not frames.has_animation(str(excluded.animation)))
	assert(not bool(profile.get_meta("twilight_production_connected")))
	assert(absf(profile.pixel_scale - 112.0 / 96.0) < 0.000000001)
	assert(profile.sprite_offset.is_equal_approx(Vector2(0, -32.0 * profile.pixel_scale)))
	assert(profile.attack_hit_frame == 2)
	var pivot := Node2D.new()
	pivot.position = Vector2(256,280)
	root.add_child(pivot)
	var sprite := AnimatedSprite2D.new()
	pivot.add_child(sprite)
	sprite.sprite_frames = frames
	var reports: Array = []
	var total_phases := 0
	var native_source_poses: Dictionary = {}
	var native_cases := 0
	var death_heading_cases := 0
	for track: Dictionary in actor.tracks:
		var facings: Array[int] = []
		if str(track.role) == "death":
			for direction: int in range(8):
				facings.append(direction)
		else:
			facings.append(DIRECTIONS.find(str(track.direction)))
		for facing: int in facings:
			var aim := Vector2.RIGHT.rotated(facing * PI / 4.0)
			var role: String = str(track.role)
			var key: String = str(track.animation)
			var motion = Motion.new()
			motion.profile = profile
			motion.face(aim)
			motion.advance(0.2, Vector2.ZERO)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			if role == "attack":
				motion.begin_attack(0.7, aim, "heavy")
			elif role == "hit":
				motion.react(false, -aim)
			elif role == "death":
				motion.die()
			var seen: Dictionary = {}
			var samples := 0
			for tick: int in range(480):
				motion.advance(1.0 / 120.0, aim * profile.reference_speed * 1.25 if role == "run" else Vector2.ZERO)
				motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
				if str(sprite.animation) != key or str(motion._resolved_key) != key:
					continue
				assert(motion.facing8 == facing)
				assert(str(motion._resolved_key) == key)
				assert(not sprite.flip_h and sprite.rotation == 0.0)
				var pose: Texture2D = frames.get_frame_texture(key, sprite.frame)
				assert(pose is AtlasTexture and minf(pose.get_width(), pose.get_height()) > 0)
				var logical_canvas := Vector2(float(track.geometry.canvas_size[0]), float(track.geometry.canvas_size[1]))
				assert(pose.get_size() == logical_canvas)
				assert(sprite.scale.is_equal_approx(Vector2.ONE * profile.pixel_scale * Vector2(256, 256) / logical_canvas))
				var ground := Vector2(0, pose.get_height() / 8.0)
				assert((sprite.position + ground * sprite.scale).length() < 0.001)
				if str(track.texture).contains("/r003/") and not seen.has(sprite.frame):
						caption.text = "Kurtz r003 " + key + " phase " + str(sprite.frame) + " @ 1x / static-first-pass only"
						await RenderingServer.frame_post_draw
						var capture_path: String = capture_dir.path_join(key + "-" + str(sprite.frame) + ".png")
						var screenshot: Image = root.get_texture().get_image()
						assert(screenshot != null and not screenshot.is_empty())
						assert(screenshot.save_png(capture_path) == OK)
						captures.append({"animation": key, "phase": sprite.frame, "path": capture_path,
							"actual_position": [sprite.position.x,sprite.position.y], "actual_scale": [sprite.scale.x,sprite.scale.y]})
					seen[sprite.frame] = true
				native_source_poses[key + ":" + str(sprite.frame)] = true
				samples += 1
			assert(seen.size() == frames.get_frame_count(key), key + " did not play every source phase")
			total_phases += seen.size()
			if role == "death":
				death_heading_cases += 1
				assert(key == "death_2")
			else:
				native_cases += 1
			sprite.animation = key
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.speed_scale = 1.0
			sprite.play(key)
			await create_timer(0.16).timeout
			assert(sprite.frame > 0 or sprite.frame_progress > 0.0)
			reports.append({"requested_role": role, "requested_heading": DIRECTIONS[facing],
				"resolved_animation": key, "source_phases_played": seen.size(), "ActorMotion_samples": samples,
				"engine_clock_AnimatedSprite2D_1x": "PASS", "virtual_ground_and_common_scale": "PASS_METADATA_ONLY"})
	assert(native_cases == 16 and death_heading_cases == 8)
	assert(native_source_poses.size() == 58 and total_phases == 86)
	var missing_cases: Array = []
	for missing: String in actor.missing_required_tracks:
		var parts := missing.split("_")
		var role: String = parts[0]
		var facing := int(parts[1])
		var aim := Vector2.RIGHT.rotated(facing * PI / 4.0)
		var motion = Motion.new()
		motion.profile = profile
		motion.face(aim)
		motion.advance(0.2, Vector2.ZERO)
		sprite.animation = "idle_0"
		motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		if role == "attack":
			motion.begin_attack(0.7, aim, "heavy")
		elif role == "hit":
			motion.react(false, -aim)
		motion.advance(0.001, aim * profile.reference_speed * 1.25 if role == "run" else Vector2.ZERO)
		motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		assert(motion.state == role)
		assert(str(motion._resolved_role) == "unavailable" and str(motion._resolved_key).is_empty())
		assert(not sprite.flip_h and not frames.has_animation(missing))
		missing_cases.append({"requested_animation": missing, "native_role": str(motion._resolved_role),
			"fallback_used": false, "invented_track": false})
	assert(missing_cases.size() == 16)
	var report := {"schema": "pr122-kurtz-r003-playback-v1", "engine": Engine.get_version_info().string,
		"native_clips": 17, "distinct_source_poses_played": 58, "total_case_phase_visits": 86,
		"ActorMotion_cases": reports.size(), "ordinary_role_heading_cases": native_cases,
		"S_death_reused_for_requested_headings": death_heading_cases, "PNG_paths_loaded": textures.size(),
		"actual_ActorMotion_all_source_poses": "PASS", "AnimatedSprite2D_play_1x_engine_progress": "PASS",
		"missing_16_native_slots_without_old_source_fallback": "PASS", "missing_cases": missing_cases,
		"common_profile_pixel_scale": profile.pixel_scale, "source_RGBA_and_geometry_preservation": "PINNED_BY_COMPOSER",
		"animation_timing": "Same established Kurtz role-duration builder; original reused role/frame counts",
		"virtual_ground_registration": "PASS_METADATA_ONLY", "physical_contact_or_mythic_approval": false,
		"default_Main": "NOT_RUN", "new_approvals": 0, "production_connected": false,
		"candidate_path": CANDIDATE, "reports": reports, "live_render_captures": captures, "headless": false, "renderer": "OpenGL Compatibility / llvmpipe"}
	var destination: String = OS.get_environment("KURTZ_R003_RENDER_REPORT")
	assert(not destination.is_empty())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("KURTZ_R003_RENDER_PASS clips=17 source_poses=58 cases=24 death_headings=8 missing16=unavailable")
	quit(0)
