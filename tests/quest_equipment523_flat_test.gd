extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_GEAR_FLAT_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact prior actual gear save copied unchanged")
 if not failures.is_empty():quit(1);return
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/class selection")
 var owner: RefCounted=w.quest_item_provider.equipment_owner;var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold;var used_ids: Array=[]
 for iid: int in [926,2832,5021]:
  var id: String=""
  for uid: String in w.item_instances:
   if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==iid and w.item_instances[uid].has("quest_reward_receipt"):id=uid;break
  check(not id.is_empty(),"genuine remaining source reward "+str(iid))
  if id.is_empty():continue
  var before: Dictionary=w.item_instances.duplicate(true);var old_mp: int=w.mp;var old_max_mp: int=w._effective_max_mp();var old_str: int=w._effective_attribute("STR");var quote: Dictionary=owner.quote(w,id)
  check(quote.get("ok",false),"exact MP/STR source profile and constraints "+str(iid))
  if not quote.get("ok",false):continue
  owner.cancel(quote.token)
  var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(w.item_instances[id].name)+"@@@"+id);check(not bag.detail_action.disabled,"actual selected inventory button");bag.detail_action.pressed.emit()
  var output: String=""
  for uid: String in w.item_instances:
   if w.item_instances[uid].get("quest_source_input_physical_id")==id:output=uid;break
  check(not output.is_empty() and owner._state_matches(w,output).get("ok",false) and not w.item_instances.has(id),"selected source debit plus exact physical output/equip receipt")
  if output.is_empty():continue
  for uid: String in before:
   if uid!=id:check(w.item_instances.get(uid)==before[uid],"unrelated actual physical state unchanged")
  if iid==926:
   check(w._effective_max_mp()==old_max_mp+25 and w.mp==old_mp,"source MP25 reaches existing max-MP consumer without free MP refill")
   var record: Dictionary=w.item_instances[output].duplicate(true)
   w.mp=w._effective_max_mp();check(w._save_game(true)==OK,"controlled QA mana refill fixture saved for clamp path")
   bag.set_character_state(w.hud.character_state);bag._select_item(str(record.name)+"@@@"+output);check(str(bag.detail_action.text).contains("해제"),"existing worn-belt UI unequip action");bag.detail_action.pressed.emit()
   check(w._effective_max_mp()==old_max_mp and w.mp==old_max_mp and w.item_instances[output]==record,"same-UUID atomic belt unequip clamps current MP under reduced maximum")
   bag.set_character_state(w.hud.character_state);bag._select_item(str(record.name)+"@@@"+output);bag.detail_action.pressed.emit()
   check(w._effective_max_mp()==old_max_mp+25 and w.mp==old_max_mp,"belt re-equip preserves current MP, raises maximum only")
  else:check(w._effective_attribute("STR")==old_str+1,"source Strength1 reaches existing attribute consumer")
  used_ids.append(iid)
 check(used_ids==[926,2832,5021],"all three additional exact source classes executed")
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.rng.state==rng and w.gold==gold,"no regrant/claim/quickslot/RNG/currency change")
 var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));var hash: String=FileAccess.get_sha256(w.save_path());check(durable.item_instances==norm(w.item_instances) and durable.equipped_items==norm(w.equipped_items) and durable.inventory==norm(w.inventory),"joint durable physical/equipment state")
 var max_mp: int=w._effective_max_mp();var strength: int=w._effective_attribute("STR");w.queue_free();await process_frame
 w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"fresh actual Main reconnect")
 check(norm(w.item_instances)==durable.item_instances and norm(w.equipped_items)==durable.equipped_items and w._effective_max_mp()==max_mp and w._effective_attribute("STR")==strength and FileAccess.get_sha256(w.save_path())==hash,"MP/STR state/effects/receipt reconnect exactly")
 print("QUEST_EQUIPMENT_FLAT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"actual_additional_item_classes":used_ids,"save_sha256":hash,"controlled_mana_refill_fixture":true,"scope":"exact MP/STR existing consumers and one selected equipment transaction, not new native spell/weapon/regen engines"}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
