extends Node
class_name FieldPopulation

const COORD = preload("res://scripts/maps/world_coordinates.gd")
const DIRECTOR = preload("res://scripts/monsters/boss_director.gd")
const BOSS_HUD = preload("res://scripts/monsters/boss_hud.gd")
const MAX_POOL: int = 64
const IDLE_POOL_TARGET: int = 16
const MAP_CHANGE_POOL_TARGET: int = 8
const IDLE_POOL_AGE_MS: int = 30000
const AI_POLICY = preload("res://scripts/monsters/monster_ai_policy.gd")
var world: Node
var field: PlayableField
var slots: Array[Dictionary] = []
var records: Dictionary = {}
var boss_director: TwilightBossDirector = DIRECTOR.new()
var wake_clock: float = 0.0
var generation: int = 0
var available: Array[TwilightMonster] = []
var available_since: Dictionary = {}
var pool_root: Node2D
var boss_hud: CanvasLayer
var summons: Array[Dictionary] = []
var pending_initial_spawns: Array[Dictionary] = []
var pending_spawn_ids: Dictionary = {}
const INITIAL_SPAWNS_PER_FRAME: int = 3
# A slot whose spawn search fails (full or unreachable region) retried every
# 2 s. On aden_world 27 such slots each ran up to 64x96 floor probes in the
# same frame: a ~150 ms stall every 2 s during play. Repeated failures now
# back off (2, 4, 8 ... 60 s) with jitter so they never line up, a success
# resets the delay, and one wake spends at most SPAWN_SEARCH_BUDGET_USEC on
# normal respawn searches (the rest wait for the next wake). Bosses keep
# their own cadence.
const SPAWN_RETRY_MIN: float = 2.0
const SPAWN_RETRY_MAX: float = 60.0
const SPAWN_SEARCH_BUDGET_USEC: int = 6000
var retry_jitter := RandomNumberGenerator.new()
const INITIAL_SPAWN_BUDGET_USEC: int = 4000

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
	var previous_map: String=str(field.data.map_id) if field!=null else ""
	var next_map: String=str(value.data.map_id) if value!=null else ""
	if previous_map!=next_map:
		_trim_pool(MAP_CHANGE_POOL_TARGET,true)
		preload("res://scripts/animation/animation_catalog.gd").release_region_frames()
	generation += 1
	world = controller
	field = value
	slots.clear()
	pending_initial_spawns.clear()
	pending_spawn_ids.clear()
	wake_clock = 0.
	set_process(field != null)
	if field == null: return
	records.clear()
	var reviewed:Dictionary={}
	for record: Dictionary in world.monster_db:
		if not bool(record.get("catalog_only", false)): records[str(record.name)] = record
		elif preload("res://scripts/monsters/monster_catalog.gd").reviewed_record_allowed(record):reviewed[str(record.get("sourceId",""))]=record
	# Catalog-only identities opt in through an exact verified source region.
	for region: Dictionary in field.data["monster_spawn"]:
		if region.has("source_game_id"):
			var source:Dictionary=reviewed.get(str(region.source_game_id),{})
			if source.is_empty() or str(source.get("source_npc_id",""))!=str(region.source_npc_id) or region.monster_types!=[str(source.name)]:continue
			records[str(source.name)]=source
		for index: int in range(int(region["max_count"])):
			var slot: Dictionary = {"region":region,"index":index,"slot_id":slots.size(),"monster":null,"remaining":0.0,"has_spawned":false}
			slots.append(slot)
			if _zone_active(region):
				# Boss state is restored immediately. Normal PNG populations fill in
				# bounded batches while retaining their authored slot and RNG order.
				if region.has("local_habitat") or ((field is NativePngField or region.has("source_game_id")) and str(region.get("mode","normal"))!="boss"):
					pending_initial_spawns.append(slot)
					pending_spawn_ids[int(slot.slot_id)]=true
				else:_spawn_slot(slot)

func _source_visible(point:Vector2) -> bool:
	var camera:Camera2D=world.player.camera
	var extent:Vector2=get_viewport().get_visible_rect().size/camera.zoom
	return Rect2(camera.get_screen_center_position()-extent*.5,extent).grow(48.0).has_point(point)

func _zone_active(region: Dictionary) -> bool:
	if region.has("source_game_id") or region.has("local_habitat"):
		var r:Array=region.rect
		return Rect2(r[0],r[1],r[2],r[3]).grow(1600.0).has_point(world.player.global_position)
	# One Escaros PNG includes five former fields (165 slots). Creating every
	# distant normal monster on entry freezes the map; activate nearby habitats
	# while keeping every slot, boss identity and respawn timer intact.
	if field is NativePngField and str(field.data.map_id)=="escaros_world" and str(region.get("mode","normal"))!="boss":
		var extents: Array=region.rect
		var area:=Rect2(float(extents[0]),float(extents[1]),float(extents[2]),float(extents[3]))
		return area.grow(1650.0).has_point(world.player.global_position)
	if str(region.get("mode","normal")) != "dense": return true
	var a: Array = region.rect
	var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
	return center.distance_to(world.player.global_position) <= float(region.get("activation_distance",1900.))

func _spawn_point(region: Dictionary) -> Vector2:
	var radius: float = float(region.get("spawn_radius",0))
	var a: Array = region.rect
	var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
	var spacing: float = float(region.get("min_spacing",28.))
	# Dense hotspots need more attempts near capacity, without reducing the
	# authored population target or weakening collision/spacing constraints.
	var attempts: int = 160 if str(region.get("mode", "normal")) == "dense" else 64
	for attempt: int in range(attempts):
		var p: Vector2 = preload("res://scripts/maps/source_map_spawns.gd").sample_spawn(field,region,world.rng) if region.has("source_sampling") else field.sample_spawn(str(region.id),world.rng)
		if not p.is_finite(): return Vector2.INF
		if (region.has("source_game_id") or region.has("local_habitat")) and not preload("res://scripts/maps/source_map_spawns.gd").floor_allowed(field,p):continue
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
	# A repeated wake/spawn request must not orphan a live actor when the slot
	# is reassigned. Dead or freed actors may still be replaced normally.
	var occupant: Variant = slot.get("monster")
	if is_instance_valid(occupant) and not occupant.dead: return
	var region: Dictionary = slot.region
	var boss: bool = str(region.get("mode","normal")) == "boss"
	if boss:
		var identity: String = boss_director.key(str(field.data.map_id),region)
		for other: Dictionary in slots:
			if str(other.region.get("mode","normal")) != "boss": continue
			var live: Variant = other.get("monster")
			if is_instance_valid(live) and not live.dead and boss_director.key(str(field.data.map_id),other.region) == identity:
				return
	if boss and not boss_director.can_spawn(str(field.data.map_id),region): return
	var p: Vector2 = _spawn_point(region)
	if not p.is_finite(): return
	if bool(slot.get("has_spawned",false)) and region.has("respawn_on_screen") and not bool(region.respawn_on_screen) and _source_visible(p):
		slot.remaining=3.0
		return
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
	if region.has("source_game_id"):
		record=record.duplicate(true)
		record["ai"]={"aggressive":str(record.get("source_raw_fields",{}).get("agro","0"))=="1"}
	var variant: Dictionary = region.get("variants",{}).get(name_value,{})
	if not variant.is_empty():
		record = record.duplicate(true)
		var ratio: float = clampf(float(variant.get("level",record.get("lv",1)))/maxf(1.,float(record.get("lv",1))),.6,2.2)
		record["lv"] = int(variant.get("level",record.get("lv",1)))
		record["hp"] = int(float(record.get("hp",100))*ratio)
		record["atk"] = int(float(record.get("atk",10))*sqrt(ratio))
	# The authored regional level range is for this spawn instance only. Never
	# mutate a species' shared DB record or silently rescale its base HP/drops.
	var level_range: Array = region.get("level", [])
	# Renewed rosters retain catalog levels; their historical broad range
	# is not an implicit species override. Explicit variants and legacy
	# layouts still enforce the authored regional range on a copy.
	if level_range.size() == 2 and (variant.has("level") or not field.data.has("spawn_layout_revision")):
		var local_level: int = clampi(int(record.get("lv", 1)), int(level_range[0]), int(level_range[1]))
		if local_level != int(record.get("lv", 1)):
			record = record.duplicate(true)
			record["lv"] = local_level
	# A node queued by combat/map cleanup can still receive its last physics
	# callback before deletion. Never cast a stale pool entry to a live actor.
	var monster: TwilightMonster = null
	while not available.is_empty():
		var candidate: Variant = available.pop_back()
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion(): continue
		available_since.erase(candidate.get_instance_id())
		monster = candidate as TwilightMonster
		break
	if monster == null: monster = world.MONSTER_SCENE.instantiate()
	# Place the actor before it (re)enters the physics space. Monsters are
	# kinematic bodies: moving one after it is registered is simulated as motion
	# from its old transform, so its broadphase box sweeps from the origin (new
	# instance) or the previous map (pooled) to its spawn. With ~360 Aden actors
	# that one step produced ~350,000 collision pairs and stalled for minutes.
	monster.position = world.monsters_root.to_local(p)
	if monster.get_parent() != null: monster.reparent(world.monsters_root,false)
	else: world.monsters_root.add_child(monster)
	monster.global_position = p
	# A pooled actor may carry the last map's source override. Restore that
	# before setup writes this life/record's normal animation collision shape.
	preload("res://scripts/maps/source_body_profile.gd").apply(monster,false)
	monster.setup(record,world.player,world,world._monster_texture(record))
	# setup/_setup_animation writes collision_radius and collision_offset.
	# Apply the source foot LAST so monsters and the player really use 4px.
	preload("res://scripts/maps/source_body_profile.gd").apply(monster,field is RemakePlayableField or field is NativePngField)
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
	monster.set_meta("source_game_id",str(region.get("source_game_id","")))
	monster.set_meta("source_spawn_key",str(region.get("source_key","")))
	slot.monster = monster
	slot.has_spawned=true
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
			if box.has_point(saved_home) and field.spawn_contains(region,saved_home) and field.walkable(saved_home) and field.point_clear(saved_home) and not field.is_safe(saved_home): monster.home_position = saved_home
		if position.size()==2:
			var saved := Vector2(float(position[0]),float(position[1]))
			if destination_allowed(monster,saved) and field.walkable(saved) and field.point_clear(saved) and not field.is_safe(saved) and saved.distance_to(monster.home_position)<float(monster.ai.get("leash_distance",820.)):
				monster.global_position = saved
		boss_director.capture(str(field.data.map_id),region,monster)
	_update_activity(monster)
	# Spread the first AI decision across the existing 30 Hz cadence.
	if field is NativePngField and str(field.data.map_id)=="escaros_world":
		monster.decision_elapsed=float(int(slot.slot_id)%2)*.016

func destination_allowed(monster: TwilightMonster, point: Vector2) -> bool:
	var id: int = int(monster.get_meta("field_slot",-1))
	if id < 0 or id >= slots.size(): return true
	var region: Dictionary = slots[id].region
	if region.has("source_game_id") or region.has("local_habitat"):
		return preload("res://scripts/maps/source_map_spawns.gd").floor_allowed(field,point) and point.distance_to(monster.home_position)<=float(monster.ai.get("leash_distance",1050.0))
	if field is RemakePlayableField:
		return (field as RemakePlayableField).remake_region_contains(str(region.id),point)
	var patrol: Dictionary = region.get("patrol_region",{})
	return patrol.is_empty() or field.REGION_GEOMETRY.contains(patrol,point)

func release(monster: TwilightMonster) -> void:
	var id: int = int(monster.get_meta("field_slot",-1))
	if id<0 or id>=slots.size() or slots[id].monster!=monster: return
	var slot: Dictionary = slots[id]
	slot.monster = null
	slot.remaining = 0.0 if str(slot.region.get("mode","normal"))=="boss" else float(slot.region.respawn_time)
	if slot.region.has("source_respawn_seconds"):
		var delay:Array=slot.region.source_respawn_seconds
		slot.remaining=float(world.rng.randi_range(int(delay[0]),maxi(int(delay[0]),int(delay[1])-1)))
	if str(slot.region.get("mode","normal"))=="boss":
		boss_director.died(str(field.data.map_id),slot.region)
		_clear_summons(monster.get_instance_id())

func recycle(monster: TwilightMonster) -> bool:
	if not is_instance_valid(monster) or monster.is_queued_for_deletion(): return false
	if not monster.dead or int(monster.get_meta("population_generation",-1))!=generation: return false
	if available.has(monster): return true
	if available.size()>=MAX_POOL: return false
	monster.hide()
	monster.retire_for_pool()
	monster.reparent(pool_root,false)
	available.append(monster)
	available_since[monster.get_instance_id()]=Time.get_ticks_msec()
	return true

func _trim_pool(target: int, force: bool) -> void:
	var now: int=Time.get_ticks_msec()
	for index: int in range(available.size()-1,-1,-1):
		var monster: TwilightMonster=available[index]
		if is_instance_valid(monster) and not monster.is_queued_for_deletion():continue
		if is_instance_valid(monster):available_since.erase(monster.get_instance_id())
		available.remove_at(index)
	while available.size()>target:
		var candidate: TwilightMonster=available[0]
		if not force and now-int(available_since.get(candidate.get_instance_id(),now))<IDLE_POOL_AGE_MS:break
		available.pop_front()
		available_since.erase(candidate.get_instance_id())
		candidate.queue_free()

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
		monster.position = world.monsters_root.to_local(p)
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
	_drain_initial_spawns()
	wake_clock -= delta
	var refresh: bool = wake_clock<=0.
	if refresh:
		wake_clock = .4
		_trim_pool(IDLE_POOL_TARGET,false)
	# Camera geometry is constant during this synchronous wake sweep. Build it
	# lazily so empty populations and non-Escaros fields do no extra work.
	var activity_view := Rect2()
	var activity_radius: float = -1.0
	var escaros_refresh: bool = refresh and field is NativePngField and str(field.data.map_id)=="escaros_world"
	var search_spent: int = 0
	for slot: Dictionary in slots:
		if pending_spawn_ids.has(int(slot.slot_id)):continue
		var monster: TwilightMonster = slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		if not is_instance_valid(monster):
			slot.remaining = maxf(0.,float(slot.remaining)-delta)
			if float(slot.remaining)<=0. and (refresh or str(slot.region.get("mode",""))=="boss") and _zone_active(slot.region):
				if slot.region.has("source_game_id") or slot.region.has("local_habitat"):
					pending_initial_spawns.append(slot)
					pending_spawn_ids[int(slot.slot_id)]=true
					continue
				var boss_slot: bool = str(slot.region.get("mode","normal"))=="boss"
				if not boss_slot and search_spent>=SPAWN_SEARCH_BUDGET_USEC:continue
				var search_started: int = Time.get_ticks_usec()
				_spawn_slot(slot)
				if not boss_slot:search_spent += Time.get_ticks_usec()-search_started
				# Full/blocked regions can fail all 64–160 candidate probes. Do not
				# repeat that costly search at every 0.4s wake until a later retry.
				# Successful spawns and boss cooldown semantics remain unchanged.
				if not is_instance_valid(slot.monster) and str(slot.region.get("mode","normal"))!="boss":
					slot.remaining = _spawn_retry_delay(slot)
				elif is_instance_valid(slot.monster):slot.spawn_failures = 0
		elif refresh:
			if escaros_refresh and activity_radius < 0.0:
				var camera: Camera2D = world.player.camera
				var extent: Vector2 = get_viewport().get_visible_rect().size/camera.zoom
				activity_view = Rect2(camera.get_screen_center_position()-extent*.5,extent).grow(240.0)
				activity_radius = extent.length()*.5+320.0
			_update_activity(monster, activity_view, activity_radius)

func _spawn_retry_delay(slot: Dictionary) -> float:
	var failures: int = int(slot.get("spawn_failures",0))+1
	slot.spawn_failures = failures
	return minf(SPAWN_RETRY_MAX,SPAWN_RETRY_MIN*pow(2.0,failures-1))*retry_jitter.randf_range(.8,1.2)

func _drain_initial_spawns() -> void:
	var spawn_start: int=Time.get_ticks_usec()
	var initial_count: int=0
	while not pending_initial_spawns.is_empty() and initial_count<INITIAL_SPAWNS_PER_FRAME:
		if initial_count>0 and Time.get_ticks_usec()-spawn_start>=INITIAL_SPAWN_BUDGET_USEC:break
		var pending: Dictionary=pending_initial_spawns.pop_front()
		pending_spawn_ids.erase(int(pending.slot_id))
		if _zone_active(pending.region):
			_spawn_slot(pending)
			if not is_instance_valid(pending.monster):pending.remaining=maxf(_spawn_retry_delay(pending),float(pending.remaining))
			else:pending.spawn_failures=0
		initial_count+=1

func _update_activity(monster: TwilightMonster, view: Rect2 = Rect2(), view_radius: float = -1.0) -> void:
	var distance: float=monster.global_position.distance_to(world.player.global_position)
	var awake: bool=distance<float(field.data.streaming.monster_sleep_distance)
	if field is NativePngField and str(field.data.map_id)=="escaros_world":
		# Standalone spawn updates still take a fresh camera snapshot. Never
		# retain this context across frames, camera changes or map transitions.
		if view_radius < 0.0:
			var camera: Camera2D = world.player.camera
			var extent: Vector2 = get_viewport().get_visible_rect().size/camera.zoom
			view = Rect2(camera.get_screen_center_position()-extent*.5,extent).grow(240.0)
			view_radius = extent.length()*.5+320.0
		# Preserve combat, death/recycling and status clocks outside the view.
		var busy: bool=monster.dead or monster.motion.active or monster.aggro_remaining>0 or monster.returning_home or monster.poison_remaining>0 or monster.bleed_remaining>0 or monster.slow_remaining>0 or monster.is_stunned() or monster.is_held() or monster.is_feared() or monster.is_silenced()
		var radius: float=maxf(view_radius,float(monster.ai.get("aggro_radius",420.0))*1.7+320.0)
		awake=busy or distance<radius
		monster.visible=view.has_point(monster.global_position) or (monster.is_boss and monster.motion.active)
	monster.set_physics_process(awake)
	if not awake:monster.velocity=Vector2.ZERO
