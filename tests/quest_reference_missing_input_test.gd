extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const REF=preload("res://scripts/quests/quest_reference_learning.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("REFERENCE_MISSING_INPUT_FAIL: "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func _initialize()->void:call_deferred("run")
func run()->void:
 var expected: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed-sha="):expected=arg.trim_prefix("--seed-sha=")
 var hash: String=FileAccess.get_sha256("user://twilight_v20_save.json")
 check(expected.length()==64 and hash==expected,"exact real held-learning output copied unchanged")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://twilight_v20_save.json"))
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false)
 check(QA.enter_game(w,"마법사") and not w.quest_item_provider.ready and w.quest_item_provider.skill_books.active_sha256.is_empty(),"cold Main has neither optional item nor skill evidence pack")
 check(norm(w.inventory)==saved.inventory and norm(w.item_instances)==saved.item_instances and norm(w.quickslots)==saved.quickslots,"missing inputs preserve exact ownership and50bindings")
 for row: Dictionary in REF.MAP.values():
  var skill: Dictionary=w.original_skills.catalog.record_for(row.key)
  check(int(w.original_skills.catalog.learned.get(row.key,0))==1 and not w.original_skills.catalog.source_learning_status(skill).is_empty(),"native knowledge persists without private input")
  check(not w.original_skills.ready(skill) and not w._cast_job_skill(row.key) and not w._quickslot_registration_error("skill",row.key).is_empty(),"cold source execution/registration stays closed")
 w.hud.open_skills();await process_frame;await RenderingServer.frame_post_draw
 var ui: Node=w.hud.skills_view
 for row: Dictionary in REF.MAP.values():
  var index: int=-1
  for i: int in range(ui.filtered.size()):
   if ui.filtered[i].id==row.key:index=i;break
  check(index>=0,"learned exact source reference visible without optional pack")
  if index>=0:
   ui.select(index);ui._process(.5)
   check(str(ui.detail.text).contains("원본 학습 완료") and ui.use_button.disabled and ui.quick_button.disabled,"cold UI does not call recorded source knowledge unlearned/castable")
 var raw_hints: int=0
 for id: String in w.item_instances:
  var item: Dictionary=w.item_instances[id];var record: Dictionary=item.get("record",{})
  if int(record.get("source_item_class_id",0)) not in [177342,177432]:continue
  var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory;bag._select_item(str(item.name)+"@@@"+id)
  check(bag.detail_action.text=="학습 기록" and str(bag.detail_action.tooltip_text).contains("실행은 보류"),"actual remaining raw book UI states learning-only scope before consumption")
  w._on_inventory_item_activated(str(item.name)+"@@@"+id);raw_hints+=1
 check(raw_hints==2,"both genuine unspent duplicate raw books retained")
 var stripped: Dictionary=saved.original_skill_state.duplicate(true);stripped.erase("source_quest_knowledge")
 check(REF.restore(stripped,saved).size()==4,"source learning receipts recover execution holds if presentation metadata absent")
 check(REF.restore({"learned":{"lmref_64f77fcd9c52a02b":1}},{"consumable_state":{}}).is_empty(),"prior local knowledge without new source provenance is not converted")
 check(FileAccess.get_sha256(w.save_path())==hash and norm(w.inventory)==saved.inventory and norm(w.item_instances)==saved.item_instances and norm(w.quest_service.export_state())==saved.quest_state,"all blocked actions and UI leave actual save/progression/owned remainders unchanged")
 print("REFERENCE_MISSING_INPUT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_save_sha256":hash,"knowledge_held":4,"unspent_raw_duplicates":raw_hints,"native_execution_completed":false}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
