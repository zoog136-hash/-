extends SceneTree
const ENHANCE=preload("res://scripts/crafting/patch523_enhancement.gd")
const COMBAT=preload("res://scripts/crafting/patch523_equipment_combat.gd")
class SyntheticBook extends RefCounted:
	var data: Dictionary={"items":{"101":{}}}
	func catalog_identity_matches(record: Dictionary,_id: String) -> bool:return record.get("name")=="synthetic"
func _initialize() -> void:
	var book:=SyntheticBook.new()
	var record: Dictionary={"source":"inven","sourceId":"101","name":"synthetic"}
	var checks: Array=[
		ENHANCE.rule(book,record,"138",0,-1,1).get("success",-1)==0.0,
		ENHANCE.rule(book,record,"138",0,1,3).get("success",-1)==0.0,
		ENHANCE.rule(book,{"source":"inven","sourceId":"101","name":"conflict"},"138",0,1,1).get("success",-1)==0.0,
		ENHANCE.prepare(book,record,-1)==record]
	var option: Dictionary={"ID":11,"Param1":20,"Param2":0,"Param3":0,"Param4":false,"Param5":false,"Param6":0,"MaterialTypeID":0,"MaterialAmount":0,"IsAmmoAttack":false,"WeaponGroupID":0,"ShieldTypeID":0,"SuccessedInvokeOptionID":0,"TargetKind":0,"SiegeTargetKind":0,"InvokeOptionTypeID":3,"AttackTypeID":0,"BySpellAttack":false}
	var effect: Dictionary={"row_id":1,"kind":"attack_fixed_damage","probability":20000,"option":option}
	checks.append(COMBAT.valid(effect))
	for pair: Array in [["ID",null],["BySpellAttack","false"],["Param1",1.5],["MaterialAmount",1],["IsAmmoAttack",true],["AttackTypeID",62]]:
		var malformed: Dictionary=effect.duplicate(true);malformed.option[pair[0]]=pair[1]
		checks.append(not COMBAT.valid(malformed))
	checks.append(COMBAT.level_effects({"patch523_invoke_options":[]},0).is_empty())
	checks.append(COMBAT.level_effects({"patch523_invoke_options":{"0":[12,"bad",{"option":false}]}},0).is_empty())
	print("PATCH523_ENHANCEMENT_GUARDS ",JSON.stringify({"checks":checks.size(),"passed":checks.count(true),"scope":"synthetic rejection paths only"}))
	quit(0 if checks.count(true)==checks.size() else 1)
