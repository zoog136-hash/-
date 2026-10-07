extends CharacterBody2D
class_name TwilightPlayer

signal attack_requested
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

func _ready() -> void:
	base_move_speed = move_speed
	set_class_index(class_index)
	navigation_agent.path_desired_distance = 8.0
	navigation_agent.target_desired_distance = 16.0
	navigation_agent.avoidance_enabled = false
	camera.enabled = true

func _physics_process(delta: float) -> void:
	attack_clock = maxf(0.0, attack_clock - delta)
	transform_bob_clock += delta
	_tick_stun(delta)
	_tick_silence(delta)
	_tick_hold(delta)
	_tick_fear(delta)
	_tick_poison(delta)
	_tick_bleed(delta)
	if is_stunned():
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
	if distance <= 10.0:
		path_index += 1
		if path_index >= click_path.size():
			return Vector2.ZERO
		next_point = click_path[path_index]
	var direction: Vector2 = global_position.direction_to(next_point)
	return direction * click_move_speed * equipment_move_speed_multiplier * skill_speed_multiplier

func _update_facing(motion: Vector2) -> void:
	if motion.length_squared() < 1.0:
		return
	if absf(motion.x) > absf(motion.y):
		facing = 2 if motion.x < 0.0 else 3
	else:
		facing = 1 if motion.y < 0.0 else 0

func _update_visual(_delta: float) -> void:
	var moving: bool = velocity.length_squared() > 4.0
	if transform_active:
		class_sprite.visible = false
		transform_sprite.visible = true
		transform_sprite.flip_h = false
		var animation_name: String = _direction_animation_name(facing)
		transform_sprite.speed_scale = attack_speed_multiplier if attack_clock > 0.0 else equipment_move_speed_multiplier * skill_speed_multiplier
		if transform_sprite.animation != animation_name:
			transform_sprite.animation = animation_name
			transform_sprite.frame = 0
		if moving or attack_clock > 0.0:
			if not transform_sprite.is_playing():
				transform_sprite.play()
		else:
			transform_sprite.stop()
			transform_sprite.frame = 0
		var bob: float = -absf(sin(transform_bob_clock * 8.0)) * 2.0 if moving else sin(transform_bob_clock * 2.5) * 1.0
		transform_sprite.position.y = -55.0 + bob
		if attack_clock > 0.0:
			var pulse_duration: float = maxf(0.05, attack_visual_duration)
			var pulse: float = sin((1.0 - attack_clock / pulse_duration) * PI)
			transform_sprite.scale = transform_sprite.get_meta("base_scale", Vector2(0.6, 0.6)) * (1.0 + pulse * 0.08)
		else:
			transform_sprite.scale = transform_sprite.get_meta("base_scale", Vector2(0.6, 0.6))
		return

	transform_sprite.visible = false
	class_sprite.visible = true
	class_sprite.flip_h = false
	# Resource imports can briefly leave the base class sheet unavailable.
	# Never request a non-existent animation from AnimatedSprite2D.
	if class_sprite.sprite_frames == null:
		return
	class_sprite.speed_scale = attack_speed_multiplier if attack_clock > 0.0 else equipment_move_speed_multiplier * skill_speed_multiplier
	var required_animation: String = "attack" if attack_clock > 0.0 else _class_direction_animation_name(facing)
	if not class_sprite.sprite_frames.has_animation(required_animation):
		class_sprite.visible = false
		return
	if attack_clock > 0.0:
		class_sprite.animation = "attack"
		class_sprite.flip_h = facing == 2
		if not class_sprite.is_playing():
			class_sprite.play()
	elif moving:
		match facing:
			0: class_sprite.animation = "walk_down"
			1: class_sprite.animation = "walk_up"
			2: class_sprite.animation = "walk_left"
			3: class_sprite.animation = "walk_right"
		if not class_sprite.is_playing():
			class_sprite.play()
	else:
		class_sprite.stop()
		class_sprite.animation = "walk_down" if facing == 0 else ("walk_up" if facing == 1 else ("walk_left" if facing == 2 else "walk_right"))
		class_sprite.frame = 0

func set_class_index(value: int) -> void:
	class_index = clampi(value, 0, CLASS_SHEETS.size() - 1)
	_build_class_frames(CLASS_SHEETS[class_index])
	if not transform_active:
		class_sprite.visible = true

func _build_class_frames(path: String) -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var names: Array[String] = ["walk_down", "walk_up", "walk_left", "walk_right", "attack"]
	if not ResourceLoader.exists(path):
		class_sprite.sprite_frames = frames
		return
	var texture: Texture2D = load(path) as Texture2D
	for row: int in range(5):
		var anim: String = names[row]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 10.0 if row < 4 else 12.0)
		frames.set_animation_loop(anim, row < 4)
		for column: int in range(5):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
			frames.add_frame(anim, atlas)
	class_sprite.sprite_frames = frames
	class_sprite.animation = "walk_down"
	class_sprite.frame = 0
	class_sprite.play()

func set_transform_visual(path: String, _speed_multiplier: float) -> void:
	if path == "" or not ResourceLoader.exists(path):
		clear_transform_visual()
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		clear_transform_visual()
		return
	_build_directional_frames(transform_sprite, texture)
	var size: Vector2 = texture.get_size()
	var cell_height: float = size.y / 4.0
	var desired_height: float = 120.0
	var scale_value: float = desired_height / maxf(1.0, cell_height)
	var base_scale: Vector2 = Vector2(scale_value, scale_value)
	transform_sprite.set_meta("base_scale", base_scale)
	transform_sprite.scale = base_scale
	transform_sprite.animation = _direction_animation_name(facing)
	transform_sprite.frame = 0
	transform_sprite.play()
	transform_active = true
	class_sprite.visible = false
	transform_sprite.visible = true
	# Movement bonuses are applied centrally so transformation, doll, relic and equipment options stack consistently.

func _build_directional_frames(sprite: AnimatedSprite2D, texture: Texture2D) -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var names: Array[String] = ["dir_down", "dir_up", "dir_left", "dir_right"]
	var size: Vector2 = texture.get_size()
	var cell_width: float = size.x / 4.0
	var cell_height: float = size.y / 4.0
	for row: int in range(4):
		var animation_name: String = names[row]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 8.0)
		frames.set_animation_loop(animation_name, true)
		for column: int in range(4):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * cell_width, row * cell_height, cell_width, cell_height)
			frames.add_frame(animation_name, atlas)
	sprite.sprite_frames = frames

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
	click_path = points
	path_index = 0
	navigation_agent.target_position = target

func clear_click_path() -> void:
	click_path = PackedVector2Array()
	path_index = 0

func show_miss() -> void:
	_show_combat_text("MISS", Color(0.78, 0.86, 1.0, 1.0), Vector2(-38.0, -112.0))

func show_received_damage(amount: int, critical: bool = false) -> void:
	var display_text: String = ("CRIT " + str(amount)) if critical else str(amount)
	var display_color: Color = Color(1.0, 0.20, 0.12, 1.0) if critical else Color(1.0, 0.38, 0.32, 1.0)
	_show_combat_text(display_text, display_color, Vector2(-38.0 if critical else -28.0, -112.0))

func _show_combat_text(text_value: String, color_value: Color, start_position: Vector2) -> void:
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
	if is_stunned():
		return
	attack_visual_duration = clampf(0.42 / maxf(0.5, attack_speed_multiplier), 0.10, 0.42)
	attack_clock = attack_visual_duration
	if not transform_active:
		class_sprite.animation = "attack"
		class_sprite.frame = 0
		class_sprite.play()
