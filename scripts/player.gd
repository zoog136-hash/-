extends CharacterBody2D
class_name TwilightPlayer

signal attack_requested
signal attack_strike(sequence: int)
signal attack_cancelled(sequence: int)

const ANIMATION_CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const ANIMATION_PROFILE = preload("res://scripts/animation/animation_profile.gd")
const EXTERNAL_SPX = preload("res://addons/twilight_l1j/twilight_external_spx_actor.gd")
const VISUAL_CONFIG_PATH := "user://twilight_ui_settings.cfg"
var motion: TwilightActorMotion = MOTION.new()
var class_profile: TwilightAnimationProfile = ANIMATION_PROFILE.new()
var transform_profile: TwilightAnimationProfile = ANIMATION_PROFILE.new()
var spx_profile: TwilightAnimationProfile = ANIMATION_PROFILE.new()
var spx_sprite: AnimatedSprite2D = null
var spx_actor_id: String = ""
var animation_state: String:
	get: return motion.state
var facing8: int:
	get: return motion.facing8
signal auto_toggled(enabled: bool)
signal poison_tick(damage: int)
signal bleed_tick(damage: int)

@export var move_speed: float = 210.0
@export var click_move_speed: float = 225.0

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var class_sprite: AnimatedSprite2D = $ClassSprite
@onready var transform_sprite: AnimatedSprite2D = $TransformSprite
@onready var camera: Camera2D = $Camera2D

const CLASS_SHEETS: Array[String] = [
	"res://assets/sprites/classes/warrior.png",
	"res://assets/sprites/classes/mage.png",
	"res://assets/sprites/classes/archer.png",
	"res://assets/sprites/classes/assassin.png"
]
const CELL_SIZE: Vector2 = Vector2(148, 116)

var touch_vector: Vector2 = Vector2.ZERO
var click_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var auto_enabled: bool = false
var movement_locked: bool = false
var class_index: int = 0
var facing: int = 0 # 0 down, 1 up, 2 left, 3 right
var attack_clock: float = 0.0
var transform_active: bool = false
var transform_bob_clock: float = 0.0
var stun_remaining: float = 0.0
var silence_remaining: float = 0.0
var hold_remaining: float = 0.0
var fear_remaining: float = 0.0
var fear_source_position: Vector2 = Vector2.ZERO
var fear_move_multiplier: float = 0.82
var poison_remaining: float = 0.0
var poison_tick_interval: float = 1.0
var poison_tick_clock: float = 0.0
var poison_tick_damage: int = 0
var bleed_remaining: float = 0.0
var bleed_tick_interval: float = 0.75
var bleed_tick_clock: float = 0.0
var bleed_tick_damage: int = 0
var base_move_speed: float = 210.0
var skill_speed_multiplier: float = 1.0
var equipment_move_speed_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var attack_visual_duration: float = 0.42
var physics_delta: float = 1.0 / 60.0

func _ready() -> void:
	base_move_speed = move_speed
	motion.strike.connect(func(id: int) -> void: attack_strike.emit(id))
	motion.cancelled.connect(func(id: int) -> void: attack_cancelled.emit(id))
	set_class_index(class_index)
	navigation_agent.path_desired_distance = 8.0
	navigation_agent.target_desired_distance = 16.0
	navigation_agent.avoidance_enabled = false
	camera.enabled = true
	var shadow: Node2D = preload("res://scripts/animation/actor_shadow.gd").new()
	shadow.name = "GroundShadow"
	add_child(shadow)
	var action_fx: TwilightPlayerActionFX = preload("res://scripts/animation/player_action_fx.gd").new()
	action_fx.name = "PlayerActionFX"
	action_fx.actor = self
	action_fx.z_index = 6
	add_child(action_fx)
	spx_sprite = AnimatedSprite2D.new()
	spx_sprite.name = "ExternalSPXActor"
	spx_sprite.z_index = class_sprite.z_index
	# AnimatedSprite2D uses the actor's foot anchor; physics and click targets stay unchanged.
	add_child(spx_sprite)
	spx_sprite.hide()
	var visual_settings := ConfigFile.new()
	if visual_settings.load(VISUAL_CONFIG_PATH) == OK:
		select_external_spx_actor(str(visual_settings.get_value("visual","spx_actor","")))

func _physics_process(delta: float) -> void:
	physics_delta = delta
	transform_bob_clock += delta
	_tick_stun(delta)
	_tick_silence(delta)
	_tick_hold(delta)
	_tick_fear(delta)
	_tick_poison(delta)
	_tick_bleed(delta)
	if is_stunned():
		cancel_attack()
		velocity = Vector2.ZERO
		touch_vector = Vector2.ZERO
		clear_click_path()
		move_and_slide()
		_update_visual(delta)
		return
	if Input.is_action_just_pressed("attack") and not is_feared():
		attack_requested.emit()
	if Input.is_action_just_pressed("toggle_auto"):
		set_auto_enabled(not auto_enabled)

	if is_held():
		velocity = Vector2.ZERO
		touch_vector = Vector2.ZERO
		clear_click_path()
		move_and_slide()
		_update_visual(delta)
		return

	if is_feared():
		cancel_attack()
		touch_vector = Vector2.ZERO
		clear_click_path()
		velocity = _fear_velocity()
		move_and_slide()
		_update_facing(velocity)
		_update_visual(delta)
		return

	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_visual(delta)
		return

	var keyboard: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var manual: Vector2 = keyboard
	if manual.length_squared() < 0.01:
		manual = touch_vector

	if manual.length_squared() > 0.01:
		cancel_attack()
		if auto_enabled:
			set_auto_enabled(false)
		clear_click_path()
		velocity = manual.normalized() * move_speed * equipment_move_speed_multiplier * skill_speed_multiplier
	else:
		velocity = _click_path_velocity()

	move_and_slide()
	_update_facing(velocity)
	_update_visual(delta)

func _click_path_velocity() -> Vector2:
	if path_index >= click_path.size():
		return Vector2.ZERO
	var next_point: Vector2 = click_path[path_index]
	var distance: float = global_position.distance_to(next_point)
	while distance <= 5.0:
		path_index += 1
		if path_index >= click_path.size():
			return Vector2.ZERO
		next_point = click_path[path_index]
		distance = global_position.distance_to(next_point)
	var direction: Vector2 = global_position.direction_to(next_point)
	var speed: float = click_move_speed * equipment_move_speed_multiplier * skill_speed_multiplier
	return direction * minf(speed, distance / maxf(physics_delta, 0.001))

func _update_facing(motion_vector: Vector2) -> void:
	if motion.active: return
	motion.face(motion_vector)
	facing = motion.facing4

func _update_visual(delta: float) -> void:
	var show_spx: bool = not transform_active and spx_sprite != null and not spx_actor_id.is_empty()
	motion.profile = transform_profile if transform_active else (spx_profile if show_spx else class_profile)
	motion.advance(delta, get_position_delta() / maxf(delta, 0.001))
	facing = motion.facing4
	attack_clock = maxf(0.0, motion.attack_duration - motion.attack_elapsed) if motion.active else 0.0
	class_sprite.visible = not transform_active and not show_spx
	transform_sprite.visible = transform_active
	if spx_sprite != null: spx_sprite.visible = show_spx
	var active_sprite: AnimatedSprite2D = transform_sprite if transform_active else (spx_sprite if show_spx else class_sprite)
	motion.apply(active_sprite, active_sprite.get_meta("base_scale", Vector2.ONE))

func face_target(position_value: Vector2) -> void:
	motion.face(position_value - global_position)
	facing = motion.facing4

func start_combat_attack(aim: Vector2, duration: float, style: String, marker: float = -1.0) -> int:
	attack_visual_duration = duration
	attack_clock = duration
	return motion.begin_attack(duration, aim - global_position, style, marker)

func cancel_attack() -> void:
	motion.cancel_attack()
	attack_clock = 0.0

func combat_hit_position() -> Vector2:
	return global_position + motion.profile.hit_position

func combat_projectile_origin() -> Vector2:
	var point: Vector2 = motion.profile.projectile_origin
	point.x *= -1.0 if motion.direction.x < 0.0 else 1.0
	return global_position + point

func set_class_index(value: int) -> void:
	class_index = clampi(value, 0, CLASS_SHEETS.size() - 1)
	class_profile.profile_id = "class:" + str(class_index)
	class_profile.layout = "class5"
	class_profile.dedicated_attack = true
	class_profile.sprite_offset = Vector2(0, -46)
	motion.profile = transform_profile if transform_active else class_profile
	_build_class_frames(CLASS_SHEETS[class_index])
	if not transform_active:
		class_sprite.visible = true

func _build_class_frames(path: String) -> void:
	class_sprite.sprite_frames = ANIMATION_CATALOG.frames(path, "class5")
	class_sprite.set_meta("base_scale", Vector2.ONE)
	class_sprite.pause()

func set_transform_visual(path: String, _speed_multiplier: float, profile_value: TwilightAnimationProfile = null) -> void:
	transform_profile = profile_value if profile_value != null else ANIMATION_CATALOG.for_record("transform", {}, path)
	transform_profile.resource_path_hint = path
	var frames: SpriteFrames = ANIMATION_CATALOG.frames_for_profile(transform_profile, path)
	var names: PackedStringArray = frames.get_animation_names()
	var texture: Texture2D = ANIMATION_CATALOG.first_texture(frames)
	if texture == null:
		clear_transform_visual()
		return
	transform_sprite.stop()
	transform_sprite.sprite_frames = frames
	transform_sprite.animation = names[0]
	var scale_value: float = 120.0 / maxf(1.0, texture.get_height())
	transform_sprite.set_meta("base_scale", Vector2.ONE * scale_value)
	transform_active = true
	motion.profile = transform_profile
	class_sprite.stop()
	class_sprite.visible = false
	transform_sprite.visible = true
	# Keep position, current attack sequence, AUTO and all combat stats intact.
	motion.apply(transform_sprite, Vector2.ONE * scale_value)

# Returns false if no complete local-only 8-direction pack is installed.
# This changes presentation only; transform, collisions, stats and combat stay authoritative.
func select_external_spx_actor(id: String) -> bool:
	if id.is_empty() or id == "default":
		spx_actor_id = ""
		if spx_sprite != null: spx_sprite.hide()
		return true
	var frames: SpriteFrames = EXTERNAL_SPX.frames(id)
	if frames == null or spx_sprite == null: return false
	spx_profile = ANIMATION_PROFILE.new()
	spx_profile.profile_id = "spx-local:" + id
	spx_profile.layout = "directional8"
	spx_profile.reference_speed = class_profile.reference_speed
	spx_profile.movement_fps = class_profile.movement_fps
	spx_profile.attack_hit_ratio = class_profile.attack_hit_ratio
	spx_profile.attack_hit_frame = 4
	spx_profile.sprite_offset = Vector2(0, -63)
	spx_profile.shadow_size = class_profile.shadow_size
	spx_sprite.stop()
	spx_sprite.sprite_frames = frames
	spx_sprite.set_meta("base_scale", Vector2.ONE * 125.0 / maxf(1.0, float(frames.get_frame_texture("idle_2", 0).get_height())))
	spx_actor_id = id
	return true

func _class_direction_animation_name(direction_value: int) -> String:
	match direction_value:
		1: return "walk_up"
		2: return "walk_left"
		3: return "walk_right"
		_: return "walk_down"

func _direction_animation_name(direction_value: int) -> String:
	match direction_value:
		1: return "dir_up"
		2: return "dir_left"
		3: return "dir_right"
		_: return "dir_down"

func clear_transform_visual() -> void:
	transform_active = false
	motion.profile = class_profile
	transform_sprite.rotation = 0.0
	transform_sprite.stop()
	transform_sprite.visible = false
	class_sprite.visible = true

func set_equipment_speed_multipliers(move_multiplier: float, attack_multiplier: float) -> void:
	equipment_move_speed_multiplier = clampf(move_multiplier, 0.5, 2.5)
	attack_speed_multiplier = clampf(attack_multiplier, 0.5, 4.0)

func set_skill_speed_multiplier(value: float) -> void:
	skill_speed_multiplier = clampf(value, 0.5, 2.0)

func set_touch_vector(value: Vector2) -> void:
	touch_vector = value.limit_length(1.0)

func set_click_path(points: PackedVector2Array, target: Vector2) -> void:
	if not points.is_empty(): cancel_attack()
	click_path = points
	path_index = 0
	navigation_agent.target_position = target

func clear_click_path() -> void:
	click_path = PackedVector2Array()
	path_index = 0

func show_miss() -> void:
	_show_combat_text("MISS", Color(0.78, 0.86, 1.0, 1.0), Vector2(-38.0, -112.0))

func show_received_damage(amount: int, critical: bool = false, kind: String = "melee", source: Vector2 = Vector2.ZERO) -> void:
	motion.react(critical)
	var world: Node = get_parent()
	if world is TwilightWorld and world.combat_vfx != null:
		world.combat_vfx.impact(combat_hit_position(), source.direction_to(combat_hit_position()), kind, critical)
	var display_text: String = ("CRIT " + str(amount)) if critical else str(amount)
	var display_color: Color = Color(1.0, 0.20, 0.12, 1.0) if critical else Color(1.0, 0.38, 0.32, 1.0)
	_show_combat_text(display_text, display_color, Vector2(-38.0 if critical else -28.0, -112.0))

func _show_combat_text(text_value: String, color_value: Color, start_position: Vector2) -> void:
	if get_parent().has_method("show_combat_number"):
		get_parent().show_combat_number(global_position + Vector2(0, start_position.y), text_value, color_value, text_value.begins_with("CRIT"))
		return
	var label: Label = Label.new()
	label.text = text_value
	label.position = start_position
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color_value)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 40
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -34.0), 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _tick_poison(delta: float) -> void:
	if poison_remaining <= 0.0 or poison_tick_damage <= 0:
		return
	var active_delta: float = minf(delta, poison_remaining)
	poison_remaining = maxf(0.0, poison_remaining - delta)
	poison_tick_clock -= active_delta
	while poison_tick_clock <= 0.0 and poison_tick_damage > 0:
		poison_tick.emit(poison_tick_damage)
		poison_tick_clock += poison_tick_interval
	if poison_remaining <= 0.0:
		poison_tick_clock = 0.0
		poison_tick_damage = 0

func is_poisoned() -> bool:
	return poison_remaining > 0.0 and poison_tick_damage > 0

func apply_poison(duration: float, damage: int, interval: float = 1.0) -> void:
	var safe_duration: float = maxf(0.0, duration)
	var safe_interval: float = maxf(0.1, interval)
	var was_poisoned: bool = is_poisoned()
	poison_remaining = maxf(poison_remaining, safe_duration)
	poison_tick_damage = maxi(poison_tick_damage, maxi(1, damage))
	poison_tick_interval = safe_interval
	if not was_poisoned or poison_tick_clock <= 0.0:
		poison_tick_clock = safe_interval
	else:
		poison_tick_clock = minf(poison_tick_clock, safe_interval)
	show_status_text("POISON")

func clear_poison() -> void:
	poison_remaining = 0.0
	poison_tick_clock = 0.0
	poison_tick_damage = 0

func show_poison_damage(amount: int) -> void:
	_show_combat_text("POISON " + str(amount), Color(0.48, 0.92, 0.38, 1.0), Vector2(-54.0, -118.0))

func _tick_bleed(delta: float) -> void:
	if bleed_remaining <= 0.0 or bleed_tick_damage <= 0:
		return
	var active_delta: float = minf(delta, bleed_remaining)
	bleed_remaining = maxf(0.0, bleed_remaining - delta)
	bleed_tick_clock -= active_delta
	while bleed_tick_clock <= 0.0 and bleed_tick_damage > 0:
		bleed_tick.emit(bleed_tick_damage)
		bleed_tick_clock += bleed_tick_interval
	if bleed_remaining <= 0.0:
		bleed_tick_clock = 0.0
		bleed_tick_damage = 0

func is_bleeding() -> bool:
	return bleed_remaining > 0.0 and bleed_tick_damage > 0

func apply_bleed(duration: float, damage: int, interval: float = 0.75) -> void:
	var safe_duration: float = maxf(0.0, duration)
	var safe_interval: float = maxf(0.1, interval)
	var was_bleeding: bool = is_bleeding()
	bleed_remaining = maxf(bleed_remaining, safe_duration)
	bleed_tick_damage = maxi(bleed_tick_damage, maxi(1, damage))
	bleed_tick_interval = safe_interval
	if not was_bleeding or bleed_tick_clock <= 0.0:
		bleed_tick_clock = safe_interval
	else:
		bleed_tick_clock = minf(bleed_tick_clock, safe_interval)
	show_status_text("BLEED")

func clear_bleed() -> void:
	bleed_remaining = 0.0
	bleed_tick_clock = 0.0
	bleed_tick_damage = 0

func show_bleed_damage(amount: int) -> void:
	_show_combat_text("BLEED " + str(amount), Color(1.0, 0.30, 0.25, 1.0), Vector2(-50.0, -126.0))

func _tick_fear(delta: float) -> void:
	fear_remaining = maxf(0.0, fear_remaining - delta)

func is_feared() -> bool:
	return fear_remaining > 0.0

func apply_fear(duration: float, source_position: Vector2) -> void:
	fear_remaining = maxf(fear_remaining, maxf(0.0, duration))
	fear_source_position = source_position
	touch_vector = Vector2.ZERO
	clear_click_path()
	show_status_text("FEAR")

func _fear_velocity() -> Vector2:
	var away: Vector2 = global_position - fear_source_position
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	return away.normalized() * move_speed * fear_move_multiplier * equipment_move_speed_multiplier * skill_speed_multiplier

func _tick_hold(delta: float) -> void:
	hold_remaining = maxf(0.0, hold_remaining - delta)

func is_held() -> bool:
	return hold_remaining > 0.0

func apply_hold(duration: float) -> void:
	hold_remaining = maxf(hold_remaining, maxf(0.0, duration))
	velocity = Vector2.ZERO
	touch_vector = Vector2.ZERO
	clear_click_path()
	show_status_text("HOLD")

func _tick_silence(delta: float) -> void:
	silence_remaining = maxf(0.0, silence_remaining - delta)

func is_silenced() -> bool:
	return silence_remaining > 0.0

func apply_silence(duration: float) -> void:
	silence_remaining = maxf(silence_remaining, maxf(0.0, duration))
	show_status_text("SILENCE")

func _tick_stun(delta: float) -> void:
	stun_remaining = maxf(0.0, stun_remaining - delta)

func is_stunned() -> bool:
	return stun_remaining > 0.0

func apply_stun(duration: float) -> void:
	stun_remaining = maxf(stun_remaining, maxf(0.0, duration))
	velocity = Vector2.ZERO
	touch_vector = Vector2.ZERO
	clear_click_path()
	show_status_text("STUN")

func show_status_text(text_value: String) -> void:
	_show_combat_text(text_value, Color(0.93, 0.78, 0.30, 1.0), Vector2(-45.0, -136.0))

func clear_status_effects() -> void:
	stun_remaining = 0.0
	silence_remaining = 0.0
	hold_remaining = 0.0
	fear_remaining = 0.0
	clear_poison()
	clear_bleed()
	velocity = Vector2.ZERO
	touch_vector = Vector2.ZERO
	clear_click_path()

func set_auto_enabled(enabled: bool) -> void:
	auto_enabled = enabled
	auto_toggled.emit(enabled)

func pulse_attack() -> void:
	if is_stunned(): return
	if motion.active: return
	attack_visual_duration = clampf(0.42 / maxf(0.5, attack_speed_multiplier), 0.10, 0.84)
	start_combat_attack(global_position + motion.direction, attack_visual_duration, motion.profile.motion_style)
