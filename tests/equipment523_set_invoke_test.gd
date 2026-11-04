extends SceneTree
const SUBJECT = preload("res://scripts/equipment523/set_invoke.gd")
var failed: int = 0
var checks: int = 0

class TestWorld extends Node:
	var rng := RandomNumberGenerator.new()
	var skill_cooldowns: Dictionary = {}
	var option_awakening: Variant = null
	var player := Node2D.new()

class Victim extends Node2D:
	var dead: bool = false
	var hp: int = 1000
	func take_damage(amount: int, _critical: bool, _kind: String) -> void:
		hp -= amount
		dead = hp <= 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(message)

func _initialize() -> void:
	var pack: Dictionary = {
		"source_sha256":"synthetic-contract",
		"items":{},
		"tables":{
			"ItemSet":[{"ID":7,"Name":"fixture","BuffClassID":0}],
			"ItemForItemSet":[{"ItemSetID":7,"ItemClassID":91},{"ItemSetID":7,"ItemClassID":92}],
			"ItemSetBonus":[{"ItemSetID":7,"CompletionDegree":2,"BonusID":1}],
			"ItemBonus":[{"ItemClassID":91,"BonusID":2,"IsPossession":false}],
			"ItemInvokeReplacementEntityView":[
				{"ID":21,"ItemInvokeReplacementID":9,"SlotNumber":3,"ItemInvokeReplacementBonusGroupID":10,"Prob":1000000},
				{"ID":22,"ItemInvokeReplacementID":9,"SlotNumber":3,"ItemInvokeReplacementBonusGroupID":11,"Prob":0}],
			"ItemInvokeReplacementBonusGroup":[{"ID":10,"Name":"fixture damage"},{"ID":11,"Name":"None"}],
			"ItemInvokeReplacementBonus":[{"ItemInvokeReplacementBonusGroupID":10,"EnchantLevel":0,"BlessCode":0,"BonusID":3}],
			"InvokeOption":[{"ID":8,"InvokeOptionTypeID":1,"Param1":100}],
			"SpellClass":[{"ID":100,"TargettingTypeID":2}],
			"SpellBonus":[]},
		"bonuses":{
			"1":{"supported":true,"record":{"strFlat":2},"raw":{"ID":1},"type":{"Name":"Strength"}},
			"2":{"supported":false,"raw":{"Value":9,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},"type":{"Name":"ItemInvokeReplacementID"}},
			"3":{"supported":false,"raw":{"Value":1000000,"BonusApplicationTypeID":10,"BonusApplicationTargetID":8},"type":{"Name":"InvokeOption","UnitID":3}}}}
	var target: Dictionary = {"source_id":"91","instance_id":"one","level":0,"bless_code":1,"equipped":true,"state":{"other_feature":{"preserve":true}}}
	var second: Dictionary = {"source_id":"92","instance_id":"two","equipped":true}
	check(SUBJECT.equipped(pack,[target,target],{}).records.is_empty(),"duplicate physical item cannot complete a set")
	check(SUBJECT.equipped(pack,[target,target.duplicate(true)],{}).details[0].count == 1,"same source counts once")
	check(SUBJECT.equipped(pack,[target,second],{}).records.size() == 1,"two exact members activate the set")
	var context: Dictionary = {"target":target,"materials":[{"source_id":"169994","amount":1}],"policy":{"invoke_slot":3}}
	check(SUBJECT.slot_options(pack,target).size() == 1 and SUBJECT.slot_options(pack,target)[0].slot == 3,"UI exposes only the variable source slot")
	var quote: Dictionary = SUBJECT.quote(pack,"invoke_replacement",context)
	check(bool(quote.get("ok",false)),"owned explicit ticket and variable slot produce a quote")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var result: Dictionary = SUBJECT.roll(pack,quote,rng)
	check(result.state.invoke_replacement.slots["3"].group_id == 10,"100% outcome uses source group")
	check(not target.state.has("invoke_replacement") and target.state.other_feature.preserve,"rolling stages state and preserves live unrelated data")
	target.state.merge(result.state.duplicate(true),true)
	check(SUBJECT.effects(pack,target,{}).size() == 1,"saved selection resolves to an invoke effect")
	var copied: Dictionary = target.duplicate(true)
	copied.instance_id = "another-physical-item"
	check(SUBJECT.effects(pack,copied,{}).is_empty(),"a copied namespace cannot activate on a different physical item")
	target.state.invoke_replacement.slots["3"].group_id = 999
	check(SUBJECT.effects(pack,target,{}).is_empty(),"forged group is not executed")
	target.state.merge(result.state.duplicate(true),true)
	context.target = target.duplicate(true)
	context.target.locked = true
	check(not SUBJECT.quote(pack,"invoke_replacement",context).ok,"locked target cannot spend tickets")
	context.target.locked = false
	context.policy.invoke_slot = 1
	check(not SUBJECT.quote(pack,"invoke_replacement",context).ok,"fixed or missing base slot cannot be rerolled")
	var names: Array[String] = ["SpellDamageBase","SpellDamageDiceNumber","SpellDamageDiceSpotCount","FixedMagicDamage","IgnoreMagicResistance","IgnoreDamageReductionCalculation"]
	var amounts: Array[int] = [70,1,1,1,1,1]
	for index: int in range(names.size()):
		var id: int = 1000 + index
		pack.bonuses[str(id)] = {"raw":{"Value":amounts[index],"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},"type":{"Name":names[index],"UnitID":20 if index in [3,4] else 1}}
		pack.tables.SpellBonus.append({"SpellClassID":100,"MinSpellLevel":0,"BonusID":id})
	check(SUBJECT.spell_contract(pack,pack.tables.InvokeOption[0]).ok,"fully fixed numeric spell has an execution contract")
	var world := TestWorld.new()
	var victim := Victim.new()
	var fired: Array = SUBJECT.on_hit(pack,world,[target],{},victim,"melee",true,false)
	check(fired.size() == 1 and victim.hp == 929,"actual invoke consumes fixed70+1d1 damage once")
	check(SUBJECT.on_hit(pack,world,[target],{},victim,"melee",true,true).is_empty(),"normal-attack invoke cannot fire from a spell")
	pack.tables.InvokeOption[0].InvokeOptionTypeID = 38
	check(not SUBJECT.spell_contract(pack,pack.tables.InvokeOption[0]).ok,"aura source invoke is not executed as an attack")
	victim.free()
	world.player.free()
	world.free()
	print("equipment523 set/invoke checks=%d failed=%d" % [checks,failed])
	print("EQUIPMENT523_SET_INVOKE_RESULT ",JSON.stringify({"checks":checks,"failures":[] if failed == 0 else ["failed"]}))
	quit(1 if failed else 0)
