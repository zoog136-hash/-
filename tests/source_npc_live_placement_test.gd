extends SceneTree
const NPC=preload("res://scripts/npc/source_npc_catalog.gd")
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var errors:Array[String]=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors.append(label);printerr("NPC_LIVE_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
 check(QA.enter_game(world),"real class confirmation")
 world.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 if "--restart-check" in OS.get_cmdline_user_args():
  var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
  print("NPC_RESTART_STATE actual=",JSON.stringify(NPC.export_state())," saved=",JSON.stringify(saved.source_npc_state))
  check(int(saved.source_npc_state.schema)==1 and NPC.export_state().placements==saved.source_npc_state.placements,"fresh process restores exact random source placement")
  check(world.gold==7654321,"fresh process retains actual character save")
  await finish(world);return
 var before:Dictionary=world.inventory.duplicate(true);var before_gold:int=world.gold;var count:int=0
 for mid:String in ["aden_world","source_77"]:
  world._set_map(mid,false);world.field_population.set_process(false);world.portal_cooldown=100000
  check(world.active_map_id==mid and world.field_map.get_meta("source_map84",false),"actual admitted field "+mid)
  print("NPC_LIVE_PROGRESS loaded=",mid)
  var source_rows:Array=world.field_map.data.npc_spawn.filter(func(r):return r.has("source_catalog_id"))
  check(source_rows.size()==(5 if mid=="aden_world" else 1),"exact installed six, no preview injection")
  for spawn:Dictionary in source_rows:
   var id:String=spawn.source_catalog_id;var n:Dictionary=NPC.record(id);var p:Vector2=Vector2(spawn.position[0],spawn.position[1]);var original:Dictionary=n.spawns[0]
   check(spawn.source_position==original.source_position,"original source coordinate preserved "+id)
   check(world.field_map.point_clear(p,6),"six pixel foot clearance "+id)
   check(NPC._within_source_offsets(spawn.runtime_source_position,original),"exact fixed anchor or bounded original random offsets "+id)
   check(world.field_map.coordinates.to_world(Vector2(spawn.runtime_source_position[0],spawn.runtime_source_position[1]))==p,"actual source projection "+id)
   var approach:Vector2=Vector2.INF
   for dy:int in range(-4,5):
    for dx:int in range(-4,5):
     var q:Vector2=world.field_map.coordinates.to_world(Vector2(spawn.runtime_source_position[0]+dx,spawn.runtime_source_position[1]+dy))
     if q.distance_to(p)>45 and q.distance_to(p)<150 and world.field_map.point_clear(q,6) and world.field_map.line_clear(q,p):approach=q
   check(approach.is_finite(),"actual safe interaction approach "+id)
   if not approach.is_finite():continue
   world.player.global_position=approach;world.player.camera.reset_smoothing();world.field_renderer.refresh_visible()
   await process_frame;await process_frame
   check(NPC.nearby(world,id),"actual 190px proximity accepts "+id)
   var marker:Node=world.field_renderer.source_markers.get("npc_spawn:"+id)
   check(marker!=null,"real streamed actor marker "+id)
   var live_actor:Node=null
   if marker!=null:
    for child:Node in marker.get_children():
     if child.get_script()==preload("res://scripts/npc/source_npc_actor.gd"):live_actor=child
   check(live_actor!=null and live_actor.feet==spawn.foot_pixels,"actual reviewed feet and exact native art "+id)
   if live_actor!=null:
    var initial:int=live_actor.frame_index;live_actor._process(float(n.visual.seconds_per_frame)*1.1);check(live_actor.frame_index!=initial,"real idle advances "+id)
   for repeat:int in range(2):
    world._set_click_destination(p);await process_frame
    if n.has_verified_normal_dialogue:
     check(world.hud.active_section=="dialogue","real NPC opens approved text "+id)
     var text:Dictionary=world.dialogue_service.resolve(id,"",world._npc_dialogue_state());check(text.ok and text.choices.is_empty(),"no invented services or rewards "+id)
     world.hud._close_workspace();check(not world.hud.workspace.visible,"real dialogue closes "+id)
    else:check(world.hud.active_section!="dialogue","display-only NPC cannot borrow adjacent dialogue "+id)
   var capture:String=OS.get_environment("TWILIGHT_NPC_LIVE_CAPTURES")
   if not capture.is_empty():
    DirAccess.make_dir_recursive_absolute(capture);await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(capture+"/"+id+".png")==OK,"actual placement viewport "+id)
   world.player.global_position=p+Vector2(400,0);check(not NPC.nearby(world,id),"distance rejection "+id)
   if n.has_verified_normal_dialogue:check(not world.dialogue_service.resolve(id,"",world._npc_dialogue_state()).ok,"far dialogue rejected "+id)
   count+=1
   print("NPC_LIVE_PROGRESS visited=",id)
 check(count==6,"all six real map placements visited")
 check(world.gold==before_gold and world.inventory==before,"interaction preserves economy")
 var random_id:String="l1j_tw380_npc_71094";var old_state:Dictionary=NPC.export_state();var samples:Dictionary={};var field=RUN.load_field("aden_world")
 for i:int in range(24):
  field.data.npc_spawn=field.data.npc_spawn.filter(func(r):return str(r.get("source_catalog_id",""))!=random_id)
  NPC.placements.erase(random_id);check(NPC.append_to_field(field).is_empty(),"random placement remains admissible")
  samples[JSON.stringify(NPC.placements[random_id].source_position)]=true
 check(samples.size()>1,"Endia chooses real varied positions, never a fixed anchor")
 field.close();NPC.import_state(old_state)
 var invalid:Dictionary=old_state.duplicate(true);invalid.placements[random_id].source_position=[0,0]
 check(not NPC.validate_state(invalid).is_empty(),"corrupt random save rejected before live mutation")
 world._set_map("aden_world",false);world.player.global_position=Vector2(world.field_map.data.spawn_position[0],world.field_map.data.spawn_position[1]);world.gold=7654321
 check(world._save_game(true)==OK,"real source NPC placement save")
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
 check(NPC.validate_state(saved.source_npc_state).is_empty(),"bounded random state only, valid save")
 var expected:Dictionary=NPC.export_state();NPC.placements.clear();world._load_game(true)
 check(NPC.export_state()==expected and world.gold==7654321,"actual load restores same position and progress")
 print("NPC_LIVE_PROGRESS saved_and_reloaded=true starting_restart")
 var output:Array=[];var code:int=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/source_npc_live_placement_test.gd","--","--restart-check"],output,true)
 check(code==0,"independent restart process")
 for line:Variant in output:print(line)
 await finish(world)
func finish(world:Node):
 world.queue_free();await process_frame;await process_frame
 print("SOURCE_NPC_LIVE_RESULT checks=",checks," failures=",errors.size()," actual_placement=6/6")
 quit(0 if errors.is_empty() else 1)
