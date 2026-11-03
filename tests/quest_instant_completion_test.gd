extends SceneTree
const QUESTS = preload("res://scripts/quests/quest_runtime.gd")
var failed: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, reason: String) -> void:
	if not ok:
		failed.append(reason)
		printerr("QUEST_FAIL: "+reason)
func _run() -> void:
	var q = QUESTS.new()
	q.configure()
	check(q.definitions.size() == 6,"six local definitions loaded")
	check(q.apply_event("kill","버그베어",3).is_empty(),"locked chapter cannot pre-progress")
	var a: Array[Dictionary] = q.apply_event("kill","고스트")
	check(a.size() == 1 and str(a[0].id) == "story_001","first kill completes immediately")
	check(q.apply_event("kill","고스트").is_empty(),"repeated kill cannot duplicate reward")
	check(q.apply_event("kill","버그베어",2).is_empty(),"progress remains incomplete")
	check(q.apply_event("kill","버그베어",1).size() == 1,"third kill completes without NPC")
	check(q.apply_event("acquire","HP 물약",1).size() == 1,"pickup instantly completes")
	check(q.apply_event("acquire","HP 물약",100).is_empty(),"repeat pickup cannot duplicate reward")
	check(q.apply_event("acquire","수정 단검",1).size() == 1,"rare item acquisition completes")
	var state: Dictionary = q.export_state()
	var restored = QUESTS.new()
	restored.configure()
	check(restored.import_state(state),"valid quest state restored")
	check(restored.export_state() == state,"progress and completion persist")
	check(restored.apply_event("acquire","수정 단검",1).is_empty(),"reloaded completed quest not paid twice")
	check(not restored.import_state({"schema":1,"progress":{"unknown":1},"completed":{}}),"unknown quest state rejected")
	check(restored.export_state() == state,"invalid load cannot mutate live state")
	if failed.is_empty(): print("QUEST_INSTANT_PASS")
	quit(0 if failed.is_empty() else 1)
