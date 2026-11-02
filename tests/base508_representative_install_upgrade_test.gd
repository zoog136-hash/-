extends SceneTree
## Opt-in private representative packs; isolated user data is required by the runner.
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
const BINDINGS=preload("res://scripts/monsters/base508_monster_bindings.gd")
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const BOSS=preload("res://scripts/monsters/base508_boss_combat.gd")
const DROPS=preload("res://scripts/loot/base508_monster_drops.gd")
var errors:Array=[]
func check(value:bool,label:String)->void:
 if not value: errors.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var args:Dictionary={}
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--")and arg.contains("="):args[arg.get_slice("=",0).trim_prefix("--")]=arg.substr(arg.find("=")+1)
 if not args.has_all(["baseline","updated","corrupt"]):quit(2);return
 check(INSTALL.monster_root().is_empty()or not FileAccess.file_exists(INSTALL.monster_root().path_join("installed.json")),"test requires fresh isolated user data")
 if not errors.is_empty():print(errors);quit(2);return
 var installer=INSTALL.new();root.add_child(installer)
 var first:Dictionary=await installer.install_zip(args.baseline)
 check(bool(first.get("ok",false)),"baseline installation")
 if not bool(first.get("ok",false)):print(first);installer.free();quit(1);return
 var old_root:String=first.root
 var old_manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(old_root.path_join("manifest.json")))
 var old_actor:Dictionary=old_manifest.records["60303"].duplicate(true)
 # Installer explicitly requires restart; simulate the next process cache here.
 check(bool(first.get("restart_required",false)),"baseline restart required")
 INSTALL._monster_session_root=""
 var update:Dictionary=await installer.install_zip(args.updated)
 check(bool(update.get("ok",false)),"update installation")
 if not bool(update.get("ok",false)):print(update);installer.free();quit(1);return
 check(bool(update.get("restart_required",false)),"update restart required")
 INSTALL._monster_session_root=""
 var active:String=INSTALL.monster_root()
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(active.path_join("manifest.json")))
 check(active==str(update.root)and active!=old_root,"new version activated")
 check(manifest.records.size()==10,"ten representative records")
 check(manifest.records["60303"]==old_actor,"old actor preserved")
 check(FileAccess.file_exists(old_root.path_join("installed.json")),"old version retained")
 check(BINDINGS.pack_manifest()==active.path_join("manifest.json"),"managed manifest discovery")
 check(FileAccess.get_sha256(active.path_join("boss_combat.bin"))==BOSS.CATALOG_SHA256 and not BOSS.data().is_empty(),"managed combat catalog")
 check(FileAccess.get_sha256(active.path_join("monster_drops.bin"))==DROPS.DATA_SHA and not DROPS.data().is_empty(),"managed drops")
 check(INSTALL.validate_boss_vfx_payload(active,manifest).is_empty(),"installed original VFX hash contract")
 var ready:Array=[];var blocked:Array=[]
 for id:int in [51731,41852,46813,726]:
  var actor:Dictionary=manifest.records[str(id)]
  var context:Dictionary=actor.get("source_contexts",[actor])[0]
  var key:String="lineagem_base508:npc:%d:spawn:%d:territory:%d"%[id,int(context.spawn_view_id),int(context.territory_link_id)]
  var value:Dictionary=ROSTER.record(key,"",{"source_m_allow_contextual":true})
  if value.is_empty():blocked.append(id)
  else:ready.append(id)
 var complete_726:bool=str(args.get("expect-caster726-ready","false"))=="true"
 check(ready==([51731,41852,46813,726]if complete_726 else[51731,41852,46813])and blocked==([]if complete_726 else[726]),"complete caster effects required; missing impact blocks factory")
 var bad:Dictionary=await installer.install_zip(args.corrupt)
 check(not bool(bad.get("ok",false)),"corrupt update rejected")
 check(INSTALL.monster_root()==active,"failed update preserves active root")
 check(FileAccess.file_exists(active.path_join("installed.json")),"failed update preserves receipt")
 print("BASE508_REPRESENTATIVE_INSTALL ",JSON.stringify({"records":manifest.records.size(),"ready_casters":ready,"blocked_casters":blocked,"errors":errors,"full_pack_install_tested":false}))
 installer.free();quit(0 if errors.is_empty()else 1)
