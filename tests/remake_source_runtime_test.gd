extends SceneTree
## Actual Main, installed private A3 grids and existing actors. No mock combat.
const REGISTRY = preload("res://scripts/maps/remake_registry.gd")
var world: TwilightWorld
var failures: Array[String] = []
var checks: int = 0
var reports: Array = []
var output: String = "user://map-remake"
var combat_reports: Array = []
var service_reports: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("REMAKE_RUNTIME_FAIL "+label)
func frames(n: int) -> void:
	for i: int in range(n): await physics_frame
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	await frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	check(img != null and img.save_png(output+"/"+name+".png")==OK,"Godot PNG "+name)

func boss_slot() -> Dictionary:
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode",""))=="boss": return slot
	return {}

func combat(id: String) -> void:
	var slot: Dictionary = boss_slot()
	check(not slot.is_empty() and is_instance_valid(slot.get("monster")),id+" existing DB boss alive")
	if slot.is_empty() or not is_instance_valid(slot.get("monster")): return
	var boss: TwilightMonster = slot.monster
	var field: RemakePlayableField = world.field_map
	world.level=100;world.experience=0
	world.exp_need=world.EXP_PROGRESSION.required_for_level(100,world.exp_need)
	world.max_hp=1000000;world.hp=world.max_hp
	world.hud._close_workspace()
	world._update_hud()
	var cell: Vector2i = field.world_to_cell(boss.global_position)
	var landing: Vector2 = Vector2.INF
	var preferred: float=maxf(26,minf(boss.current_attack_range()*.65,float(boss.ai.get("retreat_distance",0))+56))
	var error: float=INF
	for dy: int in range(-12,13):
		for dx: int in range(-12,13):
			var p: Vector2=field.cell_to_world(cell+Vector2i(dx,dy))
			var distance: float=p.distance_to(boss.global_position)
			if distance<20 or distance>boss.current_attack_range(): continue
			if not field.remake_region_contains(str(slot.region.id),p) or not field.point_clear(p) or field.is_safe(p) or not field.line_clear(p,boss.global_position): continue
			if absf(distance-preferred)<error: landing=p;error=absf(distance-preferred)
	check(landing.is_finite(),id+" boss combat approach")
	if not landing.is_finite(): return
	check(not field.path(world.player.global_position,landing).is_empty(),id+" boss reachable from entry")
	# QA teleport to an already path-checked arena, then ordinary attack marker,
	# damage/AI and real actors; no fabricated battle image or altered boss DB.
	world.player.global_position=landing
	world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	world.field_renderer.refresh_visible()
	world.field_population._process(0.5)
	var hp_before: int = boss.hp
	var player_before: int = world.hp
	var boss_attacks: Array = [0]
	boss.player_hit.connect(func(_who: TwilightMonster,_damage: int,_kind: String) -> void: boss_attacks[0]+=1)
	# Observe the ranged boss inside its real attack range before AUTO pursuit
	# can repeatedly drive it into retreat. Preserve actual marker/damage checks.
	world.selected_monster=null;world.auto_target=null;world.player.set_auto_enabled(false)
	for observation: int in range(600):
		await frames(1)
		if boss_attacks[0]>0 and world.hp<player_before: break
	world.selected_monster=boss
	world.auto_target=boss
	world.player.set_auto_enabled(true)
	for attempt: int in range(16):
		world._attack()
		await frames(24)
		if boss.hp<hp_before and world.hp<player_before and boss_attacks[0]>0: break
	world.player.set_auto_enabled(false)
	world.player.clear_click_path()
	world.player.velocity=Vector2.ZERO
	# Ranged bosses retreat while AUTO pursues them. Observe their ordinary AI
	# with the player stationary as well, so pursuit cannot indefinitely postpone
	# their cast. Keep the actual boss marker and player-damage assertions below.
	if boss_attacks[0]==0:
		for observation: int in range(300):
			await frames(1)
			if boss_attacks[0]>0 and world.hp<player_before: break
	check(boss.hp<hp_before,id+" ordinary player attack damages boss")
	check(world.hp<player_before and boss_attacks[0]>0,id+" actual boss AI damages player")
	if boss.hp==hp_before or boss_attacks[0]==0:
		print("COMBAT_DIAGNOSTIC ",JSON.stringify({"map":id,"player":str(world.player.global_position),"boss":str(boss.global_position),
			"distance":world.player.global_position.distance_to(boss.global_position),"los":field.line_clear(world.player.global_position,boss.global_position),
			"player_safe":field.is_safe(world.player.global_position),"boss_safe":field.is_safe(boss.global_position),
			"stun":world.player.stun_remaining,"fear":world.player.fear_remaining,"pending":not world.pending_attack.is_empty(),
			"boss_processing":boss.is_physics_processing(),"boss_motion":boss.motion.state,"boss_returning":boss.returning_home}))
	await shot(id+"-boss-combat")
	combat_reports.append({"map":id,"boss":boss.monster_name,"boss_hp_before":hp_before,"boss_hp_after":boss.hp,
		"player_hp_before":player_before,"player_hp_after":world.hp,"boss_attack_markers":boss_attacks[0],
		"boss_attack_observation":"STATIONARY_PLAYER_IN_REAL_RANGE_BEFORE_AUTO_ATTACK",
		"arena_arrival":"QA_TELEPORT_AFTER_PATH_CHECK","attack":"NORMAL_GAMEPLAY_MARKERS",
		"lifecycle_test":"DIRECT_LETHAL_DAMAGE_AND_TEST_CLOCK_EXPIRY"})
	boss.set_physics_process(false)
	var damaged_hp: int = boss.hp
	world._save_game(true)
	world._load_game(true)
	slot=boss_slot();boss=slot.monster
	check(boss.hp==damaged_hp,id+" live boss HP save/load")
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	boss.take_damage(99999999)
	check(world.inventory==inventory_before,id+" death uses ground loot, no instant inventory")
	var director: TwilightBossDirector = world.field_population.boss_director
	var key: String = director.key(id,slot.region)
	var deadline: float = director.states[key].ready_at
	check(str(director.states[key].phase)=="cooldown" and deadline>Time.get_unix_time_from_system(),id+" death cooldown")
	check(int(slot.region.respawn_time)==86400,id+" existing 24h boss respawn preserved")
	print("REMAKE_STAGE ",id," dead_boss_restore_begin rng_state=",world.rng.state)
	world._save_game(true);world._load_game(true)
	print("REMAKE_STAGE ",id," dead_boss_restore_end rng_state=",world.rng.state)
	slot=boss_slot();director=world.field_population.boss_director
	field=world.field_map
	check(not is_instance_valid(slot.monster) and director.states[key].ready_at==deadline,id+" dead boss deadline survives reload")
	director.states[key].ready_at=Time.get_unix_time_from_system()-1
	world.field_population._process(0.5)
	print("REMAKE_STAGE ",id," boss_respawn_end")
	check(is_instance_valid(slot.monster) and slot.monster.hp==slot.monster.max_hp,id+" deadline respawns boss once")
	if is_instance_valid(slot.monster):
		check(field.remake_region_contains(str(slot.region.id),slot.monster.home_position),id+" boss respawn stays in arena")

func services_and_travel(id: String) -> void:
	world._set_map(id,false)
	world.portal_cooldown=1000
	for npc: Dictionary in world.field_map.data.npc_spawn:
		world.player.global_position=Vector2(npc.position[0],npc.position[1])
		world._set_click_destination(world.player.global_position)
		check(world.hud.active_section=="dialogue",id+" existing guide dialogue opens")
		world.hud._close_workspace()
	var portals: Array=world.field_map.data.portal.duplicate(true)
	var arrivals: Array=[]
	for portal: Dictionary in portals:
		print("REMAKE_STAGE ",id," portal_begin ",portal.id)
		world._set_map(id,false)
		world.player.global_position=Vector2(portal.position[0],portal.position[1])
		world.player.set_auto_enabled(false)
		world.portal_cooldown=0
		# Exercise the production proximity trigger and its deferred transition.
		world._update_field_triggers()
		await frames(3)
		check(world.active_map_id==str(portal.target_map),id+" actual portal trigger "+str(portal.id))
		check(world.field_map.walkable(world.player.global_position) and world.field_map.point_clear(world.player.global_position),id+" destination foot clearance "+str(portal.id))
		arrivals.append({"portal":portal.id,"expected":portal.target_map,"actual":world.active_map_id})
		print("REMAKE_STAGE ",id," portal_end ",portal.id)
	service_reports.append({"map":id,"portals":arrivals,"npc_action":"EXISTING_GUIDE_DIALOGUE"})

func run() -> void:
	# Preserve the A3 source-to-source return/foot and original-grid contracts.
	# Native PNG portal landings remain covered on the active installed maps.
	if preload("res://tests/legacy_aden_faith_fixture.gd").delegate(self,"res://tests/remake_source_runtime_test.gd"): return
	if not REGISTRY.installed("oman_01"):
		print("REMAKE_SOURCE_RUNTIME_SKIP: private A3 pack absent; no source play claim")
		quit(); return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: String = ""
	for arg: String in args:
		if arg.begins_with("--map="): only = arg.trim_prefix("--map=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(3)
	world.hud.complete_class_selection(); world.hud._close_workspace()
	world.level = 100; world.max_hp = 1000000; world.hp = world.max_hp
	world.save_timer=-10000
	world._update_hud()
	world.rng.seed = 20261015
	for floor_number: int in range(1,11):
		var id: String = "oman_%02d" % floor_number
		if not only.is_empty() and only != id: continue
		var started: int = Time.get_ticks_usec()
		world._set_map(id,false)
		var load_msec: float = (Time.get_ticks_usec()-started)/1000.0
		await frames(3)
		world.portal_cooldown = 1000
		check(world.active_map_id==id and world.field_map is RemakePlayableField,id+" Main entry")
		if not world.field_map is RemakePlayableField: continue
		var field: RemakePlayableField = world.field_map
		var entry: Vector2 = world.player.global_position
		check(field.walkable(entry) and field.point_clear(entry),id+" foot clearance")
		check(world.field_population==world.legacy_population,id+" existing boss state owner")
		check(world.player.get_node("CollisionShape2D").shape is CircleShape2D,id+" source foot collider")
		var c: Vector2i = field.world_to_cell(entry)
		var target: Vector2 = entry
		for direction: Vector2i in field.DIRECTIONS:
			var p: Vector2 = field.cell_to_world(c+direction*4)
			if field.walkable(p) and field.line_clear(entry,p): target=p; break
		check(target!=entry,id+" movement destination")
		world._set_click_destination(target)
		await frames(90)
		check(world.player.global_position.distance_to(target)<16,id+" real click movement")
		world.player.clear_click_path();world.player.velocity=Vector2.ZERO
		await shot(id+"-gameplay")
		var blocked: int = 0
		var allowed: int = 0
		for dy: int in range(-10,11):
			for dx: int in range(-10,11):
				var cell: Vector2i = c+Vector2i(dx,dy)
				if field.value_at(cell,true)==0: continue
				for heading: int in [0,2,4,6]:
					if blocked>=20 and allowed>=20: break
					var p: Vector2 = field.cell_to_world(cell)
					var q: Vector2 = field.cell_to_world(cell+field.DIRECTIONS[heading])
					var open: bool = field.can_step(cell,heading)
					var query := PhysicsRayQueryParameters2D.create(p,q,4)
					var hit: Dictionary = world.get_world_2d().direct_space_state.intersect_ray(query)
					check(hit.is_empty()==open,id+" physics/nav edge "+str(cell)+":"+str(heading))
					if open: allowed+=1
					else: blocked+=1
		check(blocked>=20 and allowed>=20,id+" both edge classes exercised")
		for npc: Dictionary in field.data.npc_spawn:
			var p := Vector2(npc.position[0],npc.position[1])
			check(not field.path(entry,p).is_empty(),id+" NPC approach "+str(npc.id))
		for portal: Dictionary in field.data.portal:
			var p := Vector2(portal.position[0],portal.position[1])
			check(not field.path(entry,p).is_empty(),id+" portal approach "+str(portal.id))
		for slot: Dictionary in world.field_population.slots:
			if not is_instance_valid(slot.monster): continue
			var mob: TwilightMonster = slot.monster
			check(field.remake_region_contains(str(slot.region.id),mob.home_position),id+" spawn remains in assigned zone")
			check(field.walkable(mob.home_position) and not field.is_safe(mob.home_position),id+" spawn avoids reservations")
		world._save_game(true)
		var saved: Vector2 = world.player.global_position
		world.player.global_position = entry
		world._load_game(true)
		await frames(2)
		field = world.field_map
		check(world.player.global_position.distance_to(saved)<0.01,id+" save roundtrip")
		world.portal_cooldown = 1000
		world.field_renderer.set_visual_mode("collision")
		await shot(id+"-collision")
		world.field_renderer.set_visual_mode("twilight")
		check(field.nav_cache.size()<=64 and field.collision_stream.chunks.size()<=9,id+" bounded caches")
		await combat(id)
		field=world.field_map
		reports.append({"map":id,"checks_cumulative":checks,"entry_and_tests_ms":(Time.get_ticks_usec()-started)/1000.0,
			"synchronous_map_entry_ms":load_msec,"layout_revision":int(field.data.layout_revision),
			"physics_blocked_edges":blocked,"physics_open_edges":allowed,"monsters":world.monsters_root.get_child_count(),
			"draw_chunks":world.field_renderer.chunks.size(),"nav_chunks":field.nav_cache.size(),
			"max_chunk_build_usec":world.field_renderer.stream_build_usec,"memory_static_bytes":OS.get_static_memory_usage(),
			"source_hash":field.definition.source_sha256,"edition":"A3_PC_CURRENT_M_UNVERIFIED"})
		await services_and_travel(id)
		print("REMAKE_FLOOR_CHECKED ",id," checks=",checks)
	print("REMAKE_STAGE legacy_return_begin")
	# The portal coroutine resumes inside physics_frame. Let the deferred portal
	# transition and its queued collision-body cleanup finish before this QA-only
	# immediate map change; normal proximity travel already uses call_deferred.
	await process_frame
	world._set_map("aden_world",false)
	print("REMAKE_STAGE legacy_return_set")
	await frames(2)
	print("REMAKE_STAGE legacy_return_frames")
	# Latest main already uses the source field for Aden. Returning from Oman
	# to Aden must retain the source foot; exercise restoration on an actually
	# authored map as well, instead of treating a stale Aden expectation as a
	# production regression.
	check(world.field_map is RemakePlayableField and world.player.get_node("CollisionShape2D").shape is CircleShape2D and world.player.get_node("CollisionShape2D").shape.radius == 4.0,"Aden source foot retained on source-to-source return")
	# Domination is now an intentional native PNG map with a 4px foot. Use
	# the existing unmapped Albino 4 to verify restoring the authored capsule.
	world._set_map("albino_04",false)
	await frames(2)
	check(world.active_map_id=="albino_04" and not world.field_map is OriginalPlayableField and not world.field_map is NativePngField,"authored map restoration exercised")
	check(world.player.get_node("CollisionShape2D").shape is CapsuleShape2D,"legacy foot collider restored")
	var report: Dictionary = {"checks":checks,"failures":failures,"maps":reports,"display":DisplayServer.get_name(),
		"renderer":RenderingServer.get_video_adapter_name(),"android":"NOT_RUN","boss_combat":combat_reports,"services_and_travel":service_reports}
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE)
	print("REMAKE_STAGE report_write")
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("REMAKE_RUNTIME_RESULT "+JSON.stringify(report))
	world.queue_free();await frames(2)
	quit(0 if failures.is_empty() else 1)
