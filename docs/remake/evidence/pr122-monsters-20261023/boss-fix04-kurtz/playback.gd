extends SceneTree

const Motion = preload("res://scripts/animation/actor_motion.gd")
const BASE = "res://docs/remake/evidence/pr122-monsters-20261023/boss-fix04-kurtz/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "candidate.json"))
	var actor: Dictionary = register.actors["monster:커츠"]
	var loaded: Dictionary = {}
	for track: Dictionary in actor.tracks:
		var path: String = "res://" + str(track.texture)
		if not loaded.has(path):
			var im: Image = Image.load_from_file(path)
			assert(im != null and not im.is_empty())
			var tex: ImageTexture = ImageTexture.create_from_image(im)
			tex.take_over_path(path)
			loaded[path] = tex
	var profile: Resource = load(actor.native_profile)
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(profile != null and frames != null)
	assert(frames.get_animation_names().size() == actor.native_track_count)
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	var reports: Array = []
	var total_seen: int = 0
	for track: Dictionary in actor.tracks:
		var key: String = str(track.animation)
		var role: String = str(track.role)
		var facing: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(str(track.direction))
		var aim := Vector2.RIGHT.rotated(facing * PI / 4.0)
		assert(frames.has_animation(key))
		assert(frames.get_frame_count(key) == track.geometry.frames.size())
		var motion = Motion.new()
		motion.profile = profile
		motion.face(aim)
		motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		if role == "attack":
			motion.begin_attack(0.6, aim, "heavy")
		elif role == "hit":
			motion.react(false, -aim)
		elif role == "death":
			motion.die()
		var seen: Dictionary = {}
		var samples: int = 0
		for tick: int in range(360):
			motion.advance(1.0 / 120.0, aim * profile.reference_speed if role == "run" else Vector2.ZERO)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			if str(sprite.animation) != key:
				continue
			assert(not sprite.flip_h and sprite.rotation == 0.0)
			var pose: Texture2D = frames.get_frame_texture(key, sprite.frame)
			assert(pose != null and pose.get_width() > 0 and pose.get_height() > 0)
			var foot := Vector2(0, pose.get_height() / 8.0)
			assert((sprite.position + foot * sprite.scale).length() < 0.001)
			seen[sprite.frame] = true
			samples += 1
		assert(seen.size() == frames.get_frame_count(key), key + " missing a motion phase")
		total_seen += seen.size()
		sprite.animation = key
		sprite.frame = 0
		sprite.frame_progress = 0.0
		sprite.speed_scale = 1.0
		sprite.play(key)
		await create_timer(0.16).timeout
		assert(sprite.frame > 0 or sprite.frame_progress > 0.0)
		reports.append({"animation": key, "poses": seen.size(), "motion_samples": samples,
			"engine_clock_play_1x_progress": true, "mirror_or_warp": false, "virtual_ground_anchor": "PASS"})
	var result := {"engine": Engine.get_version_info().string, "profile": actor.native_profile,
		"SpriteFrames": actor.frames, "clips": actor.native_track_count, "source_poses_examined": total_seen,
		"PNG_count": loaded.size(), "all_declared_phases_ActorMotion": "PASS", "AnimatedSprite2D_play_1x": "PASS",
		"reports": reports, "missing_required_tracks": actor.missing_required_tracks,
		"default_Main": "NOT_RUN", "quality_or_contact_approval": false, "new_approvals": 0}
	var path: String = OS.get_environment("KURTZ_PLAYBACK_REPORT")
	assert(not path.is_empty())
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("KURTZ_BOSS_REPAIR_PLAYBACK_PASS clips=", actor.native_track_count, " poses=", total_seen)
	quit(0)
