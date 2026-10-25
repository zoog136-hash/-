extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate_path: String = OS.get_environment("PR122_ALBINO_DEMON_CANDIDATE")
	assert(not candidate_path.is_empty())
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(candidate_path))
	var key: String = "monster:알비노 데몬"
	var actor: Dictionary = register.actors[key]
	assert(actor.native_track_count == 33 and actor.native_pose_count == 107)
	assert(not actor.production_connected and not actor.detailed_completed and not actor.newly_approved)
	var textures: Array[ImageTexture] = []
	var loaded: Dictionary = {}
	for track: Dictionary in actor.tracks:
		if loaded.has(track.texture):
			continue
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path("res://" + str(track.texture)))
		assert(image != null and not image.is_empty())
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path("res://" + str(track.texture))
		textures.append(texture)
		loaded[track.texture] = true
	var profile: Resource = load(actor.native_profile)
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(profile is Profile and profile.profile_id == key and profile.pixel_scale == 2.0)
	assert(frames != null and frames.get_animation_names().size() == 33)
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	var checked: int = 0
	var poses: int = 0
	var role_counts: Dictionary = {}
	var clips: Array[Dictionary] = []
	for track: Dictionary in actor.tracks:
		var animation: String = track.animation
		var count: int = track.geometry.frames.size()
		assert(frames.get_frame_count(animation) == count)
		var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
		var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
		var motion = Motion.new()
		motion.profile = profile
		motion.face(aim)
		motion.advance(0.1, Vector2.ZERO)
		motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		var ticks: int = 240
		match str(track.role):
			"attack":
				motion.begin_attack(0.64, aim, "slash")
				ticks = 38
			"hit":
				motion.react(false, -aim)
				ticks = 12
			"death":
				motion.die()
				ticks = 120
		var seen: Dictionary = {}
		var order: Array[int] = []
		var previous: int = -1
		for tick: int in range(ticks):
			motion.advance(1.0 / 60.0, aim * 124.0 if track.role == "run" else Vector2.ZERO)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			assert(str(sprite.animation) == animation, "Wrong role/direction: " + animation)
			assert(not sprite.flip_h and sprite.rotation == 0.0)
			var pose: AtlasTexture = frames.get_frame_texture(animation, sprite.frame) as AtlasTexture
			assert(pose != null and pose.region.position.x >= 0 and pose.region.position.y >= 0)
			assert(pose.region.end.x <= pose.atlas.get_width() and pose.region.end.y <= pose.atlas.get_height())
			assert((sprite.position + Vector2(0, pose.get_height() / 8.0) * sprite.scale).length() < 0.001)
			seen[sprite.frame] = true
			if sprite.frame != previous:
				order.append(sprite.frame)
				previous = sprite.frame
		assert(seen.size() == count, "Every source pose must play: " + animation)
		assert(frames.get_animation_loop(animation) == (track.role in ["idle", "run"]))
		if track.role == "attack":
			assert(profile.hit_frame_for("attack") == 1 and seen.has(1))
		if track.role == "death":
			assert(sprite.frame == count - 1 and motion.dead and motion.begin_attack(0.64, aim) == -1)
		role_counts[track.role] = int(role_counts.get(track.role, 0)) + 1
		clips.append({"animation": animation, "source_poses": count, "seen_source_frames": seen.keys(), "frame_order": order})
		checked += 1
		poses += count
	for direction: int in range(8):
		var death = Motion.new()
		death.profile = profile
		death.face(Vector2.RIGHT.rotated(direction * PI / 4.0))
		death.die()
		for tick: int in range(120):
			death.advance(1.0 / 60.0, Vector2(124, 0))
			death.apply(sprite, Vector2.ONE * profile.pixel_scale)
			assert(sprite.animation == &"death_2" and not sprite.flip_h)
		assert(sprite.frame == 2 and death.dead and death.begin_attack(0.64, Vector2.RIGHT) == -1)
	assert(checked == 33 and poses == 107)
	assert(role_counts == {"idle": 8, "attack": 8, "hit": 8, "run": 8, "death": 1})
	var report := {"engine": Engine.get_version_info().string, "actor": key,
		"dedicated_clips": checked, "unique_source_poses_replayed": poses,
		"PNG_load": "PASS", "SpriteFrames_and_NativeProfile_load": "PASS",
		"actual_ActorMotion_playback": "PASS", "NPC_speed_124_RUN": "PASS",
		"all_107_source_poses_visited": "PASS", "all_8_attack_contact_frames_visited": "PASS",
		"canvas_foot_anchor_and_regions": "PASS", "S_death_8_headings_terminal_hold": "PASS",
		"clips": clips, "new_walk_sources": 0, "new_approvals": 0, "default_catalog_switches": 0,
		"quality_scope": "Headless real ActorMotion sequencing and geometry only; see visual-review.json for separate static observations and unresolved quality",
		"physical_support_and_real_target_contact": "NOT_REVIEWED", "default_Main": "NOT_RUN"}
	var destination: String = OS.get_environment("PR122_ALBINO_DEMON_REPORT")
	assert(not destination.is_empty())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_ALBINO_DEMON_PLAYBACK_PASS clips=33 poses=107 approvals_added=0")
	sprite.queue_free()
	quit(0)
