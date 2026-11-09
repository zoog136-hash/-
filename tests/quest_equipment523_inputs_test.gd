extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_EQUIPMENT_INPUT_FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 check(seed.length()==64 and FileAccess.file_exists("user://twilight_v20_save.json") and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"exact caller-selected QA save before Main creation")
 if not failures.is_empty():quit(1);return
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false)
 check(QA.enter_game(w,"기사"),"actual Main/source character")
 var hash: String=FileAccess.get_sha256(w.save_path());var inv: Dictionary=w.inventory.duplicate(true);var physical: Dictionary=w.item_instances.duplicate(true);var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true)
 check(w.quest_item_provider.definition_count()==22 and w.quest_item_provider.skill_books.active_sha256=="256f0ba0944e05b86134b40ed3aea97c71e1073b3947ea6e46cb018b6179926a","all22 prior reviewed native supplier definitions coexist with exact skill v3")
 check(not w.quest_item_provider.equipment_owner.data.is_empty(),"exact36KB gear view coexists with source item and skill inputs")
 var q: Dictionary=w.quest_item_provider.equipment_owner.quote(w,"91")
 check(q.get("ok",false),"genuine source240 selected candidate with combined optional inputs")
 if q.get("ok",false):w.quest_item_provider.equipment_owner.cancel(q.token)
 var book_id: String=""
 for uid: String in w.item_instances:
  if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==177232:book_id=uid;break
 check(not book_id.is_empty(),"actual source spell book remains owned")
 if not book_id.is_empty():check(not w.quest_item_provider.skill_books.use(w,D.variant_item(D.definition_id("177232").native_record,1),book_id).get("ok",false),"combined gear registration does not waive Knight native book-learning restriction")
 var hp: int=w.hp;w.hp=0
 check(str(w.quest_item_provider.equipment_owner.quote(w,"91").get("reason","")).contains("생존 상태"),"dead actor cannot acquire HP by equipping")
 w.hp=hp
 check(w.inventory==inv and w.item_instances==physical and w.quest_service.claimed==claims and w.quickslots==slots and FileAccess.get_sha256(w.save_path())==hash,"combined registration/quotes/denials preserve original ownership,claims,50bindings and save bytes")
 print("QUEST_EQUIPMENT_INPUT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_completions":811,"supplier_definitions":w.quest_item_provider.definition_count(),"save_sha256":hash,"scope":"combined optional input and original constraint smoke, not all consumer transactions or whole catalogue registration"}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
