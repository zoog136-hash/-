extends SceneTree
## Opt-in private flat root. Validates installer metadata/hashes without copying GBs.
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
func _initialize()->void:
 var path:String=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--monster-flat-root="):path=arg.trim_prefix("--monster-flat-root=")
 if path.is_empty()or not FileAccess.file_exists(path.path_join("manifest.json")):quit(2);return
 var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("manifest.json")))
 if not value is Dictionary or not value.get("records")is Dictionary:quit(2);return
 var ids:Array=[]
 for key:String in value.records:ids.append(int(key))
 var error:String=INSTALL.validate_monster_payload(path,value,{"npc_ids":ids})
 print("BASE508_FULL_PAYLOAD ",JSON.stringify({"records":ids.size(),"models":value.get("models",{}).size(),"packets":value.get("source_files",{}).size(),"error":error,"actual_install_zip_or_copy":false,"pixel_visual_review":false}))
 quit(0 if error.is_empty()else 1)
