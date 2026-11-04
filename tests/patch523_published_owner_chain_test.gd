extends "res://tests/patch523_published_owners_main_test.gd"
## Resume the already verified real provider checkpoint; no reward injection.
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world),"actual existing eligible provider save loads")
 world.player.set_physics_process(false);world.field_population.set_process(false)
 world.quest_auto=load("res://scripts/quests/quest_auto_runner.gd").new()
 world.quest_item_provider=load("res://scripts/quests/quest_item_provider238.gd").new()
 world.protection523=load("res://scripts/protection/protection523_runtime.gd").new();world.protection523.setup(world)
 world._load_game(true)
 world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
 check(world.patch523_owner_state_problem.is_empty() and world.protection523.state.titles==[1173],"resume actual first permanent owner transaction without regrant")
 var completed: Array=[]
 var ids: Array=[245718,297828,328254,346911,371108]
 for index: int in range(ids.size()):
  world.level=92+index
  drain(world)
  report(world,"controlled source goal "+str(world.level))
  var item_id: int=ids[index]
  var definition: Dictionary=world.protection523.source.definitions[str(item_id)]
  var recipe: int=int(definition.recipe.ItemCraftID)
  var binding: Dictionary=preload("res://scripts/crafting/patch523_protection_bindings.gd").prepare(world)
  check(binding.get("ok",false),"actual newly issued receipt accepted "+str(item_id)+str(binding.get("error","")))
  var quote: Dictionary=world.protection523.quote_craft(item_id)
  check(quote.get("ok",false),"actual source chain produces eligible next-stage materials "+str(item_id)+str(quote.get("error","")))
  if not quote.get("ok",false):break
  var key: String=world.protection523.owned_key(200698,world.inventory)
  var before: String=JSON.stringify([world.inventory,world.item_instances,world.protection523.state,world.crafting_log]);var sha: String=FileAccess.get_sha256(world.save_path())
  world.ui_preferences["item_locks"]={key:true}
  check(not world.patch523_delegate_protection(recipe).get("ok",false) and JSON.stringify([world.inventory,world.item_instances,world.protection523.state,world.crafting_log])==before and FileAccess.get_sha256(world.save_path())==sha,"real locked reward material is preserved "+str(item_id))
  world.ui_preferences.item_locks={}
  var physical_id: String=""
  for p: String in world.item_instances:
   if world.item_instances[p].get("name")==key:physical_id=p;break
  check(not physical_id.is_empty(),"actual typed material physical proof exists "+str(item_id))
  if physical_id.is_empty():break
  var receipt: Dictionary=world.item_instances[physical_id].quest_reward_receipt.duplicate(true)
  world.item_instances[physical_id].quest_reward_receipt.quantity=int(receipt.quantity)+1
  check(not world.patch523_delegate_protection(recipe).get("ok",false),"mismatched granted quantity cannot become consumable ownership")
  world.item_instances[physical_id].quest_reward_receipt=receipt.duplicate(true)
  # Verify the atomic boundary too: published owner itself may be called by
  # its panel, so a stale/malformed receipt must be rejected at the save edge.
  world.item_instances[physical_id].quest_reward_receipt.bless_code_id=2
  var blocked: Dictionary=world.protection523.craft_recipe(recipe)
  check(not blocked.get("ok",false) and FileAccess.get_sha256(world.save_path())==sha,"direct owner UI cannot bypass typed receipt validation at joint save")
  world.item_instances[physical_id].quest_reward_receipt=receipt.duplicate(true)
  if index%2==0:
   world.open_patch523_protection_owner();await process_frame
   var button: Button=world.hud.find_child("ProtectionCraft_"+str(item_id),true,false)
   check(button!=null and not button.disabled,"actual owner next-stage UI action "+str(item_id))
   if button!=null and not button.disabled:
    button.pressed.emit();await process_frame
    var confirm: Button=world.hud.find_child("ConfirmTransaction",true,false)
    check(confirm!=null,"actual owner next-stage confirmation "+str(item_id))
    if confirm!=null:confirm.pressed.emit()
  else:world._patch523_craft_requested("patch523:"+str(recipe),1)
  await process_frame
  check(world.protection523.state.crafted.get(str(recipe))==1 and world.protection523.state.titles.has(int(definition.title.ID)),"actual body/Appellation/log transaction advances exact recipe "+str(recipe))
  check(not world.protection523.owned_key(item_id,world.inventory).is_empty(),"actual new body exists "+str(item_id))
  var rng_after: int=world.rng.state
  world._load_game(true)
  world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
  check(world.patch523_owner_state_problem.is_empty() and world.protection523.state.titles.size()==index+2 and world.rng.state==rng_after,"actual reconnect retains each new Appellation and transaction RNG "+str(item_id))
  var count: int=world.crafting_log.size();sha=FileAccess.get_sha256(world.save_path())
  check(not world.patch523_delegate_protection(recipe).get("ok",false) and world.crafting_log.size()==count and FileAccess.get_sha256(world.save_path())==sha,"lifetime duplicate remains blocked after reconnect "+str(recipe))
  completed.append(item_id)
 check(completed.size()==5 and world.protection523.state.titles==[1173,1508,1788,2144,2521,2658],"all6 source permanent Appellations earned from actual typed quest rewards")
 print("PUBLISHED_OWNER_CHAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"new_stages":completed,"controlled_player_levels":true,"source_dates_prerequisites_intact":true,"not_organic_leveling":true}))
 world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
