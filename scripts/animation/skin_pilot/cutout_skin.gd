class_name SharedCutoutSkin
extends Node2D
const GirtasUpper = preload("res://scripts/animation/skin_pilot/girtas_upper_body.gd")
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
	if skin.get("upper_body_profile","")=="girtas_267":
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
	return not spine.is_empty() and (draw_pose.locomotion_weight>0.001 or attacking)
func _lean_angle() -> float:
	if not _spine_active(): return 0.0
	var run_lean: float=(0.26+0.065*(draw_pose.torso_x/1.2))*draw_pose.locomotion_weight
	var attack_lean: float=GirtasUpper.curve(attack_progress,attack_hit_ratio,[0.0,-0.08,0.16,0.07,0.0]) if attacking else 0.0
	return run_lean+attack_lean
func _chest_anchor_source() -> Vector2:
	return _v(spine.joint) if not spine.is_empty() else _v(skin.rig.waist)
func _chest_anchor_world() -> Vector2:
	return _waist()+((_chest_anchor_source()-_v(skin.rig.waist))*float(skin.body_scale)).rotated(draw_pose.torso_angle)
func _upper_point(source_point: Vector2) -> Vector2:
	return _chest_anchor_world()+((source_point-_chest_anchor_source())*float(skin.body_scale)).rotated(draw_pose.torso_angle+_lean_angle())
func _draw_body() -> void:
	var size := float(skin.body_scale)
	draw_set_transform(draw_pose.hip,draw_pose.pelvis_angle,Vector2.ONE*size)
	draw_texture(parts.pelvis,-_v(skin.parts.pelvis.pivot))
	var neck: Vector2
	if _spine_active():
		# One chest parent carries the shoulder sockets, head and upper arms.
		# Only the forearm folds at the elbow; no raised-hand target is used.
		draw_set_transform(_waist(),draw_pose.torso_angle,Vector2.ONE*size)
		draw_texture(spine_textures.abdomen,-_v(spine.abdomen.pivot))
		draw_set_transform(_chest_anchor_world(),draw_pose.torso_angle+_lean_angle(),Vector2.ONE*size)
		draw_texture(spine_textures.chest_run if draw_pose.locomotion_weight>0.001 else spine_textures.chest_idle,-_chest_anchor_source())
		neck=_upper_point(_v(skin.rig.neck))
	else:
		draw_set_transform(_waist(),draw_pose.torso_angle,Vector2.ONE*size)
		draw_texture(_turn_texture("torso"),-_v(skin.parts.torso.pivot))
		neck=_waist()+((_v(skin.rig.neck)-_v(skin.rig.waist))*size).rotated(draw_pose.torso_angle)
	draw_set_transform(neck,draw_pose.torso_angle*0.5+draw_pose.head_counter+_lean_angle()*0.2,Vector2.ONE*size)
	draw_texture(parts.head,-_v(skin.parts.head.pivot))

func _draw_cape() -> void:
	var pivot := _v(skin.parts.cape.pivot)
	var bind := (pivot - _v(skin.rig.waist)) * float(skin.body_scale)
	draw_set_transform(_waist() + bind.rotated(draw_pose.torso_angle), draw_pose.torso_angle + draw_pose.cape_angle, Vector2.ONE * float(skin.body_scale))
	draw_texture(parts.cape, -pivot)

func _far_segment(key: String, start: Vector2, end: Vector2) -> void:
	var part: Dictionary=spine.far_parts[key]
	var source := _v(part.end)-_v(part.pivot)
	var target := end-start
	var tr := Transform2D(target.angle(),Vector2.ZERO).scaled_local(Vector2(target.length()/source.length(),float(skin.body_scale)))*Transform2D(-source.angle(),Vector2.ZERO)
	tr.origin=start
	draw_set_transform_matrix(tr)
	draw_texture(spine_textures[key],-_v(part.pivot))
func _draw_far_arm() -> void:
	var pivot := _v(skin.parts.far_arm.pivot)
	var bind := (pivot-_v(skin.rig.waist))*float(skin.body_scale)
	if not turn_frames.is_empty():bind=_v(turn_frames[0 if not spine.is_empty() else turn_index].far_offset)
	var shoulder := _waist()+bind.rotated(draw_pose.torso_angle)
	if not _spine_active():
		draw_set_transform(shoulder,draw_pose.torso_angle+draw_pose.far_arm_angle,Vector2.ONE*float(skin.body_scale))
		draw_texture(parts.far_arm,-pivot)
		return
	shoulder=_upper_point(_v(skin.rig.waist)+bind/float(skin.body_scale))
	var weight: float=draw_pose.locomotion_weight
	var parent_angle: float=draw_pose.torso_angle+_lean_angle()
	var upper_bind := _v(spine.far_parts.far_upper.end)-_v(spine.far_parts.far_upper.pivot)
	var lower_bind := _v(spine.far_parts.far_forearm.end)-_v(spine.far_parts.far_forearm.pivot)
	var upper_angle: float=parent_angle+upper_bind.angle()+draw_pose.far_arm_angle*0.6
	var lower_angle: float=parent_angle+lerpf(lower_bind.angle(),-0.15-draw_pose.far_arm_angle*0.5,weight)
	if attacking:
		var mix: float=GirtasUpper.blend(attack_progress)
		upper_angle=lerpf(upper_angle,parent_angle+GirtasUpper.curve(attack_progress,attack_hit_ratio,[upper_bind.angle(),1.7,2.3,1.6,upper_bind.angle()]),mix)
		lower_angle=lerpf(lower_angle,parent_angle+GirtasUpper.curve(attack_progress,attack_hit_ratio,[lower_bind.angle(),0.2,0.8,1.0,lower_bind.angle()]),mix)
	var elbow := shoulder+Vector2.from_angle(upper_angle)*upper_bind.length()*float(skin.body_scale)
	var wrist := elbow+Vector2.from_angle(lower_angle)*lower_bind.length()*float(skin.body_scale)
	_far_segment("far_upper",shoulder,elbow);_far_segment("far_forearm",elbow,wrist)
	draw_set_transform(wrist,parent_angle+draw_pose.far_arm_angle,Vector2.ONE*float(skin.body_scale))
	draw_texture(spine_textures.far_hand,-_v(spine.far_parts.far_hand.pivot))

func _draw_arm() -> void:
	var bind := _v(skin.rig.get("shoulder_offset", [-1, -12]))
	if not turn_frames.is_empty(): bind = _v(turn_frames[0 if not spine.is_empty() else turn_index].near_offset)
	var lengths: Array = skin.rig.get("arm_lengths", [11.0, 11.0])
	var parent_angle: float=draw_pose.torso_angle+_lean_angle()
	var shoulder := _upper_point(_v(skin.rig.waist)+bind/float(skin.body_scale)) if _spine_active() else _waist()+bind.rotated(draw_pose.torso_angle)
	var elbow := shoulder + Vector2.from_angle(1.65 + draw_pose.upper_arm_angle + parent_angle) * float(lengths[0])
	var forearm_rest := lerpf(0.65,-0.30,draw_pose.locomotion_weight) if _spine_active() else 0.65
	var wrist := elbow + Vector2.from_angle(forearm_rest + draw_pose.forearm_angle + parent_angle) * float(lengths[1])
	if not spine.is_empty() and attacking:
		var mix: float=GirtasUpper.blend(attack_progress)
		var upper_angle: float=lerpf(1.65+draw_pose.upper_arm_angle,GirtasUpper.curve(attack_progress,attack_hit_ratio,[1.65,2.4,0.1,0.9,1.65]),mix)+parent_angle
		var lower_angle: float=lerpf(forearm_rest+draw_pose.forearm_angle,GirtasUpper.curve(attack_progress,attack_hit_ratio,[0.65,-1.35,0.15,0.75,0.65]),mix)+parent_angle
		elbow=shoulder+Vector2.from_angle(upper_angle)*float(lengths[0])
		wrist=elbow+Vector2.from_angle(lower_angle)*float(lengths[1])
	_segment("upper_arm", shoulder, elbow)
	_segment("forearm", elbow, wrist)
	if parts.has("shoulder_armor") and skin.parts.has("shoulder_armor"):
		var guard: Dictionary = skin.parts.shoulder_armor
		var guard_pivot := _v(guard.pivot)
		if not turn_frames.is_empty(): guard_pivot = _v(turn_frames[turn_index].guard_pivot)
		# This visible pauldron belongs to the shoulder, not the rigid chest texture.
		# Only locomotion adds articulation; attacks use the existing shoulder/torso transform.
		var follow: float = 0.0 if not spine.is_empty() else draw_pose.upper_arm_angle * draw_pose.locomotion_weight
		draw_set_transform(shoulder, parent_angle + follow, Vector2.ONE * float(skin.body_scale))
		draw_texture(_turn_texture("shoulder_armor"), -guard_pivot)
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

func _update_turn() -> void:
	if turn_frames.is_empty(): return
	# Appearance is a function of the shared joint pose. No extra clock, frame timer or FPS.
	var turn: float = clampf(draw_pose.torso_turn * draw_pose.locomotion_weight, 0.0, 1.0)
	turn_index = roundi(turn * float(turn_frames.size() - 1))

func _turn_texture(key: String) -> Texture2D:
	if turn_textures.is_empty(): return parts[key]
	return turn_textures[turn_index][key]
