extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const SAFE=preload("res://scripts/maps/source_map_spawns.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("CATALOG_GAP_MAIN_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1000,700)
 var additions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/reviewed_source_additions.json"))
 var habitats:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/local_source_habitats.json"))
 var world:TwilightWorld=load("res://Main.tscn").instantiate();world.active_map_id="source_440";root.add_child(world)
 check(QA.enter_game(world),"actual Main class confirmation")
 world.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 check(world.monster_db.size()==438,"actual Main contains retained 431 plus reviewed seven")
 for record:Dictionary in additions.records:
  var chosen:Dictionary={}
  for row:Dictionary in habitats.rows:
   if str(row.get("source_npc_id",""))==str(record.source_npc_id):chosen=row;break
  check(not chosen.is_empty(),"new species has actual habitat "+str(record.name))
  if chosen.is_empty():continue
  world._set_map(str(chosen.map_id),false);world.portal_cooldown=100000;world.field_population.set_process(false)
  var point:Vector2=world.field_map.coordinates.to_world(Vector2(chosen.source_center[0],chosen.source_center[1]))
  check(SAFE.floor_allowed(world.field_map,point),"actual floor "+str(record.name))
  world.player.global_position=point;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();world.field_renderer.refresh_visible()
  var population:FieldPopulation=world.field_population
  for i:int in range(80):population._process(.4);await process_frame
  var slot:Dictionary={}
  var live:int=0
  for value:Dictionary in population.slots:
   if str(value.region.id)!=str(chosen.id):continue
   if is_instance_valid(value.monster):live+=1
   if slot.is_empty():slot=value
  check(live>0 and live<=int(chosen.max_count),"bounded actual actor population "+str(record.name))
  if slot.is_empty() or not is_instance_valid(slot.monster):continue
  var actor:TwilightMonster=slot.monster
  actor.set_physics_process(false)
  check(actor.monster_name==record.name and actor.max_hp==maxi(30,int(record.hp)) and actor.monster_level==int(record.lv),"independent source identity and retained stats")
  check(actor.current_attack_type()==str(record.get("attack_type","melee")),"explicit local melee/caster policy")
  check(actor.motion.frame_source!=null,"actual source animation, no generic silhouette")
  actor.motion.state="idle";actor.motion.active=false;actor.motion.dead=false;actor.motion.facing8=2;actor.motion.state_clock=0;actor.motion.apply(actor.sprite,actor.animation_base_scale)
  var canvas:Array=record.source_animation.canvas_original_grid
  var foot:=Vector2(24.0-float(canvas[0]),18.0-float(canvas[1]))
  var projected:Vector2=actor.sprite.to_global(foot-actor.sprite.texture.get_size()*.5)
  check(projected.distance_to(actor.global_position)<0.01,"reviewed cosmetic ground and physical node align")
  for role:String in ["idle","walk","run","attack","hit","death"]:
   for facing:int in range(8):
    actor.motion.state=role;actor.motion.active=role=="attack";actor.motion.dead=role=="death";actor.motion.facing8=facing;actor.motion.state_clock=.12;actor.motion.gait=1;actor.motion.move_ratio=1.0 if role in ["walk","run"] else 0.0;actor.motion.visual_progress=.5;actor.motion.attack_duration=.8;actor.motion.attack_elapsed=.4;actor.motion.death_clock=.15;actor.motion.hit_clock=.08 if role=="hit" else 0
    actor.motion.apply(actor.sprite,actor.animation_base_scale)
    check(actor.motion._resolved_key==role+"_"+str(facing),"actual actor role/direction")
    if DisplayServer.get_name()!="headless":
     await process_frame;await RenderingServer.frame_post_draw
     var frame:Image=root.get_texture().get_image();check(not frame.is_empty(),"actual Main GPU readback")
  actor.motion.dead=false;actor.motion.state="idle";actor.motion.hit_clock=0;actor.motion.active=false
  world._deal_successful_player_hit(actor,actor.max_hp+1,false)
  check(actor.dead and slot.monster==null,"actual successful hit kills and releases source actor")
  if chosen.mode=="boss":
   var state:Dictionary=population.boss_director.state_for(str(chosen.map_id),slot.region)
   check(state.phase=="cooldown" and float(state.ready_at)>Time.get_unix_time_from_system()+800,"single named life enters persistent cooldown")
  else:
   var delay:float=slot.remaining;population._process(delay-.1);check(slot.monster==null,"no early respawn")
   for i:int in range(20):population._process(.4);await process_frame
   check(is_instance_valid(slot.monster) and not slot.monster.dead,"production respawn after declared delay")
  print("CATALOG_GAP_MAIN_SPECIES ",record.source_npc_id," ",record.name," map=",chosen.map_id)
 var before:int=world.field_population.slots.size();var back:String=world.active_map_id
 world._set_map("source_77",false);world.field_population.set_process(false)
 world._set_map(back,false);world.field_population.set_process(false)
 check(world.field_population.slots.size()==before,"map round trip does not duplicate habitats")
 check(world._save_game(true)==OK,"actual save after new habitats and named death")
 world.queue_free();await process_frame;await process_frame
 print("REVIEWED_CATALOG_GAPS_MAIN_RESULT checks=",checks," failures=",failures," species=",additions.records.size());quit(0 if failures==0 else 1)
