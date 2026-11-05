extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const C=preload("res://scripts/quests/quest_reward_consumption.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_CONSUMPTION_ZERO_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact real partial-use ownership save copied before Main")
 if not failures.is_empty():quit(1);return
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/class")
 var id: String="10";var owned: Dictionary=OWN.proof(w,id);check(owned.get("ok",false) and int(owned.quantity)>0,"actual previously partially consumed material remains owned")
 if not owned.get("ok",false):w.queue_free();await process_frame;quit(1);return
 var physical: Dictionary=w.item_instances[id].duplicate(true);var all_objects: Dictionary=w.item_instances.duplicate(true);var inv: Dictionary=w.inventory.duplicate(true);var hash: String=FileAccess.get_sha256(w.save_path())
 var request: Dictionary={"physical_id":id,"quantity":int(owned.quantity),"expected_quantity":int(owned.quantity),"expected_remaining":0,"quest_reward_receipt":physical.quest_reward_receipt.duplicate(true)}
 var stage: Dictionary=C.stage(w,[request],PIN);check(stage.get("ok",false) and C.matches_payload(w,stage,stage.overrides),"exact full-remainder candidate validates")
 if not stage.get("ok",false):w.queue_free();await process_frame;quit(1);return
 check(not stage.overrides.item_instances.has(id) and int(stage.overrides.inventory[owned.inventory_key])==int(inv[owned.inventory_key])-int(owned.quantity),"zero remainder erases exactly one physical ID while preserving other same-name quantity")
 var receipt: Dictionary={}
 for row: Dictionary in stage.overrides.quest_state.item_grants[owned.quest_id]:
  if int(row.reward_id)==int(owned.reward_id):receipt=row
 check(int(receipt.used_quantity)==int(physical.quest_reward_receipt.quantity) and receipt.quantity==physical.quest_reward_receipt.quantity,"fully consumed ledger reaches immutable original quantity without editing it")
 var bad: Dictionary=stage.overrides.duplicate(true);bad.item_instances[id]=physical.duplicate(true);check(not C.matches_payload(w,stage,bad),"erased source ID cannot be resurrected inside an output candidate")
 w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
 check(w._save_game(true,stage.overrides)!=OK,"failed zero-remainder save refused");w.equipment_collections.test_save_writer=Callable()
 check(w.inventory==inv and w.item_instances==all_objects and FileAccess.get_sha256(w.save_path())==hash,"failed full consumption preserves all old quantity and save bytes")
 check(C.matches_payload(w,stage,stage.overrides) and w._save_game(true,stage.overrides)==OK,"full consumption and exact ledger saved once")
 w.inventory=stage.overrides.inventory;w.item_instances=stage.overrides.item_instances;check(w.quest_service.import_state(stage.overrides.quest_state),"confirmed full receipt adopted");w.deferred_save.cancel()
 for uid: String in all_objects:
  if uid!=id:check(w.item_instances.get(uid)==all_objects[uid],"all unselected material and legacy/native objects unchanged")
 check(not C.current(w,stage) and not OWN.proof(w,id).get("ok",false),"fully consumed source cannot be replayed or used again")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));hash=FileAccess.get_sha256(w.save_path());w.queue_free();await process_frame
 w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main reconnect")
 check(not w.item_instances.has(id) and norm(w.inventory)==saved.inventory and norm(w.quest_service.item_grants)==saved.quest_state.item_grants and FileAccess.get_sha256(w.save_path())==hash,"zero physical remainder/aggregate/fully used receipt reconnect together")
 print("QUEST_CONSUMPTION_ZERO_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"actual quest-produced full-remainder ownership-layer transaction; no265 processing effect claimed","final_save_sha256":hash}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
