extends SceneTree

const Motion = preload("res://scripts/animation/actor_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_monk_staging.json"))
	var actor: Dictionary = register.actors["monster:알비노 몽크"]
	var track: Dictionary = actor.tracks[0]
	var texture := ImageTexture.create_from_image(Image.load_from_file("res://" + str(track.texture)))
	texture.take_over_path("res://" + str(track.texture))
	var profile: Resource = load(actor.native_profile)
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(frames != null and frames.get_animation_names().size() == 1)
	assert(frames.has_animation("run_3") and frames.get_frame_count("run_3") == 6)
	assert(not frames.has_animation("walk_3") and not frames.has_animation("run_4"))
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	var motion = Motion.new()
	motion.profile = profile
	var seen: Dictionary = {}
	var aim := Vector2(-1, 1).normalized()
	for tick: int in range(180):
		motion.advance(1.0 / 60.0, aim * profile.reference_speed * 1.25)
		motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		assert(motion.state == "run" and motion.facing8 == 3 and str(sprite.animation) == "run_3")
		assert(not sprite.flip_h and sprite.rotation == 0.0)
		var pose: Texture2D = frames.get_frame_texture("run_3", sprite.frame)
		var foot := Vector2(0, pose.get_height() / 8.0)
		assert((sprite.position + foot * sprite.scale).length() < .001)
		seen[sprite.frame] = true
	assert(seen.size() == 6 and frames.get_animation_loop("run_3"))
	var missing = Motion.new()
	missing.profile = profile
	missing.advance(.2, Vector2.RIGHT * profile.reference_speed * 1.25)
	missing.apply(sprite, Vector2.ONE * profile.pixel_scale)
	assert(missing._resolved_role == "unavailable")
	var report := {"engine": Engine.get_version_info().string, "clips": 1, "poses": 6,
		"PNG_and_SpriteFrames_loading": "PASS", "actual_ActorMotion_all_phases": "PASS",
		"SW_no_mirror_no_warp_canvas_foot": "PASS", "missing_direction_no_proxy_fallback": "PASS",
		"actual_hind_support_and_identity_review": "HOLD", "default_Main": "NOT_RUN", "new_approvals": 0}
	var destination: String = OS.get_environment("PR122_MONK_REPORT")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_MONK_SW_RUN_PLAYBACK_PASS clips=1 poses=6 approvals_added=0")
	quit(0)
