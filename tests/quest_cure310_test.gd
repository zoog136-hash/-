extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const CURE=preload("res://scripts/quests/quest_cure310.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	checks+=1
	if not v:failures.append(label);printerr("QUEST_CURE310_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func bleed(w: Node)->Array:return [w.player.bleed_remaining,w.player.bleed_tick_interval,w.player.bleed_tick_clock,w.player.bleed_tick_damage]
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String="";var mode: String="held"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	if mode=="fresh":check(OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/q262-r14-") and not FileAccess.file_exists("user://twilight_v20_save.json"),"explicit empty isolated producer profile")
	else:check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact immutable actual811 producer save")
	if not failures.is_empty():quit(1);return
	var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/current source-map/class UI")
	if mode=="fresh":
		w.level=86;check(w._save_game(true)==OK,"controlled starting eligibility fixture, not natural XP")
		for step: int in range(100):
			w.quest_auto.last_signature="";w.quest_auto.next_scan=0;w.quest_auto.auto_claim=true;w.quest_auto.tick(w)
			if w.quest_service.save_blocked or w.quest_auto.retry_at>Time.get_unix_time_from_system():break
	var record: Dictionary=D.variant_item(D.definition_id("310").native_record,1);var id: String="";var key: String=str(record.name);var largest: int=0
	if mode!="fresh":
		for uid: String in w.item_instances:
			var p: Dictionary=w.item_instances[uid]
			if p.has("quest_reward_receipt") and int(p.record.source_item_class_id)==310 and int(p.source_reward_quantity)>largest:id=uid;largest=int(p.source_reward_quantity)
		check(not id.is_empty() and largest>=2,"genuine selected multi-unit source310 reward")
	else:
		var issued: bool=false
		for rows: Array in w.quest_service.item_grants.values():
			for r: Dictionary in rows:
				if r.get("item_class_id")==310 and not r.has("origin"):issued=true
		check(issued and int(w.inventory.get(key,0))>=2,"actual source quest automatically issues exact native antidote and immutable grant")
	if not failures.is_empty():w.queue_free();await process_frame;quit(1);return
	var inv: Dictionary=w.inventory.duplicate(true);var objects: Dictionary=w.item_instances.duplicate(true);var quest: Dictionary=w.quest_service.export_state();var original_receipt: Dictionary={} if id.is_empty() else w.item_instances[id].quest_reward_receipt.duplicate(true);var buffs: Dictionary=w.active_item_buffs.duplicate(true);var state: Dictionary=w.consumable_service.export_state();var hash: String=FileAccess.get_sha256(w.save_path());var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold
	check(not CURE.perform(w,record,id).get("saved",false) and FileAccess.get_sha256(w.save_path())==hash,"no matching poison target preserves item under labelled host policy")
	w.player.apply_poison(20,7,1);w.player.apply_bleed(30,3,0.75);var other: Array=bleed(w);var poisoned: Dictionary=CURE.poison(w)
	check(w.player.is_poisoned() and not CURE.prepare(w,record,id).is_empty(),"actual existing player poison owner is the effect target; no fixture ownership")
	if mode=="uncertain":
		w.equipment_collections.test_save_writer=func(path: String,_data: Dictionary)->Error:
			var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string("{");f.close();return ERR_FILE_CANT_WRITE
		var result: Dictionary=CURE.perform(w,record,id);w.equipment_collections.test_save_writer=Callable()
		check(not result.get("saved",false) and result.get("uncertain",false) and w.quest_service.save_blocked,"changed/unconfirmed cure save blocks retry")
		check(w.inventory==inv and w.item_instances==objects and CURE.poison(w)==poisoned and bleed(w)==other and w.consumable_service.export_state()==state,"unconfirmed result adopts no debit/counter or poison clear")
		check(not CURE.perform(w,record,id).get("saved",false) and FileAccess.get_file_as_string(w.save_path())=="{","no retry or poison clear after uncertain output")
	elif mode=="precision":
		w.ui_preferences["qa_precision_guard"]=1.2345678901234567
		w.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:
			var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close();return ERR_FILE_CANT_WRITE
		var result: Dictionary=CURE.perform(w,record,id);w.equipment_collections.test_save_writer=Callable()
		check(not result.get("saved",false) and result.get("uncertain",false) and w.quest_service.save_blocked and not w.patch523_owner_state_problem.is_empty(),"lossy whole-save precision cannot be accepted by a subset receipt confirmation")
		check(w.inventory==inv and w.item_instances==objects and CURE.poison(w)==poisoned and w.consumable_service.export_state()==state,"central unconfirmed transaction retains all live dose/poison/receipt/counter values")
		var disk: String=FileAccess.get_sha256(w.save_path());check(not CURE.perform(w,record,id).get("saved",false) and FileAccess.get_sha256(w.save_path())==disk,"uncertain central result blocks duplicate debit/retry")
		print("QUEST_CURE_PRECISION_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"central_whole_save_guard_preserved":true}))
		w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1);return
	else:
		var quote: Dictionary=CURE.prepare(w,record,id);w.player.poison_tick_clock=0.75
		check(not CURE.commit(w,quote).get("saved",false),"stale poison target clock invalidates selected quote");w.player.poison_tick_clock=float(poisoned.poison_tick_clock)
		var locks: Dictionary=w.ui_preferences.get("item_locks",{}).duplicate(true);w.ui_preferences["item_locks"]={(key if id.is_empty() else str(objects[id].name)+"@@@"+id):true}
		check(not CURE.perform(w,record,id).get("saved",false),"native/selected physical lock preserves dose and poison");w.ui_preferences["item_locks"]=locks
		if not id.is_empty():
			w.item_instances[id].quest_reward_receipt.bless_code_id=2;check(not CURE.prepare(w,record,id).get("ok",false),"wrong immutable blessing/source proof refused");w.item_instances[id]=objects[id].duplicate(true)
		w.equipment_collections.test_save_writer=func(_p: String,_data: Dictionary)->Error:return ERR_FILE_CANT_WRITE
		check(not CURE.perform(w,record,id).get("saved",false),"prewrite failure refuses cure/debit/counter");w.equipment_collections.test_save_writer=Callable()
		check(w.inventory==inv and w.item_instances==objects and CURE.poison(w)==poisoned and bleed(w)==other and w.consumable_service.export_state()==state and FileAccess.get_sha256(w.save_path())==hash,"all failed candidates retain actual poison, source quantities and save bytes")
		var bag: Variant=w.hud.lineage_inventory_ui;bag.inventory=w.inventory;bag.set_character_state(w.hud.character_state);bag._select_item(key if id.is_empty() else str(objects[id].name)+"@@@"+id)
		check(not bag.detail_action.disabled,"existing real inventory action, no UI creation")
		w.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:
			var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"",true,true));f.close();return ERR_FILE_CANT_WRITE
		bag.detail_action.pressed.emit();w.equipment_collections.test_save_writer=Callable()
		check(not w.player.is_poisoned() and w.player.poison_remaining==0 and w.player.poison_tick_damage==0 and bleed(w)==other,"confirmed write-then-error clears only actual core poison, preserves bleeding")
		var inventory_key: String=key if id.is_empty() else str(objects[id].name);check(int(w.inventory[inventory_key])==int(inv[inventory_key])-1,"one confirmed UI cure debits exactly one genuine unit")
		if not id.is_empty():check(int(w.item_instances[id].source_reward_quantity)==largest-1 and w.item_instances[id].quest_reward_receipt==original_receipt,"actual selected partial remaining and immutable granted amount remain distinct")
		var hp: int=w.hp;w.player._tick_poison(3.0);check(w.hp==hp,"cleared actual poison can no longer tick damage")
		w.player.apply_poison(20,7,1);check(not CURE.perform(w,record,id).get("saved",false) and w.player.is_poisoned(),"new poison cannot bypass original500ms reuse delay")
		w._tick_item_buffs(0.5)
		var log_key: String="native:"+str(record.sourceId) if id.is_empty() else "quest:"+id
		var history: Dictionary=w.consumable_service.export_state();history.source_instant_cure_uses[log_key]["existing_extension"]={"retained":true};w.consumable_service.import_state(history)
		var result: Dictionary=CURE.perform(w,record,id);check(result.get("saved",false) and result.get("consumed")==1 and not w.player.is_poisoned(),"second real owned unit cures new poison after source cooldown")
		check(int(w.inventory[inventory_key])==int(inv[inventory_key])-2 and w.consumable_service.export_state().source_instant_cure_uses[log_key].units_consumed==2 and w.consumable_service.export_state().source_instant_cure_uses[log_key].existing_extension=={"retained":true},"same dose/counter transaction retains existing owner extension")
		for uid: String in objects:
			if uid!=id:check(w.item_instances.get(uid)==objects[uid],"every competing/legacy/native/source physical record unchanged")
		check(w.active_item_buffs==buffs and bleed(w)==other and w.quest_service.claimed==quest.claimed and norm(w.quickslots)==norm(slots) and w.rng.state==rng and w.gold==gold,"no fabricated timed buff, unrelated status removal, claim/reward/50slot/currency/RNG change")
		if id.is_empty():check(w.quest_service.export_state()==quest,"new native grant receipts stay immutable")
		else:check(int(w.item_instances[id].source_reward_quantity)==largest-2 and w.item_instances[id].quest_reward_receipt==original_receipt,"same selected source stack partly consumed twice without receipt rewrite")
		check(w._save_game(true)==OK,"dose/cure log/cooldown/receipt save succeeds")
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));hash=FileAccess.get_sha256(w.save_path());w.queue_free();await process_frame
		w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main reconnect")
		check(norm(w.inventory)==saved.inventory and norm(w.item_instances)==saved.item_instances and norm(w.consumable_service.export_state())==saved.consumable_state and not w.player.is_poisoned() and FileAccess.get_sha256(w.save_path())==hash,"actual dose/counter/receipts reconnect; existing load clears transient player statuses")
	print("QUEST_CURE310_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":mode,"item_class_id":310,"source_buff_class_id":27,"physical_id":id,"effect_owner":"existing Player.clear_poison","controlled_poison_not_natural_NPC_probability":true,"other_poison_DOT_or_curse_namespaces_not_erased":true,"existing_transient_load_policy_preserved":true,"final_save_sha256":FileAccess.get_sha256(w.save_path())}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
