extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_GEAR_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func make_world()->TwilightWorld:
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false)
 check(QA.enter_game(w,"기사"),"actual saved character class selection");return w
func activate(w: TwilightWorld,uid: String)->void:
 var p: Dictionary=w.item_instances[uid];var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(p.name)+"@@@"+uid)
 check(not bag.detail_action.disabled and bag.detail_action.text=="선택 개체 장착","actual inventory selected-instance button")
 bag.detail_action.pressed.emit()
func raw(w: TwilightWorld,id: int)->String:
 for uid: String in w.item_instances:
  if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==id and w.item_instances[uid].has("quest_reward_receipt"):return uid
 return ""
func output(w: TwilightWorld,input: String)->String:
 for uid: String in w.item_instances:
  if w.item_instances[uid].get("quest_source_input_physical_id")==input:return uid
 return ""
func run()->void:
 var seed: String="";var mode: String="held"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
  if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
 check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact retained genuine producer save copied unchanged")
 var w: TwilightWorld=make_world();var owner: RefCounted=w.quest_item_provider.equipment_owner
 check(not owner.data.is_empty(),"exact bounded gear view loaded from unchanged verified239 input")
 var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold
 var original_inventory: Dictionary=w.inventory.duplicate(true);var hash: String=FileAccess.get_sha256(w.save_path())
 if mode=="rune":
  var id: String="8023355db46215dffeafef8db866d8b6";var physical: Dictionary=w.item_instances[id].duplicate(true)
  check(owner._state_matches(w,id).get("ok",false),"real369002->59062->226318 provenance authenticated without deleting either receipt")
  var quote: Dictionary=owner.quote(w,id);check(quote.get("ok",false),"actual selected rune equip candidate")
  if quote.get("ok",false):owner.cancel(quote.token);check(not owner.commit(w,quote).get("ok",false),"cancelled rune candidate never commits")
  check(w.inventory==original_inventory and w.equipped_items.get("rune",{}).is_empty() and FileAccess.get_sha256(w.save_path())==hash,"cancelled actual rune preserves inventory/save/equipped state")
  var bad: Dictionary=physical.duplicate(true);bad.quest_source_input_receipt.reward_id+=1;w.item_instances[id]=bad
  check(not owner.quote(w,id).get("ok",false),"wrong original quest reward cannot equip")
  w.item_instances[id]=physical.duplicate(true);w.item_instances[id].source_m_reward_proof.bless=1.5
  check(not owner.quote(w,id).get("ok",false),"fractional blessing proof cannot equip")
  w.item_instances[id]=physical.duplicate(true);w.item_instances[id].future_unknown_state=true
  check(not owner.quote(w,id).get("ok",false),"unknown physical fields preserved and refused")
  w.item_instances[id]=physical.duplicate(true)
  var def: int=w._effective_defense();var mr: int=w._effective_mr();var xp: float=w._experience_multiplier()
  w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
  activate(w,id);w.equipment_collections.test_save_writer=Callable()
  check(w.equipped_items.get("rune",{}).is_empty() and w.item_instances[id]==physical and FileAccess.get_sha256(w.save_path())==hash,"actual rune save failure preserves ownership/effects/receipts")
  activate(w,id)
  check(w.equipped_items.get("rune",{}).get("instance_id")==id and w.inventory==original_inventory and w.item_instances[id]==physical,"same existing UUID and both original provenance records equipped with no debit/regrant")
  check(w._effective_defense()==def+1 and w._effective_mr()==mr+5,"actual existing defense and MR consumers apply exact rune1/5")
  check(is_equal_approx(w._experience_multiplier(),xp+.03),"original rank0 XP3percent reaches existing experience consumer")
  hash=FileAccess.get_sha256(w.save_path());check(not owner.quote(w,id).get("ok",false),"already worn owner quote refuses duplicate")
  w._on_inventory_item_activated(str(physical.name)+"@@@"+id)
  check(FileAccess.get_sha256(w.save_path())==hash,"already worn rune cannot repeat a transaction")
  w._unequip_item_reference(str(physical.name)+"@@@"+id)
  check(w.equipped_items.get("rune",{}).is_empty() and w._effective_defense()==def and w._effective_mr()==mr and is_equal_approx(w._experience_multiplier(),xp) and w.item_instances[id]==physical,"atomic UI unequip reverts exact effects without source consumption")
  activate(w,id)
 else:
  var held: int=0;var eligible: int=0;var unsupported: int=0
  for uid: String in w.item_instances.keys():
   var r: Dictionary=w.item_instances[uid].get("record",{})
   if not owner.IDS.has(int(r.get("source_item_class_id",0))) or not r.get("source_pending_use",false):continue
   held+=1;check(OWN.proof(w,uid).get("ok",false),"genuine selected held equipment receipt "+uid)
   var q: Dictionary=owner.quote(w,uid)
   if q.get("ok",false):eligible+=1;owner.cancel(q.token)
   else:unsupported+=1
  check(held==33 and eligible>0 and unsupported>0,"all33 actual held stacks checked; unsupported effects/class remain separate")
  check(w.inventory==original_inventory and FileAccess.get_sha256(w.save_path())==hash and w.rng.state==rng,"read-only cancelled gear candidates do not materialize a live item or advance world RNG")
  var source: String=raw(w,1197);var original: Dictionary=w.item_instances[source].duplicate(true);var owned: Dictionary=OWN.proof(w,source)
  var q: Dictionary=owner.quote(w,source);check(q.get("ok",false),"actual HP20 necklace staged")
  if not q.get("ok",false):w.queue_free();await process_frame;quit(1);return
  var tampered: Dictionary=q.duplicate(true);tampered.payload.inventory["fake credit"]=999
  check(not owner.commit(w,tampered).get("ok",false),"external candidate payload tampering cannot grant credit");owner.cancel(q.token)
  q=owner.quote(w,source);w.ui_preferences.item_locks[str(owned.inventory_key)+"@@@"+source]=true
  check(not owner.commit(w,q).get("ok",false) and w.item_instances[source]==original,"stale quote and source lock preserve actual selected input")
  w.ui_preferences.item_locks.erase(str(owned.inventory_key)+"@@@"+source)
  w.item_instances[source].quest_reward_receipt.quantity=2
  check(not owner.quote(w,source).get("ok",false),"wrong immutable original quantity refused")
  w.item_instances[source]=original.duplicate(true)
  var max_hp: int=w._effective_max_hp();var before: Dictionary=w.item_instances.duplicate(true)
  w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
  activate(w,source);w.equipment_collections.test_save_writer=Callable()
  check(w.item_instances==before and w.inventory==original_inventory and w.equipped_items.get("necklace",{}).is_empty() and FileAccess.get_sha256(w.save_path())==hash,"held materialization/equip failure preserves every input/output/effect/receipt")
  w.equipment_collections.test_save_writer=func(p: String,data: Dictionary)->Error:
   var error: Error=WRITER.write(p,data)
   return ERR_FILE_CANT_WRITE if error==OK else error
  activate(w,source);w.equipment_collections.test_save_writer=Callable()
  var uid: String=output(w,source)
  if uid.is_empty():
   printerr("QUEST_GEAR_FAIL no durable materialized output; message="+str(w.hud.message_label.text));w.queue_free();await process_frame;quit(1);return
  check(not uid.is_empty() and uid.length()==32 and not w.item_instances.has(source) and w.equipped_items.get("necklace",{}).get("instance_id")==uid,"write-then-error confirms one selected debit plus one real UUID equipped")
  check(w._effective_max_hp()==max_hp+20 and not w.quest_service.save_blocked,"actual existing HP consumer applies20 after confirmed save")
  check(w.item_instances[uid].quest_source_input_receipt==original.quest_reward_receipt and w.item_instances[uid].source_m_reward_proof.supplier.input_receipt==original.quest_reward_receipt and owner._state_matches(w,uid).get("ok",false),"original input and verified supplier provenance retained separately on physical output")
  var body1: String=raw(w,2772);var body_name: String=w.item_instances[body1].name;var quantity: int=int(w.inventory[body_name])
  activate(w,body1);var first: String=output(w,body1);var body2: String=raw(w,2772)
  check(not first.is_empty() and not body2.is_empty() and int(w.inventory[body_name])==quantity-1,"partial aggregate keeps the other genuinely issued same-name receipt owned")
  var other: Dictionary=w.item_instances[body2].duplicate(true);w.ui_preferences.item_locks[str(w.item_instances[first].name)+"@@@"+first]=true
  check(not owner.quote(w,body2).get("ok",false) and w.item_instances[body2]==other,"locked existing worn object is not replaced or consumed")
  w.ui_preferences.item_locks.erase(str(w.item_instances[first].name)+"@@@"+first)
  activate(w,body2);var second: String=output(w,body2)
  check(not second.is_empty() and second!=first and w.equipped_items.body.instance_id==second and w.item_instances.has(first) and not w.item_instances.has(body2),"selected second receipt materializes its own UUID and never consumes competing first native object")
  var helmet: String=raw(w,240);var item: Dictionary=w.item_instances[helmet].duplicate(true);var job: String=w.job_class;w.job_class="마법사"
  check(not owner.quote(w,helmet).get("ok",false) and w.item_instances[helmet]==item,"native class restriction enforced independently of source completion")
  w.job_class=job
  var helmet_record: Dictionary=owner.profile(240,1);var saved_weight: Variant=w.item_weight_index.get(str(helmet_record.name),null);w.item_weight_index[str(helmet_record.name)]=w._carrying_capacity()+1
  check(not owner.quote(w,helmet).get("ok",false),"candidate gear weight cannot exceed existing capacity")
  if saved_weight==null:w.item_weight_index.erase(str(helmet_record.name))
  else:w.item_weight_index[str(helmet_record.name)]=saved_weight
  var def: int=w._effective_defense();activate(w,helmet)
  check(w._effective_defense()==def+3,"actual source helmet AC3 reaches current defense consumer")
  print("QUEST_GEAR_ELIGIBILITY "+JSON.stringify({"actual_held_stacks":held,"eligible_cancelled":eligible,"blocked_preserved":unsupported,"multiunit_gear_stack_not_in_original811":true,"partial_two_independent_receipts_verified":true}))
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.gold==gold and w.rng.state==rng,"all transactions preserve original claims,50bindings,gold and unrelated RNG")
 var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));hash=FileAccess.get_sha256(w.save_path())
 check(durable.equipped_items==norm(w.equipped_items) and durable.item_instances==norm(w.item_instances) and durable.inventory==norm(w.inventory) and durable.consumable_state==norm(w.consumable_service.export_state()),"one durable snapshot includes actual physical/equip/receipt state")
 w.queue_free();await process_frame;w=make_world();owner=w.quest_item_provider.equipment_owner
 check(norm(w.inventory)==durable.inventory and norm(w.item_instances)==durable.item_instances and norm(w.equipped_items)==durable.equipped_items and norm(w.quest_service.export_state())==durable.quest_state and FileAccess.get_sha256(w.save_path())==hash,"fresh Main reconnect preserves exact saved ownership/equipment/quest receipts")
 for key: String in w.equipped_items:
  var worn: Dictionary=w.equipped_items[key]
  if worn.is_empty():continue
  check(owner._state_matches(w,str(worn.instance_id)).get("ok",false),"reconnected selected equipment owner authenticates "+key)
 print("QUEST_EQUIPMENT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":mode,"input_sha256":seed,"final_save_sha256":FileAccess.get_sha256(w.save_path()),"source_gear_scope":"exact +0 AC/HP/MR only; unknown effects/enchant/proc remain held","natural_multiquantity_gear_tested":false,"rules_sha256":owner.RULE_SHA}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
