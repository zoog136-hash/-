extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("SOURCE201_MAIN_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
 check(QA.enter_game(world),"actual Main character confirmation")
 world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(true);world.save_timer=-100000
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/source_transform_visuals.json"))
 var count:int=0;var position:Vector2=world.player.global_position
 var inventory:Dictionary=world.inventory.duplicate(true)
 var collision:int=world.player.collision_layer;var mask:int=world.player.collision_mask
 for card:Dictionary in world.catalog_db["변신"]:
  var entry:Dictionary=manifest.entries.get("transform:"+str(card.sourceId),{})
  if not entry.get("source201_selected_input",false):continue
  world.player.start_combat_attack(position+Vector2(100,0),0.72,"slash")
  var sequence:int=world.player.motion.sequence;var elapsed:float=world.player.motion.attack_elapsed
  world._apply_transform_visual(card)
  check(world.player.transform_profile.frames_path==entry.frames_path,"production Main selects exact source frames")
  check(world.player.global_position==position and world.player.auto_enabled,"position and AUTO preserved")
  check(world.player.collision_layer==collision and world.player.collision_mask==mask,"collision channels preserved")
  check(world.player.motion.active and world.player.motion.sequence==sequence and world.player.motion.attack_elapsed==elapsed and world.player.motion.attack_duration==0.72,"in-flight production attack clock preserved")
  for facing:int in range(8):
   for role:String in ["idle","walk","attack","cast","hit","death"]:
    world.player.motion.facing8=facing;world.player.motion.facing4=facing/2;world.player.motion.state=role
    world.player.motion.apply_frames(world.player.transform_sprite)
    check(world.player.transform_sprite.animation==role+"_"+str(facing),"actual Main role/facing")
  count+=1
 check(count==14 and world.inventory==inventory,"fourteen visual substitutions never grant gameplay items")
 var selected:Dictionary=world.catalog_db["변신"].filter(func(r):return str(r.sourceId)=="222")[0]
 world.equipped_catalog["변신"]=selected.duplicate(true);world._restore_equipped_visuals()
 check(world._save_game(true)==OK,"existing save stores selected canonical transform ID")
 world._load_game(true)
 check(str(world.equipped_catalog["변신"].sourceId)=="222" and world.player.transform_profile.frames_path==manifest.entries["transform:222"].frames_path,"actual save/load resolves current source appearance without changing ID")
 world.queue_free();await process_frame;await process_frame
 print("SOURCE201_MAIN_RESULT entries=",count," checks=",checks," errors=",errors);quit(0 if errors==0 else 1)
