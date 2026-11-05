extends SceneTree
## Synthetic contracts only; original buff rows stay in the private pack.
const Subject = preload("res://scripts/equipment523/invoke_debuff.gd")
const RealStatus = preload("res://scripts/skills/status_service.gd")
var checks: int = 0
var failures: Array[String] = []

class Status extends RefCounted:
	var sources: Dictionary = {}
	func set_modifiers(actor: Node, source: String, duration: float, values: Dictionary) -> void:
		if not sources.has(actor.get_instance_id()): sources[actor.get_instance_id()] = {}
		sources[actor.get_instance_id()][source] = {"duration":duration,"values":values.duplicate(true)}
	func remove_modifiers(actor: Node, source: String) -> void:
		if sources.has(actor.get_instance_id()): sources[actor.get_instance_id()].erase(source)
	func modifier(actor: Node, field: String) -> float:
		var value: float = 0
		for entry: Dictionary in sources.get(actor.get_instance_id(),{}).values():
			if entry.values.has(field): value = float(entry.values[field])
		return value

class Skills extends RefCounted:
	var status = Status.new()

class World extends Node:
	var original_skills = Skills.new()
	var rng := RandomNumberGenerator.new()
	var combat_generation: int = 1
	var owner_accept: bool = true
	var owner_spell: int = 10
	func _equipment523_invoke_owner(origin: Dictionary, spell_id: int) -> bool:
		return owner_accept and spell_id == owner_spell and origin.get("instance_id") == "physical:1" and origin.get("source_id") == 100 and origin.get("slot") == 2 and origin.get("bonus_id") == 900

class Actor extends Node2D:
	var world_controller: Node
	var life_id: int = 1
	var dead: bool = false
	var is_boss: bool = false
	var attack_power: int = 100
	var melee_accuracy: int = 30
	var stun_resistance: float = 0
	var hold_resistance: float = 0
	var status_immunities: Array = []
	var stun_remaining: float = 10
	var hold_remaining: float = 10
	var notified_control: String = ""
	func on_equipment523_control(kind: String) -> void: notified_control = kind

func _initialize() -> void:
	var world := World.new()
	var actor := Actor.new()
	actor.world_controller = world
	var policy: Dictionary = settings()
	var option: Dictionary = {"ID":9,"InvokeOptionTypeID":1,"Param1":10}
	var pack: Dictionary = fixture([["MeleeDamage",1,-5,0,0],["MeleeHit",1,-1,0,0]])
	check(not Subject.contract(pack,option,{}).ok,"unmarked host formula is rejected")
	var parsed: Dictionary = Subject.contract(pack,option,policy)
	check(parsed.ok and parsed.duration_min == 32 and parsed.duration_max == 32,"source units and exact duration form a contract")
	actor.set_meta("source_invisible",true)
	var before_hidden: int = world.rng.state
	check(not Subject.apply(pack,world,actor,option,policy,origin()).ok and world.rng.state == before_hidden,"source CanCastOnInvisible restriction blocks direct debuff application before RNG or mutation")
	actor.remove_meta("source_invisible")
	world.original_skills.status.set_modifiers(actor,"unrelated",100,{"ac":7})
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"typed scalar debuff reaches actual runtime layer")
	check(Subject.outgoing(actor,100,"melee") == 95 and Subject.outgoing(actor,100,"ranged") == 100,"melee damage change is channel-scoped")
	check(Subject.accuracy_delta(actor,"melee") == -1 and Subject.accuracy_delta(actor,"ranged") == 0,"melee accuracy change has a numeric consumer")
	check(actor.attack_power == 100 and actor.melee_accuracy == 30,"base actor stats are never destructively edited")
	Subject.tick(world,33)
	check(Subject.outgoing(actor,100,"melee") == 100 and Subject.accuracy_delta(actor,"melee") == 0,"timed debuff expires without residual stats")
	check(world.original_skills.status.sources[actor.get_instance_id()].has("unrelated"),"expiration preserves unrelated skill modifiers")
	pack = fixture([["ArmorClassBonus",1,-12,0,0],["SpecialResistance",3,-100000,2,6]])
	parsed = Subject.contract(pack,option,policy)
	check(parsed.ok and parsed.status.ac == 12 and parsed.status.status_resistance_6 == -10,"source AC sign and Percentage divisor match existing consumers")
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"AC and status resistance reach the status service")
	check(world.original_skills.status.sources[actor.get_instance_id()]["equipment523-debuff:20"].values.ac == 12,"actual status modifier receives positive worsened AC")
	pack = fixture([["DamageReduction",1,-5,0,0],["HPHealDecreasePercent",3,100000,0,0],["HPPotionDecreasePercent",3,200000,0,0]])
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"recovery debuff applies alongside reduction")
	check(Subject.healing_weight(actor,false) == 100000 and Subject.healing_weight(actor,true) == 200000,"recovery exposes exact raw 1M weights for existing maximum stacking")
	actor.life_id += 1
	check(Subject.healing_weight(actor,false) == 0,"a new life cannot inherit the old actor debuff")
	Subject.tick(world,0)
	pack = fixture([["CannotMove",20,1,0,0],["StatusEffectID",121,300,0,0],["MeleeEvasion",1,-10,0,0],["RangeEvasion",1,-10,0,0]],7,2,3)
	parsed = Subject.contract(pack,option,policy)
	check(parsed.ok and parsed.control == "hold" and parsed.source_control == 7,"source hold is explicitly mapped to the host hold state")
	var result: Dictionary = Subject.apply(pack,world,actor,option,policy,origin())
	check(result.ok and result.duration >= 2 and result.duration <= 3 and Subject.control_active(actor,"hold") and actor.notified_control == "hold","independent hold receives a source-bounded duration and notifies its consumer")
	actor.status_immunities = ["hold"]
	check(not Subject.apply(pack,world,actor,option,policy,origin()).ok,"host control immunity is preserved")
	actor.status_immunities.clear()
	var effects: Array = []
	for name: String in Subject.CONTROL_FIELDS: effects.append([name,20,1,0,0])
	effects.append(["StatusEffectID",121,200,0,0])
	effects.append(["DamageReduction",1,-10,0,0])
	pack = fixture(effects,2,2,3)
	check(Subject.contract(pack,option,policy).ok,"full source petrification flags require the explicit host stun mapping")
	result = Subject.apply(pack,world,actor,option,policy,origin())
	check(result.ok and result.duration >= 2 and result.duration <= 3 and Subject.control_active(actor,"stun") and actor.notified_control == "stun","independent petrification mapping controls the actor")
	actor.stun_resistance = 100
	check(not Subject.apply(pack,world,actor,option,policy,origin()).ok,"host stun resistance can reject the approximation")
	actor.stun_resistance = 0
	world.original_skills.status.set_modifiers(actor,"unrelated-resistance",100,{"status_resistance_6":100})
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"source stun resistance 6 cannot block source petrification 2")
	world.original_skills.status.set_modifiers(actor,"source-petrification-resistance",100,{"status_resistance_2":100})
	result = Subject.apply(pack,world,actor,option,policy,origin())
	check(not result.ok and result.attempted and result.resisted,"source petrification resistance 2 participates in its own control check")
	world.original_skills.status.remove_modifiers(actor,"source-petrification-resistance")
	world.original_skills.status.remove_modifiers(actor,"unrelated-resistance")
	var wrong: Dictionary = policy.duplicate(true)
	wrong.invoke_debuff_control_map["2"] = "hold"
	check(not Subject.contract(pack,option,wrong).ok,"a weaker mapping cannot silently drop petrification conditions")
	pack = fixture([["UnknownSideEffect",1,5,0,0]])
	check(not Subject.contract(pack,option,policy).ok,"unconnected buff effects reject the entire contract")
	pack = fixture([["MeleeDamage",1,-5,0,0]])
	pack.tables.SpellClass[0].TargetAreaRadius = 1
	check(not Subject.contract(pack,option,policy).ok,"area spells are not flattened into a single target")
	pack = fixture([["MeleeDamage",1,-5,0,0]])
	pack.tables.BuffBonus[0].CharacterLevel = 1
	check(not Subject.contract(pack,option,policy).ok,"conditional source rows are rejected")
	pack = fixture([["MeleeDamage",3,-5,0,0]])
	check(not Subject.contract(pack,option,policy).ok,"mismatched source units are rejected")
	pack = fixture([["MeleeDamage",1,-5,0,0]])
	pack.tables.BuffClass[0].IsEraseOnAttack = true
	check(not Subject.contract(pack,option,policy).ok,"unimplemented event expiration is not treated as a simple timer")
	Subject.clear(world)
	check(world.original_skills.status.sources[actor.get_instance_id()].has("unrelated"),"clear removes only this module's sources")
	actor.free()
	world.free()
	_test_ownership_and_lifecycle()
	_test_controls_and_randomness()
	_test_complete_source_guards()
	_test_actual_status_and_overlap()
	print("EQUIPMENT523_INVOKE_DEBUFF_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func origin() -> Dictionary:
	return {"instance_id":"physical:1","source_id":100,"slot":2,"bonus_id":900}

func settings() -> Dictionary:
	return {"invoke_debuff_mode":"source_numbers_host_controls_v1","invoke_debuff_stack_mode":"latest_field","invoke_debuff_hit_mode":"proc_only","invoke_debuff_world_rules":"pve_no_alignment_or_counter_v1","invoke_debuff_duration_mode":"source_uniform_seconds","invoke_debuff_control_map":{"2":"stun","7":"hold"},"invoke_debuff_boss_chance_factor":1,"invoke_debuff_boss_duration_factor":1}

func _test_ownership_and_lifecycle() -> void:
	var world := World.new()
	var actor := Actor.new()
	actor.world_controller = world
	var option: Dictionary = {"InvokeOptionTypeID":1,"Param1":10}
	var pack: Dictionary = fixture([["MeleeDamage",1,-5,0,0]])
	var policy: Dictionary = settings()
	var before: int = world.rng.state
	var result: Dictionary = Subject.apply(pack,world,actor,option,policy)
	check(not result.ok and not result.attempted and world.rng.state == before,"missing physical origin fails before RNG")
	world.owner_accept = false
	result = Subject.apply(pack,world,actor,option,policy,origin())
	check(not result.ok and not result.attempted and world.rng.state == before,"unequipped or changed physical owner fails before RNG")
	world.owner_accept = true
	world.owner_spell = 11
	result = Subject.apply(pack,world,actor,option,policy,origin())
	check(not result.ok and not result.attempted,"a valid physical slot cannot authorize another spell")
	world.owner_spell = 10
	var wrong: Dictionary = origin()
	wrong.slot = 3
	check(not Subject.apply(pack,world,actor,option,policy,wrong).ok,"origin includes the exact variable slot")
	wrong = origin()
	wrong.source_id = "100"
	check(not Subject.apply(pack,world,actor,option,policy,wrong).ok,"physical origin IDs cannot be coerced from strings")
	var other_world := World.new()
	check(not Subject.apply(pack,other_world,actor,option,policy,origin()).ok,"a live actor in another world cannot receive this effect")
	actor.set_meta("is_player_combatant",true)
	check(not Subject.apply(pack,world,actor,option,policy,origin()).ok,"the current adaptation rejects player combatants")
	actor.remove_meta("is_player_combatant")
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok and world.rng.state == before,"a fixed-duration numeric effect consumes no extra RNG")
	world.combat_generation += 1
	Subject.tick(world,1)
	check(Subject.outgoing(actor,100,"melee") == 95,"same-map travel generation increments preserve the live debuff")
	Subject.clear(other_world)
	Subject.tick(other_world,100)
	check(Subject.outgoing(actor,100,"melee") == 95,"another world cannot clear or advance current effects")
	actor.life_id += 1
	check(Subject.outgoing(actor,100,"melee") == 100,"actor pooling cannot inherit a previous life's numeric state")
	Subject.tick(world,0)
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"the actor's new life can receive a new verified effect")
	actor.dead = true
	check(Subject.outgoing(actor,100,"melee") == 100,"death disables effects before the next module tick")
	Subject.tick(world,0)
	actor.dead = false
	check(Subject.outgoing(actor,100,"melee") == 100,"a cleared dead life does not resume its old effect")
	var other_actor := Actor.new()
	other_actor.world_controller = other_world
	check(Subject.apply(pack,other_world,other_actor,option,policy,origin()).ok,"a new world binds its own validated effects")
	Subject.clear(world)
	check(Subject.outgoing(other_actor,100,"melee") == 95,"previous Main teardown cannot clear the next Main's state")
	Subject.clear(other_world)
	check(Subject.outgoing(other_actor,100,"melee") == 100,"explicit current-world teardown removes timed effects")
	actor.free()
	other_actor.free()
	world.free()
	other_world.free()

func _test_controls_and_randomness() -> void:
	var world := World.new()
	var actor := Actor.new()
	actor.world_controller = world
	var option: Dictionary = {"InvokeOptionTypeID":1,"Param1":10}
	var pack: Dictionary = fixture([["CannotMove",20,1,0,0],["StatusEffectID",121,300,0,0],["MeleeEvasion",1,-10,0,0]],7,2,3)
	var policy: Dictionary = settings()
	world.rng.seed = 31233
	var before: int = world.rng.state
	actor.status_immunities = ["hold"]
	var result: Dictionary = Subject.apply(pack,world,actor,option,policy,origin())
	check(not result.ok and result.attempted and result.resisted and world.rng.state == before,"immunity is an attempted proc without an extra random draw")
	actor.status_immunities.clear()
	actor.hold_resistance = 100
	result = Subject.apply(pack,world,actor,option,policy,origin())
	check(not result.ok and result.attempted and result.resisted and world.rng.state == before,"certain resistance consumes no random draw")
	actor.hold_resistance = 0
	world.original_skills.status.set_modifiers(actor,"source-hold-resistance",100,{"status_resistance_7":100})
	result = Subject.apply(pack,world,actor,option,policy,origin())
	check(not result.ok and result.attempted and result.resisted and world.rng.state == before,"source hold resistance 7 participates without another random draw")
	world.original_skills.status.remove_modifiers(actor,"source-hold-resistance")
	var expected := RandomNumberGenerator.new()
	expected.state = before
	var expected_duration: float = expected.randf_range(2,3)
	result = Subject.apply(pack,world,actor,option,policy,origin())
	check(result.ok and is_equal_approx(result.duration,expected_duration) and world.rng.state == expected.state,"a guaranteed successful control draws only its variable duration")
	check(Subject.control_active(actor,"hold") and actor.hold_remaining == 10 and actor.stun_remaining == 10,"equipment control never writes merged builtin timers")
	check(not Subject.control_active(actor,"fear"),"only the explicitly supported independent controls are consumed")
	Subject.clear(world)
	check(not Subject.control_active(actor,"hold") and actor.hold_remaining == 10 and actor.stun_remaining == 10,"equipment teardown preserves unrelated builtin controls")
	actor.hold_resistance = 50
	before = world.rng.state
	expected.state = before
	var expected_success: bool = expected.randf() < .5
	if expected_success: expected.randf_range(2,3)
	result = Subject.apply(pack,world,actor,option,policy,origin())
	check(result.ok == expected_success and result.attempted and world.rng.state == expected.state,"fractional resistance draws once, then duration only on success")
	Subject.clear(world)
	actor.hold_resistance = 0
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"control fixture can be reapplied after explicit clear")
	Subject.tick(world,4)
	check(not Subject.control_active(actor,"hold") and actor.hold_remaining == 10,"the independent control expires without modifying builtin controls")
	Subject.clear(world)
	actor.free()
	world.free()

func _test_complete_source_guards() -> void:
	var option: Dictionary = {"InvokeOptionTypeID":1,"Param1":10}
	var policy: Dictionary = settings()
	var pack: Dictionary
	for field: String in ["MinCastRange","BackwardPathCount","TargetLimitCount","SiegeTargetKindID","HideCasterTime"]:
		pack = fixture([["MeleeDamage",1,-5,0,0]])
		pack.tables.SpellClass[0][field] = 1
		check(not Subject.contract(pack,option,policy).ok,"unsupported source spell condition is rejected: "+field)
	for field: String in ["IsAttackRange","IsChargeSpell","IsRequireSpellGroupMastery"]:
		pack = fixture([["MeleeDamage",1,-5,0,0]])
		pack.tables.SpellClass[0][field] = true
		check(not Subject.contract(pack,option,policy).ok,"unsupported source spell mode is rejected: "+field)
	for field: String in ["IsOverlapByPlayer","IsImmuneToDead","IsBuffGroup"]:
		pack = fixture([["MeleeDamage",1,-5,0,0]])
		pack.tables.BuffClass[0][field] = true
		check(not Subject.contract(pack,option,policy).ok,"unsupported source lifecycle is rejected: "+field)
	for field: String in ["IsAllowOverlap","IsEraseBySpellLevel"]:
		pack = fixture([["MeleeDamage",1,-5,0,0]])
		pack.tables.BuffGroup[0][field] = true
		check(not Subject.contract(pack,option,policy).ok,"unsupported source group mode is rejected: "+field)
	pack = fixture([["MeleeDamage",1,-5,0,0]])
	pack.tables.BuffGroup.clear()
	check(not Subject.contract(pack,option,policy).ok,"missing source group definitions reject the contract")
	pack = fixture([["CannotMove",20,1.5,0,0],["StatusEffectID",121,300,0,0]],7,2,3)
	check(not Subject.contract(pack,option,policy).ok,"TrueFalse control requires exactly one")
	pack = fixture([["MeleeDamage",1,-5,0,0]],2)
	check(not Subject.contract(pack,option,policy).ok,"a resistance selector without a control cannot be silently ignored")
	pack = fixture([["MeleeDamage",1,-5,0,0]])
	pack.tables.SpellClass[0].AlignmentTypeID = 3
	pack.tables.SpellClass[0].AlignmentChangeAmount = -5
	pack.tables.SpellClass[0].IsPierceCounterMagic = true
	var parsed: Dictionary = Subject.contract(pack,option,policy)
	check(parsed.ok and parsed.source_context.AlignmentChangeAmount == -5 and parsed.source_context.IsPierceCounterMagic,"source alignment and counter metadata remain visible in the adaptation contract")
	var wrong: Dictionary = policy.duplicate(true)
	wrong.erase("invoke_debuff_world_rules")
	check(not Subject.contract(pack,option,wrong).ok,"missing alignment and counter adaptation policy rejects the contract")

func _test_actual_status_and_overlap() -> void:
	var world := World.new()
	world.original_skills.status = RealStatus.new()
	var actor := Actor.new()
	actor.world_controller = world
	var policy: Dictionary = settings()
	var option: Dictionary = {"InvokeOptionTypeID":1,"Param1":10}
	var pack: Dictionary = fixture([["MeleeDamage",1,-5,0,0],["ArmorClassBonus",1,-3,0,0]])
	var other: Dictionary = fixture([["MeleeDamage",1,-9,0,0],["ArmorClassBonus",1,-7,0,0]],0,2,2,11,21,301)
	for table: String in other.tables: pack.tables[table].append_array(other.tables[table])
	pack.bonuses.merge(other.bonuses,true)
	world.original_skills.status.set_modifiers(actor,"unrelated",100,{"ac":1})
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"the actual status consumer accepts a verified equipment source")
	world.owner_spell = 11
	option.Param1 = 11
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok and Subject.outgoing(actor,100,"melee") == 91 and world.original_skills.status.modifier(actor,"ac") == 7,"different buffs use the same latest-value rule in numeric and actual status consumers")
	world.owner_spell = 10
	option.Param1 = 10
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok and Subject.outgoing(actor,100,"melee") == 95 and world.original_skills.status.modifier(actor,"ac") == 3,"refreshing an earlier buff moves both consumers to latest precedence")
	world.owner_spell = 11
	option.Param1 = 11
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"a different live source can be refreshed independently")
	Subject.tick(world,3)
	world.original_skills.status.tick(3)
	check(Subject.outgoing(actor,100,"melee") == 95 and world.original_skills.status.modifier(actor,"ac") == 3,"expiry restores the older live numeric and status fields")
	pack.tables.BuffClass[1].BuffGroupID = 300
	var before: int = world.rng.state
	var result: Dictionary = Subject.apply(pack,world,actor,option,policy,origin())
	check(not result.ok and not result.attempted and Subject.outgoing(actor,100,"melee") == 95 and world.rng.state == before,"unknown same-group replacement preserves existing effects without RNG")
	actor.life_id += 1
	world.original_skills.status.set_modifiers(actor,"new-life",100,{"ac":9})
	Subject.tick(world,0)
	check(world.original_skills.status.modifier(actor,"ac") == 9,"stale equipment cleanup cannot erase a new life's actual status sources")
	world.owner_spell = 10
	option.Param1 = 10
	check(Subject.apply(pack,world,actor,option,policy,origin()).ok,"a new life can install a new source in the actual status consumer")
	Subject.clear(world)
	check(world.original_skills.status.modifier(actor,"ac") == 9,"module clear preserves the new life's unrelated actual status modifier")
	actor.free()
	world.free()

func fixture(effects: Array, resistance: int = 0, low: int = 32, high: int = 32, spell_id: int = 10, buff_id: int = 20, group_id: int = 300) -> Dictionary:
	var pack: Dictionary = {"tables":{"SpellClass":[{"ID":spell_id,"TargettingTypeID":2,"TargetKindID":11}],"BuffClass":[{"ID":buff_id,"BuffGroupID":group_id,"IsGood":false,"IsEraseOnTimeEnd":true}],"BuffGroup":[{"ID":group_id,"IsAllowOverlap":false,"IsAllowPriority":false,"IsEraseBySpellLevel":false}],"SpellBonus":[],"BuffBonus":[]},"bonuses":{}}
	var spell_effects: Array = [["BuffClassID",16,buff_id],["SpellDebuffMinDuration",17,low],["SpellDebuffMaxDuration",17,high]]
	if resistance > 0: spell_effects.append(["SpecialResistanceTypeID",18,resistance])
	for index: int in range(spell_effects.size()):
		var row: Array = spell_effects[index]
		var id: int = 100+spell_id*100+index
		pack.tables.SpellBonus.append({"ID":id,"SpellClassID":spell_id,"BonusID":id,"MinSpellLevel":0})
		pack.bonuses[str(id)] = {"type":{"Name":row[0],"UnitID":row[1]},"raw":{"Value":row[2],"BonusApplicationTypeID":0,"BonusApplicationTargetID":0}}
	for index: int in range(effects.size()):
		var row: Array = effects[index]
		var id: int = 100000+buff_id*100+index
		pack.tables.BuffBonus.append({"ID":id,"BuffClassID":buff_id,"BonusID":id,"CharacterLevel":0,"CharacterClass":0,"MinSpellLevel":0})
		pack.bonuses[str(id)] = {"type":{"Name":row[0],"UnitID":row[1]},"raw":{"Value":row[2],"BonusApplicationTypeID":row[3],"BonusApplicationTargetID":row[4]}}
	return pack
