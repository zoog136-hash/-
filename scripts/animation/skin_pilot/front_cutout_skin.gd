extends Node2D
const GirtasUpper = preload("res://scripts/animation/skin_pilot/girtas_upper_body.gd")
## Girtas S-view binding of the SAME pose, not a universal front-skin rig.
var skin: Dictionary
var pose: Dictionary
var parts: Dictionary
var attacking := false
var attack_progress := 0.0
var attack_hit_ratio := 0.5
var spine: Dictionary
var run_lean: Dictionary
var run_lean_textures: Dictionary
var spine_textures: Dictionary
func set_action(active: bool, progress: float, hit_ratio: float) -> void:
	attacking=active
	attack_progress=progress
	attack_hit_ratio=hit_ratio
const SIZE := 0.219105011732
func bind_skin(definition: Dictionary) -> void:
	skin = definition
	assert(skin.get("upper_body_profile","")=="girtas_267","This front binding requires the Girtas profile")
	spine=JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/girtas_articulated_torso.json")).S
	for key in ["front_core","front_outer"]:spine_textures[key]=load(spine[key].texture)
	run_lean=JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/girtas_front_lean.json"))
	for key in ["head","torso"]:run_lean_textures[key]=load(run_lean[key].texture)
	for key in skin.parts: parts[key] = load(skin.parts[key].texture)
	queue_redraw()
func apply_pose(shared: Dictionary) -> void:
	pose = shared
	queue_redraw()
func v(a: Array) -> Vector2: return Vector2(a[0], a[1])
func draw_part(key: String, at: Vector2, angle: float = 0.0) -> void:
	draw_set_transform(at, angle, Vector2.ONE * SIZE)
	draw_texture(parts[key], -v(skin.parts[key].pivot))
func segment(key: String, a: Vector2, b: Vector2) -> void:
	var part: Dictionary = skin.parts[key]
	var source := v(part.end) - v(part.pivot)
	var target := b-a
	# This is direction-dependent limb projection, not bounding-box body scaling.
	var tr := Transform2D(target.angle(), Vector2.ZERO).scaled_local(Vector2(target.length()/source.length(), SIZE)) * Transform2D(-source.angle(), Vector2.ZERO)
	tr.origin = a
	draw_set_transform_matrix(tr)
	draw_texture(parts[key], -v(part.pivot))
func front_foot(side: int) -> Vector2:
	var weight: float = pose.locomotion_weight
	var idle_x: float = (357.0 if side == 0 else 207.0) - 288.0
	var run_x: float = 11.5 if side == 0 else -11.5
	var depth: float = pose.feet[side].x * 0.35
	var lift: float = minf(0.0, pose.feet[side].y + 3.0) * 0.65
	return Vector2(lerpf(idle_x*SIZE, run_x, weight), -8.8 + weight*(depth+lift))
func _draw() -> void:
	if pose.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.22));draw_circle(Vector2.ZERO,18,Color(0,0,0,0.25))
	var weight: float = pose.locomotion_weight
	var hip := Vector2(pose.hip.x*(0.55 if attacking else 0.25), pose.hip.y-14.0)
	var roll: float = -pose.pelvis_angle*1.5 - (pose.torso_angle*0.25 if attacking else 0.0)
	var chest_angle: float = -roll + (pose.torso_angle*0.65 if attacking else 0.0)
	chest_angle -= 0.11*(pose.torso_x/1.2)*weight
	if attacking: chest_angle += GirtasUpper.curve(attack_progress,attack_hit_ratio,[0.0,0.20,-0.34,-0.15,0.0])
	var waist := hip + Vector2(0,-35*SIZE)
	draw_part("cape",hip,roll*0.5)
	for side in range(2):
		var sign_x: float = 1.0 if side == 0 else -1.0
		var root := hip+Vector2(sign_x*44*SIZE,11*SIZE).rotated(roll)
		var ankle := front_foot(side)
		var knee := Vector2(lerpf((346.0 if side==0 else 222.0)-288.0,sign_x*50.0,weight)*SIZE, lerpf(root.y,ankle.y,0.48)-weight*maxf(0.0,-pose.feet[side].y-3.0)*0.35)
		segment("thigh_%d"%side,root,knee);segment("shin_%d"%side,knee,ankle)
		draw_part("foot_%d"%side,ankle,pose.foot_angle[side]*0.12*sign_x)
	draw_part("pelvis",hip,roll)
	var lean_weight: float = maxf(weight,GirtasUpper.curve(attack_progress,attack_hit_ratio,[0.0,0.0,0.65,0.3,0.0]) if attacking else 0.0)
	# A painted bowed face/neck/chest key supplies actual frontal occlusion.
	# Original crown, outer armor, arms and weapon remain source-bound.
	var run_key := weight>0.5
	if run_key:
		draw_set_transform(waist,chest_angle,Vector2.ONE*SIZE)
		draw_texture(run_lean_textures.torso,-v(run_lean.torso.pivot))
	elif attacking and lean_weight>0.001:
		draw_set_transform(waist,chest_angle,Vector2.ONE*SIZE)
		draw_texture(spine_textures.front_outer,-v(spine.front_outer.pivot))
		draw_set_transform(waist+Vector2(0,3.5*lean_weight),chest_angle,Vector2.ONE*SIZE)
		draw_texture(spine_textures.front_core,-v(spine.front_core.pivot))
	else:
		draw_part("torso",waist,chest_angle)
	var neck := waist+Vector2(0,-105*SIZE).rotated(chest_angle)
	if run_key:
		draw_set_transform(neck+Vector2(0,-10.0*(1.0-weight)),0.0,Vector2.ONE*SIZE)
		draw_texture(run_lean_textures.head,-v(run_lean.head.pivot))
	else:
		draw_part("head",neck+Vector2(0,6.0*lean_weight),0.0)
	for side in range(2):
		var sign_x: float = 1.0 if side==0 else -1.0
		var arm: float = pose.far_arm_angle if side==0 else pose.upper_arm_angle
		var shoulder := waist+(Vector2((363.0 if side==0 else 208.0)-288.0,-52)*SIZE).rotated(chest_angle)
		# The shoulder is attached to the moving chest; no independent lift.
		var elbow := shoulder+Vector2((6.0 if side==0 else -10.0)*SIZE,42*SIZE)
		var wrist := elbow+Vector2((5.0 if side==0 else -12.0)*SIZE,40*SIZE)
		var attack_mix := smoothstep(0.0,0.12,attack_progress)*(1.0-smoothstep(0.8,1.0,attack_progress)) if attacking else 0.0
		var attack_elbow := shoulder+(elbow-shoulder).rotated(arm if side==1 else arm*0.6)
		var attack_wrist := attack_elbow+Vector2((5.0 if side==0 else -12.0)*SIZE,40*SIZE).rotated(pose.forearm_angle if side==1 else arm*0.6)
		if attacking:
			var upper_bind := Vector2((6.0 if side==0 else -10.0)*SIZE,42*SIZE)
			var lower_bind := Vector2((5.0 if side==0 else -12.0)*SIZE,40*SIZE)
			var up: float=GirtasUpper.curve(attack_progress,attack_hit_ratio,[upper_bind.angle(),3.6,1.0,1.5,upper_bind.angle()] if side==1 else [upper_bind.angle(),1.0,2.1,1.4,upper_bind.angle()])
			var low: float=GirtasUpper.curve(attack_progress,attack_hit_ratio,[lower_bind.angle(),-0.9,2.0,1.3,lower_bind.angle()] if side==1 else [lower_bind.angle(),2.3,0.6,1.0,lower_bind.angle()])
			attack_elbow=shoulder+Vector2.from_angle(up+chest_angle)*upper_bind.length()
			attack_wrist=attack_elbow+Vector2.from_angle(low+chest_angle)*lower_bind.length()
		# Bent running arms follow a visible arc, rather than merely sliding vertically.
		var run_elbow := shoulder+Vector2(sign_x*2.0,9.5).rotated(-arm*sign_x*1.1)
		var run_wrist := run_elbow+Vector2(-sign_x*7.0,-2.0).rotated(-arm*sign_x*0.8)
		# Forearm folds around the elbow, rather than translating the arm upward.
		run_elbow=shoulder+(run_elbow-shoulder).rotated(chest_angle)
		run_wrist=run_elbow+Vector2(-sign_x*7.0,-2.0).rotated(-arm*sign_x*0.8+chest_angle)
		elbow=elbow.lerp(run_elbow,weight)
		wrist=wrist.lerp(run_wrist,weight)
		elbow=elbow.lerp(attack_elbow,attack_mix)
		wrist=wrist.lerp(attack_wrist,attack_mix)
		segment("upper_%d"%side,shoulder,elbow);segment("lower_%d"%side,elbow,wrist)
		draw_part("hand_%d"%side,wrist,lerpf((arm*0.5-0.15)*weight,-(pose.weapon_angle-0.55),attack_mix) if side==1 else arm*0.5*weight)
		draw_part("shoulder_%d"%side,shoulder,chest_angle)
