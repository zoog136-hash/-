extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const C=preload("res://scripts/quests/quest_reward_consumption.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
# Public QA labels supply two distinct valid digests. These are not consumer
# artifact identities or effect authorization; actual ownership stays source-validated.
var QA_CONSUMER_B: String="TWILIGHT_PUBLIC_QA_CONSUMER_B".sha256_text()
var QA_CONSUMER_A: String="TWILIGHT_PUBLIC_QA_CONSUMER_A".sha256_text()
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_CONSUMPTION_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func request(w: Node,id: String,q: int)->Dictionary:
 var p: Dictionary=w.item_instances[id]
 return {"physical_id":id,"quantity":q,"expected_quantity":int(p.source_reward_quantity),"expected_remaining":int(p.source_reward_quantity)-q,"quest_reward_receipt":p.quest_reward_receipt.duplicate(true)}
func adopt(w: Node,payload: Dictionary)->void:
 w.inventory=payload.inventory.duplicate(true);w.item_instances=payload.item_instances.duplicate(true);check(w.quest_service.import_state(payload.quest_state),"caller adopts only confirmed source ledger");w.deferred_save.cancel();w.quest_auto.refresh_context(w);w.hud.refresh_inventory(w.inventory);w._update_hud()
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for a: String in OS.get_cmdline_user_args():
  if a.begins_with("--seed-sha="):seed=a.trim_prefix("--seed-sha=")
 check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact protected existing producer copied before Main")
 if not failures.is_empty():quit(1);return
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual existing Main and class")
 var ids: Array=[]
 for id: String in w.item_instances:
  if int(w.item_instances[id].get("record",{}).get("source_item_class_id",0))==313 and int(w.item_instances[id].get("source_reward_quantity",0))>=2 and OWN.proof(w,id).get("ok",false):ids.append(id)
 check(ids.size()>=2,"two genuinely issued same-name original material receipts")
 if ids.size()<2:w.queue_free();await process_frame;quit(1);return
 var a: String=ids[0];var b: String=ids[1];var inv: Dictionary=w.inventory.duplicate(true);var objects: Dictionary=w.item_instances.duplicate(true);var source_state: Dictionary=w.quest_service.export_state();var hash: String=FileAccess.get_sha256(w.save_path());var rng: int=w.rng.state;var gold: int=w.gold;var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true)
 var requests: Array=[request(w,a,1),request(w,b,1)];var stage: Dictionary=C.stage(w,requests,QA_CONSUMER_A)
 check(stage.get("ok",false) and not stage.use_authorized and C.current(w,stage),"exact typed batch candidate is current but never effect-authorized")
 if not stage.get("ok",false):print("STAGE_ERROR "+str(stage.get("reason")));w.queue_free();await process_frame;quit(1);return
 var key: String=str(objects[a].name)
 check(int(stage.overrides.inventory[key])==int(inv[key])-2 and int(stage.overrides.item_instances[a].source_reward_quantity)==int(objects[a].source_reward_quantity)-1 and int(stage.overrides.item_instances[b].source_reward_quantity)==int(objects[b].source_reward_quantity)-1,"two selected physical debits share one accurate inventory sum")
 check(w.inventory==inv and w.item_instances==objects and w.quest_service.item_grants==source_state.get("item_grants",{}) and FileAccess.get_sha256(w.save_path())==hash,"staging does not mutate live ownership/ledger/save")
 for id: String in [a,b]:
  var p: Dictionary=objects[id];var receipt: Dictionary={}
  for row: Dictionary in stage.overrides.quest_state.item_grants[p.quest_reward_receipt.quest_id]:
   if int(row.reward_id)==int(p.quest_reward_receipt.reward_id):receipt=row
  check(int(receipt.used_quantity)==1 and int(receipt.quantity)==int(p.quest_reward_receipt.quantity) and receipt.pack_sha256==QA_CONSUMER_A,"each selected source receipt gets its own first use and immutable original amount")
  check(stage.overrides.item_instances[id].quest_reward_receipt==p.quest_reward_receipt,"immutable physical grant proof retained")
 var bad: Dictionary=requests[0].duplicate(true);bad.expected_quantity+=1;bad.expected_remaining+=1;check(not C.stage(w,[bad],QA_CONSUMER_A).ok,"changed expected remaining cannot select a newer quantity")
 bad=requests[0].duplicate(true);bad.quest_reward_receipt.reward_id+=1;check(not C.stage(w,[bad],QA_CONSUMER_A).ok,"wrong exact source receipt rejected")
 for q: Variant in [0,-1,1.5,"1"]:
  bad=requests[0].duplicate(true);bad.quantity=q;check(not C.stage(w,[bad],QA_CONSUMER_A).ok,"nonpositive/fractional/string debit is never coerced")
 check(not C.stage(w,[requests[0],requests[0]],QA_CONSUMER_A).ok,"same physical ID cannot be debited twice in one candidate")
 bad=stage.duplicate(true);bad.overrides.inventory["fake grant"]=1;check(not C.current(w,bad),"edited staged inventory rejected")
 bad=stage.duplicate(true);bad.use_authorized=true;check(not C.current(w,bad),"ownership proof cannot be relabelled as effect authorization")
 check(C.matches_payload(w,stage,stage.overrides),"unmodified shared payload validates against exact selected source sums")
 var merged: Dictionary=stage.overrides.duplicate(true);merged.quest_state=source_state.duplicate(true);check(not C.matches_payload(w,stage,merged),"blind merge of old quest ledger rejected")
 merged=stage.overrides.duplicate(true);merged.inventory=inv.duplicate(true);check(not C.matches_payload(w,stage,merged),"blind merge of original inventory over selected debits rejected")
 merged=stage.overrides.duplicate(true);merged.item_instances[b]=objects[b].duplicate(true);check(not C.matches_payload(w,stage,merged),"another selected quantity cannot be restored by full-candidate merge")
 merged=stage.overrides.duplicate(true);var other: String=ids[2] if ids.size()>2 else ""
 if not other.is_empty():merged.item_instances.erase(other);check(not C.matches_payload(w,stage,merged),"sorted-ID consumption of unselected quest receipt rejected")
 merged=stage.overrides.duplicate(true);merged.item_instances["bad-output"]=false;check(not C.matches_payload(w,stage,merged),"malformed physical output is refused without an engine cast error")
 var locks: Dictionary=w.ui_preferences.get("item_locks",{}).duplicate(true);w.ui_preferences.item_locks[key+"@@@"+a]=true;check(not C.current(w,stage),"new selection lock invalidates consumption quote");w.ui_preferences.item_locks=locks
 w.item_instances[a].source_reward_quantity-=1;w.inventory[key]-=1;check(not C.current(w,stage),"intervening selected-quantity change invalidates candidate");w.item_instances=objects.duplicate(true);w.inventory=inv.duplicate(true)
 w.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_FILE_CANT_WRITE
 check(C.matches_payload(w,stage,stage.overrides) and w._save_game(true,stage.overrides)!=OK,"caller save failure refuses whole debit/ledger candidate");w.equipment_collections.test_save_writer=Callable()
 check(w.inventory==inv and w.item_instances==objects and w.quest_service.item_grants==source_state.get("item_grants",{}) and FileAccess.get_sha256(w.save_path())==hash,"failed save preserves real material, all grant receipts and previous bytes")
 check(C.matches_payload(w,stage,stage.overrides) and w._save_game(true,stage.overrides)==OK,"caller writes physical remainder/inventory/used ledger in one candidate")
 adopt(w,stage.overrides)
 check(not C.current(w,stage),"successful candidate cannot be replayed")
 var second: Dictionary=C.stage(w,[request(w,a,1)],QA_CONSUMER_B);check(second.get("ok",false),"a second public QA consumer digest can stage an actually remaining unit")
 if second.get("ok",false):
  check(second.selections[0].first_consumer_pack_sha256==QA_CONSUMER_A and second.selections[0].consumer_data_sha256==QA_CONSUMER_B,"first consumer proof retained without pretending a different artifact was the original")
  check(int(second.selections[0].original_quantity)==int(objects[a].quest_reward_receipt.quantity),"cross-owner original grant amount is immutable")
  check(C.matches_payload(w,second,second.overrides) and w._save_game(true,second.overrides)==OK,"second selected use commits once");adopt(w,second.overrides)
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));hash=FileAccess.get_sha256(w.save_path())
 for id: String in objects:
  if id not in [a,b]:check(w.item_instances.get(id)==objects[id],"unselected same-name/native/legacy objects remain unchanged")
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots) and w.gold==gold and w.rng.state==rng,"staging and ownership-layer QA preserve claims50slots/currency/RNG")
 w.queue_free();await process_frame;w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main reconnect")
 check(norm(w.item_instances)==saved.item_instances and norm(w.inventory)==saved.inventory and norm(w.quest_service.item_grants)==saved.quest_state.item_grants and FileAccess.get_sha256(w.save_path())==hash,"physical remainder, sum and each used_quantity reconnect together")
 print("QUEST_CONSUMPTION_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"actual quest-produced ownership and shared-ledger contract; batch save is QA ownership layer, not a claimed265 processing effect","selected_item_class":313,"actual_selected_physical_ids":[a,b],"final_save_sha256":hash}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
