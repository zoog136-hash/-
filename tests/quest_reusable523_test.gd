extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const R=preload("res://scripts/quests/quest_reusable523.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const BUFF_IDS=[295544,302461]
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	checks+=1
	if not v:failures.append(label);printerr("QUEST_REUSABLE_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String="";var mode: String="held"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	if mode=="fresh":check(OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/q262-r11-") and not FileAccess.file_exists("user://twilight_v20_save.json"),"empty isolated producer profile")
	else:check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"immutable actual811 source-issued baseline")
	if not failures.is_empty():quit(1);return
	var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/current map/class UI")
	if mode=="fresh":
		w.level=86;check(w._save_game(true)==OK,"explicit QA eligibility level, not naturally earned XP")
		for step: int in range(100):
			w.quest_auto.last_signature="";w.quest_auto.next_scan=0;w.quest_auto.auto_claim=true;w.quest_auto.tick(w)
			if w.quest_service.save_blocked or w.quest_auto.retry_at>Time.get_unix_time_from_system():break
	var inventory: Dictionary=w.inventory.duplicate(true);var objects: Dictionary=w.item_instances.duplicate(true);var quest: Dictionary=w.quest_service.export_state();var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold
	var issued: Dictionary={}
	for iid: int in BUFF_IDS:
		var record: Dictionary=D.variant_item(D.definition_id(str(iid)).native_record,1);var id: String="";var key: String=str(record.name)
		if mode!="fresh":
			for uid: String in w.item_instances:
				if w.item_instances[uid].has("quest_reward_receipt") and int(w.item_instances[uid].record.source_item_class_id)==iid:id=uid;break
			check(not id.is_empty(),"genuine original raw quest reward for reusable source item")
			if id.is_empty():continue
		else:
			var found: bool=false
			for rows: Array in w.quest_service.item_grants.values():
				for receipt: Dictionary in rows:
					if receipt.get("item_class_id")==iid and not receipt.has("origin"):found=true
			check(found and int(w.inventory.get(key,0))>0,"genuine automatic original quest producer -> registered native ownership/receipt")
			if not found:continue
		issued[str(iid)]={"physical_id":id,"quantity":int(w.inventory.get(key,0)) if id.is_empty() else int(w.item_instances[id].source_reward_quantity)}
		check(not R.profile(record).is_empty(),"entire exact InfiniteAmount/buff/duration/effect/source group definition accepted")
		var before: String=FileAccess.get_sha256(w.save_path());var state: Dictionary=w.consumable_service.export_state();var buffs: Dictionary=w.active_item_buffs.duplicate(true)
		if mode=="uncertain":
			w.equipment_collections.test_save_writer=func(path: String,_d: Dictionary)->Error:
				var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string("{");f.close();return ERR_FILE_CANT_WRITE
			var result: Dictionary=R.perform(w,record,id);w.equipment_collections.test_save_writer=Callable()
			check(not result.saved and result.uncertain and w.quest_service.save_blocked,"uncertain changed save blocks repeated ownership/effect use")
			check(w.inventory==inventory and w.item_instances==objects and w.active_item_buffs==buffs and w.consumable_service.export_state()==state,"uncertain result adopts neither effect nor use ledger nor debit")
			check(not R.perform(w,record,id).saved and FileAccess.get_file_as_string(w.save_path())=="{","uncertain result cannot be retried")
			break
		var locks: Dictionary=w.ui_preferences.get("item_locks",{}).duplicate(true);w.ui_preferences["item_locks"]={(key if id.is_empty() else str(w.item_instances[id].name)+"@@@"+id):true}
		check(not R.perform(w,record,id).saved,"selected/native locked ownership preserved");w.ui_preferences["item_locks"]=locks
		var hp: int=w.hp;w.hp=0;check(not R.perform(w,record,id).saved,"dead actor cannot activate source reusable item");w.hp=hp
		if not id.is_empty():
			var original: Dictionary=w.item_instances[id].duplicate(true);w.item_instances[id].quest_reward_receipt.bless_code_id=2
			check(not R.perform(w,record,id).saved,"wrong immutable source blessing rejected");w.item_instances[id]=original
		w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
		check(not R.perform(w,record,id).saved,"prewrite failure has no effect/use ledger");w.equipment_collections.test_save_writer=Callable()
		check(w.inventory==inventory and w.item_instances==objects and w.active_item_buffs==buffs and w.consumable_service.export_state()==state and FileAccess.get_sha256(w.save_path())==before,"all failed ownership/effect transactions preserve save bytes/source quantities")
		var bag: Variant=w.hud.lineage_inventory_ui;bag.inventory=w.inventory;bag.set_character_state(w.hud.character_state)
		bag._select_item(key if id.is_empty() else str(w.item_instances[id].name)+"@@@"+id)
		check(not bag.detail_action.disabled,"existing actual inventory action; no new UI")
		bag.detail_action.pressed.emit()
		var buff: Dictionary=w.active_item_buffs.get(key,{})
		check(buff.get("duration")==1800 and buff.get("remaining")==1800 and buff.get("source_buff_class",{}).get("ID")== (223 if iid==295544 else 5),"real existing UI invokes original30minute source buff")
		check(w.inventory==inventory and w.item_instances==objects and w.quest_service.export_state()==quest,"infinite use preserves all physical quantities and original/used grant ledger")
		var ledger_key: String="native:"+str(record.sourceId) if id.is_empty() else "quest:"+id
		check(w.consumable_service.export_state().get("source_reusable_item_uses",{}).get(ledger_key,{}).get("uses")==1,"separate ownership-proven successful-use counter persisted once")
		check(not R.perform(w,record,id).saved,"500ms source reuse cooldown prevents duplicate action")
		w.item_use_cooldowns["m523:item:"+str(iid)]=0.0
		w.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:
			var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"",true,true));f.close();return ERR_FILE_CANT_WRITE
		check(R.perform(w,record,id).saved,"confirmed write-then-error adopts effect and counter together once");w.equipment_collections.test_save_writer=Callable()
		check(w.consumable_service.export_state().get("source_reusable_item_uses",{}).get(ledger_key,{}).get("uses")==2 and w.inventory==inventory and w.item_instances==objects,"repeated source infinite use retains ownership; separate count two")
		if iid==295544:check(w._active_item_buff_total("melee_damage")==3 and w._active_item_buff_total("ranged_damage")==3 and w._active_item_buff_total("sp")==3 and w._active_item_buff_total("magic_accuracy")==3,"source six exact combat effects reach existing stat consumers")
		else:check(w._active_item_buff_total("def")==3,"source ArmorClass3 reaches existing defense stat consumer")
	if mode!="uncertain":
		for uid: String in objects:check(w.item_instances.get(uid)==objects[uid],"every unrelated selected/legacy/native quest object unchanged")
		check(w.quest_service.export_state()==quest and norm(w.quickslots)==norm(slots) and w.gold==gold and w.rng.state==rng,"claims50slots/currency/RNG unchanged")
		check(w._save_game(true)==OK,"final owned quantities/buffs/cooldowns/use ledger saved together")
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));var hash: String=FileAccess.get_sha256(w.save_path())
		w.queue_free();await process_frame;w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"new actual Main reconnect")
		check(norm(w.inventory)==saved.inventory and norm(w.item_instances)==saved.item_instances and norm(w.active_item_buffs)==saved.active_item_buffs and norm(w.consumable_service.export_state())==saved.consumable_state and FileAccess.get_sha256(w.save_path())==hash,"reusable ownership/effect/cooldown/counter reconnect")
		for iid: int in BUFF_IDS:
			var rec: Dictionary=D.variant_item(D.definition_id(str(iid)).native_record,1);var uid: String=str(issued[str(iid)].physical_id)
			w.item_use_cooldowns["m523:item:"+str(iid)]=0.0
			check(R.perform(w,rec,uid).saved,"reloaded JSON numeric proof still authenticates third source reusable use")
		USE.clear_on_death(w)
		var battle: String=str(D.variant_item(D.definition_id("295544").native_record,1).name);var armor: String=str(D.variant_item(D.definition_id("302461").native_record,1).name)
		check(w.active_item_buffs.has(battle) and not w.active_item_buffs.has(armor),"actual source death immunity differs: battle retained, armor removed")
	print("QUEST_REUSABLE_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":mode,"actual_item_classes":BUFF_IDS,"issued":issued,"no_quantity_consumption":true,"controlled_eligibility_not_natural_probabilities":true,"final_save_sha256":FileAccess.get_sha256(w.save_path())}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
