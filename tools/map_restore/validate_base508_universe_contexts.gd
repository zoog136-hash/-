extends SceneTree
## Actual pack API checks across every preserved original Land context; no save/world.
const PACK=preload("res://scripts/maps/base508_pack.gd")
var path:String
var records:Dictionary={}
func _initialize()->void:
 path=OS.get_environment("TWILIGHT_BASE508_UNIVERSE")
 call_deferred("run")
func run()->void:
 var receipt:String=path+"/runtime-context-evidence.json"
 if FileAccess.file_exists(receipt):records=JSON.parse_string(FileAccess.get_file_as_string(receipt))
 while true:
  var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/universe-progress.json"))
  for key in state.assets:
   if records.has(key) and not (records[key].status=="FAILED" and records[key].reason=="Shared Land context unavailable"):continue
   var row:Dictionary=state.assets[key]
   if not row.get("status","") in ["VERIFIED_VISUAL","REUSED_VERIFIED_VISUAL","VERIFIED_EMPTY"]:continue
   if row.land_ids.is_empty():records[key]={"status":"UNREFERENCED_NOT_REGISTERED","land_ids":[]};continue
   var pack=PACK.new()
   var error:String=""
   if not pack.load_pack(row.pack_root):error=pack.error
   var verified:Array=[]
   if error.is_empty():
    for lid in row.land_ids:
     if int(pack.manifest.land.ID)!=int(lid) or pack.manifest.has("land_contexts_file"):
      if not pack.select_land_context(int(lid)):error=pack.error;break
     elif row.land_ids.size()!=1:error="Multiple Land IDs require explicit shared contexts";break
     if int(pack.manifest.land.ID)!=int(lid):error="Context LandID mismatch";break
     for portal:Dictionary in pack.portals:
      if int(portal.SourceLandID)!=int(lid):error="Portal source context mismatch";break
     for geometry:Dictionary in pack.manifest.geometry:
      var cell=Vector2i(int(geometry.origin[0]),int(geometry.origin[1]))
      if pack.raw_attribute(cell.x*2,cell.y)<0:error="Original attribute not loaded";break
      if pack.can_enter(cell):error="Unknown terrain unexpectedly passable";break
     if not error.is_empty():break
     verified.append(int(lid))
   records[key]={"status":"RUNTIME_CONTEXTS_VERIFIED" if error.is_empty() else "FAILED","land_ids":verified,"reason":error,"movement":"UNKNOWN_BLOCKED","save_access":false}
   var file=FileAccess.open(receipt,FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
   print("BASE508_CONTEXTS ",key," ",records[key].status," ",verified.size())
   await process_frame
  var checkpoint=FileAccess.open(receipt,FileAccess.WRITE);checkpoint.store_string(JSON.stringify(records,"  "));checkpoint.close()
  var terminal:int=0
  for row in state.assets.values():
   if row.get("status","") in ["VERIFIED_VISUAL","REUSED_VERIFIED_VISUAL","VERIFIED_EMPTY","FAILED","BLOCKED"]:terminal+=1
  if terminal==int(state.get("total_asset_jobs",672)):break
  await create_timer(2).timeout
 quit()
