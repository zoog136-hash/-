extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")
var textures: Array[ImageTexture] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_hold_staging.json"))
	var actor: Dictionary = register.actors["monster:알비노 피쉬맨"]
	var paths: Dictionary = {}
	for track: Dictionary in actor.tracks:
		var path: String = "res://" + str(track.texture)
		if paths.has(path): continue
		paths[path] = true
		var image := Image.load_from_file(path)
		assert(image != null and not image.is_empty())
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path(path)
		textures.append(texture)
	var profile: Resource = load(actor.native_profile)
	assert(profile is Profile and profile.profile_id == "monster:알비노 피쉬맨")
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(frames != null and frames.get_animation_names().size() == 41)
	var required_clips: int = 0
	var poses: int = 0
	var all_poses: int = 0
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	for track: Dictionary in actor.tracks:
		var count: int = track.geometry.frames.size()
		assert(frames.get_frame_count(track.animation) == count)
		all_poses += count
		if track.role == "walk":
			assert(frames.get_animation_loop(track.animation))
			continue
		var motion = Motion.new()
		motion.profile = profile
		var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
		var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
		motion.face(aim)
		motion.advance(.2, Vector2.ZERO)
		motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		if track.role == "attack": motion.begin_attack(.42, aim, "slash")
		elif track.role == "hit": motion.react(false, -aim)
		elif track.role == "death": motion.die()
		var seen: Dictionary = {}
		for tick: int in range(180 if track.role in ["idle", "run"] else (48 if track.role == "death" else 24)):
			motion.advance(1.0 / 60.0, aim * profile.reference_speed * 1.25 if track.role == "run" else Vector2.ZERO)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			if str(sprite.animation) != track.animation: continue
			assert(not sprite.flip_h and sprite.rotation == 0.0)
			var pose: Texture2D = frames.get_frame_texture(sprite.animation, sprite.frame)
			assert(pose is AtlasTexture and pose.get_width() > 0)
			var foot := Vector2(0, pose.get_height() / 8.0)
			assert((sprite.position + foot * sprite.scale).length() < .001)
			seen[sprite.frame] = true
		assert(seen.size() == count, "ActorMotion must visit all frames: " + str(track.animation))
		required_clips += 1
		poses += count
	# One new S death must resolve from all eight directions and hold its corpse.
	for direction: int in range(8):
		var motion = Motion.new()
		motion.profile = profile
		motion.face(Vector2.RIGHT.rotated(direction * PI / 4.0))
		motion.die()
		for tick: int in range(50):
			motion.advance(1.0 / 60.0, Vector2.ZERO)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		assert(str(sprite.animation) == "death_2" and sprite.frame == 2 and motion.state == "corpse")
	assert(required_clips == 33 and poses == 91 and all_poses == 115)
	var adapters: int = 0
	for key: String in register.get("family_adapters", {}):
		var adapter: Dictionary = register.family_adapters[key]
		var shared_profile: Resource = load(adapter.native_profile)
		assert(shared_profile is Profile and shared_profile.profile_id == key)
		assert(shared_profile.frames_path == profile.frames_path)
		assert(shared_profile.color_tint == Color.WHITE)
		assert(is_equal_approx(shared_profile.native_width_ratio, float(adapter.native_width_ratio)))
		assert(not adapter.production_connected and not adapter.new_approval)
		adapters += 1
	var report := {"engine": Engine.get_version_info().string, "PNG_sources": paths.size(),
		"required_clips": required_clips, "required_poses": poses, "optional_preserved_walk_clips": 8,
		"all_clips": 41, "all_poses": all_poses, "SpriteFrames_loading": "PASS",
		"actual_ActorMotion_all_required_phases": "PASS", "canvas_foot_anchor": "PASS",
		"S_death_from_eight_directions_terminal_hold": "PASS", "quality_identity_support_contact": "HOLD",
		"same_source_family_adapters_loaded": adapters, "default_Main": "NOT_RUN", "new_approvals": 0}
	var destination: String = OS.get_environment("PR122_FISHMAN_REPORT")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_FISHMAN_PLAYBACK_PASS required_clips=33 required_poses=91 preserved_walk_clips=8 all_poses=115 approvals_added=0")
	quit(0)
