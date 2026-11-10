extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const R=preload("res://scripts/quests/quest_reusable523.gd")
const B=preload("res://scripts/quests/quest_source_buffs523.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	checks+=1
	if not v:failures.append(label);printerr("QUEST_SOURCE_BUFF_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func held(w: Node,id: int)->String:
	for uid: String in w.item_instances:
		if w.item_instances[uid].has("quest_reward_receipt") and int(w.item_instances[uid].record.source_item_class_id)==id:return uid
	return ""
func attempt(w: Node,record: Dictionary,uid: String)->void:
	if uid.is_empty():w.quest_item_provider.try_use_inventory(w,str(record.name))
	else:w.quest_item_provider.try_use_held(w,uid)
func _initialize()->void:call_deferred("run")
func run()->void:
	var mode: String="held";var seed: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
	if mode=="fresh":check(OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/q262-r13-") and not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated empty fresh producer profile")
	else:check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact immutable genuine source811 producer baseline")
	if not failures.is_empty():quit(1);return
	var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/current source map and class UI")
	if mode=="fresh":
		w.level=86;check(w._save_game(true)==OK,"explicit controlled starting eligibility level, not natural XP")
		for step: int in range(100):
			w.quest_auto.last_signature="";w.quest_auto.next_scan=0;w.quest_auto.auto_claim=true;w.quest_auto.tick(w)
			if w.quest_service.save_blocked or w.quest_auto.retry_at>Time.get_unix_time_from_system():break
	var issued: Dictionary={};var consumed_uid: String="";var current_food: String="";var xp_key: String="";var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var gold: int=w.gold;var rng: int=w.rng.state
	for iid: int in B.IDS:
		var record: Dictionary=D.variant_item(D.definition_id(str(iid)).native_record,1);var key: String=str(record.name);var uid: String="" if mode=="fresh" else held(w,iid)
		if mode=="fresh":
			var found: bool=false
			for rows: Array in w.quest_service.item_grants.values():
				for receipt: Dictionary in rows:
					if receipt.get("item_class_id")==iid and not receipt.has("origin"):found=true
			check(found and int(w.inventory.get(key,0))>0,"actual automatic source quest issues exact native ID and original receipt")
		else:check(not uid.is_empty(),"actual source-issued selected held physical record")
		if (mode=="fresh" and int(w.inventory.get(key,0))<=0) or (mode!="fresh" and uid.is_empty()):continue
		issued[str(iid)]={"physical_id":uid,"quantity":int(w.inventory.get(key,0)) if uid.is_empty() else int(w.item_instances[uid].source_reward_quantity)}
		check(w.quest_item_provider.has_definition(iid) and USE.action_record(w,record).get("source_use_spec",{}).get("activation_status")=="unrestricted","exact complete source joins enable only reviewed effect")
		var inv: Dictionary=w.inventory.duplicate(true);var objects: Dictionary=w.item_instances.duplicate(true);var quest: Dictionary=w.quest_service.export_state();var buffs: Dictionary=w.active_item_buffs.duplicate(true);var state: Dictionary=w.consumable_service.export_state();var hash: String=FileAccess.get_sha256(w.save_path())
		if mode=="uncertain":
			if iid==1186:continue
			w.equipment_collections.test_save_writer=func(path: String,_data: Dictionary)->Error:
				var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string("{");f.close();return ERR_FILE_CANT_WRITE
			var result: Dictionary=R.perform(w,record,uid);w.equipment_collections.test_save_writer=Callable()
			check(not result.saved and result.uncertain and w.quest_service.save_blocked,"changed unconfirmed source food save blocks another transaction")
			check(w.inventory==inv and w.item_instances==objects and w.active_item_buffs==buffs and w.consumable_service.export_state()==state,"unconfirmed food effect/reusable counter not adopted")
			check(not R.perform(w,record,uid).saved and FileAccess.get_file_as_string(w.save_path())=="{","uncertain outcome cannot be retried")
			break
		if iid in B.FOOD:
			w.ui_preferences["quest523_food_regen_interval_seconds"]=0
			check(not R.perform(w,record,uid).saved,"disabled/unverified cadence preserves food and original source effects");w.ui_preferences.erase("quest523_food_regen_interval_seconds")
		w.equipment_collections.test_save_writer=func(_p: String,_data: Dictionary)->Error:return ERR_FILE_CANT_WRITE
		attempt(w,record,uid);w.equipment_collections.test_save_writer=Callable()
		check(w.inventory==inv and w.item_instances==objects and w.active_item_buffs==buffs and w.consumable_service.export_state()==state and FileAccess.get_sha256(w.save_path())==hash,"prewrite failure preserves selected quantity/effects/receipts and bytes")
		var bag: Variant=w.hud.lineage_inventory_ui;bag.inventory=w.inventory;bag.set_character_state(w.hud.character_state);bag._select_item(key if uid.is_empty() else str(w.item_instances[uid].name)+"@@@"+uid)
		check(not bag.detail_action.disabled,"existing actual inventory use action, no replacement UI")
		bag.detail_action.pressed.emit()
		var buff: Dictionary=w.active_item_buffs.get(key,{})
		check(buff.get("duration")==1800 and buff.get("remaining")==1800 and buff.get("source_item_class_id")==iid,"original30minute buff is actual saved use result")
		if iid==1186:
			xp_key=key
			check(w._active_item_buff_total("xp")==10 and is_equal_approx(w._experience_multiplier(),1.0+float(w._equipped_numeric_sum("xp"))+0.1),"source raw100000 Percentage reaches existing XP multiplier as10percent")
			if uid.is_empty():check(int(w.inventory[key])==int(inv[key])-1 and w.quest_service.export_state()==quest,"new native finite potion has exactly one debit with immutable producer grants")
			else:
				consumed_uid=uid;check(not w.item_instances.has(uid) and int(w.inventory.get(objects[uid].name,0))==int(inv[objects[uid].name])-1,"selected one-unit source stack removed without consuming competing same-name physical records")
				var receipt: Dictionary=objects[uid].quest_reward_receipt;var matched: bool=false
				for r: Dictionary in w.quest_service.item_grants.get(str(receipt.quest_id),[]):
					if r.get("reward_id")==receipt.reward_id and r.get("quantity")==receipt.quantity and r.get("used_quantity")==1:matched=true
				check(matched,"finite used count is separate from immutable original grant quantity")
		else:
			check(w.inventory==inv and w.item_instances==objects and w.quest_service.export_state()==quest,"InfiniteAmount1 keeps physical ownership, original quantity and used ledger unchanged")
			check(w._active_item_buff_total("melee_damage")==2 and w._active_item_buff_total("ranged_damage")==2 and w._active_item_buff_total("sp")==2 and w._active_item_buff_total("mr")==10 and w._active_item_buff_total("damage_reduction")==2,"all seven original flat cooking effects reach existing stat consumers")
			if not current_food.is_empty():check(not w.active_item_buffs.has(current_food),"source non-overlap group291 replaces prior cooking buff rather than stacking")
			current_food=key
			w.hp=w._effective_max_hp()-20;w.mp=w._effective_max_mp()-30
			var hp: int=w.hp;var mp: int=w.mp;w._tick_item_buffs(29.0);check(w.hp==hp and w.mp==mp,"labelled host cadence does not tick early")
			w._tick_item_buffs(1.0);check(w.hp==hp+2 and w.mp==mp+3,"actual existing tick consumer applies exact source HP2/MP3")
		for id: String in objects:
			if id!=consumed_uid:check(w.item_instances.get(id)==objects[id],"every unrelated/competing legacy/native/source record remains intact")
		check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.gold==gold and w.rng.state==rng,"consumer transactions preserve completion50slots/currency/RNG")
	if mode!="uncertain":
		check(w._save_game(true)==OK,"source debit/owned food/effects/timer/counter saved")
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));var hash: String=FileAccess.get_sha256(w.save_path());w.queue_free();await process_frame
		w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"fresh actual Main reconnect")
		check(norm(w.inventory)==saved.inventory and norm(w.item_instances)==saved.item_instances and norm(w.active_item_buffs)==saved.active_item_buffs and norm(w.consumable_service.export_state())==saved.consumable_state and FileAccess.get_sha256(w.save_path())==hash,"finite/infinite ownership/immutable receipts/effects/timer/counter reconnect")
		USE.clear_on_death(w);check(w.active_item_buffs.has(xp_key) and not w.active_item_buffs.has(current_food),"original XP death immunity and food death removal remain distinct")
		var before: float=w._experience_multiplier();w._tick_item_buffs(float(w.active_item_buffs[xp_key].remaining));check(not w.active_item_buffs.has(xp_key) and is_equal_approx(before-w._experience_multiplier(),0.1),"source XP expiry removes exactly the original10percent contribution")
	print("QUEST_SOURCE_BUFF_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":mode,"item_classes":B.IDS,"issued":issued,"original_source_XP_percent":10,"source_food_regen_HP":2,"source_food_regen_MP":3,"host_food_interval_seconds":30,"native_interval_and_XP_stacking_order_verified":false,"final_save_sha256":FileAccess.get_sha256(w.save_path())}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
