extends RefCounted
## Additional SQL memberships inside the existing successful empty rarity pool.
## No extra rarity rolls, source probability conversion, stack or enchantment.
const PATH="res://data/monsters/source3_drop_extensions.json"
const SHA="7e06bd8db082f4521af7706c4f6f1c599c4f82fff287ae918f12b8ab6fb4f500"
const LINKS=preload("res://scripts/loot/source3_item_links.gd")
static var loaded:bool=false
static var entries:Dictionary={}
static func registry() -> Dictionary:
 if loaded:return entries
 loaded=true
 if FileAccess.get_sha256(PATH)!=SHA:return entries
 var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 if not document is Dictionary or document.get("schema")!=1 or document.get("policy")!="EXISTING_SUCCESSFUL_GRADE_EMPTY_POOL_ONLY":return entries
 if FileAccess.get_sha256(LINKS.PATH)!=str(document.get("item_links_sha256","")):return entries
 entries=document.get("entries",{})
 return entries
static func identity(record:Dictionary) -> Dictionary:
 var id:String=str(record.get("source_npc_id",""))
 if not registry().has(id) or not record.get("catalog_only",false) or not record.get("import_enabled",false):return {}
 if not str(record.get("appearance_status","")).is_empty():return {}
 var result:Dictionary={}
 for key:String in ["name","sourceId","source_id","source_npc_id","source_name_original","source_version","source_locale"]:result[key]=record.get(key,"")
 var raw:Dictionary=record.get("source_raw_fields",{})
 result.raw_npc_gfxid=raw.get("gfxid","");result.raw_npc_nameid=raw.get("nameid","")
 var proof:Dictionary=record.get("identity_review_evidence",{}).get("SQL",{})
 result.npc_sql_sha256=proof.get("row_sha256",proof.get("tuple_sha256",""))
 return result if result==registry()[id].identity else {}
static func candidates(grade:String,items:Dictionary,monster_identity:Dictionary) -> Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var id:String=str(monster_identity.get("source_npc_id",""))
 var spec:Dictionary=registry().get(id,{})
 if spec.is_empty() or monster_identity!=spec.identity:return result
 for row:Dictionary in spec.drops:
  if str(row.grade)!=grade or row.get("quantity")!=1 or row.get("source_enchant")!=0:continue
  var link:Dictionary=LINKS.entries().get(str(row.source_item_key),{})
  var item:Dictionary=items.get(str(row.item_name),{})
  if link.is_empty() or not LINKS.matches(link,item):continue
  if str(item.get("grade",""))!=grade or str(item.get("type",""))!=str(row.type) or str(item.get("slot",""))!=str(row.slot):continue
  result.append({"item_name":str(row.item_name),"weight":1,"min":1,"max":1})
 return result
