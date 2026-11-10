extends SceneTree
## Integration consumes unmodified published providers staged outside feature Git.
## Player baseline is controlled QA; rewards/receipts are never fabricated.
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
var captures: String=""
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("PUBLISHED_OWNER_FAIL: ",label)
func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):captures=arg.trim_prefix("--capture-dir=")
 call_deferred("run")
func drain(world: TwilightWorld) -> void:
 for step: int in range(160):
  var count: int=world.quest_service.claimed.size()
  world.quest_auto.next_scan=0;world.quest_auto.retry_at=0
  world.quest_auto.auto_claim=true;world.quest_auto.tick(world)
  if world.quest_service.save_blocked or not world.patch523_owner_state_problem.is_empty():break
  if count==world.quest_service.claimed.size():break
func report(world: TwilightWorld,label: String) -> void:
 var materials: Array=[]
 for id: String in world.item_instances:
  var p: Dictionary=world.item_instances[id];var r: Dictionary=p.get("record",{})
  if int(r.get("source_item_class_id",0)) in [96004,96014,200698]:materials.append({"physical_id":id,"item_id":r.source_item_class_id,"remaining":p.get("source_reward_quantity"),"receipt":p.get("quest_reward_receipt")})
 print("PUBLISHED_OWNER_PHASE ",JSON.stringify({"phase":label,"level":world.level,"completed":world.quest_service.claimed.size(),"materials":materials,"source_error":world.patch523_owner_state_problem,"failures":world.quest_auto.failures.size()}))
func run() -> void:
 var source=load("res://scripts/quests/source_quest523.gd")
 check(source!=null and source.install_zip("/workspace/published-owner239/quests-current523-v1.zip").ok,"exact existing approved quest-v1 payload installs")
 print("PUBLISHED_OWNER_PHASE source-installed; Main instantiate")
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 print("PUBLISHED_OWNER_PHASE Main ready")
 check(QA.enter_game(world,"기사"),"actual Main and class screen with current source map")
 world.player.set_physics_process(false);world.field_population.set_process(false)
 check(world.install_patch523_craft_catalog_zip("/workspace/pr238-full-drive239/TWILIGHT_patch523_full_items_38ee3ec7.zip"),"actual full native catalog coexists with legacy aliases")
 world.quest_auto=load("res://scripts/quests/quest_auto_runner.gd").new()
 # Real optional supplier, unconfigured: source acquisition must keep held
 # provenance instead of claiming unavailable 859/1281/return consumers.
 world.quest_item_provider=load("res://scripts/quests/quest_item_provider238.gd").new()
 world.protection523=load("res://scripts/protection/protection523_runtime.gd").new()
 world.protection523.setup(world)
 check(world.protection523.source.get("ok",false),"actual published c69 owner installs from the existing pinned original ZIP")
 var binding: Dictionary=preload("res://scripts/crafting/patch523_protection_bindings.gd").prepare(world)
 check(binding.get("ok",false),"exact source-owned namespace binding "+str(binding.get("error","")))
 check(world.quest_service.source.quests.size()==3621,"current76a actual quest source loaded all3621 definitions")
 if not binding.get("ok",false) or world.quest_service.source.quests.size()!=3621:quit(1);return
 print("PUBLISHED_OWNER_PHASE providers verified; eligibility scan")
 check(world._save_game(true)==OK,"actual joint provider baseline saves")
 drain(world);report(world,"ordinary initial eligibility")
 check(not world.quest_service.claimed.has("m523:quest:71854") or world.level>=87,"source87 goal not waived by automatic completion")
 # Controlled current-level baselines exercise original prerequisite/level
 # gates. No direct materials, claimed quest IDs or receipts are injected.
 for required: int in [87,88,89,90,91]:
  world.level=maxi(world.level,required)
  drain(world);report(world,"QA level baseline "+str(required))
 check(world.quest_service.claimed.get("m523:quest:71854",false) and world.quest_service.claimed.get("m523:quest:71864",false) and world.quest_service.claimed.get("m523:quest:74773",false),"actual producer awards the87/88/89 source chain")
 check(world.quest_service.claimed.get("m523:quest:77992",false),"actual producer awards source91 grace material")
 if failures.is_empty():
  world.open_patch523_protection_owner()
  await process_frame
  var ui: Button=world.hud.find_child("ProtectionSupplyCraft_75764",true,false)
  check(ui!=null and not ui.disabled,"real published owner supply1 UI enabled from actual quest receipts")
  if ui!=null and not ui.disabled:
   ui.pressed.emit()
   await process_frame
   var dialog: Control=world.hud.find_child("TwilightConfirmation",true,false)
   check(dialog!=null,"actual supply1 confirmation appears")
   if dialog!=null:dialog.get("confirm_button").pressed.emit()
   await process_frame
  check(not world.protection523.owned_key(75764,world.inventory).is_empty(),"real supply1 creates body through UI")
  report(world,"after supply1")
  var before: String=JSON.stringify([world.inventory,world.item_instances,world.protection523.state,world.crafting_log])
  var sha: String=FileAccess.get_sha256(world.save_path())
  world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary) -> Error:return ERR_FILE_CANT_WRITE
  var failed: Dictionary=world.patch523_delegate_protection(47273)
  check(not failed.get("ok",false) and JSON.stringify([world.inventory,world.item_instances,world.protection523.state,world.crafting_log])==before and FileAccess.get_sha256(world.save_path())==sha,"actual owner pre-write failure preserves source quantities/body/title/log/disk")
  world.equipment_collections.test_save_writer=Callable()
  var supplied: Dictionary=world.patch523_delegate_protection(47273)
  check(supplied.get("ok",false),"generic exact source recipe delegates supply2 "+str(supplied.get("error","")))
  check(not world.protection523.owned_key(123373,world.inventory).is_empty(),"source supply2 actual body exists")
  report(world,"after supply2")
  var owned_before: Dictionary=world.protection523.state.duplicate(true)
  check(owned_before.titles.is_empty() and owned_before.crafted.is_empty(),"two upstream recipes do not invent permanent titles or lifetime limits")
  world.equipment_collections.test_save_writer=func(path: String,data: Dictionary) -> Error:
   var error: Error=preload("res://scripts/skills/save_writer.gd").write_text(path,JSON.stringify(data,"",true,true))
   return ERR_FILE_CANT_WRITE if error==OK else error
  var permanent: Dictionary=world.patch523_delegate_protection(132033)
  world.equipment_collections.test_save_writer=Callable()
  check(permanent.get("ok",false),"post-write response error reconciles one exact durable owner transaction "+str(permanent.get("error","")))
  check(world.protection523.state.titles==[1173] and world.protection523.state.crafted.get("132033")==1,"body and permanent original Appellation commit together")
  check(not world.protection523.owned_key(200723,world.inventory).is_empty(),"permanent craft grants actual source body rather than only a title")
  check(world.protection523.effects().title_flat>0 and world._damage_reduction_stat()>=int(world.protection523.effects().title_flat),"actual owner permanent title enters current combat reduction")
  before=JSON.stringify([world.inventory,world.item_instances,world.protection523.state,world.crafting_log]);sha=FileAccess.get_sha256(world.save_path())
  var duplicate: Dictionary=world.patch523_delegate_protection(132033)
  check(not duplicate.get("ok",false) and JSON.stringify([world.inventory,world.item_instances,world.protection523.state,world.crafting_log])==before and FileAccess.get_sha256(world.save_path())==sha,"actual duplicate craft cannot double debit/grant/title/save")
  world._load_game(true)
  check(world.patch523_owner_state_problem.is_empty() and world.protection523.state.titles==[1173] and not world.protection523.owned_key(200723,world.inventory).is_empty(),"actual Main reconnect restores sole-owner body/title/receipt state")
  report(world,"after owner reconnect")
 print("PUBLISHED_OWNER_SMOKE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"real providers, controlled eligible player levels; no organic87-level progression claim"}))
 world.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
