extends SceneTree

const MOTION = preload("res://scripts/animation/actor_motion.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
var failures: Array[String] = []
var cases: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		if failures.size() <= 8: print("REVIEWED_HIT_FAIL ", message)

func fixture(reviewed: bool, staging: bool = false) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var registered := {}
	for direction in range(8):
		for role in ["idle", "run", "hit", "attack", "death"]:
			var key: String = role + "_" + str(direction)
			frames.add_animation(key)
			frames.set_animation_speed(key, 27.272727273 if role == "hit" else 12.5)
			frames.set_animation_loop(key, role in ["idle", "run"])
			var entries := []
			for phase in range(6):
				var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
				image.fill(Color.from_hsv(float(phase) / 6.0, 1.0, 1.0))
				frames.add_frame(key, ImageTexture.create_from_image(image))
				entries.append({"anchor":Vector2(1, 2), "scale":Vector2.ONE, "target":Vector2.ZERO})
			registered[key] = {"semantic_review":"PASS", "frames":entries}
	if reviewed: frames.set_meta("twilight_reviewed_frame_registration", registered)
	if staging: frames.set_meta("twilight_native_locomotion_staging", true)
	return frames

func configured(frames: SpriteFrames, direction: int) -> Array:
	var motion := MOTION.new()
	motion.profile = PROFILE.new()
	motion.profile.profile_id = "transform:reviewed-hit-regression"
	motion.profile.layout = "directional8"
	motion.profile.authored_motion_weight = 0.0
	motion.profile.hit_recoil = 0.0
	motion.profile.attack_hit_frame = 3
	motion.face(Vector2.from_angle(direction * PI / 4.0))
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	motion.apply(sprite, Vector2.ONE)
	return [motion, sprite]

func run() -> void:
	for staging in [false, true]:
		var frames := fixture(not staging, staging)
		for fps in [30, 60, 120]:
			for moving in [false, true]:
				for direction in range(8):
					var pair := configured(frames, direction)
					var motion: TwilightActorMotion = pair[0]
					var sprite: AnimatedSprite2D = pair[1]
					var velocity := Vector2.from_angle(direction * PI / 4.0) * 210.0 if moving else Vector2.ZERO
					motion.react()
					check(is_equal_approx(motion.hit_duration, 0.085), "logical reaction duration changed")
					var seen := {}
					var gait_before := motion.gait
					for tick in range(fps / 2):
						motion.advance(1.0 / fps, velocity)
						motion.apply(sprite, Vector2.ONE)
						if sprite.animation == "hit_" + str(direction): seen[sprite.frame] = true
						if float(tick + 1) / fps > 0.1:
							check(is_zero_approx(motion.hit_clock), "visual hit extended gameplay clock")
					check(seen.size() == 6, "all six hit poses fps=%s moving=%s dir=%s staging=%s seen=%s" % [fps, moving, direction, staging, seen.keys()])
					check(sprite.animation == ("run_" if moving else "idle_") + str(direction), "hit did not resume same-direction locomotion/idle")
					if moving: check(motion.gait > gait_before, "hit paused locomotion cadence")
					sprite.free()
					cases += 1
	# An incoming hit must not defer an outgoing authoritative strike.
	var frames := fixture(true)
	var pair := configured(frames, 0)
	var motion: TwilightActorMotion = pair[0]
	var sprite: AnimatedSprite2D = pair[1]
	var strikes: Array[int] = []
	motion.strike.connect(func(seq: int) -> void: strikes.append(seq))
	var seq := motion.begin_attack(0.6, Vector2.RIGHT, "slash", 0.44)
	motion.advance(0.25, Vector2.RIGHT * 210.0)
	motion.react(true)
	motion.advance(0.015, Vector2.RIGHT * 210.0)
	motion.apply(sprite, Vector2.ONE)
	check(strikes == [seq] and sprite.animation == "attack_0" and sprite.frame == 3, "incoming critical hid/delayed attack marker")
	motion.advance(0.4, Vector2.ZERO)
	motion.apply(sprite, Vector2.ONE)
	check(strikes == [seq] and not motion.active, "hit changed attack count or cadence")
	motion.react()
	motion.begin_attack(0.6, Vector2.RIGHT)
	check(not motion._native_hit_presenting(), "new attack retained stale hit")
	motion.cancel_attack()
	motion.apply(sprite, Vector2.ONE)
	motion.react(true)
	check(is_equal_approx(motion.hit_duration, 0.13), "critical gameplay reaction duration changed")
	motion.profile = PROFILE.new()
	motion.advance(0.01, Vector2.ZERO)
	check(not motion._native_hit_presenting(), "form switch retained stale hit")
	motion.profile.profile_id = "transform:reviewed-hit-regression"
	motion.profile.layout = "directional8"
	motion.apply(sprite, Vector2.ONE)
	motion.react()
	motion.die()
	check(not motion._native_hit_presenting(), "death retained stale hit")
	sprite.free()
	# Legacy/unreviewed resources retain their existing reaction contract.
	for metadata: Variant in [null, "invalid", {"hit_0":{"semantic_review":"HOLD"}},
		{"hit_0":{"semantic_review":"PASS", "frames":[]}}]:
		var legacy := fixture(false)
		if metadata != null: legacy.set_meta("twilight_reviewed_frame_registration", metadata)
		pair = configured(legacy, 0)
		motion = pair[0]
		sprite = pair[1]
		motion.react()
		check(not motion._native_hit_presenting(), "unreviewed resource gained authored-hit presentation")
		motion.advance(0.1, Vector2.RIGHT * 210.0)
		motion.apply(sprite, Vector2.ONE)
		check(motion.state == "run" and is_zero_approx(motion.hit_clock), "legacy reaction changed")
		sprite.free()
	print("REVIEWED_HIT_RESULT cases=", cases, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
