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
 if not document is Dictionary or document.get("schema")!=1 or FileAccess.get_sha256(CATALOG)!=str(document.get("catalog_sha256","")):return bindings
 for row:Dictionary in document.get("bindings",[]):
  var key:String=str(row.get("source_item_key",""))
  var expected:String="source3:tw380:Taiwan:"+str(row.get("source_table",""))+":"+str(row.get("source_item_id",""))
  if key!=expected or bindings.has(key):bindings.clear();return bindings
  if row.get("source_variant",{}).get("bless_raw")!="1" or row.source_variant.get("trade_raw")!="0":bindings.clear();return bindings
  var game_id:String=str(row.game_source_id)
  if reverse.has(game_id):bindings.clear();reverse.clear();return bindings
  reverse[game_id]=key
  bindings[key]=row
 return bindings
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
