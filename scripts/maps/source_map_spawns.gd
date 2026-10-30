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
     if not floor_allowed(field,p):continue
     var cell:Vector2i=field.world_to_cell(p)
     cells.append(cell.y*field.width+cell.x)
     minimum=minimum.min(p);maximum=maximum.max(p)
   # Geometry is immutable for the pinned grid. Every spawn still checks live
   # doors, random NPC placement, safety and portal clearance before creating.
   if not cells.is_empty():admitted_cells[cache_key]={"cells":cells,"minimum":minimum,"maximum":maximum}
  if cells.is_empty():held.append({"key":row.key,"reason":"no_verified_source_floor"});continue
  cells.sort()
  field.region_cells[id]=cells
  var area:Vector2=maximum-minimum
  field.data.monster_spawn.append({"id":id,"source_game_id":row.game_source_id,"source_npc_id":row.source_npc_id,"source_key":row.key,"source_heading":row.heading,"source_bounds":a,"mode":"normal","rect":[minimum.x-1,minimum.y-1,area.x+2,area.y+2],"monster_types":[row.name],"max_count":int(row.count),"respawn_time":float(row.respawn_seconds[0]),"source_respawn_seconds":row.respawn_seconds,"min_spacing":8.0,"roaming_radius":120.0})
 field.set_meta("source_spawn_holds",held)
static func floor_allowed(field:Object,p:Vector2) -> bool:
 if not p.is_finite() or not field.point_clear(p,4.0) or field.is_safe(p):return false
 for portal:Dictionary in field.data.get("portal",[]):
  var at:Vector2=Vector2(portal.position[0],portal.position[1])
  if p.distance_to(at)<maxf(48.0,float(portal.get("radius",18.0))+16.0):return false
 for npc:Dictionary in field.data.get("npc_spawn",[]):
  if p.distance_to(Vector2(npc.position[0],npc.position[1]))<48.0:return false
 return true
