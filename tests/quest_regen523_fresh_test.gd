extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_REGEN_FRESH_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
 check(OS.get_cmdline_user_args().has("--fresh-qa") and OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/q262-r8-") and not FileAccess.file_exists("user://twilight_v20_save.json"),"explicit empty isolated QA profile before actual Main")
 if not failures.is_empty():quit(1);return
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"마법사"),"actual new-character Mage class UI")
 # Explicit eligibility fixture, not naturally earned XP/progression probability.
 w.level=86;check(w._save_game(true)==OK,"controlled level86 eligibility saved only in this empty QA profile")
 for step: int in range(100):
  w.quest_auto.last_signature="";w.quest_auto.next_scan=0;w.quest_auto.tick(w)
  if w.quest_service.save_blocked or w.quest_auto.retry_at>Time.get_unix_time_from_system():break
 var native: Dictionary={}
 for iid: int in [376,385]:
  var rec: Dictionary=D.variant_item(D.definition_id(str(iid)).native_record,1);var key: String=str(rec.name);var receipts: Array=[]
  for qid: String in w.quest_service.item_grants:
   for r: Dictionary in w.quest_service.item_grants[qid]:
    if int(r.get("item_class_id",0))==iid and not r.has("origin"):receipts.append({"quest_id":qid,"receipt":r.duplicate(true)})
  check(not receipts.is_empty() and int(w.inventory.get(key,0))>0,"actual original quest auto-completion issues exact native identity with saved source receipt")
  native[str(iid)]={"key":key,"record":rec,"receipts":receipts,"issued":int(w.inventory.get(key,0))}
 if not failures.is_empty():print("FRESH_BLOCK "+JSON.stringify({"provider_ids":w.quest_item_provider.definition_ids(),"auto_failures":w.quest_auto.failures,"native":native}));w.queue_free();await process_frame;quit(1);return
 var claims: Dictionary=w.quest_service.claimed.duplicate(true);var ledger: Dictionary=w.quest_service.item_grants.duplicate(true);var slots: Array=w.quickslots.duplicate(true);var rng: int=w.rng.state;var gold: int=w.gold
 for iid: int in [385,376]:
  var row: Dictionary=native[str(iid)];var key: String=row.key;var before: int=int(w.inventory[key]);var hash: String=FileAccess.get_sha256(w.save_path())
  w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
  w.quest_item_provider.try_use_inventory(w,key);w.equipment_collections.test_save_writer=Callable()
  check(int(w.inventory[key])==before and FileAccess.get_sha256(w.save_path())==hash and not w.active_item_buffs.has(key),"real newly issued native use/save failure preserves quantity and effect")
  var bag: Variant=w.hud.lineage_inventory_ui;bag.inventory=w.inventory;bag.set_character_state(w.hud.character_state);bag._select_item(key);check(not bag.detail_action.disabled,"real newly issued native reward inventory action")
  bag.detail_action.pressed.emit()
  check(int(w.inventory[key])==before-1 and int(w.active_item_buffs.get(key,{}).get("mp_regen_tick",0))==(2 if iid==376 else 3),"actual new quest native issue -> UI use -> one debit and original regeneration amount")
  var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));check(durable.inventory==norm(w.inventory) and durable.active_item_buffs==norm(w.active_item_buffs) and durable.quest_state.item_grants==norm(ledger),"new native partial quantity/effect/source-grant receipt persist together")
  var qid: String=row.receipts[0].quest_id;var before_claim: String=FileAccess.get_sha256(w.save_path());check(not w.quest_auto.complete(w,[qid]) and int(w.inventory[key])==before-1 and FileAccess.get_sha256(w.save_path())==before_claim,"already completed producer cannot issue the same reward again")
 check(w.quest_service.claimed==claims and w.quest_service.item_grants==ledger and norm(w.quickslots)==norm(slots) and w.rng.state==rng and w.gold==gold,"native consumer preserves immutable producer receipts/claims50bindings/currency/RNG")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));var final_hash: String=FileAccess.get_sha256(w.save_path());var count: int=0
 for id: String in w.quest_service.claimed:
  if id.begins_with("m523:quest:"):count+=1
 w.queue_free();await process_frame;w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"마법사"),"fresh actual Main reconnect")
 check(norm(w.inventory)==saved.inventory and norm(w.active_item_buffs)==saved.active_item_buffs and norm(w.quest_service.item_grants)==saved.quest_state.item_grants and FileAccess.get_sha256(w.save_path())==final_hash,"actual new producer/native-use partial ownership/effect/receipt reconnect")
 print("QUEST_REGEN_FRESH_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_completions_in_controlled_new_Mage_profile":count,"actual_item_classes":[376,385],"controlled_level86_not_natural_xp_or_encounter_probability":true,"issued_native_quantities":{"376":native["376"].issued,"385":native["385"].issued},"final_save_sha256":final_hash}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
