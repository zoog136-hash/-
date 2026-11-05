extends SceneTree
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const PACK=preload("res://scripts/monsters/base508_monster_pack_cache.gd")
const ACTIONS=preload("res://scripts/monsters/base508_boss_host_adoptions.gd")
const COMBAT=preload("res://scripts/monsters/base508_boss_combat.gd")
const VIEW=preload("res://scripts/monsters/base508_monster_view.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var path:String=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--lineagem-monster-pack="):path=arg.trim_prefix("--lineagem-monster-pack=")
 if path.is_empty():print("BASE508_ORDINARY_CONTRACT_SKIPPED: explicit private pack required");quit(0);return
 var manifest:Dictionary=PACK.manifest(path);var catalog:Dictionary=COMBAT.data(path.get_base_dir());var errors:Array=[];var ids:Array=[];var pixels:int=0
 for nid:String in manifest.get("records",{}):
  var row:Dictionary=manifest.records[nid];var p:Dictionary=row.get("source_actor_profile",{})
  if p.get("source_behavior_family","")!="source_motion_without_basic_attack"or int(p.get("source_sparse_attachment_slot_count",-1))!=0 or not p.get("unresolved_source_action_ids",[]).is_empty():continue
  var actor:Dictionary=PACK.actor(path,int(nid));var contract:Dictionary=ACTIONS.actor_contract(int(nid),int(row.sprite_id),p,actor.tracks,catalog)
  if contract.get("contract","")!="base508_exact_context_ordinary_host_action_v1":continue
  var record:Dictionary={};var key:String=""
  for context:Dictionary in row.source_contexts:
   key="lineagem_base508:npc:%d:spawn:%d:territory:%d" % [int(nid),int(context.spawn_view_id),int(context.territory_link_id)]
   record=ROSTER.record(key,path,{"source_m_allow_contextual":true})
   if not record.is_empty():break
  if record.is_empty():errors.append("No valid explicit source context "+nid);continue
  if not ROSTER.record(key,path).is_empty():errors.append("Source actor enabled without explicit activation "+nid)
  if record.get("source_m_host_action_contract",{})!=contract:errors.append("Factory contract changed "+nid)
  if actor.tracks.has("attack"):errors.append("Original missing basic attack overwritten "+nid)
  var action:int=int(contract.attack_action_id);var view=VIEW.new()
  if not view.configure(record,path):errors.append("Exact source view rejected "+nid);view.free();continue
  for facing:int in [0,4]:
   if not view.advance_source_action(action,0.0,facing,1):errors.append("Native action rejected "+nid)
   if view.last_source_frame<0:errors.append("Native frame unavailable "+nid)
   for sprite:Sprite2D in view._layers:
    if sprite.visible and sprite.texture!=null:pixels+=1
  view.clear_source_action();view.advance(0.0,"idle",0,2,false,false)
  if view.source_state_status.get("role","")!="idle":errors.append("Idle restore failed "+nid)
  view.free();ids.append(int(nid))
 ids.sort()
 print("BASE508_ORDINARY_SOURCE_CONTRACT ",JSON.stringify({"actors":ids.size(),"source_ids":ids,"source_layer_samples":pixels,"errors":errors,"automatic_geographic_spawns":0}))
 quit(0 if errors.is_empty()and ids.size()==24 and pixels>0 else 1)
