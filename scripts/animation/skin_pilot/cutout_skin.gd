class_name SharedCutoutSkin
extends Node2D
## Texture bindings only. All instances receive the same pose from one controller.
var skin: Dictionary
var pose: Dictionary
var parts: Dictionary
var show_joints := false

func bind_skin(definition: Dictionary) -> void:
	skin = definition
	for key: String in skin.parts:
		parts[key] = load(skin.parts[key].texture)
		assert(parts[key] != null, "Missing skin part: " + key)
	queue_redraw()

func apply_pose(shared_pose: Dictionary) -> void:
	pose = shared_pose
	queue_redraw()

func _draw() -> void:
	if skin.is_empty() or pose.is_empty(): return
	draw_set_transform(Vector2.ZERO)
	draw_ellipse_shadow()
	# Far leg behind cape/torso; near leg in front. No per-skin motion logic.
	_draw_leg(0)
	_draw_cape()
	_draw_body()
	_draw_leg(1)
	_draw_arm()
	if show_joints:
		draw_set_transform(Vector2.ZERO)
		for side in range(2):
			draw_line(pose.hip, pose.knees[side], Color(0.4, 1, 0.7, 0.8), 0.5)
			draw_line(pose.knees[side], pose.feet[side], Color(0.4, 1, 0.7, 0.8), 0.5)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)

func _waist() -> Vector2:
	return pose.hip + Vector2(0, -12 + pose.torso_y)

func _draw_body() -> void:
	var size := float(skin.body_scale)
	draw_set_transform(pose.hip, 0, Vector2.ONE * size)
	draw_texture(parts.pelvis, -_v(skin.parts.pelvis.pivot))
	draw_set_transform(_waist(), pose.torso_angle, Vector2.ONE * size)
	draw_texture(parts.torso, -_v(skin.parts.torso.pivot))
	var neck := (_v(skin.rig.neck) - _v(skin.rig.waist)) * size
	draw_set_transform(_waist() + neck.rotated(pose.torso_angle), pose.torso_angle * 0.5, Vector2.ONE * size)
	draw_texture(parts.head, -_v(skin.parts.head.pivot))

func _draw_cape() -> void:
	var pivot := _v(skin.parts.cape.pivot)
	var bind := (pivot - _v(skin.rig.waist)) * float(skin.body_scale)
	draw_set_transform(_waist() + bind.rotated(pose.torso_angle), pose.torso_angle + pose.cape_angle, Vector2.ONE * float(skin.body_scale))
	draw_texture(parts.cape, -pivot)

func _draw_arm() -> void:
	var shoulder := _waist() + Vector2(-1, -12).rotated(pose.torso_angle)
	var elbow := shoulder + Vector2.from_angle(1.65 + pose.upper_arm_angle + pose.torso_angle) * 11.0
	var wrist := elbow + Vector2.from_angle(0.65 + pose.forearm_angle + pose.torso_angle) * 11.0
	_segment("upper_arm", shoulder, elbow)
	_segment("forearm", elbow, wrist)
	var weapon: Dictionary = skin.parts.weapon_hand
	var bind_axis := _v(weapon.end) - _v(weapon.pivot)
	draw_set_transform(wrist, pose.weapon_angle + pose.torso_angle - bind_axis.angle(), Vector2.ONE * float(skin.body_scale))
	draw_texture(parts.weapon_hand, -_v(weapon.pivot))

func _draw_leg(side: int) -> void:
	var hip: Vector2 = pose.hip + Vector2(-1 if side == 0 else 1, 0)
	_segment("thigh_%d" % side, hip, pose.knees[side])
	_segment("shin_%d" % side, pose.knees[side], pose.feet[side])
	var key := "foot_%d" % side
	draw_set_transform(pose.feet[side], pose.foot_angle[side], Vector2.ONE * float(skin.body_scale))
	var pivot := _v(skin.parts[key].pivot)
	# Bind the visible boot sole to the common ground plane; no whole-body offset.
	pivot.y = float(skin.parts[key].sole_y) - 3.0 / float(skin.body_scale)
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
