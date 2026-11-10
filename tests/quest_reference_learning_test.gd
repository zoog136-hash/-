extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const REF=preload("res://scripts/quests/quest_reference_learning.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const CATALOG=preload("res://scripts/skills/skill_catalog.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("QUEST_REFERENCE_LEARN_FAIL: "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func make_world(job: String="기사")->TwilightWorld:
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false)
 check(QA.enter_game(w,job),"actual saved class selection "+job);return w
func input_for(w: TwilightWorld,id: int,fresh: bool)->Dictionary:
 var record: Dictionary=D.variant_item(D.definition_id(str(id)).native_record,1)
 if fresh:return {"id":"","key":record.name,"record":record}
 for uid: String in w.item_instances:
  if int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))==id:return {"id":uid,"key":w.item_instances[uid].name,"record":record}
 return {}
func activate(w: TwilightWorld,input: Dictionary)->void:
 if int(w.inventory.get(str(input.key),0))>0:
  var bag: Variant=w.hud.lineage_inventory_ui;bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory
  bag._select_item(str(input.key)+("@@@"+str(input.id) if not str(input.id).is_empty() else ""))
  check(not bag.detail_action.disabled,"real source book inventory button enabled")
  if REF.MAP.has(int(input.record.get("source_item_class_id",0))):check(bag.detail_action.text=="학습 기록" and str(bag.detail_action.tooltip_text).contains("실행은 보류"),"before-consumption UI clearly states learning-only scope")
  bag.detail_action.pressed.emit()
 else:w._on_inventory_item_activated(str(input.key))
func assert_no_execution(w: TwilightWorld,key: String)->void:
 var row: Dictionary=w.original_skills.catalog.record_for(key)
 var hp: int=w.hp;var mp: int=w.mp;var rng: int=w.rng.state;var buffs: Dictionary=w.active_skill_buffs.duplicate(true);var cooldowns: Dictionary=w.skill_cooldowns.duplicate(true);var hash: String=FileAccess.get_sha256(w.save_path())
 check(not w.original_skills.catalog.source_learning_status(row).is_empty() and int(w.original_skills.catalog.learned.get(key,0))==1,"source knowledge owned separately from execution "+key)
 check(not w.original_skills.catalog.enabled(row) and not w.original_skills.ready(row) and not w.original_skills.cast(row) and not w._cast_job_skill(key),"existing direct/world execution paths stay closed "+key)
 check(not w._quickslot_registration_error("skill",key).is_empty() and not w._quickslot_registration_error("skill_auto",key).is_empty(),"manual and automatic quickslot registration stay closed")
 check(w.hp==hp and w.mp==mp and w.rng.state==rng and w.active_skill_buffs==buffs and w.skill_cooldowns==cooldowns and FileAccess.get_sha256(w.save_path())==hash,"blocked cast spends no resources/effect/RNG/save")
func _initialize()->void:call_deferred("run")
func run()->void:
 var fresh: bool=false;var seed: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--quest-pack="):fresh=true;check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged questv1 installer")
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
 if not fresh:
  check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"unmodified actual811 source-issued save copy")
  if not failures.is_empty():quit(1);return
 var w: TwilightWorld=make_world()
 if fresh:
  for batch: int in range(100):
   w.quest_auto.retry_at=0;w.quest_auto.next_scan=0
   var before: int=w.quest_service.claimed.size();w.quest_auto.tick(w)
   if before==w.quest_service.claimed.size():break
 var reader: RefCounted=w.quest_item_provider.skill_books
 var inputs: Dictionary={}
 var inventory: Dictionary=w.inventory.duplicate(true);var hash: String=FileAccess.get_sha256(w.save_path())
 for item: int in REF.MAP:
  check(w.quest_item_provider.has_definition(item),"exact reference book learning supplier registered "+str(item))
  inputs[item]=input_for(w,item,fresh);check(not inputs[item].is_empty(),"genuine source quest reward input "+str(item))
  if not fresh:check(OWN.proof(w,inputs[item].id).ok,"actual physical quest receipt proof")
  activate(w,inputs[item])
 check(w.inventory==inventory and w.original_skills.catalog.source_quest_knowledge.is_empty() and FileAccess.get_sha256(w.save_path())==hash,"Knight original SpellLearnLimit denies all four without consumption")
 check(QA.enter_game(w,"마법사"),"normal class picker selects source-eligible Mage")
 if fresh:
  for i: int in range(50):w.quickslots[i]={"kind":"item","id":"HP 물약"} if i%3==0 else {}
  w.ui_preferences.edited_quickslots[w.job_class]=true
 var claims: Dictionary=w.quest_service.claimed.duplicate(true);var slots: Array=w.quickslots.duplicate(true)
 var current_record: Dictionary=w.original_skills.catalog.record_for("lmref_64f77fcd9c52a02b")
 var before_knowledge: Variant=w.original_skills.catalog.learned.get(current_record.id,null)
 w.original_skills.catalog.learned[current_record.id]=1
 check(w.original_skills.catalog.enabled(current_record) and w.original_skills.catalog.source_learning_status(current_record).is_empty(),"controlled prior local learning stays executable without a new source hold")
 hash=FileAccess.get_sha256(w.save_path());activate(w,inputs[177432])
 check(w.inventory==inventory and w.original_skills.catalog.source_quest_knowledge.is_empty() and FileAccess.get_sha256(w.save_path())==hash,"controlled preexisting local knowledge preserves book and is not converted into a new execution hold")
 if before_knowledge==null:w.original_skills.catalog.learned.erase(current_record.id)
 else:w.original_skills.catalog.learned[current_record.id]=before_knowledge
 check(w._save_game(true)==OK,"eligible actual class baseline saved")
 hash=FileAccess.get_sha256(w.save_path())
 var selected: Dictionary=inputs[177432];var key: String=REF.MAP[177432].key
 var quantity: int=int(w.inventory[selected.key]);var instances: Dictionary=w.item_instances.duplicate(true)
 var learned: Dictionary=w.original_skills.catalog.export_state();var consumables: Dictionary=w.consumable_service.export_state()
 var lock: String=str(selected.key)+("@@@"+str(selected.id) if not str(selected.id).is_empty() else "")
 w.ui_preferences.item_locks[lock]=true;activate(w,selected);w.ui_preferences.item_locks.erase(lock)
 check(w.inventory==inventory and FileAccess.get_sha256(w.save_path())==hash,"actual book lock preserved")
 var level: int=w.level;w.level=0;activate(w,selected);w.level=level
 check(w.inventory==inventory and FileAccess.get_sha256(w.save_path())==hash,"native learning minimum level remains distinct from later casting conditions")
 var invalid: Dictionary=selected.record.duplicate(true);invalid.source_use_spec.source_spell_row_sha256="0".repeat(64)
 check(not reader.use(w,invalid,selected.id).ok and w.inventory==inventory,"wrong source learning row proof cannot consume")
 w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
 activate(w,selected)
 check(w.inventory==inventory and w.item_instances==instances and w.original_skills.catalog.export_state()==learned and w.consumable_service.export_state()==consumables and FileAccess.get_sha256(w.save_path())==hash,"failed save retains item/knowledge/execution hold/receipt together")
 w.equipment_collections.test_save_writer=func(p: String,data: Dictionary)->Error:
  var error: Error=WRITER.write(p,data)
  return ERR_FILE_CANT_WRITE if error==OK else error
 activate(w,selected);w.equipment_collections.test_save_writer=Callable()
 check(int(w.inventory.get(selected.key,0))==quantity-1 and int(w.original_skills.catalog.learned.get(key,0))==1 and not w.quest_service.save_blocked,"write then error confirms exactly one actual book and original learning record")
 var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
 check(durable.original_skill_state==norm(w.original_skills.catalog.export_state()) and durable.consumable_state==norm(w.consumable_service.export_state()),"knowledge and execution-pending proof stored in same durable transaction")
 var receipts: Array=durable.consumable_state.source_skill_book_receipts
 check(receipts.size()==1 and receipts[0].source_learning_record.execution_status=="blocked_until_verified_owner" and int(receipts[0].source_learning_record.spell_class_id)==70,"native learning proof explicitly does not grant native execution")
 if not fresh:check(receipts[0].input.quest_receipt==norm(instances[selected.id].quest_reward_receipt) and int(receipts[0].input.original_quantity)==1,"actual immutable source input proof retained")
 assert_no_execution(w,key)
 for item: int in [177292,177322,177342]:
  activate(w,inputs[item]);var learned_key: String=REF.MAP[item].key
  check(int(w.original_skills.catalog.learned.get(learned_key,0))==1,"real original learning succeeds independently of later source cast/effect hold "+str(item))
  assert_no_execution(w,learned_key)
 # Remaining genuine duplicates are preserved; no re-learning or forced cast.
 inventory=w.inventory.duplicate(true);hash=FileAccess.get_sha256(w.save_path())
 for item: int in [177342,177432]:
  var duplicate: Dictionary=input_for(w,item,fresh)
  if not duplicate.is_empty():activate(w,duplicate)
 check(w.inventory==inventory and FileAccess.get_sha256(w.save_path())==hash and w.consumable_service.export_state().source_skill_book_receipts.size()==4,"already learned source duplicates preserved without new grant/receipt")
 # Existing executable book path remains independent.
 var normal: Dictionary=input_for(w,177232,fresh);activate(w,normal)
 check(int(w.original_skills.catalog.learned.get("lm_1ec7e7edbce9ac29",0))==1 and w.original_skills.catalog.enabled(w.original_skills.catalog.record_for("lm_1ec7e7edbce9ac29")),"ordinary existing learning remains executable and has no source-reference hold")
 w.hud.open_skills();await process_frame;await RenderingServer.frame_post_draw
 var ui: Node=w.hud.skills_view
 for item: int in REF.MAP:
  var skill_key: String=REF.MAP[item].key;var index: int=-1
  for i: int in range(ui.filtered.size()):
   if ui.filtered[i].get("id")==skill_key:index=i;break
  check(index>=0,"current Mage UI exposes exact learned source identity even when legacy presentation class differs "+skill_key)
  if index<0:continue
  ui.select(index);ui._process(.5)
  check(str(ui.detail.text).contains("원본 학습 완료") and str(ui.cooldown.text).contains("실행 대기") and ui.use_button.disabled and ui.quick_button.disabled and ui.learn_button.disabled and ui.book_button.disabled,"persistent UI distinguishes source knowledge from blocked execution")
  check(str(ui.cards.get_item_tooltip(index)).contains("원본 학습"),"source knowledge icon status is not labelled unlearned")
 # Unknown metadata survives; it cannot release the execution hold.
 w.original_skills.catalog.source_quest_knowledge[key]["future_annotation"]={"ratio":.125,"execution_allowed":true}
 check(w._save_game(true)==OK,"full source knowledge snapshot saved with future non-executing annotation")
 assert_no_execution(w,key)
 durable=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()));hash=FileAccess.get_sha256(w.save_path())
 check(w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots),"learning and source holds preserve claims and all50 current user bindings")
 w.queue_free();await process_frame;w=make_world("마법사")
 check(norm(w.inventory)==durable.inventory and norm(w.item_instances)==durable.item_instances and norm(w.original_skills.catalog.export_state())==durable.original_skill_state and norm(w.consumable_service.export_state())==durable.consumable_state,"fresh Main restores exact input remainder/learning/hold/receipt states")
 check(w.original_skills.catalog.source_quest_knowledge[key].future_annotation.ratio==.125 and w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots),"future metadata,claims and50bindings survive without activating a cast")
 for item: int in REF.MAP:assert_no_execution(w,REF.MAP[item].key)
 w.quest_auto.refresh_context(w);var completed: int=0;var pending: int=0
 for entry: Dictionary in w.quest_service.entries(w.level,w.inventory):
  if entry.get("source_id")!=null and entry.completed:
   completed+=1
   if not entry.rewards.get("pending_use",[]).is_empty():pending+=1
 print("QUEST_REFERENCE_LEARNING_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":"real_native_reference_books" if fresh else "real_held_reference_books","learned_source_spell_ids":[347,358,1133,70],"native_spell_execution_completed":false,"all_four_execution_holds_persist":true,"source_completions":completed,"some_use_pending":pending,"already_known_or_duplicate_books_preserved":true,"final_save_sha256":FileAccess.get_sha256(w.save_path()),"input_seed_sha256":seed}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
