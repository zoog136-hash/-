extends SceneTree
## Explicit experiment, NOT a recovered M passability rule or production navigation.
## Reads both original halfwords; no old PNG polygons, guessed height, or save access.
const PACK=preload('res://scripts/maps/base508_pack.gd')
const SPACE=preload('res://scripts/maps/base508_contract.gd')
const IDENTITIES={13398:47914,13401:48274,13472:48774,13504:49324}
const ARRIVALS={13398:43661,13401:43674,13472:43854,13504:44054}
const DIRECTIONS=[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
var pack=PACK.new()
var words:Dictionary={}
var ids:Dictionary={}
var graph:=AStar2D.new()
var holder:=Node2D.new()
var actor:=CharacterBody2D.new()
var records:Dictionary={}
var diagonal_edges:int=0
func _initialize()->void:call_deferred('run')
func point(cell:Vector2i)->Vector2:
 return SPACE.visual_cell_center(pack.manifest,Vector2(cell))
func open_edge(a:Vector2i,b:Vector2i)->bool:
 if not words.has(a) or not words.has(b):return false
 var d:Vector2i=b-a
 if d==Vector2i.RIGHT:return words[a][1]==0
 if d==Vector2i.DOWN:return words[b][0]==0
 if d==Vector2i.LEFT:return words[b][1]==0
 if d==Vector2i.UP:return words[a][0]==0
 return false
func boundary(body:StaticBody2D,a:Vector2i,d:Vector2i)->void:
 var middle:Vector2=(point(a)+point(a+d))*0.5
 var tangent:Vector2=Vector2(12,6) if d.x!=0 else Vector2(12,-6)
 var shape:=SegmentShape2D.new();shape.a=middle-tangent;shape.b=middle+tangent
 var node:=CollisionShape2D.new();node.shape=shape;body.add_child(node)
func run()->void:
 assert('--source-edge-experiment' in OS.get_cmdline_user_args(),'Explicit experimental mode required')
 var asset:int=int(OS.get_environment('TWILIGHT_EDGE_ASSET'))
 assert(IDENTITIES.has(asset),'Unreviewed source identity')
 var folder:String=OS.get_environment('TWILIGHT_BASE508_UNIVERSE')+'/assets/base508_asset_'+str(asset)
 assert(pack.load_pack(folder,IDENTITIES[asset]),pack.error)
 assert(str(pack.manifest.land.AssetPath)==str(asset)+'/')
 for chunk:Dictionary in pack.geometry.values():
  var raw:PackedByteArray=Marshalls.base64_to_raw(chunk.attribute_u16le)
  assert(raw.size()==16384)
  var origin:=Vector2i(chunk.origin[0],chunk.origin[1])
  for y:int in range(64):
   for x:int in range(64):
    var offset:int=(y*128+x*2)*2
    var pair:Array=[raw.decode_u16(offset),raw.decode_u16(offset+2)]
    assert(pair[0] in [0,1] and pair[1] in [0,1],'Unknown attribute: refuse experiment')
    words[origin+Vector2i(x,y)]=pair
 for cell:Vector2i in words:
  for d:Vector2i in DIRECTIONS:
   if open_edge(cell,cell+d):
    ids[cell]=ids.size();graph.add_point(ids[cell],point(cell));break
 for cell:Vector2i in ids:
  for d:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
   if open_edge(cell,cell+d):graph.connect_points(ids[cell],ids[cell+d],true)
 # Diagonals require both orthogonal routes, preventing a corner shortcut.
 for cell:Vector2i in ids:
  for dy:int in [-1,1]:
   var horizontal:Vector2i=cell+Vector2i.RIGHT
   var vertical:Vector2i=cell+Vector2i(0,dy)
   var target:Vector2i=cell+Vector2i(1,dy)
   if open_edge(cell,horizontal) and open_edge(cell,vertical) and open_edge(horizontal,target) and open_edge(vertical,target):
    graph.connect_points(ids[cell],ids[target],true);diagonal_edges+=1
 root.add_child(holder)
 var body:=StaticBody2D.new();body.collision_layer=4;holder.add_child(body)
 var closed_edges:Array=[]
 for cell:Vector2i in ids:
  for d:Vector2i in DIRECTIONS:
   if not open_edge(cell,cell+d):
    if ids.has(cell+d) and (d==Vector2i.LEFT or d==Vector2i.UP):continue
    boundary(body,cell,d);closed_edges.append([cell,cell+d])
 actor.collision_layer=1;actor.collision_mask=4;actor.safe_margin=0.001
 var foot:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=4;foot.shape=circle;actor.add_child(foot);holder.add_child(actor)
 await physics_frame;await physics_frame
 # Exact source arrival record; no region midpoint or nearest-cell fallback.
 var locations_file:String=OS.get_environment('TWILIGHT_BASE508_TABLES')+'/Locations.json'
 var location_table:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(locations_file))
 var arrival:Dictionary={}
 for row:Dictionary in location_table.rows:
  if int(row.ID)==ARRIVALS[asset]:assert(arrival.is_empty());arrival=row
 assert(not arrival.is_empty() and int(arrival.LandID)==IDENTITIES[asset])
 var arrival_cell:=Vector2i(arrival.X,arrival.Y)
 assert(ids.has(arrival_cell),'Original arrival blocked by candidate; do not project it elsewhere')
 var entry:Dictionary=source_entry(IDENTITIES[asset],int(arrival.ID))
 var seed:int=ids[arrival_cell]
 var connected:Dictionary={seed:true};var queue:Array=[seed]
 for id:int in queue:
  for neighbor:int in graph.get_point_connections(id):
   if not connected.has(neighbor):connected[neighbor]=true;queue.append(neighbor)
 var targets:Array=[]
 for direction:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  var best:int=seed;var score:float=-INF
  for id:int in queue:
   var value:float=graph.get_point_position(id).dot(direction)
   if value>score:score=value;best=id
  targets.append(best)
 var routes:Array=[];var failures:Array=[]
 for target:int in targets:
  actor.position=graph.get_point_position(seed)
  var route:PackedVector2Array=graph.get_point_path(seed,target)
  var distance:float=0.0;var stopped:bool=false
  for next:Vector2 in route:
   for step:int in range(100):
    var delta:Vector2=next-actor.position
    if delta.length()<0.05:break
    var before:Vector2=actor.position
    if actor.move_and_collide(delta.limit_length(2))!=null:stopped=true;break
    distance+=before.distance_to(actor.position)
   if stopped:break
  var reached:bool=not stopped and actor.position.distance_to(graph.get_point_position(target))<0.1
  routes.append({'target_source_node':target,'target_source_cell':source_for_id(target),'waypoints':route.size(),'distance_pixels':distance,'reached':reached,'final':[actor.position.x,actor.position.y]})
  if not reached:failures.append('candidate route hit candidate physics')
  if not OS.get_environment('TWILIGHT_EDGE_CAPTURE').is_empty():await capture_route(asset,routes.size(),route)
 var blocked:int=0;var misses:int=0
 for index:int in range(0,closed_edges.size(),maxi(1,closed_edges.size()/1000)):
  var edge:Array=closed_edges[index];actor.position=point(edge[0])
  if actor.test_move(actor.global_transform,point(edge[1])-actor.position):blocked+=1
  else:misses+=1
 if misses:failures.append('closed edge physics missed')
 records={'asset':asset,'land':IDENTITIES[asset],'original_arrival':arrival,'original_item_entry':entry,'locations_sha256':FileAccess.get_sha256(locations_file),'status':'EXPERIMENT_NOT_NATIVE_M_APPROVAL','source_halfword_policy':'candidate: zero opens directional edge; one closes; no PC zone conversion','height':'UNINTERPRETED','foot_anchor':'explicit visual cell center, original M anchor unverified','foot_radius':4,'source_cells':words.size(),'candidate_nodes':ids.size(),'component_nodes':queue.size(),'diagonal_edges_with_both_orthogonal_routes':diagonal_edges,'boundary_segments':closed_edges.size(),'closed_edge_body_hits':blocked,'closed_edge_body_misses':misses,'routes':routes,'failures':failures,'native_terrain_enabled':false,'automatic_portals_enabled':false,'saves_accessed':false}
 var out:String=OS.get_environment('TWILIGHT_EDGE_OUTPUT');assert(not out.is_empty())
 var file=FileAccess.open(out,FileAccess.WRITE);file.store_string(JSON.stringify(records,'  '));file.close()
 print('SOURCE_EDGE_EXPERIMENT ',JSON.stringify(records))
 if '--interactive' in OS.get_cmdline_user_args() and failures.is_empty():await interactive_walk(seed)
 holder.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

func source_for_id(id:int)->Array:
 for cell:Vector2i in ids:
  if ids[cell]==id:return [cell.x,cell.y]
 return []

func capture_route(asset:int,index:int,route:PackedVector2Array)->void:
 assert(DisplayServer.get_name()!='headless','Capture needs real rendering')
 root.size=Vector2i(1280,720)
 var canvas:=Node2D.new();holder.add_child(canvas)
 var camera:=Camera2D.new();camera.position=actor.position;canvas.add_child(camera);camera.make_current()
 var view:=Rect2(actor.position-Vector2(640,360),Vector2(1280,720))
 for row:Dictionary in pack.manifest.art.chunks:
  if not Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1])).intersects(view):continue
  var filename:String=pack.safe_file(row.file)
  assert(FileAccess.get_sha256(filename)==row.sha256)
  var image=Image.load_from_file(filename);assert(image!=null)
  var sprite:=Sprite2D.new();sprite.centered=false;sprite.position=Vector2(row.position[0],row.position[1]);sprite.texture=ImageTexture.create_from_image(image);canvas.add_child(sprite)
 var trail:=Line2D.new();trail.points=route;trail.width=2;trail.default_color=Color.CYAN;canvas.add_child(trail)
 var marker:=Polygon2D.new();marker.polygon=PackedVector2Array([Vector2(0,-18),Vector2(7,-5),Vector2(4,0),Vector2(-4,0),Vector2(-7,-5)]);marker.color=Color.YELLOW;marker.position=actor.position;canvas.add_child(marker)
 var ui:=CanvasLayer.new();canvas.add_child(ui);var label:=Label.new();label.position=Vector2(12,12);label.add_theme_color_override('font_shadow_color',Color.BLACK);label.add_theme_constant_override('shadow_offset_x',2);label.add_theme_constant_override('shadow_offset_y',2);label.text='SOURCE EDGE EXPERIMENT | Land %s / Asset %s | Route %s\nActual radius-4 body sweep; cyan route; no legacy polygons\nNOT native M collision approval | height/foot/trigger meanings unverified' % [IDENTITIES[asset],asset,index];ui.add_child(label)
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(OS.get_environment('TWILIGHT_EDGE_CAPTURE')+'-'+str(index)+'.png')==OK)
 canvas.queue_free();await process_frame

func interactive_walk(seed:int)->void:
 assert(DisplayServer.get_name()!='headless','Interactive review requires a display')
 Engine.max_fps=30;root.size=Vector2i(1280,720)
 actor.position=graph.get_point_position(seed)
 var camera:=Camera2D.new();holder.add_child(camera);camera.make_current()
 var marker:=Polygon2D.new();marker.polygon=PackedVector2Array([Vector2(0,-18),Vector2(7,-5),Vector2(4,0),Vector2(-4,0),Vector2(-7,-5)]);marker.color=Color.YELLOW;marker.z_index=10;actor.add_child(marker)
 var ui:=CanvasLayer.new();holder.add_child(ui);var label:=Label.new();label.position=Vector2(12,12);ui.add_child(label)
 var sprites:Dictionary={};var path:PackedVector2Array=[];var mouse_was_down:bool=false;var frames:int=0;var moved:float=0
 while not Input.is_key_pressed(KEY_ESCAPE):
  await physics_frame
  camera.position=actor.position
  var view:=Rect2(actor.position-Vector2(768,488),Vector2(1536,976));var wanted:Dictionary={}
  for row:Dictionary in pack.manifest.art.chunks:
   if Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1])).intersects(view):wanted[row.file]=row
  for key:String in sprites.keys():
   if not wanted.has(key):sprites[key].queue_free();sprites.erase(key)
  for key:String in wanted:
   if sprites.has(key):continue
   var row:Dictionary=wanted[key];var filename:String=pack.safe_file(key)
   assert(FileAccess.get_sha256(filename)==row.sha256)
   var image=Image.load_from_file(filename);assert(image!=null)
   var sprite:=Sprite2D.new();sprite.centered=false;sprite.z_index=-5;sprite.position=Vector2(row.position[0],row.position[1]);sprite.texture=ImageTexture.create_from_image(image);holder.add_child(sprite);sprites[key]=sprite;break
  var mouse_down:bool=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
  if mouse_down and not mouse_was_down:
   var target:Vector2=holder.get_global_mouse_position();var goal:int=graph.get_closest_point(target)
   if graph.get_point_position(goal).distance_to(target)<=32:path=graph.get_point_path(graph.get_closest_point(actor.position),goal)
  mouse_was_down=mouse_down
  var direction:=Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
  if direction!=Vector2.ZERO:path=[]
  var motion:Vector2=direction.normalized()*120.0/Engine.physics_ticks_per_second
  if not path.is_empty():
   var delta:Vector2=path[0]-actor.position
   if delta.length()<0.1:path.remove_at(0)
   else:motion=delta.limit_length(120.0/Engine.physics_ticks_per_second)
  if '--interactive-smoke' in OS.get_cmdline_user_args():motion=Vector2.RIGHT if frames<30 else Vector2.LEFT
  var before:Vector2=actor.position
  if actor.move_and_collide(motion)!=null:path=[]
  moved+=before.distance_to(actor.position)
  label.text='SOURCE EDGE EXPERIMENT | %s | WASD / click path / Esc\nNo legacy collision. M height, actor depth and triggers UNVERIFIED.\nActual body movement %.1f px | source display (%.1f, %.1f)' % [pack.manifest.land.Name,moved,actor.position.x,actor.position.y]
  frames+=1
  if '--interactive-smoke' in OS.get_cmdline_user_args() and frames>=60:
   print('SOURCE_EDGE_INTERACTIVE_SMOKE ',JSON.stringify({'frames':frames,'distance_pixels':moved,'resident_source_chunks':sprites.size(),'native_M_approved':false}));break

func source_rows(table:String)->Array:
 var filename:String=OS.get_environment('TWILIGHT_BASE508_TABLES')+'/'+table+'.json'
 var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(filename))
 assert(document.get('rows') is Array,'Missing original '+table)
 return document.rows

func source_entry(land:int,location:int)->Dictionary:
 var quick:Dictionary={}
 for row:Dictionary in source_rows('UIMapQuickTeleportOman'):
  if int(row.LandID)==land:assert(quick.is_empty());quick=row
 assert(not quick.is_empty(),'No original quick-entry item')
 var kind:int=-1
 for row:Dictionary in source_rows('BonusType'):
  if str(row.Name)=='TeleportToLocation':assert(kind==-1);kind=int(row.ID)
 assert(kind>=0)
 var bonuses:Dictionary={}
 for row:Dictionary in source_rows('Bonus'):bonuses[int(row.ID)]=row
 var matches:Array=[]
 for row:Dictionary in source_rows('ItemBonus'):
  if int(row.ItemClassID)!=int(quick.ItemClassID):continue
  var bonus:Dictionary=bonuses.get(int(row.BonusID),{})
  if int(bonus.get('BonusTypeID',-1))==kind:
   assert(int(bonus.Value)==location,'Entry destination disagrees with source Land')
   matches.append({'item_bonus':row,'bonus':bonus})
 assert(matches.size()==1,'Ambiguous original entry')
 return {'quick_teleport':quick,'teleport_bonus':matches[0],'activation':'REVIEW_SELECTION_ONLY; ownership/cost/conditions not consumed or inferred'}
