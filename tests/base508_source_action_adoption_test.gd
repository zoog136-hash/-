extends SceneTree
## Optional private-data test: no fixture artwork or invented native attack clip.
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const PACK=preload("res://scripts/monsters/base508_monster_pack_cache.gd")
const VIEW=preload("res://scripts/monsters/base508_monster_view.gd")
const ACTIONS=preload("res://scripts/monsters/base508_boss_host_adoptions.gd")
const COMBAT=preload("res://scripts/monsters/base508_boss_combat.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var path: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--lineagem-monster-pack="): path=arg.trim_prefix("--lineagem-monster-pack=")
 if path.is_empty() or not FileAccess.file_exists(path):
  print("BASE508_SOURCE_ACTION_ADOPTION_SKIPPED: explicit private manifest required")
  quit(0);return
 var errors: Array=[];var ready: int=0;var source_layers: int=0
 for spec: Array in [[66993,300203,140833,243953],[67033,300213,140843,244103]]:
  var nid: int=int(spec[0]);var key: String="lineagem_base508:npc:%d:spawn:%d:territory:%d" % [nid,int(spec[1]),int(spec[2])]
  var record: Dictionary=ROSTER.record(key,path,{"source_m_allow_contextual":true})
  if record.is_empty(): errors.append("Exact source action actor rejected "+str(nid));continue
  var actor: Dictionary=PACK.actor(path,nid);var contract: Dictionary=record.get("source_m_host_action_contract",{})
  if int(contract.get("explicit_attack_id",-1))!=int(spec[3]) or int(contract.get("attack_action_id",-1))!=18: errors.append("Wrong adopted attack "+str(nid))
  if actor.get("tracks",{}).has("attack"): errors.append("Native missing basic attack was aliased "+str(nid))
  if not actor.get("source_actor_profile",{}).get("missing_roles",[]).has("attack"): errors.append("Source capability changed "+str(nid))
  if not ROSTER.record(key,path).is_empty(): errors.append("Contextual source actor enabled by default "+str(nid))
  var catalog: Dictionary=COMBAT.data(path.get_base_dir())
  if not ACTIONS.actor_contract(nid,20319,actor.source_actor_profile,actor.tracks,{}).is_empty(): errors.append("Missing combat table accepted "+str(nid))
  if not ACTIONS.actor_contract(nid,20320,actor.source_actor_profile,actor.tracks,catalog).is_empty(): errors.append("Wrong source sprite accepted "+str(nid))
  var view=VIEW.new()
  if not view.configure(record,path): errors.append("Native actor view rejected "+str(nid));view.free();continue
  if not view.advance_source_action(18,0.0,0,1): errors.append("Authored action18 rejected "+str(nid))
  if view.last_source_frame<0: errors.append("Native action had no pixel frame "+str(nid))
  if view.supports_state("attack"): errors.append("Basic attack invented "+str(nid))
  for layer: Sprite2D in view._layers:
   if layer.visible and layer.texture!=null: source_layers+=1
  view.clear_source_action();view.advance(0.0,"idle",0,2,false,false)
  if view.source_state_status.get("role","")!="idle": errors.append("Native action did not return to idle "+str(nid))
  view.free();ready+=1
 print("BASE508_SOURCE_ACTION_ADOPTION ",JSON.stringify({"actors":ready,"visible_source_layers":source_layers,"errors":errors}))
 quit(0 if errors.is_empty() and ready==2 and source_layers>0 else 1)
