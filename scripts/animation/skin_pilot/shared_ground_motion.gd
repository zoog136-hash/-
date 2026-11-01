class_name SharedGroundMotion
extends Resource
## One distance-driven contact timeline. Skins contain no animation clocks.
## Other requested families deliberately have no unverified motion implementation.
enum Family { GROUND, WINGED_FLOATING, RANGED }
@export var family: Family = Family.GROUND
@export var stride_distance: float = 46.0
@export var stance_fraction: float = 0.52
@export var swing_height: float = 8.0
var phase: float = 0.0
var distance: float = 0.0
var previous_pose: Dictionary = {}
var was_moving := false
var transition_time := 1.0
var transition_feet: Array = []

func advance(delta: float, speed: float) -> Dictionary:
	assert(family == Family.GROUND, "Only the observed ground pilot is implemented")
	distance += speed * delta
	phase = fposmod(distance / stride_distance, 1.0)
	var moving := speed > 0.01
	if moving != was_moving and not previous_pose.is_empty():
		transition_time = 0.0
		transition_feet = previous_pose.feet.duplicate()
	was_moving = moving
	var result := sample(phase, moving)
	transition_time += delta
	if transition_time < 0.18 and transition_feet.size() == 2:
		var blend := smoothstep(0.0, 0.18, transition_time)
		for side in range(2):
			result.feet[side] = transition_feet[side].lerp(result.feet[side], blend)
			var hip: Vector2 = result.hip + Vector2(-1 if side == 0 else 1, 0)
			result.knees[side] = _knee(hip, result.feet[side], 16.0, 16.0)
			result.contact[side] = false
	previous_pose = result
	return result

func sample(at_phase: float, moving: bool = true) -> Dictionary:
	var pose := {"hip": Vector2(0, -32), "feet": [], "knees": [], "contact": [], "foot_angle": []}
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
				angle = -0.3 * sin(PI * t)
				contact = false
		var hip: Vector2 = pose.hip + Vector2(-1 if side == 0 else 1, 0)
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
