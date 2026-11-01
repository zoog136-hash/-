class_name SharedGroundMotion
extends Resource
## One distance-driven contact timeline. Skins contain no animation clocks.
## Other requested families deliberately have no unverified motion implementation.
enum Family { GROUND, WINGED_FLOATING, RANGED }
@export var family: Family = Family.GROUND
@export var stride_distance: float = 46.0
@export var stance_fraction: float = 0.52
@export var swing_height: float = 8.0
@export var arm_swing_radians: float = 0.16
@export var cape_swing_radians: float = 0.08
var run_gait := false
var idle_time := 0.0
var attack_origin: Dictionary = {}
var phase: float = 0.0
var distance: float = 0.0
var previous_pose: Dictionary = {}
var was_moving := false
var transition_time := 1.0
var transition_feet: Array = []
var transition_arm := 0.0
var transition_cape := 0.0
var transition_pose: Dictionary = {}

func configure_run() -> void:
	# Authored from observed heel recovery/support pattern; not source-game measurements.
	run_gait = true
	stride_distance = 84.0
	stance_fraction = 0.44
	swing_height = 10.0
	arm_swing_radians = 0.34

func advance(delta: float, speed: float) -> Dictionary:
	assert(family == Family.GROUND, "Only the observed ground pilot is implemented")
	idle_time += delta
	distance += speed * delta
	phase = fposmod(distance / stride_distance, 1.0)
	var moving := speed > 0.01
	if moving != was_moving and not previous_pose.is_empty():
		transition_time = 0.0
		transition_pose = previous_pose.duplicate(true)
		transition_feet = previous_pose.feet.duplicate()
		transition_arm = previous_pose.arm_angle
		transition_cape = previous_pose.cape_angle
	was_moving = moving
	var result := sample(phase, moving)
	if not moving:
		result.torso_y = 0.25 * sin(TAU * idle_time / 2.6)
	transition_time += delta
	if transition_time < 0.18 and transition_feet.size() == 2:
		var blend := smoothstep(0.0, 0.18, transition_time)
		result.hip = transition_pose.hip.lerp(result.hip, blend)
		for key in ["torso_angle", "torso_y", "torso_x", "pelvis_angle", "head_counter", "locomotion_weight", "upper_arm_angle", "forearm_angle", "weapon_angle", "far_arm_angle"]:
			result[key] = lerpf(transition_pose[key], result[key], blend)
		result.arm_angle = lerpf(transition_arm, result.arm_angle, blend)
		result.cape_angle = lerpf(transition_cape, result.cape_angle, blend)
		for side in range(2):
			result.foot_angle[side] = lerpf(transition_pose.foot_angle[side], result.foot_angle[side], blend)
			result.feet[side] = transition_feet[side].lerp(result.feet[side], blend)
			var hip: Vector2 = result.hip + Vector2(-1 if side == 0 else 1, 0).rotated(result.pelvis_angle)
			result.knees[side] = _knee(hip, result.feet[side], 16.0, 16.0)
			result.contact[side] = false
	previous_pose = result
	return result

func sample(at_phase: float, moving: bool = true) -> Dictionary:
	var pose := {"hip": Vector2(0, -32), "feet": [], "knees": [], "contact": [], "foot_angle": [], "cape_angle": cape_swing_radians * sin(TAU * at_phase + PI * 0.5) if moving else 0.0, "arm_angle": -arm_swing_radians * cos(TAU * at_phase) if moving else 0.0}
	if moving and run_gait:
		# Shallow loaded posture and less than one pixel of flight rise, not whole-body bobbing.
		var half_phase := fposmod(at_phase, 0.5)
		var flight_rise := 0.0
		if half_phase > stance_fraction:
			flight_rise = 0.8 * sin(PI * (half_phase - stance_fraction) / (0.5 - stance_fraction))
		pose.hip.y = -27.5 - flight_rise
		pose.hip.x = -0.5 * cos(TAU * at_phase)
	pose.locomotion_weight = 1.0 if moving and run_gait else 0.0
	pose.pelvis_angle = -0.035 * cos(TAU * at_phase) if moving and run_gait else 0.0
	pose.torso_x = 1.2 * cos(TAU * at_phase) if moving and run_gait else 0.0
	pose.head_counter = -0.022 * cos(TAU * at_phase) if moving and run_gait else 0.0
	pose.torso_angle = ((0.12 + 0.055 * cos(TAU * at_phase)) if run_gait else (0.025 + 0.012 * sin(TAU * at_phase))) if moving else 0.0
	pose.torso_y = 0.0
	pose.upper_arm_angle = -(0.32 if run_gait else 0.10) * cos(TAU * at_phase) if moving else 0.0
	pose.forearm_angle = pose.arm_angle
	pose.far_arm_angle = 0.32 * cos(TAU * at_phase) if moving and run_gait else 0.0
	pose.weapon_angle = 0.55 + pose.arm_angle * 0.6
	for side in range(2):
		var p := fposmod(at_phase + side * 0.5, 1.0)
		var reach := stride_distance * stance_fraction * 0.5
		var foot := Vector2(lerpf(5.0, -5.0, side), -3)
		var contact := true
		var angle := 0.0
		if moving:
			if p < stance_fraction:
				foot.x = reach - stride_distance * p
			else:
				var t := (p - stance_fraction) / (1.0 - stance_fraction)
				var ease := t * t * (3.0 - 2.0 * t)
				foot = Vector2(lerpf(-reach, reach, ease), -3.0 - swing_height * sin(PI * t))
				if run_gait:
					# Match stance velocity at toe-off and landing; the curved return includes
					# heel recoil behind the hip, folded recovery, then forward extension.
					var tangent := -stride_distance * (1.0 - stance_fraction)
					foot.x = -reach * (2*t*t*t - 3*t*t + 1) + reach * (-2*t*t*t + 3*t*t) + tangent * (2*t*t*t - 3*t*t + t)
					foot.y = -3.0 - swing_height * pow(sin(PI * t), 0.8)
				angle = -(0.55 if run_gait else 0.3) * sin(PI * t)
				contact = false
		var hip: Vector2 = pose.hip + Vector2(-1 if side == 0 else 1, 0).rotated(pose.pelvis_angle)
		pose.feet.append(foot)
		pose.knees.append(_knee(hip, foot, 16.0, 16.0))
		pose.contact.append(contact)
		pose.foot_angle.append(angle)
	return pose

static func _knee(hip: Vector2, ankle: Vector2, upper: float, lower: float) -> Vector2:
	var offset := ankle - hip
	var d := clampf(offset.length(), 0.001, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + d * d) / (2.0 * d)
	var perpendicular := sqrt(maxf(0.0, upper * upper - along * along))
	var axis := offset.normalized()
	return hip + axis * along + Vector2(axis.y, -axis.x) * perpendicular

# Pure visual sampling of the existing ActorMotion attack clock. No hit events here.
func capture_attack_origin() -> void:
	attack_origin = previous_pose.duplicate(true)

func sample_attack(progress: float, hit_ratio: float) -> Dictionary:
	var p := clampf(progress, 0.0, 1.0)
	var h := clampf(hit_ratio, 0.1, 0.85)
	var times := [0.0, h * 0.55, h, h + (1.0 - h) * 0.22, 1.0]
	var result := sample(0.0, false)
	result.hip += Vector2(_curve(p, times, [0.0, -3.0, 7.0, 4.0, 0.0]), _curve(p, times, [0.0, 3.0, 3.0, 2.0, 0.0]))
	result.torso_angle = _curve(p, times, [0.0, -0.10, 0.18, 0.12, 0.0])
	result.upper_arm_angle = _curve(p, times, [0.0, -1.05, -0.70, -0.15, 0.0])
	result.forearm_angle = _curve(p, times, [0.0, -1.55, -0.60, 0.15, 0.0])
	result.weapon_angle = _curve(p, times, [0.55, -0.95, 0.02, 0.95, 0.55])
	result.far_arm_angle = _curve(p, times, [0.0, -0.30, 0.65, 0.25, 0.0])
	result.cape_angle = _curve(p, times, [0.0, 0.08, -0.10, -0.06, 0.0])
	var spread := smoothstep(0.0, h * 0.55, p) * (1.0 - smoothstep(times[3], 1.0, p))
	for side in range(2):
		result.feet[side].x += (7.0 if side == 0 else -5.0) * spread
		var lift := 0.0
		if p < times[1]: lift = sin(PI * p / times[1]) * (3.0 if side == 0 else 1.5)
		elif p > times[3]: lift = sin(PI * (p - times[3]) / (1.0 - times[3])) * 2.0
		result.feet[side].y -= lift
		result.contact[side] = lift < 0.01
	if not attack_origin.is_empty() and p < h * 0.35:
		var weight := smoothstep(0.0, h * 0.35, p)
		result.hip = attack_origin.hip.lerp(result.hip, weight)
		for key in ["torso_angle", "torso_y", "torso_x", "pelvis_angle", "head_counter", "locomotion_weight", "upper_arm_angle", "forearm_angle", "weapon_angle", "cape_angle", "far_arm_angle"]:
			result[key] = lerpf(attack_origin[key], result[key], weight)
		for side in range(2):
			result.feet[side] = attack_origin.feet[side].lerp(result.feet[side], weight)
			result.foot_angle[side] = lerpf(attack_origin.foot_angle[side], 0.0, weight)
			result.contact[side] = false
	for side in range(2):
		var hip: Vector2 = result.hip + Vector2(-1 if side == 0 else 1, 0).rotated(result.pelvis_angle)
		result.knees[side] = _knee(hip, result.feet[side], 16.0, 16.0)
	previous_pose = result
	return result

static func _curve(p: float, times: Array, values: Array) -> float:
	for index in range(1, times.size()):
		if p <= times[index]:
			return lerpf(values[index - 1], values[index], smoothstep(times[index - 1], times[index], p))
	return values[-1]
