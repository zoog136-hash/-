extends "res://scripts/animation/skin_pilot/shared_ground_motion.gd"
## Girtas pilot profile only. Same distance clock, stride and planted-foot path.
## Redistribute airborne recovery; never slow the shared phase or the game speed.
func sample(at_phase: float, moving: bool = true) -> Dictionary:
	var pose := super.sample(at_phase, moving)
	if not moving or not run_gait: return pose
	var reach := stride_distance * stance_fraction * 0.5
	var tangent := -stride_distance * (1.0-stance_fraction)
	for side in range(2):
		var p := fposmod(at_phase+side*0.5,1.0)
		if p < stance_fraction: continue
		var t := (p-stance_fraction)/(1.0-stance_fraction)
		# Smooth acceleration into a broad return-speed plateau. The integral
		# preserves travel and matches the planted-foot velocity at both ends.
		var ramp := 0.22
		var area := 1.0-ramp
		var integral := t-ramp*0.5
		if t < ramp:
			var u := t/ramp
			integral = ramp*(u*u*u-0.5*u*u*u*u)
		elif t > 1.0-ramp:
			var u := (1.0-t)/ramp
			integral = area-ramp*(u*u*u-0.5*u*u*u*u)
		pose.feet[side].x = -reach+tangent*t+(2.0*reach-tangent)*integral/area
		# Preserve the existing lift clearance and reduce boot rotation only.
		pose.feet[side].y = -3.0-swing_height*pow(sin(PI*t),0.8)
		pose.foot_angle[side] = -0.45*sin(PI*t)
		var hip: Vector2 = pose.hip+Vector2(-1 if side==0 else 1,0).rotated(pose.pelvis_angle)
		pose.knees[side] = _knee(hip,pose.feet[side],16.0,16.0)
	return pose
