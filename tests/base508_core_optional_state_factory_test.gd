extends SceneTree
## Opt-in exact source IDs from a private manifest; optional gaps stay declared.
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const FULL=preload("res://scripts/monsters/base508_authoritative_catalog.gd")
const PACK=preload("res://scripts/monsters/base508_monster_pack_cache.gd")
func _initialize()->void:
 var manifest:String="";var ids:PackedStringArray=[]
 var expected_contract:String="base508_exact_context_core_ready_optional_gaps_v1";var expected_action:int=1
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--monster-manifest="):manifest=arg.trim_prefix("--monster-manifest=")
  if arg.begins_with("--candidate-ids="):ids=arg.trim_prefix("--candidate-ids=").split(",",false)
  if arg.begins_with("--expected-contract="):expected_contract=arg.trim_prefix("--expected-contract=")
  if arg.begins_with("--expected-action="):expected_action=int(arg.trim_prefix("--expected-action="))
 if manifest.is_empty()or ids.is_empty():quit(2);return
 var errors:Array=[];var ready:Array=[]
 for id_string:String in ids:
  var id:int=int(id_string);var actor:Dictionary=PACK.actor(manifest,id)
  var result:Dictionary={}
  for key:String in FULL.context_keys(id):
   result=ROSTER.record(key,manifest,{"source_m_allow_contextual":true})
   if not result.is_empty():break
  if result.is_empty():errors.append("factory rejected exact source ID "+id_string);continue
  var contract:Dictionary=result.get("source_m_host_action_contract",{})
  if contract.get("contract","")!=expected_contract or int(contract.get("attack_action_id",-1))!=expected_action:errors.append("wrong core contract "+id_string)
  if result.get("source_m_actor_profile",{})!=actor.get("source_actor_profile",{}):errors.append("optional source profile changed "+id_string)
  ready.append(id)
 print("BASE508_CORE_OPTIONAL_FACTORY ",JSON.stringify({"ready":ready,"errors":errors,"optional_missing_states_not_synthesized":true,"native_geographic_spawns":0}))
 quit(0 if errors.is_empty()else 1)
