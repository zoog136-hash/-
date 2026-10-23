extends SceneTree
const Motion = preload("res://scripts/animation/actor_motion.gd")
const Profile = preload("res://scripts/animation/animation_profile.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/evidence/pr122-monsters-20261023/boss-fix06-queen-n/candidate.json"))
	var actor: Dictionary = candidate.actors["monster:얼음 여왕"]
	var track: Dictionary = actor.tracks[0]
	var textures: Dictionary = {}
	for frame: Dictionary in track.geometry.frames:
		var path: String = "res://" + str(frame.texture)
		if textures.has(path): continue
		var im: Image = Image.load_from_file(path)
		assert(im != null and not im.is_empty())
		var tex := ImageTexture.create_from_image(im)
		tex.take_over_path(path)
		textures[path] = tex
	var frames: SpriteFrames = load(actor.frames)
	var profile: Resource = load(actor.native_profile)
	assert(profile is Profile and frames != null and frames.get_animation_names().size() == 1)
	assert(frames.has_animation("run_6") and frames.get_frame_count("run_6") == 6)
	assert(frames.get_meta("twilight_canvas_size") == Vector2(256, 256))
	assert(bool(frames.get_meta("twilight_native_locomotion_staging")))
	assert(not actor.production_connected and not actor.detailed_completed)
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	var motion = Motion.new()
	motion.profile = profile
	var seen: Dictionary = {}
	for tick: int in range(360):
		motion.advance(1.0/120.0, Vector2.UP * profile.reference_speed * 1.25)
		motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		assert(motion.state == "run" and motion.facing8 == 6)
		assert(str(motion._resolved_key) == "run_6" and str(sprite.animation) == "run_6")
		assert(not sprite.flip_h and sprite.rotation == 0.0)
		var frame: Dictionary = track.geometry.frames[sprite.frame]
		var pose: Texture2D = frames.get_frame_texture("run_6", sprite.frame)
		var logical := Vector2(float(frame.canvas_size[0]), float(frame.canvas_size[1]))
		assert(pose is AtlasTexture and pose.get_size() == logical)
		assert(sprite.scale.is_equal_approx(Vector2.ONE * profile.pixel_scale * Vector2(256,256) / logical))
		assert((sprite.position + Vector2(0,pose.get_height()/8.0) * sprite.scale).length() < 0.001)
		seen[sprite.frame] = true
	assert(seen.size() == 6)
	var engine_seen: Dictionary = {0:true}
	sprite.frame_changed.connect(func() -> void: engine_seen[sprite.frame] = true)
	sprite.animation = "run_6"
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.speed_scale = 1.0
	sprite.play("run_6")
	await create_timer(0.65).timeout
	assert(engine_seen.size() == 6)
	sprite.pause()
	var report := {"schema":"pr122-queen-N-single-playback-v1","engine":Engine.get_version_info().string,
		"clips":1,"source_poses":6,"new_source_poses":3,"reused_source_poses":3,"PNG_sources":textures.size(),
		"actual_ActorMotion_all6":"PASS","actual_engine_clock_AnimatedSprite2D_all6":"PASS",
		"per_frame_virtual_canvas_and_common_scale":"PASS","registered_ground":"PASS_METADATA_ONLY",
		"source_RGBA_preservation":"VERIFIED_BY_BUILDER","actual_anatomical_moving_ground_contact":"NOT_VERIFIED",
		"default_Main":"NOT_RUN","production_connected":false,"new_approvals":0}
	var output: String = OS.get_environment("QUEEN_N_PLAYBACK_REPORT")
	assert(not output.is_empty())
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("QUEEN_N_RUN_PLAYBACK_PASS clips=1 phases=6 new=3 reused=3 approvals=0")
	quit(0)
