extends SceneTree
## Opt-in source durations preserve a locomotion cycle with fewer real poses.
## Gameplay cadence and every non-opted-in action keep their existing clocks.
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int, duration: float, opted_in: bool) -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	for role in ["idle", "run", "attack"]:
		var key: String = role + "_2"
		result.add_animation(key)
		result.set_animation_loop(key, role != "attack")
		result.set_animation_speed(key, 12.5)
		for phase in range(count if role == "run" else 6):
			result.add_frame(key, texture, duration if role == "run" else 1.0)
	if opted_in:
		result.set_meta("twilight_weighted_locomotion_durations", true)
	return result

func motion(source: SpriteFrames) -> TwilightActorMotion:
	var result := MOTION.new()
	result.profile = PROFILE.new()
	result.profile.profile_id = "transform:134"
	result.profile.layout = "directional8"
	result.profile.frames_path = "unit://source-duration-clock"
	result.profile.movement_fps = 12.5
	result.profile.attack_hit_frame = 3
	result.profile.action_hit_frames = {"attack": 3}
	result.frame_source = source
	result.facing8 = 2
	result.move_ratio = 1.0
	result.state = "run"
	return result

func phase_at(controller: TwilightActorMotion, sprite: AnimatedSprite2D, seconds: float) -> int:
	controller.gait = seconds * controller.profile.movement_fps
	controller.apply_frames(sprite)
	return sprite.frame

func action_trace(source: SpriteFrames) -> Dictionary:
	var controller := motion(source)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = source
	var releases: Array = []
	var released: Callable = func(sequence: int) -> void: releases.append([sequence, controller.attack_elapsed])
	controller.strike.connect(released)
	controller.begin_attack(.9, Vector2.DOWN, "slash", .44)
	var poses: Array = []
	var marker_frames: Array = []
	for tick in range(120):
		var before := releases.size()
		controller.advance(1.0 / 120.0, Vector2.ZERO)
		controller.apply_frames(sprite)
		poses.append([str(sprite.animation), sprite.frame, controller.active, controller.released])
		if releases.size() > before:
			marker_frames.append(sprite.frame)
	controller.strike.disconnect(released)
	sprite.free()
	return {"releases": releases, "poses": poses, "marker_frames": marker_frames}

func _initialize() -> void:
	for count in [4, 5]:
		var source := frames(count, 6.0 / count, true)
		var controller := motion(source)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = source
		var seconds_per_pose: float = .48 / count
		for cycle in range(4):
			for phase in range(count):
				var middle: float = cycle * .48 + (phase + .5) * seconds_per_pose
				check(phase_at(controller, sprite, middle) == phase, "Real pose midpoint and .48-second cycle: " + str(count) + "/" + str(phase))
			check(phase_at(controller, sprite, cycle * .48 + .4799) == count - 1, "Last genuine pose persists before original wrap")
			check(phase_at(controller, sprite, cycle * .48 + .4801) == 0, "Original .48-second loop wrap preserved")
		check(is_equal_approx(controller.profile.movement_fps, 12.5), "Gameplay locomotion cadence setting unchanged")
		sprite.free()
	# Uniform sources must produce exactly the same frame at every sampled time.
	for count in [4, 5, 6]:
		var original := frames(count, 1.0, false)
		var opted_in := frames(count, 1.0, true)
		var a := motion(original)
		var b := motion(opted_in)
		var first := AnimatedSprite2D.new()
		var second := AnimatedSprite2D.new()
		first.sprite_frames = original
		second.sprite_frames = opted_in
		for step in range(1001):
			var seconds := (step + .031) / 120.0
			check(phase_at(a, first, seconds) == phase_at(b, second, seconds), "Uniform original clocks remain identical")
		first.free()
		second.free()
	# Non-opted-in variable sources retain their prior count-based behavior.
	var legacy := frames(5, 1.2, false)
	var old_motion := motion(legacy)
	var old_sprite := AnimatedSprite2D.new()
	old_sprite.sprite_frames = legacy
	check(phase_at(old_motion, old_sprite, .4001) == 0, "No opt-in means no change to pre-existing variable locomotion")
	old_sprite.free()
	var baseline := action_trace(frames(5, 1.2, false))
	var opted := action_trace(frames(5, 1.2, true))
	check(baseline == opted, "Locomotion-only opt-in preserves all attack poses and authoritative clock")
	check(opted.releases.size() == 1 and opted.marker_frames == [3], "Exactly one existing strike at authored impact3")
	call_deferred("finish")

func finish() -> void:
	await process_frame
	print("WEIGHTED_LOCOMOTION_CLOCK_RESULT ", 0 if failures.is_empty() else 1, " errors=", failures.size())
	quit(0 if failures.is_empty() else 1)
