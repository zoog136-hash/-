extends Node2D
## Opt-in presentation adapter for the real player. Never owns combat or movement.
const Ground = preload("res://scripts/animation/skin_pilot/girtas_ground_motion.gd")
const Side = preload("res://scripts/animation/skin_pilot/cutout_skin.gd")
const Front = preload("res://scripts/animation/skin_pilot/front_cutout_skin.gd")
var ground := Ground.new()
var east: Node2D
var south: Node2D
var previous_attack := false
var previous_sequence := -1
var supported := false

func _ready() -> void:
	ground.configure_run()
	east = Side.new()
	south = Front.new()
	add_child(east)
	add_child(south)
	east.bind_skin(JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/girtas_shared_skin.json")).skin)
	south.bind_skin(JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/girtas_front_skin.json")))
	hide()

func update_from_player(player: Node, delta: float, original: AnimatedSprite2D) -> bool:
	var clock = player.motion
	var eligible: bool = player.transform_active and player.transform_profile.profile_id == "transform:267"
	supported = eligible and clock.facing8 in [0,2] and clock.state in ["idle","turn","run","walk","attack","recovery"] and not clock.dead
	visible = supported
	if not eligible:
		previous_attack = false
		return false
	# Actual post-collision displacement, never intended input speed.
	var speed: float = player.get_position_delta().length()/maxf(delta,0.001)
	var attacking: bool = clock.presenting_attack
	if attacking and (not previous_attack or previous_sequence != clock.sequence):
		ground.capture_attack_origin()
	var pose := ground.advance(delta,speed)
	if attacking: pose = ground.sample_attack(clock.visual_progress,clock.attack_hit_ratio)
	previous_attack = attacking
	previous_sequence = clock.sequence
	if not supported: return false
	east.visible = clock.facing8 == 0
	south.visible = clock.facing8 == 2
	var skin: Node2D = east if east.visible else south
	skin.set_action(attacking,clock.visual_progress,clock.attack_hit_ratio)
	skin.apply_pose(pose)
	# Keep original status tint/opacity; the original renderer still advances.
	modulate = original.modulate
	original.hide()
	return true
