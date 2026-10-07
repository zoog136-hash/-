extends CharacterBody2D
class_name TwilightMonster

signal died(monster: TwilightMonster)
signal player_hit(damage: int)
signal selected(monster: TwilightMonster)

@onready var sprite: Sprite2D = $Sprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar

var monster_name: String = "몬스터"
var monster_level: int = 1
var defense_value: int = 0
var armor_class: int = -10
var hp: int = 100
var max_hp: int = 100
var attack_power: int = 8
var move_speed: float = 90.0
var exp_reward: int = 25
var gold_reward: int = 40
var grade: String = "일반"
var target_player: TwilightPlayer = null
var world_controller: Node = null
var attack_cooldown: float = 0.0
var repath_cooldown: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var dead: bool = false

func setup(record: Dictionary, player_ref: TwilightPlayer, world_ref: Node, texture: Texture2D) -> void:
	monster_name = str(record.get("name", "몬스터"))
	monster_level = maxi(1, int(record.get("lv", record.get("level", 1))))
	defense_value = maxi(0, int(record.get("def", record.get("defense", record.get("방어력", 0)))))
	var default_ac: int = -(10 + monster_level + defense_value * 2)
	armor_class = int(record.get("ac", record.get("AC", default_ac)))
	if armor_class > 0:
		armor_class = -armor_class
	max_hp = maxi(30, int(record.get("hp", record.get("HP", 100))))
	hp = max_hp
	attack_power = maxi(3, int(record.get("atk", record.get("attack", record.get("공격력", 8)))))
	exp_reward = maxi(10, int(record.get("xp", record.get("exp", record.get("경험치", int(float(max_hp) / 4.0))))))
	gold_reward = maxi(10, int(record.get("gold", record.get("아데나", int(float(max_hp) / 3.0)))))
	grade = str(record.get("grade", record.get("등급", "일반")))
	move_speed = float(record.get("speed", 70.0 + float(mini(70, int(float(max_hp) / 10.0)))))
	target_player = player_ref
	world_controller = world_ref
	sprite.texture = texture
	if texture != null:
		var size: Vector2 = texture.get_size()
		var largest: float = maxf(size.x, size.y)
		if largest > 1.0:
			var desired: float = 72.0 if largest > 100.0 else 56.0
			var scale_value: float = desired / largest
			sprite.scale = Vector2(scale_value, scale_value)
	name_label.text = "Lv.%d %s" % [monster_level, monster_name]
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	navigation_agent.path_desired_distance = 8.0
	navigation_agent.target_desired_distance = 42.0

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	repath_cooldown = maxf(0.0, repath_cooldown - delta)
	var distance: float = global_position.distance_to(target_player.global_position)
	var ui_visible: bool = distance <= 420.0
	name_label.visible = ui_visible
	hp_bar.visible = ui_visible
	if distance <= 58.0:
		velocity = Vector2.ZERO
		if attack_cooldown <= 0.0:
			attack_cooldown = 1.25
			player_hit.emit(attack_power)
		return
	if distance > 760.0:
		velocity = Vector2.ZERO
		return

	if repath_cooldown <= 0.0:
		repath_cooldown = 0.65
		navigation_agent.target_position = target_player.global_position
		if world_controller != null and world_controller.has_method("find_world_path"):
			var result: PackedVector2Array = world_controller.find_world_path(global_position, target_player.global_position)
			path = result
			path_index = 0

	var move_target: Vector2 = target_player.global_position
	if path_index < path.size():
		move_target = path[path_index]
		if global_position.distance_to(move_target) < 10.0:
			path_index += 1
			if path_index < path.size():
				move_target = path[path_index]
	var direction: Vector2 = global_position.direction_to(move_target)
	velocity = direction * move_speed
	move_and_slide()
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0

func take_damage(amount: int) -> void:
	if dead:
		return
	hp = maxi(0, hp - amount)
	hp_bar.value = hp
	_show_damage_number(amount)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.10)
	if hp <= 0:
		dead = true
		died.emit(self)

func show_miss() -> void:
	if dead:
		return
	var label: Label = Label.new()
	label.text = "MISS"
	label.position = Vector2(-36.0, -88.0)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.14, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 30
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -30.0), 0.50)
	tween.tween_property(label, "modulate:a", 0.0, 0.50)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _show_damage_number(amount: int) -> void:
	var label: Label = Label.new()
	label.text = str(amount)
	label.position = Vector2(-28.0, -88.0)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.77, 0.28, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.01, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 30
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -34.0), 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(self)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			selected.emit(self)
