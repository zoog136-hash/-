extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
var world: TwilightWorld

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); print("MONSTER WORLD FAIL: "+message)

func pause_actors() -> void:
	world.field_population.set_process(false)
	for monster: TwilightMonster in world.monsters_root.get_children(): monster.set_physics_process(false)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world),"class selection still enters gameplay")
	world.save_timer = -10000.
	world.rng.seed = 20261009
	pause_actors()
	var base: Array = JSON.parse_string(FileAccess.get_file_as_string(world.DB_PATH))["몬스터"]
	var by_name: Dictionary = {}
	for record: Dictionary in world.monster_db:
		check(not by_name.has(str(record.name)),"no duplicate species "+str(record.name))
		by_name[str(record.name)] = record
	check(world.monster_db.size()>=base.size(),"existing catalog retained")
	for old: Dictionary in base:
		check(by_name.has(str(old.name)) and by_name[str(old.name)].get("drop",[])==old.get("drop",[]),"existing drop pool retained "+str(old.name))
	var displayed: int = 0
	for record: Dictionary in world.monster_db:
		var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(actor)
		actor.setup(record,world.player,world,world._monster_texture(record))
		actor.set_physics_process(false)
		check(actor.sprite.texture!=null and actor.sprite.texture.get_width()>20 and actor.sprite.texture.get_height()>20,"visible original body "+str(record.name))
		check(is_instance_valid(actor.species_visual) or actor.motion.frame_source!=null,"body rig or preserved native frames "+str(record.name))
		for direction: int in range(8):
			var aim := Vector2.from_angle(float(direction)*PI/4.)
			actor.motion.face(aim)
			actor.motion.advance(.08,aim*actor.base_move_speed)
			actor.motion.apply(actor.sprite,actor.animation_base_scale)
			if is_instance_valid(actor.species_visual): actor.species_visual.update_pose()
			check(actor.motion.facing8==direction and actor.sprite.scale.is_finite(),"walk direction "+str(direction)+" "+str(record.name))
			actor.motion.begin_attack(.6,aim,actor.motion.profile.motion_style)
			actor.motion.advance(.10,Vector2.ZERO)
			check(actor.motion.state=="attack","attack pose "+str(record.name))
			actor.motion.cancel_attack()
		actor.motion.react(); actor.motion.advance(.02,Vector2.ZERO)
		check(actor.motion.state=="hit","hit pose "+str(record.name))
		actor.motion.die(); actor.motion.advance(.2,Vector2.ZERO)
		check(actor.motion.state=="death","death pose "+str(record.name))
		actor.queue_free()
		displayed += 1
		if displayed%32==0: await process_frame
	await process_frame
	var map_count: int = 0
	var dense_count: int = 0
	var boss_count: int = 0
	for id: String in world.maps_by_id:
		world._set_map(id,false)
		pause_actors()
		var population: FieldPopulation = world.field_population
		var field: PlayableField = world.field_map
		check(field!=null,"map loaded "+id)
		map_count += 1
		for slot: Dictionary in population.slots:
			var mob := slot.monster as TwilightMonster
			if not is_instance_valid(mob): continue
			check(slot.region.monster_types.has(mob.monster_name),"only assigned species "+id)
			check(field.walkable(mob.global_position) and field.point_clear(mob.global_position) and not field.is_safe(mob.global_position),"safe/blocked spawn excluded "+id)
			if str(slot.region.get("mode",""))=="boss":
				boss_count += 1
				check(mob.is_boss and mob.ai.has("special"),"boss has a separate skill "+id)
		for region: Dictionary in field.data.monster_spawn:
			if str(region.get("mode",""))!="dense": continue
			dense_count += 1
			var a: Array = region.rect
			var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
			var landing: Vector2 = field.cell_to_world(field.nearest_cell(center))
			check(not field.path(world.player.global_position,landing).is_empty(),"auto hunt route to dense zone "+id)
			world.player.global_position = landing
			population._process(.5)
			pause_actors()
			var members: Array[TwilightMonster] = []
			for slot: Dictionary in population.slots:
				if str(slot.region.id)!=str(region.id): continue
				if is_instance_valid(slot.monster): members.append(slot.monster)
			check(members.size()==int(region.max_count),"dense zone fills independent cap "+id)
			for mob: TwilightMonster in members:
				check(mob.global_position.distance_to(center)<=float(region.spawn_radius)+.1,"compact dense radius "+id)
			var inventory_before: Dictionary = world.inventory.duplicate(true)
			for i: int in range(mini(6,members.size())): members[i].take_damage(9999999)
			check(world.inventory==inventory_before,"kill never inserts ground items into inventory "+id)
			await process_frame
			for i: int in range(mini(6,members.size())):
				if is_instance_valid(members[i]): members[i]._physics_process(1.1)
			check(population.available.size()>0,"dead actors enter bounded pool "+id)
			population._process(float(region.respawn_time)+.1)
			pause_actors()
			var alive: int = 0
			for slot: Dictionary in population.slots:
				if str(slot.region.id)==str(region.id) and is_instance_valid(slot.monster):
					alive += 1
					check(not slot.monster.dead and slot.monster.hp==slot.monster.max_hp and slot.monster.motion.death_clock==0.,"pooled actor fully reset")
			check(alive==int(region.max_count) and population.available.size()<=64,"continuous bounded dense respawn "+id)
		await process_frame
	check(map_count==25 and dense_count==4 and boss_count==27,"all maps/four dense/twenty-seven boss zones covered")
	world._set_map("oman_10",false)
	pause_actors()
	var boss_slot: Dictionary = {}
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode",""))=="boss": boss_slot = slot
	var boss: TwilightMonster = boss_slot.monster
	check(boss.monster_name=="오만한 우그누스","canonical tenth-floor boss")
	boss.take_damage(77)
	var damaged_hp: int = boss.hp
	world._save_game(true)
	world._set_map("faith_01",false)
	world._set_map("oman_10",false)
	pause_actors()
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode",""))=="boss": boss_slot = slot
	boss = boss_slot.monster
	check(boss.hp==damaged_hp,"boss HP survives map round trip")
	world._load_game(true)
	pause_actors()
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode",""))=="boss": boss_slot = slot
	boss = boss_slot.monster
	check(boss.hp==damaged_hp,"boss HP survives save/load")
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	boss.take_damage(99999999)
	check(world.inventory==inventory_before,"boss reward still goes through ground loot")
	world._save_game(true)
	var saved_drops: Array = world._ground_drops_snapshot()
	var state: Dictionary = world.field_population.export_state()
	var key: String = world.field_population.boss_director.key("oman_10",boss_slot.region)
	check(str(state.bosses[key].phase)=="cooldown","dead boss enters cooldown")
	world._set_map("aden_world",false); world._load_game(true)
	pause_actors()
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode",""))=="boss": boss_slot = slot
	check(not is_instance_valid(boss_slot.monster),"no boss clone on reload while cooldown")
	check(world._ground_drops_snapshot().size()==saved_drops.size(),"ground loot survives boss-state restore")
	world.field_population._process(float(boss_slot.region.respawn_time)-.1)
	check(not is_instance_valid(boss_slot.monster),"boss cannot respawn early")
	world.field_population._process(.2)
	pause_actors()
	check(is_instance_valid(boss_slot.monster) and boss_slot.monster.hp==boss_slot.monster.max_hp,"boss respawns once after game-time cooldown")
	var live_bosses: int = 0
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode",""))=="boss" and is_instance_valid(slot.monster): live_bosses += 1
	check(live_bosses==1,"one live boss identity per map")
	print("MONSTER_WORLD covered species=",displayed," maps=",map_count," dense=",dense_count," boss_zones=",boss_count," checks=",checks)
	world.queue_free()
	await process_frame
	print("MONSTER_WORLD_OK" if failures.is_empty() else "MONSTER_WORLD_FAILED")
	quit(0 if failures.is_empty() else 1)
