extends CharacterBody2D
class_name TwilightMonster

signal died(monster: TwilightMonster)
signal player_hit(attacker: TwilightMonster, damage: int, attack_type: String)
signal selected(monster: TwilightMonster)

@onready var sprite: Sprite2D = $Sprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar

var monster_name: String = "몬스터"
var monster_type: String = ""
var undead: bool = false
var element_resistance: Dictionary = {}
var attack_element: String = "physical"
var damage_hit_count: int = 0
var monster_level: int = 1
var defense_value: int = 0
var armor_class: int = -10
var hp: int = 100
var max_hp: int = 100
var attack_power: int = 8
var melee_accuracy: int = 12
var ranged_accuracy: int = 12
var magic_accuracy: int = 12
var magic_resistance: int = 10
var melee_critical_rate: int = 5
var ranged_critical_rate: int = 5
var magic_critical_rate: int = 5
var critical_resistance: int = 0
var stun_accuracy: int = 0
var stun_resistance: int = 0
var stun_duration: float = 0.0
var stun_remaining: float = 0.0
var silence_accuracy: int = 0
var silence_resistance: int = 0
var silence_duration: float = 0.0
var silence_remaining: float = 0.0
var hold_accuracy: int = 0
var hold_resistance: int = 0
var hold_duration: float = 0.0
var hold_remaining: float = 0.0
var fear_accuracy: int = 0
var fear_resistance: int = 0
var fear_duration: float = 0.0
var fear_remaining: float = 0.0
var fear_source_position: Vector2 = Vector2.ZERO
var fear_move_multiplier: float = 0.82
var poison_accuracy: int = 0
var poison_resistance: int = 0
var poison_duration: float = 0.0
var poison_tick_damage: int = 0
var poison_tick_interval: float = 1.0
var poison_remaining: float = 0.0
var poison_tick_clock: float = 0.0
var bleed_accuracy: int = 0
var bleed_resistance: int = 0
var bleed_duration: float = 0.0
var bleed_tick_damage: int = 0
var bleed_tick_interval: float = 0.75
var bleed_remaining: float = 0.0
var bleed_tick_clock: float = 0.0
var attack_type: String = "melee"
var move_speed: float = 90.0
var base_move_speed: float = 90.0
var slow_remaining: float = 0.0
var slow_multiplier: float = 1.0
var exp_reward: int = 25
var gold_reward: int = 40
var grade: String = "일반"
var drop_items: Array[String] = []
var target_player: TwilightPlayer = null
var world_controller: Node = null
var attack_cooldown: float = 0.0
var repath_cooldown: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var dead: bool = false
var home_position: Vector2 = Vector2.ZERO
var spawn_region_id: String = ""
var roaming_radius: float = 180.0
var roam_clock: float = 0.0

func setup(record: Dictionary, player_ref: TwilightPlayer, world_ref: Node, texture: Texture2D) -> void:
	monster_name = str(record.get("name", "몬스터"))
	monster_type = str(record.get("type", record.get("race", "")))
	undead = bool(record.get("undead", monster_type == "언데드"))
	var raw_resistance: Variant = record.get("element_resistance", {})
	element_resistance = (raw_resistance as Dictionary).duplicate(true) if raw_resistance is Dictionary else {}
	attack_element = str(record.get("attack_element", "physical"))
	monster_level = maxi(1, int(record.get("lv", record.get("level", 1))))
	defense_value = maxi(0, int(record.get("def", record.get("defense", record.get("방어력", 0)))))
	var default_ac: int = -(10 + monster_level + defense_value * 2)
	armor_class = int(record.get("ac", record.get("AC", default_ac)))
	if armor_class > 0:
		armor_class = -armor_class
	max_hp = maxi(30, int(record.get("hp", record.get("HP", 100))))
	hp = max_hp
	attack_power = maxi(3, int(record.get("atk", record.get("attack", record.get("공격력", 8)))))
	var default_accuracy: int = monster_level + 10 + int(round(float(attack_power) * 0.25))
	melee_accuracy = maxi(1, int(record.get("melee_accuracy", record.get("accuracy", record.get("hit", record.get("명중", default_accuracy))))))
	ranged_accuracy = maxi(1, int(record.get("ranged_accuracy", record.get("원거리 명중", melee_accuracy))))
	var default_magic_accuracy: int = monster_level + 10 + int(round(float(attack_power) * 0.20))
	magic_accuracy = maxi(1, int(record.get("magic_accuracy", record.get("마법 명중", default_magic_accuracy))))
	var default_mr: int = 10 + monster_level + defense_value
	magic_resistance = maxi(0, int(record.get("mr", record.get("MR", record.get("마법 방어력", default_mr)))))
	var generic_critical: int = maxi(0, int(record.get("crit", record.get("critical_rate", record.get("치명타", 5)))))
	melee_critical_rate = clampi(int(record.get("melee_crit", record.get("근거리 치명타", generic_critical))), 0, 50)
	ranged_critical_rate = clampi(int(record.get("ranged_crit", record.get("원거리 치명타", generic_critical))), 0, 50)
	magic_critical_rate = clampi(int(record.get("magic_crit", record.get("마법 치명타", generic_critical))), 0, 50)
	critical_resistance = clampi(int(record.get("critical_resistance", record.get("crit_resist", record.get("치명타 저항", 0)))), 0, 50)
	var default_stun_accuracy: int = 5 + int(floor(float(monster_level) / 5.0))
	var default_stun_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	stun_accuracy = clampi(int(record.get("stun_accuracy", record.get("스턴 적중", default_stun_accuracy))), 0, 100)
	stun_resistance = clampi(int(record.get("stun_resistance", record.get("stun_resist", record.get("스턴 내성", default_stun_resistance)))), 0, 100)
	stun_duration = maxf(0.0, float(record.get("stun_duration", record.get("스턴 지속시간", 0.0))))
	var default_silence_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	silence_accuracy = clampi(int(record.get("silence_accuracy", record.get("침묵 적중", 0))), 0, 100)
	silence_resistance = clampi(int(record.get("silence_resistance", record.get("silence_resist", record.get("침묵 내성", default_silence_resistance)))), 0, 100)
	silence_duration = maxf(0.0, float(record.get("silence_duration", record.get("침묵 지속시간", 0.0))))
	var default_hold_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	hold_accuracy = clampi(int(record.get("hold_accuracy", record.get("홀드 적중", 0))), 0, 100)
	hold_resistance = clampi(int(record.get("hold_resistance", record.get("hold_resist", record.get("홀드 내성", default_hold_resistance)))), 0, 100)
	hold_duration = maxf(0.0, float(record.get("hold_duration", record.get("홀드 지속시간", 0.0))))
	var default_fear_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	fear_accuracy = clampi(int(record.get("fear_accuracy", record.get("공포 적중", 0))), 0, 100)
	fear_resistance = clampi(int(record.get("fear_resistance", record.get("fear_resist", record.get("공포 내성", default_fear_resistance)))), 0, 100)
	fear_duration = maxf(0.0, float(record.get("fear_duration", record.get("공포 지속시간", 0.0))))
	var default_poison_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	poison_accuracy = clampi(int(record.get("poison_accuracy", record.get("독 적중", 0))), 0, 100)
	poison_resistance = clampi(int(record.get("poison_resistance", record.get("poison_resist", record.get("독 내성", default_poison_resistance)))), 0, 100)
	poison_duration = maxf(0.0, float(record.get("poison_duration", record.get("독 지속시간", 0.0))))
	poison_tick_damage = maxi(0, int(record.get("poison_tick_damage", record.get("독 피해", 0))))
	poison_tick_interval = maxf(0.1, float(record.get("poison_tick_interval", record.get("독 주기", 1.0))))
	var default_bleed_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	bleed_accuracy = clampi(int(record.get("bleed_accuracy", record.get("출혈 적중", 0))), 0, 100)
	bleed_resistance = clampi(int(record.get("bleed_resistance", record.get("bleed_resist", record.get("출혈 내성", default_bleed_resistance)))), 0, 100)
	bleed_duration = maxf(0.0, float(record.get("bleed_duration", record.get("출혈 지속시간", 0.0))))
	bleed_tick_damage = maxi(0, int(record.get("bleed_tick_damage", record.get("출혈 피해", 0))))
	bleed_tick_interval = maxf(0.1, float(record.get("bleed_tick_interval", record.get("출혈 주기", 0.75))))
	attack_type = str(record.get("attack_type", record.get("attackType", record.get("공격타입", "melee")))).to_lower()
	if attack_type != "ranged" and attack_type != "magic":
		attack_type = "melee"
	exp_reward = maxi(10, int(record.get("xp", record.get("exp", record.get("경험치", int(float(max_hp) / 4.0))))))
	gold_reward = maxi(10, int(record.get("gold", record.get("아데나", int(float(max_hp) / 3.0)))))
	grade = str(record.get("grade", record.get("등급", "일반")))
	drop_items.clear()
	var drop_value: Variant = record.get("drop", [])
	if drop_value is Array:
		for item_value: Variant in drop_value as Array:
			var item_name: String = str(item_value)
			if not item_name.is_empty():
				drop_items.append(item_name)
	move_speed = float(record.get("speed", 70.0 + float(mini(70, int(float(max_hp) / 10.0)))))
	base_move_speed = move_speed
	slow_remaining = 0.0
	slow_multiplier = 1.0
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
	_tick_stun(delta)
	_tick_silence(delta)
	_tick_hold(delta)
	_tick_fear(delta)
	_tick_poison(delta)
	_tick_bleed(delta)
	_tick_slow(delta)
	if dead:
		velocity = Vector2.ZERO
		return
	if is_stunned():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	repath_cooldown = maxf(0.0, repath_cooldown - delta)
	var distance: float = global_position.distance_to(target_player.global_position)
	var ui_visible: bool = distance <= 420.0
	name_label.visible = ui_visible
	hp_bar.visible = ui_visible
	var effective_attack_type: String = current_attack_type()
	var attack_range: float = 280.0 if effective_attack_type == "magic" else (220.0 if effective_attack_type == "ranged" else 58.0)
	if is_feared():
		if is_held():
			velocity = Vector2.ZERO
			path = PackedVector2Array()
			path_index = 0
			return
		velocity = _fear_velocity()
		path = PackedVector2Array()
		path_index = 0
		move_and_slide()
		if absf(velocity.x) > 1.0:
			sprite.flip_h = velocity.x < 0.0
		return
	# Avoid line sampling to every distant monster on every physics tick.
	var has_sight: bool = distance <= attack_range and world_controller._has_line_of_sight_world(global_position,target_player.global_position)
	var field_active: bool = world_controller.field_map != null
	if world_controller != null and world_controller.has_method("is_player_concealed") and world_controller.call("is_player_concealed"):
		if field_active:
			_roam_field(delta)
		else:
			_stop_chasing_concealed_player()
		return
	if field_active and (world_controller.field_map.is_safe(target_player.global_position) or distance > 550.0 or target_player.global_position.distance_to(home_position) > 1050.0):
		_roam_field(delta)
		return
	if distance <= attack_range and has_sight:
		velocity = Vector2.ZERO
		if attack_cooldown <= 0.0:
			attack_cooldown = 1.25
			player_hit.emit(self, attack_power, effective_attack_type)
		return
	if is_held():
		velocity = Vector2.ZERO
		path = PackedVector2Array()
		path_index = 0
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

	if path.is_empty() or path_index >= path.size():
		velocity = Vector2.ZERO
		return
	var move_target: Vector2 = path[path_index]
	if path_index < path.size():
		move_target = path[path_index]
		if global_position.distance_to(move_target) < 10.0:
			path_index += 1
			if path_index < path.size():
				move_target = path[path_index]
	var direction: Vector2 = global_position.direction_to(move_target)
	velocity = direction * minf(move_speed,global_position.distance_to(move_target)/maxf(delta,.001))
	move_and_slide()
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0

func _stop_chasing_concealed_player() -> void:
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0

func _roam_field(delta: float) -> void:
	if is_held():
		velocity = Vector2.ZERO
		return
	roam_clock -= delta
	if roam_clock <= 0.0:
		roam_clock = world_controller.rng.randf_range(3.5,7.0)
		var angle: float = world_controller.rng.randf_range(0.0,TAU)
		var goal: Vector2 = home_position + Vector2.from_angle(angle)*world_controller.rng.randf_range(30.0,roaming_radius)
		path = world_controller.find_world_path(global_position,goal)
		path_index = 0
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 8:
		path_index += 1
	if path_index >= path.size():
		velocity = Vector2.ZERO
		return
	var direction: Vector2 = global_position.direction_to(path[path_index])
	velocity = direction * minf(move_speed*.48,global_position.distance_to(path[path_index])/maxf(delta,.001))
	move_and_slide()
	if absf(velocity.x)>1:
		sprite.flip_h = velocity.x<0

func _tick_poison(delta: float) -> void:
	if dead or poison_remaining <= 0.0 or poison_tick_damage <= 0:
		return
	var active_delta: float = minf(delta, poison_remaining)
	poison_remaining = maxf(0.0, poison_remaining - delta)
	poison_tick_clock -= active_delta
	while poison_tick_clock <= 0.0 and poison_tick_damage > 0 and not dead:
		take_damage(poison_tick_damage, false)
		poison_tick_clock += poison_tick_interval
	if poison_remaining <= 0.0 or dead:
		poison_tick_clock = 0.0
		if not dead:
			poison_tick_damage = 0

func is_poisoned() -> bool:
	return poison_remaining > 0.0 and poison_tick_damage > 0 and not dead

func apply_poison(duration: float, damage: int, interval: float = 1.0) -> void:
	if dead:
		return
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

func _tick_bleed(delta: float) -> void:
	if dead or bleed_remaining <= 0.0 or bleed_tick_damage <= 0:
		return
	var active_delta: float = minf(delta, bleed_remaining)
	bleed_remaining = maxf(0.0, bleed_remaining - delta)
	bleed_tick_clock -= active_delta
	while bleed_tick_clock <= 0.0 and bleed_tick_damage > 0 and not dead:
		take_damage(bleed_tick_damage, false)
		bleed_tick_clock += bleed_tick_interval
	if bleed_remaining <= 0.0 or dead:
		bleed_tick_clock = 0.0
		if not dead:
			bleed_tick_damage = 0

func is_bleeding() -> bool:
	return bleed_remaining > 0.0 and bleed_tick_damage > 0 and not dead

func apply_bleed(duration: float, damage: int, interval: float = 0.75) -> void:
	if dead:
		return
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

func _tick_fear(delta: float) -> void:
	fear_remaining = maxf(0.0, fear_remaining - delta)

func is_feared() -> bool:
	return fear_remaining > 0.0

func apply_fear(duration: float, source_position: Vector2) -> void:
	if dead:
		return
	fear_remaining = maxf(fear_remaining, maxf(0.0, duration))
	fear_source_position = source_position
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0
	show_status_text("FEAR")

func _fear_velocity() -> Vector2:
	var away: Vector2 = global_position - fear_source_position
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	return away.normalized() * move_speed * fear_move_multiplier

func _tick_hold(delta: float) -> void:
	hold_remaining = maxf(0.0, hold_remaining - delta)

func is_held() -> bool:
	return hold_remaining > 0.0

func apply_hold(duration: float) -> void:
	if dead:
		return
	hold_remaining = maxf(hold_remaining, maxf(0.0, duration))
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0
	show_status_text("HOLD")

func current_attack_type() -> String:
	if attack_type == "magic" and is_silenced():
		return "melee"
	return attack_type

func _tick_silence(delta: float) -> void:
	silence_remaining = maxf(0.0, silence_remaining - delta)

func is_silenced() -> bool:
	return silence_remaining > 0.0

func apply_silence(duration: float) -> void:
	if dead:
		return
	silence_remaining = maxf(silence_remaining, maxf(0.0, duration))
	show_status_text("SILENCE")

func _tick_stun(delta: float) -> void:
	stun_remaining = maxf(0.0, stun_remaining - delta)

func is_stunned() -> bool:
	return stun_remaining > 0.0

func apply_stun(duration: float) -> void:
	if dead:
		return
	stun_remaining = maxf(stun_remaining, maxf(0.0, duration))
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0
	show_status_text("STUN")

func show_status_text(text_value: String) -> void:
	if dead:
		return
	var label: Label = Label.new()
	label.text = text_value
	label.position = Vector2(-48.0, -112.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.30, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 34
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -28.0), 0.60)
	tween.tween_property(label, "modulate:a", 0.0, 0.60)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func critical_rate_for_type(kind: String) -> int:
	match kind:
		"ranged":
			return ranged_critical_rate
		"magic":
			return magic_critical_rate
		_:
			return melee_critical_rate

func apply_slow(duration: float, multiplier: float = 0.65) -> void:
	if dead:
		return
	slow_remaining = maxf(slow_remaining, maxf(0.0, duration))
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.2, 1.0))
	move_speed = base_move_speed * slow_multiplier
	show_status_text("SLOW")

func _tick_slow(delta: float) -> void:
	if slow_remaining <= 0.0:
		return
	slow_remaining = maxf(0.0, slow_remaining - delta)
	if slow_remaining <= 0.0:
		slow_multiplier = 1.0
	move_speed = base_move_speed * slow_multiplier

func is_undead() -> bool:
	return undead or monster_type == "언데드"

func elemental_resistance_percent(element_name: String) -> float:
	return float(element_resistance.get(element_name, 0.0))

func take_damage(amount: int, critical: bool = false) -> void:
	if dead:
		return
	damage_hit_count += 1
	hp = maxi(0, hp - amount)
	hp_bar.value = hp
	_show_damage_number(amount, critical)
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

func _show_damage_number(amount: int, critical: bool = false) -> void:
	var label: Label = Label.new()
	label.text = ("CRIT " + str(amount)) if critical else str(amount)
	label.position = Vector2(-28.0, -88.0)
	label.add_theme_font_size_override("font_size", 24 if critical else 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.18, 1.0) if critical else Color(1.0, 0.77, 0.28, 1.0))
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
