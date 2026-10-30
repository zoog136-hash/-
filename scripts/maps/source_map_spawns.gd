extends RefCounted
## Source coordinates are admitted only against the actual verified runtime floor.
const PATH="res://data/monsters/source3_map_spawns.json"
static var payload:Dictionary={}
static var admitted_cells:Dictionary={}
static func rows() -> Array:
 if payload.is_empty():payload=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 return payload.get("rows",[])
static func append_to_field(field:Object) -> void:
 var held:Array=[]
 var present:Dictionary={}
 for region:Dictionary in field.data.monster_spawn:present[str(region.id)]=true
 for row:Dictionary in rows():
  if row.map_id!=field.data.map_id:continue
  var id:String="source3:"+str(row.key)
  if present.has(id):continue
  if row.grid_sha256!=field.definition.source_sha256 or int(row.layout_revision)!=int(field.data.layout_revision):held.append({"key":row.key,"reason":"grid_identity"});continue
  var a:Array=row.source_bounds
  var count:int=(int(a[2])-int(a[0])+1)*(int(a[3])-int(a[1])+1)
  if count<1 or count>65536:held.append({"key":row.key,"reason":"unbounded_source_area"});continue
  var rejected:Dictionary={}
  var cells:=PackedInt32Array()
  var minimum:=Vector2.INF
  var maximum:Vector2=-Vector2.INF
  var cache_key:String=str(row.grid_sha256)+":"+str(row.layout_revision)+":"+id
  if admitted_cells.has(cache_key):
   var prior:Dictionary=admitted_cells[cache_key]
   cells=prior.cells;minimum=prior.minimum;maximum=prior.maximum
  else:
   for y:int in range(int(a[1]),int(a[3])+1):
    for x:int in range(int(a[0]),int(a[2])+1):
     var p:Vector2=field.coordinates.to_world(Vector2(x,y))
     var reason:String=floor_rejection(field,p)
     if not reason.is_empty():rejected[reason]=int(rejected.get(reason,0))+1;continue
     var cell:Vector2i=field.world_to_cell(p)
     cells.append(cell.y*field.width+cell.x)
     minimum=minimum.min(p);maximum=maximum.max(p)
   # Geometry is immutable for the pinned grid. Every spawn still checks live
   # doors, random NPC placement, safety and portal clearance before creating.
   if not cells.is_empty():admitted_cells[cache_key]={"cells":cells,"minimum":minimum,"maximum":maximum}
  if cells.is_empty():held.append({"key":row.key,"reason":"no_verified_source_floor","source_bounds":a,"rejected_cells":rejected});continue
  cells.sort()
  field.region_cells[id]=cells
  var area:Vector2=maximum-minimum
  field.data.monster_spawn.append({"id":id,"source_game_id":row.game_source_id,"source_npc_id":row.source_npc_id,"source_key":row.key,"source_heading":row.heading,"source_bounds":a,"source_sampling":row.position_mode,"source_sampling_center":row.sampling_center,"source_sampling_offsets":row.sampling_offsets,"respawn_on_screen":row.respawn_on_screen,"mode":"normal","rect":[minimum.x-1,minimum.y-1,area.x+2,area.y+2],"monster_types":[row.name],"max_count":int(row.count),"respawn_time":float(row.respawn_seconds[0]),"source_respawn_seconds":row.respawn_seconds,"min_spacing":8.0,"roaming_radius":120.0})
 field.set_meta("source_spawn_holds",held)
static func floor_allowed(field:Object,p:Vector2) -> bool:
 return floor_rejection(field,p).is_empty()
static func floor_rejection(field:Object,p:Vector2) -> String:
 if not p.is_finite():return "invalid_projection"
 var c:Vector2i=field.world_to_cell(p)
 var grid:RefCounted=field.raw_grid
 if c.x<0 or c.y<0 or c.x>=grid.width or c.y>=grid.height:return "outside_collision_bounds"
 if grid.clipped_cells.has(c):return "reviewed_local_clip"
 if grid.require_artwork and not grid.artwork_chunks.has(Vector2i(c.x>>6,c.y>>6)):return "missing_client_chunk"
 if not grid.contains(c):return "reviewed_grid_exclusion_or_closed_door"
 var tile:int=grid.tile(c)
 if (tile&128)!=0 or (tile&3)==0:return "source_collision_solid"
 if not field.point_clear(p,4.0):return "four_pixel_foot_clearance"
 if (tile&48)==16:return "source_safe_zone"
 if field.is_safe(p):return "entry_or_gameplay_reservation"
 for portal:Dictionary in field.data.get("portal",[]):
  var at:Vector2=Vector2(portal.position[0],portal.position[1])
  if p.distance_to(at)<maxf(48.0,float(portal.get("radius",18.0))+16.0):return "portal_clearance"
 for npc:Dictionary in field.data.get("npc_spawn",[]):
  if p.distance_to(Vector2(npc.position[0],npc.position[1]))<48.0:return "npc_clearance"
 return ""

static func sample_spawn(field:Object,region:Dictionary,random:RandomNumberGenerator) -> Vector2:
 var a:Array=region.source_bounds
 var center:Array=region.source_sampling_center
 var offsets:Array=region.source_sampling_offsets
 for attempt:int in range(96):
  var source:=Vector2(random.randi_range(int(a[0]),int(a[2])),random.randi_range(int(a[1]),int(a[3])))
  if region.source_sampling=="random_offsets":
   var rx:int=maxi(0,int(offsets[0])-1);var ry:int=maxi(0,int(offsets[1])-1)
   source=Vector2(int(center[0])+random.randi_range(0,rx)-random.randi_range(0,rx),int(center[1])+random.randi_range(0,ry)-random.randi_range(0,ry))
  var point:Vector2=field.coordinates.to_world(source)
  if floor_allowed(field,point):return point
 return Vector2.INF
