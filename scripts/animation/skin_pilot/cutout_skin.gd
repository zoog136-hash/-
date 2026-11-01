class_name SharedCutoutSkin
extends Node2D
const UpperTargets = preload("res://scripts/animation/skin_pilot/upper_body_targets.gd")
## Texture bindings only. All instances receive the same pose from one controller.
var skin: Dictionary
var pose: Dictionary
var draw_pose: Dictionary
var parts: Dictionary
var show_joints := false
var turn_frames: Array = []
var turn_textures: Array = []
var turn_index := 0
var spine: Dictionary = {}
var spine_textures: Dictionary = {}
var attacking := false
var attack_progress := 0.0
var attack_hit_ratio := 0.5
func set_action(active: bool, progress: float, hit_ratio: float) -> void:
	attacking=active
	attack_progress=progress
	attack_hit_ratio=hit_ratio


func bind_skin(definition: Dictionary) -> void:
	skin = definition
	spine.clear()
	spine_textures.clear()
	if skin.get("articulated_direction","")=="E":
		spine=JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/girtas_articulated_torso.json")).E
		for key in ["abdomen","chest_idle","chest_run"]:spine_textures[key]=load(spine[key].texture)
		for key in spine.far_parts:spine_textures[key]=load(spine.far_parts[key].texture)
	turn_frames.clear()
	turn_textures.clear()
	turn_index = 0
	if skin.has("torso_turn_pack"):
		turn_frames = JSON.parse_string(FileAccess.get_file_as_string(skin.torso_turn_pack)).frames
		for frame: Dictionary in turn_frames:
			turn_textures.append({"torso": load(frame.torso), "shoulder_armor": load(frame.shoulder_armor)})
	for key: String in skin.parts:
		parts[key] = load(skin.parts[key].texture)
		assert(parts[key] != null, "Missing skin part: " + key)
	if not pose.is_empty():
		draw_pose = _retarget(pose)
		_update_turn()
	queue_redraw()

func apply_pose(shared_pose: Dictionary) -> void:
	pose = shared_pose
	draw_pose = _retarget(shared_pose)
	_update_turn()
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

func _spine_active() -> bool:
	return not spine.is_empty() and (attacking or draw_pose.locomotion_weight>0.001)
func _abdomen_angle() -> float:
	return draw_pose.torso_angle*0.25 if _spine_active() else draw_pose.torso_angle
func _chest_angle() -> float:
	return draw_pose.torso_angle+0.10*draw_pose.locomotion_weight if _spine_active() else draw_pose.torso_angle
func _chest_origin() -> Vector2:
	return _waist()+((_v(spine.joint)-_v(skin.rig.waist))*float(skin.body_scale)).rotated(_abdomen_angle())
func _upper_point(bind: Vector2) -> Vector2:
	if not _spine_active():return _waist()+bind.rotated(draw_pose.torso_angle)
	var joint_bind := (_v(spine.joint)-_v(skin.rig.waist))*float(skin.body_scale)
	return _chest_origin()+(bind-joint_bind).rotated(_chest_angle())
func _draw_body() -> void:
	var size := float(skin.body_scale)
	draw_set_transform(draw_pose.hip, draw_pose.pelvis_angle, Vector2.ONE * size)
	draw_texture(parts.pelvis, -_v(skin.parts.pelvis.pivot))
	var neck: Vector2
	if _spine_active():
		draw_set_transform(_waist(),_abdomen_angle(),Vector2.ONE*size)
		draw_texture(spine_textures.abdomen,-_v(spine.abdomen.pivot))
		draw_set_transform(_chest_origin(),_chest_angle(),Vector2.ONE*size)
		var key := "chest_run" if draw_pose.locomotion_weight>0.001 else "chest_idle"
		draw_texture(spine_textures[key],-_v(spine[key].pivot))
		neck=_chest_origin()+((_v(skin.rig.neck)-_v(spine.joint))*size).rotated(_chest_angle())
	else:
		draw_set_transform(_waist(),draw_pose.torso_angle,Vector2.ONE*size)
		draw_texture(_turn_texture("torso"),-_v(skin.parts.torso.pivot))
		neck=_waist()+((_v(skin.rig.neck)-_v(skin.rig.waist))*size).rotated(draw_pose.torso_angle)
	draw_set_transform(neck,_chest_angle()*0.5+draw_pose.head_counter,Vector2.ONE*size)
	draw_texture(parts.head,-_v(skin.parts.head.pivot))

func _draw_cape() -> void:
	var pivot := _v(skin.parts.cape.pivot)
	var bind := (pivot - _v(skin.rig.waist)) * float(skin.body_scale)
	draw_set_transform(_waist() + bind.rotated(draw_pose.torso_angle), draw_pose.torso_angle + draw_pose.cape_angle, Vector2.ONE * float(skin.body_scale))
	draw_texture(parts.cape, -pivot)

func _attack_mix() -> float:
	return smoothstep(0.0,0.12,attack_progress)*(1.0-smoothstep(0.85,1.0,attack_progress)) if attacking else 0.0
func _far_segment(key: String, start: Vector2, end: Vector2) -> void:
	var part: Dictionary=spine.far_parts[key]
	var original := _v(part.end)-_v(part.pivot)
	var target := end-start
	var tr := Transform2D(target.angle(),Vector2.ZERO).scaled_local(Vector2(target.length()/original.length(),float(skin.body_scale)))*Transform2D(-original.angle(),Vector2.ZERO)
	tr.origin=start
	draw_set_transform_matrix(tr)
	draw_texture(spine_textures[key],-_v(part.pivot))
func _draw_far_arm() -> void:
	var pivot := _v(skin.parts.far_arm.pivot)
	var bind := (pivot-_v(skin.rig.waist))*float(skin.body_scale)
	if not turn_frames.is_empty():bind=_v(turn_frames[turn_index].far_offset)
	if not _spine_active():
		draw_set_transform(_waist()+bind.rotated(draw_pose.torso_angle),draw_pose.torso_angle+draw_pose.far_arm_angle,Vector2.ONE*float(skin.body_scale))
		draw_texture(parts.far_arm,-pivot)
		return
	var shoulder := _upper_point(bind)
	var upper := (_v(spine.far_parts.far_upper.end)-_v(spine.far_parts.far_upper.pivot)).length()*float(skin.body_scale)
	var lower := (_v(spine.far_parts.far_forearm.end)-_v(spine.far_parts.far_forearm.pivot)).length()*float(skin.body_scale)
	var rest := (_v(spine.far_parts.far_hand.pivot)-pivot)*float(skin.body_scale)
	var hand := rest.lerp(UpperTargets.run_hand(draw_pose.far_arm_angle,"E",0),draw_pose.locomotion_weight)
	hand=hand.lerp(UpperTargets.attack_hand(attack_progress,attack_hit_ratio,rest,"E",false),_attack_mix())
	var elbow := UpperTargets.solve_elbow(Vector2.ZERO,hand,upper,lower)
	var wrist := shoulder+hand.rotated(_chest_angle())
	elbow=shoulder+elbow.rotated(_chest_angle())
	_far_segment("far_upper",shoulder,elbow)
	_far_segment("far_forearm",elbow,wrist)
	draw_set_transform(wrist,_chest_angle()+draw_pose.far_arm_angle*0.25,Vector2.ONE*float(skin.body_scale))
	draw_texture(spine_textures.far_hand,-_v(spine.far_parts.far_hand.pivot))

func _draw_arm() -> void:
	var bind := _v(skin.rig.get("shoulder_offset", [-1, -12]))
	if not turn_frames.is_empty(): bind = _v(turn_frames[turn_index].near_offset)
	var lengths: Array = skin.rig.get("arm_lengths", [11.0, 11.0])
	var shoulder := _upper_point(bind)
	var elbow := shoulder + Vector2.from_angle(1.65 + draw_pose.upper_arm_angle + draw_pose.torso_angle) * float(lengths[0])
	var wrist := elbow + Vector2.from_angle(0.65 + draw_pose.forearm_angle + draw_pose.torso_angle) * float(lengths[1])
	if _spine_active():
		var neutral := Vector2.from_angle(1.65)*float(lengths[0])+Vector2.from_angle(0.65)*float(lengths[1])
		var hand := neutral.lerp(UpperTargets.run_hand(draw_pose.upper_arm_angle,"E",1),draw_pose.locomotion_weight)
		hand=hand.lerp(UpperTargets.attack_hand(attack_progress,attack_hit_ratio,neutral,"E",true),_attack_mix())
		elbow=shoulder+UpperTargets.solve_elbow(Vector2.ZERO,hand,float(lengths[0]),float(lengths[1])).rotated(_chest_angle())
		wrist=shoulder+hand.rotated(_chest_angle())
	_segment("upper_arm", shoulder, elbow)
	_segment("forearm", elbow, wrist)
	if parts.has("shoulder_armor") and skin.parts.has("shoulder_armor"):
		var guard: Dictionary = skin.parts.shoulder_armor
		var guard_pivot := _v(guard.pivot)
		if not turn_frames.is_empty(): guard_pivot = _v(turn_frames[turn_index].guard_pivot)
		# This visible pauldron belongs to the shoulder, not the rigid chest texture.
		# Only locomotion adds articulation; attacks use the existing shoulder/torso transform.
		var follow: float = draw_pose.upper_arm_angle * draw_pose.locomotion_weight
		draw_set_transform(shoulder, _chest_angle() + follow, Vector2.ONE * float(skin.body_scale))
		draw_texture(_turn_texture("shoulder_armor"), -guard_pivot)
	var weapon: Dictionary = skin.parts.weapon_hand
	var bind_axis := _v(weapon.end) - _v(weapon.pivot)
	var heading: float=lerpf(draw_pose.weapon_angle,0.75+draw_pose.arm_angle*0.2,draw_pose.locomotion_weight) if _spine_active() else draw_pose.weapon_angle
	draw_set_transform(wrist, heading + _chest_angle() - bind_axis.angle(), Vector2.ONE * float(skin.body_scale))
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

func _update_turn() -> void:
	if turn_frames.is_empty(): return
	# Appearance is a function of the shared joint pose. No extra clock, frame timer or FPS.
	var turn: float = clampf(draw_pose.torso_turn * draw_pose.locomotion_weight, 0.0, 1.0)
	turn_index = roundi(turn * float(turn_frames.size() - 1))

func _turn_texture(key: String) -> Texture2D:
	if turn_textures.is_empty(): return parts[key]
	return turn_textures[turn_index][key]
