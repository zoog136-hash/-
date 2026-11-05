extends SceneTree
var world:Node
var failures:Array=[]
func _initialize()->void:call_deferred('run')
func check(ok:bool,name:String)->void:
 if not ok:failures.append(name);printerr('MAIN_EDGE_FAIL ',name)
func run()->void:
 root.size=Vector2i(1280,720)
 var save_paths:Array=['user://twilight_v20_save.json','user://twilight_native_png_save.json']
 var save_hashes:Dictionary={}
 for path:String in save_paths:save_hashes[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ''
 var scene=load('res://Main.tscn');assert(scene!=null)
 world=scene.instantiate()
 if world.get_script()==null:printerr('Main script unavailable');quit(1);return
 root.add_child(world)
 var qa=load('res://tests/qa_class_selection.gd')
 check(qa.enter_game(world),'class selection')
 for i:int in range(8):await physics_frame
 var field=world.field_map
 check(field!=null and field.get_script().resource_path.ends_with('base508_source_edge_field.gd'),'actual Main source field')
 if field==null:quit(1);return
 check(world.active_map_id==field.source_pack.source_map_key()+'_edge_review','source map identity')
 check(world.player.global_position.distance_to(field.source_to_world(Vector2(field.source_navigation.arrival)))<1,'exact source arrival')
 check(world.player.get_node('CollisionShape2D').shape is CircleShape2D and world.player.get_node('CollisionShape2D').shape.radius==4,'real Player foot')
 check(world._save_game(true)==ERR_UNAVAILABLE,'save disabled')
 var before:Vector2=world.player.global_position
 var target:Vector2=Vector2.INF
 for offset:Vector2i in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
  var candidate_target:Vector2=field.source_to_world(Vector2(field.source_navigation.arrival+offset))
  if not world.find_world_path(before,candidate_target).is_empty():target=candidate_target;break
 check(target.is_finite(),'nearby source click destination')
 if not target.is_finite():world.queue_free();quit(1);return
 check(not world.find_world_path(before,target).is_empty(),'Main path')
 world._set_click_destination(target)
 for i:int in range(180):
  await physics_frame
  if world.player.global_position.distance_to(target)<6:break
 check(world.player.global_position.distance_to(target)<6,'actual Player click movement')
 var nav=field.source_navigation
 var route_count:int=0
 var sweep_steps:int=0
 var start:Vector2=nav.point(nav.arrival)
 world.player.set_physics_process(false)
 var review_ids:Array=[]
 var entry_component:bool='--base508-component-review' in OS.get_cmdline_user_args()
 if entry_component:
  var visited:Dictionary={nav.ids[nav.arrival]:true};review_ids=[nav.ids[nav.arrival]]
  for id:int in review_ids:
   for neighbor:int in nav.graph.get_point_connections(id):
    if not visited.has(neighbor):visited[neighbor]=true;review_ids.append(neighbor)
 else:
  for id:int in nav.graph.get_point_ids():review_ids.append(id)
 for direction:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  var target_id:int=-1;var best:float=-INF
  for id:int in review_ids:
   var score:float=nav.graph.get_point_position(id).dot(direction)
   if score>best:best=score;target_id=id
  var route:PackedVector2Array=field.path(start,nav.graph.get_point_position(target_id))
  check(not route.is_empty(),'whole-map route')
  world.player.position=start
  for waypoint:Vector2 in route:
   var delta:Vector2=waypoint-world.player.position
   var steps:int=maxi(1,ceili(delta.length()/2))
   for step:int in range(steps):
    var hit=world.player.move_and_collide(delta/steps)
    sweep_steps+=1
    if hit!=null:check(false,'whole-map physical obstruction');break
  check(world.player.position.distance_to(nav.graph.get_point_position(target_id))<0.2,'whole-map arrival')
  route_count+=1
 var blocked:int=0
 for segment:Array in nav.barriers:
  if blocked>=64:break
  var middle:Vector2=(segment[0]+segment[1])*0.5
  var normal:Vector2=(segment[1]-segment[0]).orthogonal().normalized()
  if not nav.safe(middle+normal*8):normal=-normal
  if not nav.safe(middle+normal*8):continue
  world.player.position=middle+normal*8
  check(world.player.move_and_collide(-normal*16)!=null,'closed edge physically blocks')
  blocked+=1
 check(blocked==64,'boundary sample count')
 world.player.position=start
 var candidate:Dictionary={}
 for record:Dictionary in field.source_pack.npc_territory_records():
  if not field.source_pack.is_explicit_spawn_disabled(record) and field.source_pack.npc_flags.get(int(record.npc_class_id)) is bool and field.source_pack.npc_flags.get(int(record.npc_class_id)):
   candidate=record;break
 if candidate.is_empty():print('MAIN_SOURCE_OCCUPANCY_UNAVAILABLE no original occupying class in this pack; no fabricated instance')
 if not candidate.is_empty():
  var occupancy_neighbor:Vector2=start
  for direction:Vector2i in nav.DIRS:
   if nav.edge(nav.arrival,nav.arrival+direction) and nav.safe(nav.point(nav.arrival+direction)):
    occupancy_neighbor=nav.point(nav.arrival+direction);break
  check(occupancy_neighbor!=start,'occupancy approach edge')
  check(not field.register_source_occupant('review',candidate,nav.arrival,2),'nonboolean placement rejected')
  check(field.register_source_occupant('review',candidate,nav.arrival,true),'confirmed test instance')
  check(not field.walkable(start),'occupied source cell blocked')
  var next_cell:Vector2i=Vector2i(nav.source(occupancy_neighbor).round())
  check(not field.relocate_source_occupant('review',candidate,next_cell,2),'unconfirmed relocation rejected')
  check(not field.walkable(start),'rejected relocation keeps old occupancy')
  check(field.relocate_source_occupant('review',candidate,next_cell,true),'confirmed relocation')
  check(field.walkable(start) and not field.walkable(occupancy_neighbor),'relocation updates source occupancy')
  await physics_frame
  world.player.position=start
  check(world.player.move_and_collide(occupancy_neighbor-start)!=null,'relocated occupant physically blocks new cell')
  check(field.relocate_source_occupant('review',candidate,nav.arrival,true),'restore original occupied cell')
  await physics_frame
  world.player.position=occupancy_neighbor
  check(world.player.move_and_collide(start-world.player.position)!=null,'occupied cell physically blocks')
  field.unregister_source_occupant('review')
  check(field.walkable(start),'removed occupancy restored')
  await physics_frame
  world.player.position=occupancy_neighbor
  check(world.player.move_and_collide(start-world.player.position)==null,'removed occupancy physics restored')
  var disabled:Dictionary=candidate.duplicate(true);disabled.is_spawn_raw=0
  check(not field.register_source_occupant('disabled',disabled,nav.arrival,true),'explicit disabled spawn rejected')
  for raw:Variant in [1,2,null]:
   var contextual:Dictionary=candidate.duplicate(true);contextual.is_spawn_raw=raw
   check(field.register_source_occupant('contextual',contextual,nav.arrival,true),'active conditional or unknown retained by zero-only policy')
   check(not field.register_source_occupant('contextual',disabled,nav.arrival,true),'disabled update rejected')
   check(not field.occupancy_shapes.has('contextual') and not field.source_pack.npc_instances.has('contextual') and field.walkable(start),'disabled instance occupancy and physics removed')
 for cell:Vector2i in nav.ids:
  check(Vector2(cell).distance_to(field.world_to_source(field.source_to_world(Vector2(cell))))<0.001,'coordinate round trip')
 print('MAIN_SOURCE_EDGE_COVERAGE ',JSON.stringify({'scope':'ENTRY_COMPONENT' if entry_component else 'WHOLE_GRAPH','review_cells':review_ids.size(),'routes':route_count,'physical_steps':sweep_steps,'blocked_edges':blocked,'coordinate_cells':nav.ids.size()}))
 print('MAIN_SOURCE_EDGE_RESULT ',JSON.stringify({'failures':failures,'start':[before.x,before.y],'end':[world.player.global_position.x,world.player.global_position.y],'map':world.active_map_id,'save_disabled':true}))
 if DisplayServer.get_name()!='headless' and not OS.get_environment('BASE508_MAIN_CAPTURE').is_empty():
  for i:int in range(30):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment('BASE508_MAIN_CAPTURE'))
 world.queue_free();await physics_frame
 var saves_unchanged:bool=true
 for path:String in save_paths:
  var after:String=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ''
  saves_unchanged=saves_unchanged and after==save_hashes[path]
  check(after==save_hashes[path],'save unchanged after scene exit')
 print('MAIN_SOURCE_EDGE_EXIT ',JSON.stringify({'failures':failures,'save_files_unchanged':saves_unchanged}))
 quit(0 if failures.is_empty() else 1)
