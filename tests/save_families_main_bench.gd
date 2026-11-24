extends SceneTree
## Optional repeatable headless workload. Fresh isolated user directory only.
## Caller time (us) is separate from worker completion. No player data input.
const QA=preload("res://tests/qa_class_selection.gd")
const WH=preload("res://tests/warehouse_busy_retry_test.gd")
const D=preload("res://tests/dungeon_durable_cpu_main_test.gd")
const STORE=preload("res://scripts/characters/account_store.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const DS=preload("res://scripts/dungeons/dungeon_play_service.gd")
var w: Node;var failures: Array[String]=[];var times: Dictionary={};var i:=0
func ck(v: bool,m: String)->void:
	if not v:failures.append(m);printerr("SAVE_FAMILY_BENCH_FAIL ",m)
func tick(k: String,t: int)->void:
	if i>0:
		if not times.has(k):times[k]=[]
		times[k].append(Time.get_ticks_usec()-t)
func disk()->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
func _initialize()->void:run.call_deferred()
func run()->void:
	for n: String in DirAccess.get_files_at("user://"):
		if n.begins_with("twilight_v20_save"):printerr("isolated profile required");quit(2);return
	w=load("res://Main.tscn").instantiate();root.add_child(w)
	var wh:=WH.new();wh.prepare(w);wh.free()
	ck(QA.enter_game(w),"Main entry")
	w.field_population.set_process(false);w.player.set_physics_process(false);w.player.auto_enabled=false
	w.background_save_enabled=true;w.deferred_save_enabled=true
	var path: String=w.save_path();var item: String=WH.ITEM
	for round_id: int in 6:
		i=round_id;w.inventory[item]=4;w.warehouse.stacks.erase(item)
		w.rng.seed=1234;w.titles.state.rng="1234";w.halphas_star.rng.seed=1234
		w.ain_service.last_regen_at=1700000000;ck(w._save_game(true)==OK,"seed")
		var before: int=w.equipment_collections.save_writes;var t:=Time.get_ticks_usec()
		for j: int in 100:w._tick_automatic_save(0.0)
		tick("idle_100_ticks",t);ck(w.equipment_collections.save_writes==before,"idle no write")
		w.gold+=1
		t=Time.get_ticks_usec();for j: int in 100:w._request_general_save()
		tick("reserve_100",t)
		t=Time.get_ticks_usec();w._commit_general_save();tick("dirty_autosave_submit",t)
		ck(w.background_save_pending(),"dirty autosave is pending");t=Time.get_ticks_usec()
		while w.background_save_pending() and not WorkerThreadPool.is_task_completed(w._background_save_task):OS.delay_usec(100)
		tick("worker_wait",t);t=Time.get_ticks_usec();w._finish_background_save(false);tick("dirty_autosave_publish",t)
		ck(int(disk().gold)==w.gold and w.equipment_collections.save_writes==before+1,"one durable coalesced write")
		t=Time.get_ticks_usec();w._warehouse_transfer(item,1,"deposit","");tick("warehouse_deposit",t)
		ck(w.warehouse.stacks.get(item,0)==1 and disk().warehouse.stacks.get(item,0)==1,"deposit durable")
		t=Time.get_ticks_usec();w._warehouse_transfer(item,1,"withdraw","");tick("warehouse_withdraw",t)
		ck(w.inventory.get(item)==4 and disk().inventory.get(item)==4,"withdraw durable")
		var potion: String="HP 물약";var potions_before: int=int(w.inventory.get(potion,0))
		# This headless profile has no private map installed. Supply just
		# a reachable grid for the real loot/take/persist owner.
		if w.field_map==null:
			w.astar=AStarGrid2D.new();w.astar.region=Rect2i(-32,-32,64,64);w.astar.update()
		var pos: Vector2=Vector2(100,100) if w.field_map==null else preload("res://tests/active_source_test_positions.gd").combat(w,[Vector2(30,0)])
		if pos.is_finite():w.player.global_position=pos
		var drop: Button=w._spawn_ground_drop(potion,w.player.global_position,1)
		if drop!=null:
			drop.set("visible_since",Time.get_ticks_msec()-900)
			var rec: Dictionary=w.ground_loot.records[str(drop.get_meta("id"))]
			w.player.global_position=Vector2(rec.position[0],rec.position[1])
		t=Time.get_ticks_usec();var got: bool=drop!=null and w._collect_ground_drop(drop);tick("loot_pickup",t);ck(got and w.inventory.get(potion,0)==potions_before+1,"loot pickup")
		w._notification(Node.NOTIFICATION_APPLICATION_PAUSED);ck(disk().inventory.get(potion,0)==potions_before+1,"pickup survives flush")
		w.hp=1;w.item_use_cooldowns.erase(w.HP_POTION_COOLDOWN_KEY)
		t=Time.get_ticks_usec();w._use_healing_item(potion,50);tick("item_consume",t)
		ck(w.inventory.get(potion,0)==potions_before,"item use consumes one")
		w._notification(Node.NOTIFICATION_APPLICATION_PAUSED);ck(disk().inventory.get(potion,0)==potions_before,"consumption survives flush")
		var old: int=w.gold; t=Time.get_ticks_usec();var paid: Error=w._save_game(true,{"gold":old+17});tick("economy_sync_write",t)
		ck(paid==OK and disk().gold==old+17,"staged economy durable before publish");w.gold=old+17
		var play=w.dungeon_play;play.rules=D.FixtureRules.new();var now:=1800000000
		play.state=DS.empty_state();play.state.active={"kind":"special","status":"active","id":"save-bench:1","land":22701,"map_id":"aden_world","stage_id":41,"started":now,"last":now,"groups":[61],"duration":0,"seed":1,"cursor":0,"remaining_count":0,"buffs":{},"events":{},"rewards":[],"issued":{}}
		play.state.pools={"61":{"period":now,"base":3,"bonus":120}}
		ck(w._save_game(true)==OK,"dungeon seed");t=Time.get_ticks_usec();var checkpoint: Dictionary=play.account_special(now+10);tick("checkpoint",t)
		ck(checkpoint.get("ok",false) and disk().source_dungeon_play.pools["61"].bonus==113,"checkpoint amount")
		t=Time.get_ticks_usec();var stopped: Dictionary=play.stop(now+12,false);tick("dungeon_stop",t)
		ck(stopped.get("ok",false) and disk().source_dungeon_play.pools["61"].bonus==111,"stop")
		w.gold+=3;t=Time.get_ticks_usec();w._notification(Node.NOTIFICATION_APPLICATION_PAUSED);tick("pause_flush",t)
		ck(disk().gold==w.gold,"quit/pause flush")
		var hash_before:=FileAccess.get_sha256(path);w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_CANT_CREATE
		t=Time.get_ticks_usec();var err: Error=w._save_game(true,{"gold":w.gold+99});tick("write_failure",t)
		w.equipment_collections.test_save_writer=Callable();ck(err!=OK and hash_before==FileAccess.get_sha256(path),"failure old bytes remain")
		w.gold=0;t=Time.get_ticks_usec();w._load_game(true);tick("reload",t);ck(w.gold==disk().gold,"reload durable")
		var acc:=STORE.new();acc.path="user://bench-legacy-"+str(i)+".json"
		ck(WRITER.write(acc.path,{"job_class":"기사","gold":321,"unknown_future":{"kept":true}})==OK and acc.open().legacy,"migration source")
		var sess: Dictionary=STORE.session.duplicate(true);t=Time.get_ticks_usec();var migrated: Dictionary=acc.migrate_legacy();tick("legacy_migrate",t);STORE.session=sess
		ck(migrated.ok and JSON.parse_string(FileAccess.get_file_as_string(acc.path)).gold==321,"legacy migration")
	print("SAVE_FAMILIES_MAIN_BENCH_RESULT ",JSON.stringify({"failures":failures,"us":times}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
