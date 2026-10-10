extends Node
class_name FieldPopulation

const COORD = preload("res://scripts/maps/world_coordinates.gd")
const DIRECTOR = preload("res://scripts/monsters/boss_director.gd")
const BOSS_HUD = preload("res://scripts/monsters/boss_hud.gd")
const MAX_POOL: int = 64
const AI_POLICY = preload("res://scripts/monsters/monster_ai_policy.gd")
var world: Node
var field: PlayableField
var slots: Array[Dictionary] = []
var records: Dictionary = {}
var boss_director: TwilightBossDirector = DIRECTOR.new()
var wake_clock: float = 0.0
var generation: int = 0
var available: Array[TwilightMonster] = []
var pool_root: Node2D
var boss_hud: CanvasLayer
var summons: Array[Dictionary] = []

func _ready() -> void:
	pool_root = Node2D.new()
	pool_root.name = "DormantMonsterPool"
	add_child(pool_root)
	pool_root.hide()
	boss_hud = BOSS_HUD.new()
	boss_hud.controller = self
	add_child(boss_hud)

func configure(controller: Node, value: PlayableField) -> void:
	_capture_bosses()
	_clear_summons()
	generation += 1
	world = controller
	field = value
	slots.clear()
	wake_clock = 0.
	set_process(field != null)
	if field == null: return
	records.clear()
	for record: Dictionary in world.monster_db: records[str(record.name)] = record
	for region: Dictionary in field.data["monster_spawn"]:
		for index: int in range(int(region["max_count"])):
			var slot: Dictionary = {"region":region,"index":index,"slot_id":slots.size(),"monster":null,"remaining":0.0}
			slots.append(slot)
			if _zone_active(region): _spawn_slot(slot)

func _zone_active(region: Dictionary) -> bool:
	if str(region.get("mode","normal")) != "dense": return true
	var a: Array = region.rect
	var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
	return center.distance_to(world.player.global_position) <= float(region.get("activation_distance",1900.))

func _spawn_point(region: Dictionary) -> Vector2:
	var radius: float = float(region.get("spawn_radius",0))
	var a: Array = region.rect
	var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
	var spacing: float = float(region.get("min_spacing",28.))
	for attempt: int in range(64):
		var p: Vector2 = field.sample_spawn(str(region.id),world.rng)
		if not p.is_finite(): return Vector2.INF
		if radius > 0. and p.distance_to(center) > radius: continue
		var clear: bool = true
		for slot: Dictionary in slots:
			var monster: TwilightMonster = slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
			if is_instance_valid(monster) and not monster.dead and monster.global_position.distance_squared_to(p)<spacing*spacing:
				clear = false
				break
		if clear: return p
	return Vector2.INF

func _spawn_slot(slot: Dictionary) -> void:
	var region: Dictionary = slot.region
	var boss: bool = str(region.get("mode","normal")) == "boss"
	if boss and not boss_director.can_spawn(str(field.data.map_id),region): return
	var p: Vector2 = _spawn_point(region)
	if not p.is_finite(): return
	var names: Array = region.monster_types
	var name_value: String = str(names[int(slot.index)%names.size()])
	var weights: Array = region.get("weights",[])
	if weights.size() == names.size():
		var total: float = 0.
		for weight: Variant in weights: total += maxf(0.,float(weight))
		var choice: float = world.rng.randf()*total
		for i: int in range(names.size()):
			choice -= maxf(0.,float(weights[i]))
			if choice <= 0.: name_value = str(names[i]); break
	var record: Dictionary = records.get(name_value,{})
	if record.is_empty():
		push_error("Unknown field monster: "+name_value)
		return
	var variant: Dictionary = region.get("variants",{}).get(name_value,{})
	if not variant.is_empty():
		record = record.duplicate(true)
		var ratio: float = clampf(float(variant.get("level",record.get("lv",1)))/maxf(1.,float(record.get("lv",1))),.6,2.2)
		record["lv"] = int(variant.get("level",record.get("lv",1)))
		record["hp"] = int(float(record.get("hp",100))*ratio)
		record["atk"] = int(float(record.get("atk",10))*sqrt(ratio))
	# A node queued by combat/map cleanup can still receive its last physics
	# callback before deletion. Never cast a stale pool entry to a live actor.
	var monster: TwilightMonster = null
	while not available.is_empty():
		var candidate: Variant = available.pop_back()
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion(): continue
		monster = candidate as TwilightMonster
		break
	if monster == null: monster = world.MONSTER_SCENE.instantiate()
	if monster.get_parent() != null: monster.reparent(world.monsters_root,false)
	else: world.monsters_root.add_child(monster)
	monster.global_position = p
	monster.setup(record,world.player,world,world._monster_texture(record))
	monster.attack_cooldown = world.rng.randf_range(0.,monster.attack_interval*.7)
	if not monster.died.is_connected(world._on_monster_died): monster.died.connect(world._on_monster_died)
	if not monster.player_hit.is_connected(world._on_player_hit): monster.player_hit.connect(world._on_player_hit)
	if not monster.selected.is_connected(world._select_monster): monster.selected.connect(world._select_monster)
	if variant.has("name"):
		monster.monster_name = str(variant.name)
		monster.name_label.text = "Lv.%d %s" % [monster.monster_level,monster.monster_name]
	monster.name_label.add_theme_font_size_override("font_size",17)
	monster.name_label.add_theme_color_override("font_color",Color("fff0cc"))
	monster.home_position = p
	monster.spawn_region_id = str(region.id)
	monster.roaming_radius = float(region.get("roaming_radius",120))
	monster.collision_mask = 4
	monster.set_meta("field_slot",int(slot.slot_id))
	monster.set_meta("population_generation",generation)
	monster.set_meta("summoned",false)
	slot.monster = monster
	slot.remaining = 0.
	if boss:
		var state: Dictionary = boss_director.state_for(str(field.data.map_id),region)
		if int(state.hp)>0: monster.hp = mini(monster.max_hp,int(state.hp)); monster.hp_bar.value = monster.hp
		var position: Array = state.position
		var home: Array = state.get("home",[])
		if home.size()==2:
			var saved_home := Vector2(float(home[0]),float(home[1]))
			var rect: Array = region.rect
			var box := Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))
			if box.has_point(saved_home) and field.walkable(saved_home) and field.point_clear(saved_home) and not field.is_safe(saved_home): monster.home_position = saved_home
		if position.size()==2:
			var saved := Vector2(float(position[0]),float(position[1]))
			if field.walkable(saved) and field.point_clear(saved) and not field.is_safe(saved) and saved.distance_to(monster.home_position)<float(monster.ai.get("leash_distance",820.)):
				monster.global_position = saved
		boss_director.capture(str(field.data.map_id),region,monster)
	monster.set_physics_process(monster.global_position.distance_to(world.player.global_position)<float(field.data.streaming.monster_sleep_distance))

func release(monster: TwilightMonster) -> void:
	var id: int = int(monster.get_meta("field_slot",-1))
	if id<0 or id>=slots.size() or slots[id].monster!=monster: return
	var slot: Dictionary = slots[id]
	slot.monster = null
	slot.remaining = float(slot.region.respawn_time)
	if str(slot.region.get("mode","normal"))=="boss":
		boss_director.died(str(field.data.map_id),slot.region)
		_clear_summons(monster.get_instance_id())

func recycle(monster: TwilightMonster) -> bool:
	if not is_instance_valid(monster) or monster.is_queued_for_deletion(): return false
	if not monster.dead or int(monster.get_meta("population_generation",-1))!=generation: return false
	if available.has(monster): return true
	if available.size()>=MAX_POOL: return false
	monster.hide()
	monster.set_physics_process(false)
	monster.reparent(pool_root,false)
	available.append(monster)
	return true

func alert_social(source: TwilightMonster) -> void:
	# Bound pack assistance and reject retired, returning, unsafe or unrelated
	# helpers. A wall blocks local aggro propagation just like movement.
	if field==null or not is_instance_valid(source) or source.dead or source.returning_home:
		return
	if not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	var radius: float = clampf(float(source.ai.get("social_radius",0)),0.0,360.0)
	var group: String = str(source.ai.get("social_group",""))
	if radius <= 0.0 or group.strip_edges().is_empty():
		return
	var safe: bool = field.is_safe(world.player.global_position)
	var hidden: bool = world.has_method("is_player_concealed") and world.is_player_concealed()
	if safe or hidden:
		return
	var candidates: Array[TwilightMonster] = []
	for slot: Dictionary in slots:
		var other: TwilightMonster = slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		if not is_instance_valid(other) or other.dead or other==source or not other.is_physics_processing():
			continue
		var leash: float = float(other.ai.get("leash_distance",1050.))
		if not AI_POLICY.can_assist(group,str(other.ai.get("social_group","")),
			other.global_position.distance_to(source.global_position),
			other.global_position.distance_to(other.home_position),
			world.player.global_position.distance_to(other.home_position),
			leash,radius,safe,hidden,other.returning_home):
			continue
		if not field.line_clear(source.global_position,other.global_position):
			continue
		candidates.append(other)
	# Nearest valid allies receive the call, not arbitrary spawn-slot order.
	candidates.sort_custom(func(a: TwilightMonster,b: TwilightMonster) -> bool:
		return a.global_position.distance_squared_to(source.global_position) < b.global_position.distance_squared_to(source.global_position))
	for index: int in range(mini(AI_POLICY.MAX_SOCIAL_ASSIST,candidates.size())):
		var ally: TwilightMonster = candidates[index]
		ally.aggro_remaining = maxf(ally.aggro_remaining,8.0)
		ally.repath_cooldown = 0.0

func summon_for(owner: TwilightMonster) -> void:
	var owned: int = 0
	for value: Dictionary in summons:
		if int(value.owner)==owner.get_instance_id() and is_instance_valid(value.monster): owned += 1
	if owned>=4: return
	var region: Dictionary = {}
	for slot: Dictionary in slots:
		if str(slot.region.get("mode","normal"))=="normal": region = slot.region; break
	if region.is_empty(): return
	for i: int in range(mini(2,4-owned)):
		var p: Vector2 = owner.global_position+Vector2.from_angle(float(i)*PI)*100.
		if not field.walkable(p) or not field.point_clear(p) or field.is_safe(p): continue
		var record: Dictionary = (records[str(region.monster_types[i%region.monster_types.size()])] as Dictionary).duplicate(true)
		record["drop"] = []
		var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(monster)
		monster.global_position = p
		monster.setup(record,world.player,world,world._monster_texture(record))
		monster.home_position = owner.home_position
		monster.collision_mask = 4
		monster.aggro_remaining = 20.
		monster.set_meta("summoned",true)
		monster.died.connect(world._on_monster_died)
		monster.player_hit.connect(world._on_player_hit)
		monster.selected.connect(world._select_monster)
		summons.append({"owner":owner.get_instance_id(),"monster":monster})

func _clear_summons(owner: int = -1) -> void:
	for i: int in range(summons.size()-1,-1,-1):
		if owner!=-1 and int(summons[i].owner)!=owner: continue
		var monster: Variant = summons[i].monster
		if is_instance_valid(monster): monster.queue_free()
		summons.remove_at(i)

func _capture_bosses() -> void:
	if field==null: return
	for slot: Dictionary in slots:
		if str(slot.region.get("mode",""))=="boss": boss_director.capture(str(field.data.map_id),slot.region,slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null)

func export_state() -> Dictionary:
	_capture_bosses()
	return boss_director.export_state()

func import_state(value: Variant) -> void:
	boss_director.import_state(value)

func _process(delta: float) -> void:
	if field==null: return
	boss_director.tick(delta)
	wake_clock -= delta
	var refresh: bool = wake_clock<=0.
	if refresh: wake_clock = .4
	for slot: Dictionary in slots:
		var monster: TwilightMonster = slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		if not is_instance_valid(monster):
			slot.remaining = maxf(0.,float(slot.remaining)-delta)
			if float(slot.remaining)<=0. and (refresh or str(slot.region.get("mode",""))=="boss") and _zone_active(slot.region): _spawn_slot(slot)
		elif refresh:
			var distance: float = monster.global_position.distance_to(world.player.global_position)
			monster.set_physics_process(distance<float(field.data.streaming.monster_sleep_distance))
			if not monster.is_physics_processing(): monster.velocity = Vector2.ZERO
