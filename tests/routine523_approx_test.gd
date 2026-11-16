extends SceneTree
## TWILIGHT 근사: the 8 routines with no offset Goal row are linked to the unused Goal row
## naming the same content/action (routine523_source.APPROX_GOAL_LINKS). With the original
## ZIP: each linked mission has its goal (type, class, amount) and no goal_missing reason.
const SRC = preload("res://scripts/routine523/routine523_source.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("ROUTINE523_APPROX_FAIL: ",label)

func _initialize() -> void:
	if not SOURCE.not_installed():
		SRC.reset()
		var c: Dictionary = SRC.load_contract()
		check(c.get("ok",false), "contract: "+str(c.get("problem","")))
		if c.get("ok",false):
			var linked: Dictionary = {}
			var open: int = 0
			for id: Variant in c.missions:
				var mission: Dictionary = c.missions[id]
				if mission.reasons.is_empty(): open += 1
				if mission.has("approx_goal_link"): linked[str(id)] = {"goal":mission.approx_goal_link,"type":str(mission.get("goal",{}).get("type","")),"amount":int(mission.get("goal",{}).get("amount",0)),"reasons":mission.reasons}
			evidence["linked"] = linked
			evidence["open_missions"] = open
			evidence["missions"] = c.missions.size()
			check(linked.size() == 8, "8 routines linked: "+str(linked))
			for key: String in linked:
				check(not (linked[key].reasons as Array).has("goal_missing") and not str(linked[key].type).is_empty(), "%s has its goal %s" % [key,str(linked[key])])
	else:
		check(SRC.load_contract().get("code","") == "source_not_installed", "without the original ZIP the contract is refused")
	print("ROUTINE523_APPROX_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
