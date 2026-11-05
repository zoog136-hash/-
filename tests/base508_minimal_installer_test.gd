extends SceneTree
## Run only in the generated small project with its independent user-data identity.
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 if str(ProjectSettings.get_setting("application/config/name",""))!="Base508 Installer Isolated Validation":
  push_error("Generate the isolated validator project first");quit(2);return
 var path:String="";var expected:int=0
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--install-monster-zip="):path=arg.trim_prefix("--install-monster-zip=")
  if arg.begins_with("--expected-count="):expected=int(arg.trim_prefix("--expected-count="))
 if path.is_empty()or expected<=0:quit(2);return
 var prior:String=INSTALL.monster_root()
 if FileAccess.file_exists(prior.path_join("installed.json")):
  push_error("Use a fresh XDG_DATA_HOME; existing validation install is preserved");quit(2);return
 var installer=INSTALL.new();root.add_child(installer)
 var result:Dictionary=await installer.install_zip(path)
 if not bool(result.get("ok",false)):
  print("BASE508_MINIMAL_INSTALL ",JSON.stringify(result));installer.free();quit(1);return
 var pack_root:String=str(result.root)
 var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_root.path_join("manifest.json")))
 var errors:Array=[]
 if not value is Dictionary or value.get("records",{}).size()!=expected:errors.append("unexpected installed record count")
 if not bool(result.get("restart_required",false)):errors.append("restart contract missing")
 if not FileAccess.file_exists(pack_root.path_join("installed.json")):errors.append("activation receipt missing")
 # Model the next invocation; a running game intentionally keeps its old version.
 INSTALL._monster_session_root=""
 if INSTALL.monster_root()!=pack_root:errors.append("next session selected another version")
 print("BASE508_MINIMAL_INSTALL ",JSON.stringify({"errors":errors,"records":value.get("records",{}).size()if value is Dictionary else 0,"files":result.get("files",0),"root":pack_root,"actual_installer_copy":true,"full_game_or_visual_validation":false}))
 installer.free();quit(0 if errors.is_empty()else 1)
