extends RefCounted
class_name TwilightFollowerMotion

const MOTION = preload("res://scripts/animation/actor_motion.gd")
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
var motion: TwilightActorMotion = MOTION.new()
var enabled: bool = false
var opacity: float = 0.0
var base_scale: Vector2 = Vector2.ONE
var state: String = "despawn"
var combat_reaction: float = 0.0
var previous_sequence: int = -1
var follow_offset: Vector2 = Vector2(-54, 24)
var appear_speed: float = 5.0
var disappear_speed: float = 5.0

func configure(record: Dictionary, path: String, anchor: Node2D, sprite: AnimatedSprite2D, player: TwilightPlayer) -> void:
	if not record.is_empty():
		motion = MOTION.new()
		motion.profile = CATALOG.for_record("doll", record, path)
	if record.is_empty():
		enabled = false
		state = "despawn"
		return
	sprite.stop()
	sprite.sprite_frames = CATALOG.frames_for_profile(motion.profile, path)
	appear_speed = 1.0 / MOTION.presentation_seconds(sprite.sprite_frames, "summon", 0.2)
	disappear_speed = 1.0 / MOTION.presentation_seconds(sprite.sprite_frames, "despawn", 0.2)
	var names: PackedStringArray = sprite.sprite_frames.get_animation_names()
	var texture: Texture2D = CATALOG.first_texture(sprite.sprite_frames)
	if texture == null:
		enabled = false
		return
	sprite.animation = names[0]
	base_scale = Vector2.ONE * (72.0 / maxf(1.0, texture.get_height()))
	anchor.global_position = player.global_position + follow_offset
	motion.face(player.motion.direction)
	opacity = 0.0
	combat_reaction = 0.0
	enabled = true
	sprite.visible = true
	state = "summon"
	previous_sequence = player.motion.sequence

func update(delta: float, anchor: Node2D, sprite: AnimatedSprite2D, player: TwilightPlayer) -> void:
	if not sprite.visible and not enabled: return
	opacity = move_toward(opacity, 1.0 if enabled else 0.0, delta * (appear_speed if enabled else disappear_speed))
	# Repeated frame deltas can leave a tiny remainder after the final authored
	# frame. Finish the fade so an invisible node does not retain its lifecycle.
	if absf(opacity - (1.0 if enabled else 0.0)) < 0.00001:
		opacity = 1.0 if enabled else 0.0
	if not enabled and opacity <= 0.001:
		opacity = 0.0
		sprite.visible = false
		sprite.stop()
		return
	var target: Vector2 = player.global_position + follow_offset
	var old_position: Vector2 = anchor.global_position
	var distance: float = old_position.distance_to(target)
	if distance > 900.0:
		# Region/teleport relocation is masked by a fresh summon fade.
		anchor.global_position = target
		opacity = 0.0
		state = "summon"
	elif distance > 0.65:
		var cap: float = maxf(300.0, player.velocity.length() * 1.35)
		anchor.global_position = old_position.move_toward(target, minf(cap, distance * 7.0) * delta)
	var actual_velocity: Vector2 = (anchor.global_position - old_position) / maxf(delta, 0.001)
	if distance > 900.0: actual_velocity = Vector2.ZERO
	var prior_state: String = motion.state
	var prior_clock: float = motion.state_clock
	motion.advance(delta, actual_velocity)
	if previous_sequence != player.motion.sequence:
		previous_sequence = player.motion.sequence
		combat_reaction = 0.22
	combat_reaction = maxf(0.0, combat_reaction - delta)
	# These are real atlas tracks. The follower remains a presentation layer:
	# owner buffs, attack damage and movement authority are unchanged.
	var pose: String = ""
	if not enabled: pose = "despawn"
	elif opacity < 1.0: pose = "summon"
	elif combat_reaction > 0.0: pose = "activate"
	if not pose.is_empty():
		motion.state_clock = prior_clock + delta if prior_state == pose else 0.0
		motion.state = pose
	motion.apply(sprite, base_scale)
	sprite.modulate = Color(1.0 + combat_reaction, 1.0 + combat_reaction * 0.7, 1.0, opacity)
	if not enabled: state = "despawn"
	elif opacity < 1.0: state = "summon"
	elif combat_reaction > 0.0: state = "combat_reaction"
	elif actual_velocity.length() > 1.0: state = "follow"
	else: state = "idle"
