extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
var failures: Array[String] = []
var assertions := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		print("EIGHT_DIRECTION_FAIL: " + label)

func run() -> void:
	for identity: Dictionary in [{"kind":"transform","sourceId":"46"}, {"kind":"monster","name":"해골 근위병"}]:
		var profile = CATALOG.for_record(str(identity.kind), identity)
		var frames = CATALOG.frames_for_profile(profile, "")
		check(frames != null and frames.get_animation_names().size() == 24, "24 native tracks " + profile.profile_id)
		if frames == null: continue
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		root.add_child(sprite)
		for direction: int in range(8):
			var aim := Vector2.from_angle(direction * PI / 4.0)
			var motion = MOTION.new()
			motion.profile = profile
			motion.face(aim)
			for role: String in ["idle", "walk", "attack"]:
				var key := "%s_%d" % [role,direction]
				check(frames.has_animation(key), profile.profile_id + " " + key)
				var unique: Dictionary = {}
				for f: int in range(frames.get_frame_count(key)):
					var texture: Texture2D = frames.get_frame_texture(key,f)
					check(texture != null and texture.get_size() == Vector2(256,256), "fixed canvas " + key)
					if texture != null:
						var pixels := texture.get_image()
						check(not pixels.is_invisible(), "nonempty " + key)
						unique[pixels.get_data().hex_encode().sha256_text()] = true
				check(unique.size() == (8 if role == "walk" else 4), "actual distinct poses " + key)
			motion.advance(.25, aim * profile.reference_speed)
			motion.apply(sprite,Vector2.ONE * profile.pixel_scale)
			check(sprite.animation == "walk_" + str(direction), "8-way velocity to artwork")
			check(not sprite.flip_h and is_zero_approx(sprite.rotation), "no mirrored/rotated direction")
			check(sprite.position.is_equal_approx(profile.sprite_offset), "stable foot offset")
			motion.advance(.2,Vector2.ZERO)
			motion.apply(sprite,Vector2.ONE * profile.pixel_scale)
			check(sprite.animation == "idle_" + str(direction), "walk settles to directional idle")
			for duration: float in [1.44,.72,.18]:
				for step: float in [1.0/60.0,.12,.4]:
					var strikes: Array[int] = []
					var callback: Callable = func(id: int) -> void: strikes.append(id)
					motion.strike.connect(callback)
					var seq: int = motion.begin_attack(duration,aim,"slash",.44)
					var clock := 0.0
					while clock < duration + step:
						motion.advance(step,Vector2.ZERO)
						motion.apply(sprite,Vector2.ONE * profile.pixel_scale)
						clock += step
					check(strikes == [seq], "one strike at speed/frame skip " + str([direction,duration,step]))
					motion.strike.disconnect(callback)
			motion.begin_attack(.72,aim,"slash",.44)
			motion.advance(.72*.43,Vector2.ZERO)
			motion.apply(sprite,Vector2.ONE * profile.pixel_scale)
			check(sprite.frame < 2, "windup precedes contact")
			motion.advance(.72*.02,Vector2.ZERO)
			motion.apply(sprite,Vector2.ONE * profile.pixel_scale)
			check(sprite.frame == 2 and sprite.animation == "attack_"+str(direction), "hit pose and marker share clock")
			motion.cancel_attack()
			motion.advance(.2,Vector2.ZERO)
			motion.apply(sprite,Vector2.ONE * profile.pixel_scale)
			check(sprite.animation == "idle_"+str(direction), "cancel settles without stale swing")
		sprite.free()
	print("EIGHT_DIRECTION_RESULT " + JSON.stringify({"assertions":assertions,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
