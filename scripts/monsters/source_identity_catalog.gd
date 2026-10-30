extends RefCounted
## Read-only source review registry. Never turns a candidate into a spawnable actor.
const PATH="res://data/monsters/source_identity_catalog.json"
const NAMESPACE="source3:tw380:Taiwan:npc:"
static var data:Dictionary={}
static var index:Dictionary={}
static func ensure_loaded() -> void:
 if not data.is_empty():return
 data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 for row:Dictionary in data.get("entities",[]):index[str(row.key)]=row
static func entity(key:String) -> Dictionary:
 if not key.begins_with(NAMESPACE):return {}
 ensure_loaded()
 return index.get(key,{}).duplicate(true)
static func body_records(key:String,only_missing:bool=false) -> Array:
 var row:Dictionary=entity(key)
 if row.is_empty():return []
 var result:Array=[];var seen:Dictionary={}
 for candidate:Dictionary in row.model_candidates:
  var model:Dictionary=data.models.get(str(candidate.model_key),{})
  for record:Array in model.get("records",[]):
   if seen.has(str(record[0])) or (only_missing and bool(record[5])):continue
   seen[str(record[0])]=true
   result.append({"model_key":candidate.model_key,"original_pack_root":model.get("original_pack_root"),"record_key":record[0],"filename":record[1],"pak_byte_offset":record[2],"bytes":record[3],"sha256":record[4],"available_locally":record[5],"frames":record[6]})
 return result
static func counts() -> Dictionary:
 ensure_loaded()
 return data.get("counts",{}).duplicate(true)

static func for_game_record(record:Dictionary) -> Dictionary:
 ensure_loaded()
 for row:Dictionary in data.get("game_records",[]):
  if str(row.name)!=str(record.get("name","")) or str(row.game_source_id)!=str(record.get("sourceId","")):continue
  return row.duplicate(true)
 return {}
