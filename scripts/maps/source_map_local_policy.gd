extends RefCounted
## Explicitly approved local interpretation overlay; the original84 manifests
## and source bytes remain unchanged. Never used for protected eleven IDs.
const RECEIPT='res://data/maps/source_map_local_pack.json'
const ART=preload('res://scripts/maps/source_map_review_pack.gd')
static func index(root: String) -> Dictionary:
 var receipt:Dictionary=ART.read_object(RECEIPT)
 var path:String=root+'/local-interpretation-v1/index.json'
 if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=receipt.get('index_sha256'):return {}
 var result:Dictionary=ART.read_object(path)
 if result.get('schema')!=1 or result.get('linkage_sha256')!=ART.LINKAGE_SHA or result.get('policy')!='user_authorized_local_interpretation_20261029':return {}
 return result
static func decorate(record:Dictionary,root:String) -> Dictionary:
 var mid:String=str(record.get('target_map_id',''))
 var catalog:Dictionary=index(root)
 if not catalog.get('maps',{}).has(mid):return {}
 var row:Dictionary=catalog.maps[mid]
 var value:Dictionary=record.duplicate(true)
 if row.has('runtime_source_id'):
  if record.source_map_id!=null or not mid.begins_with('source_variant_'):return {}
  value.original_source_map_id=null
  value.source_map_id=int(row.runtime_source_id)
 if row.has('collision'):
  if record.collision!=null:return {}
  value.collision=row.collision.duplicate(true)
  value.collision.file='local-interpretation-v1/'+str(value.collision.file)
  value.selected_collision_version=str(row.collision.version)
 for patch:Dictionary in row.get('patches',[]):
  var i:int=int(patch.chunk_index)
  if i<0 or i>=value.chunks.size() or value.chunks[i].file!=patch.original_file or value.chunks[i].sha256!=patch.original_sha256:return {}
  value.chunks[i].file='local-interpretation-v1/'+str(patch.file)
  value.chunks[i].sha256=patch.sha256
  value.chunks[i].local_patch=true
 if row.has("clip_grid"):
  value.clip_grid=row.clip_grid.duplicate(true);value.clip_grid.file="local-interpretation-v1/"+str(value.clip_grid.file)
 value.local_policy=true
 return value
static func texture(root:String,row:Dictionary) -> Texture2D:
 var rel:String=str(row.get('file',''))
 if not rel.begins_with('local-interpretation-v1/patches/') or rel.contains('..'):return null
 var path:String=root+'/'+rel
 if FileAccess.get_sha256(path)!=row.sha256:return null
 var bitmap:=Image.new()
 if bitmap.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
 if bitmap.get_width()!=int(row.size[0]) or bitmap.get_height()!=int(row.size[1]):return null
 return ImageTexture.create_from_image(bitmap)
