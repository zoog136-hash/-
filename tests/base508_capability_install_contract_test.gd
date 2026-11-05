extends SceneTree
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var path: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--lineagem-monster-pack="):path=arg.trim_prefix("--lineagem-monster-pack=")
 if path.is_empty() or not FileAccess.file_exists(path):
  print("BASE508_PRIVATE_PACK_TEST_SKIPPED: explicit private manifest required; no source load claim")
  quit(0);return
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var ids: Array=[]
 for key: String in manifest.records:ids.append(int(key))
 var result: String=INSTALL.validate_monster_payload(path.get_base_dir(),manifest,{"npc_ids":ids})
 print("BASE508_CAPABILITY_INSTALL_CONTRACT ",JSON.stringify({"classes":ids.size(),"error":result,"scope":"metadata/hash/context validator; not a full installer run"}))
 quit(0 if result.is_empty()else 1)
