extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const R=preload("res://scripts/quests/quest_reusable523.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	checks+=1
	if not v:failures.append(label);printerr("QUEST_INFINITE_MP_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String="";var mode: String="held"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	if mode=="fresh":check(OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/q262-r12-") and not FileAccess.file_exists("user://twilight_v20_save.json"),"empty isolated producer profile")
	else:check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"immutable actual811 source-issued baseline")
	if not failures.is_empty():quit(1);return
	var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/current map/class UI")
	if mode=="fresh":
		w.level=86;check(w._save_game(true)==OK,"controlled QA eligibility, not natural XP")
		for step: int in range(100):
			w.quest_auto.last_signature="";w.quest_auto.next_scan=0;w.quest_auto.auto_claim=true;w.quest_auto.tick(w)
			if w.quest_service.save_blocked or w.quest_auto.retry_at>Time.get_unix_time_from_system():break
	w.quest_auto.refresh_context(w);var source_completed: int=0;var pending: int=0
	for row: Dictionary in w.quest_service.entries(w.level,w.inventory):
		if row.get("source_id")!=null and row.completed:
			source_completed+=1
			if not row.rewards.get("pending_use",[]).is_empty():pending+=1
	# Controlled maxMP capacity only; source effect1000 and genuine ownership
	# remain unchanged. Original/user save bytes are never opened for writes.
	w.max_mp=2000;w.mp=0;check(w._save_game(true)==OK,"explicit MP-capacity QA fixture for measuring full original1000")
	var inventory: Dictionary=w.inventory.duplicate(true);var objects: Dictionary=w.item_instances.duplicate(true);var quest: Dictionary=w.quest_service.export_state();var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold
	var issued: Dictionary={}
	for iid: int in R.MP_IDS:
		var record: Dictionary=D.variant_item(D.definition_id(str(iid)).native_record,1);var id: String="";var key: String=str(record.name)
		if mode!="fresh":
			for uid: String in w.item_instances:
				if w.item_instances[uid].has("quest_reward_receipt") and int(w.item_instances[uid].record.source_item_class_id)==iid:id=uid;break
			check(not id.is_empty(),"genuine raw original quest reward")
			if id.is_empty():continue
		else:
			var found: bool=false
			for rows: Array in w.quest_service.item_grants.values():
				for receipt: Dictionary in rows:
					if receipt.get("item_class_id")==iid and not receipt.has("origin"):found=true
			check(found and int(w.inventory.get(key,0))>0,"real source automatic quest production -> native ownership/source receipt")
			if not found:continue
		issued[str(iid)]={"physical_id":id,"quantity":int(w.inventory.get(key,0)) if id.is_empty() else int(w.item_instances[id].source_reward_quantity)}
		check(not R.profile(record).is_empty(),"exact source five joins including InfiniteAmount1/ClassUsageInterval1800/MPRestoration1000")
		w.mp=0;check(w._save_game(true)==OK,"controlled depleted MP before transaction")
		var before: String=FileAccess.get_sha256(w.save_path());var state: Dictionary=w.consumable_service.export_state()
		if mode=="uncertain":
			w.equipment_collections.test_save_writer=func(path: String,_d: Dictionary)->Error:
				var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string("{");f.close();return ERR_FILE_CANT_WRITE
			var result: Dictionary=R.perform(w,record,id);w.equipment_collections.test_save_writer=Callable()
			check(not result.saved and result.uncertain and w.quest_service.save_blocked,"uncertain output blocks retry")
			check(w.mp==0 and w.inventory==inventory and w.item_instances==objects and w.consumable_service.export_state()==state,"unconfirmed MP/ledger/cooldown candidate not adopted")
			check(not R.perform(w,record,id).saved and FileAccess.get_file_as_string(w.save_path())=="{","no repeated transaction after uncertain output")
			break
		w.ui_preferences["quest523_source_class_usage_interval_policy"]="unverified"
		check(not R.perform(w,record,id).saved,"disabled/unverified scope policy preserves original potion");w.ui_preferences.erase("quest523_source_class_usage_interval_policy")
		var locks: Dictionary=w.ui_preferences.get("item_locks",{}).duplicate(true);w.ui_preferences["item_locks"]={(key if id.is_empty() else str(w.item_instances[id].name)+"@@@"+id):true}
		check(not R.perform(w,record,id).saved,"actual owned key/selected UUID lock");w.ui_preferences["item_locks"]=locks
		w.mp=w._effective_max_mp();check(not R.perform(w,record,id).saved,"full MP has no saved use or source interval");w.mp=0
		w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
		check(not R.perform(w,record,id).saved,"prewrite failure preserves source and MP");w.equipment_collections.test_save_writer=Callable()
		check(w.mp==0 and w.inventory==inventory and w.item_instances==objects and w.consumable_service.export_state()==state and FileAccess.get_sha256(w.save_path())==before,"failed MP/counter/cooldown transaction preserves original bytes")
		var bag: Variant=w.hud.lineage_inventory_ui;bag.inventory=w.inventory;bag.set_character_state(w.hud.character_state);bag._select_item(key if id.is_empty() else str(w.item_instances[id].name)+"@@@"+id)
		check(not bag.detail_action.disabled,"actual existing inventory use action");bag.detail_action.pressed.emit()
		check(w.mp==1000 and w.inventory==inventory and w.item_instances==objects and w.quest_service.export_state()==quest,"actual source-issued owned item -> UI -> exact1000MP with zero quantity consumption")
		check(w.item_use_cooldowns.get("m523:item:"+str(iid))==1.0 and w.item_use_cooldowns.get(R.interval_key(record))==1800.0,"source1000ms delay and separate1800second class interval both persisted")
		check(not R.perform(w,record,id).saved,"immediate duplicate blocked")
		w._tick_item_buffs(1.0);w.mp=0
		check(not R.perform(w,record,id).saved and w.item_use_cooldowns.get(R.interval_key(record))==1799.0,"short delay expiry cannot bypass source ClassUsageInterval")
	if mode!="uncertain":
		for uid: String in objects:check(w.item_instances.get(uid)==objects[uid],"all genuine old/legacy/native physical records retained")
		check(w.quest_service.export_state()==quest and norm(w.quickslots)==norm(slots) and w.gold==gold and w.rng.state==rng,"claims/quantity proofs50slots/currency/RNG unchanged")
		check(w._save_game(true)==OK,"MP/remaining interval/counters jointly saved")
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));var hash: String=FileAccess.get_sha256(w.save_path())
		w.queue_free();await process_frame;w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main reconnect")
		check(norm(w.inventory)==saved.inventory and norm(w.item_instances)==saved.item_instances and w.mp==saved.mp and norm(w.item_use_cooldowns)==saved.item_use_cooldowns and norm(w.consumable_service.export_state())==saved.consumable_state and FileAccess.get_sha256(w.save_path())==hash,"reusable exact physical/MP/interval/counter reconnect")
		var record: Dictionary=D.variant_item(D.definition_id("203422").native_record,1);var id: String=str(issued["203422"].physical_id);var left: float=float(w.item_use_cooldowns[R.interval_key(record)])
		check(not R.perform(w,record,id).saved,"reconnect preserves remaining source interval")
		w._tick_item_buffs(left-0.1);check(not R.perform(w,record,id).saved,"not usable immediately before actual interval expiry")
		w._tick_item_buffs(0.2);w.mp=w._effective_max_mp()-250
		var ledger_key: String="native:"+str(record.sourceId) if id.is_empty() else "quest:"+id
		var history: Dictionary=w.consumable_service.export_state();history.source_reusable_item_uses[ledger_key]["existing_extension"]={"retained":true};w.consumable_service.import_state(history)
		check(w._save_game(true)==OK,"controlled existing owner-log extension is durably retained")
		var invalid: Dictionary=history.duplicate(true);invalid.source_reusable_item_uses[ledger_key].quantity_consumed=1;w.consumable_service.import_state(invalid)
		check(not R.perform(w,record,id).saved,"malformed infinite-consumption history blocked without rewriting it");w.consumable_service.import_state(history)
		w.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:
			var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"",true,true));f.close();return ERR_FILE_CANT_WRITE
		check(R.perform(w,record,id).saved and w.mp==w._effective_max_mp(),"confirmed write-then-error after interval cap-restores MP once");w.equipment_collections.test_save_writer=Callable()
		check(w.consumable_service.export_state().source_reusable_item_uses[ledger_key].get("existing_extension")=={"retained":true},"successful next use preserves existing owner-log extension")
		check(norm(w.inventory)==norm(inventory) and norm(w.item_instances)==norm(objects) and norm(w.quest_service.export_state())==norm(quest),"expiry never grants/redebits/rewrites original quantities")
	print("QUEST_INFINITE_MP_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":mode,"source_completions_before_actions":source_completed,"some_use_pending_no_skillv3_no_equipment_view":pending,"actual_item_classes":R.MP_IDS,"issued":issued,"quantity_consumed":0,"source_mp":1000,"source_class_interval_seconds":1800,"source_item_delay_ms":1000,"host_scope_clock":"per_ItemClass_active_play_seconds; native_shared_scope_and_offline_clock_unverified","controlled_MP_capacity_eligibility_not_natural_progression":true,"final_save_sha256":FileAccess.get_sha256(w.save_path())}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
