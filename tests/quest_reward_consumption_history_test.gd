extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const C=preload("res://scripts/quests/quest_reward_consumption.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
var checks: int=0
var failures: Array[String]=[]
class Missing extends Node:
 var quest_service: Dictionary={}
 var inventory: Dictionary={}
 var item_instances: Dictionary={}
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_CONSUMPTION_HISTORY_FAIL "+label)
func req(w: Node,id: String)->Dictionary:
 var p: Dictionary=w.item_instances[id]
 return {"physical_id":id,"quantity":1,"expected_quantity":int(p.source_reward_quantity),"expected_remaining":int(p.source_reward_quantity)-1,"quest_reward_receipt":p.quest_reward_receipt.duplicate(true)}
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact previously validated partially consumed source save")
 if not failures.is_empty():quit(1);return
 var missing:=Missing.new();check(not C.available(missing) and not C.stage(missing,[{}],PIN).get("ok",false) and not C.current(missing,{"kind":C.KIND}),"older/missing owner shape refuses safely without property or method errors");missing.free()
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main partial-use restore")
 var id: String=""
 for uid: String in w.item_instances:
  var p: Dictionary=w.item_instances[uid]
  if int(p.get("record",{}).get("source_item_class_id",0))!=313 or int(p.get("source_reward_quantity",0))<1:continue
  var owned: Dictionary=OWN.proof(w,uid)
  if not owned.get("ok",false):continue
  for row: Dictionary in w.quest_service.item_grants.get(owned.quest_id,[]):
   if int(row.reward_id)==int(owned.reward_id):id=uid;break
  if not id.is_empty():break
 check(not id.is_empty(),"actual retained material has earlier partial-use receipt")
 if id.is_empty():w.queue_free();await process_frame;quit(1);return
 var p: Dictionary=w.item_instances[id].duplicate(true);var qid: String=p.quest_reward_receipt.quest_id;var idx: int=-1
 for i: int in range(w.quest_service.item_grants[qid].size()):
  if int(w.quest_service.item_grants[qid][i].reward_id)==int(p.quest_reward_receipt.reward_id):idx=i;break
 var original: Dictionary=w.quest_service.item_grants[qid][idx].duplicate(true);var hash: String=FileAccess.get_sha256(w.save_path());var requests: Array=[req(w,id)]
 check(C.stage(w,requests,PIN).get("ok",false),"exact historical proof remains usable by another compatible owner")
 for field: String in ["item_class_id","bless_raw","used_quantity","quantity"]:
  w.quest_service.item_grants[qid][idx]=original.duplicate(true);w.quest_service.item_grants[qid][idx][field]=int(original[field])+1
  check(not C.stage(w,requests,PIN).get("ok",false),"corrupt historical "+field+" cannot be relabelled or repaired by consuming")
 w.quest_service.item_grants[qid][idx]=original.duplicate(true);w.quest_service.item_grants[qid][idx].future_note={"ratio":.125,"label":"preserve_unknown_receipt_metadata"}
 var stage: Dictionary=C.stage(w,requests,PIN);check(stage.get("ok",false) and C.matches_payload(w,stage,stage.overrides),"valid unknown receipt metadata is preserved without widening authority")
 if stage.get("ok",false):
  var preserved: Dictionary={}
  for row: Dictionary in stage.overrides.quest_state.item_grants[qid]:
   if int(row.reward_id)==int(original.reward_id):preserved=row
  check(preserved.future_note.ratio==.125 and preserved.quantity==original.quantity and preserved.pack_sha256==original.pack_sha256,"unknown metadata, immutable grant amount and first proof survive candidate construction")
 w.quest_service.item_grants[qid][idx]=original.duplicate(true)
 check(FileAccess.get_sha256(w.save_path())==hash and w.item_instances[id]==p,"history diagnostics do not write a save or mutate actual owned quantity")
 print("QUEST_CONSUMPTION_HISTORY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"actual partial-source historical identity refusals and nonmutating metadata preservation","save_unchanged":FileAccess.get_sha256(w.save_path())==hash}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
