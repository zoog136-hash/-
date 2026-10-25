extends SceneTree

const MOTION = preload("res://scripts/animation/actor_motion.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
const SCOPE = preload("res://scripts/animation/transformation_movement_scope.gd")

func _initialize() -> void:
	var cases: Dictionary = {"transform:413": "run", "transform:393": "walk", "transform:267": "walk", "monster:413": "walk", "boss:413": "walk", "class:0": "walk", "transform:999999": "walk"}
	for key: String in cases:
		var motion = MOTION.new()
		motion.profile = PROFILE.new()
		motion.profile.profile_id = key
		motion.profile.reference_speed = 210.0
		motion.advance(0.064, Vector2(126.0, 0.0))
		assert(motion.state == cases[key], "Incorrect slow movement scope: " + key)
		assert(SCOPE.requires_walk(key) == (cases[key] == "walk"))
		motion.advance(0.064, Vector2(262.5, 0.0))
		assert(motion.state == "run")
		motion.advance(0.064, Vector2.ZERO)
		assert(motion.state == "idle")
	print("PR122_TRANSFORM_RUN_ONLY_SCOPE_PASS cases=7 slow,fast,stationary unique,boss,class,unknown_preserved approvals_added=0")
	quit(0)
