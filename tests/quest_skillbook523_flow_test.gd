extends SceneTree
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const BOOK=preload("res://scripts/quests/quest_skillbooks523.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("QUEST_SKILLBOOK_FAIL: "+label)
func norm(v: Variant)->Variant:return JSON.parse_string(JSON.stringify(v))
func make_world(job: String="기사")->TwilightWorld:
 var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w)
 w.set_process(false);w.player.set_physics_process(false)
 check(QA.enter_game(w,job),"actual Main class picker "+job)
 return w
func owned(w: TwilightWorld,item: int,fresh: bool)->Dictionary:
 if fresh:
  var record: Dictionary=D.variant_item(D.definition_id(str(item)).native_record,1)
  return {"key":str(record.name),"id":"","record":record}
 for uid: String in w.item_instances:
  var p: Dictionary=w.item_instances[uid]
  if int(p.get("record",{}).get("source_item_class_id",0))==item:return {"key":str(p.name),"id":uid,"record":D.variant_item(D.definition_id(str(item)).native_record,1)}
 return {}
func activate(w: TwilightWorld,input: Dictionary)->void:
 if not str(input.id).is_empty() and w.item_instances.has(str(input.id)):
  var bag: Variant=w.hud.lineage_inventory_ui
  bag.set_character_state(w.hud.character_state);bag.inventory=w.inventory
  bag._select_item(str(input.key)+"@@@"+str(input.id))
  check(not bag.detail_action.disabled,"actual selected physical book UI action enabled")
  bag.detail_action.pressed.emit()
 else:w._on_inventory_item_activated(str(input.key))
func _initialize()->void:call_deferred("run")
func run()->void:
 var fresh: bool=false;var seed: String="";var skill_path: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--player-skills523-pack="):skill_path=arg.trim_prefix("--player-skills523-pack=")
  if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
  if arg.begins_with("--quest-pack="):fresh=true;check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged questv1 installed")
 if not fresh:
  check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"unmodified actual811 source-issued ownership copy")
  if not failures.is_empty():quit(1);return
 var w: TwilightWorld=make_world()
 if fresh:
  for batch: int in range(100):
   w.quest_auto.retry_at=0;w.quest_auto.next_scan=0
   var before: int=w.quest_service.claimed.size();w.quest_auto.auto_claim=true;w.quest_auto.tick(w)
   if before==w.quest_service.claimed.size():break
  for i: int in range(50):w.quickslots[i]={"kind":"item","id":"HP 물약"} if i%3==0 else {}
  w.ui_preferences.edited_quickslots[w.job_class]=true
 var initial_completed: int=0;var initial_pending: int=0
 w.quest_auto.refresh_context(w)
 for entry: Dictionary in w.quest_service.entries(w.level,w.inventory):
  if entry.get("source_id")!=null and entry.completed:
   initial_completed+=1
   if not entry.rewards.get("pending_use",[]).is_empty():initial_pending+=1
 var reader: RefCounted=w.quest_item_provider.skill_books
 check(reader.active_sha256==BOOK.PACK_SHA and reader.profiles.size()==441,"exact privatev3/published245 bindings loaded, not reference engine")
 var before_profiles: Dictionary=reader.profiles.duplicate(true)
 check(not reader.load_pack(skill_path,"0".repeat(64)) and reader.profiles==before_profiles,"wrong pinned SHA rejects without replacing active profiles")
 check(not reader.load_pack("user://absent-quest262-skills.json",BOOK.PACK_SHA),"missing input rejects")
 for item: int in BOOK.IDS:check(w.quest_item_provider.has_definition(item),"exact existing runtime skill book linked "+str(item))
 var input: Dictionary=owned(w,177232,fresh)
 check(not input.is_empty() and int(w.inventory.get(input.key,0))>0,"genuine quest4981 reward ownership located")
 if input.is_empty():w.queue_free();quit(1);return
 if not fresh:check(OWN.proof(w,input.id).ok,"real physical quest receipt accepted without migration")
 var inventory: Dictionary=w.inventory.duplicate(true);var instances: Dictionary=w.item_instances.duplicate(true)
 var path: String=w.save_path();var hash: String=FileAccess.get_sha256(path)
 activate(w,input)
 check(w.inventory==inventory and w.item_instances==instances and FileAccess.get_sha256(path)==hash,"Knight source learn-class restriction preserves owned book")
 var starter: Dictionary=owned(w,177192,fresh)
 var starter_state: Dictionary=w.original_skills.catalog.export_state()
 activate(w,starter)
 check(w.inventory==inventory and w.original_skills.catalog.export_state()==starter_state and FileAccess.get_sha256(path)==hash,"already-known starter skill preserves book and save")
 var claims: Dictionary=w.quest_service.claimed.duplicate(true)
 check(QA.enter_game(w,"마법사"),"actual user class picker selects eligible Mage; ownership not fabricated")
 if fresh:
  for i: int in range(50):w.quickslots[i]={"kind":"item","id":"HP 물약"} if i%3==0 else {}
  w.ui_preferences.edited_quickslots[w.job_class]=true
 # Class picker legitimately swaps job-specific quickslots; pin the user's
 # current valid50-slot state after the normal class switch, not before it.
 var slots: Array=w.quickslots.duplicate(true)
 var target: Dictionary=reader.identity(input.record);var key: String=str(target.local_skill_id)
 check(not key.is_empty() and not w.original_skills.catalog.learned.has(key),"existing executable target is unlearned")
 check(w._save_game(true)==OK,"actual class-selected learning baseline saved")
 hash=FileAccess.get_sha256(path);inventory=w.inventory.duplicate(true);instances=w.item_instances.duplicate(true)
 var learned: Dictionary=w.original_skills.catalog.export_state();var consumables: Dictionary=w.consumable_service.export_state()
 var lock: String=str(input.key)+("@@@"+str(input.id) if not str(input.id).is_empty() else "")
 w.ui_preferences.item_locks[lock]=true;activate(w,input)
 check(w.inventory==inventory and FileAccess.get_sha256(path)==hash,"selected book lock blocks without consumption")
 w.ui_preferences.item_locks.erase(lock)
 var level: int=w.level;w.level=0;activate(w,input);w.level=level
 check(w.inventory==inventory and FileAccess.get_sha256(path)==hash,"native learning minimum level is retained")
 for id: int in [177292,177322,177342,177432]:
  var reference_identity: Dictionary=reader.identity(D.variant_item(D.definition_id(str(id)).native_record,1))
  check(not reference_identity.is_empty() and not w.original_skills.catalog.enabled(w.original_skills.catalog.record_for(str(reference_identity.local_skill_id))),"exact reference learning identity is known while execution stays closed before its separate learning test "+str(id))
 check(w.inventory==inventory and w.original_skills.catalog.export_state()==learned and FileAccess.get_sha256(path)==hash,"reference guards preserve all owned books/skills")
 w.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
 activate(w,input)
 check(w.inventory==inventory and w.item_instances==instances and w.original_skills.catalog.export_state()==learned and w.consumable_service.export_state()==consumables and FileAccess.get_sha256(path)==hash,"failed save retains input/learning/use receipts/bytes together")
 w.equipment_collections.test_save_writer=func(target_path: String,data: Dictionary)->Error:
  var error: Error=WRITER.write(target_path,data)
  return ERR_FILE_CANT_WRITE if error==OK else error
 activate(w,input)
 var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 check(int(w.inventory.get(input.key,0))==int(inventory[input.key])-1 and int(w.original_skills.catalog.learned.get(key,0))==1 and not w.quest_service.save_blocked,"write-then-error confirmed actual debit plus exactly one learned skill")
 check(durable.original_skill_state==norm(w.original_skills.catalog.export_state()) and durable.consumable_state==norm(w.consumable_service.export_state()) and durable.inventory==norm(w.inventory) and durable.item_instances==norm(w.item_instances),"learning/ownership/consumable source receipts durably match live state")
 var use_receipts: Array=durable.consumable_state.get("source_skill_book_receipts",[])
 check(use_receipts.size()==1 and use_receipts[0].local_skill_id==key and int(use_receipts[0].spell_class_id)==74 and use_receipts[0].spell_row_sha256==input.record.source_use_spec.source_spell_row_sha256 and use_receipts[0].skill_pack_sha256==BOOK.PACK_SHA,"original spell/item/definition hashes retained in learning receipt")
 if not fresh:check(use_receipts[0].input.quest_receipt==norm(instances[input.id].quest_reward_receipt) and int(use_receipts[0].input.original_quantity)==1 and not w.item_instances.has(input.id),"selected immutable grant proof survives spent physical stack")
 w.equipment_collections.test_save_writer=Callable();hash=FileAccess.get_sha256(path)
 activate(w,input)
 check(FileAccess.get_sha256(path)==hash and w.consumable_service.export_state().source_skill_book_receipts.size()==1,"duplicate activation does not debit/relearn or append receipt")
 # Other eligible already-issued books use the same genuine ownership path.
 for item: int in [177252,177332,177452]:
  var other: Dictionary=owned(w,item,fresh)
  var target_key: String=str(reader.identity(other.record).local_skill_id)
  var quantity: int=int(w.inventory.get(other.key,0))
  activate(w,other)
  check(int(w.inventory.get(other.key,0))==quantity-1 and int(w.original_skills.catalog.learned.get(target_key,0))==1,"real source book learns existing skill "+str(item))
 check(w.quest_service.claimed==claims,"learning never changes/regrants completed quests")
 check(norm(w.quickslots)==norm(slots),"all50 current class user slots survive learning")
 durable=JSON.parse_string(FileAccess.get_file_as_string(path));hash=FileAccess.get_sha256(path)
 w.queue_free();await process_frame;w=make_world("마법사")
 check(norm(w.inventory)==durable.inventory and norm(w.item_instances)==durable.item_instances and norm(w.original_skills.catalog.export_state())==durable.original_skill_state and norm(w.consumable_service.export_state())==durable.consumable_state,"fresh Main restores exact source learning,receipts and stock")
 check(w.consumable_service.export_state().source_skill_book_receipts.size()==4 and w.quest_service.claimed==claims and norm(w.quickslots)==norm(slots),"four real learned-book receipts/claims/50slots survive reconnect")
 print("QUEST_SKILLBOOK_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":"real_native_quest_books" if fresh else "real_held_quest_books","initial_source_completions":initial_completed,"initial_pending_use_completed":initial_pending,"skill_pack_sha256":BOOK.PACK_SHA,"learned_source_spell_ids":[74,73,1113,81],"starter_already_known_preserved":[2,65,1,80],"reference_targets_not_consumed_in_this_legacy_regression":[347,358,1133,70],"original_seed_sha256":seed,"final_save_sha256":FileAccess.get_sha256(path),"scope":"genuine quest issue/ownership to existing skill learning, one atomic save and reconnect; no new spell/cast execution/reference activation"}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
