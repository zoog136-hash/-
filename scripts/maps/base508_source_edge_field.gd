extends 'res://scripts/maps/native_png_field.gd'
## Source-only opt-in Main field. This is explicit compatibility, not native-M approval.
const EDGE_NAV=preload('res://scripts/maps/base508_source_navigation.gd')
var source_navigation:RefCounted
var source_pack:RefCounted
var physics_body:StaticBody2D
var occupancy_shapes:Dictionary={}
func configure_edges(pack:RefCounted,tables:String,review_entry:Dictionary={})->bool:
 source_navigation=EDGE_NAV.new();source_pack=pack
 if not source_navigation.configure(pack,tables,review_entry):return false
 var art:Dictionary=pack.manifest.art
 bounds=Rect2(0,0,art.size[0],art.size[1]);cell_size=1;clearance=4
 var contract:Dictionary=pack.geographic_contract();width=int(contract.source_cell_bounds[2])-source_navigation.source_origin.x+1;height=int(contract.source_cell_bounds[3])-source_navigation.source_origin.y+1
 astar=AStarGrid2D.new();astar.region=Rect2i(0,0,width,height);astar.update();astar.fill_solid_region(astar.region,true)
 reachable=PackedByteArray();reachable.resize(width*height)
 var start:int=source_navigation.ids[source_navigation.arrival];var visited:Dictionary={start:true};var queue:Array=[start]
 for id:int in queue:
  for neighbor:int in source_navigation.graph.get_point_connections(id):
   if not visited.has(neighbor):visited[neighbor]=true;queue.append(neighbor)
 for cell:Vector2i in source_navigation.ids:
  var local:Vector2i=cell-source_navigation.source_origin;astar.set_point_solid(local,false)
  if visited.has(source_navigation.ids[cell]):reachable[local.y*width+local.x]=1
 var spawn:Vector2=source_navigation.point(source_navigation.arrival)
 data={'map_id':pack.source_map_key()+'_edge_review','map_name':str(pack.manifest.land.Name)+' · 원본 경계 검토','short_name':str(pack.manifest.land.Name),'bounds':[0,0,bounds.size.x,bounds.size.y],'spawn_position':[spawn.x,spawn.y],'navigation':{'cell_size':1,'clearance':4,'use_baked_cache':false},'streaming':{'chunk_size':1024,'margin':256,'monster_sleep_distance':2100},'camera':{'zoom':1.0,'offset':[0,0],'follow_speed':7},'collision':[],'monster_spawn':[],'npc_spawn':[],'portal':[],'teleport':[],'regions':[],'surfaces':[],'roads':[],'water':[],'props':[],'bridges':[],'safe_zone':[],'combat_zone':[],'boss_zone':[],'route_checks':[],'blocked_probes':[],'minimap':{'title':pack.manifest.land.Name},'collision_scope':'SOURCE_EDGE_COMPATIBILITY; NATIVE_M_UNVERIFIED','layout_revision':2026110201,'population_status':'NO_INFERRED_ORIGINAL_SPAWNS'}
 png_manifest={};png_root=pack.root;set_meta('base508_source_test',true)
 return line_clear(spawn,spawn)
func prepare_precise_routes_step(_max_cells:int=256,_max_usec:int=2000)->bool:return true
func park_precise_routes()->void:pass
func world_to_cell(p:Vector2)->Vector2i:return Vector2i(source_navigation.source(p).round())-source_navigation.source_origin
func cell_to_world(cell:Vector2i)->Vector2:return source_navigation.point(cell+source_navigation.source_origin)
func walkable(p:Vector2)->bool:return source_navigation.safe(p)
func point_clear(p:Vector2,padding:float=4)->bool:return source_navigation.safe(p,padding)
func line_clear(a:Vector2,b:Vector2)->bool:return source_navigation.clear(a,b)
func path(a:Vector2,b:Vector2)->PackedVector2Array:return source_navigation.route(a,b)
func nearest_cell(p:Vector2)->Vector2i:return world_to_cell(p) if walkable(p) else Vector2i(-1,-1)
func nearest_safe_click_destination(p:Vector2,_max_radius_cells:int=4)->Vector2:return p if walkable(p) else Vector2.INF
func build_physics(parent:Node2D)->StaticBody2D:
 physics_body=StaticBody2D.new();physics_body.name='Base508SourceEdges';physics_body.collision_layer=4;physics_body.collision_mask=0;parent.add_child(physics_body)
 for edge:Array in source_navigation.barriers:
  var segment:=SegmentShape2D.new();segment.a=edge[0];segment.b=edge[1]
  var shape:=CollisionShape2D.new();shape.shape=segment;physics_body.add_child(shape)
 return physics_body
func source_to_world(cell:Vector2)->Vector2:return source_pack.COORDINATE_CONTRACT.visual_cell_center(source_pack.manifest,cell)
func world_to_source(p:Vector2)->Vector2:return source_navigation.source(p)
func overview_texture()->Texture2D:
 var art:Dictionary=source_pack.manifest.art;var file:String=source_pack.safe_file(art.overview)
 if FileAccess.get_sha256(file)!=art.overview_sha256:return null
 return ImageTexture.create_from_image(Image.load_from_file(file))
func portal_evidence()->Array:return [] # Faith uses item→Location entries, not invented floor portals.
func register_source_occupant(instance:String,record:Dictionary,cell:Vector2i,placement_confirmed:Variant)->bool:
 if not is_instance_valid(physics_body) or occupancy_shapes.has(instance):return false
 if not source_pack.register_source_npc_instance(instance,record,cell,placement_confirmed):return false
 var center:Vector2=source_to_world(Vector2(cell));var shape:=CollisionPolygon2D.new()
 shape.polygon=PackedVector2Array([center+Vector2(-24,0),center+Vector2(0,-12),center+Vector2(24,0),center+Vector2(0,12)])
 physics_body.add_child(shape);occupancy_shapes[instance]=shape;return true
func unregister_source_occupant(instance:String)->void:
 source_pack.unregister_npc_occupancy(instance)
 if occupancy_shapes.has(instance):
  var shape:Node=occupancy_shapes[instance]
  physics_body.remove_child(shape);shape.queue_free();occupancy_shapes.erase(instance)

func relocate_source_occupant(instance:String,record:Dictionary,cell:Vector2i,placement_confirmed:Variant)->bool:
 # Validate first: failed updates preserve both the old source cell and collider.
 if not is_instance_valid(physics_body) or not occupancy_shapes.has(instance):return false
 if not source_pack.register_source_npc_instance(instance,record,cell,placement_confirmed):return false
 var center:Vector2=source_to_world(Vector2(cell))
 occupancy_shapes[instance].polygon=PackedVector2Array([center+Vector2(-24,0),center+Vector2(0,-12),center+Vector2(24,0),center+Vector2(0,12)])
 return true
