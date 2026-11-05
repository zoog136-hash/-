extends SceneTree
const Policy = preload("res://scripts/honing/outcome_policy.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	for level: int in [7,8,9]:
		var successes: int = 0
		for roll: int in range(100):
			var result: Dictionary = Policy.resolve(level,roll)
			if result.success: successes += 1
		check(successes == Policy.SUCCESS_PERCENT[level],"exact public probability at " + str(level))
		var failed: Dictionary = Policy.resolve(level,99)
		check(not failed.success and not failed.target_destroyed and failed.enchant_delta == 0,"estimated failure preserves target and enchant")
		check(failed.materials_consumed_percent == 100 and failed.materials_refund_percent == 0,"estimated no refund")
		check(not failed.failure_policy.original_verified and failed.failure_policy.evidence == "estimate_after_public_search","estimate never labeled original")
	for bad: Array in [[6,0],[10,0],[7,-1],[7,100]]:
		check(not Policy.resolve(bad[0],bad[1]).ok,"unsupported input rejected")
	var target: Dictionary = {"name":"synthetic gear","level":7,"record":{"source_item_class_id":9001},"options":{"keep":7}}
	var binding: Dictionary = {"entity_id":1,"honing_id":2,"item_class_id":9001,"epithet_id":3,"bonus_ids":[4]}
	var failed: Dictionary = Policy.target_candidate(target,binding,99)
	check(failed.ok and failed.target == target and not failed.use_authorized,"failure returns unchanged target without authorization")
	var success: Dictionary = Policy.target_candidate(target,binding,0)
	check(success.ok and success.target.honing.source_binding == binding and not success.use_authorized,"success retains source references without authorization")
	check(success.target.level == 7 and success.target.options == target.options and success.target.record == target.record,"success preserves enchant record options")
	check(not target.has("honing"),"candidate generation does not mutate live target")
	check(not Policy.target_candidate(success.target,binding,0).ok,"rehoning rejected")
	success.target.honing.source_binding.bonus_ids.append(99)
	check(binding.bonus_ids == [4],"source references deeply copied")
	var wrong: Dictionary = binding.duplicate(true)
	wrong.item_class_id = 9999
	check(not Policy.target_candidate(target,wrong,0).ok,"wrong physical source binding rejected")
	print("HONING_OUTCOME_POLICY_CHECKS ",checks," failures=",failures)
	quit(1 if failures else 0)
