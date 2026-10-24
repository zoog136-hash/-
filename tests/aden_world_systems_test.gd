extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var checks: int = 0
var failures: Array[String] = []
var output: String = "user://aden-world-systems"
var capture: bool = false
var npcs: Array = []
var bosses: Array = []
var portals: Array = []
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("ADEN_SYSTEM_FAIL ",label)
func pause_actors() -> void:
	world.set_process(false);world.field_population.set_process(false)
	for mob: Node in world.monsters_root.get_children():mob.set_physics_process(false)
func capture_boss(id: String, boss: TwilightMonster) -> void:
	var field: RemakePlayableField = world.field_map
	world.player.global_position=field.cell_to_world(field.nearest_cell(boss.global_position+Vector2(110,60)))
	world.player.camera.zoom=Vector2.ONE;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible();field.collision_stream.refresh();world._select_monster(boss)
	for i: int in range(5):await process_frame
	if capture and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output+"/boss-"+id+".png")==OK,"actual boss PNG "+id)
func run() -> void:
	if preload("res://tests/legacy_aden_faith_fixture.gd").delegate(self,"res://tests/aden_world_systems_test.gd"): return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--capture":capture=true
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"actual character selection");world.save_timer=-100000;pause_actors()
	var field: RemakePlayableField = world.field_map
	var expected: Dictionary = {"shop":"npc_shop","warehouse":"warehouse","teleport":"teleport","craft":"crafting","buyback":"sell","guide":"dialogue"}
	for npc: Dictionary in field.data.npc_spawn:
		var point := Vector2(npc.position[0],npc.position[1]);world.player.global_position=point
		world._set_click_destination(point)
		check(world.hud.workspace.visible and world.hud.active_section==expected[str(npc.role)],"actual NPC service "+str(npc.id))
		npcs.append({"id":npc.id,"role":npc.role,"active_section":world.hud.active_section})
		world.hud._close_workspace()
	check(npcs.size()==9,"all nine preserved NPCs")
	for region: Dictionary in field.data.monster_spawn:
		var random := RandomNumberGenerator.new();random.seed=16
		for i: int in range(4):
			var point: Vector2 = field.sample_spawn(str(region.id),random)
			check(point.is_finite() and field.point_clear(point) and field.spawn_contains(region,point) and not field.is_safe(point),"regional source spawn "+str(region.id))
	# All existing five boss regions, real production death/respawn services.
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode",""))!="boss":continue
		world.field_population._spawn_slot(slot)
		check(is_instance_valid(slot.monster),"live regional boss "+str(slot.region.id))
		if not is_instance_valid(slot.monster):continue
		var boss: TwilightMonster = slot.monster;boss.set_physics_process(false)
		await capture_boss(str(slot.region.id),boss)
		var hp: int = boss.hp;boss.take_damage(5)
		check(boss.hp<hp,"boss damage "+str(slot.region.id));boss.take_damage(99999999)
		var director: TwilightBossDirector = world.field_population.boss_director
		var state: Dictionary = director.state_for("aden_world",slot.region)
		check(str(state.phase)=="cooldown" and float(state.ready_at)>Time.get_unix_time_from_system(),"boss death cooldown "+str(slot.region.id))
		world.field_population._spawn_slot(slot)
		check(not is_instance_valid(slot.monster) or slot.monster.dead,"boss deadline enforced "+str(slot.region.id))
		state.ready_at=Time.get_unix_time_from_system()-1;slot.remaining=0.0
		world.field_population._spawn_slot(slot)
		check(is_instance_valid(slot.monster) and not slot.monster.dead,"boss simulated deadline respawn "+str(slot.region.id))
		if is_instance_valid(slot.monster):slot.monster.set_physics_process(false)
		bosses.append({"id":slot.region.id,"damage_death_cooldown_respawn":"PASS","timer":"SIMULATED_DEADLINE","manual_long_fight":"NOT_RUN"})
	check(bosses.size()==5,"all five existing boss zones")
	# Dense source-cell contract, not the legacy zero-radius circle assertion.
	for region: Dictionary in field.data.monster_spawn:
		if str(region.get("mode",""))!="dense":continue
		var flat: int = int(region.source_cells[0]);world.player.global_position=field.cell_to_world(Vector2i(flat%field.width,flat/field.width))
		world.field_population._process(.5);pause_actors()
		var alive: int = 0;var valid: bool = true
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.id)==str(region.id) and is_instance_valid(slot.monster) and not slot.monster.dead:
				alive+=1;valid = valid and field.spawn_contains(region,slot.monster.global_position)
		check(alive==int(region.max_count) and valid,"dense zone source-cell population and cap")
	for id: String in ["town_waystone","ruin_waystone","oman_gate"]:
		if world.active_map_id!="aden_world":world._set_map("aden_world",false);pause_actors()
		check(world.use_field_portal(id),"production portal "+id);pause_actors()
		check(world.field_map.point_clear(world.player.global_position),"portal clear landing "+id)
		portals.append({"id":id,"map":world.active_map_id,"landing_clear":world.field_map.point_clear(world.player.global_position)})
		if id=="oman_gate":
			check(world.active_map_id=="oman_01","existing Oman arrival")
			var returned: bool = false
			for portal: Dictionary in world.field_map.data.portal:
				if str(portal.get("target_map",""))=="aden_world":returned=world.use_field_portal(str(portal.id));break
			check(returned and world.active_map_id=="aden_world" and world.field_map.point_clear(world.player.global_position),"existing Oman return portal")
	var report: Dictionary = {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"npcs":npcs,"bosses":bosses,"portals":portals,
		"manual_long_fights":"NOT_RUN","android":"NOT_RUN","original_m_npc_spawn_identity":"NOT_RUN",
		"scope":"all preserved NPC UI services, all18 source spawn zones, all5 boss callbacks/deadlines, dense source-cell cap, all3 exits and existing Oman return"}
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ADEN_SYSTEM_RESULT ",JSON.stringify(report));world.queue_free();quit(0 if failures.is_empty() else 1)
