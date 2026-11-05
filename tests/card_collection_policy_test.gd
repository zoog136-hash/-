extends SceneTree
const Runtime=preload("res://scripts/cards/collection_runtime.gd")
const Policy=preload("res://scripts/cards/collection_policy.gd")
class Host:
 extends Node
 var hp: int=100
 var mp: int=20
 var equipment_records_dirty: bool=false
 var equipment_effects_dirty: bool=false
 var reject: bool=false
 func _invalidate_equipment_static() -> void:pass
 func _effective_max_hp() -> int:return 90
 func _effective_max_mp() -> int:return 15
 func _save_game(_quiet: bool) -> Error:return ERR_CANT_CREATE if reject else OK
 func _update_hud() -> void:pass
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize() -> void:
 var host=Host.new();var runtime=Runtime.new();runtime.world=host
 var profile: Dictionary={"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}
 var unknown: Dictionary={"schema":99,"server_context":profile,"future":[1,2,3]}
 runtime.import_policy(unknown)
 check(runtime.export_policy()==unknown and not runtime.estimated() and runtime.source_server_context().is_empty(),"unknown version preserved without interpreting context or estimates")
 check(runtime.apply_policy({"death_damage_per_point":2.0},profile).ok,"valid explicit local edit")
 check(runtime.export_policy().prior_unrecognized_policy==unknown,"edit archives unknown prior policy")
 check(host.hp==90 and host.mp==15,"explicit context/settings change clamps only lower caps")
 var saved: Dictionary=runtime.export_policy();saved["future_top"]="keep";saved["values"]["future_child"]=[4,5]
 runtime.import_policy(saved)
 check(runtime.apply_policy({"death_damage_per_point":3.0}).ok and runtime.export_policy().future_top=="keep" and runtime.export_policy()["values"].future_child==[4,5],"known edit retains unknown nested/top-level fields")
 var prior: Variant=runtime.export_policy();var prior_context: Dictionary=runtime.source_server_context()
 host.hp=100;host.mp=20;host.reject=true
 check(not runtime.apply_policy({"death_damage_per_point":4.0},{}).ok,"controlled failed write")
 check(runtime.export_policy()==prior and runtime.source_server_context()==prior_context and host.hp==100 and host.mp==20,"rejected write restores policy/context and HP/MP")
 check(not Policy.validate({"final_blow_multiplier":NAN}).ok and not Policy.validate({"estimates_enabled":1}).ok and not Policy.validate({"ranged_burst_min_hits":2.5}).ok,"invalid/nonfinite policy values rejected")
 host.free()
 print("CARD_COLLECTION_POLICY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"policy state only; actual saving covered by Main/UI tests"}))
 quit(0 if failures.is_empty() else 1)
