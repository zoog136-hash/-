extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_queen_run_staging.json"))
	var actor: Dictionary = register.actors["monster:얼음 여왕"]
	var textures: Array[ImageTexture] = []
	for track: Dictionary in actor.tracks:
		var image: Image = Image.load_from_file("res://" + str(track.texture))
		assert(image != null and not image.is_empty())
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path("res://" + str(track.texture))
		textures.append(texture)
	var profile: Resource = load(actor.native_profile)
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(profile is Profile and frames != null)
	assert(not actor.production_connected and not actor.detailed_completed)
	assert(not bool(profile.get_meta("twilight_production_connected")))
	assert(frames.get_animation_names().size() == 6)
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	var clips: int = 0
	var poses: int = 0
	var clip_results: Array = []
	for track: Dictionary in actor.tracks:
		var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
		var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
		var motion = Motion.new()
		motion.profile = profile
		var seen: Dictionary = {}
		for tick: int in range(180):
			motion.advance(1.0 / 60.0, aim * profile.reference_speed * 1.25)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			assert(motion.state == "run" and motion.facing8 == direction)
			assert(str(sprite.animation) == track.animation)
			assert(not sprite.flip_h and sprite.rotation == 0.0)
			var pose: Texture2D = frames.get_frame_texture(track.animation, sprite.frame)
			assert(pose is AtlasTexture and pose.get_size() == Vector2(2048, 2048))
			assert(sprite.scale.is_equal_approx(Vector2.ONE * profile.pixel_scale * 256.0 / pose.get_size()))
			var canvas_foot := Vector2(0, pose.get_height() / 8.0)
			assert((sprite.position + canvas_foot * sprite.scale).length() < 0.001)
			seen[sprite.frame] = true
		assert(seen.size() == 6 and frames.get_animation_loop(track.animation))
		clips += 1
		poses += seen.size()
		clip_results.append({"direction": track.direction, "actual_phases": seen.size(), "resource": "PASS", "ActorMotion": "PASS"})
		await process_frame
	assert(clips == 6 and poses == 36)
	var report := {"engine": Engine.get_version_info().string, "clips": clips, "poses": poses,
		"PNG_load": "PASS", "SpriteFrames_load": "PASS", "actual_ActorMotion_playback": "PASS",
		"all_six_phases": "PASS", "canvas_foot_anchor": "PASS", "no_mirror_or_warp": "PASS",
		"common_uniform_scale": "PASS", "identity_direction_support_flight_visual_review": "HOLD",
		"prior_ES_scale_integration": "HOLD", "default_Main": "NOT_RUN", "new_approvals": 0, "tracks": clip_results}
	var destination: String = OS.get_environment("PR122_QUEEN_REPORT")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_QUEEN_BATCH03_PLAYBACK_PASS clips=%d poses=%d engine=%s approvals_added=0" % [clips, poses, report.engine])
	quit(0)
