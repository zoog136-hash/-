extends RefCounted
## Namespace-safe identity pointers. No source stats, prices or items are granted.
const PATH="res://data/l1j/source3_item_links.json"
const CATALOG="res://data/catalog_v19.json"
static var loaded:bool=false
static var bindings:Dictionary={}
static var reverse:Dictionary={}
static func entries() -> Dictionary:
 if loaded:return bindings
 loaded=true
 var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 var catalog:Variant=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
 if not document is Dictionary or not catalog is Dictionary:return bindings
 bindings=reviewed_entries(document,catalog.get("아이템",[]))
 for key:String in bindings:reverse[str(bindings[key].game_source_id)]=key
 return bindings

static func _canonical_numbers(value:Variant) -> Variant:
 # Godot JSON reads integers as floats. Recreate the producer's canonical
 # integer encoding before checking its existing per-record SHA-256.
 if value is float and is_finite(value) and value==floor(value):return int(value)
 if value is Array:
  var array:Array=[]
  for item:Variant in value:array.append(_canonical_numbers(item))
  return array
 if value is Dictionary:
  var dictionary:Dictionary={}
  for key:String in value:dictionary[key]=_canonical_numbers(value[key])
  return dictionary
 return value

static func reviewed_entries(document:Dictionary,catalog_items:Array) -> Dictionary:
 var result:Dictionary={};var seen:Dictionary={};var by_id:Dictionary={};var duplicates:Dictionary={}
 if document.get("schema")!=1:return result
 for item:Dictionary in catalog_items:
  var id:String=str(item.get("sourceId",""))
  if by_id.has(id):duplicates[id]=true
  by_id[id]=item
 for row:Dictionary in document.get("bindings",[]):
  var key:String=str(row.get("source_item_key",""))
  var expected:String="source3:tw380:Taiwan:"+str(row.get("source_table",""))+":"+str(row.get("source_item_id",""))
  var game_id:String=str(row.get("game_source_id",""))
  if key!=expected or result.has(key) or seen.has(game_id):return {}
  if row.get("source_variant",{}).get("bless_raw")!="1" or row.source_variant.get("trade_raw")!="0":return {}
  seen[game_id]=true
  if not by_id.has(game_id) or duplicates.has(game_id):continue
  var item:Dictionary=by_id[game_id]
  # An unrelated transformation/catalog edit must not disable valid item
  # identities. Full original matched item records remain individually pinned.
  if JSON.stringify(_canonical_numbers(item),"",true,true).sha256_text()!=str(row.get("game_record_sha256","")):continue
  if not matches(row,item):continue
  result[key]=row
 return result
static func matches(row:Dictionary,item:Dictionary) -> bool:
 if item.is_empty() or str(item.get("name",""))!=str(row.game_name) or str(item.get("type",""))!=str(row.game_type) or str(item.get("slot",""))!=str(row.game_slot):return false
 var identity:bool=false
 for field:String in ["sourceId","grade_source_id"]:
  if not item.has(field):continue
  if str(item[field])!=str(row.game_source_id):return false
  identity=true
 return identity
static func runtime_index(items:Dictionary) -> Dictionary:
 var result:Dictionary={}
 for key:String in entries():
  var row:Dictionary=bindings[key]
  if matches(row,items.get(str(row.game_name),{})):result[key]=str(row.game_name)
 return result
static func resolve(source_table:String,source_id:String,catalog:Dictionary) -> Dictionary:
 if source_table not in ["weapon","armor","etcitem"] or not source_id.is_valid_int():return {}
 var row:Dictionary=entries().get("source3:tw380:Taiwan:"+source_table+":"+source_id,{})
 if row.is_empty():return {}
 var item:Dictionary=catalog.get("by_name",{}).get(str(row.game_name),{})
 return item.duplicate(true) if matches(row,item) else {}

static func source_identity_for(item:Dictionary) -> Dictionary:
 entries()
 var game_id:String=str(item.get("sourceId",item.get("grade_source_id","")))
 var row:Dictionary=bindings.get(str(reverse.get(game_id,"")),{})
 return row.duplicate(true) if not row.is_empty() and matches(row,item) else {}
