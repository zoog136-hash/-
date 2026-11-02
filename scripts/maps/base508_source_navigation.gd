extends RefCounted
## Reviewed source-edge compatibility policy, not recovered native M semantics.
const SPACE=preload('res://scripts/maps/base508_contract.gd')
const LAND_ASSETS={47914:'13398/',48274:'13401/',48774:'13472/',49324:'13504/',25:'25/',75:'75/'}
const DIRS=[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
var pack:RefCounted
var words:Dictionary={}
var ids:Dictionary={}
var graph:=AStar2D.new()
var barriers:Array=[]
var buckets:Dictionary={}
var occupied:Dictionary={}
var suppressed_diagonals:Array=[]
var arrival:Vector2i
var arrival_record:Dictionary
var source_origin:Vector2i
var scale:=Vector2.ONE
var translation:=Vector2.ZERO
var error:String=''
func to_render(p:Vector2)->Vector2:return p
func point(cell:Vector2i)->Vector2:return SPACE.visual_cell_center(pack.manifest,Vector2(cell))
func source(p:Vector2)->Vector2:return SPACE.source_from_grid_anchor(pack.manifest,p-Vector2(24,12))
func edge(a:Vector2i,b:Vector2i)->bool:
 if not words.has(a) or not words.has(b):return false
 var d:Vector2i=b-a
 if d==Vector2i.RIGHT:return words[a][1]==0
 if d==Vector2i.DOWN:return words[b][0]==0
 if d==Vector2i.LEFT:return words[b][1]==0
 if d==Vector2i.UP:return words[a][0]==0
 return false
func configure(value:RefCounted,tables:String)->bool:
 pack=value
 var land:int=int(pack.manifest.land.ID)
 if LAND_ASSETS.get(land,'')!=str(pack.manifest.land.AssetPath):error='Unreviewed source identity';return false
 var entry_file:String='';var entry_id:int=-1
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--base508-entry-portals='):entry_file=arg.trim_prefix('--base508-entry-portals=')
  if arg.begins_with('--base508-entry-portal='):entry_id=int(arg.trim_prefix('--base508-entry-portal='))
 if not entry_file.is_empty() and entry_id>=0:
  var portals:Variant=JSON.parse_string(FileAccess.get_file_as_string(entry_file))
  if not portals is Array:error='Invalid original portal evidence';return false
  for portal:Dictionary in portals:
   if int(portal.ID)!=entry_id:continue
   var target:Dictionary=portal.TargetTerritory
   if int(target.LandID)!=land or int(target.StartX)!=int(target.EndX) or int(target.StartY)!=int(target.EndY):error='Portal target must be exact point on this Land';return false
   if not arrival_record.is_empty():error='Ambiguous portal evidence';return false
   arrival_record={'ID':entry_id,'X':target.StartX,'Y':target.StartY,'entry_kind':'ORIGINAL_PORTAL_TARGET','portal':portal}
 else:
  # Locations include merchants and test markers; row count never proves entry semantics.
  var reviewed_locations:Dictionary={47914:43661,48274:43674,48774:43854,49324:44054,25:760}
  if not reviewed_locations.has(land):error='Explicit original entry evidence required';return false
  var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(tables+'/Locations.json'))
  if not document is Dictionary:return false
  for row:Dictionary in document.get('rows',[]):
   if int(row.ID)==int(reviewed_locations[land]) and int(row.LandID)==land:
    if not arrival_record.is_empty():error='Ambiguous source arrival';return false
    arrival_record=row.duplicate(true)
    arrival_record['entry_kind']='REVIEW_TEST_LOCATION' if land==25 else 'REVIEWED_ITEM_LOCATION'
 if arrival_record.is_empty():error='Missing original entry evidence';return false
 arrival=Vector2i(arrival_record.X,arrival_record.Y)
 var contract:Dictionary=pack.geographic_contract()
 source_origin=Vector2i(contract.source_cell_bounds[0],contract.source_cell_bounds[1])
 for chunk:Dictionary in pack.geometry.values():
  var raw:PackedByteArray=Marshalls.base64_to_raw(chunk.attribute_u16le)
  if raw.size()!=16384:return false
  var origin:=Vector2i(chunk.origin[0],chunk.origin[1])
  for y:int in range(64):
   for x:int in range(64):
    var offset:int=(y*128+x*2)*2;var pair:Array=[raw.decode_u16(offset),raw.decode_u16(offset+2)]
    if pair[0] not in [0,1] or pair[1] not in [0,1]:error='Unknown raw edge attribute';return false
    words[origin+Vector2i(x,y)]=pair
 for cell:Vector2i in words:
  for d:Vector2i in DIRS:
   if edge(cell,cell+d):ids[cell]=ids.size();graph.add_point(ids[cell],point(cell));break
 if not ids.has(arrival):error='Original arrival unavailable; no nearest fallback';return false
 for cell:Vector2i in ids:
  for d:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
   if edge(cell,cell+d):graph.connect_points(ids[cell],ids[cell+d])
  for dy:int in [-1,1]:
   var h:Vector2i=cell+Vector2i.RIGHT;var v:Vector2i=cell+Vector2i(0,dy);var target:Vector2i=cell+Vector2i(1,dy)
   if edge(cell,h) and edge(cell,v) and edge(h,target) and edge(v,target):graph.connect_points(ids[cell],ids[target])
  for d:Vector2i in DIRS:
   if edge(cell,cell+d):continue
   if ids.has(cell+d) and (d==Vector2i.LEFT or d==Vector2i.UP):continue
   var midpoint:Vector2=(point(cell)+point(cell+d))*0.5
   var tangent:=Vector2(12,6) if d.x!=0 else Vector2(12,-6)
   var segment:Array=[midpoint-tangent,midpoint+tangent];barriers.append(segment)
   var low:=Vector2i(((midpoint-Vector2(32,32))/128).floor());var high:=Vector2i(((midpoint+Vector2(32,32))/128).floor())
   for by:int in range(low.y,high.y+1):
    for bx:int in range(low.x,high.x+1):
     var key:=Vector2i(bx,by)
     if not buckets.has(key):buckets[key]=[]
     buckets[key].append(segment)
 return true
func safe(p:Vector2,radius:float=4)->bool:
 if not p.is_finite():return false
 var cell:=Vector2i(source(p).round())
 if not ids.has(cell) or pack.npc_cells.has(cell) or pack.confirmed_occupancy.has(cell):return false
 for segment:Array in buckets.get(Vector2i((p/128).floor()),[]):
  if Geometry2D.get_closest_point_to_segment(p,segment[0],segment[1]).distance_squared_to(p)<=radius*radius:return false
 # Occupied source cells are diamonds; include the physical foot near their boundary.
 var all_occupied:Dictionary=pack.npc_cells.duplicate()
 all_occupied.merge(pack.confirmed_occupancy)
 for occupied_cell:Vector2i in all_occupied:
  var center:Vector2=point(occupied_cell)
  var vertices:=PackedVector2Array([center+Vector2(-24,0),center+Vector2(0,-12),center+Vector2(24,0),center+Vector2(0,12)])
  if Geometry2D.is_point_in_polygon(p,vertices):return false
  for i:int in range(4):
   if Geometry2D.get_closest_point_to_segment(p,vertices[i],vertices[(i+1)%4]).distance_squared_to(p)<=radius*radius:return false
 return true
func clear(a:Vector2,b:Vector2,radius:float=4)->bool:
 var count:int=maxi(1,ceili(a.distance_to(b)/2))
 for i:int in range(count+1):
  if not safe(a.lerp(b,float(i)/count),radius):return false
 return true
func route(a:Vector2,b:Vector2)->PackedVector2Array:
 if not safe(a) or not safe(b):return []
 if clear(a,b):return PackedVector2Array([b])
 for pair:Array in suppressed_diagonals:graph.connect_points(pair[0],pair[1])
 suppressed_diagonals.clear()
 for cell:Vector2i in occupied:
  if ids.has(cell):graph.set_point_disabled(ids[cell],false)
 occupied=pack.npc_cells.duplicate()
 occupied.merge(pack.confirmed_occupancy)
 for cell:Vector2i in occupied:
  if ids.has(cell):graph.set_point_disabled(ids[cell],true)
  for dx:int in [-1,1]:
   for dy:int in [-1,1]:
    var edge_a:Vector2i=cell+Vector2i(dx,0);var edge_b:Vector2i=cell+Vector2i(0,dy)
    if ids.has(edge_a) and ids.has(edge_b) and graph.are_points_connected(ids[edge_a],ids[edge_b]):
     graph.disconnect_points(ids[edge_a],ids[edge_b]);suppressed_diagonals.append([ids[edge_a],ids[edge_b]])
 var start:=Vector2i(source(a).round());var finish:=Vector2i(source(b).round())
 var result:PackedVector2Array=graph.get_point_path(ids[start],ids[finish])
 if result.is_empty():return []
 result.append(b)
 var previous:Vector2=a
 for p:Vector2 in result:
  if not clear(previous,p):return []
  previous=p
 return result
