extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	checks+=1
	if not v:failures.append(label);printerr("QUEST_GEAR_REGEN_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
	check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact previously validated real21-unit gear producer save")
	if not failures.is_empty():quit(1);return
	var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main and preserved current class")
	var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var gold: int=w.gold;var rng: int=w.rng.state;var used: Array=[];var expected_hp: int=0;var expected_mp: int=0;var outputs: Dictionary={}
	for iid: int in [4851,4871,4921,4951,85643]:
		var id: String=""
		for uid: String in w.item_instances:
			if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==iid and w.item_instances[uid].has("quest_reward_receipt"):id=uid;break
		check(not id.is_empty(),"genuine remaining source regeneration equipment")
		if id.is_empty():continue
		var owner: RefCounted=w.quest_item_provider.equipment_owner;var before: Dictionary=w.item_instances.duplicate(true);var hash: String=FileAccess.get_sha256(w.save_path());var q: Dictionary=owner.quote(w,id)
		check(q.get("ok",false),"all original positive effects and current source conditions supported")
		if not q.get("ok",false):print("GEAR_REGEN_HELD "+JSON.stringify({"item":iid,"reason":q.get("reason")}));continue
		owner.cancel(q.token)
		if iid==4851:
			w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
			check(not owner.commit(w,owner.quote(w,id)).get("ok",false),"failed save never equips/consumes source regeneration gear");w.equipment_collections.test_save_writer=Callable()
			check(w.item_instances==before and FileAccess.get_sha256(w.save_path())==hash,"physical input/effect/receipt/save preserved on failure")
		var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(w.item_instances[id].name)+"@@@"+id)
		check(not bag.detail_action.disabled and bag.detail_text.text.contains("30초"),"actual selected gear UI labels existing host cadence")
		bag.detail_action.pressed.emit();var output: String=""
		for uid: String in w.item_instances:
			if w.item_instances[uid].get("quest_source_input_physical_id")==id:output=uid;break
		check(not output.is_empty() and owner._state_matches(w,output).get("ok",false),"actual selected source unit yields one authenticated worn UUID")
		if output.is_empty():continue
		for uid: String in before:
			if uid!=id:check(w.item_instances.get(uid)==before[uid],"all competing legacy/native/quest objects remain unchanged")
		outputs[str(iid)]=output;used.append(iid)
		expected_hp+=int({4851:4,4871:5,4921:1,4951:3}.get(iid,0));expected_mp+=1 if iid==85643 else 0
		w.ui_preferences["quest523_source_gear_regen_enabled"]=false;w._invalidate_equipment_static();w._refresh_equipment_effects();var legacy_hp: int=int(w.equipment_effects.hp_tick_amount);var legacy_mp: int=int(w.equipment_effects.mp_tick_amount)
		w.ui_preferences.erase("quest523_source_gear_regen_enabled");w._invalidate_equipment_static();w._refresh_equipment_effects()
		check(int(w.equipment_effects.hp_tick_amount)==legacy_hp+expected_hp and int(w.equipment_effects.mp_tick_amount)==legacy_mp+expected_mp,"exact source amounts add to unchanged legacy/card/growth recovery policy")
	check(used==[4851,4871,4921,4951,85643],"all five exact source regeneration classes worn")
	if used.size()==5:
		w._refresh_equipment_effects();var hp_tick: int=int(w.equipment_effects.hp_tick_amount);var mp_tick: int=int(w.equipment_effects.mp_tick_amount)
		w.hp=1;w.mp=0;w.hp_recovery_elapsed=0;w.mp_recovery_elapsed=0;w._tick_catalog_recovery(29.0);check(w.hp==1 and w.mp==0,"existing gear recovery clock has no early source tick")
		w._tick_catalog_recovery(1.0);check(w.hp==mini(w._effective_max_hp(),1+hp_tick) and w.mp==mini(w._effective_max_mp(),mp_tick),"actual existing gear tick uses13sourceHP and1sourceMP plus prior legacy amounts")
		var uid: String=outputs["4851"];var physical: Dictionary=w.item_instances[uid].duplicate(true);var bag: Variant=w.hud.lineage_inventory_ui
		bag.set_character_state(w.hud.character_state);bag._select_item(str(physical.name)+"@@@"+uid);bag.detail_action.pressed.emit();w._refresh_equipment_effects()
		check(int(w.equipment_effects.hp_tick_amount)==hp_tick-4 and w.item_instances[uid]==physical,"same-UUID unequip removes only the selected source4 regen")
		bag.set_character_state(w.hud.character_state);bag._select_item(str(physical.name)+"@@@"+uid);bag.detail_action.pressed.emit();w._refresh_equipment_effects();check(int(w.equipment_effects.hp_tick_amount)==hp_tick,"same-UUID re-equip restores source4 without another item debit")
	check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.rng.state==rng and w.gold==gold,"original claims50bindings/currency/RNG preserved by all source gear transactions")
	check(w._save_game(true)==OK,"source ownership/equipment/effects/current HPMP and receipt saved")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));var hash: String=FileAccess.get_sha256(w.save_path());var effects: Dictionary=w.equipment_effects.duplicate(true)
	w.queue_free();await process_frame;w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"fresh actual Main reconnect with same source input")
	w._refresh_equipment_effects();check(norm(w.item_instances)==saved.item_instances and norm(w.equipped_items)==saved.equipped_items and w.equipment_effects.hp_tick_amount==effects.hp_tick_amount and w.equipment_effects.mp_tick_amount==effects.mp_tick_amount and FileAccess.get_sha256(w.save_path())==hash,"all five real gear UUIDs/receipt/regen amounts and source effects reconnect")
	print("QUEST_GEAR_REGEN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"actual_item_classes":used,"host_policy":"existing30second gear clock; source amounts4/5/1/3HP and1MP; original interval unverified","selected_units":used.size(),"natural_probability_or_native_cycle_equivalence":false,"save_sha256":hash}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
