extends RefCounted
## This optional supplement never promotes a map. A reviewed runtime rule must
## explicitly request the pinned representative of an identical archive set.
const RECEIPT='res://data/maps/source_map_equal_collision_pack.json'
const AUDIT_SHA='4c0e3e9be4ea0e37805942679cc4c80783ae888cce7c79f443202be11c1b4cb3'
const READ=preload('res://scripts/maps/source_map_review_pack.gd')
static func spec(root: String, source_id: int) -> Dictionary:
 var receipt:Dictionary=READ.read_object(RECEIPT)
 var path:String=root+'/equal-collision-v1/index.json'
 if receipt.get('audit_sha256')!=AUDIT_SHA or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=receipt.get('index_sha256'):return {}
 var index:Dictionary=READ.read_object(path)
 if index.get('schema')!=1 or index.get('audit_sha256')!=AUDIT_SHA or index.get('linkage_sha256')!=READ.LINKAGE_SHA or not index.get('maps') is Dictionary or index.maps.size()!=35:return {}
 var row:Dictionary=index.maps.get(str(source_id),{})
 if row.get('archive_version_label')!='351' or row.get('file')!='grids/'+str(source_id)+'.u8.gz':return {}
 var result:Dictionary=row.duplicate(true)
 result.file='equal-collision-v1/'+str(row.file)
 return result
