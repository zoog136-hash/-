extends RefCounted
class_name TwilightRelicMotion

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const GLOW = preload("res://assets/effects/relic_glow.gdshader")
var enabled: bool = false
var opacity: float = 0.0
var clock: float = 0.0
var reaction: float = 0.0
var previous_sequence: int = -1
var state: String = "despawn"
var base_scale: Vector2 = Vector2.ONE
var profile: TwilightAnimationProfile
var material: ShaderMaterial
var follow_offset: Vector2 = Vector2(48, 18)
var motion: TwilightActorMotion = MOTION.new()
var appear_speed: float = 4.0
var disappear_speed: float = 4.0

func configure(record: Dictionary, sprite: Sprite2D, player: TwilightPlayer, grade_color: Color) -> void:
	var path: String = str(record.get("image_path", ""))
	if record.is_empty():
		enabled = false
		state = "despawn"
		return
	profile = CATALOG.for_record("relic", record, path)
	motion = MOTION.new()
	motion.profile = profile
	var frames: SpriteFrames = CATALOG.frames_for_profile(profile, path)
	appear_speed = 1.0 / MOTION.presentation_seconds(frames, "equip", 0.25)
	disappear_speed = 1.0 / MOTION.presentation_seconds(frames, "unequip", 0.25)
	var texture: Texture2D = CATALOG.first_texture(frames)
	if texture == null:
		enabled = false
		state = "despawn"
		return
	# Reuse the float/glow/foot sorting while sharing the native frame sampler.
	motion.frame_source = frames
	sprite.texture = texture
	base_scale = Vector2.ONE * (34.0 / maxf(1.0, maxf(sprite.texture.get_width(), sprite.texture.get_height())))
	if material == null:
		material = ShaderMaterial.new()
		material.shader = GLOW
	material.set_shader_parameter("aura_color", grade_color)
	sprite.material = material
	sprite.z_index = 0 # root position is the foot; texture offset carries the elevation
	sprite.global_position = player.global_position + follow_offset
	sprite.visible = true
	opacity = 0.0
	clock = 0.0
	reaction = 0.0
	previous_sequence = player.motion.sequence
	enabled = true
	state = "summon"
	update(0.0, sprite, player)

func update(delta: float, sprite: Sprite2D, player: TwilightPlayer) -> void:
	if not enabled and not sprite.visible: return
	opacity = move_toward(opacity, 1.0 if enabled else 0.0, delta * (appear_speed if enabled else disappear_speed))
	if absf(opacity - (1.0 if enabled else 0.0)) < 0.00001:
		opacity = 1.0 if enabled else 0.0
	if not enabled and opacity <= 0.001:
		opacity = 0.0
		sprite.visible = false
		sprite.texture = null
		return
	clock += delta
	var target: Vector2 = player.global_position + follow_offset
	var previous: Vector2 = sprite.global_position
	if sprite.global_position.distance_to(target) > 900.0:
		sprite.global_position = target
		opacity = 0.0
	else:
		sprite.global_position = sprite.global_position.lerp(target, 1.0 - exp(-8.0 * delta))
	var real_velocity: Vector2 = (sprite.global_position - previous) / maxf(delta, 0.001)
	if previous.distance_to(target) > 900.0: real_velocity = Vector2.ZERO
	var prior_state: String = motion.state
	var prior_clock: float = motion.state_clock
	motion.advance(delta, real_velocity)
	if player.motion.sequence != previous_sequence:
		previous_sequence = player.motion.sequence
		reaction = 0.28
	reaction = maxf(0.0, reaction - delta)
	# A relic uses body/energy/equip tracks, never humanoid walking poses.
	var pose: String = "float"
	if not enabled: pose = "unequip"
	elif opacity < 1.0: pose = "equip"
	elif reaction > 0.0: pose = "activate"
	motion.state_clock = prior_clock + delta if prior_state == pose else 0.0
	motion.state = pose
	motion.apply_frames(sprite)
	var elevation: float = profile.sprite_offset.y if profile != null else -64.0
	sprite.scale = base_scale * (1.0 + reaction * 0.16)
	sprite.offset = Vector2(0, elevation + sin(clock * 2.4) * 3.5) / sprite.scale
	sprite.rotation = sin(clock * 1.6) * 0.045
	sprite.modulate.a = opacity
	if material != null: material.set_shader_parameter("strength", 0.18 + sin(clock * 2.1) * 0.035 + reaction)
	state = "despawn" if not enabled else ("summon" if opacity < 1.0 else ("combat_reaction" if reaction > 0.0 else "float"))
