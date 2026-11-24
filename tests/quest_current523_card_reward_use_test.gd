extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const FIXED=preload("res://scripts/quests/quest_fixed_cards523.gd")
const EXPECTED={139781:[77381,93201,12231,false,false],289172:[60311,296242,22892,false,false],
	289182:[60321,296252,22902,false,false],289202:[60341,296272,22922,true,false],306611:[86111,323831,23801,true,true],
	306621:[86521,326161,23811,true,true],306631:[86571,326291,23821,true,true],306641:[86581,326321,23831,true,true]}
var failures: Array[String]=[]
var checks: int=0
var rejected: Dictionary={}
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_CARD_FAIL ",label)
func _initialize()->void:run.call_deferred()
func reject(_path: String,candidate: Dictionary)->Error:
	rejected=candidate
	return ERR_FILE_CANT_WRITE

func run()->void:
	check(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"actual pinned original 523 archive")
	if failures.is_empty():await exercise()
	print("QUEST_CURRENT523_CARD_USE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func exercise()->void:
	var w: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(w)
	w.set_process(false);w.player.set_physics_process(false);w.field_population.set_process(false);w.save_timer=-100000
	check(QA.enter_game(w,"마검사"),"real class-selected Main")
	var primary: String="m523:quest:60311"
	for id: int in EXPECTED:
		var row: Array=EXPECTED[id]
		var quest: Dictionary=w.quest_service.full(w.quest_service.index.get("m523:quest:"+str(row[0]),{}))
		var found: bool=false
		for r: Dictionary in quest.get("source_rewards",[]):
			if r.get("ID")==row[1] and r.get("RewardClassID")==id and r.get("ItemBlessCodeID")==1 and r.get("UseImmediately")==false:
				found=true;break
		check(found,"exact original quest links item "+str(id))
		var definition: Dictionary=D.definition_id(str(id))
		var target: Dictionary=FIXED.target(w,D.variant_item(definition.get("native_record",{}),1))
		var card: Dictionary=target.get("record",{})
		check(w.quest_item_provider.has_definition(id) and target.get("category")=="변신" and int(card.get("source_card_id",0))==row[2] and card.get("source_merge_out_disabled")==row[3] and card.get("source_swap_out_disabled")==row[4],"exact downstream identity and unchanged restrictions "+str(id))
	var source_quest: Dictionary=w.quest_service.full(w.quest_service.index.get(primary,{}))
	# Supply an isolated character at the original quest's eligibility point;
	# use the actual runtime to gate, stage, issue and save the reward.
	for req: Dictionary in source_quest.get("prerequisites",[]):
		if req.get("type_name")=="Quest" and w.quest_service.index.has("m523:quest:"+str(int(req.Value))):
			w.quest_service.claimed["m523:quest:"+str(int(req.Value))]=true
	w.level=55
	w.quest_auto.refresh_context(w)
	var gate: String=w.quest_service.source.gate(w.quest_service.index.get(primary,{}),w.quest_auto.context,w.quest_service.claimed,int(Time.get_unix_time_from_system()))
	check(gate.is_empty(),"real #60311 primary qualifies: "+gate)
	check(w.quest_auto.complete(w,[primary]),"actual #60311 completion issues real reward")
	var record: Dictionary=D.variant_item(D.definition_id("289172").get("native_record",{}),1)
	var name_value: String=str(record.get("name",""))
	var selected_id: String=""
	for uid: String in w.item_instances:
		if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==289172:
			selected_id=uid;break
	var owned: Dictionary=STACK.proof(w,selected_id)
	check(not owned.is_empty() and owned.get("remaining")==1 and owned.get("receipt",{}).get("origin",{}).get("kind")=="quest_current523","fresh physical modern receipt from production quest grant")
	if selected_id.is_empty():w.queue_free();return
	var actual_name: String=str(w.item_instances[selected_id].name)
	var reference: String=actual_name+"@@@"+selected_id
	var identity: String="source:m508:1:22892"
	var before: PackedByteArray=FileAccess.get_file_as_bytes(w.save_path())
	var old_cards: Dictionary=w.card_draw_fusion.export_state()
	var old_quest: Dictionary=w.quest_service.export_state()
	w.equipment_collections.test_save_writer=reject
	w.hud.inventory_item_activated.emit(reference)
	check(not rejected.is_empty() and rejected.get("inventory",{}).get(actual_name,0)==0 and rejected.get("card_draw_fusion",{}).get("owned",{}).get("변신",{}).get(identity)==true,"fault hits writer with both exact debit and deck grant")
	check(w.card_draw_fusion.export_state()==old_cards and w.quest_service.export_state()==old_quest and w.inventory.get(actual_name)==1 and before==FileAccess.get_file_as_bytes(w.save_path()),"failed save changes neither card, quest, inventory, nor bytes")
	w.equipment_collections.test_save_writer=Callable()
	w._load_game(true) # Native failed saves intentionally require a trusted reload.
	w.hud.inventory_item_activated.emit(reference)
	check(w.card_draw_fusion.total_count("변신",identity)==1 and not w.item_instances.has(selected_id) and not w.inventory.has(actual_name),"actual inventory activation owns only Dark Blader and consumes one")
	var persisted: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	check(persisted.get("card_draw_fusion",{}).get("owned",{}).get("변신",{}).get(identity)==true and not persisted.get("inventory",{}).has(actual_name),"exact durable bag/deck output")
	w.card_draw_fusion.owned["변신"].erase(identity)
	w._load_game(true)
	check(w.card_draw_fusion.total_count("변신",identity)==1 and not w.inventory.has(actual_name),"load restores the card without returning original reward")
	if is_instance_valid(w.hud.card_reveal_stage) and w.hud.card_reveal_stage.has_method("close_reveal"):
		w.hud.card_reveal_stage.call("close_reveal")
	var tutorial: String="m523:quest:77381"
	check(not w.quest_service.source.gate(w.quest_service.index.get(tutorial,{}),w.quest_auto.context,w.quest_service.claimed,int(Time.get_unix_time_from_system())).is_empty(),"deleted tutorial remains disabled; only its already-issued card may be used")
	exercise_legacy(w,139781,false)
	exercise_legacy(w,306611,true)
	w.queue_free()
	await process_frame


## An isolated previous-issue save fixture built from the actual original
## quest's reward plan, not a fabricated ItemClass or a free card injection.
func exercise_legacy(w: TwilightWorld,item_id: int,old_name_balance: bool)->void:
	var entry: Array=EXPECTED[item_id]
	var quest_id: String="m523:quest:"+str(entry[0])
	var quest: Dictionary=w.quest_service.full(w.quest_service.index.get(quest_id,{}))
	var plan: Dictionary=w.quest_service.source.reward_plan(quest,w.quest_auto.context.duplicate(true))
	var canonical: Dictionary=D.variant_item(D.definition_id(str(item_id)).get("native_record",{}),1)
	var name_value: String=str(canonical.get("name",""))
	var uid: String=""
	w.quest_service.claimed[quest_id]=true
	if old_name_balance:
		w.quest_service.item_grants[quest_id]=[{"schema":1,"reward_id":entry[1],"item_class_id":item_id,"quantity":1,"bless_raw":1,"inventory_key":name_value,"pack_sha256":FIXED.PIN}]
	else:
		var context: Dictionary=w.quest_auto.context.duplicate(true)
		context["class_id"]=81 # Historical Saint Paladin receipt before the tutorial was retired.
		for key: String in ["quest_item_provider","source_item_consumer","source_items"]:context.erase(key)
		plan=w.quest_service.source.reward_plan(quest,context)
		var held: Dictionary={}
		for candidate: Dictionary in plan.get("items",[]):
			if candidate.get("source_reward_id")==entry[1]:
				held=candidate.get("record",{});break
		check(held.get("source_pending_use")==true,"actual unbound reward plan reproduces the old raw receipt")
		if held.is_empty():return
		name_value=str(held.name)
		uid=str(w.next_item_instance_id)
		w.next_item_instance_id+=1
		w.item_instances[uid]={"name":name_value,"record":held,"level":0,"source_reward_quantity":1,"quest_reward_receipt":{"schema":1,"quest_id":quest_id,"reward_id":entry[1],"item_class_id":item_id,"bless_code_id":1,"source_sha256":SOURCE.SOURCE_SHA,"quantity":1}}
	w.inventory[name_value]=1
	if old_name_balance:
		check(FIXED.legacy_receipts(w,name_value,item_id).size()==1,"historical name balance verifies against actual quest relation")
	else:
		check(OWN.proof(w,uid).get("ok",false),"actual quest receipt is well-formed before activation")
	check(w._save_game(true)==OK,"legacy fixture accepted by actual save guard")
	w.hud.inventory_item_activated.emit(name_value+("@@@"+uid if not uid.is_empty() else ""))
	var identity: String="source:m508:1:"+str(entry[2])
	check(w.card_draw_fusion.total_count("변신",identity)==1 and not w.inventory.has(name_value),"legacy reward consumed to exact card #"+str(item_id))
