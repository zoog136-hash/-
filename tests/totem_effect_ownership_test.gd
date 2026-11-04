extends SceneTree

const Status = preload("res://scripts/skills/status_service.gd")
const Monster = preload("res://scripts/monster.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var target := Monster.new()
	var effect := {"type":{"Name":"HPPotionDecreasePercent"},"unit":{"Name":"Percentage"},"bonus":{"Value":150000,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0}}
	check(target.apply_source_option_debuff("card-probe",3,[effect]),"card effect accepted")
	check(target.apply_source_option_debuff("totem:17524",3,[effect]),"totem effect accepted")
	target.prune_source_option_debuffs({"card-probe":true})
	check(target.source_option_debuffs.size() == 2,"card owner retains its effect and does not prune totem")
	target.prune_source_option_debuffs({"totem:17524":true},"totem:")
	check(target.source_option_debuffs.size() == 2,"totem owner retains its effect and does not prune card")
	check(target.source_option_healing(100,true) == 85,"overlapping healing penalties follow existing maximum policy once")
	target.prune_source_option_debuffs({},"totem:")
	check(target.source_option_debuffs.has("card-probe") and not target.source_option_debuffs.has("totem:17524"),"totem cleanup leaves card effect")
	target.prune_source_option_debuffs({})
	check(target.source_option_debuffs.is_empty(),"card cleanup removes only remaining card effect")
	var status := Status.new()
	status.set_modifiers(target,"probe",10,{"reduction":100})
	for reached in range(5): check(status.damage_after_reduction(200,target,float(reached)/100.0) == 100+reached,"target reduction ignore %d percent" % reached)
	status.set_modifiers(target,"probe",10,{"reduction":-3})
	check(status.damage_after_reduction(200,target,0.04) == 203,"negative reduction modifier unchanged")
	status.remove_modifiers(target,"probe")
	check(status.damage_after_reduction(200,target,0.04) == 200,"no reduction means no bonus damage")
	status.clear()
	target.free()
	print("TOTEM_OWNERSHIP_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
