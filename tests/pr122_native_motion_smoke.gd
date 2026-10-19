extends SceneTree
const Profile = preload("res://scripts/animation/animation_profile.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var motion_script: Script = load("res://scripts/animation/actor_motion.gd")
	if motion_script == null or not motion_script.can_instantiate():
		push_error("PR122_NATIVE_MOTION_LOAD_FAILED")
		quit(1)
		return
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var checked: int = 0
	for key: String in register.actors:
		var actor: Dictionary = register.actors[key]
		var textures: Array[ImageTexture] = []
		for track: Dictionary in actor.tracks:
			var texture: ImageTexture = ImageTexture.create_from_image(Image.load_from_file("res://" + str(track.texture)))
			texture.take_over_path("res://" + str(track.texture))
			textures.append(texture)
		var profile: Resource = load(actor.native_profile)
		var frames: SpriteFrames = load(profile.frames_path) as SpriteFrames
		assert(profile is Profile and profile.profile_id == key)
		assert(profile.color_tint == Color.WHITE and profile.authored_motion_weight == 0.0)
		assert(not bool(profile.get_meta("twilight_production_connected")))
		assert(not bool(profile.get_meta("twilight_detailed_completed")))
		var sprite := AnimatedSprite2D.new()
		root.add_child(sprite)
		sprite.sprite_frames = frames
		for track: Dictionary in actor.tracks:
			var motion: RefCounted = motion_script.new()
			motion.profile = profile
			var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
			var velocity: Vector2 = Vector2.RIGHT.rotated(float(direction) * PI / 4.0) * profile.reference_speed
			velocity *= 0.6 if track.role == "walk" else 1.25
			var seen: Dictionary = {}
			for tick: int in range(120):
				motion.advance(1.0 / 60.0, velocity)
				motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
				assert(motion.state == track.role and motion.facing8 == direction)
				assert(str(sprite.animation) == track.animation)
				assert(not sprite.flip_h and sprite.rotation == 0.0)
				assert(sprite.scale.is_equal_approx(Vector2.ONE * profile.pixel_scale))
				var foot_local: Vector2 = Vector2(0, float(actor.foot[1]) - float(actor.canvas_size[1]) / 2.0)
				assert((sprite.position + foot_local * sprite.scale).is_equal_approx(Vector2.ZERO))
				seen[sprite.frame] = true
			assert(seen.size() == 6)
			checked += 1
		sprite.queue_free()
		await process_frame
	assert(checked == 9)
	print("PR122_NATIVE_ACTOR_MOTION_PASS tracks=%d cases=direction,walk,run,all_phases,foot_anchor,native_color,no_mirror,no_warp engine=%s approvals_added=0" % [checked, Engine.get_version_info().string])
	quit(0)
