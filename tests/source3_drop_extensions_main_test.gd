extends SceneTree
const EXTRA=preload("res://scripts/loot/source3_drop_extensions.gd")
const DROP=preload("res://scripts/loot_drop.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("DROP_EXTENSION_MAIN_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
 check(QA.enter_game(world),"actual Main character confirmation")
 world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 if "--restart-check" in OS.get_cmdline_user_args():
  var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://source-drop-extension-expect.json"))
  for name:String in expected.counts:check(int(world.inventory.get(name,0))==int(expected.counts[name]),"independent restart preserves picked item "+name)
  for id:String in expected.collected:check(not world.ground_loot.records.has(id),"independent restart cannot restore collected ID")
  await finish(world);return
 check(world.loot_catalog.source3_by_key.size()==26,"actual Main exposes all existing runtime item identities")
 var floor:Vector2=preload("res://tests/active_source_test_positions.gd").combat(world,[Vector2(30,0)])
 check(floor.is_finite(),"real admitted combat floor")
 if not floor.is_finite():await finish(world);return
 world.player.global_position=floor;world.level=90;world.ain_service.blessing=200
 world.original_skills.catalog.learned.clear();world._clear_monsters();world.ground_loot.clear_map(world.active_map_id)
 var by_id:Dictionary={}
 for record:Dictionary in world.monster_db:
  if record.has("source_npc_id"):by_id[str(record.source_npc_id)]=record
 var expected:Dictionary={"counts":{},"collected":[]};var visited:int=0
 for id:String in EXTRA.registry():
  var actor:TwilightMonster=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(actor)
  actor.setup(by_id[id],world.player,world,null);actor.global_position=floor+Vector2(30,0);actor.set_physics_process(false)
  actor.died.connect(world._on_monster_died)
  check(actor.loot_source_identity==EXTRA.registry()[id].identity,"real actor retains strict source identity "+id)
  var target:String=str(EXTRA.registry()[id].drops[0].item_name)
  var seed_value:int=-1
  for index:int in range(20000):
   var rng:=RandomNumberGenerator.new();rng.seed=index
   var rolled:Array=DROP.roll_detailed(actor.drop_items,actor.is_boss,world.loot_catalog,rng,actor.monster_name,actor.loot_source_identity)
   if rolled.any(func(row):return row.item_name==target):seed_value=index;break
  check(seed_value>=0,"existing grade roll can reach source member "+id)
  if seed_value<0:actor.queue_free();await process_frame;continue
  var before:int=int(world.inventory.get(target,0));var old_ids:Array=world.ground_loot.records.keys()
  world.rng.seed=seed_value;world._deal_successful_player_hit(actor,actor.max_hp+1,false)
  check(actor.dead,"production damage kills real source actor "+id)
  var ground_id:String=""
  for candidate:String in world.ground_loot.records:
   if not old_ids.has(candidate) and world.ground_loot.records[candidate].item_name==target:ground_id=candidate;break
  check(not ground_id.is_empty(),"real death creates exact source-ground item "+id)
  check(int(world.inventory.get(target,0))==before,"death never directly grants inventory")
  var snapshot:Dictionary=world.ground_loot.records.duplicate(true);world._on_monster_died(actor)
  check(world.ground_loot.records==snapshot,"duplicate death cannot duplicate reward "+id)
  if ground_id.is_empty():actor.queue_free();await process_frame;continue
  var view:Button=world.ground_loot.views.get(ground_id)
  check(view!=null and view.tooltip_text.contains(target),"real pickup button and item identity "+id)
  if view!=null:
   var position:Array=world.ground_loot.records[ground_id].position
   world.player.global_position=Vector2(position[0],position[1])
   while Time.get_ticks_msec()-view.visible_since<world.ground_loot.MIN_VISIBLE_MS:
    await create_timer(0.1).timeout
   world.player.global_position=Vector2(position[0],position[1])
   var picked:bool=world._collect_ground_drop(view)
   if not picked:print("PICKUP_DIAGNOSTIC ",id," ",JSON.stringify({"age_ms":Time.get_ticks_msec()-view.visible_since,"valid":world.ground_loot.valid_view(view),"player":str(world.player.global_position),"target":str(position),"stun":world.player.is_stunned(),"fear":world.player.is_feared(),"hold":world.player.is_held(),"line_clear":world._has_line_of_sight_world(world.player.global_position,Vector2(position[0],position[1]))}))
   check(picked,"actual visibility-gated pickup transaction "+id)
   check(not world._collect_ground_drop(view),"same view cannot reward twice "+id)
   check(int(world.inventory.get(target,0))==before+1,"exactly one existing item granted on pickup "+id)
   if picked:expected.counts[target]=before+1;expected.collected.append(ground_id)
  world.player.global_position=floor;world._clear_monsters();await process_frame;await process_frame
  visited+=1
 check(visited==17,"all seventeen reviewed source actors killed and picked")
 world._open_inventory();await process_frame
 check(world.hud.workspace.visible,"production inventory UI opens with picked equipment")
 check(world._save_game(true)==OK,"save actual source drops after pickup")
 var file=FileAccess.open("user://source-drop-extension-expect.json",FileAccess.WRITE);file.store_string(JSON.stringify(expected));file.close()
 var output:Array=[]
 var code:int=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/source3_drop_extensions_main_test.gd","--","--restart-check"],output,true)
 check(code==0,"fresh independent restart verifies inventory and stable ground IDs")
 for line:Variant in output:print(line)
 await finish(world)
func finish(world:Node):
 world.queue_free();await process_frame;await process_frame
 print("SOURCE3_DROP_EXTENSIONS_MAIN_RESULT checks=",checks," errors=",errors)
 quit(0 if errors==0 else 1)
