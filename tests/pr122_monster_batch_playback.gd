extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_animation_staging.json"))
	var clips: int = 0
	var poses: int = 0
	var report_actors: Dictionary = {}
	for key: String in register.actors:
		if key not in ["monster:놀", "monster:얼음 여왕"]:
			continue
		var actor: Dictionary = register.actors[key]
		var textures: Array[ImageTexture] = []
		for track: Dictionary in actor.tracks:
			var image: Image = Image.load_from_file("res://" + str(track.texture))
			assert(image != null and not image.is_empty())
			var texture := ImageTexture.create_from_image(image)
			texture.take_over_path("res://" + str(track.texture))
			textures.append(texture)
		var profile: Resource = load(actor.native_profile)
		assert(profile is Profile and profile.profile_id == key)
		var frames: SpriteFrames = load(actor.frames) as SpriteFrames
		assert(frames != null and frames.get_animation_names().size() == actor.native_track_count)
		assert(not actor.production_connected and not actor.detailed_completed)
		var sprite := AnimatedSprite2D.new()
		root.add_child(sprite)
		sprite.sprite_frames = frames
		var actor_clips: int = 0
		var actor_poses: int = 0
		for track: Dictionary in actor.tracks:
			var animation: String = track.animation
			var count: int = track.geometry.frames.size()
			assert(frames.get_frame_count(animation) == count and count >= 2)
			var motion = Motion.new()
			motion.profile = profile
			var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
			var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
			var seen: Dictionary = {}
			if track.role == "attack":
				motion.begin_attack(0.42, aim, "slash")
			for tick: int in range(180 if track.role == "run" else 24):
				motion.advance(1.0 / 60.0, aim * profile.reference_speed * 1.25 if track.role == "run" else Vector2.ZERO)
				motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
				assert(str(sprite.animation) == animation and not sprite.flip_h and sprite.rotation == 0.0)
				var pose: Texture2D = frames.get_frame_texture(animation, sprite.frame)
				assert(pose is AtlasTexture and pose.get_width() > 0 and pose.get_height() > 0)
				var foot := Vector2(0, pose.get_height() / 8.0)
				assert((sprite.position + foot * sprite.scale).length() < 0.001)
				assert(sprite.scale.is_equal_approx(Vector2.ONE * profile.pixel_scale * 256.0 / pose.get_size()))
				seen[sprite.frame] = true
			assert(seen.size() == count, "Actual ActorMotion must visit every authored pose")
			if track.role == "run":
				assert(frames.get_animation_loop(animation))
			else:
				assert(not frames.get_animation_loop(animation))
				assert(profile.hit_frame_for("attack") == 1)
			clips += 1
			poses += count
			actor_clips += 1
			actor_poses += count
		# Partial source work cannot silently select the old tinted proxy.
		var missing_motion = Motion.new()
		missing_motion.profile = profile
		missing_motion.face(Vector2.LEFT)
		missing_motion.advance(1.0 / 60.0, Vector2.LEFT * profile.reference_speed * 1.25)
		missing_motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		assert(missing_motion._resolved_role == "unavailable")
		report_actors[key] = {"clips": actor_clips, "poses": actor_poses, "source_quality": "HOLD", "default_Main": "NOT_RUN"}
		sprite.queue_free()
		await process_frame
	assert(clips == 4 and poses == 21)
	var report := {"engine": Engine.get_version_info().string, "clips": clips, "poses": poses,
		"PNG_load": "PASS", "SpriteFrames_load": "PASS", "actual_ActorMotion_playback": "PASS",
		"all_authored_phases": "PASS", "canvas_foot_anchor": "PASS", "no_mirror_or_warp": "PASS",
		"support_paw_and_contact_visual_review": "HOLD", "new_approvals": 0, "actors": report_actors}
	var destination: String = OS.get_environment("PR122_MONSTER_REPORT")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_MONSTER_BATCH_PLAYBACK_PASS clips=%d poses=%d engine=%s approvals_added=0" % [clips, poses, report.engine])
	quit(0)
