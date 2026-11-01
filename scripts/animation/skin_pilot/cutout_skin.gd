class_name SharedCutoutSkin
extends Node2D
## Texture bindings only. All instances receive the same pose from one controller.
var skin: Dictionary
var pose: Dictionary
var draw_pose: Dictionary
var parts: Dictionary
var show_joints := false

func bind_skin(definition: Dictionary) -> void:
	skin = definition
	for key: String in skin.parts:
		parts[key] = load(skin.parts[key].texture)
		assert(parts[key] != null, "Missing skin part: " + key)
	if not pose.is_empty(): draw_pose = _retarget(pose)
	queue_redraw()

func apply_pose(shared_pose: Dictionary) -> void:
	pose = shared_pose
	draw_pose = _retarget(shared_pose)
	queue_redraw()

func _draw() -> void:
	if skin.is_empty() or draw_pose.is_empty(): return
	draw_set_transform(Vector2.ZERO)
	draw_ellipse_shadow()
	# Far leg behind cape/torso; near leg in front. No per-skin motion logic.
	_draw_leg(0)
	_draw_cape()
	_draw_far_arm()
	_draw_body()
	_draw_leg(1)
	_draw_arm()
	if show_joints:
		draw_set_transform(Vector2.ZERO)
		for side in range(2):
			draw_line(draw_pose.hip, draw_pose.knees[side], Color(0.4, 1, 0.7, 0.8), 0.5)
			draw_line(draw_pose.knees[side], draw_pose.feet[side], Color(0.4, 1, 0.7, 0.8), 0.5)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)

func _waist() -> Vector2:
	var offset := _v(skin.retarget.waist_offset) if skin.has("retarget") else Vector2(0, -12)
	return draw_pose.hip + offset.rotated(draw_pose.pelvis_angle) + Vector2(draw_pose.torso_x, draw_pose.torso_y)

func _draw_body() -> void:
	var size := float(skin.body_scale)
	draw_set_transform(draw_pose.hip, draw_pose.pelvis_angle, Vector2.ONE * size)
	draw_texture(parts.pelvis, -_v(skin.parts.pelvis.pivot))
	draw_set_transform(_waist(), draw_pose.torso_angle, Vector2.ONE * size)
	draw_texture(parts.torso, -_v(skin.parts.torso.pivot))
	var neck := (_v(skin.rig.neck) - _v(skin.rig.waist)) * size
	draw_set_transform(_waist() + neck.rotated(draw_pose.torso_angle), draw_pose.torso_angle * 0.5 + draw_pose.head_counter, Vector2.ONE * size)
	draw_texture(parts.head, -_v(skin.parts.head.pivot))

func _draw_cape() -> void:
	var pivot := _v(skin.parts.cape.pivot)
	var bind := (pivot - _v(skin.rig.waist)) * float(skin.body_scale)
	draw_set_transform(_waist() + bind.rotated(draw_pose.torso_angle), draw_pose.torso_angle + draw_pose.cape_angle, Vector2.ONE * float(skin.body_scale))
	draw_texture(parts.cape, -pivot)

func _draw_far_arm() -> void:
	# Only the source's visible far-arm silhouette is rebound; hidden anatomy is not fabricated.
	var pivot := _v(skin.parts.far_arm.pivot)
	var bind := (pivot - _v(skin.rig.waist)) * float(skin.body_scale)
	draw_set_transform(_waist() + bind.rotated(draw_pose.torso_angle), draw_pose.torso_angle + draw_pose.far_arm_angle, Vector2.ONE * float(skin.body_scale))
	draw_texture(parts.far_arm, -pivot)

func _draw_arm() -> void:
	var bind := _v(skin.rig.get("shoulder_offset", [-1, -12]))
	var lengths: Array = skin.rig.get("arm_lengths", [11.0, 11.0])
	var shoulder := _waist() + bind.rotated(draw_pose.torso_angle)
	var elbow := shoulder + Vector2.from_angle(1.65 + draw_pose.upper_arm_angle + draw_pose.torso_angle) * float(lengths[0])
	var wrist := elbow + Vector2.from_angle(0.65 + draw_pose.forearm_angle + draw_pose.torso_angle) * float(lengths[1])
	_segment("upper_arm", shoulder, elbow)
	_segment("forearm", elbow, wrist)
	if parts.has("shoulder_armor") and skin.parts.has("shoulder_armor"):
		var guard: Dictionary = skin.parts.shoulder_armor
		var guard_pivot := _v(guard.pivot)
		# This visible pauldron belongs to the shoulder, not the rigid chest texture.
		# Only locomotion adds articulation; attacks use the existing shoulder/torso transform.
		var follow: float = draw_pose.upper_arm_angle * draw_pose.locomotion_weight
		draw_set_transform(shoulder, draw_pose.torso_angle + follow, Vector2.ONE * float(skin.body_scale))
		draw_texture(parts.shoulder_armor, -guard_pivot)
	var weapon: Dictionary = skin.parts.weapon_hand
	var bind_axis := _v(weapon.end) - _v(weapon.pivot)
	draw_set_transform(wrist, draw_pose.weapon_angle + draw_pose.torso_angle - bind_axis.angle(), Vector2.ONE * float(skin.body_scale))
	draw_texture(parts.weapon_hand, -_v(weapon.pivot))

func _draw_leg(side: int) -> void:
	var hip: Vector2 = draw_pose.hip + (_v(skin.retarget.hip_offsets[side]) if skin.has("retarget") else Vector2(-1 if side == 0 else 1, 0)).rotated(draw_pose.pelvis_angle)
	_segment("thigh_%d" % side, hip, draw_pose.knees[side])
	_segment("shin_%d" % side, draw_pose.knees[side], draw_pose.feet[side])
	var key := "foot_%d" % side
	draw_set_transform(draw_pose.feet[side], draw_pose.foot_angle[side], Vector2.ONE * float(skin.body_scale))
	var pivot := _v(skin.parts[key].pivot)
	# Bind the visible boot sole to the common ground plane; no whole-body offset.
	pivot.y = float(skin.parts[key].sole_y) - float(skin.get("retarget", {}).get("ankle_height", 3.0)) / float(skin.body_scale)
	draw_texture(parts[key], -pivot)

func _segment(key: String, start: Vector2, end: Vector2) -> void:
	var part: Dictionary = skin.parts[key]
	var original := _v(part.end) - _v(part.pivot)
	var target := end - start
	# Fixed segment lengths: no frame-dependent silhouette scaling.
	var factor := target.length() / original.length()
	var transform := Transform2D(target.angle(), Vector2.ZERO).scaled_local(Vector2(factor, float(skin.body_scale))) * Transform2D(-original.angle(), Vector2.ZERO)
	transform.origin = start
	draw_set_transform_matrix(transform)
	draw_texture(parts[key], -_v(part.pivot))

static func _v(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))

# Fixed skin dimensions only; shared phase, contact timing and displacement remain unchanged.
func _retarget(shared_pose: Dictionary) -> Dictionary:
	if not skin.has("retarget"): return shared_pose
	var result := shared_pose.duplicate(true)
	var bind: Dictionary = skin.retarget
	result.hip.y += float(bind.hip_y) + 32.0
	# Fixed wrist range for long blades; same attack phase and hit clock.
	if result.weapon_angle > 0.55:
		result.weapon_angle = 0.55 + (result.weapon_angle - 0.55) * float(bind.get("weapon_downward_gain", 1.0))
	for side in range(2):
		result.feet[side] += Vector2(float(bind.foot_bias[side]), 3.0 - float(bind.ankle_height) + float(bind.ground_y[side]))
		var hip: Vector2 = result.hip + _v(bind.hip_offsets[side]).rotated(result.pelvis_angle)
		result.knees[side] = SharedGroundMotion._knee(hip, result.feet[side], float(bind.lengths[side][0]), float(bind.lengths[side][1]))
	return result
