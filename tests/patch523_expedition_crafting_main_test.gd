extends "res://tests/patch523_enhancement_main_test.gd"
## Source contracts and real published withdraw/UI/save. Storage and unrelated
## ingredient stocks are controlled QA fixtures; no natural expedition claim.
const MATERIALS=preload("res://scripts/crafting/patch523_expedition_materials.gd")
const CATALOG_PATH="/workspace/published-owner239/expedition-957b-published-catalog.json"
const CATALOG_SHA="39f075e3aea122080b060c8682c81dc6b43e3cb97e886504bdefd9dfc2034991"
func freeze(world: TwilightWorld) -> void:
 world.player.set_physics_process(false);world.field_population.configure(world,null);world.field_population.set_process(false);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
func confirm(world: TwilightWorld) -> bool:
 var dialog: Control=world.hud.find_child("TwilightConfirmation",true,false)
 if dialog==null:return false
 dialog.get("confirm_button").pressed.emit()
 return true
func issued(world: TwilightWorld,id: String,amount: int,bless: int=1) -> String:
 var tuple: String=id+":"+str(bless)+":0"
 world.expedition_local.state.storage[tuple]=amount # explicitly controlled storage fixture
 var result: Dictionary=world.expedition_local.withdraw(tuple,amount)
 check(result.get("ok",false),"real published withdraw issues typed ownership "+tuple+str(result.get("error","")))
 return str(world.expedition_local.state.issued.get(tuple,""))
func available(world: TwilightWorld,material: Dictionary) -> int:
 return world.patch523_equipment.available_material(material,world.inventory,world._patch523_craft_item_index(),world.item_instances,world.equipped_items,world.ui_preferences.get("item_locks",{}),false,world.gold,world._patch523_craft_context())
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world),"actual Main and source-map class screen")
 freeze(world)
 check(world.install_patch523_craft_catalog_zip("/workspace/pr238-full-drive239/TWILIGHT_patch523_full_items_38ee3ec7.zip"),"actual complete native catalog installs beside legacy aliases")
 world.level=100;world.gold=1000000000
 world.expedition_catalog=load("res://scripts/expedition/source_catalog.gd").new()
 check(world.expedition_catalog.install(CATALOG_PATH,CATALOG_SHA),"exact published source catalog from existing original ZIP")
 world.expedition_local=load("res://scripts/expedition/local_runtime.gd").new()
 world.expedition_local.world=world;world.expedition_local.restore({})
 var resume: bool="--resume-typed-material-matrix" in OS.get_cmdline_user_args()
 if resume:world._load_game(true);freeze(world)
 var book: RefCounted=world.patch523_equipment
 for id: int in ([] if resume else MATERIALS.IDS):
  var key: String=issued(world,str(id),2)
  var m: Dictionary={"item":book.record(str(id)).name,"source_id":str(id),"physical":false,"bless_code":1,"level":0}
  check(available(world,m)==2,"all41 materials plus3 new tokens use actual issued key "+str(id))
  var r: Dictionary=world._find_catalog_item_record(key)
  check(r.source_item==book.data.items[str(id)].item_class and not r.get("source_m_native_item",false),"raw source grade/restrictions retained without native promotion "+str(id))
  var tuple: String=r.expedition_key
  world.expedition_local.state.issued.erase(tuple)
  check(available(world,m)==0,"missing issuance ledger rejects same-named material "+str(id))
  world.expedition_local.state.issued[tuple]=key
  world.ui_preferences["item_locks"]={key:true}
  check(available(world,m)==0,"typed issued lock respected "+str(id))
  world.ui_preferences.item_locks={}
  var modified: Dictionary=m.duplicate(true);modified.bless_code=2
  check(available(world,modified)==0,"normal/blessed issued ownership cannot merge "+str(id))
 print("EXPEDITION_TYPED_MATERIAL_MATRIX ",JSON.stringify({"original_handoff":41,"additional_tokens":3,"actual_issued":0 if resume else MATERIALS.IDS.size(),"prior44_checkpoint_reused":resume}))
 var plans: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/workspace/equipment523-logs/expedition-craft-ui-plans_LOCAL_ONLY.json"))
 var completed: Array=[]
 for id: String in plans.plans:
  var only_id: String=""
  for arg: String in OS.get_cmdline_user_args():
   if arg.begins_with("--only-material-id="):only_id=arg.trim_prefix("--only-material-id=")
  if not only_id.is_empty() and id!=only_id:continue
  if "--reconnect-only-materials" in OS.get_cmdline_user_args() and id not in ["3732","341344","341354","341364","3652","3672","3692","3722","188384"]:continue
  var plan: Dictionary=plans.plans[id];var recipe_id: String=plan.recipe_id
  world.inventory={"화살":0,"총알":0};world.item_instances={};world.equipped_items={};world.gold=1000000000
  world.patch523_material_choices[recipe_id]=plan.choices
  var selected: Dictionary=book.material_selection(recipe_id,plan.choices).recipe
  var target_key: String="";var target_required: int=0
  for m: Dictionary in selected.materials:
   if int(m.source_id)==26 and m.get("wallet",false):continue
   if m.source_id==id and int(id) in MATERIALS.IDS:
    target_required+=int(m.quantity);target_key=issued(world,id,int(m.quantity)+1)
   else:world.inventory[book.ownership_key(m)]=int(world.inventory.get(book.ownership_key(m),0))+int(m.quantity)
  if target_key.is_empty():target_key=book.record(id).name;target_required=int(world.inventory.get(target_key,0))
  if id=="188384":check(not world.PATCH523_ITEM_USE.reason(book.record(id),world.level,world.BASE508.source_class_id(world.job_class)).is_empty(),"unresolved ClassID0 remains blocked for item activation; pure material manufacture is separate")
  check(world._save_game(true)==OK,"actual controlled ingredients baseline saves "+id)
  var quote: Dictionary=world._craft_quote(recipe_id,1)
  check(quote.get("ok",false),"full source recipe quotes actual material identity "+id+str(quote.get("reason","")))
  if not quote.get("ok",false):continue
  check(int(quote.materials.get(target_key,0))==target_required,"quote pins the exact debit key "+id)
  world.hud.open_crafting();await process_frame
  var panel: Control=world.hud.workspace.find_child("CraftRecipes",true,false)
  while panel!=null and panel.get_script()!=world.hud.CraftUI:panel=panel.get_parent()
  check(panel!=null,"actual crafting screen ancestor exists")
  if panel==null:break
  var index: int=panel.recipe_ids.find(recipe_id)
  check(index>=0,"source recipe visible in existing crafting UI "+id)
  if index<0:continue
  panel.listing.select(index);panel.listing.item_selected.emit(index)
  check(not panel.action.disabled,"actual crafting action enabled by typed availability "+id)
  if int(id) in MATERIALS.IDS:
   var visible_key: bool=false
   for row: Dictionary in panel.material_rows:
    if row.panel.tooltip_text.contains(target_key):visible_key=true
   check(visible_key,"actual UI discloses the issued debit key "+id)
  var old_count: int=int(world.inventory.get(target_key,0))
  var old_log: int=world.crafting_log.size()
  if id=="3732":
   var before: String=JSON.stringify([world.inventory,world.item_instances,world.crafting_log,world.patch523_crafting_usage,world.expedition_local.state]);var old_rng: int=world.rng.state;var old_sha: String=FileAccess.get_sha256(world.save_path())
   world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary) -> Error:return ERR_FILE_CANT_WRITE
   panel.action.pressed.emit();check(confirm(world),"actual failed material-craft confirmation")
   await process_frame
   var after_failed: String=JSON.stringify([world.inventory,world.item_instances,world.crafting_log,world.patch523_crafting_usage,world.expedition_local.state])
   if after_failed!=before or world.rng.state!=old_rng or FileAccess.get_sha256(world.save_path())!=old_sha:print("EXPEDITION_PREWRITE_DIAGNOSTIC ",JSON.stringify({"same_live":after_failed==before,"same_rng":world.rng.state==old_rng,"same_disk":FileAccess.get_sha256(world.save_path())==old_sha}))
   check(after_failed==before and world.rng.state==old_rng and FileAccess.get_sha256(world.save_path())==old_sha,"pre-write failure preserves issued debit/result/ledger/RNG/disk")
   world.equipment_collections.test_save_writer=func(path: String,data: Dictionary) -> Error:
    var error: Error=preload("res://scripts/skills/save_writer.gd").write_text(path,JSON.stringify(data,"",true,true))
    return ERR_FILE_CANT_WRITE if error==OK else error
  panel.action.pressed.emit();check(confirm(world),"actual crafting confirmation "+id)
  world.equipment_collections.test_save_writer=Callable()
  await process_frame
  check(world.crafting_log.size()==old_log+1,"one durable actual UI craft "+id)
  check(int(world.inventory.get(target_key,0))==old_count-target_required,"real UI debits the exact key once "+id)
  var rng_after: int=world.rng.state;var owned_after: Dictionary=world.inventory.duplicate(true)
  var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
  var same_bag: bool=durable.inventory==JSON.parse_string(JSON.stringify(owned_after,"",true,true))
  var same_rng: bool=durable.patch523_transaction_rng.state==str(rng_after)
  if not same_bag or not same_rng:print("EXPEDITION_DURABLE_DIAGNOSTIC ",JSON.stringify({"item":id,"same_inventory":same_bag,"same_rng":same_rng,"disk_rng":durable.patch523_transaction_rng,"live_rng":str(rng_after)}))
  check(same_bag and same_rng,"every actual UI transaction has exact durable debit/result/RNG "+id)
  if id in ["3732","341344","341354","341364","3652","3672","3692","3722","188384"]:
   world._load_game(true);freeze(world)
   var normalized: Dictionary=JSON.parse_string(JSON.stringify(owned_after,"",true,true))
   if world.inventory!=normalized or world.rng.state!=rng_after:print("EXPEDITION_RECONNECT_DIAGNOSTIC ",JSON.stringify({"item":id,"same_normalized_inventory":world.inventory==normalized,"same_rng":world.rng.state==rng_after,"before_keys":normalized.keys(),"after_keys":world.inventory.keys()}))
   check(world.inventory==normalized and world.rng.state==rng_after,"actual reconnect retains typed debit/result and RNG "+id)
  check(world.expedition_local.validate(world.expedition_local.state).is_empty(),"issuance state remains valid and separate "+id)
  completed.append(id)
  print("EXPEDITION_CRAFT_UI_COMPLETE ",id," ",recipe_id)
 print("EXPEDITION_CRAFT_UI_MATRIX ",JSON.stringify({"completed_ids":completed,"source_without_active_material_recipe":plans.not_exercised,"scope":"actual published withdrawal/UI transactions for completed_ids; every durable readback; selected9 source namespaces reconnect; controlled storage/other ingredient stock, not natural expedition acquisition"}))
 print("EXPEDITION_CRAFT_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
 world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
