extends RefCounted
## Source coordinates are admitted only against the actual verified runtime floor.
const PATH="res://data/monsters/source3_map_spawns.json"
const DISK_CACHE_DIR="user://source_spawn_admission"
const DISK_CACHE_SCHEMA=1
## Files whose rules decide floor admission. Their bytes are part of the disk
## cache key, so editing any rule invalidates stored cells automatically.
const RULE_FILES:Array[String]=[PATH,"res://scripts/maps/source_map_spawns.gd","res://scripts/maps/remake_field.gd","res://scripts/maps/source_field.gd","res://scripts/maps/source_map_runtime_field.gd","res://scripts/maps/source_v1_grid.gd","res://scripts/maps/source_coordinates.gd","res://scripts/maps/source_body_profile.gd"]
static var payload:Dictionary={}
static var admitted_cells:Dictionary={}
static var disk_cache_hits:int=0
static func rows() -> Array:
 if payload.is_empty():payload=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 return payload.get("rows",[])
static func append_to_field(field:Object) -> void:
 var held:Array=[]
 var present:Dictionary={}
 # Doors, portals and NPCs cannot change during this admission pass, so the
 # per-cell checks share precomputed geometry. Results are identical.
 var context:Dictionary=admission_context(field)
 # Admission depends only on the pinned grid, doors, clips, portals, NPCs,
 # reservations and the rule files, all hashed into this key. Cells computed on
 # an earlier launch are reused; any input change selects a new key.
 var disk_key:String=disk_cache_key(field,context)
 var disk:Dictionary=_read_disk_cache(disk_key)
 var disk_dirty:bool=false
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
  var row_context:Dictionary=row_admission_context(field,context,a)
  # A randomly placed NPC moves every load; rows it can reach are recomputed.
  var disk_usable:bool=not disk_key.is_empty() and row_context.get("random_npcs",PackedVector2Array()).is_empty()
  if admitted_cells.has(cache_key):
   var prior:Dictionary=admitted_cells[cache_key]
   cells=prior.cells;minimum=prior.minimum;maximum=prior.maximum
  elif disk_usable and disk.has(id) and disk[id].bounds==a:
   var stored:Dictionary=disk[id]
   cells=stored.cells;minimum=stored.minimum;maximum=stored.maximum;rejected=stored.rejected
   disk_cache_hits+=1
   if not cells.is_empty():admitted_cells[cache_key]={"cells":cells,"minimum":minimum,"maximum":maximum}
  else:
   for y:int in range(int(a[1]),int(a[3])+1):
    for x:int in range(int(a[0]),int(a[2])+1):
     var p:Vector2=field.coordinates.to_world(Vector2(x,y))
     var reason:String=floor_rejection(field,p,row_context)
     if not reason.is_empty():rejected[reason]=int(rejected.get(reason,0))+1;continue
     var cell:Vector2i=field.world_to_cell(p)
     cells.append(cell.y*field.width+cell.x)
     minimum=minimum.min(p);maximum=maximum.max(p)
   # Geometry is immutable for the pinned grid. Every spawn still checks live
   # doors, random NPC placement, safety and portal clearance before creating.
   if not cells.is_empty():admitted_cells[cache_key]={"cells":cells,"minimum":minimum,"maximum":maximum}
   if disk_usable:
    disk[id]={"bounds":a.duplicate(),"cells":cells,"minimum":minimum,"maximum":maximum,"rejected":rejected}
    disk_dirty=true
  if cells.is_empty():held.append({"key":row.key,"reason":"no_verified_source_floor","source_bounds":a,"rejected_cells":rejected});continue
  cells.sort()
  field.region_cells[id]=cells
  var area:Vector2=maximum-minimum
  field.data.monster_spawn.append({"id":id,"source_game_id":row.game_source_id,"source_npc_id":row.source_npc_id,"source_key":row.key,"source_heading":row.heading,"source_bounds":a,"source_sampling":row.position_mode,"source_sampling_center":row.sampling_center,"source_sampling_offsets":row.sampling_offsets,"respawn_on_screen":row.respawn_on_screen,"mode":"normal","rect":[minimum.x-1,minimum.y-1,area.x+2,area.y+2],"monster_types":[row.name],"max_count":int(row.count),"respawn_time":float(row.respawn_seconds[0]),"source_respawn_seconds":row.respawn_seconds,"min_spacing":8.0,"roaming_radius":120.0})
 field.set_meta("source_spawn_holds",held)
 if disk_dirty:_write_disk_cache(disk_key,disk)

## Empty when the inputs cannot be identified exactly (e.g. exported builds
## without readable rule sources, or PNG review footprints): never cache then.
static func disk_cache_key(field:Object,context:Dictionary) -> String:
 if context.is_empty() or field.get("png_review_footprints")!=null or field.get("raw_grid")==null:return ""
 var rules:Array=[]
 for path:String in RULE_FILES:
  var digest:String=FileAccess.get_sha256(path)
  if digest.is_empty():return ""
  rules.append(digest)
 var grid:RefCounted=field.raw_grid
 var reservations:Array=field.get("reservations") if field.get("reservations")!=null else []
 # Rows a random NPC can reach never use the disk cache, so only fixed NPCs
 # belong in the key.
 var fixed_npcs:Array=[]
 for npc:Dictionary in field.data.get("npc_spawn",[]):
  if not _randomly_placed(npc):fixed_npcs.append(npc)
 var parts:Array=[DISK_CACHE_SCHEMA,rules,str(field.get_script().resource_path),str(field.data.map_id),str(field.definition.source_sha256),int(field.data.layout_revision),
  grid.origin,grid.width,grid.height,grid.require_artwork,_sorted_keys(grid.artwork_chunks),_sorted_keys(grid.open_doors),_sorted_keys(grid.closed_doors),_sorted_keys(grid.clipped_cells),
  field.data.get("portal",[]),fixed_npcs,reservations]
 return var_to_str(parts).sha256_text()

static func _sorted_keys(values:Dictionary) -> Array:
 var keys:Array=[]
 for key:Variant in values.keys():keys.append(var_to_str(key))
 keys.sort()
 return keys

const DISK_CACHE_MAGIC:int=0x54535041 # "TSPA"
static func _read_disk_cache(key:String) -> Dictionary:
 if key.is_empty():return {}
 var path:String=DISK_CACHE_DIR+"/"+key+".bin"
 if not FileAccess.file_exists(path):return {}
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {}
 # Header (magic, length, SHA-256) is verified before decoding so a truncated
 # or corrupt file is a silent miss rather than a decoder error.
 if file.get_length()<44 or file.get_32()!=DISK_CACHE_MAGIC:file.close();return {}
 var length:int=file.get_64()
 var digest:PackedByteArray=file.get_buffer(32)
 if length<0 or length!=file.get_length()-44:file.close();return {}
 var bytes:PackedByteArray=file.get_buffer(length)
 file.close()
 var hashing:=HashingContext.new()
 hashing.start(HashingContext.HASH_SHA256);hashing.update(bytes)
 if bytes.size()!=length or hashing.finish()!=digest:return {}
 var stored:Variant=bytes_to_var(bytes)
 if not stored is Dictionary or stored.get("schema")!=DISK_CACHE_SCHEMA or stored.get("key")!=key or not stored.get("rows") is Dictionary:return {}
 var rows_out:Dictionary={}
 for id:Variant in stored.rows:
  var row:Variant=stored.rows[id]
  if not row is Dictionary or not row.get("cells") is PackedInt32Array or not row.get("bounds") is Array or not row.get("minimum") is Vector2 or not row.get("maximum") is Vector2 or not row.get("rejected") is Dictionary:return {}
  rows_out[str(id)]=row
 return rows_out

static func _write_disk_cache(key:String,rows_by_id:Dictionary) -> void:
 if key.is_empty():return
 DirAccess.make_dir_recursive_absolute(DISK_CACHE_DIR)
 var path:String=DISK_CACHE_DIR+"/"+key+".bin"
 var temporary:String=path+".tmp"
 var bytes:PackedByteArray=var_to_bytes({"schema":DISK_CACHE_SCHEMA,"key":key,"rows":rows_by_id})
 var hashing:=HashingContext.new()
 hashing.start(HashingContext.HASH_SHA256);hashing.update(bytes)
 var file:=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return
 file.store_32(DISK_CACHE_MAGIC);file.store_64(bytes.size());file.store_buffer(hashing.finish());file.store_buffer(bytes)
 var error:Error=file.get_error()
 file.close()
 if error!=OK:DirAccess.remove_absolute(temporary);return
 DirAccess.rename_absolute(temporary,path)

static func floor_allowed(field:Object,p:Vector2) -> bool:
 return floor_rejection(field,p).is_empty()
## Precomputed, read-only inputs for many floor_rejection() calls on one field.
static func admission_context(field:Object) -> Dictionary:
 var portals:Array=[]
 for portal:Dictionary in field.data.get("portal",[]):
  portals.append([Vector2(portal.position[0],portal.position[1]),maxf(48.0,float(portal.get("radius",18.0))+16.0)])
 var npcs:PackedVector2Array=PackedVector2Array()
 var random_npcs:PackedVector2Array=PackedVector2Array()
 for npc:Dictionary in field.data.get("npc_spawn",[]):
  npcs.append(Vector2(npc.position[0],npc.position[1]))
  if _randomly_placed(npc):random_npcs.append(Vector2(npc.position[0],npc.position[1]))
 return {"portals":portals,"npcs":npcs,"random_npcs":random_npcs,"blocked":{},"memo_clear":field.has_method("point_clear_memo")}
static func _randomly_placed(npc:Dictionary) -> bool:
 return str(npc.get("source_position_mode",""))=="random_offsets"
## Narrows the context to portals, NPCs and reservations that can reach any
## cell of source bounds a. to_world() is affine, so the corner box contains
## every tested cell centre and the narrowed checks give identical answers.
static func row_admission_context(field:Object,context:Dictionary,a:Array) -> Dictionary:
 var area:=Rect2(field.coordinates.to_world(Vector2(int(a[0]),int(a[1]))),Vector2.ZERO)
 for corner:Vector2 in [Vector2(int(a[2]),int(a[1])),Vector2(int(a[0]),int(a[3])),Vector2(int(a[2]),int(a[3]))]:
  area=area.expand(field.coordinates.to_world(corner))
 if not area.position.is_finite() or not area.size.is_finite():return context
 var portals:Array=[]
 for portal:Array in context.portals:
  if area.grow(float(portal[1])+1.0).has_point(portal[0]):portals.append(portal)
 var npcs:=PackedVector2Array()
 for at:Vector2 in context.npcs:
  if area.grow(49.0).has_point(at):npcs.append(at)
 var random_npcs:=PackedVector2Array()
 for at:Vector2 in context.random_npcs:
  if area.grow(49.0).has_point(at):random_npcs.append(at)
 var narrowed:Dictionary=context.duplicate()
 narrowed.portals=portals;narrowed.npcs=npcs;narrowed.random_npcs=random_npcs
 if field.has_method("reservations_near"):narrowed.reservations=field.reservations_near(area)
 return narrowed
static func floor_rejection(field:Object,p:Vector2,context:Dictionary={}) -> String:
 if not p.is_finite():return "invalid_projection"
 var c:Vector2i=field.world_to_cell(p)
 var grid:RefCounted=field.raw_grid
 if c.x<0 or c.y<0 or c.x>=grid.width or c.y>=grid.height:return "outside_collision_bounds"
 if grid.clipped_cells.has(c):return "reviewed_local_clip"
 if grid.require_artwork and not grid.artwork_chunks.has(Vector2i(c.x>>6,c.y>>6)):return "missing_client_chunk"
 if not grid.contains(c):return "reviewed_grid_exclusion_or_closed_door"
 var tile:int=grid.tile(c)
 if (tile&128)!=0 or (tile&3)==0:return "source_collision_solid"
 if context.is_empty():
  if not field.point_clear(p,4.0):return "four_pixel_foot_clearance"
 elif context.memo_clear:
  if not field.point_clear_memo(p,4.0,context.blocked):return "four_pixel_foot_clearance"
 elif not field.point_clear(p,4.0):return "four_pixel_foot_clearance"
 if (tile&48)==16:return "source_safe_zone"
 if context.has("reservations"):
  if field.is_safe_among(p,context.reservations):return "entry_or_gameplay_reservation"
 elif field.is_safe(p):return "entry_or_gameplay_reservation"
 if context.is_empty():
  for portal:Dictionary in field.data.get("portal",[]):
   var at:Vector2=Vector2(portal.position[0],portal.position[1])
   if p.distance_to(at)<maxf(48.0,float(portal.get("radius",18.0))+16.0):return "portal_clearance"
  for npc:Dictionary in field.data.get("npc_spawn",[]):
   if p.distance_to(Vector2(npc.position[0],npc.position[1]))<48.0:return "npc_clearance"
  return ""
 for portal:Array in context.portals:
  if p.distance_to(portal[0])<portal[1]:return "portal_clearance"
 for at:Vector2 in context.npcs:
  if p.distance_to(at)<48.0:return "npc_clearance"
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
