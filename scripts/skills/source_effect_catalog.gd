extends RefCounted
## Complete permitted source inventory, separate from reviewed combat bindings.
## A group/variant/record must be selected explicitly; names never pick a variant.
const DECODER=preload("res://scripts/skills/source_spr_decoder.gd")
const PATH="res://data/skills/source_effects/catalog.json"
var manifest:Dictionary={}
func _init():
 if FileAccess.file_exists(PATH):
  var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
  if value is Dictionary:manifest=value
func groups()->Dictionary:
 return manifest.get("groups",{}).duplicate(true)
func records(group_id:String)->Array:
 var spec:Dictionary=manifest.get("groups",{}).get(group_id,{})
 if spec.is_empty():return []
 var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(str(spec.path)))
 if not value is Dictionary or str(value.get("group",{}).get("group_id",""))!=group_id:return []
 return value.get("records",[])
func frame(group_id:String,record_key:String,index:int)->Dictionary:
 var selected:Dictionary={}
 for r:Dictionary in records(group_id):
  if str(r.record_key)==record_key:selected=r;break
 if selected.is_empty() or index<0 or index>=int(selected.get("frames",selected.get("count",0))):return {}
 if selected.get("storage","")=="reviewed_atlas":
  var path:String="res://assets/external_spx/similar_skills/"+str(selected.atlas)
  if FileAccess.get_sha256(path)!=str(selected.sha256):return {}
  var atlas:=Image.new()
  if atlas.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return {}
  var width:int=int(selected.width);var height:int=int(selected.height);var columns:int=int(selected.columns)
  var pixels:Image=atlas.get_region(Rect2i((index%columns)*width,(index/columns)*height,width,height))
  return {"image":pixels,"bounds":Rect2i(int(selected.offset[0]),int(selected.offset[1]),width,height),"frame_count":int(selected.count),"record_key":record_key,"anchor_is_foot":false}
 var spec:Dictionary=manifest.get("packs",{}).get(str(selected.archive),{})
 if spec.is_empty():return {}
 var reader:=ZIPReader.new()
 if reader.open(str(spec.path))!=OK:return {}
 var data:PackedByteArray=reader.read_file(str(selected.package_blob));reader.close()
 if data.size()!=int(selected.size):return {}
 var hash_context:=HashingContext.new();hash_context.start(HashingContext.HASH_SHA256);hash_context.update(data)
 if hash_context.finish().hex_encode()!=str(selected.sha256):return {}
 var result:Dictionary=DECODER.decode(data,index)
 if not result.is_empty():result["record_key"]=record_key;result["sha256"]=selected.sha256
 return result
func texture(group_id:String,record_key:String,index:int)->Dictionary:
 # No global texture cache: callers own/release only the frame they request.
 var result:Dictionary=frame(group_id,record_key,index)
 if result.is_empty():return {}
 result["texture"]=ImageTexture.create_from_image(result.image)
 return result
