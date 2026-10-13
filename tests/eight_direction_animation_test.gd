extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const DIRECTION_REFERENCE = "res://tests/fixtures/skeleton_direction_reference.json"
var failures: Array[String] = []
var assertions := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		print("EIGHT_DIRECTION_FAIL: " + label)

func run() -> void:
	var direction_reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTION_REFERENCE))
	for identity: Dictionary in [{"kind":"transform","sourceId":"46"}, {"kind":"monster","name":"해골 근위병"}]:
		var profile = CATALOG.for_record(str(identity.kind), identity)
		var frames = CATALOG.frames_for_profile(profile, "")
		check(frames != null and frames.get_animation_names().size() == 40, "40 native tracks " + profile.profile_id)
		if frames == null: continue
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		root.add_child(sprite)
		for direction: int in range(8):
			var aim := Vector2.from_angle(direction * PI / 4.0)
			var motion = MOTION.new()
			motion.profile = profile
			motion.face(aim)
			for role: String in ["idle", "walk", "attack", "hit", "death"]:
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
						if f == 0 and (profile.profile_id == "monster:해골 근위병" or role == "idle"):
							# Track names alone cannot detect opposite-facing artwork.
							# Reviewed pixel references verify compass orientation
							# independently of the resource's animation names.
							var hash := HashingContext.new()
							hash.start(HashingContext.HASH_SHA256)
							hash.update(pixels.get_data())
							var reference: Dictionary = direction_reference.views if profile.profile_id == "monster:해골 근위병" else direction_reference.knight_idle_views
							check(hash.finish().hex_encode() == reference[key], "reviewed compass artwork " + profile.profile_id + " " + key)
				check(unique.size() == int({"idle":4,"walk":8,"attack":4,"hit":2,"death":6}[role]), "actual distinct poses " + key)
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
			motion.react()
			motion.advance(.045,Vector2.ZERO)
			motion.apply(sprite,Vector2.ONE*profile.pixel_scale)
			check(sprite.animation == "hit_"+str(direction) and sprite.frame == 1,"real directional hit")
			motion.die()
			motion.advance(.4,Vector2.ZERO)
			motion.apply(sprite,Vector2.ONE*profile.pixel_scale)
			check(sprite.animation == "death_"+str(direction) and sprite.frame == 3,"source-duration death halfway")
			check(is_zero_approx(sprite.rotation) and sprite.position.is_equal_approx(profile.sprite_offset),"native fall has no second root rotation")
			motion.advance(.42,Vector2.ZERO)
			motion.apply(sprite,Vector2.ONE*profile.pixel_scale)
			check(sprite.frame == 5 and motion.state == "corpse" and sprite.modulate.a>.8,"corpse holds final pose before fade")
		sprite.free()
	print("EIGHT_DIRECTION_RESULT " + JSON.stringify({"assertions":assertions,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
