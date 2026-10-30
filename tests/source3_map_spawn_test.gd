extends SceneTree
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const SPAWN=preload("res://scripts/maps/source_map_spawns.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("SOURCE_SPAWN_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var total:int=0
 var slots:int=0
 var held:int=0
 var chosen:Dictionary={}
 var maps:Array=RUN.policy().keys() if "--all-maps" in OS.get_cmdline_user_args() else ["source_440","source_0","source_783","source_303","source_69","aden_world"]
 if "--runtime-only" in OS.get_cmdline_user_args():maps=["source_440"]
 for mid:String in maps:
  var field=RUN.load_field(mid)
  check(field!=null,"verified field "+mid)
  if field==null:continue
  var ids:Dictionary={}
  for region:Dictionary in field.data.monster_spawn:
   check(not ids.has(str(region.id)),"unique region "+str(region.id));ids[str(region.id)]=true
   if not region.has("source_game_id"):continue
   total+=1;slots+=int(region.max_count)
   var cells:PackedInt32Array=field.region_cells[region.id]
   check(not cells.is_empty(),"admitted floor "+str(region.id))
   var random:=RandomNumberGenerator.new();random.seed=123
   for i:int in range(3):
    var p:Vector2=field.sample_spawn(str(region.id),random)
    check(p.is_finite() and SPAWN.floor_allowed(field,p),"safe original floor "+str(region.id))
    var source:Vector2=field.coordinates.to_source(p).floor()
    var a:Array=region.source_bounds
    check(source.x>=a[0] and source.x<=a[2] and source.y>=a[1] and source.y<=a[3],"exact source bounds")
   if mid=="source_440" and chosen.is_empty():chosen={"map":mid,"region":region.duplicate(true),"point":field.sample_spawn(str(region.id),random)}
  held+=field.get_meta("source_spawn_holds",[]).size()
  print("SOURCE_SPAWN_MAP ",mid," admitted=",field.data.monster_spawn.filter(func(r):return r.has("source_game_id")).size()," holds=",field.get_meta("source_spawn_holds",[]).size())
  field.close()
 if "--geometry-only" in OS.get_cmdline_user_args():
  print("SOURCE3_MAP_SPAWN_GEOMETRY checks=",checks," errors=",errors," admitted_rows=",total," slots=",slots," floor_holds=",held)
  quit(0 if errors==0 else 1);return
 check(total>0 and not chosen.is_empty(),"actual rows admitted")
 if not chosen.is_empty():
  var world:TwilightWorld=load("res://Main.tscn").instantiate();world.active_map_id=chosen.map;root.add_child(world)
  check(QA.enter_game(world),"actual Main entry")
  world.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.field_population.set_process(false);world.save_timer=-100000;world.portal_cooldown=100000
  world.player.global_position=chosen.point
  var population:FieldPopulation=world.field_population
  for i:int in range(40):population._process(.4);await process_frame
  var slot:Dictionary={}
  for candidate:Dictionary in population.slots:
   if str(candidate.region.id)==str(chosen.region.id):slot=candidate;break
  check(not slot.is_empty() and is_instance_valid(slot.get("monster")),"source actor spawned on real entry")
  if not slot.is_empty() and is_instance_valid(slot.get("monster")):
   var actor:TwilightMonster=slot.monster
   check(actor.get_meta("source_game_id","")==chosen.region.source_game_id,"exact source identity")
   check(SPAWN.floor_allowed(world.field_map,actor.home_position),"actual actor floor")
   check(not bool(actor.ai.get("aggressive",true)),"source passive animal stays passive")
   world._deal_successful_player_hit(actor,actor.max_hp+1,false)
   check(actor.dead and slot.monster==null,"actual kill releases slot")
   var delay:float=slot.remaining
   check(delay>=float(slot.region.source_respawn_seconds[0]) and delay<=float(slot.region.source_respawn_seconds[1]),"source respawn interval")
   population._process(delay-.1);check(slot.monster==null,"no early respawn")
   population._process(.2)
   for i:int in range(20):population._process(.4);await process_frame
   check(is_instance_valid(slot.monster) and not slot.monster.dead,"production clock respawns actor")
  var count:int=population.slots.size()
  var portal:Dictionary=world.field_map.data.portal[0]
  world.player.global_position=Vector2(portal.position[0],portal.position[1]);world.portal_cooldown=0
  check(world.use_field_portal(str(portal.id)) and world.active_map_id=="aden_world","real source return portal")
  world.field_population.set_process(false)
  check(world.field_map.point_clear(world.player.global_position,4),"real portal landing clearance")
  world._set_map(str(chosen.map),false);world.field_population.set_process(false)
  check(world.field_population.slots.size()==count,"round trip no duplicate slots")
  check(world.field_map.point_clear(world.player.global_position,4),"round trip entry collision")
  world.queue_free();await process_frame;await process_frame
 print("SOURCE3_MAP_SPAWN_RESULT checks=",checks," errors=",errors," admitted_rows=",total," slots=",slots," floor_holds=",held)
 quit(0 if errors==0 else 1)
