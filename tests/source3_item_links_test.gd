extends SceneTree
const LINKS=preload("res://scripts/loot/source3_item_links.gd")
const DROP=preload("res://scripts/loot_drop.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("ITEM_LINK_FAIL ",label)
func _initialize():
 var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LINKS.PATH))
 var source:Dictionary=LINKS.entries()
 check(source.size()==252,"all strict typed identity pointers available")
 check(int(doc.source_records_total)==2992,"complete source item population classified")
 if source.size()!=252:quit(1);return
 var count:int=source.size()
 for value:Variant in doc.excluded_or_unresolved.values():count+=int(value)
 check(count==2992,"every source row has a binding or explicit unresolved reason")
 var game:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["아이템"]
 var catalog:Dictionary=DROP.build_catalog(game)
 check(catalog.source3_by_key.size()==252,"full game catalog exposes all reviewed typed pointers")
 var before:String=JSON.stringify(game)
 var unrelated:Array=game.duplicate(true)
 unrelated.append({"name":"unrelated future item","sourceId":"unrelated_future","slot":"material"})
 check(LINKS.reviewed_entries(doc,unrelated).size()==252,"unrelated catalog changes preserve all verified item identities")
 var changed:Array=game.duplicate(true)
 var changed_id:String=str(source.values()[0].game_source_id)
 for item:Dictionary in changed:
  if str(item.sourceId)==changed_id:item["atk"]=int(item.get("atk",0))+1
 var checked:Dictionary=LINKS.reviewed_entries(doc,changed)
 check(checked.size()==251 and not checked.has(source.values()[0].source_item_key),"changed original item stats fail closed without disabling unrelated identities")
 var duplicated:Array=game.duplicate(true)
 for item:Dictionary in game:
  if str(item.sourceId)==changed_id:duplicated.append(item.duplicate(true));break
 check(LINKS.reviewed_entries(doc,duplicated).size()==251,"ambiguous duplicate catalog ID cannot enable an identity")

 for key:String in source:
  var row:Dictionary=source[key]
  var item:Dictionary=LINKS.resolve(str(row.source_table),str(row.source_item_id),catalog)
  check(not item.is_empty() and item.name==row.game_name and str(item.sourceId)==str(row.game_source_id),"forward lookup "+key)
  check(not item.has("source_item_key"),"lookup does not mutate game item schema")
  check(LINKS.source_identity_for(item).get("source_item_key")==key,"reverse typed identity "+key)
  item["name"]="caller mutation"
 check(JSON.stringify(game)==before,"all game records unchanged")
 check(LINKS.resolve("weapon","423",catalog).is_empty(),"Inven ID is not a source weapon ID")
 check(LINKS.resolve("","11",catalog).is_empty(),"bare IDs require namespace")
 check(LINKS.resolve("armor","11",catalog).is_empty(),"table namespace cannot cross weapon11")
 if not source.has("source3:tw380:Taiwan:weapon:11"):quit(1);return
 var row:Dictionary=source["source3:tw380:Taiwan:weapon:11"]
 var fake:Dictionary=LINKS.resolve("weapon","11",catalog);fake.sourceId="other"
 check(not LINKS.matches(row,fake),"changed game identity rejected")
 check(not LINKS.matches(row,{"name":row.game_name,"type":row.game_type,"slot":row.game_slot}),"name alone cannot establish a runtime identity")
 print("SOURCE3_ITEM_LINK_RESULT checks=",checks," errors=",errors," links=",source.size()," stats_imported=0")
 quit(0 if errors==0 else 1)
