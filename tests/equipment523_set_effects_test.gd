extends SceneTree
const Sets = preload("res://scripts/equipment523/set_effects.gd")
const SetInvoke = preload("res://scripts/equipment523/set_invoke.gd")
var checks: int = 0
var failures: Array = []
var private_source_contracts_checked: int = 0

class Victim extends Node:
	var hp: int = 30
	var mp: int = 10
	var life_id: int = 1
	var dead: bool = false
	func take_damage(amount: int, _critical: bool = false, _kind: String = "melee") -> void:
		hp = maxi(0,hp-amount)
		dead = hp <= 0

class Status extends RefCounted:
	var effects: Dictionary = {}
	func set_modifiers(target: Node, source: String, duration: float, values: Dictionary) -> void:
		effects[source] = {"id":target.get_instance_id(),"duration":duration,"values":values}
	func remove_modifiers(_target: Node, source: String) -> void: effects.erase(source)

class Skills extends RefCounted:
	var status = Status.new()

class Host extends Node:
	var hp: int = 40
	var mp: int = 20
	var rng = RandomNumberGenerator.new()
	var original_skills = Skills.new()
	func _effective_max_hp() -> int: return 50
	func _effective_max_mp() -> int: return 25

func _initialize() -> void:
	_test_contracts()
	_test_lifecycle()
	_test_hits()
	_test_cancel()
	_test_source_graph()
	print("equipment523 set effects: %d checks, %d failures" % [checks,failures.size()])
	print("EQUIPMENT523_SET_EFFECTS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"private_source_contracts_checked":private_source_contracts_checked,"scope":"SYNTHETIC_KERNEL_WITH_OPTIONAL_PRIVATE_SOURCE_CONTRACTS"}))
	quit(1 if not failures.is_empty() else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _bonus(pack: Dictionary, id: int, name: String, unit: int, value: int, app: int = 0, target: int = 0) -> void:
	pack.bonuses[str(id)] = {"raw":{"ID":id,"BonusTypeID":id,"Value":value,"BonusApplicationTypeID":app,"BonusApplicationTargetID":target},"type":{"ID":id,"Name":name,"UnitID":unit},"record":{},"supported":false}

func _fixture() -> Dictionary:
	var p: Dictionary = {"source_sha256":"d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832","tables":{},"bonuses":{},"items":{"1":{"raw":{"TestItem":false}},"2":{"raw":{"TestItem":false}},"3":{"raw":{"TestItem":false}},"4":{"raw":{"TestItem":false}}}}
	p.tables.ItemSet = [{"ID":1,"Name":"fixture","BuffClassID":50},{"ID":2,"Name":"[테스트] fixture"}]
	p.tables.ItemForItemSet = [{"ItemSetID":1,"ItemClassID":1},{"ItemSetID":1,"ItemClassID":2},{"ItemSetID":1,"ItemClassID":3},{"ItemSetID":1,"ItemClassID":4},{"ItemSetID":2,"ItemClassID":1}]
	p.tables.ItemSetBonus = []
	p.tables.DescData_Korean = [{"ID":100,"Description":"Synthetic source caption"}]
	var defs: Array = [[10,"ElementalResistance",3,100000,3,5],[11,"HitSpecialResistance",3,70000,2,8],[12,"CastSpeedBonus",3,50000,0,0],[13,"AttackDrainHP",1,1,0,0],[14,"AttackDrainMP",1,1,0,0],[15,"CanSenseInvisibility",20,1,0,0],[16,"RevealDoppelPolymorphChange",20,1,0,0],[17,"RevealCamouflage",20,1,0,0],[18,"FixedDesc",41,1,72,100],[19,"BuffClassID",16,50,0,0],[20,"InvokeOption",3,1000000,10,60]]
	for d: Array in defs:
		_bonus(p,d[0],d[1],d[2],d[3],d[4],d[5])
		p.tables.ItemSetBonus.append({"ID":d[0],"ItemSetID":1,"CompletionDegree":2,"BonusID":d[0]})
	p.tables.ItemSetBonus.append({"ID":99,"ItemSetID":2,"CompletionDegree":1,"BonusID":12})
	p.tables.InvokeOption = [{"ID":60,"InvokeOptionTypeID":1,"Param1":70,"Param4":true}]
	p.tables.SpellClass = [{"ID":70,"TargettingTypeID":2,"TargetKindID":52,"TestSpell":false},{"ID":71,"TargettingTypeID":1,"TestSpell":false}]
	p.tables.SpellBonus = []
	p.tables.TargetKind = [{"ID":52,"Name":"PCButMe"}]
	p.tables.BuffClass = [{"ID":50,"IsGood":true,"BuffGroupID":5,"IsImmuneToCancellation":true,"IsImmuneToDead":true},{"ID":51,"IsGood":false,"IsImmuneToCancellation":true},{"ID":52,"IsGood":true,"IsImmuneToCancellation":true}]
	p.tables.BuffBonus = []
	p.tables.BuffStack = [{"ID":53,"BuffClassID":51,"StackCount":1,"isAdditionalStack":false}]
	p.tables.BuffStackBonus = [{"ID":54,"BuffStackID":53,"BonusID":55}]
	_bonus(p,55,"PVPDamageReduction",1,-10)
	var spell_defs: Array = [[21,70,"BuffClassID",16,51],[22,70,"SpellDebuffMinDuration",17,8],[23,70,"SpellDebuffMaxDuration",17,8],[24,70,"NextSpellClassID",12,71],[25,71,"BuffClassID",16,52],[26,71,"SpellBuffDuration",17,8]]
	for d: Array in spell_defs:
		_bonus(p,d[0],d[2],d[3],d[4])
		p.tables.SpellBonus.append({"ID":d[0],"SpellClassID":d[1],"BonusID":d[0],"MinSpellLevel":0})
	p.tables.IntervalBonusCategory = []
	p.tables.IntervalBonus = []
	p.tables.UniversalGroupSet = []
	for attack: int in [1,2,52,62]: p.tables.UniversalGroupSet.append({"ID":attack,"GroupID":100,"UnitID":10431,"Value":attack})
	for stage: int in range(1,5):
		var category: int = 100+stage
		var selector: int = 200+stage
		var invoke_bonus: int = 300+stage
		var option: int = 400+stage
		var spell: int = 500+stage
		var buff: int = 600+stage
		_bonus(p,selector,"HPIntervalBonus",10674,category)
		p.tables.ItemSetBonus.append({"ID":selector,"ItemSetID":1,"CompletionDegree":stage,"BonusID":selector})
		p.tables.IntervalBonusCategory.append({"ID":category})
		p.tables.IntervalBonus.append({"ID":category,"IntervalBonusCategory":category,"Low":0,"High":20,"BonusID":invoke_bonus})
		_bonus(p,invoke_bonus,"InvokeOption",3,1000000,10,option)
		p.tables.InvokeOption.append({"ID":option,"InvokeOptionTypeID":2,"Param1":spell,"Param3":1,"Param4":true})
		p.tables.SpellClass.append({"ID":spell,"TargettingTypeID":1,"CastDelay":60000})
		p.tables.BuffClass.append({"ID":buff,"IsGood":true,"BuffGroupID":200,"IsImmuneToCancellation":false})
		for d: Array in [[700+stage,"SpellBuffDuration",17,6,0,0],[800+stage,"BuffClassID",16,buff,0,0],[900+stage,"CounterAssult",1,15*stage,381,100],[1000+stage,"StatusEffectID",121,22,0,0],[1100+stage,"OnBuffRemovedEffectSpriteID",21,33,0,0]]:
			_bonus(p,d[0],d[1],d[2],d[3],d[4],d[5])
			if d[0] < 900: p.tables.SpellBonus.append({"ID":d[0],"SpellClassID":spell,"BonusID":d[0],"MinSpellLevel":0})
			else: p.tables.BuffBonus.append({"ID":d[0],"BuffClassID":buff,"BonusID":d[0],"CharacterLevel":0,"CharacterClass":0,"MinSpellLevel":0})
	return p

func _targets(amount: int = 4) -> Array:
	var targets: Array = []
	for id: int in range(1,amount+1): targets.append({"source_id":id,"instance_id":str(id),"equipped":true})
	return targets

func _test_contracts() -> void:
	var p: Dictionary = _fixture()
	var result: Dictionary = Sets.resolve(p,_targets())
	_check(result.records.size() == 3,"three additional stat contracts")
	_check(result.records[0].get("element_resist_all",0) == 10,"all-element channel preserved")
	_check(result.records[1].get("fear_accuracy",0) == 7 and not result.records[1].has("fear_resistance"),"fear accuracy is not resistance")
	_check(Sets.cast_speed(result.records) == 5,"cast percentage divisor")
	_check(result.capabilities == {"invisibility":true,"doppel":true,"camouflage":true},"three independent reveal flags")
	_check(result.drains.size() == 2 and result.invokes.size() == 1 and result.intervals.size() == 4,"special graph outputs")
	_check(result.buffs.size() == 1,"numeric-free marker buff")
	_check(Sets.resolve(p,[{"source_id":1,"instance_id":"a"},{"source_id":1,"instance_id":"b"}]).records.is_empty(),"duplicate item kind cannot satisfy threshold")
	_check(Sets.resolve(p,[{"source_id":1,"instance_id":"a"},{"source_id":2,"instance_id":"a"}]).records.is_empty(),"duplicate physical ID cannot satisfy threshold")
	_check(Sets.resolve(p,[{"source_id":1,"instance_id":"a"},{"source_id":2,"instance_id":"b","equipped":false}]).records.is_empty(),"unequipped kind excluded")
	_check(Sets.resolve(p,_targets(),{"set_threshold_mode":"highest"}).records.is_empty(),"highest threshold mode does not add lower numeric stages")
	var bad: Dictionary = p.duplicate(true)
	bad.erase("_equipment523_set_cache")
	bad.bonuses["11"].type.UnitID = 1
	_check(not Sets.resolve(bad,_targets()).diagnostics.is_empty(),"wrong typed units fail closed")
	bad = p.duplicate(true)
	bad.tables.UniversalGroupSet[0].UnitID = 1
	_check(not Sets.interval_contract(bad,bad.bonuses["201"].raw).ok,"guard attack group unit checked")
	_check(Sets.contract(p,{"BonusID":18}).kind == "description","fixed description never causes duplicate proc")
	var caption_count: int = 0
	for displayed: Dictionary in SetInvoke.equipped(p,_targets()).details[0].effects:
		if displayed.get("description") == "Synthetic source caption": caption_count += 1
	_check(caption_count == 1,"typed source caption reaches the existing set UI detail model once")

func _test_lifecycle() -> void:
	var p: Dictionary = _fixture()
	var runtime = Sets.new()
	var ctx: Dictionary = {"hp":20,"max_hp":100,"alive":true,"zone_allowed":true,"incoming_event":true,"attacker_is_pc":true,"attack_kind":"melee","landed":true}
	runtime.sync(p,_targets(),{},{"hp":20,"max_hp":100,"alive":true,"zone_allowed":true})
	_check(runtime.guard.is_empty(),"low HP sync alone cannot trigger a defensive invoke")
	var miss_context: Dictionary = ctx.duplicate()
	miss_context.landed = false
	var landed_only_pack: Dictionary = _fixture()
	for option: Dictionary in landed_only_pack.tables.InvokeOption:
		if int(option.get("InvokeOptionTypeID",0)) == 2: option.Param4 = false
	var landed_only = Sets.new()
	landed_only.sync(landed_only_pack,_targets(),{},miss_context)
	_check(landed_only.guard.is_empty(),"Param4 false prevents a failed attack from triggering")
	var spell_context: Dictionary = ctx.duplicate()
	spell_context.by_spell = true
	landed_only.sync(p,_targets(),{},spell_context)
	_check(landed_only.guard.is_empty(),"BySpellAttack false preserves normal-attack trigger scope")
	runtime.sync(p,_targets(),{},miss_context)
	_check(runtime.guard.get("hits",0) == 60 and not runtime.incoming("melee",false,true,{},false),"source Param4 permits miss activation without a landed-only charge")
	var created: Array = runtime.drain_visual_events()
	_check(created.size() == 1 and created[0].kind == "guard_created" and int(created[0].spell.ID) == 504,"guard activation forwards exact source spell once")
	runtime.sync(p,_targets(),{},ctx)
	_check(runtime.guard.hits == 60 and runtime.guard.remaining == 6,"highest HP interval stage is sixty hits for six seconds")
	_check(runtime.markers.size() == 1 and runtime.markers["50"].numeric_effects == 0,"zone marker owns zero numeric effects")
	_check(not runtime.incoming("melee") and runtime.guard.hits == 60,"NPC attacks require explicit local PvE policy")
	_check(not runtime.incoming("magic",false,true) and runtime.guard.hits == 60,"magic never consumes physical guard")
	_check(runtime.incoming("ranged",true,true) and runtime.guard.hits == 59,"physical ranged skill consumes one guard hit")
	var saved: Dictionary = runtime.export_state()
	var loaded = Sets.new()
	loaded.import_state(saved)
	loaded.sync(p,_targets(),{},ctx)
	_check(loaded.guard.hits == 59 and loaded.cooldowns["group:200"] == 60,"reconnect preserves remaining hits and reuse clock")
	loaded.advance(6)
	loaded.sync(p,_targets(),{},ctx)
	_check(loaded.guard.is_empty() and loaded.cooldowns["group:200"] == 54,"expiry cannot retrigger during cooldown")
	loaded.sync(p,[],{},ctx)
	_check(loaded.markers.is_empty() and loaded.cooldowns["group:200"] == 54,"unequip removes aura and retains cooldown")
	loaded.sync(p,_targets(),{},ctx)
	_check(loaded.guard.is_empty(),"reequip cannot bypass cooldown")
	loaded.advance(54)
	loaded.sync(p,_targets(),{},ctx)
	_check(loaded.guard.hits == 60,"guard may reactivate after cooldown")
	loaded.on_death()
	_check(loaded.guard.is_empty() and loaded.cooldowns["group:200"] == 60,"death removes guard without resetting reuse clock")
	_check(loaded.markers.has("50"),"source death-immune marker survives death")
	var dead_context: Dictionary = ctx.duplicate()
	dead_context.alive = false
	loaded.sync(p,_targets(),{},dead_context)
	_check(loaded.markers.has("50"),"dead sync preserves an already active death-immune marker")
	var unactivated = Sets.new()
	unactivated.sync(p,_targets(),{},dead_context)
	_check(unactivated.markers.is_empty(),"death immunity does not fabricate a new aura on a corpse")
	var removed: Array = loaded.drain_visual_events()
	_check(not removed.is_empty() and removed[-1].field == "OnBuffRemovedEffectSpriteID" and int(removed[-1].spell.OnBuffRemovedEffectSpriteID) == 33 and not removed[-1].spell.has("EffectSpriteActionNo"),"removal forwards source SpriteID without inventing an action")
	runtime.sync(p,_targets(),{},{"hp":21,"max_hp":100,"zone_allowed":false})
	_check(runtime.markers.is_empty(),"zone exit clears shell aura")
	var tampered: Dictionary = saved.duplicate(true)
	tampered.guard.hits = 9999
	tampered.guard.remaining = 9999
	tampered.guard.attack_types = [3]
	loaded.import_state(tampered)
	loaded.sync(p,_targets(),{},ctx)
	_check(loaded.guard.hits == 60 and loaded.guard.remaining == 6 and not loaded.incoming("magic"),"saved values clamped and attack selectors rebuilt from source")
	tampered.source_sha256 = "wrong"
	loaded.import_state(tampered)
	loaded.sync(p,_targets(),{},{"hp":50,"max_hp":100})
	_check(loaded.guard.is_empty(),"source mismatch cannot retain saved effect")
	var other = Sets.new()
	other.sync(p,_targets(),{"set_interval_cast_delay_divisor":2000},ctx)
	_check(other.cooldowns["group:200"] == 30,"CastDelay conversion is explicit configurable policy")
	_check(Sets.validate_state(saved).is_empty(),"saved state has a valid precise shape")
	_check(Sets.validate_state(JSON.parse_string(JSON.stringify(saved))).is_empty(),"JSON numeric roundtrip preserves guard IDs and hits")
	_check(Sets.new().export_state().is_empty() and Sets.validate_state({}).is_empty(),"no-pack initial save has an empty valid state")
	var unknown: Dictionary = saved.duplicate(true)
	unknown.source_sha256 = "unknown-future-source"
	_check(not Sets.validate_state(unknown).is_empty(),"unknown source requires save protection")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.cooldowns["group:200"] = "60"
	_check(not Sets.validate_state(invalid).is_empty(),"string cooldown cannot coerce into numeric state")
	invalid = saved.duplicate(true)
	invalid.guard.hits = true
	_check(not Sets.validate_state(invalid).is_empty(),"boolean cannot become guard hit count")
	for bad_key: String in ["group:0200","group:+200","group: 200","group:200 "]:
		invalid = saved.duplicate(true)
		invalid.cooldowns = {bad_key:60}
		_check(not Sets.validate_state(invalid).is_empty(),"noncanonical cooldown group key is rejected")
	other.clear()
	runtime.clear()
	loaded.clear()

func _test_hits() -> void:
	var p: Dictionary = _fixture()
	var runtime = Sets.new()
	var host = Host.new()
	var victim = Victim.new()
	root.add_child(host)
	root.add_child(victim)
	host.rng.seed = 523
	var policy: Dictionary = {"set_drain_hp_per_point":1,"set_drain_mp_per_point":1}
	var result: Array = runtime.on_hit(host,p,_targets(),policy,victim,"melee")
	_check(victim.hp == 29 and victim.mp == 9 and host.hp == 41 and host.mp == 21,"drain subtracts exact resources before capped recovery")
	_check(result.size() == 2 and runtime.locked_target() == null,"strict PCButMe selector does not affect NPC")
	policy.set_pvp_targets_as_pve = true
	victim.set_meta("source_invisible",true)
	result = runtime.on_hit(host,p,_targets(),policy,victim,"melee")
	_check(runtime.locked_target() == null and result.size() == 2,"source invisible cast restriction is independent of detection")
	victim.remove_meta("source_invisible")
	result = runtime.on_hit(host,p,_targets(),policy,victim,"melee")
	_check(runtime.locked_target() == victim and result.size() == 3,"explicit local PvE policy enables target lock")
	_check(host.original_skills.status.effects.values()[0]["values"]["reduction"] == -10,"source negative PvP reduction reaches existing status consumer")
	var other = Victim.new()
	root.add_child(other)
	runtime.on_hit(host,p,_targets(),policy,other,"melee")
	_check(runtime.locked_target() == victim,"active fixed target cannot silently switch")
	var threshold_pack: Dictionary = p.duplicate(true)
	threshold_pack.erase("_equipment523_set_cache")
	for row: Dictionary in threshold_pack.tables.ItemSetBonus:
		if int(row.get("BonusID",0)) == 20: row.CompletionDegree = 4
	runtime.sync(threshold_pack,_targets(3),policy,{"alive":true})
	_check(runtime.current.set_ids.has(1) and runtime.locked_target() == null,"losing only the invoke threshold releases its owned lock under explicit detach policy")
	runtime.on_hit(host,p,_targets(),policy,victim,"melee")
	var duration_policy: Dictionary = policy.duplicate()
	duration_policy.set_yahi_detach_mode = "duration"
	runtime.sync(threshold_pack,_targets(3),duration_policy,{"alive":true})
	_check(runtime.locked_target() == victim,"source-undefined detach lifetime has an explicit duration-only alternative")
	runtime.sync(p,[],{},{} )
	_check(runtime.locked_target() == null and host.original_skills.status.effects.is_empty(),"unequip cleans only owned target debuff")
	runtime.on_hit(host,p,_targets(),policy,victim,"melee")
	victim.life_id += 1
	runtime.advance(0)
	_check(runtime.locked_target() == null,"respawn cannot inherit previous life lock")
	runtime.on_hit(host,p,_targets(),policy,victim,"melee")
	runtime.advance(8)
	_check(runtime.locked_target() == null and host.original_skills.status.effects.is_empty(),"eight-second lock expiry cleans status source")
	var before: int = victim.hp
	runtime.on_hit(host,p,_targets(),{},victim,"melee")
	_check(victim.hp == before,"unknown drain formula is disabled without explicit coefficient")
	for invalid_coefficient: Variant in ["1",true,NAN,INF,-1.0]:
		var rejected: Array = runtime.on_hit(host,p,_targets(),{"set_drain_hp_per_point":invalid_coefficient,"set_drain_mp_per_point":1},victim,"melee")
		_check(rejected.is_empty() and victim.hp == before,"invalid drain policy cannot coerce or partially mutate")
	runtime.clear()
	other.free()
	victim.free()
	host.free()


func _test_cancel() -> void:
	var p: Dictionary = _fixture()
	var runtime = Sets.new()
	var context: Dictionary = {"hp":20,"max_hp":100,"alive":true,"zone_allowed":true,"incoming_event":true,"attacker_is_pc":true,"attack_kind":"melee","landed":true}
	runtime.sync(p,_targets(),{},context)
	var before: Dictionary = runtime.cooldowns.duplicate(true)
	_check(runtime.cancel(p,[999]) == 0 and not runtime.guard.is_empty(),"unmatched cancel group preserves guard")
	_check(runtime.cancel(p,["200",true,200.5]) == 0 and not runtime.guard.is_empty(),"untyped cancel groups cannot coerce into a source match")
	_check(runtime.cancel(p,[200]) == 1 and runtime.guard.is_empty(),"matching source group cancels one guard")
	_check(runtime.cooldowns == before and runtime.markers.size() == 1,"targeted cancel preserves reuse clock and immune aura marker")
	runtime.sync(p,_targets(),{},context)
	_check(runtime.guard.is_empty(),"cancel does not allow immediate guard recast")
	runtime.advance(60)
	runtime.sync(p,_targets(),{},context)
	_check(not runtime.guard.is_empty() and runtime.cancel(p,[]) == 1,"full cancel removes a source good guard after normal recast")
	_check(runtime.cooldowns["group:200"] == 60,"full cancel also retains the new reuse clock")
	var immune_pack: Dictionary = _fixture()
	for buff: Dictionary in immune_pack.tables.BuffClass:
		if int(buff.ID) == 604: buff.IsImmuneToCancellation = true
	var immune = Sets.new()
	immune.sync(immune_pack,_targets(),{},context)
	_check(immune.cancel(immune_pack,[]) == 0 and immune.cancel(immune_pack,[200]) == 0 and not immune.guard.is_empty(),"source cancellation immunity applies to full and targeted cancel")
	var bad_buff_pack: Dictionary = _fixture()
	for buff: Dictionary in bad_buff_pack.tables.BuffClass:
		if int(buff.ID) == 604: buff.IsGood = false
	var bad_buff_runtime = Sets.new()
	bad_buff_runtime.sync(bad_buff_pack,_targets(),{},context)
	_check(bad_buff_runtime.cancel(bad_buff_pack,[]) == 0 and not bad_buff_runtime.guard.is_empty(),"full cancel only removes source good buffs")
	_check(bad_buff_runtime.cancel(bad_buff_pack,[200]) == 1,"targeted cancel uses exact source group independently of good flag")
	var unmapped: Dictionary = runtime.export_state()
	unmapped.guard = {"bonus_id":204,"set_id":1,"buff_id":99999,"hits":60,"remaining":6}
	runtime.import_state(unmapped)
	_check(runtime.cancel(p,[]) == 0 and not runtime.guard.is_empty(),"unmapped source buff is preserved for authority review")
	var invalid_runtime = Sets.new()
	for invalid_divisor: Variant in ["1000",true,NAN,INF,0,-1]:
		invalid_runtime.clear()
		invalid_runtime.sync(p,_targets(),{"set_interval_cast_delay_divisor":invalid_divisor},context)
		_check(invalid_runtime.guard.is_empty() and invalid_runtime.cooldowns.is_empty(),"invalid CastDelay policy rejects guard activation")
	var missing_pack: Dictionary = _fixture()
	for buff: Dictionary in missing_pack.tables.BuffClass:
		if int(buff.ID) == 604: buff.erase("IsImmuneToCancellation")
	var missing = Sets.new()
	missing.sync(missing_pack,_targets(),{},context)
	_check(missing.cancel(missing_pack,[]) == 0 and not missing.guard.is_empty(),"missing source cancellation policy fails closed")
	var host = Host.new()
	var target = Victim.new()
	root.add_child(host)
	root.add_child(target)
	var yahi = Sets.new()
	yahi.sync(p,_targets(),{},context)
	yahi.on_hit(host,p,_targets(),{"set_pvp_targets_as_pve":true},target,"melee")
	_check(yahi.locked_target() == target,"cancel fixture has an owned Yahi target and self buff")
	_check(yahi.cancel(p,[]) == 1 and yahi.locked_target() == target and yahi.markers.size() == 1 and not host.original_skills.status.effects.is_empty(),"full cancel keeps cancellation-immune Yahi buffs and aura")
	_check(yahi.cancel(p,[5]) == 0 and yahi.locked_target() == target,"targeted group cancel also keeps immune Yahi buffs")
	yahi.clear()
	runtime.clear()
	immune.clear()
	missing.clear()
	invalid_runtime.clear()
	bad_buff_runtime.clear()
	target.free()
	host.free()

func _test_source_graph() -> void:
	var path: String = OS.get_environment("EQUIPMENT523_RULES_FILE")
	var extension: String = OS.get_environment("EQUIPMENT523_EFFECT_EXTENSION")
	if path.is_empty() or extension.is_empty(): return
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(extension))
	if not p is Dictionary or not extra is Dictionary:
		_check(false,"private source contracts readable")
		return
	for name: String in extra.get("tables",{}):
		var index: Dictionary = {}
		for row: Dictionary in p.tables.get(name,[]): index[int(row.ID)] = row
		for row: Dictionary in extra.tables[name]: index[int(row.ID)] = row
		p.tables[name] = index.values()
	p.bonuses.merge(extra.get("bonuses",{}),true)
	var contracts: Array = Sets.contracts(p)
	private_source_contracts_checked = contracts.size()
	_check(contracts.size() == 22,"all twenty-two original special set links have contracts")
	var set_ids: Dictionary = {}
	for value: Dictionary in contracts:
		_check(bool(value.get("ok",false)),"original typed special contract " + str(value.get("bonus_id",value.get("error","unknown"))))
		set_ids[int(value.get("set_id",0))] = true
	_check(set_ids.size() == 12,"all twelve original special set definitions accounted for")
