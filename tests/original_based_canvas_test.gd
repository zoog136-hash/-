extends SceneTree

const MOTION = preload("res://scripts/animation/actor_motion.gd")
const FRAMES = preload("res://assets/actors/eight_direction/original_based/ghost/SpriteFrames.tres")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("ORIGINAL_CANVAS_FAIL: " + label)

func _initialize() -> void:
	for animated: bool in [false, true]:
		var sprite: Node2D = AnimatedSprite2D.new() if animated else Sprite2D.new()
		root.add_child(sprite)
		if animated: (sprite as AnimatedSprite2D).sprite_frames = FRAMES
		for direction: int in range(8):
			var motion := MOTION.new()
			motion.frame_source = FRAMES
			motion.profile.layout = "directional8"
			motion.profile.frames_path = FRAMES.resource_path
			motion.profile.authored_motion_weight = 0.
			motion.profile.hit_recoil = 0.
			motion.profile.sprite_offset = Vector2(0, -32) * .85
			motion.face(Vector2.RIGHT.rotated(float(direction) * PI / 4.))
			for phase: int in range(4):
				if phase == 1: motion.react()
				if phase == 3: motion.die()
				motion.advance(.2 if phase == 2 else .01, Vector2.ZERO)
				for _repeat: int in range(3):
					motion.apply(sprite, Vector2.ONE * .85)
					var texture: Texture2D = FRAMES.get_frame_texture((sprite as AnimatedSprite2D).animation, (sprite as AnimatedSprite2D).frame) if animated else (sprite as Sprite2D).texture
					var canvas: Vector2 = texture.get_size()
					check((canvas * sprite.scale).is_equal_approx(Vector2(256, 256) * .85), "equal displayed canvas through resolution changes")
					var foot: Vector2 = sprite.position + Vector2(0, canvas.y / 8.) * sprite.scale
					check(foot.is_zero_approx(), "fixed world foot through resolution changes")
					check(sprite.scale.x > 0. and sprite.scale.y > 0. and is_zero_approx(sprite.rotation), "positive upright scale")
				var expected: String = ["idle", "hit", "idle", "death"][phase] + "_" + str(direction)
				check(motion._resolved_key == expected, "original action/facing retained: " + expected)
		sprite.free()
	print("ORIGINAL_CANVAS_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	if failures.is_empty(): print("ORIGINAL_CANVAS_OK")
	quit(0 if failures.is_empty() else 1)
