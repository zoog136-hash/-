extends SceneTree

const MOTION = preload("res://scripts/animation/actor_motion.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
const SCOPE = preload("res://scripts/animation/transformation_movement_scope.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var policy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCOPE.MONSTER_POLICY_PATH))
	var kinds: Dictionary = {"normal": 0, "boss": 0}
	for row: Dictionary in policy.monsters:
		assert(not SCOPE.requires_walk(row.id), "Known monster must support new RUN-only motion: " + str(row.id))
		kinds[row.kind] += 1
	assert(kinds.normal == 258 and kinds.boss == 60)
	var preserved: Dictionary = {"transform:393": true, "transform:267": true,
		"transform:413": false, "monster:unknown": true, "boss:unknown": true,
		"class:0": true, "transform:999999": true}
	for key: String in preserved:
		assert(SCOPE.requires_walk(key) == preserved[key], "Existing transform/unknown contract changed: " + key)
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_animation_staging.json"))
	var playback_cases: int = 0
	var run_tracks: int = 0
	var actors_tested: int = 0
	for key: String in register.actors:
		var actor: Dictionary = register.actors[key]
		var textures: Array[ImageTexture] = []
		var loaded_textures: Dictionary = {}
		for track: Dictionary in actor.tracks:
			if loaded_textures.has(str(track.texture)):
				continue
			var texture := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://" + str(track.texture))))
			texture.take_over_path("res://" + str(track.texture))
			textures.append(texture)
			loaded_textures[str(track.texture)] = true
		var profile: Resource = load(actor.native_profile)
		var frames: SpriteFrames = load(actor.frames) as SpriteFrames
		actors_tested += 1
		var sprite := AnimatedSprite2D.new()
		root.add_child(sprite)
		sprite.sprite_frames = frames
		for track: Dictionary in actor.tracks:
			if track.role != "run":
				continue
			run_tracks += 1
			var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
			for speed: float in [100.0, 124.0, 262.5]:
				var motion = MOTION.new()
				motion.profile = profile
				var prior_scope = MOTION.new()
				prior_scope.profile = profile.duplicate()
				prior_scope.profile.profile_id = "monster:unknown"
				var velocity := Vector2.RIGHT.rotated(direction * PI / 4.0) * speed
				var seen: Dictionary = {}
				for tick: int in range(240):
					motion.advance(1.0 / 60.0, velocity)
					prior_scope.advance(1.0 / 60.0, velocity)
					assert(is_equal_approx(motion.gait, prior_scope.gait))
					assert(is_equal_approx(motion.move_ratio, prior_scope.move_ratio))
					assert(is_equal_approx(motion.attack_elapsed, prior_scope.attack_elapsed))
					motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
					assert(motion.state == "run" and motion._resolved_role == "run")
					assert(str(sprite.animation) == str(track.animation) and not sprite.flip_h)
					seen[sprite.frame] = true
				assert(seen.size() == track.geometry.frames.size())
				motion.advance(0.1, Vector2.ZERO)
				assert(motion.state == "idle")
				playback_cases += 1
		sprite.queue_free()
		await process_frame
	# A previously approved WALK-only resource keeps its exact animation and
	# frames through the existing runtime fallback; no new aliases are authored.
	var old_frames := SpriteFrames.new()
	old_frames.remove_animation("default")
	old_frames.add_animation("walk_0")
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	old_frames.add_frame("walk_0", texture)
	old_frames.add_frame("walk_0", texture)
	var old_profile = PROFILE.new()
	old_profile.profile_id = "monster:고스트"
	old_profile.layout = "directional8"
	var old_motion = MOTION.new()
	old_motion.profile = old_profile
	var old_sprite := AnimatedSprite2D.new()
	root.add_child(old_sprite)
	old_sprite.sprite_frames = old_frames
	old_motion.advance(0.1, Vector2(100, 0))
	old_motion.apply(old_sprite, Vector2.ONE)
	assert(old_motion.state == "run" and old_motion._resolved_role == "walk")
	assert(old_sprite.animation == &"walk_0" and old_frames.get_frame_count("walk_0") == 2)
	assert(not old_frames.has_animation("run_0"))
	old_sprite.queue_free()
	assert(run_tracks >= 3 and actors_tested >= 2 and playback_cases == run_tracks * 3)
	var report := {"engine": Engine.get_version_info().string, "known_monsters": 318,
		"normal": kinds.normal, "boss": kinds.boss, "real_run_playback_cases": playback_cases,
		"staged_actors": actors_tested, "authored_run_tracks": run_tracks,
		"NPC_speeds": [100, 124, 262.5], "preserved_transform_unknown_cases": preserved.size(),
		"existing_walk_fallback": "PASS", "gait_velocity_and_attack_clocks": "UNCHANGED", "new_approvals": 0}
	var destination: String = OS.get_environment("PR122_MONSTER_SCOPE_REPORT")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_MONSTER_RUN_ONLY_SCOPE_PASS monsters=318 run_cases=%d existing_walk=preserved transform_unknown=7 approvals_added=0" % playback_cases)
	quit(0)
