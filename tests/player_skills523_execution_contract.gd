extends SceneTree
const SOURCE=preload("res://scripts/skills/player_skills523.gd")
var failures: Array=[]
var checks:=0
class Owner extends Node:
	var job_class: String="군주"
	var level:=90
	var equipped_items: Dictionary={}
	func _current_weapon_type() -> String:return ""

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("EXECUTION523_FAIL ",label)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var adapter:=SOURCE.new()
	adapter.configure_arguments()
	check(adapter.profiles.size()==441,"verified full pack loaded")
	if adapter.profiles.is_empty():quit(2);return
	var id: String="lm_b9f1605d690c64f7"
	var profile: Dictionary=adapter.evidence_for(id)
	check(not adapter.progression_rules.graph_for(id,profile).is_empty(),"reviewed execution graph present")
	var input_path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--player-skills523-pack="):input_path=arg.get_slice("=",1)
	var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(input_path))
	var original_sha: String=adapter.active_sha256;var revision: int=adapter.revision
	pack.profiles[id].execution_graph.spells[0].row.ID=999999
	pack.profiles[id].execution_graph.spells[0].row_json=JSON.stringify(pack.profiles[id].execution_graph.spells[0].row)
	var bad_path: String="user://invalid-execution523.json"
	var file:=FileAccess.open(bad_path,FileAccess.WRITE);file.store_string(JSON.stringify(pack));file.close()
	check(not adapter.load_pack(bad_path,FileAccess.get_sha256(bad_path)),"unreviewed child identity rejected despite self-consistent row JSON and file hash")
	check(adapter.active_sha256==original_sha and adapter.revision==revision and adapter.evidence_for(id)==profile,"failed graph replacement preserves active source snapshot")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	pack=JSON.parse_string(FileAccess.get_file_as_string(input_path))
	pack.profiles["lm_b08f206fe97abc83"].execution_graph.invokes=[]
	file=FileAccess.open(bad_path,FileAccess.WRITE);file.store_string(JSON.stringify(pack));file.close()
	check(not adapter.load_pack(bad_path,FileAccess.get_sha256(bad_path)),"missing typed invoke edge cannot connect arbitrary child nodes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	check(not adapter.set_progression_setting(id,"native_mp",0) and not adapter.set_progression_setting(id,"power",NAN),"original costs and nonfinite own values rejected")
	var owner:=Owner.new();root.add_child(owner)
	var catalog:=preload("res://scripts/skills/skill_catalog.gd").new();catalog.configure(owner)
	var canonical: Dictionary=catalog.record_for("lm_d44e85981c877135")
	var copied: Dictionary=catalog.resolve(canonical.duplicate(true))
	check(catalog.resolved_cache.has(str(canonical.id)),"exact UI deep copies reuse canonical source cache")
	var changed: Dictionary=canonical.duplicate(true);changed["power"]=777
	check(catalog.resolve(changed).power==777 and catalog.resolve(canonical).power!=777,"altered copies cannot poison canonical cache")
	copied.stats.lightRadius=1
	check(catalog.resolve(canonical).stats.lightRadius==160,"returned projection edits cannot mutate cached native stats")
	owner.free()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--skills523-compat-pack="):
			var old_path: String=arg.get_slice("=",1)
			check(adapter.load_pack(old_path,FileAccess.get_sha256(old_path)),"previous v2 remains readable")
			check(adapter.progression_rules.graph_for(id,adapter.evidence_for(id)).is_empty(),"v2 without execution evidence cannot implicitly enable new roles")
			var clear: String="lm_62bee07ed64c92aa"
			check(not adapter.recovery_rules.spec_for(clear,adapter.evidence_for(clear)).is_empty(),"previous seven recovery roles remain available with v2")
	print("SKILLS523_EXECUTION_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
