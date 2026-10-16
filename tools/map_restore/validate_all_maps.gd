extends SceneTree
## Production Main, existing DB actors, isolated user data. Source geometry and
## provisional authored geometry are reported separately, never as M fidelity.
var world: TwilightWorld
var output: String="user://all-map-validation"
var only: String=""
var failures: Array[String]=[]
var checks: int=0
var reports: Array=[]
var boss_reports: Array=[]
var combat_enabled: bool=true
var travel_only: bool=false
var travel_reports: Array=[]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("ALL_MAP_FAIL "+label)
func frames(n: int) -> void:
	for i: int in range(n): await physics_frame
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	await frames(2);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"PNG "+name)

func collision_equivalence(field: AuthoredRemakeField, id: String, entry: Vector2) -> Dictionary:
	# Independent Godot World2D containing the entire old collision body. Compare
	# actual physics queries, including original polygons/circles/rectangles.
	var reference:=SubViewport.new();reference.world_2d=World2D.new()
	root.add_child(reference)
	var holder:=Node2D.new();reference.add_child(holder)
	var old:=PlayableField.new();old.blockers=field.blockers
	old.build_physics(holder)
	await frames(2)
	var signatures: Dictionary={}
	for key: Vector2i in field.collision_stream.chunks: signatures[key]=field.collision_stream.chunk_signature(key)
	var positions: Array[Vector2]=[entry]
	for region_id: String in field.spawn_cells:
		var p: Vector2=field.sample_spawn(region_id,world.rng)
		if p.is_finite() and p.distance_to(entry)>3000: positions.append(p);break
	var queries: int=0
	for p: Vector2 in positions:
		world.player.global_position=p;world.field_renderer.refresh_visible()
		await frames(2)
		check(field.collision_stream.active_shape_count<=field.collision_stream.total_shape_count,id+" no duplicated physical shapes")
		check(preload("res://tests/streamed_field_physics.gd").intact(world),id+" exact original shapes and actual loaded Godot shapes")
		for key: Vector2i in field.collision_stream.buckets:
			var relevant: bool=(field.collision_stream.bucket_bounds[key] as Rect2).intersects(field.collision_stream.required_bounds(),true)
			check(field.collision_stream.chunks.has(key)==relevant,id+" full awake-area coverage "+str(key))
		var actual: PhysicsDirectSpaceState2D=world.get_world_2d().direct_space_state
		var expected: PhysicsDirectSpaceState2D=reference.world_2d.direct_space_state
		for i: int in range(128):
			var a: Vector2=p+Vector2(world.rng.randf_range(-1850,1850),world.rng.randf_range(-1850,1850))
			var b: Vector2=a+Vector2(world.rng.randf_range(-180,180),world.rng.randf_range(-180,180))
			var query:=PhysicsRayQueryParameters2D.create(a,b,4)
			query.hit_from_inside=true
			var hit: Dictionary=actual.intersect_ray(query);var old_hit: Dictionary=expected.intersect_ray(query)
			check(hit.is_empty()==old_hit.is_empty(),id+" streamed/full physical occupancy "+str(i))
			if not hit.is_empty() and not old_hit.is_empty(): check((hit.position as Vector2).distance_to(old_hit.position)<.05,id+" original collision hit position")
			queries+=1
	world.player.global_position=entry;world.field_renderer.refresh_visible();await frames(2)
	for key: Vector2i in signatures:
		check(field.collision_stream.chunk_signature(key)==signatures[key],id+" collision revisit hash "+str(key))
	check(world.field_renderer.floor_stream.chunks.size()<=49,id+" bounded floor chunks")
	var floor_hashes: Dictionary={}
	for key: Vector2i in world.field_renderer.floor_stream.chunks: floor_hashes[key]=world.field_renderer.floor_stream.chunk_signature(key)
	if positions.size()>1:
		world.player.global_position=positions[1];world.field_renderer.refresh_visible();await frames(2)
		world.player.global_position=entry;world.field_renderer.refresh_visible();await frames(2)
		for key: Vector2i in floor_hashes: check(world.field_renderer.floor_stream.chunk_signature(key)==floor_hashes[key],id+" floor revisit mesh hash "+str(key))
	var result: Dictionary={"full_reference_shapes":field.collision_stream.total_shape_count,
		"active_shapes":field.collision_stream.active_shape_count,"queries":queries,"sample_locations":positions.size(),
		"collision_unloaded_buckets":field.collision_stream.freed_chunks,"floor_unloaded_chunks":world.field_renderer.floor_stream.freed_chunks}
	reference.queue_free();await process_frame
	return result

func combat(id: String, slot: Dictionary) -> void:
	if not is_instance_valid(slot.monster): check(false,id+" boss spawned "+str(slot.region.id));return
	var boss: TwilightMonster=slot.monster
	var field: PlayableField=world.field_map
	var landing:=Vector2.INF
	var distance: float=maxf(64,minf(boss.current_attack_range()*.75,float(boss.ai.get("retreat_distance",0))+64))
	for i: int in range(16):
		var p: Vector2=boss.global_position+Vector2.from_angle(TAU*i/16)*distance
		if field.point_clear(p) and not field.is_safe(p) and field.line_clear(p,boss.global_position): landing=p;break
	check(landing.is_finite(),id+" boss approach "+str(slot.region.id))
	if not landing.is_finite(): return
	var entry:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	check(not field.path(entry,landing).is_empty(),id+" boss reachable "+str(slot.region.id))
	world.player.global_position=landing;world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	world.field_renderer.refresh_visible();world.field_population._process(.5)
	world.max_hp=1000000;world.hp=world.max_hp;world._update_hud()
	var hp: int=boss.hp;var player_hp: int=world.hp;var markers: Array=[0]
	boss.player_hit.connect(func(_who: TwilightMonster,_damage: int,_kind: String) -> void: markers[0]+=1)
	# Observe the existing AI first. Continual AUTO pursuit can keep a ranged
	# boss retreating, and a weak boss can die before its first attack marker.
	world.selected_monster=null;world.auto_target=null;world.player.set_auto_enabled(false)
	for i: int in range(600):
		await frames(1)
		if markers[0]>0 and world.hp<player_hp: break
	world.selected_monster=boss;world.auto_target=boss;world.player.set_auto_enabled(true)
	for i: int in range(16):
		world._attack();await frames(24)
		if boss.hp<hp and world.hp<player_hp and markers[0]>0: break
	world.player.set_auto_enabled(false);world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	if markers[0]==0:
		for i: int in range(300):
			await frames(1)
			if markers[0]>0 and world.hp<player_hp: break
	check(boss.hp<hp,id+" ordinary attack damages "+boss.monster_name)
	check(markers[0]>0 and world.hp<player_hp,id+" actual boss attack "+boss.monster_name)
	await shot(id+"-boss-"+str(slot.region.id))
	boss_reports.append({"map":id,"region":slot.region.id,"boss":boss.monster_name,"boss_hp_before":hp,"boss_hp_after":boss.hp,
		"player_hp_before":player_hp,"player_hp_after":world.hp,"real_attack_markers":markers[0],
		"observation":"STATIONARY_PLAYER_BEFORE_AUTO_ATTACK",
		"arena_arrival":"QA_TELEPORT_AFTER_PATH_CHECK","player_test_hp":1000000,"damage":"ORDINARY_PLAYER_ATTACK_AND_REAL_BOSS_AI"})
	# Boss state serialization must keep live HP and deadlines. Full death/drop
	# lifecycle has a separate existing regression suite; no fake screenshot.
	world.field_population._capture_bosses()
	var director: TwilightBossDirector=world.field_population.boss_director
	var key: String=director.key(id,slot.region)
	check(int(director.states[key].hp)==boss.hp,id+" existing boss persistence HP "+str(slot.region.id))

func services_and_travel(id: String) -> void:
	await process_frame;world._set_map(id,false);world.portal_cooldown=1000
	world.player.set_auto_enabled(false)
	var npc_results: Array=[]
	for npc: Dictionary in world.field_map.data.npc_spawn:
		world.player.global_position=Vector2(npc.position[0],npc.position[1])
		world._set_click_destination(world.player.global_position)
		check(world.hud.workspace.visible,id+" real NPC service opens "+str(npc.id))
		var sections: Dictionary={"guide":"dialogue","shop":"npc_shop","warehouse":"warehouse","teleport":"teleport","craft":"crafting","buyback":"sell"}
		check(world.hud.active_section==str(sections.get(str(npc.role),"")),id+" correct NPC service "+str(npc.id))
		npc_results.append({"npc":npc.id,"service":npc.role,"actual_section":world.hud.active_section})
		world.hud._close_workspace()
	var portals: Array=world.field_map.data.portal.duplicate(true)
	var arrivals: Array=[]
	for portal: Dictionary in portals:
		await process_frame;world._set_map(id,false)
		var director: TwilightBossDirector=world.field_population.boss_director
		world.field_population._capture_bosses()
		var saved: Dictionary=director.states.duplicate(true)
		world.player.global_position=Vector2(portal.position[0],portal.position[1])
		world.player.clear_click_path();world.player.velocity=Vector2.ZERO
		world.field_renderer.refresh_visible();world.portal_cooldown=0
		world._update_field_triggers();await frames(3)
		check(world.active_map_id==str(portal.target_map),id+" actual proximity portal "+str(portal.id))
		check(world.field_map.walkable(world.player.global_position) and world.field_map.point_clear(world.player.global_position),id+" portal arrival foot clearance "+str(portal.id))
		for key: String in saved:
			check(director.states.has(key) and director.states[key].phase==saved[key].phase and director.states[key].ready_at==saved[key].ready_at,id+" boss phase/deadline retained "+key)
		arrivals.append({"portal":portal.id,"expected":portal.target_map,"actual":world.active_map_id})
	travel_reports.append({"map":id,"npc_services":npc_results,"actual_portal_arrivals":arrivals})
	print("ALL_MAP_TRAVEL_CHECKED ",id)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--map="): only=arg.trim_prefix("--map=")
		if arg=="--no-combat": combat_enabled=false
		if arg=="--travel-only": travel_only=true
	DirAccess.make_dir_recursive_absolute(output)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(3)
	world.hud.complete_class_selection();world.hud._close_workspace();world.save_timer=-100000
	world.level=100;world.max_hp=1000000;world.hp=world.max_hp
	world.exp_need=world.EXP_PROGRESSION.required_for_level(100,world.exp_need)
	world.rng.seed=2026101503
	var original_layouts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/navigation/catalog.json"))
	for record: Dictionary in world.maps:
		var id: String=record.id
		if not only.is_empty() and id!=only: continue
		if travel_only:
			if not id.begins_with("oman_"): await services_and_travel(id)
			continue
		print("ALL_MAP_BEGIN ",id)
		await process_frame
		var started: int=Time.get_ticks_usec();world._set_map(id,false)
		var load_ms: float=(Time.get_ticks_usec()-started)/1000.0
		world.portal_cooldown=1000;await frames(3)
		var field: PlayableField=world.field_map
		check(field is RemakePlayableField or field is AuthoredRemakeField,id+" common remake Main entry")
		var entry: Vector2=world.player.global_position
		check(field.walkable(entry) and field.point_clear(entry),id+" entry foot clearance")
		var target: Vector2=entry
		for direction: Vector2 in [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]:
			var p: Vector2=entry+direction*96
			if field.point_clear(p) and field.line_clear(entry,p): target=p;break
		check(target!=entry,id+" click destination")
		world._set_click_destination(target);await frames(90)
		check(world.player.global_position.distance_to(target)<24,id+" real click movement")
		world.player.clear_click_path();world.player.velocity=Vector2.ZERO
		await shot(id+"-gameplay")
		var physics: Dictionary={"scope":"SOURCE_DETAILED_RESULTS_PRESERVED_IN_OMAN_FINAL_ACCEPTED"}
		if field is AuthoredRemakeField:
			check(field.geometry_signature()==str(original_layouts[id].baked_signature),id+" exact original navigation/spawn signature")
			check(world.player.get_node("CollisionShape2D").shape is CapsuleShape2D,id+" legacy actor collider preserved")
			physics=await collision_equivalence(field,id,entry)
		world.field_renderer.set_visual_mode("collision");await shot(id+"-collision")
		world.field_renderer.set_visual_mode("twilight")
		for npc: Dictionary in field.data.npc_spawn:
			var p:=Vector2(npc.position[0],npc.position[1])
			check(not field.path(entry,p).is_empty(),id+" NPC reachable "+str(npc.id))
		for portal: Dictionary in field.data.portal:
			var p:=Vector2(portal.position[0],portal.position[1])
			check(not field.path(entry,p).is_empty(),id+" portal reachable "+str(portal.id))
		var live: int=0;var boss_slots: Array=[]
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.get("mode",""))=="boss": boss_slots.append(slot)
			if not is_instance_valid(slot.monster): continue
			var mob: TwilightMonster=slot.monster;live+=1
			check(field.walkable(mob.home_position) and not field.is_safe(mob.home_position),id+" valid non-safe spawn "+str(slot.slot_id))
			check(field.spawn_contains(slot.region,mob.home_position),id+" spawn in assigned region "+str(slot.slot_id))
		check(live>0,id+" existing monsters spawned")
		if field is AuthoredRemakeField and combat_enabled:
			for slot: Dictionary in boss_slots: await combat(id,slot)
		world.player.global_position=entry;world.player.clear_click_path()
		world._save_game(true);world._load_game(true);await frames(2)
		check(world.active_map_id==id and world.player.global_position.distance_to(entry)<.01,id+" save/load map and position")
		reports.append({"map":id,"source_kind":"A3_PC_GRID" if field is RemakePlayableField else "TWILIGHT_AUTHORED_POLYGONS",
			"current_M_coordinates":"UNVERIFIED","original_fidelity_complete":false,"technical_complete":false,
			"load_ms":load_ms,"live_monsters":live,"boss_zones":boss_slots.size(),"collision":physics,
			"memory_static_bytes":OS.get_static_memory_usage()})
		print("ALL_MAP_CHECKED ",id," checks=",checks)
	var report: Dictionary={"maps":reports,"checks":checks,"failures":failures,"boss_combat":boss_reports,"services_and_travel":travel_reports,
		"display":DisplayServer.get_name(),"renderer":RenderingServer.get_video_adapter_name(),"android":"NOT_RUN"}
	var file:=FileAccess.open(output+"/runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ALL_MAP_RESULT ",JSON.stringify({"maps":reports.size(),"checks":checks,"failures":failures}))
	world.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
