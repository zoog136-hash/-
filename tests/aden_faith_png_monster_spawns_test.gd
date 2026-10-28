extends SceneTree
const REGISTRY = preload("res://scripts/maps/native_png_registry.gd")
const SPAWNS = preload("res://scripts/monsters/native_png_spawns.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const FIELD = preload("res://scripts/maps/native_png_field.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const DIRECTOR = preload("res://scripts/monsters/boss_director.gd")
const ROUTES = preload("res://tests/native_png_route_checks.gd")
const EXPECTED := {"aden_world":[72,5],"faith_01":[6,1],"faith_02":[6,1],"faith_03":[6,1],"faith_04":[9,1]}
var checks: int = 0
var failures: Array[String] = []
var records: Array = []
var world: TwilightWorld
var visited_habitats: Dictionary = {}
var tested_bosses: Dictionary = {}
var normal_deaths: int = 0
var actual_drops: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("ADEN_FAITH_PNG_MONSTER_FAIL: "+label)
func ticks(count: int) -> void:
	for _index: int in range(count): await physics_frame

func pause_actors() -> void:
	world.set_process(false)
	world.save_timer=-10000.0
	world.portal_cooldown=10000.0
	world.player.auto_enabled=false
	world.player.set_physics_process(false)
	world.player.clear_click_path()
	world.player.velocity=Vector2.ZERO
	world.field_population.set_process(false)
	for monster: TwilightMonster in world.monsters_root.get_children(): monster.set_physics_process(false)
	if world.field_renderer!=null: world.field_renderer.set_process(false)

func boss_slots() -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode",""))=="boss": found.append(slot)
	return found

func slot_by_zone(id: String) -> Dictionary:
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.id)==id: return slot
	return {}

func inspect(mid: String) -> void:
	world._set_map(mid,false)
	world.portal_cooldown=10000
	check(world.field_map is NativePngField and world.active_map_id==mid,mid+" real native field loaded")
	if not world.field_map is NativePngField: return
	var field: NativePngField=world.field_map
	legacy_boss_identity_migration(mid,field)
	# Entry preparation is now frame-budgeted. Drain only that queue here so
	# authored actor counts can be checked without advancing combat or AI.
	for _batch: int in range(world.field_population.pending_initial_spawns.size()+1):
		if world.field_population.pending_initial_spawns.is_empty():break
		world.field_population._drain_initial_spawns()
	check(world.field_population.pending_initial_spawns.is_empty(),mid+" initial population preparation completes")
	world.field_population.set_process(false)
	if world.field_renderer!=null: world.field_renderer.set_process(false)
	var expected: int=0
	for zone: Dictionary in field.data.monster_spawn:
		expected+=int(zone.max_count)
		check(not field.spawn_cells.get(str(zone.id),[]).is_empty(),mid+" post-alpha candidates "+str(zone.id))
	check(expected>0 and world.field_population.slots.size()==expected,mid+" all authored population slots exist")
	var normals: Array[TwilightMonster]=[]
	var bosses: int=0
	var live: int=0
	for slot: Dictionary in world.field_population.slots:
		var monster: TwilightMonster=slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		check(monster!=null,mid+" actual live actor "+str(slot.region.id)+"/"+str(slot.index))
		if monster==null: continue
		live+=1
		monster.set_physics_process(false)
		var point: Vector2=monster.global_position
		check(field.walkable(point) and field.point_clear(point,12) and field.spawn_contains(slot.region,point),mid+" live actor on permitted floor "+monster.monster_name)
		check(not field.is_safe(point) and world.field_population.destination_allowed(monster,point),mid+" live actor respects safe/patrol holes")
		if str(slot.region.mode)=="boss": bosses+=1
		else: normals.append(monster)
	check(live==expected,mid+" actual births fill authored capacity")
	check(normals.size()==int(EXPECTED[mid][0]) and bosses==int(EXPECTED[mid][1]),mid+" reviewed normal/boss totals")
	check(not normals.is_empty() and bosses>0,mid+" both normals and existing bosses present")
	if normals.is_empty(): return
	var actor: TwilightMonster=normals[0]
	for candidate: TwilightMonster in normals:
		if candidate.current_attack_type()=="melee": actor=candidate;break
	var slot: Dictionary=world.field_population.slots[int(actor.get_meta("field_slot"))]
	var target:=Vector2.INF
	var best: float=INF
	for cell: Vector2i in field.spawn_cells.get(str(slot.region.id),[]):
		var point: Vector2=field.cell_to_world(cell)
		var distance: float=point.distance_to(actor.global_position)
		if distance<maxf(120,actor.current_attack_range()+40) or distance>400 or not field.line_clear(actor.global_position,point): continue
		if distance<best: best=distance;target=point
	check(target.is_finite(),mid+" has an unobstructed actual pursuit segment")
	if target.is_finite():
		world.player.global_position=target
		world.player.clear_click_path();world.player.velocity=Vector2.ZERO
		var before: Vector2=actor.global_position
		actor.aggro_remaining=10
		actor.attack_cooldown=100
		actor.repath_cooldown=0
		actor.set_physics_process(true)
		var moved: bool=false
		# Exact-route construction may span frames on native PNG maps. Preserve
		# the 45-frame safety sample, then allow a bounded 135-frame retry window
		# before declaring a real pursuit failure (never weaken collision checks).
		for _frame: int in range(180):
			world._advance_native_route_preparation()
			await physics_frame
			check(field.walkable(actor.global_position) and not field.is_safe(actor.global_position) and world.field_population.destination_allowed(actor,actor.global_position),mid+" live normal pursuit remains in habitat")
			moved=moved or actor.global_position.distance_to(before)>4
			if moved and _frame>=44: break
		if not moved:
			printerr("ADEN_FAITH_PNG_PURSUE_DIAGNOSTIC ",JSON.stringify({"map":mid,"start":str(before),"end":str(actor.global_position),"target":str(target),"graph":field.route_graph_stats(),"actor_path_count":actor.path.size()}))
		check(moved,mid+" actual normal AI moved toward player")
		actor.set_physics_process(false)
	var safe_point:=Vector2.INF
	var closest: float=INF
	for region: Dictionary in field.data.get("regions",[]):
		if str(region.get("type",""))!="safe": continue
		var raw: Array=region.get("center",[])
		if raw.size()!=2: continue
		var point:=Vector2(raw[0],raw[1])
		if field.walkable(point) and field.is_safe(point) and point.distance_to(actor.home_position)<closest:
			closest=point.distance_to(actor.home_position);safe_point=point
	check(safe_point.is_finite(),mid+" actual safe pad is defined")
	if safe_point.is_finite():
		check(not actor._patrol_allows(safe_point),mid+" normal movement guard rejects safe pad")
		world.player.global_position=safe_point
		world.player.clear_click_path();world.player.velocity=Vector2.ZERO
		world.hp=world.max_hp
		var hp_before: int=world.hp
		actor.aggro_remaining=10
		actor.attack_cooldown=0
		actor.set_physics_process(true)
		for _frame: int in range(30):
			await physics_frame
			check(not field.is_safe(actor.global_position),mid+" provoked normal cannot enter safe pad")
		check(world.hp==hp_before,mid+" safe player is not attacked")
		actor.set_physics_process(false)
	records.append({"map":mid,"expected":expected,"live":live,"normals":normals.size(),"bosses":bosses})
	print("ADEN_FAITH_PNG_MONSTER_MAP ",JSON.stringify(records[-1]))

func legacy_boss_identity_migration(mid: String, field: NativePngField) -> void:
	var path: String="res://data/maps/aden_field.json" if mid=="aden_world" else "res://data/maps/"+mid+".json"
	var legacy: Dictionary=CATALOG.apply_map(REGISTRY.read_json(path))
	var old_bosses: Dictionary={}
	for row: Dictionary in legacy.monster_spawn:
		if str(row.get("mode",""))=="boss": old_bosses[str(row.monster_types[0])]=row
	var director: TwilightBossDirector=DIRECTOR.new()
	var deadline: float=Time.get_unix_time_from_system()+14400.0
	var covered: int=0
	for row: Dictionary in field.data.monster_spawn:
		if str(row.get("mode",""))!="boss": continue
		var species: String=str(row.monster_types[0])
		check(old_bosses.has(species),mid+" boss comes from an actual effective legacy encounter: "+species)
		if not old_bosses.has(species): continue
		var old_key: String=director.key(mid,old_bosses[species])
		check(director.key(mid,row)==old_key,species+" retains the exact legacy persisted identity "+old_key)
		# Legacy rows can lack boss_id: their encounter id is the persisted key.
		# The new placement must preserve that key before resetting stale pixels.
		var saved: Dictionary={"version":2,"bosses":{old_key:{"phase":"alive","hp":123,"ready_at":deadline,
			"layout_revision":0,"position":[30000,20000],"home":[30000,20000]}}}
		director.import_state(saved)
		var alive: Dictionary=director.state_for(mid,row)
		check(str(alive.phase)=="alive" and int(alive.hp)==123 and float(alive.ready_at)==deadline and director.can_spawn(mid,row),old_key+" legacy saved live HP is restored without waiting for a new spawn")
		check(alive.position.is_empty() and alive.home.is_empty() and int(alive.layout_revision)==int(field.data.layout_revision),old_key+" only old canvas coordinates reset for the reviewed placement")
		saved.bosses[old_key].phase="cooldown";saved.bosses[old_key].hp=-1
		director.import_state(saved)
		var dead: Dictionary=director.state_for(mid,row)
		check(str(dead.phase)=="cooldown" and float(dead.ready_at)==deadline and not director.can_spawn(mid,row),old_key+" legacy saved dead-boss deadline is never bypassed by migration")
		covered+=1
	check(covered==int(EXPECTED[mid][1]),mid+" all effective legacy boss identities are covered")

func walk_to(point: Vector2, label: String) -> bool:
	var path: PackedVector2Array=world.field_map.path(world.player.global_position,point)
	check(not path.is_empty(),label+" has physical walking path")
	if path.is_empty(): return false
	# A straight production path can start at its destination after shortcut
	# pruning. Include the actor-to-first-waypoint segment in the time budget.
	var length: float=world.player.global_position.distance_to(path[0])
	for index: int in range(1,path.size()): length+=path[index-1].distance_to(path[index])
	world.player.set_physics_process(true)
	world._set_click_destination(point)
	var arrived: bool=false
	# Display units enlarge real travel distances; keep the actual actor speed
	# and every destination instead of truncating long routes at 1200 ticks.
	var budget: int=maxi(120,ceili(length/world.player.move_speed*Engine.physics_ticks_per_second*1.5)+120)
	for _frame: int in range(budget):
		await physics_frame
		if world.player.global_position.distance_to(point)<12.0:
			arrived=true
			break
	check(arrived,label+" actual body reaches target; position="+str(world.player.global_position)+" target="+str(point))
	if not arrived:
		printerr("ADEN_ROUTE_DIAGNOSTIC ",JSON.stringify({"label":label,"position":str(world.player.global_position),"path":str(world.player.click_path),"path_index":world.player.path_index,"velocity":str(world.player.velocity),"ui_blocks":world.hud.blocks_keyboard_input(),"movement_locked":world.player.movement_locked,"touch":str(world.player.touch_vector),"physics_enabled":world.player.is_physics_processing(),"foot_clear":world.field_map.line_clear(world.player.global_position,world.player.global_position)}))
		for i: int in range(world.player.get_slide_collision_count()):
			var contact: KinematicCollision2D=world.player.get_slide_collision(i)
			printerr("ADEN_ROUTE_CONTACT ",contact.get_collider().get_path()," normal=",contact.get_normal())
	world.player.set_physics_process(false)
	world.player.clear_click_path()
	world.player.velocity=Vector2.ZERO
	return arrived

func visit_current_habitat(field: NativePngField) -> void:
	for zone: Dictionary in field.data.monster_spawn:
		var id: String=str(zone.id)
		if visited_habitats.has(id): continue
		var candidate:=Vector2.INF
		var closest: float=INF
		for cell: Vector2i in field.spawn_cells.get(id,[]):
			var point: Vector2=field.cell_to_world(cell)
			var distance: float=point.distance_squared_to(world.player.global_position)
			if distance>=closest or field.path(world.player.global_position,point).is_empty(): continue
			candidate=point;closest=distance
		if not candidate.is_finite(): continue
		if await walk_to(candidate,"aden habitat "+id):
			visited_habitats[id]=true
			check(field.walkable(world.player.global_position),"body reaches reviewed floor in "+id)

func gate_habitat_walk() -> void:
	world._set_map("aden_world",false)
	pause_actors()
	await ticks(2)
	var field: NativePngField=world.field_map
	var edges: int=0
	# The authored forward chain visits every real PNG hunting pocket and
	# returns to the palace. Sources are reached by the actual player body.
	for portal: Dictionary in field.data.portal:
		var id: String=str(portal.id)
		if id!="aden_hunting_entry" and not id.ends_with("_next"): continue
		var position: Array=portal.position
		if not await walk_to(Vector2(position[0],position[1]),"aden gate "+id): return
		check(world.player.global_position.distance_to(Vector2(position[0],position[1]))<float(portal.radius),id+" reached actual activation radius")
		check(world.use_field_portal(id),id+" uses the normal field travel handler")
		var target: Array=portal.target_position
		check(world.player.global_position.distance_to(Vector2(target[0],target[1]))<0.01,id+" lands at reviewed exact target")
		world.portal_cooldown=10000.0
		edges+=1
		await visit_current_habitat(field)
	check(edges==18,"all eighteen forward travel gates walked")
	check(visited_habitats.size()==17,"all seventeen actual Aden encounter habitats reached")
	print("ADEN_FAITH_PNG_MONSTER_ROUTE ",JSON.stringify({"gates":edges,"habitats":visited_habitats.keys()}))

func normal_lifecycle(mid: String) -> void:
	# Portal travel can configure a new native PNG population after the
	# initial inspect; drain the existing bounded queue before lifecycle QA.
	while not world.field_population.pending_initial_spawns.is_empty():
		world.field_population._drain_initial_spawns()
	for present: Node in world.monsters_root.get_children():
		present.set_physics_process(false)
	var slot: Dictionary={}
	for candidate: Dictionary in world.field_population.slots:
		if str(candidate.region.get("mode",""))=="normal" and is_instance_valid(candidate.monster): slot=candidate;break
	check(not slot.is_empty(),mid+" has a normal life for real combat/loot test")
	if slot.is_empty(): return
	var population: FieldPopulation=world.field_population
	var found_drop: bool=false
	# Rates and item pools stay untouched. A bounded, seeded sequence of real
	# kills covers the probabilistic drop path without manufacturing a reward.
	for attempt: int in range(16):
		var monster: TwilightMonster=slot.monster
		if not is_instance_valid(monster): break
		var old_instance: int=monster.get_instance_id()
		var old_life: int=monster.life_id
		var inventory_before: Dictionary=world.inventory.duplicate(true)
		var drops_before: Array=world.ground_loot.records.keys()
		world.rng.seed=2026102000+attempt
		monster.take_damage(monster.hp+1)
		normal_deaths+=1
		check(monster.dead and not is_instance_valid(slot.monster),mid+" real normal death releases exactly one slot")
		check(world.inventory==inventory_before,mid+" normal kill never directly inserts inventory items")
		var gold_after: int=world.gold
		var experience_after: int=world.experience
		var drops_after: int=world.ground_loot.records.size()
		world._on_monster_died(monster)
		check(world.gold==gold_after and world.experience==experience_after and world.inventory==inventory_before and world.ground_loot.records.size()==drops_after,mid+" same death callback cannot pay twice")
		for id: String in world.ground_loot.records:
			if id in drops_before: continue
			var drop: Dictionary=world.ground_loot.records[id]
			var point:=Vector2(drop.position[0],drop.position[1])
			check(str(drop.map_id)==mid and str(drop.state)=="ground" and int(drop.quantity)>0 and world.field_map.walkable(point),mid+" real rolled loot is a valid ground record")
			check(world.ground_loot.valid_view(world.ground_loot.views[id]),mid+" real ground drop has a live pickup view")
			actual_drops+=1;found_drop=true
		await process_frame
		if is_instance_valid(monster): monster._physics_process(5.0)
		var wait_seconds: float=float(slot.region.respawn_time)
		population._process(maxf(0.0,wait_seconds-0.5))
		pause_actors()
		check(not is_instance_valid(slot.monster),mid+" normal cannot refill before its existing respawn timer")
		population._process(0.6)
		pause_actors()
		var replacement: TwilightMonster=slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		check(replacement!=null,mid+" normal timer refills actual population slot")
		if replacement==null: break
		check(not replacement.dead and replacement.hp==replacement.max_hp and replacement.motion.death_clock==0.0,mid+" respawn restores complete living actor")
		check(replacement.get_instance_id()!=old_instance or replacement.life_id!=old_life,mid+" respawn owns a fresh reward life")
		check(world.field_map.spawn_contains(slot.region,replacement.global_position) and population.destination_allowed(replacement,replacement.global_position) and not world.field_map.is_safe(replacement.global_position),mid+" respawn remains in the reviewed habitat")
		if found_drop: break
	check(found_drop,mid+" actual normal death produced ground loot within sixteen unchanged-rate lives")

func boss_lifecycle(mid: String) -> void:
	var expected: Dictionary={}
	var population: FieldPopulation=world.field_population
	for slot: Dictionary in boss_slots():
		var boss: TwilightMonster=slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		check(boss!=null,mid+" authored boss is actually alive for lifecycle "+str(slot.region.id))
		if boss==null: continue
		var identity: String=population.boss_director.key(mid,slot.region)
		check(not tested_bosses.has(identity),"distinct persisted boss identity "+identity)
		tested_bosses[identity]=true
		var instance: int=boss.get_instance_id()
		population._spawn_slot(slot);population._spawn_slot(slot)
		check(slot.monster.get_instance_id()==instance,identity+" repeated spawn request retains the same sole actor")
		boss.take_damage(mini(77,boss.hp-1))
		check(not boss.dead and boss.hp<boss.max_hp,identity+" original combat damage changes real boss HP")
		expected[str(slot.region.id)]={"hp":boss.hp,"position":boss.global_position,"home":boss.home_position,"identity":identity}
		check(int(slot.region.respawn_time)==(28800 if mid=="aden_world" else 86400),identity+" preserves existing wall-clock cooldown policy")
	pause_actors()
	check(world._save_game(true)==OK,mid+" damaged boss state saved atomically")
	world._set_map("faith_01" if mid=="aden_world" else "aden_world",false)
	world._set_map(mid,false)
	pause_actors()
	check_saved_bosses(mid,expected,"map round trip")
	world._load_game(true)
	pause_actors()
	check(world.active_map_id==mid,mid+" actual save restores the active map")
	check_saved_bosses(mid,expected,"save/load")
	population=world.field_population
	for slot: Dictionary in boss_slots():
		var boss: TwilightMonster=slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		if boss==null: continue
		var inventory_before: Dictionary=world.inventory.duplicate(true)
		var identity: String=population.boss_director.key(mid,slot.region)
		world.rng.seed=137
		boss.take_damage(boss.hp+1)
		check(boss.dead and not is_instance_valid(slot.monster),identity+" real death releases the boss identity")
		check(world.inventory==inventory_before,identity+" boss reward remains on the existing ground-loot path")
		var state: Dictionary=population.boss_director.states[identity]
		check(str(state.phase)=="cooldown" and float(state.ready_at)>Time.get_unix_time_from_system(),identity+" death starts its wall-clock deadline")
		population._spawn_slot(slot)
		check(not is_instance_valid(slot.monster),identity+" spawn requests cannot bypass dead-boss cooldown")
	check(world._save_game(true)==OK,mid+" dead-boss cooldown saved atomically")
	var saved_drops: int=world.ground_loot.records.size()
	world._set_map("faith_01" if mid=="aden_world" else "aden_world",false)
	world._load_game(true)
	pause_actors()
	check(world.ground_loot.records.size()==saved_drops,mid+" boss save/load preserves real floor loot")
	population=world.field_population
	for slot: Dictionary in boss_slots():
		var identity: String=population.boss_director.key(mid,slot.region)
		check(not is_instance_valid(slot.monster),identity+" saved cooldown prevents a reload clone")
		population.boss_director.states[identity]["ready_at"]=Time.get_unix_time_from_system()+60.0
	population._process(1000000.0)
	pause_actors()
	for slot: Dictionary in boss_slots():
		var identity: String=population.boss_director.key(mid,slot.region)
		check(not is_instance_valid(slot.monster),identity+" elapsed game time cannot expire a future wall-clock deadline")
		# Simulate the deadline only; authored duration, HP, damage, and AI are unchanged.
		population.boss_director.states[identity]["ready_at"]=Time.get_unix_time_from_system()-1.0
	population._process(0.2)
	pause_actors()
	var live: int=0
	for slot: Dictionary in boss_slots():
		var boss: TwilightMonster=slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		var identity: String=population.boss_director.key(mid,slot.region)
		check(boss!=null and not boss.dead and boss.hp==boss.max_hp,identity+" exactly one complete life returns after wall-clock expiry")
		if boss==null: continue
		live+=1
		var instance: int=boss.get_instance_id()
		population._spawn_slot(slot)
		check(slot.monster.get_instance_id()==instance,identity+" expired deadline cannot duplicate the new life")
	check(live==int(EXPECTED[mid][1]),mid+" live boss count equals the authored unique identity count")
	print("ADEN_FAITH_PNG_MONSTER_LIFECYCLE ",JSON.stringify({"map":mid,"bosses":expected.size(),"normal_deaths":normal_deaths,"actual_normal_drops":actual_drops}))

func check_saved_bosses(mid: String, expected: Dictionary, phase: String) -> void:
	for zone_id: String in expected:
		var slot: Dictionary=slot_by_zone(zone_id)
		var boss: TwilightMonster=slot.monster as TwilightMonster if not slot.is_empty() and is_instance_valid(slot.monster) else null
		check(boss!=null,mid+" "+phase+" restores boss "+zone_id)
		if boss==null: continue
		var state: Dictionary=expected[zone_id]
		check(boss.hp==int(state.hp),str(state.identity)+" damaged HP survives "+phase)
		check(boss.global_position.distance_to(state.position)<0.01 and boss.home_position.distance_to(state.home)<0.01,str(state.identity)+" position and home survive "+phase)

func restart_cooldown() -> void:
	# Exercise the actual boot loader once with all nine existing identities
	# persisted, including a dead current-map boss, rather than only in-memory imports.
	for slot: Dictionary in boss_slots():
		if is_instance_valid(slot.monster): slot.monster.take_damage(slot.monster.hp+1)
	check(world._save_game(true)==OK,"final dead-boss state saved for a fresh Main boot")
	var inventory: Dictionary=world.inventory.duplicate(true)
	var drops: int=world.ground_loot.records.size()
	var restarted: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(restarted)
	restarted.save_timer=-10000.0
	restarted.set_process(false)
	restarted.player.set_physics_process(false)
	restarted.field_population.set_process(false)
	for actor: TwilightMonster in restarted.monsters_root.get_children(): actor.set_physics_process(false)
	check(restarted.active_map_id=="faith_04","fresh Main restores the actual saved native map")
	check(restarted.inventory==inventory and restarted.ground_loot.records.size()==drops,"fresh Main preserves inventory and real ground drops")
	var identities: int=0
	for identity: String in tested_bosses:
		if restarted.field_population.boss_director.states.has(identity): identities+=1
	check(identities==9,"fresh Main retains all nine previously visited boss identities")
	for slot: Dictionary in restarted.field_population.slots:
		if str(slot.region.get("mode",""))=="boss": check(not is_instance_valid(slot.monster),"fresh Main cannot duplicate its saved dead boss")
	restarted.queue_free()
	await process_frame

func graph_visited(field: NativePngField, point: Vector2) -> bool:
	var cell: Vector2i=field.world_to_cell(point)
	return field.reachable[cell.y*field.width+cell.x]!=0

func graph_field(spec: Dictionary, alpha: bool=false) -> NativePngField:
	var field: NativePngField=FIELD.new()
	var manifest: Dictionary={"bounds":[0,0,640,128]}
	if alpha:
		manifest["alpha_guard_cell_size"]=16
		manifest["alpha_solid_runs"]=[[3,15,1]]
	field.configure_png("helper_portal",{"maps":{"helper_portal":spec},"revision":41},manifest,"")
	return field

func independent_service_proof(spec: Dictionary) -> Dictionary:
	var field: NativePngField=graph_field(spec)
	# This intentionally false cache must not authorize the hunting audit's
	# independent proof of physical segments and exact same-map gate endpoints.
	field.reachable.fill(1)
	var violations: Array[String]=[]
	var report: Dictionary=ROUTES.portal_service_routes(field,Vector2(56,56),func(ok: bool,label: String) -> void:
		if not ok: violations.append(label))
	report["failures"]=violations
	return report

func portal_graph_negative_fixture() -> void:
	# This small synthetic fixture is only an invalid-travel/solid-grid test.
	# Population, drops, combat, and save assertions below all use actual Main assets.
	var spec: Dictionary={"name":"portal fixture","spawn":[56,56],"layout_revision":41,
		"walk_polygons":[[[16,16],[112,16],[112,112],[16,112]],[[176,16],[272,16],[272,112],[176,112]],
			[[336,16],[432,16],[432,112],[336,112]],[[496,16],[592,16],[592,112],[496,112]]],
		"route_checks":[[56,56]],"collision_scope":"SYNTHETIC_PORTAL_TEST","collision":[],"portal_connected_regions":true,
		"portals":[{"id":"b_to_c","position":[248,56],"radius":18,"target_map":"helper_portal","target_position":[360,56],"target_layout_revision":41},
			{"id":"a_to_b","position":[88,56],"radius":18,"target_map":"helper_portal","target_position":[200,56],"target_layout_revision":41}]}
	var field: NativePngField=graph_field(spec)
	check(graph_visited(field,Vector2(56,56)) and graph_visited(field,Vector2(200,56)) and graph_visited(field,Vector2(360,56)),"reversed portal chain reaches a fixed point through real valid endpoints")
	check(not graph_visited(field,Vector2(520,56)),"disconnected unlinked region stays unreachable")
	check(not field.walkable(Vector2(144,56)),"portal graph never opens solid ground")
	check(field.path(Vector2(56,56),Vector2(200,56)).is_empty(),"portal graph never invents a physical path")
	var disabled: Dictionary=spec.duplicate(true);disabled.portal_connected_regions=false
	check(not graph_visited(graph_field(disabled),Vector2(200,56)),"non-opt-in maps keep physical-only reachability")
	var stale: Dictionary=spec.duplicate(true);stale.portals[1].target_layout_revision=40
	var stale_field: NativePngField=graph_field(stale)
	check(not graph_visited(stale_field,Vector2(200,56)) and not graph_visited(stale_field,Vector2(360,56)),"wrong revision cannot unlock any downstream region")
	var blocked: Dictionary=spec.duplicate(true);blocked.portals[1].target_position=[144,56]
	check(not graph_visited(graph_field(blocked),Vector2(200,56)),"solid target is rejected rather than projected onto floor")
	var alpha_field: NativePngField=graph_field(spec,true)
	check(graph_visited(alpha_field,Vector2(200,56)) and not alpha_field.walkable(Vector2(248,56)) and not graph_visited(alpha_field,Vector2(360,56)),"alpha guard remains authoritative over downstream portal access")
	var random:=RandomNumberGenerator.new();random.seed=137
	check(alpha_field.random_landing(random,Vector2(56,56),290).is_equal_approx(Vector2.INF),"random landing excludes downstream and unlinked islands")
	var proof: Dictionary=independent_service_proof(spec)
	check(proof.failures.is_empty() and int(proof.validated_gates)==2,"independent walking proof accepts the valid reversed gate chain")
	proof=independent_service_proof(stale)
	check(not proof.failures.is_empty() and int(proof.validated_gates)==0,"forged reachable cache cannot bypass a stale gate revision")
	proof=independent_service_proof(blocked)
	check(not proof.failures.is_empty() and int(proof.validated_gates)==0,"independent walking proof refuses a solid target without projection")
	var clipped: Dictionary=spec.duplicate(true);clipped.portals[1].target_position=[176,56]
	proof=independent_service_proof(clipped)
	check(not proof.failures.is_empty() and int(proof.validated_gates)==0,"independent walking proof requires the whole four-pixel foot on floor")
	var orphan: Dictionary=spec.duplicate(true)
	orphan.portals.append({"id":"orphan_return","position":[552,56],"radius":18,"target_map":"helper_portal","target_position":[56,56],"target_layout_revision":41})
	proof=independent_service_proof(orphan)
	check(not proof.failures.is_empty() and int(proof.validated_gates)==2,"a return gate cannot bootstrap an otherwise unreachable pocket")

func finish() -> void:
	print("ADEN_FAITH_PNG_MONSTER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"maps":records,
		"actual_main_population":true,"visited_aden_habitats":visited_habitats.size(),"boss_identities":tested_bosses.size(),
		"normal_deaths":normal_deaths,"actual_normal_ground_drops":actual_drops}))
	print("ADEN_FAITH_PNG_MONSTERS_OK" if failures.is_empty() else "ADEN_FAITH_PNG_MONSTERS_FAILED")
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	# tools/test_project.py gives every test an isolated empty user directory.
	# Refuse accidental direct execution on an existing player save; never erase it.
	check(not FileAccess.file_exists("user://twilight_native_png_save.json") and not FileAccess.file_exists(TwilightWorld.SAVE_PATH),"isolated empty user save directory is required")
	check(REGISTRY.extra_installed() and not SPAWNS.extra_layout().is_empty(),"actual PNG assets and hash-bound placement are installed; no fixture skip")
	if not failures.is_empty(): finish();return
	portal_graph_negative_fixture()
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	await ticks(3)
	check(QA.enter_game(world),"actual class picker confirmed")
	world.max_hp=1000000;world.hp=world.max_hp
	world.rng.seed=20261020
	pause_actors()
	for mid: String in SPAWNS.EXTRA_MAP_IDS:
		await inspect(mid)
		pause_actors()
		if mid=="aden_world": await gate_habitat_walk()
		await normal_lifecycle(mid)
		await boss_lifecycle(mid)
	check(tested_bosses.size()==9,"all nine actual boss identities completed save/death/wall-clock lifecycle")
	await restart_cooldown()
	world.queue_free()
	await ticks(3)
	finish()
