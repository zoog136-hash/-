extends RefCounted
## Explicit TWILIGHT habitats; these coordinates are not recovered source spawns.
const PATH="res://data/monsters/local_source_habitats.json"
static var payload:Dictionary={}
static func append_to_field(field:Object) -> bool:
 if not FileAccess.file_exists(PATH):return false
 if payload.is_empty():payload=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 if payload.get("schema")!=1 or str(payload.get("source_placement_sha256",""))!=FileAccess.get_sha256("res://data/monsters/source3_map_spawns.json"):return false
 for row:Dictionary in payload.get("rows",[]):
  if row.map_id!=field.data.map_id:continue
  if row.grid_sha256!=field.definition.source_sha256 or int(row.layout_revision)!=int(field.data.layout_revision):return false
  var present:bool=false
  for region:Dictionary in field.data.monster_spawn:
   if str(region.id)==str(row.id):present=true
  if present:continue
  var cells:=PackedInt32Array(row.cells)
  if cells.is_empty():continue
  cells.sort();field.region_cells[str(row.id)]=cells
  var region:Dictionary=row.duplicate(true)
  region.erase("cells");region.erase("grid_sha256");region.erase("map_id")
  field.data.monster_spawn.append(region)
 return true
