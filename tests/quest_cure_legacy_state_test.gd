extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_CURE_LEGACY_FAIL "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact actual pre-cure R12 native-use saved state")
 if not failures.is_empty():quit(1);return
 var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://twilight_v20_save.json"))
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/current source map")
 check(old.consumable_state.has("source_reusable_item_uses") and norm(w.consumable_service.export_state())==old.consumable_state,"old successful-use proofs/counters and unknown extensions survive new optional cure namespace")
 check(norm(w.inventory)==old.inventory and norm(w.item_instances)==old.item_instances and w.quickslots.size()==50 and FileAccess.get_sha256(w.save_path())==seed,"no legacy ownership conversion/regrant/slot deletion/save migration")
 print("QUEST_CURE_LEGACY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"old_reusable_namespace_preserved":true,"input_save_bytes_unchanged":FileAccess.get_sha256(w.save_path())==seed}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
