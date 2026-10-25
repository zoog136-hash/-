extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")
const CANDIDATE = "res://docs/remake/evidence/pr122-monsters-20261023/boss-fix06-queen-n/combined-output/candidate.json"
const DIRECTIONS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE))
	var actor: Dictionary = candidate.actors["monster:얼음 여왕"]
	assert(actor.native_track_count == 33 and actor.native_pose_count == 108)
	assert(actor.missing_required_tracks.is_empty())
	assert(not actor.production_connected and not actor.detailed_completed)
	var textures: Dictionary = {}
	for track: Dictionary in actor.tracks:
		for frame: Dictionary in track.geometry.frames:
			var path: String = "res://" + str(frame.get("texture", track.texture))
			if textures.has(path): continue
			var im: Image = Image.load_from_file(path)
			assert(im != null and not im.is_empty())
			var texture := ImageTexture.create_from_image(im)
			texture.take_over_path(path)
			textures[path] = texture
	var profile: Resource = load(actor.native_profile)
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(profile is Profile and frames != null)
	assert(frames.get_animation_names().size() == 33)
	assert(frames.get_meta("twilight_canvas_size") == Vector2(256, 256))
	assert(bool(frames.get_meta("twilight_native_locomotion_staging")))
	assert(frames.has_animation("run_6") and not frames.has_animation("walk_6"))
	assert(not bool(profile.get_meta("twilight_production_connected")))
	assert(absf(profile.pixel_scale - 86.0 / 140.0) < 0.000000001)
	assert(profile.sprite_offset.is_equal_approx(Vector2(0, -32.0 * profile.pixel_scale)))
	assert(profile.attack_hit_frame == 1)
	assert(candidate.all_input_AtlasTexture_and_timing_checks.size() == 33)
	for timing: Dictionary in candidate.all_input_AtlasTexture_and_timing_checks:
		var key: String = str(timing.animation)
		assert(is_equal_approx(frames.get_animation_speed(key), float(timing.FPS)))
		assert(frames.get_animation_loop(key) == bool(timing.loop))
		assert(frames.get_frame_count(key) == timing.frame_durations.size())
		for phase: int in range(timing.frame_durations.size()):
			assert(is_equal_approx(frames.get_frame_duration(key, phase), float(timing.frame_durations[phase])))
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
			assert(is_equal_approx(frames.get_animation_speed(key), float(track.animation_fps)))
			assert(frames.get_animation_loop(key) == bool(track.loop))
			for source_phase: int in range(frames.get_frame_count(key)):
				assert(is_equal_approx(frames.get_frame_duration(key, source_phase), float(track.frame_durations[source_phase])))
			var motion = Motion.new()
			motion.profile = profile
			motion.face(aim)
			motion.advance(0.2, Vector2.ZERO)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			if role == "attack":
				motion.begin_attack(1.56, aim, "magic")
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
				var expected_frame: Dictionary = track.geometry.frames[sprite.frame]
				var actual_canvas: Array = expected_frame.get("canvas_size", track.geometry.canvas_size)
				var logical_canvas := Vector2(float(actual_canvas[0]), float(actual_canvas[1]))
				var region: Array = expected_frame.region
				var margin: Array = expected_frame.margin
				var atlas: AtlasTexture = pose as AtlasTexture
				assert(atlas.region == Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3])))
				assert(atlas.margin == Rect2(float(margin[0]), float(margin[1]), float(margin[2]), float(margin[3])))
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
	assert(native_cases == 32 and death_heading_cases == 8)
	assert(native_source_poses.size() == 108 and total_phases == 136)
	var report := {"schema":"pr122-queen-combined-r002-playback-v1","engine":Engine.get_version_info().string,
		"native_clips":33,"distinct_source_poses_played":108,"total_case_phase_visits":136,
		"ActorMotion_cases":reports.size(),"ordinary_role_heading_cases":native_cases,
		"S_death_reused_for_requested_headings":death_heading_cases,"PNG_paths_loaded":textures.size(),
		"actual_ActorMotion_all108_source_poses":"PASS","AnimatedSprite2D_play_1x_engine_progress":"PASS",
		"all33_FPS_loop_frame_duration_match_frozen_inputs":"PASS",
		"all108_AtlasTexture_region_margin_per_frame_canvas":"PASS",
		"N_run6_positive_case":"PASS","SE_SW_replacements":"PASS",
		"virtual_ground_registration":"PASS_METADATA_ONLY","physical_contact_or_mythic_approval":false,
		"source_RGBA_verification":"PINNED_BY_COMPOSER","default_Main":"NOT_RUN",
		"new_approvals":0,"production_connected":false,"input_pins":candidate.input_pins,"reports":reports}
	var destination: String = OS.get_environment("QUEEN_COMBINED_R002_REPORT")
	assert(not destination.is_empty())
	var file := FileAccess.open(destination,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("QUEEN_COMBINED_R002_PLAYBACK_PASS clips=33 source_poses=108 cases=40 phase_visits=136 approvals=0")
	quit(0)
