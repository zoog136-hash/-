extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")
const CANDIDATE = "res://docs/remake/evidence/pr122-monsters-20261023/boss-repair-session/queen-combined-candidate.json"
const DIRECTIONS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE))
	var actor: Dictionary = candidate.actors["monster:얼음 여왕"]
	assert(actor.native_track_count == 32 and actor.native_pose_count == 102)
	assert(actor.missing_required_tracks == ["run_6"])
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
	assert(frames.get_animation_names().size() == 32)
	assert(frames.get_meta("twilight_canvas_size") == Vector2(256, 256))
	assert(bool(frames.get_meta("twilight_native_locomotion_staging")))
	assert(not frames.has_animation("run_6") and not frames.has_animation("walk_6"))
	assert(not bool(profile.get_meta("twilight_production_connected")))
	assert(absf(profile.pixel_scale - 86.0 / 140.0) < 0.000000001)
	assert(profile.sprite_offset.is_equal_approx(Vector2(0, -32.0 * profile.pixel_scale)))
	assert(profile.attack_hit_frame == 1)
	for key: String in frames.get_animation_names():
		var timing: Dictionary = actor.animation_timing_preserved[key]
		assert(is_equal_approx(frames.get_animation_speed(key), float(timing.speed)))
		assert(frames.get_animation_loop(key) == bool(timing.loop))
		assert(frames.get_frame_count(key) == timing.durations.size())
		for phase: int in range(timing.durations.size()):
			assert(is_equal_approx(frames.get_frame_duration(key, phase), float(timing.durations[phase])))
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
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
				motion.begin_attack(0.7, aim, "magic")
			elif role == "hit":
				motion.react(false, -aim)
			elif role == "death":
				motion.die()
			var seen: Dictionary = {}
			var samples := 0
			for tick: int in range(480):
				motion.advance(1.0 / 120.0, aim * profile.reference_speed * 1.25 if role == "run" else Vector2.ZERO)
				motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
				if str(sprite.animation) != key:
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
	assert(native_cases == 31 and death_heading_cases == 8)
	assert(native_source_poses.size() == 102 and total_phases == 130)
	# Initialize a genuine new N idle, then require N RUN to stay unavailable.
	# No old reversed-slit N source, old WALK, direction alias, mirror or random
	# first-clip fallback is allowed into this optional native profile.
	var north = Motion.new()
	north.profile = profile
	north.face(Vector2.UP)
	north.advance(0.2, Vector2.ZERO)
	north.apply(sprite, Vector2.ONE * profile.pixel_scale)
	assert(str(sprite.animation) == "idle_6")
	for tick: int in range(120):
		north.advance(1.0 / 120.0, Vector2.UP * profile.reference_speed * 1.25)
		north.apply(sprite, Vector2.ONE * profile.pixel_scale)
		assert(north.state == "run" and north.facing8 == 6)
		assert(str(north._resolved_role) == "unavailable" and str(north._resolved_key).is_empty())
		assert(str(sprite.animation) == "idle_6" and not sprite.flip_h)
	var report := {"schema": "pr122-queen-combined-playback-v1", "engine": Engine.get_version_info().string,
		"native_clips": 32, "distinct_source_poses_played": 102, "total_case_phase_visits": 130,
		"ActorMotion_cases": reports.size(), "ordinary_role_heading_cases": native_cases,
		"S_death_reused_for_requested_headings": death_heading_cases, "PNG_paths_loaded": textures.size(),
		"actual_ActorMotion_all_source_poses": "PASS", "AnimatedSprite2D_play_1x_engine_progress": "PASS",
		"native_N_RUN_unavailable_without_old_source_fallback": "PASS", "N_negative_test_ticks": 120,
		"common_profile_pixel_scale": profile.pixel_scale, "source_RGBA_and_geometry_preservation": "PINNED_BY_COMPOSER",
		"input_animation_FPS_loop_frame_durations_preserved": "PASS",
		"virtual_ground_registration": "PASS_METADATA_ONLY", "physical_contact_or_mythic_approval": false,
		"default_Main": "NOT_RUN", "new_approvals": 0, "production_connected": false,
		"input_pins": candidate.input_pins, "reports": reports}
	var destination: String = OS.get_environment("QUEEN_COMBINED_REPORT")
	assert(not destination.is_empty())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("QUEEN_COMBINED_PLAYBACK_PASS clips=32 source_poses=102 cases=39 death_headings=8 N_RUN=unavailable")
	quit(0)
