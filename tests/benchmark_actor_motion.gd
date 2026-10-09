extends SceneTree

## Identical CPU sampling for the baseline/follow-up. Not a hardware FPS claim.
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var report: Dictionary = {"engine":Engine.get_version_info().string, "note":"CPU-only motion advance/apply; 256 actors, 5 warmed repetitions, 360 ticks each"}
	for kind: String in ["classes", "monsters"]:
		var actors: Array[Node2D] = []
		var motions: Array[TwilightActorMotion] = []
		for i: int in range(256):
			var motion: TwilightActorMotion = MOTION.new()
			motion.profile = PROFILE.new()
			var sprite: Node2D
			if kind == "classes":
				var animated: AnimatedSprite2D = AnimatedSprite2D.new()
				animated.sprite_frames = CATALOG.frames("res://assets/sprites/classes/warrior.png", "class5")
				motion.profile.layout = "class5"
				motion.profile.dedicated_attack = true
				sprite = animated
			else:
				var still: Sprite2D = Sprite2D.new()
				still.texture = load("res://assets/sprites/monsters/monster_0.png")
				sprite = still
			motion.face(Vector2.from_angle(i * PI / 4.0))
			actors.append(sprite)
			motions.append(motion)
		var samples: Array[float] = []
		for repetition: int in range(6):
			var start: int = Time.get_ticks_usec()
			for tick: int in range(360):
				for i: int in range(actors.size()):
					var motion: TwilightActorMotion = motions[i]
					if tick % 60 == 0: motion.begin_attack(0.65, motion.direction, "slash", 0.44)
					motion.advance(1.0 / 60.0, Vector2.ZERO if motion.active else motion.direction * 210.0)
					motion.apply(actors[i], Vector2.ONE)
			if repetition > 0: samples.append(float(Time.get_ticks_usec() - start) / 360000.0)
		samples.sort()
		report[kind] = {"median_ms_per_256_actor_tick":samples[2], "samples_ms":samples}
		for actor: Node2D in actors: actor.free()
	var output: String = str(OS.get_environment("TWILIGHT_MOTION_BENCHMARK"))
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("ACTOR_MOTION_BENCHMARK ", JSON.stringify(report))
	quit()
