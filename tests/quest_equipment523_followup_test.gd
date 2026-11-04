extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_GEAR_MORE_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
 var mode: String="more";var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact earlier genuine producer/output copied without alteration")
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false)
 check(QA.enter_game(w,"기사"),"actual Main/class picker");var owner: RefCounted=w.quest_item_provider.equipment_owner
 var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold;var hash: String=FileAccess.get_sha256(w.save_path())
 var ids: Array=[];var held: Array=[]
 if mode=="more":
  check(not owner.data.is_empty(),"small exact input present")
  check(w._save_game(true,{"equipped_items":w.equipped_items.duplicate(true)})==ERR_INVALID_PARAMETER and FileAccess.get_sha256(w.save_path())==hash,"world rejects unsealed equipment save overrides")
  # An explicitly synthetic legacy collision cannot confer native ownership.
  var target: String=""
  for uid: String in w.item_instances:
   if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==305 and w.item_instances[uid].has("quest_reward_receipt"):target=uid;break
  check(not target.is_empty(),"remaining genuine source cloak selected")
  var canonical: Dictionary=owner.profile(305,1);var fixture_id: String="qa_legacy_name_collision"
  var fixture: Dictionary={"name":str(canonical.name),"level":0,"element":"","element_level":0,"record":{"name":str(canonical.name),"source":"inven","sourceId":"qa:legacy_collision_only","slot":"cloak","type":"망토","grade":"일반"}}
  w.item_instances[fixture_id]=fixture.duplicate(true);w.inventory[canonical.name]=int(w.inventory.get(canonical.name,0))+1
  check(w._save_game(true)==OK,"controlled name-collision fixture saved only in this QA copy")
  var quote: Dictionary=owner.quote(w,target);check(quote.get("ok",false),"actual source quote with same-name synthetic legacy competitor")
  var result: Dictionary=owner.commit(w,quote);check(result.get("ok",false) and w.item_instances[fixture_id]==fixture and result.physical_id!=fixture_id and not w.item_instances.has(target),"selected source alone is debited; legacy competitor remains byte-identical")
  var before: String=FileAccess.get_sha256(w.save_path());w._on_inventory_item_activated(str(canonical.name));w._equip_or_acquire_item(canonical,false)
  check(FileAccess.get_sha256(w.save_path())==before and w.item_instances[fixture_id]==fixture,"name-only equip requests cannot select another physical object")
  for uid: String in w.item_instances.keys():
   var record: Dictionary=w.item_instances[uid].get("record",{})
   if owner.IDS.has(int(record.get("source_item_class_id",0))) and record.get("source_pending_use",false):held.append(uid)
  for uid: String in held:
   var input: Dictionary=w.item_instances[uid].duplicate(true);var item: int=int(input.record.source_item_class_id)
   var q: Dictionary=owner.quote(w,uid)
   if not q.get("ok",false):continue
   owner.cancel(q.token)
   var physical: Dictionary=w.item_instances.duplicate(true);var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(input.name)+"@@@"+uid)
   check(not bag.detail_action.disabled,"actual remaining source gear UI is usable")
   bag.detail_action.pressed.emit();var new_id: String=""
   for candidate: String in w.item_instances:
    if w.item_instances[candidate].get("quest_source_input_physical_id")==uid:new_id=candidate;break
   check(not new_id.is_empty() and not w.item_instances.has(uid) and owner._state_matches(w,new_id).get("ok",false),"actual remaining source unit/UUID/effect owner "+str(item))
   for old_id: String in physical:
    if old_id==uid:continue
    check(w.item_instances.get(old_id)==physical[old_id],"other owned physical bytes retained "+old_id)
   ids.append(item)
  check(w.item_instances[fixture_id]==fixture and int(w.inventory.get(canonical.name,0))==2,"same-name legacy quantity remains independent of actual source output")
 elif mode=="rune_ui":
  var uid: String="8023355db46215dffeafef8db866d8b6";var physical: Dictionary=w.item_instances[uid].duplicate(true);var mr: int=w._effective_mr();var xp: float=w._experience_multiplier();var def: int=w._effective_defense()
  var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(physical.name)+"@@@"+uid)
  check(not bag.detail_action.disabled and str(bag.detail_action.text).contains("해제"),"existing inventory UI retains its worn-item unequip action")
  bag.detail_action.pressed.emit()
  check(w.equipped_items.rune.is_empty() and w._effective_mr()==mr-5 and w._effective_defense()==def-1 and is_equal_approx(w._experience_multiplier(),xp-.03) and w.item_instances[uid]==physical,"actual UI atomic unequip removes exact1AC/5MR/3percent XP without consuming or rewriting rune")
  bag.set_character_state(w.hud.character_state);bag._select_item(str(physical.name)+"@@@"+uid);bag.detail_action.pressed.emit()
  check(w.equipped_items.rune.get("instance_id")==uid and w._effective_mr()==mr and w._effective_defense()==def and is_equal_approx(w._experience_multiplier(),xp) and w.item_instances[uid]==physical,"actual UI re-equip uses same real UUID and restores effects")
 elif mode=="missing":
  check(owner.data.is_empty(),"optional gear view genuinely absent")
  var life_hp: int=w.hp;w.hp=0
  check(str(owner.quote(w,"8023355db46215dffeafef8db866d8b6").get("reason","")).contains("생존 상태"),"dead actor cannot equip or gain HP through a gear transaction")
  w.hp=life_hp
  var inv: Dictionary=w.inventory.duplicate(true);var p: Dictionary=w.item_instances.duplicate(true);var equipped: Dictionary=w.equipped_items.duplicate(true)
  var uid: String="8023355db46215dffeafef8db866d8b6";w._unequip_item_reference(str(w.item_instances[uid].name)+"@@@"+uid)
  check(w.inventory==inv and w.item_instances==p and w.equipped_items==equipped and FileAccess.get_sha256(w.save_path())==hash,"absent input blocks new owner transactions while preserving source ownership/effects/save")
 elif mode=="uncertain":
  var uid: String="224";var inv: Dictionary=w.inventory.duplicate(true);var p: Dictionary=w.item_instances.duplicate(true);var equipped: Dictionary=w.equipped_items.duplicate(true)
  var snapshot: PackedByteArray=FileAccess.get_file_as_bytes(w.save_path());var backup:=FileAccess.open("/tmp/q262-r5/uncertain-original-save.json",FileAccess.WRITE);backup.store_buffer(snapshot);backup.close()
  w.equipment_collections.test_save_writer=func(path: String,_data: Dictionary)->Error:
   var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string("{");f.close();return ERR_FILE_CANT_WRITE
  var result: Dictionary=owner.commit(w,owner.quote(w,uid));w.equipment_collections.test_save_writer=Callable()
  check(not result.get("ok",false) and w.quest_service.save_blocked and w.inventory==inv and w.item_instances==p and w.equipped_items==equipped,"uncertain changed save blocks reuse without adopting an input debit or output")
  var corrupt: String=FileAccess.get_sha256(w.save_path());w._on_inventory_item_activated(str(w.item_instances[uid].name)+"@@@"+uid)
  check(FileAccess.get_sha256(w.save_path())==corrupt and w.inventory==inv and w.item_instances==p,"uncertain transaction cannot retry or regrant")
  w._load_game(true)
  check(w.equipment_collections.save_blocked and w.inventory==inv and w.item_instances==p,"corrupt reconnect is safely rejected without engine JSON error or ownership loss")
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.rng.state==rng and w.gold==gold,"claims50bindings and unrelated RNG/currency preserved")
 print("QUEST_EQUIPMENT_FOLLOWUP_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":mode,"actual_additional_equipped_item_ids":ids,"synthetic_legacy_collision_only":mode=="more","save_sha256":FileAccess.get_sha256(w.save_path()),"input_sha256":seed,"scope":"actual selected equipment transactions; no native enhancement/material recipe/whole-source completion"}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
