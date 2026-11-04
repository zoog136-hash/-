extends "res://tests/patch523_registered_recipes_main_test.gd"
## Entire registered recipe set; controlled source input grants are test setup,
## not evidence of natural exploration/quest/drop supply.

var only_ui: bool=false

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument=="--ui-only":only_ui=true
 super._initialize()

func seed_for(low: int,high: int) -> int:
 var probe:=RandomNumberGenerator.new()
 for value: int in range(2000000):
  probe.seed=value;var draw: int=probe.randi_range(0,999999)
  if draw>=low and draw<high:return value
 return -1

func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world),"actual Main with installed full source catalog")
 world.player.set_physics_process(false);world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
 var book: Object=world.patch523_equipment
 if world.patch523_craft_catalog_status.get("registered_count")!=30398 and not archive.is_empty():check(world.install_patch523_craft_catalog_zip(archive),"install exact existing full source catalog in fresh QA profile")
 check(world.patch523_craft_catalog_status.get("registered_count")==30398,"actual full source normal registration restored")
 check(book.problem.is_empty() and book.recipes.size()==1045,"1045 exact registered source recipes load")
 if book.recipes.size()!=1045:printerr(book.problem);quit(1);return
 if not only_ui:table_checks(world)
 # Every alternative row gets a direct transaction, with other slots fixed.
 var alternatives: int=0
 var items: Dictionary=world._patch523_craft_item_index()
 check(is_same(items,world._patch523_craft_item_index()),"full source immutable lookup reused between quotes")
 world._index_catalog_item_sources()
 check(world.patch523_craft_item_cache.is_empty(),"source registry refresh invalidates cached identity lookup")
 items=world._patch523_craft_item_index()
 world._index_item_weights()
 check(world.patch523_craft_item_cache.is_empty(),"weight index refresh invalidates cached source lookup")
 items=world._patch523_craft_item_index()
 for recipe: Dictionary in ([] if only_ui else book.recipes.values()):
  for slot: Dictionary in recipe.get("material_slots",[]):
   for candidate: Dictionary in slot.candidates:
    var state: Dictionary=prepared(book,recipe,{str(int(slot.slot_index)):int(candidate.row_id)})
    var transaction: Dictionary=book.execute(recipe.id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,state.next,{},state.choices,0 if recipe.has("outcomes") else -1,{"level":100,"usage":{},"now":int(Time.get_unix_time_from_system())})
    check(transaction.get("ok",false),"every original alternative material row executes "+recipe.id+"/"+str(candidate.row_id)+" "+str(transaction.get("reason","")))
    alternatives+=1
 print("PATCH523_FULL_ALTERNATIVES ",alternatives)
 var calendar_ids: Array[String]=[]
 for recipe: Dictionary in book.recipes.values():
  if not recipe.get("craft_conditions",{}).has("active_window"):continue
  calendar_ids.append(str(recipe.id))
  var window: Dictionary=recipe.craft_conditions.active_window
  var state: Dictionary=prepared(book,recipe)
  for moment: int in [int(window.start_unix)-1,int(window.start_unix),int(window.end_unix)-1,int(window.end_unix)]:
   var before: String=JSON.stringify(state)
   var quote: Dictionary=book.quote(recipe.id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,{},state.choices,{"level":100,"usage":{},"now":moment})
   var active: bool=moment>=int(window.start_unix) and moment<int(window.end_unix)
   check(quote.get("ok",false)==active,"all original calendar start/end boundary checks "+recipe.id+"/"+str(moment))
   check(JSON.stringify(state)==before,"calendar quote never mutates source ownership "+recipe.id)
 check(calendar_ids.size()==52,"all52 newly executable date-qualified source recipes")
 print("PATCH523_CALENDAR_BOUNDARIES ",calendar_ids.size())
 var ui_ids: Array[String]=calendar_ids.duplicate()
 var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/workspace/source523/candidate-enhancement-calendar-source-local.json"))
 for recipe: Dictionary in book.recipes.values():
  if not prior.recipes.has(recipe.id) and not recipe.has("missing_failure_policy") and recipe.id not in ui_ids:ui_ids.append(str(recipe.id))
 for id: String in ui_ids:
  setup(world,id)
  world.inventory["화살"]=0;world.inventory["총알"]=0
  check(world._save_game(true)==OK,"actual calendar source ingredient baseline saves "+id)
  var before_log: int=world.crafting_log.size()
  var action: Button=await select(world,id)
  check(action!=null and not action.disabled,"all source calendar rows expose actual crafting UI "+id)
  var label: RichTextLabel=world.hud.workspace.find_child("CraftAvailability",true,false)
  if book.recipes[id].get("craft_conditions",{}).has("active_window"):check(label!=null and label.text.contains("원본 기간") and label.text.contains("시간대 필드는 없으므로"),"actual UI shows exact source dates and explicit host clock "+id)
  await confirm(world,action)
  check(world.crafting_log.size()==mini(200,before_log+1) and str(world.crafting_log.back().recipe_id)==id,"one actual calendar UI craft committed "+id)
  var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
  check(disk.inventory==JSON.parse_string(JSON.stringify(world.inventory,"",true,true)) and int(disk.gold)==world.gold and disk.patch523_transaction_rng.state==str(world.rng.state),"every calendar UI result and RNG are durable "+id)
  print("PATCH523_NEW_SOURCE_UI_COMPLETE ",id)
 var partial_ids: Array[String]=[]
 for recipe: Dictionary in book.recipes.values():
  if recipe.has("missing_failure_policy"):partial_ids.append(str(recipe.id))
 check(partial_ids.size()==7,"all7 source partial-probability definitions keep explicit configured failure policy")
 for id: String in partial_ids:
  var recipe: Dictionary=book.recipes[id]
  var success: int=int(recipe.outcomes[0].probability)
  check(book.data.raw_recipes.outputs[str(int(recipe.source_craft_id))].size()==1,"missing failure never mutates original output rows "+id)
  var raw_before: String=JSON.stringify(book.data.raw_recipes.outputs[str(int(recipe.source_craft_id))])
  for interval: Array in [[0,success],[success,1000000]]:
   setup(world,id)
   check(world._save_game(true)==OK,"partial-probability actual input baseline saves "+id)
   var action: Button=await select(world,id)
   var label: RichTextLabel=world.hud.workspace.find_child("CraftAvailability",true,false)
   check(label!=null and label.text.contains("TWILIGHT 누락 실패 정책"),"actual UI distinguishes source success from configured failure "+id)
   await confirm(world,action,seed_for(interval[0],interval[1]))
   if interval[0]==0:check(int(world.inventory.get(recipe.result.item,0))==int(recipe.result.quantity),"source exact success branch creates original non-equipment identity "+id)
   else:check(world.inventory.is_empty() and world.item_instances.is_empty(),"configured missing failure consumes inputs with no phantom output "+id)
   check(world.gold==500 and JSON.stringify(book.data.raw_recipes.outputs[str(int(recipe.source_craft_id))])==raw_before,"source fee and original rows remain unchanged "+id)
   print("PATCH523_PARTIAL_UI_COMPLETE ",id," ",interval[0])
  if recipe.has("craft_conditions") and recipe.craft_conditions.get("quota",{}).get("mode")=="bounded_lifetime":
   for attempt: int in range(2):
    setup(world,id);var action: Button=await select(world,id);await confirm(world,action,seed_for(success,1000000))
   setup(world,id)
   var before: String=JSON.stringify([world.inventory,world.item_instances,world.gold,world.patch523_crafting_usage])
   var rng_before: int=world.rng.state
   world._patch523_craft_requested(id,1)
   check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.patch523_crafting_usage])==before and world.rng.state==rng_before,"source limit4 preserved across successes and failures without reset "+id)
 for id: String in ["patch523:1092","patch523:122114","patch523:131602","patch523:122344"]:
  var recipe: Dictionary=book.recipes[id]
  var rolls: Array[int]=[-1]
  if recipe.has("outcomes"):
   rolls.clear();var threshold: int=0
   for outcome: Dictionary in recipe.outcomes:rolls.append(threshold);threshold+=int(outcome.probability)
  for roll: int in rolls:
   setup(world,id)
   world.inventory["legacy source material sentinel"]=7
   check(world._save_game(true)==OK,"full source UI baseline save "+id)
   var action: Button=await select(world,id)
   check(action!=null and not action.disabled,"actual full source action enabled before save guard")
   if action==null or action.disabled:continue
   action.pressed.emit();await process_frame
   var confirmation: Button=world.hud.find_child("ConfirmTransaction",true,false)
   check(confirmation!=null,"actual full source confirmation before save guard")
   if confirmation==null:continue
   # Snapshot the transaction boundary after UI/ambient frames, then invoke
   # the final confirmation synchronously so unrelated NPC RNG is excluded.
   var bytes: String=FileAccess.get_sha256(world.save_path())
   var snapshot: String=JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id,world.patch523_crafting_usage])
   var before_rng: int=world.rng.state
   world.source_save_blocked=true
   confirmation.pressed.emit()
   check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id,world.patch523_crafting_usage])==snapshot,"full source blocked save preserves exact live ownership and ledger "+id)
   check(FileAccess.get_sha256(world.save_path())==bytes,"full source blocked save preserves durable bytes "+id)
   check(world.rng.state==before_rng,"full source blocked save restores transaction RNG "+id)
   world.source_save_blocked=false
   action=await select(world,id)
   await capture("full-source-"+id.replace(":","-")+"-"+str(roll))
   var seed: int=-1
   # Find any seed in the full interval; a one-in-a-million boundary need not
   # occur in the deterministic seed search.
   if roll>=0:
    var threshold: int=0
    for outcome: Dictionary in recipe.outcomes:
     if threshold==roll:seed=seed_for(threshold,threshold+int(outcome.probability));break
     threshold+=int(outcome.probability)
   check(roll<0 or seed>=0,"deterministic source outcome interval has test seed")
   await confirm(world,action,seed)
   var output: Dictionary=recipe.result
   if roll>=0:
    var threshold: int=0
    for outcome: Dictionary in recipe.outcomes:
     threshold+=int(outcome.probability)
     if roll<threshold:output=outcome;break
   check(int(world.inventory.get("legacy source material sentinel",0))==7 and world.gold==500,"unrelated stack and exact fee preserved "+id)
   if not output.get("empty_result",false):
    check(int(world.inventory.get(book.ownership_key(output),0))==int(output.quantity),"actual UI delivers original ID/state/quantity branch "+id+"/"+str(roll))
   else:
    check(world.inventory.size()==1,"explicit empty result has no phantom source item")
   if output.physical:
    var physical: Dictionary=world.item_instances.get("30001",{})
    check(book.identity(physical)==str(output.source_id),"new native gear retains exact physical source identity")
    world.hud.inventory_item_activated.emit(str(output.item)+"@@@30001")
    check(not world.equipped_items.is_empty(),"new native result uses actual inventory equipment action")
   check(world._save_game(true)==OK,"full source result saves")
   world._load_game(true)
   check(world.gold==500 and int(world.inventory.get("legacy source material sentinel",0))==7,"full source cost and unrelated ownership survive reload")
   if not output.get("empty_result",false):check(int(world.inventory.get(book.ownership_key(output),0))==int(output.quantity),"full source result survives reload "+id)
 print("PATCH523_FULL_RECIPES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"registered_recipes":book.recipes.size(),"alternatives":alternatives,"all_new_and_calendar_ui_recipes":ui_ids.size(),"calendar_recipes":calendar_ids.size(),"partial_probability_recipes":partial_ids.size(),"ui_recipe_ids":[1092,122114,131602,122344],"matrix_skipped":only_ui,"natural_supply_integrated":false,"runtime_rules":"LOCAL_ONLY candidate"}))
 world.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
