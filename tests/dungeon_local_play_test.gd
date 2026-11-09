extends SceneTree
## Real Main/current field, actual resident monster damage/death and floor pickup.
## Automated lethal damage accelerates this test; no cleared-run/host fixture.
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("DUNGEON_LOCAL_PLAY_FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	var directory := OS.get_environment("TWILIGHT_DUNGEON_SCREENSHOTS")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name+".png")) == OK,"actual local-play screenshot")

func actor(world: Node, boss: bool = false) -> TwilightMonster:
	for child: Node in world.monsters_root.get_children():
		if child is TwilightMonster and not child.dead and (not boss or child.is_boss): return child
	return null

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false);world.set_physics_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main class entry")
	world.player.set_physics_process(false)
	for i in range(20):
		world.field_population._drain_initial_spawns()
		await process_frame
	world.field_population.set_process(false)
	for child: Node in world.monsters_root.get_children(): child.set_physics_process(false)
	check(actor(world)!=null,"actual current-map resident actor")
	world.level=70
	world.ain_service.blessing=500
	world.inventory["다이아"]=100
	check(world._save_game(true)==OK,"initial test balance save")
	world.hud.open_source_dungeons()
	var view: Node = world.hud.workspace.find_child("SourceDungeonView",true,false)
	check(view.local_toggle.button_pressed and world.LOCAL_TOWER.settings(world.source_dungeon_runs.state).enabled==true,"local tower host is on by default")
	view.local_toggle.button_pressed=false
	check(not view.local_toggle.button_pressed and view.execution_buttons.begin.disabled,"switched off inspection cannot spend")
	world.source_save_blocked=true
	view.local_toggle.button_pressed=true
	check(not view.local_toggle.button_pressed and not world.LOCAL_TOWER.settings(world.source_dungeon_runs.state).enabled,"settings save failure rolls UI back")
	world.source_save_blocked=false
	view.local_toggle.button_pressed=true
	view.local_time_scale.value=2
	check(view.local_toggle.button_pressed and not view.execution_buttons.begin.disabled and view.details.text.contains("자체 도전"),"actual UI opts into labelled local adaptation")
	world._load_game(true)
	check(world.LOCAL_TOWER.settings(world.source_dungeon_runs.state).enabled==true and int(world.LOCAL_TOWER.settings(world.source_dungeon_runs.state).time_scale)==2,"local settings survive actual save/reload")
	var ain: int=world.ain_service.blessing
	view.execution_buttons.begin.pressed.emit()
	check(world.source_dungeon_runs.state.active.get("host_kind","")=="twilight_local" and world.ain_service.blessing==ain-10,"UI starts real local run with single source payment")
	check(not world.configure_source_dungeon_local(false,1).ok,"settings cannot change during paid run")
	check(int(world.source_dungeon_runs.state.active.local_deadline)-int(Time.get_unix_time_from_system())>=590,"configured seconds multiplier applied")
	var badge := Label.new();badge.text="자동 검증 · 기존 몬스터 피해 가속 · TWILIGHT 자체 지역 도전";badge.position=Vector2(190,690);badge.z_index=999;world.hud.get_node("Root").add_child(badge)
	await capture("local-start")
	var count := 0
	while count<42:
		var target:=actor(world)
		if target==null: break
		target.take_damage(target.hp+1,false,"melee")
		if count==0:
			world._on_monster_died(target)
			check(int(world.source_dungeon_runs.state.active.counts.values()[0])==1,"duplicate actual death callback counts once")
		count+=1
	check(count==42 and world.source_dungeon_runs.state.active.status=="cleared","42 real resident deaths complete source goal without a clear fixture")
	var run_id: String=world.source_dungeon_runs.state.active.id
	var goal_id: String=str(int(world.source_dungeons.stage("tower",4).goals[0].row.ID))
	check(int(world.source_dungeon_runs.state.active.counts[goal_id])==42,"actual death signal records source count")
	var gold: int=world.gold
	view._select(0)
	check(not view.execution_buttons.claim.disabled,"real combat enables claim UI")
	view.execution_buttons.claim.pressed.emit()
	check(world.gold==gold+70000 and world.source_dungeon_runs.state.settled.has(run_id),"actual local battle payout and receipt")
	await capture("local-claimed")
	world._load_game(true)
	check(not world.source_dungeon_action("claim").ok and world.gold==gold+70000,"real battle settlement replay blocked after reload")
	check(not world.source_dungeon_runs.begin(4).ok,"daily budget survives reload")
	check(world.source_dungeon_runs.buy_attempt(74).ok,"real extra-attempt purchase")
	check(world.source_dungeon_runs.begin(74).ok,"real bonus-goal challenge starts")
	var target:=actor(world)
	check(target!=null,"resident actor available for own bonus-drop rule")
	if target!=null: target.take_damage(target.hp+1,false,"melee")
	var objective: Button=null
	for id: String in world.ground_loot.records:
		var row: Dictionary=world.ground_loot.records[id]
		if row.get("item_record",{}).get("source","")=="twilight_local_dungeon":objective=world.ground_loot.views[id];break
	check(is_instance_valid(objective) and world.source_dungeon_runs.state.active.status=="active","own objective is floor loot, not immediate progress")
	if is_instance_valid(objective):
		world.player.clear_status_effects()
		world.player.global_position=objective.get_meta("world_position")
		await create_timer(0.9).timeout
		check(world._collect_ground_drop(objective),"actual floor pickup consumes objective")
		check(not world._collect_ground_drop(objective),"consumed actual goal drop cannot be replayed")
	check(world.source_dungeon_runs.state.active.status=="cleared","real floor pickup completes bonus goal")
	check(world.source_dungeon_runs.claim().ok,"bonus reward settles via real writer")
	var day: int=int(world.source_dungeon_runs.state.local_day)
	check(world.LOCAL_TOWER.cycle(world.source_dungeon_runs.state,1)==day,"clock rollback cannot regain a daily budget")
	var hard: int=int(world.source_dungeon_entries("tower",true)[0].stage.ID)
	check(world.source_dungeon_runs.begin(hard).ok,"hard budget independent")
	var before_failure: int=world.ain_service.blessing
	world.source_dungeon_runs.state.active.local_deadline=int(Time.get_unix_time_from_system())-1
	world.source_save_blocked=true;world.LOCAL_TOWER.tick(world)
	check(world.local_dungeon_failure_pending and world.source_dungeon_runs.context(hard).is_empty(),"expired write failure blocks further combat credit")
	world.source_save_blocked=false;world.LOCAL_TOWER.tick(world)
	check(world.source_dungeon_runs.state.active.status=="failed" and world.ain_service.blessing==before_failure,"expiry retry commits failure without refund")
	check(world.source_dungeon_runs.buy_attempt(hard).ok and world.source_dungeon_runs.begin(hard).ok,"remaining hard attempt starts")
	world._respawn_player("자동 검증 사망")
	check(world.source_dungeon_runs.state.active.status=="failed","actual respawn fails paid local challenge")
	check(world.active_map_id=="aden_world","no fake original dungeon transport")
	print("DUNGEON_LOCAL_PLAY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_CURRENT_MAP_RESIDENT_DAMAGE_DEATH_FLOOR_PICKUP_PAYOUT; OWN_OPT_IN_RULES; AUTOMATED_DAMAGE_NOT_MANUAL_ORIGINAL_DUNGEON_PLAY"}))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
