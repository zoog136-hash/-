extends CharacterBody2D
class_name TwilightMonster

const MOTION = preload("res://scripts/animation/actor_motion.gd")
const ANIMATION_CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MONSTER_ART = preload("res://scripts/monsters/monster_art.gd")
const VISUAL = preload("res://scripts/monsters/monster_visual.gd")
const AI_POLICY = preload("res://scripts/monsters/monster_ai_policy.gd")
var ai: Dictionary = {}
var aggro_remaining: float = 0.0
var life_id: int = 0
var species_visual: TwilightMonsterVisual
var special_sequence: int = -1
var special_cooldown: float = 3.0
var blink_cooldown: float = 0.0
var returning_home: bool = false
var enraged: bool = false
var social_alert_cooldown: float = 0.0
var decision_elapsed: float = 0.0
var sight_clock: float = 0.0
var sight_cached: bool = false
var motion: TwilightActorMotion = MOTION.new()
var animation_base_scale: Vector2 = Vector2.ONE
var attack_interval: float = 1.25
var configured_attack_range: float = 0.0
var animation_state: String = "idle"
var visual_height: float = 72.0
var motion_connected: bool = false

const LOOT_DROP = preload("res://scripts/loot_drop.gd")

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
var is_boss: bool = false
var drop_items: Array[String] = []
var target_player: TwilightPlayer = null
var world_controller: Node = null
var attack_cooldown: float = 0.0
var repath_cooldown: float = 0.0
var path_stuck_elapsed: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var dead: bool = false
var home_position: Vector2 = Vector2.ZERO
var spawn_region_id: String = ""
var roaming_radius: float = 180.0
var roam_clock: float = 0.0

func setup(record: Dictionary, player_ref: TwilightPlayer, world_ref: Node, texture: Texture2D) -> void:
	# Full reset is required when a corpse is reused by the bounded field pool.
	life_id += 1
	motion = MOTION.new()
	motion_connected = false
	dead = false
	damage_hit_count = 0
	attack_cooldown = 0.
	repath_cooldown = float(get_instance_id()%11)*.025
	path_stuck_elapsed = 0.0
	path = PackedVector2Array()
	path_index = 0
	velocity = Vector2.ZERO
	stun_remaining = 0.; silence_remaining = 0.; hold_remaining = 0.; fear_remaining = 0.
	poison_remaining = 0.; poison_tick_clock = 0.; bleed_remaining = 0.; bleed_tick_clock = 0.
	aggro_remaining = 0.; returning_home = false
	enraged = false; social_alert_cooldown = 0.0
	decision_elapsed = 0.; sight_clock = 0.; sight_cached = false
	special_sequence = -1; special_cooldown = 3.; blink_cooldown = 0.; roam_clock = 0.
	ai = (record.get("ai",{}) as Dictionary).duplicate(true)
	show()
	input_pickable = true
	collision_layer = 2
	collision_mask = 3
	set_physics_process(true)
	home_position = global_position
	name_label.show(); hp_bar.show()
	if has_node("GroundShadow"): $GroundShadow.show()
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
	is_boss = LOOT_DROP.is_boss_record(record)
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
	sprite.material = null
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
	_setup_animation(record)
	if record.has("visual") and motion.frame_source==null:
		sprite.material = MONSTER_ART.material_for(record.visual,sprite.texture)
		if not is_instance_valid(species_visual):
			species_visual = VISUAL.new()
			species_visual.actor = self
			add_child(species_visual)
		species_visual.visual = record.visual
		species_visual.original_source = not preload("res://scripts/animation/visual_manifest.gd").monster_binding(record).is_empty()
		species_visual.special = ai.get("special",{})
		species_visual.warning_active = false
		species_visual.show()
		species_visual.update_pose()
	elif is_instance_valid(species_visual): species_visual.hide()

func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		motion.advance(delta, Vector2.ZERO)
		motion.apply(sprite, animation_base_scale)
		animation_state = motion.state
		if is_instance_valid(species_visual): species_visual.warning_active = false; species_visual.queue_redraw()
		if motion.death_clock >= 1.0:
			if world_controller.has_method("recycle_monster") and world_controller.recycle_monster(self): return
			queue_free()
		return
	var previous: Vector2 = global_position
	decision_elapsed += delta
	if ai.is_empty() or decision_elapsed>=.032:
		_tick_ai(decision_elapsed)
		decision_elapsed = 0.
	elif not motion.active and not is_stunned() and not is_held():
		# Decisions/status clocks run at 30 Hz. Movement, facing, animation and
		# strike markers still advance every physics frame at the engine cadence.
		move_and_slide()
	if is_stunned() or is_feared(): motion.cancel_attack()
	motion.advance(delta, (global_position - previous) / maxf(delta, 0.001))
	if get_viewport_rect().grow(160).has_point(get_global_transform_with_canvas().origin):
		motion.apply(sprite, animation_base_scale)
		if is_instance_valid(species_visual): species_visual.update_pose()
	animation_state = motion.state
	if not motion.active and velocity.length_squared() > 1.0:
		animation_state = "patrol" if velocity.length() < move_speed * 0.7 else "chase"

func _tick_ai(delta: float) -> void:
	if dead or not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		return
	_tick_stun(delta); _tick_silence(delta); _tick_hold(delta); _tick_fear(delta)
	_tick_poison(delta); _tick_bleed(delta); _tick_slow(delta)
	if dead: velocity = Vector2.ZERO; return
	attack_cooldown = maxf(0.,attack_cooldown-delta)
	repath_cooldown = maxf(0.,repath_cooldown-delta)
	aggro_remaining = maxf(0.,aggro_remaining-delta)
	social_alert_cooldown = maxf(0.0, social_alert_cooldown-delta)
	special_cooldown = maxf(0.,special_cooldown-delta)
	blink_cooldown = maxf(0.,blink_cooldown-delta)
	sight_clock = maxf(0.,sight_clock-delta)
	var distance: float = global_position.distance_to(target_player.global_position)
	var enrage_value: Variant = ai.get("enrage", {})
	var enrage_settings: Dictionary = enrage_value as Dictionary if enrage_value is Dictionary else {}
	var next_enraged: bool = AI_POLICY.should_enrage(is_boss, hp, max_hp, enrage_settings)
	if next_enraged and not enraged:
		show_status_text("ENRAGE")
	enraged = next_enraged
	name_label.visible = distance<=520.
	hp_bar.visible = distance<=520.
	if is_stunned() or is_feared():
		motion.cancel_attack()
		if is_instance_valid(species_visual): species_visual.warning_active = false
		velocity = _fear_velocity() if is_feared() and not is_held() else Vector2.ZERO
		path = PackedVector2Array(); path_index = 0
		move_and_slide()
		return
	var field_active: bool = world_controller.field_map!=null
	var concealed: bool = world_controller.has_method("is_player_concealed") and world_controller.is_player_concealed()
	var safe: bool = field_active and world_controller.field_map.is_safe(target_player.global_position)
	var leash: float = float(ai.get("leash_distance",1050.))
	var home_distance: float = global_position.distance_to(home_position)
	# Once a monster disengages, finish walking home before re-acquiring its
	# target. This prevents infinite pursuit/re-aggro loops at the leash edge.
	if field_active and AI_POLICY.should_keep_returning(returning_home,home_distance):
		motion.cancel_attack()
		if is_instance_valid(species_visual): species_visual.warning_active = false
		_move_toward(home_position,delta,.8)
		return
	if returning_home:
		returning_home = false
		aggro_remaining = 0.0
	var disengage: bool = AI_POLICY.should_disengage(field_active,safe,concealed,
		home_distance,target_player.global_position.distance_to(home_position),
		distance,aggro_remaining,float(ai.get("aggro_radius",550.)),leash)
	if disengage:
		motion.cancel_attack()
		if is_instance_valid(species_visual): species_visual.warning_active = false
		aggro_remaining = 0.
		if not returning_home: repath_cooldown = 0.
		returning_home = true
		if home_distance > AI_POLICY.RETURN_RADIUS:
			_move_toward(home_position,delta,.8)
		else:
			returning_home = false
			velocity = Vector2.ZERO
		return
	if concealed:
		_stop_chasing_concealed_player()
		return
	var provoked: bool = aggro_remaining>0. or (bool(ai.get("aggressive",true)) and distance<=float(ai.get("aggro_radius",550.)))
	if field_active and not provoked:
		motion.cancel_attack()
		_roam_field(delta)
		return
	if provoked: aggro_remaining = maxf(aggro_remaining,2.)
	var kind: String = current_attack_type()
	var attack_range: float = current_attack_range()
	if motion.active:
		# A moving melee target can invalidate the windup and trigger pursuit;
		# an already released projectile remains independent of this pose.
		if kind=="melee" and not motion.released and special_sequence!=motion.sequence and distance>attack_range*1.35:
			motion.cancel_attack()
			repath_cooldown = 0.
		else:
			velocity = Vector2.ZERO
			if is_instance_valid(species_visual) and species_visual.warning_active:
				species_visual.warning_progress = clampf(motion.attack_elapsed/maxf(.01,motion.attack_duration*motion.attack_hit_ratio),0.,1.)
			return
	if sight_clock<=0.:
		sight_clock = .12+float(get_instance_id()%5)*.008
		sight_cached = world_controller._has_line_of_sight_world(global_position,target_player.global_position) if distance<=maxf(attack_range,620. if is_boss else attack_range) else false
	var sight: bool = sight_cached and distance<=maxf(attack_range,620. if is_boss else attack_range)
	if is_boss and ai.has("special") and special_cooldown<=0. and distance<=620. and sight and not is_silenced():
		_begin_special()
		return
	if bool(ai.get("blink",false)) and distance<105. and blink_cooldown<=0. and not is_held():
		blink_cooldown = 8.
		var goal: Vector2 = target_player.global_position+target_player.global_position.direction_to(global_position)*190.
		if field_active and world_controller.field_map.walkable(goal) and world_controller.field_map.point_clear(goal) and not world_controller.field_map.is_safe(goal):
			global_position = goal
			repath_cooldown = 0.
			if world_controller.combat_vfx!=null: world_controller.combat_vfx.ring(global_position,40.,Color(.7,.4,1.))
	var retreat: float = float(ai.get("retreat_distance",0))
	if kind in ["ranged","magic"] and distance<retreat and not is_held() and field_active:
		var goal: Vector2 = global_position+target_player.global_position.direction_to(global_position)*72.
		if world_controller.field_map.walkable(goal) and world_controller.field_map.point_clear(goal):
			_move_toward(goal,delta,.85)
			return
	if distance<=attack_range and sight:
		velocity = Vector2.ZERO
		if attack_cooldown<=0.:
			attack_cooldown = AI_POLICY.attack_interval(attack_interval, enraged)
			var style: String = motion.profile.motion_style if kind=="melee" else ("magic" if kind=="magic" else "bow")
			motion.begin_attack(minf(.68,attack_interval*.75),target_player.global_position-global_position,style,motion.profile.marker_for(style))
		return
	if is_held():
		velocity = Vector2.ZERO
		path = PackedVector2Array(); path_index = 0
		return
	if distance>float(ai.get("aggro_radius",760.))*1.7:
		velocity = Vector2.ZERO
		return
	_move_toward(target_player.global_position,delta)

func _move_toward(goal: Vector2, delta: float, speed_ratio: float = 1.) -> void:
	if is_held(): velocity = Vector2.ZERO; return
	if repath_cooldown<=0.:
		repath_cooldown = .65+float(get_instance_id()%7)*.015
		# Most crowded fights are in one open hunting room. Avoid one expensive
		# AStar search per creature when its straight movement corridor is clear.
		if world_controller.field_map!=null and world_controller.field_map.line_clear(global_position,goal):
			path = PackedVector2Array([goal])
		else:
			path = world_controller.find_world_path(global_position,goal)
		path_index = 0
	while path_index<path.size() and global_position.distance_to(path[path_index])<8.: path_index += 1
	if path_index>=path.size():
		velocity = Vector2.ZERO
		path_stuck_elapsed = 0.0
		return
	var point: Vector2 = path[path_index]
	var before_move: Vector2 = global_position
	var tactical_speed: float = move_speed * speed_ratio * AI_POLICY.chase_speed_factor(enraged and not returning_home)
	velocity = global_position.direction_to(point)*minf(tactical_speed,global_position.distance_to(point)/maxf(.001,delta))
	move_and_slide()
	path_stuck_elapsed = AI_POLICY.next_stuck_elapsed(path_stuck_elapsed,
		global_position.distance_to(before_move),velocity.length(),delta)
	if AI_POLICY.should_repath(path_stuck_elapsed):
		# Only clear the path and try AStar again; never teleport through walls.
		repath_cooldown = 0.0
		path_stuck_elapsed = 0.0
		path = PackedVector2Array()
		path_index = 0

func _begin_special() -> void:
	var skill: Dictionary = ai.special
	var aim: Vector2 = target_player.global_position-global_position
	special_cooldown = float(skill.get("cooldown",12.))*(.7 if hp*2<max_hp else 1.)
	velocity = Vector2.ZERO
	special_sequence = motion.begin_attack(float(skill.get("windup",1.15)),aim,"magic",.85)
	if is_instance_valid(species_visual):
		species_visual.warning_active = true
		species_visual.warning_center = global_position
		species_visual.warning_aim = aim.normalized()
		species_visual.warning_progress = 0.
	if world_controller.has_method("show_combat_number"):
		world_controller.show_combat_number(global_position+Vector2(0,-visual_height-30),str(skill.get("label","특수 공격")),Color(1,.55,.2),true)

func _resolve_special() -> void:
	if is_instance_valid(species_visual): species_visual.warning_active = false; species_visual.queue_redraw()
	if dead or is_stunned() or is_feared() or is_silenced() or not _target_attackable(): return
	var skill: Dictionary = ai.special
	var kind: String = str(skill.get("kind","nova"))
	var center: Vector2 = species_visual.warning_center if is_instance_valid(species_visual) else global_position
	var aim: Vector2 = species_visual.warning_aim if is_instance_valid(species_visual) else motion.direction
	var relative: Vector2 = target_player.global_position-center
	var radius: float = float(skill.get("radius",200))
	var hit: bool = relative.length()<=radius
	if kind in ["beam","charge","cone"]:
		var projection: float = relative.dot(aim)
		var width: float = 55. if kind!="cone" else 95.
		hit = projection>=0. and projection<=radius*2. and absf(relative.cross(aim))<=width
		if kind=="cone": hit = relative.length()<=radius*2. and relative.normalized().dot(aim)>=cos(.55)
	if kind=="charge":
		var goal: Vector2 = center+aim*minf(radius*2.,relative.length())
		if world_controller.field_map!=null and world_controller.field_map.walkable(goal) and world_controller.field_map.point_clear(goal) and world_controller.field_map.line_clear(center,goal):
			global_position = goal
	if kind=="summon":
		if world_controller.field_population!=null: world_controller.field_population.summon_for(self)
		hit = false
	if kind=="volley" and world_controller.combat_flights!=null:
		for i: int in range(3):
			_launch_projectile(special_sequence,"ranged",float(i)*.14,.55)
		hit = false
	if world_controller.combat_vfx!=null:
		world_controller.combat_vfx.ring(center,minf(radius,150.),Color(1,.34,.15))
	if hit and world_controller._has_line_of_sight_world(center,target_player.global_position):
		player_hit.emit(self,int(attack_power*float(skill.get("multiplier",1.6))),"magic" if kind not in ["charge","cone"] else "melee")
		if kind=="drain": hp = mini(max_hp,hp+attack_power*2); hp_bar.value = hp

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
		if world_controller.field_map.is_safe(goal) or not world_controller.field_map.walkable(goal) or not world_controller.field_map.point_clear(goal):
			goal = home_position
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
		take_damage(poison_tick_damage, false, "poison")
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
		take_damage(bleed_tick_damage, false, "bleed")
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

func take_damage(amount: int, critical: bool = false, damage_kind: String = "") -> void:
	if dead:
		return
	damage_hit_count += 1
	aggro_remaining = 10.
	if social_alert_cooldown <= 0.0 and is_instance_valid(world_controller) and world_controller.get("field_population")!=null:
		social_alert_cooldown = AI_POLICY.SOCIAL_ALERT_DELAY
		world_controller.field_population.alert_social(self)
	hp = maxi(0, hp - amount)
	hp_bar.value = hp
	_show_damage_number(amount, critical)
	if is_instance_valid(world_controller) and world_controller.has_method("monster_combat_feedback"):
		world_controller.monster_combat_feedback(self, critical, damage_kind)
	motion.react(critical)
	if hp <= 0:
		dead = true
		motion.die()
		if has_node("GroundShadow"): $GroundShadow.hide()
		name_label.hide()
		hp_bar.hide()
		input_pickable = false
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		set_physics_process(true)
		died.emit(self)

func show_miss() -> void:
	if dead:
		return
	if is_instance_valid(world_controller) and world_controller.has_method("show_combat_number"):
		world_controller.show_combat_number(global_position + Vector2(0, -visual_height - 8), "MISS", Color(0.78, 0.86, 1.0))
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
	if is_instance_valid(world_controller) and world_controller.has_method("show_combat_number"):
		world_controller.show_combat_number(global_position + Vector2(0, -visual_height - 8), ("CRIT " if critical else "") + str(amount), Color(1.0, 0.45, 0.2) if critical else Color(1.0, 0.83, 0.4), critical)
		return
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

func _setup_animation(record: Dictionary) -> void:
	motion.profile = ANIMATION_CATALOG.for_record("monster", record)
	# Sample optional native art onto the existing Sprite2D; no scene/AI/UI changes.
	motion.frame_source = null
	if not motion.profile.frames_path.is_empty():
		var frames: SpriteFrames = ANIMATION_CATALOG.frames_for_profile(motion.profile, "")
		var first: Texture2D = ANIMATION_CATALOG.first_texture(frames)
		if first != null:
			motion.frame_source = frames
			sprite.texture = first
	motion.profile.reference_speed = maxf(1.0, base_move_speed)
	visual_height = float(record.get("visual_height", 92.0 if is_boss else (62.0 if motion.profile.motion_style == "crawl" else 72.0)))
	if sprite.texture != null:
		animation_base_scale = Vector2.ONE * (visual_height / maxf(1.0, maxf(sprite.texture.get_width(), sprite.texture.get_height())))
		if record.has("visual") and motion.frame_source==null:
			var scale_value: float = minf(visual_height/maxf(1.,sprite.texture.get_height()),visual_height*1.65/maxf(1.,sprite.texture.get_width()))
			animation_base_scale = Vector2.ONE*scale_value
			visual_height = sprite.texture.get_height()*scale_value
	else:
		animation_base_scale = Vector2.ONE
	# Foot anchor and hit point depend on visible body size, not one fixed offset.
	motion.profile.sprite_offset = Vector2(0, -visual_height * 0.46)
	motion.profile.hit_position = Vector2(0, -visual_height * 0.42)
	motion.profile.projectile_origin = Vector2(visual_height * 0.15, -visual_height * 0.48)
	motion.profile.shadow_size = Vector2(visual_height * 0.25, visual_height * 0.08)
	var overrides: Dictionary = ANIMATION_CATALOG.records.get(motion.profile.profile_id, {}).duplicate(true)
	overrides.merge(record.get("animation_profile", {}), true)
	for property: String in ["sprite_offset", "hit_position", "projectile_origin", "shadow_size"]:
		var value: Variant = overrides.get(property)
		if value is Array and value.size() == 2: motion.profile.set(property, Vector2(value[0], value[1]))
	attack_interval = maxf(0.12, float(record.get("attack_interval", 1.25)))
	configured_attack_range = maxf(0.0, float(record.get("attack_range", 0.0)))
	var shape: CircleShape2D = $CollisionShape2D.shape.duplicate() as CircleShape2D
	shape.radius = maxf(1.0,float(record.get("collision_radius",19.)))
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = motion.profile.collision_offset
	name_label.position.y = -visual_height - 20.0
	hp_bar.position.y = -visual_height - 4.0
	if not motion_connected:
		motion.strike.connect(_release_attack)
		motion_connected = true
	if not has_node("GroundShadow"):
		var shadow: Node2D = preload("res://scripts/animation/actor_shadow.gd").new()
		shadow.name = "GroundShadow"
		shadow.radius = motion.profile.shadow_size
		add_child(shadow)
	motion.apply(sprite, animation_base_scale)

func current_attack_range() -> float:
	if configured_attack_range > 0.0 and not is_silenced(): return configured_attack_range
	var kind: String = current_attack_type()
	return 280.0 if kind == "magic" else (220.0 if kind == "ranged" else 58.0)

func combat_hit_position() -> Vector2:
	return global_position + motion.profile.hit_position

func _release_attack(id: int) -> void:
	if dead or id != motion.sequence or not is_instance_valid(target_player): return
	if is_stunned() or is_feared(): return
	if id==special_sequence:
		_resolve_special()
		return
	if global_position.distance_to(target_player.global_position) > current_attack_range(): return
	if not world_controller._has_line_of_sight_world(global_position, target_player.global_position): return
	if world_controller.is_player_concealed(): return
	if world_controller.field_map != null and world_controller.field_map.is_safe(target_player.global_position): return
	var kind: String = current_attack_type()
	if kind in ["ranged", "magic"] and world_controller.combat_flights != null:
		_launch_projectile(id,kind)
	else:
		_resolve_attack(id, kind)

func _target_attackable() -> bool:
	if not is_instance_valid(target_player) or world_controller.hp<=0: return false
	if world_controller.is_player_concealed(): return false
	return world_controller.field_map==null or not world_controller.field_map.is_safe(target_player.global_position)

func _launch_projectile(id: int, kind: String, delay: float = 0., ratio: float = 1.) -> void:
	var aim: Vector2 = target_player.combat_hit_position()
	var origin: Vector2 = combat_hit_position()+motion.direction*visual_height*.18
	var color: Color = {"fire":Color(1,.35,.10),"water":Color(.2,.7,1),"wind":Color(.5,1,.75),"earth":Color(.8,.65,.35),"dark":Color(.75,.4,1)}.get(attack_element,Color(1,.87,.5))
	world_controller.combat_flights.launch(origin,target_player,kind,_resolve_attack.bind(id,kind,life_id,ratio),800. if kind=="magic" else 1100.,delay,
		{"aim":aim,"hit_radius":30.,"obstruction":_projectile_clear,"color":color})

func _projectile_clear(from: Vector2, to: Vector2) -> bool:
	if dead: return false
	# Projectiles draw at torso height; map obstruction checks use their ground
	# projection, the same navigational/physical geometry as walking actors.
	var offset: Vector2 = motion.profile.hit_position
	return world_controller._has_line_of_sight_world(from-offset,to-offset)

func _resolve_attack(id: int, kind: String, born: int = -1, ratio: float = 1.) -> void:
	if dead or (born!=-1 and born!=life_id) or not _target_attackable(): return
	if kind=="melee" and (id!=motion.sequence or global_position.distance_to(target_player.global_position)>current_attack_range()): return
	if not world_controller._has_line_of_sight_world(global_position,target_player.global_position): return
	player_hit.emit(self,maxi(1,int(attack_power*ratio)),kind)
