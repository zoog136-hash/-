extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("MAIN_STREAM_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate();world.active_map_id="source_77";root.add_child(world)
 check(QA.enter_game(world),"actual Main class entry")
 world.set_process(false);world.field_population.set_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000;world.portal_cooldown=100000
 await process_frame;await physics_frame
 var start:Vector2=world.player.global_position
 var landing:Vector2=Vector2.INF
 for offset:Vector2 in [Vector2(48,0),Vector2(-48,0),Vector2(0,48),Vector2(0,-48)]:
  var point:Vector2=start+offset
  if world.field_map.point_clear(point,6) and world.field_map.line_clear(start,point):landing=point;break
 check(landing.is_finite(),"real nearby walkable route")
 if landing.is_finite():
  var path:PackedVector2Array=world.find_world_path(start,landing)
  check(not path.is_empty(),"production source path")
  world.player.set_click_path(path,landing)
  for frame:int in range(90):
   await physics_frame
   if world.player.global_position.distance_to(landing)<5:break
  check(world.player.global_position.distance_to(start)>12 and world.field_map.point_clear(world.player.global_position,4),"actual Player moves on admitted collision")
 world.player.clear_click_path();world.player.set_physics_process(false)
 var source_state:Dictionary={}
 var captures:Array=[]
 for id:String in ["source_77","source_78","source_77","aden_world","source_77"]:
  world._set_map(id,false);world.field_population.set_process(false);world.portal_cooldown=100000
  check(world.active_map_id==id and world.field_renderer.get_script().resource_path=="res://scripts/maps/source_map_runtime_renderer.gd","real Main source renderer "+id)
  check(not world.field_renderer.chunks.is_empty() and not world.field_renderer.waiting_for_visible,"first entry has required textures "+id)
  check(world.field_renderer.failure.is_empty(),"no render failure "+id)
  for frame:int in range(240):
   await process_frame
   if not world.field_renderer.waiting_for_visible and int(world.field_renderer.texture_store.stats().pending)==0:break
  check(not world.field_renderer.waiting_for_visible,"async work settles "+id)
  check(int(world.field_renderer.texture_store.stats().idle_bytes)<=64*1024*1024,"idle texture budget "+id)
  check(world.field_map.point_clear(world.player.global_position,4),"player entry clearance "+id)
  var identity:Dictionary={"grid":world.field_map.definition.source_sha256,"layout":world.field_map.data.layout_revision,"portals":world.field_map.data.portal.duplicate(true),"doors":world.field_map.local_door_states.duplicate(true)}
  if source_state.has(id):check(source_state[id]==identity,"round trip preserves collision/portal/door identity "+id)
  source_state[id]=identity;captures.append({"map":id,"stats":world.field_renderer.texture_store.stats()})
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   check(not root.get_texture().get_image().is_empty(),"real Main viewport readback "+id)
 world.gold=543210;check(world._save_game(true)==OK,"Main save after repeated map transitions")
 world.gold=1;world._load_game(true)
 check(world.gold==543210 and world.active_map_id=="source_77" and not world.source_save_blocked,"real save/load after stream round trip")
 print("SOURCE84_MAIN_STREAM_RESULT checks=",checks," errors=",errors," maps=",JSON.stringify(captures))
 world.queue_free();await process_frame;await process_frame
 quit(0 if errors==0 else 1)
