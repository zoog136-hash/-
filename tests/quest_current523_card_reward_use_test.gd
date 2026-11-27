extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const FIXED=preload("res://scripts/quests/quest_fixed_cards523.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const FORGE=preload("res://scripts/ui/renewal_forge.gd")
const NAMED=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const ENCHANT_WINDOW=preload("res://scripts/ui/original_ui/source_main_enchant_window.gd")
const ELEMENT_MANAGEMENT=preload("res://scripts/equipment523/element_management.gd")
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

func use_from_bag(w: TwilightWorld,reference: String)->void:
	var hud: Node=w.hud
	hud._close_workspace()
	hud.toggle_inventory()
	if not OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").is_empty():
		check(hud.original_inventory_is_open(),"selected original inventory is mounted")
	if hud.original_inventory_is_open():
		check(hud.original_inventory_select(reference).get("ok",false),"original bag selects the owned reward")
		check(hud.lineage_inventory_ui.item_action_label(reference)=="사용","first tap shows 사용")
		check(hud.original_inventory_activate_selected(reference).get("emitted",false),"second tap emits the selected original bag action")
	else:
		hud.lineage_inventory_ui._select_item(reference)
		check(hud.lineage_inventory_ui.item_action_label(reference)=="사용","first tap shows 사용 in the fallback bag")
		hud.lineage_inventory_ui._activate_selected()

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
	await process_frame # Let the normal deferred original HUD binding finish.
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
	use_from_bag(w,reference)
	check(not rejected.is_empty() and rejected.get("inventory",{}).get(actual_name,0)==0 and rejected.get("card_draw_fusion",{}).get("owned",{}).get("변신",{}).get(identity)==true,"fault hits writer with both exact debit and deck grant")
	check(w.card_draw_fusion.export_state()==old_cards and w.quest_service.export_state()==old_quest and w.inventory.get(actual_name)==1 and before==FileAccess.get_file_as_bytes(w.save_path()),"failed save changes neither card, quest, inventory, nor bytes")
	w.equipment_collections.test_save_writer=Callable()
	w._load_game(true) # Native failed saves intentionally require a trusted reload.
	use_from_bag(w,reference)
	check(w.card_draw_fusion.total_count("변신",identity)==1 and not w.item_instances.has(selected_id) and not w.inventory.has(actual_name),"actual inventory activation owns only Dark Blader and consumes one")
	var persisted: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	check(persisted.get("card_draw_fusion",{}).get("owned",{}).get("변신",{}).get(identity)==true and not persisted.get("inventory",{}).has(actual_name),"exact durable bag/deck output")
	w.card_draw_fusion.owned["변신"].erase(identity)
	w._load_game(true)
	check(w.card_draw_fusion.total_count("변신",identity)==1 and not w.inventory.has(actual_name),"load restores the card without returning original reward")
	if is_instance_valid(w.hud.card_reveal_stage) and w.hud.card_reveal_stage.has_method("close_reveal"):
		w.hud.card_reveal_stage.call("close_reveal")
	if is_instance_valid(w.hud.original_main_ui_controller):w.hud.original_main_ui_controller.close_feature_windows()
	var tutorial: String="m523:quest:77381"
	check(not w.quest_service.source.gate(w.quest_service.index.get(tutorial,{}),w.quest_auto.context,w.quest_service.claimed,int(Time.get_unix_time_from_system())).is_empty(),"deleted tutorial remains disabled; only its already-issued card may be used")
	exercise_legacy(w,139781,"",true)
	exercise_legacy(w,289182)
	exercise_legacy(w,306611,FIXED.PIN)
	exercise_legacy(w,306621,SOURCE.SOURCE_SHA)
	exercise_quest_enchantment(w)
	exercise_elemental_enchantment(w)
	if not OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").is_empty():await exercise_element_management(w)
	w.queue_free()
	await process_frame


## An isolated previous-issue save fixture built from the actual original
## quest's reward plan, not a fabricated ItemClass or a free card injection.
func exercise_legacy(w: TwilightWorld,item_id: int,name_digest: String="",compact: bool=false)->void:
	var entry: Array=EXPECTED[item_id]
	var quest_id: String="m523:quest:"+str(entry[0])
	var quest: Dictionary=w.quest_service.full(w.quest_service.index.get(quest_id,{}))
	var canonical: Dictionary=D.variant_item(D.definition_id(str(item_id)).get("native_record",{}),1)
	var name_value: String=str(canonical.get("name",""))
	var uid: String=""
	w.quest_service.claimed[quest_id]=true
	if not name_digest.is_empty():
		w.quest_service.item_grants[quest_id]=[{"schema":1,"reward_id":entry[1],"item_class_id":item_id,"quantity":1,"bless_raw":1,"inventory_key":name_value,"pack_sha256":name_digest}]
	else:
		var rewards: Array=quest.get("source_rewards",[]).filter(func(row: Dictionary)->bool:return row.get("ID")==entry[1])
		if rewards.size()!=1:return
		# Run just this pinned award through the legacy writer. Other awards in
		# the now-retired quest may be disallowed by current grant policy.
		var plan: Dictionary=w.quest_service.source.reward_plan({"source_rewards":rewards,"enhancements":[]},{"class_id":int(rewards[0].CharacterClassID)})
		var held: Dictionary=plan.get("items",[])[0].record if not plan.get("items",[]).is_empty() else {}
		check(held.get("source_pending_use")==true,"actual unbound reward plan reproduces the old raw receipt")
		if held.is_empty():return
		name_value=str(held.name)
		if compact:
			held={"name":name_value,"grade":"미확인","slot":"quest_reward","type":"원본 보상 보관","source_pending_use":true}
		uid=str(w.next_item_instance_id)
		w.next_item_instance_id+=1
		w.item_instances[uid]={"name":name_value,"record":held,"level":0,"source_reward_quantity":1,"quest_reward_receipt":{"schema":1,"quest_id":quest_id,"reward_id":entry[1],"item_class_id":item_id,"bless_code_id":1,"source_sha256":SOURCE.SOURCE_SHA,"quantity":1}}
	w.inventory[name_value]=1
	check(w._save_game(true)==OK,"legacy fixture accepted by actual save guard")
	w._load_game(true)
	if not name_digest.is_empty():
		check(FIXED.legacy_receipts(w,name_value,item_id).size()==1,"historical name balance verifies against actual quest relation")
	else:
		check(OWN.proof(w,uid).get("ok",false),"actual quest receipt is well-formed before activation")
		if compact and w.item_instances.has(uid):
			var record: Dictionary=w.item_instances[uid].record
			check(not record.has("source_item_class_id"),"loading leaves the compact record unchanged")
			record["source_item_class_id"]=289172
			check(not OWN.proof(w,uid).get("ok",false),"conflicting saved identity cannot use another card")
			record.erase("source_item_class_id")
			w.item_instances[uid].quest_reward_receipt.reward_id=93202
			check(not OWN.proof(w,uid).get("ok",false),"a wrong quest link does not grant a card")
			w.item_instances[uid].quest_reward_receipt.reward_id=entry[1]
			if is_instance_valid(w.hud.original_main_ui_controller):
				var bag: Control=w.hud.lineage_inventory_ui
				bag._select_item(name_value+"@@@"+uid)
				bag.open_selected_info()
				var tooltip: RefCounted=w.hud.original_main_ui_controller.item_tooltip()
				check(tooltip!=null and tooltip.is_open() and tooltip.last_result.get("item_class_id")==item_id,"compact card details use the exact ID in the original tooltip")
	use_from_bag(w,name_value+("@@@"+uid if not uid.is_empty() else ""))
	var identity: String="source:m508:1:"+str(entry[2])
	check(w.card_draw_fusion.total_count("변신",identity)==1 and not w.inventory.has(name_value),"legacy reward consumed to exact card #"+str(item_id))

func exercise_quest_enchantment(w: TwilightWorld)->void:
	var scroll_uid: String=""
	var quest_id: String=""
	for candidate: String in ["m523:quest:71934","m523:quest:72084","m523:quest:78102","m523:quest:81871","m523:quest:60022"]:
		var quest: Dictionary=w.quest_service.full(w.quest_service.index.get(candidate,{}))
		for req: Dictionary in quest.get("prerequisites",[]):
			if req.get("type_name")=="Quest":w.quest_service.claimed["m523:quest:"+str(int(req.Value))]=true
		w.quest_auto.refresh_context(w)
		if not w.quest_service.source.gate(w.quest_service.index.get(candidate,{}),w.quest_auto.context,w.quest_service.claimed,int(Time.get_unix_time_from_system())).is_empty():continue
		if not w.quest_auto.complete(w,[candidate]):continue
		for uid: String in w.item_instances:
			if w.item_instances[uid].get("quest_reward_receipt",{}).get("item_class_id")==6401:
				scroll_uid=uid
				quest_id=candidate
				break
		if not scroll_uid.is_empty():break
	check(not scroll_uid.is_empty(),"actual eligible quest issues held engraved weapon scroll #6401")
	if scroll_uid.is_empty():return
	check(INV.commit(w,[{"item_class_id":27,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}),"supply the verified +0 registered weapon")
	var weapon_uid: String=""
	for uid: String in w.item_instances:
		if w.item_instances[uid].get("record",{}).get("source_item_class_id")==27:
			weapon_uid=uid
			break
	if weapon_uid.is_empty():return
	var scroll: String=w.item_instances[scroll_uid].name
	var previous_amount: int=int(w.inventory.get(scroll,0))
	var reference: String=scroll+"@@@"+scroll_uid
	var target: String=w.item_instances[weapon_uid].name+"@@@"+weapon_uid
	w.hud.refresh_inventory(w.inventory)
	check(FORGE.owned_scrolls(w.hud).any(func(row: Dictionary)->bool:return row.reference==reference and row.count==1),"enhancement chooser lists exact quest scroll")
	var gold_before: int=w.gold
	var rng_before: int=w.rng.state
	var save_before: String=FileAccess.get_sha256(w.save_path())
	use_from_bag(w,reference)
	check(w.hud.enhancement_candidates.any(func(row: Dictionary)->bool:return row.target_id==target and row.success_chance==100.0),"original scroll selects its actual safe +0 weapon family")
	check(w.gold==gold_before and w.rng.state==rng_before and FileAccess.get_sha256(w.save_path())==save_before,"opening an enhancement does not debit or roll")
	var native: RefCounted=w.hud._original_enchant_window()
	if not OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").is_empty():check(native!=null,"enhancement chooser is the mounted original window")
	if native!=null:check(native.select_target(target).get("ok",false),"choose the verified target in the original window")
	var start: Callable=native._enchant_requested if native!=null else w.hud.enhancement_requested.emit.bind(scroll,target)
	rejected={}
	w.equipment_collections.test_save_writer=reject
	start.call()
	check(not rejected.is_empty(),"forced disk failure reaches the exact enhancement writer: "+w.hud.message_label.text)
	check(w.inventory.get(scroll,0)==previous_amount and w.item_instances[weapon_uid].level==0 and w.gold==gold_before and w.rng.state==rng_before and FileAccess.get_sha256(w.save_path())==save_before,"failed enhancement preserves the scroll, weapon, adena, RNG and save")
	w.equipment_collections.test_save_writer=Callable()
	start.call()
	check(not w.item_instances.has(scroll_uid) and w.inventory.get(scroll,0)==previous_amount-1 and w.item_instances[weapon_uid].level==1,"the successful roll debits the same quest scroll and raises the weapon: "+w.hud.message_label.text)
	w._load_game(true)
	var receipts: Array=w.quest_service.item_grants.get(quest_id,[])
	check(not w.item_instances.has(scroll_uid) and w.item_instances[weapon_uid].level==1 and receipts.any(func(row: Dictionary)->bool:return row.item_class_id==6401 and row.get("used_quantity",0)==1),"reload preserves the exact quest debit and enhancement result")

func exercise_elemental_enchantment(w: TwilightWorld)->void:
	check(INV.commit(w,[{"item_class_id":2731,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog"}),"actual fire scroll supply uses its original ID")
	var scroll_uid: String=""
	var weapon_uid: String=""
	for uid: String in w.item_instances:
		var item_id: int=int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))
		if item_id==27:weapon_uid=uid
		if item_id==2731:scroll_uid=uid
	check(not scroll_uid.is_empty() and not weapon_uid.is_empty(),"the original fire scroll and its weapon have owned references")
	if scroll_uid.is_empty() or weapon_uid.is_empty():return
	var scroll: String=w.item_instances[scroll_uid].name
	var reference: String=scroll+"@@@"+scroll_uid
	var target: String=w.item_instances[weapon_uid].name+"@@@"+weapon_uid
	var ordinary: int=int(w.item_instances[weapon_uid].level)
	check(ordinary==1,"elemental candidate uses an ordinarily enhanced weapon")
	w.hud.refresh_inventory(w.inventory)
	use_from_bag(w,reference)
	check(w.hud.enhancement_candidates.any(func(row: Dictionary)->bool:return row.target_id==target and row.level==0 and row.success_chance==30.0 and row.cost==1000),"fire scroll quotes original group 51 stage zero and adena for an ordinary +1 weapon")
	var native: RefCounted=w.hud._original_enchant_window()
	if native!=null:native.select_target(target)
	var start: Callable=native._enchant_requested if native!=null else w.hud.enhancement_requested.emit.bind(scroll,target)
	var rng:=RandomNumberGenerator.new()
	for seed: int in range(1,100):
		rng.seed=seed
		if rng.randf_range(0.0,100.0)<30.0:
			w.rng.seed=seed
			break
	var before: int=w.gold
	start.call()
	var weapon: Dictionary=w.item_instances.get(weapon_uid,{})
	check(not w.item_instances.has(scroll_uid) and weapon.get("element")=="fire" and weapon.get("element_level")==1 and weapon.get("level")==ordinary and w.gold==before-1000,"a fire enhancement saves only the elemental stage and spends the exact scroll and adena: "+w.hud.message_label.text)
	w._load_game(true)
	weapon=w.item_instances.get(weapon_uid,{})
	check(weapon.get("element")=="fire" and weapon.get("element_level")==1 and weapon.get("level")==ordinary and not w.item_instances.has(scroll_uid),"element, ordinary level and debit survive reload")

func exercise_element_management(w: TwilightWorld) -> void:
	var rows: Array[Dictionary]=[]
	for id: int in ELEMENT_MANAGEMENT.CONVERT_IDS+ELEMENT_MANAGEMENT.REMOVE_IDS:
		rows.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	w.gold=150000
	check(INV.commit(w,rows,{"kind":"twilight_debug_catalog"}),"all six original elemental management items have owned references")
	var ids: Dictionary={}
	for uid: String in w.item_instances:
		var id: int=int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))
		ids[id]=uid
	var weapon_uid: String=str(ids.get(27,""))
	var before_save: String=FileAccess.get_sha256(w.save_path())
	var before_rng: int=w.rng.state
	var forge_rows: Array=FORGE.owned_scrolls(w.hud)
	for row: Dictionary in rows:
		var id: int=row.item_class_id
		var uid: String=str(ids.get(id,""))
		if not ids.has(id):check(false,"missing native stack "+str(id));continue
		check(forge_rows.any(func(candidate: Dictionary) -> bool:return candidate.get("instance_id")==uid),"original enhancement scroll tab lists "+str(id))
		use_from_bag(w,str(w.item_instances[uid].name)+"@@@"+uid)
		var window: RefCounted=w.hud._original_enchant_window()
		var convert: bool=id in ELEMENT_MANAGEMENT.CONVERT_IDS
		var mode: String="element_convert" if convert else "element_remove"
		check(window!=null and window.is_open() and window.last_result.get("mode")==mode and window.last_result.get("cost")== (100000 if convert else 0) and window.last_result.get("material_uid")==uid,"mounted original elemental picker and exact fee for "+str(id))
	check(w.gold==150000 and w.rng.state==before_rng and FileAccess.get_sha256(w.save_path())==before_save,"opening each picker changes neither save, adena, nor RNG")
	if weapon_uid.is_empty() or not ids.has(2751) or not ids.has(198031):return
	var convert_uid: String=ids[2751]
	use_from_bag(w,str(w.item_instances[convert_uid].name)+"@@@"+convert_uid)
	var window: RefCounted=w.hud._original_enchant_window()
	if window==null or window.last_result.get("mode")!="element_convert":return
	check(window.select_target(weapon_uid).get("ok",false) and not window.last_result.get("can_enchant",false),"choose the owned weapon before choosing an element")
	check(not window._choose_property("fire").get("ok",false),"already applied element stays disabled")
	await press_element_button(window,ENCHANT_WINDOW.P_PROPERTY+"Nd_ButtonSet/Btn_Water_Normal")
	check(window.last_result.get("element_choice")=="water" and window.last_result.get("can_enchant",false),"actual original Water button enables conversion")
	var weapon_name: String=w.item_instances[weapon_uid].name
	w.ui_preferences.item_locks[weapon_name]=true
	await press_element_button(window,ENCHANT_WINDOW.P_SMELT_START)
	check(w.item_instances[weapon_uid].element=="fire" and w.item_instances.has(convert_uid) and FileAccess.get_sha256(w.save_path())==before_save,"a lock applied after selection still protects the weapon and scroll")
	w.ui_preferences.item_locks.erase(weapon_name)
	w.equipment_collections.test_save_writer=reject
	rejected={}
	await press_element_button(window,ENCHANT_WINDOW.P_SMELT_START)
	check(not rejected.is_empty() and rejected.get("gold")==50000,"actual original confirmation attempts the documented cost")
	check(w.item_instances[weapon_uid].element=="fire" and w.item_instances.has(convert_uid) and w.gold==150000 and w.rng.state==before_rng and FileAccess.get_sha256(w.save_path())==before_save,"failed write preserves weapon, scroll, currency, RNG, and save")
	w.equipment_collections.test_save_writer=Callable()
	await press_element_button(window,ENCHANT_WINDOW.P_SMELT_START)
	check(w.item_instances[weapon_uid].element=="water" and w.item_instances[weapon_uid].element_level==1 and w.item_instances[weapon_uid].level==1 and not w.item_instances.has(convert_uid) and w.gold==50000,"confirmed conversion changes only the element and consumes one exact scroll and the original fee")
	var remove_uid: String=ids[198031]
	use_from_bag(w,str(w.item_instances[remove_uid].name)+"@@@"+remove_uid)
	window=w.hud._original_enchant_window()
	if window==null or window.last_result.get("mode")!="element_remove":return
	window.select_target(weapon_uid)
	await press_element_button(window,ENCHANT_WINDOW.P_SMELT_START)
	w._load_game(true)
	check(w.item_instances[weapon_uid].element=="" and w.item_instances[weapon_uid].element_level==0 and w.item_instances[weapon_uid].level==1 and not w.item_instances.has(remove_uid) and w.gold==50000,"removal only clears elemental values and both exact debits survive reload")

func press_element_button(window: RefCounted, suffix: String) -> void:
	var located: Dictionary=NAMED.locate(window._scene,window.node_keys(),suffix)
	var node: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	check(area is Control and area.is_visible_in_tree(),"visible authored control "+suffix)
	if not area is Control or not area.is_visible_in_tree():return
	var point: Vector2=area.get_global_transform_with_canvas()*(area.size*0.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=0
		event.pressed=pressed
		event.position=point
		root.push_input(event,true)
		await process_frame
