extends SceneTree
const R=preload("res://scripts/loot/retired_enhancement_items523.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const S=preload("res://scripts/resources/current523_definition_rows.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks:=0
func ck(ok:bool,msg:String)->void:
	checks+=1
	if not ok:failures.append(msg);printerr("RETIRED_ITEMS_FAIL ",msg)
func _initialize()->void:run.call_deferred()
func run()->void:
	for f: String in DirAccess.get_files_at("user://"):
		if f.begins_with("twilight_v20_save"):printerr("use an isolated test profile");quit(2);return
	var w: Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false)
	ck(QA.enter_game(w),"actual Main")
	w.field_population.set_process(false)
	var src: String=OS.get_environment("TW_TEST_RETIRED_SOURCE")
	if not src.is_empty():
		OS.set_environment("TWILIGHT_PATCH523_CONTENT",src);S.reset()
		# The isolated fixture installs the real pack after map entry; bind the
		# same normal awakening reader as boot, not a bypass of its save guard.
		w.skill_awakening=w.SKILL_AWAKENING.new()
		ck(w.skill_awakening.configure(w),"newly installed source binds actual awakening reader: "+w.skill_awakening.problem)
	var active: Dictionary={"source_item_class_id":133135,"sourceId":"m523:item:133135","name":"same-name active control"}
	var rows: Array=[active]
	var old: Dictionary
	var item_ids: Array=[133134,133144,133154,133324,151863,151873,153904,153914,153924,153934,163603,163613,163623,163633,244282,351964,358932]
	ck(R.IDS.size()==item_ids.size(),"exact scoped set")
	for id: int in item_ids:
		var rec: Dictionary={"source_item_class_id":id,"sourceId":"m523:item:"+str(id),"source":"lineagem_patch523","source_snapshot":"patch523","source_m_native_item":true,"name":"retired "+str(id),"slot":"ring"}
		if not src.is_empty():
			var raw: Dictionary=S.row("ItemClass",id)
			ck(raw.get("ID")==id and raw.get("TestItem")==false,"actual retained original "+str(id))
			if id==133134:
				var native: Dictionary=D.definition_id(str(id)).get("native_record",{})
				ck(native.get("source_item_class_id")==id,"archived canonical item definition")
				if not native.is_empty():rec=native
		if id==133134:old=rec.duplicate(true)
		rows.append(rec)
		ck(R.record(rec) and R.record({"sourceId":"m523:item:%d:bless:2"%id}) and not R.item(id+0.5),"exact id and blessing "+str(id))
		ck(not w.stage_source_item_grants([{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"qa"}).ok,"actual grant rejected "+str(id))
		ck(not preload("res://scripts/crafting/patch523_rules.gd").new()._source_item_allowed(id),"craft input/output "+str(id))
		ck(not STACK.stage_floor_grant(rec,1,{}).ok and w.source_item_record(id).is_empty(),"floor issue and reference "+str(id))
	var variant: Dictionary=active.duplicate();variant.name=old.name
	rows.append(variant);rows.append({"ID":133134,"name":"unrelated namespace"})
	w.catalog_db["아이템"].append_array(rows);w._index_catalog_item_sources()
	ck(w._catalog_item_from_source_id("m523:item:133134").is_empty() and w._catalog_item_from_source_id("m523:item:133135")==active,"playable index removes exact id; same-name option remains")
	ck(R.catalog(rows)==[active,variant,{"ID":133134,"name":"unrelated namespace"}] and rows.size()==20,"stable unmodified projection")
	ck(not R.record({"name":old.name,"sourceId":"m523:recipe:133134"}) and not R.record({"sourceId":"m523:item:1331340"}) and not R.record({"sourceId":"m523:item:133134:wrong:2"}),"no namespace/name/prefix match")
	ck(w._source_catalog_record("아이템",old)==old,"archival lookup cannot alias same-name variant")
	ck(not w.source_shop._resolve({"unit_id":4,"class_id":133134,"amount":1},true,{},100).ok and w.source_shop._native_supply_binding(133134,1).is_empty(),"shop grant + fallback refuse")
	ck(not w.item_book523._prove({"item_class_id":133134}).ok,"collection turn-in refuses before debit")
	w._equip_or_acquire_item(old,true)
	ck(not w.inventory.has(old.name),"direct grant/equip blocked before mutation")
	var uid: String="712342";var held: Dictionary={"name":old.name,"record":old,"level":3,"element":"","element_level":0,"source_m_reward_proof":{"source_snapshot":"patch523","item_class_id":133134,"source_item_class_id":133134,"bless":1,"enchant":3,"supplier":{"kind":"prior"}}}
	w.inventory[old.name]=1;w.item_instances[uid]=held
	ck(w.unconfirmed523.stage_item({},133134,1)==R.REASON,"independent 523 item supplier refuses")
	var reward: Dictionary={"row":{"ID":1,"RewardClassID":133134,"ItemBlessCodeID":1,"Amount":1},"type":"Item","item":{"name":"old ring"}}
	var dungeon: Dictionary=w.dungeon_play.reward_plan_original([reward])
	ck(dungeon.granted.is_empty() and dungeon.withheld.size()==1 and not w.dungeon_play.reward_plan([reward]).ok,"no fallback dungeon alias")
	var locked: Dictionary=held.duplicate(true)
	var ref: String=str(old.name)+"@@@"+uid
	w._equip_reference_in_slot(ref,"ring");w._on_inventory_item_activated(ref)
	ck(w.hud.message_label.text==R.REASON and w.item_instances[uid]==locked and not w._is_instance_equipped(uid),"selected old instance/use inert")
	ck(w._source_enhancement_rule(old,3,"normal").get("reason")==R.REASON and w.item_instances[uid]==locked,"old equipment does not roll or debit")
	var saved: Error=w._save_game(false)
	ck(saved==OK,"old stock still saves under same physical ID: "+error_string(saved)+" "+w.hud.message_label.text+" / "+w.equipment_collections.problem)
	w.item_instances={};w.inventory={};w._load_game(true)
	var loaded: Dictionary=w.item_instances.get(uid,{})
	ck(w.inventory.get(old.name)==1 and loaded.get("level")==3 and loaded.get("record",{}).get("source_item_class_id")==133134 and loaded.get("source_m_reward_proof",{}).get("supplier",{}).get("kind")=="prior","actual save reload keeps holding, rank, identity and historical proof")
	print("RETIRED_ITEMS_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"original_pack":not src.is_empty()}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
