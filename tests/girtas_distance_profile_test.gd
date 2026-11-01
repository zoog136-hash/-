extends SceneTree
const Profile = preload("res://scripts/animation/skin_pilot/girtas_ground_motion.gd")
func _init() -> void:
	var motion := Profile.new()
	motion.configure_run()
	assert(absf(motion.stride_distance/210.0-0.5)<0.000001)
	assert(absf(motion.stride_distance*motion.stance_fraction-36.96)<0.000001)
	for speed in [100.0,210.0,231.0,300.0]:
		var delta := 0.0001
		var p := motion.stance_fraction*0.25
		var a := motion.sample(p)
		var b := motion.sample(p+speed*delta/motion.stride_distance)
		assert(absf(b.feet[0].x-a.feet[0].x+speed*delta)<0.00001)
	for i in range(1000):
		var pose := motion.sample(float(i)/1000.0)
		for side in range(2):
			var hip: Vector2=pose.hip+Vector2(-1 if side==0 else 1,0).rotated(pose.pelvis_angle)
			assert(absf(hip.distance_to(pose.knees[side])-16.0)<0.001)
			assert(absf(pose.knees[side].distance_to(pose.feet[side])-16.0)<0.001)
	print("GIRTAS_DISTANCE_PROFILE_OK longer_cycle=true contact_matches_actual_speed=true fixed_lengths=true")
	quit()
