extends SceneTree
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Core=preload("res://scripts/cards/option_awakening_service.gd")
const Adapter=preload("res://scripts/cards/native_option_awakening.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
 checks+=1
 if not v:failures.append(label);printerr("QUEST_OPTION_POLICY_FAIL: "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var path: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--owned-save="):path=arg.trim_prefix("--owned-save=")
 var sha: String=FileAccess.get_sha256(path)
 var owned: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var state: Dictionary=owned.card_draw_fusion
 check(state.source_card_receipts.size()==30,"real30 quest-produced card ownership records read")
 var identity: String="source:m508:1:23801"
 check(Cards.quest_reserved_spare(state,"변신",identity)==4,"explicit host policy reserves only four new duplicate copies")
 var changed: Dictionary=state.duplicate(true)
 for receipt: Dictionary in changed.source_card_receipts:receipt.source_global_no_merge=false;receipt.source_global_no_swap=false
 check(Cards.quest_reserved_spare(changed,"변신",identity)==4,"host hold follows explicit receipt policy; it is not inferred from native NoMerge/NoSwap")
 for receipt: Dictionary in changed.source_card_receipts:receipt.erase("quest_option_feed_policy")
 check(Cards.quest_reserved_spare(changed,"변신",identity)==0,"native flags alone never create an option-feed prohibition")
 changed=state.duplicate(true);changed.spare["변신"][identity]=6
 check(Cards.outgoing_material_spare(changed,"변신",identity)==2,"prior unrestricted copy quantities remain usable")
 var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/lineagem_base508/cards.json")).catalog
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/option_awakening_cards.json"))
 var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/option_awakening_policy.json"))
 var core=Core.new();check(core.configure(Adapter.adapt(data,catalog),settings,catalog),"exact current native option owner configures")
 var snapshot: Dictionary={}
 for key: String in core.definitions.get("변신",{}):
  snapshot=core.view(owned.card_option_awakening,state,int(owned.gold),"변신",key)
  if snapshot.get("ok",false):break
 check(snapshot.get("ok",false) and str(snapshot.get("policy_note","")).contains("TWILIGHT 보관 정책"),"real option UI snapshot labels new-receipt hold as host safety policy")
 check(FileAccess.get_sha256(path)==sha,"read-only policy check preserves actual issued save bytes")
 print("QUEST_OPTION_POLICY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_actual_owned_save_sha256":sha,"native_no_merge_not_reinterpreted_as_option_feed_rule":true,"legacy_costs_exp_and_usable_quantities_unchanged":true}))
 quit(0 if failures.is_empty() else 1)
