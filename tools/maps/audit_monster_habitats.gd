extends SceneTree
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const NATIVE=preload("res://scripts/maps/native_png_registry.gd")
const REMAKE=preload("res://scripts/maps/remake_registry.gd")
const TRAVEL=preload("res://scripts/maps/source_travel.gd")
const CATALOG=preload("res://scripts/monsters/monster_catalog.gd")
func _initialize():call_deferred("run")
func run():
 var records:Array=CATALOG.expand(JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))["몬스터"])
 var maps:Dictionary={}
 for m:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps_v18.json")):
  if m.id not in ["albino_03","albino_04"]:maps[str(m.id)]=m
 for m:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")):
  if maps.has(str(m.map_id)):maps[str(m.map_id)]["field_path"]=m.path
 for m:Dictionary in NATIVE.catalog_entries()+TRAVEL.catalog_entries()+RUN.catalog_entries():maps[str(m.id)]=m
 var linked:Dictionary={};var by_map:Dictionary={};var failures:Array=[];var holds:Array=[]
 for id:String in maps:
  var field:PlayableField=null
  if RUN.supports(id):field=RUN.load_field(id)
  elif NATIVE.supports(id):field=NATIVE.load_field(id)
  elif REMAKE.installed(id):field=REMAKE.load_field(id)
  elif maps[id].has("source_definition"):field=TRAVEL.load_field(maps[id])
  elif maps[id].has("field_path"):field=REMAKE.authored_field(JSON.parse_string(FileAccess.get_file_as_string(maps[id].field_path)))
  elif maps[id].has("field_definition"):field=REMAKE.authored_field(maps[id].field_definition)
  if field==null:failures.append(id);continue
  var names:Dictionary={};var source_ids:Dictionary={}
  for region:Dictionary in field.data.monster_spawn:
   if int(region.max_count)<=0:continue
   for name:String in region.monster_types:
    names[name]=true
    if not linked.has(name):linked[name]=[]
    linked[name].append(id)
   if region.has("source_npc_id"):source_ids[str(region.source_npc_id)]=true
  for h:Dictionary in field.get_meta("source_spawn_holds",[]):holds.append({"map_id":id,"hold":h})
  by_map[id]={"name":field.data.map_name,"source_map_id":field.definition.get("source_map_id",-1) if field is OriginalPlayableField else -1,"names":names.keys(),"source_ids":source_ids.keys()}
  if field.has_method("close"):field.close()
  print("HABITAT_AUDIT_MAP ",id," species=",names.size()," new_source=",source_ids.size())
 var missing:Array=[];var source_missing:Array=[]
 for r:Dictionary in records:
  if not linked.has(str(r.name)):
   missing.append({"name":r.name,"level":r.get("lv",1),"hp":r.get("hp",1),"sourceId":r.get("sourceId",""),"source_npc_id":r.get("source_npc_id","")})
   if r.get("catalog_only",false):source_missing.append(str(r.source_npc_id))
 var output:String=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 if not output.is_empty():
  var file=FileAccess.open(output,FileAccess.WRITE)
  file.store_string(JSON.stringify({"source_placement_sha256":FileAccess.get_sha256("res://data/monsters/source3_map_spawns.json"),"local_habitats_included":not "--without-local-habitats" in OS.get_cmdline_user_args(),"active":records.size(),"linked":linked,"maps":by_map,"missing":missing,"source_missing":source_missing,"failed_maps":failures,"holds":holds},"  "));file.close()
 print("HABITAT_AUDIT_RESULT active=",records.size()," linked=",records.size()-missing.size()," missing=",missing.size()," source_missing=",source_missing.size()," failed=",failures)
 quit(0 if failures.is_empty() else 1)
