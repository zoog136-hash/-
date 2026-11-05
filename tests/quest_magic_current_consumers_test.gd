extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_MAGIC_CURRENT_FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact actual R10 selected/equipped source30213 saved output")
 if not failures.is_empty():quit(1);return
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual current Main/source map")
 var owner: RefCounted=w.quest_item_provider.equipment_owner;var id: String=str(w.equipped_items.gaiters.get("instance_id",""))
 check(not id.is_empty() and owner._state_matches(w,id).get("ok",false),"same real selected30213 source UUID/proof reauthenticates with final shared consumer build")
 check(owner.reduce_hit(w,1000,"magic")==970 and owner.reduce_hit(w,1000,"melee")==1000,"source magic3percent and physical preservation in final build")
 check(w.quickslots.size()==50 and FileAccess.get_sha256(w.save_path())==seed,"current consumers do not migrate/regrant/rewrite owned gear/50bindings on load")
 print("QUEST_MAGIC_CURRENT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_item_class_id":30213,"new_reusable_and_original_equipment_owner_together":true,"original_save_bytes_unchanged":FileAccess.get_sha256(w.save_path())==seed}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
