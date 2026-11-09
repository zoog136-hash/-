extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const HELD=preload("res://scripts/quests/quest_held_use238.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const REGEN=preload("res://scripts/quests/quest_regen523.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	checks+=1
	if not v:failures.append(label);printerr("QUEST_REGEN_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func held_id(w: Node,iid: int)->String:
	for id: String in w.item_instances:
		if int(w.item_instances[id].get("record",{}).get("source_item_class_id",0))==iid and w.item_instances[id].has("quest_reward_receipt"):return id
	return ""
func attempt(w: Node,id: String)->Dictionary:
	var owned: Dictionary=OWN.prepare_debit(w,id,1)
	if not owned.get("ok",false):return {"handled":true,"committed":false,"uncertain":false}
	return HELD.perform(w,owned,D.variant_item(w.quest_item_provider.bound_definition(int(owned.ownership.item_class_id)).native_record,int(owned.ownership.bless_code_id)))
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String="";var mode: String="normal"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact existing genuine quest save before Main")
	if not failures.is_empty():quit(1);return
	var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/class window")
	var id: String=held_id(w,385);var wisdom: String=held_id(w,376)
	check(not id.is_empty() and not wisdom.is_empty() and w.quest_item_provider.has_definition(385) and w.quest_item_provider.has_definition(376),"actual original two-class ownership and source provider installed")
	if not failures.is_empty():w.queue_free();await process_frame;quit(1);return
	w.quest_auto.refresh_context(w);var completed: int=0;var pending: int=0
	for row: Dictionary in w.quest_service.entries(w.level,w.inventory):
		if row.get("source_id")!=null and row.completed:
			completed+=1
			if not row.rewards.get("pending_use",[]).is_empty():pending+=1
	var inv: Dictionary=w.inventory.duplicate(true);var objects: Dictionary=w.item_instances.duplicate(true);var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold;var before: String=FileAccess.get_sha256(w.save_path())
	if mode=="uncertain":
		var backup:=FileAccess.open("user://quest_regen_uncertain_original.json",FileAccess.WRITE);backup.store_buffer(FileAccess.get_file_as_bytes(w.save_path()));backup.close()
		w.equipment_collections.test_save_writer=func(path: String,_data: Dictionary)->Error:
			var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string("{");f.close();return ERR_FILE_CANT_WRITE
		var result: Dictionary=attempt(w,id);w.equipment_collections.test_save_writer=Callable()
		check(not result.committed and result.uncertain and w.quest_service.save_blocked,"changed unconfirmed result blocks retry")
		check(w.inventory==inv and w.item_instances==objects and w.active_item_buffs.is_empty(),"corrupt QA write cannot adopt debit or effect")
		check(not attempt(w,id).committed and FileAccess.get_file_as_string(w.save_path())=="{","no second transaction against uncertain ownership")
	else:
		check(not attempt(w,wisdom).committed and FileAccess.get_sha256(w.save_path())==before,"actual Knight cannot consume source Mage-only wisdom")
		var original: Dictionary=w.item_instances[id].duplicate(true);w.item_instances[id].quest_reward_receipt.bless_code_id=2
		check(not attempt(w,id).committed,"wrong blessing proof rejected");w.item_instances[id]=original
		var locks: Dictionary=w.ui_preferences.get("item_locks",{}).duplicate(true);w.ui_preferences["item_locks"]={};w.ui_preferences.item_locks[str(original.name)+"@@@"+id]=true
		check(not attempt(w,id).committed,"actual selected lock preserves source unit");w.ui_preferences["item_locks"]=locks
		w.ui_preferences["quest523_mp_regen_interval_seconds"]=0
		check(not attempt(w,id).committed,"disabled cadence leaves source activation blocked");w.ui_preferences.erase("quest523_mp_regen_interval_seconds")
		var old_hp: int=w.hp;w.hp=0;check(not attempt(w,id).committed,"dead actor preserves potion");w.hp=old_hp
		var stale: Dictionary=OWN.prepare_debit(w,id,1);w.inventory[original.name]=int(w.inventory[original.name])+1
		check(not HELD.perform(w,stale,D.variant_item(w.quest_item_provider.bound_definition(385).native_record,1)).committed,"stale selected-ownership debit cannot execute");w.inventory=inv.duplicate(true)
		check(w.item_instances==objects and FileAccess.get_sha256(w.save_path())==before,"all failed eligibility attempts preserve owned records and save bytes")
		w.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_FILE_CANT_WRITE
		check(not attempt(w,id).committed,"prewrite failure does not commit source use");w.equipment_collections.test_save_writer=Callable()
		check(w.inventory==inv and w.item_instances==objects and FileAccess.get_sha256(w.save_path())==before and w.active_item_buffs.is_empty(),"failed debit/buff/receipt transaction leaves prior bytes intact")
		var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(original.name)+"@@@"+id)
		check(not bag.detail_action.disabled and bag.detail_text.text.contains("TWILIGHT") and bag.detail_text.text.contains("원본 주기 미확인") and bag.detail_text.text.contains("300초"),"actual selected inventory describes source amount and host cadence")
		bag.detail_action.pressed.emit()
		var key: String=str(D.variant_item(w.quest_item_provider.bound_definition(385).native_record,1).name);var buff: Dictionary=w.active_item_buffs.get(key,{})
		check(int(w.item_instances[id].source_reward_quantity)==int(original.source_reward_quantity)-1 and w.item_instances[id].quest_reward_receipt==original.quest_reward_receipt,"selected actual stack partially debited with immutable grant proof")
		check(int(buff.get("mp_regen_tick",0))==3 and float(buff.get("remaining",0))==300 and float(buff.get("tick_interval",0))==30 and buff.get("quest523_regen_policy",{}).get("source_interval_verified")==false,"source RegenMP3/300seconds with labelled30second host cadence")
		for uid: String in objects:
			if uid!=id:check(w.item_instances.get(uid)==objects[uid],"no other legacy/native/quest object consumed")
		w.mp=0;w._tick_item_buffs(29.0);check(w.mp==0,"no recovery before configured cadence")
		w._tick_item_buffs(1.0);check(w.mp==3,"actual existing tick engine recovers exact source3")
		check(w._save_game(true)==OK,"timer remainder and MP saved together")
		check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.rng.state==rng and w.gold==gold,"consuming potion and controlled tick preserve original claims50slots/currency/RNG before reconnect")
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));var hash: String=FileAccess.get_sha256(w.save_path())
		w.queue_free();await process_frame;w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"fresh actual Main reconnect")
		rng=w.rng.state # Existing new-Main randomization is outside item consumption.
		check(norm(w.active_item_buffs)==saved.active_item_buffs and w.mp==3 and norm(w.item_instances)==saved.item_instances and FileAccess.get_sha256(w.save_path())==hash,"source partial quantity/buff/timer/receipt/MP reconnect")
		check(w.patch523_npc_spells.extensions.cancel_quest_regen([999])==0 and w.active_item_buffs.has(key),"nonmatching native cancel group preserves potion")
		check(w.patch523_npc_spells.extensions.cancel_quest_regen([5])==1 and not w.active_item_buffs.has(key),"actual source NPC cancellation consumer removes matching nonimmune potion only")
		print("PRESERVATION_KNIGHT "+JSON.stringify({"claims":w.quest_service.claimed==claims,"slots":norm(w.quickslots)==norm(slots),"rng":w.rng.state==rng,"gold":w.gold==gold,"rng_before":rng,"rng_after":w.rng.state}))
		check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.rng.state==rng and w.gold==gold,"Knight consumer transactions preserve original claims50slots/currency/RNG")
		check(QA.enter_game(w,"마법사"),"actual existing class-change UI selects Mage for class-gated use")
		var mage_slots: Array=w.quickslots.duplicate(true)
		wisdom=held_id(w,376);var q: Dictionary=w.item_instances[wisdom].duplicate(true)
		w.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:
			var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close();return ERR_FILE_CANT_WRITE
		var result: Dictionary=attempt(w,wisdom);w.equipment_collections.test_save_writer=Callable();check(result.committed and not result.uncertain,"confirmed write-then-error jointly commits source unit and buff once")
		key=str(D.variant_item(w.quest_item_provider.bound_definition(376).native_record,1).name);buff=w.active_item_buffs.get(key,{})
		check(int(w.item_instances[wisdom].source_reward_quantity)==int(q.source_reward_quantity)-1 and w._active_item_buff_total("sp")==2 and int(buff.get("mp_regen_tick",0))==2,"actual Mage-owned wisdom reaches SP2 and source MP2")
		var left: int=int(w.item_instances[wisdom].source_reward_quantity)
		check(not attempt(w,wisdom).committed and int(w.item_instances[wisdom].source_reward_quantity)==left,"immediate repeated use respects500ms cooldown without another debit")
		w.mp=0;w._tick_item_buffs(30.0);check(w.mp==2,"source wisdom exact MP amount reaches existing tick consumer")
		check(w.quest_service.save_blocked==false,"confirmed write-error did not block current consistent ownership")
		USE.clear_on_death(w);check(not w.active_item_buffs.has(key),"existing source death consumer removes nonimmune potion")
		print("PRESERVATION_MAGE "+JSON.stringify({"claims":w.quest_service.claimed==claims,"slots":norm(w.quickslots)==norm(mage_slots),"rng":w.rng.state==rng,"gold":w.gold==gold,"rng_after":w.rng.state}))
		check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(mage_slots) and w.quickslots.size()==slots.size() and w.rng.state==rng and w.gold==gold,"Mage consumer preserves post-class-selection50slots/currency/draw and combat RNG")
		check(w._save_game(true)==OK,"final source receipt and death state saved")
	print("QUEST_REGEN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":mode,"source_completions":completed,"knight_some_use_pending_before_actions_without_skillv3":pending,"actual_item_classes":[376,385] if mode=="normal" else [],"cadence_policy":"TWILIGHT configurable30s; source interval not verified","controlled_class_and_tick_contexts_not_natural_probabilities":true,"save_sha256":FileAccess.get_sha256(w.save_path())}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
