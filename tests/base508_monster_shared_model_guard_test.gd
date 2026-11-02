extends SceneTree
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
func _initialize():
 var root: String=INSTALL.monster_root()
 var path: String=root.path_join("manifest.json")
 var full=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not full is Dictionary or not full.get("records",{}).has("248") or not full.records.has("249"):
  push_error("Install the authorized source monster pack first");quit(2);return
 var pair={"kind":"base508_monster_pack","source_snapshot":"base508","records":{"248":full.records["248"].duplicate(true),"249":full.records["249"].duplicate(true)}}
 var header={"npc_ids":[248,249]}
 var valid_error: String=INSTALL.validate_monster_payload(root,pair,header)
 if not valid_error.is_empty():push_error("Valid pair rejected: "+valid_error);quit(1);return
 pair.records["249"]["tracks_ref"]=pair.records["248"].tracks_ref
 pair.records["249"]["tracks_sha256"]=pair.records["248"].tracks_sha256
 var invalid_error: String=INSTALL.validate_monster_payload(root,pair,header)
 print("BASE508_SHARED_MODEL_GUARD ",JSON.stringify({"valid_pair_accepted":true,"cross_sprite_model_rejected":not invalid_error.is_empty(),"error":invalid_error}))
 quit(0 if not invalid_error.is_empty() else 1)
