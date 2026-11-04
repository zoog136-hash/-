extends SceneTree

const Smith = preload("res://scripts/equipment523/smith_smelt.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var pack: Dictionary = _pack()
	var ctx: Dictionary = _context()
	var rng := RandomNumberGenerator.new()
	rng.seed = 523
	var q: Dictionary = Smith.quote(pack, {"kind":"smelt"}, ctx)
	_check(q.get("ok", false), "general smelt accepted")
	var result: Dictionary = Smith.roll(pack, q, rng)
	_check(result.get("ok", false) and result.state.smelt.slots.size() == 2, "every general slot rolled")
	_check(result.state.smelt.bonus_ids == [1, 2], "bonus identities preserved")
	ctx.materials[0].source_id = 287532
	_check(not Smith.quote(pack, {"kind":"smelt"}, ctx).ok, "event buff stone rejected")
	ctx.materials[0].source_id = 400
	ctx.target.source_id = 200
	ctx.target.bless_code = 1
	_check(not Smith.quote(pack, {"kind":"spirit_smelt"}, ctx).ok, "BlessCode zero is exact by default")
	ctx.policy.spirit_bless_zero = "wildcard"
	for level in [0, 4, 5, 6, 7, 8]:
		ctx.target.level = level
		q = Smith.quote(pack, {"kind":"spirit_smelt"}, ctx)
		_check(q.ok and q.slots.size() == (1 if level < 5 else (2 if level < 7 else 3)), "spirit activation +%d" % level)
	ctx.target.level = 7
	q = Smith.quote(pack, {"kind":"spirit_smelt"}, ctx)
	result = Smith.roll(pack, q, rng)
	_check(result.state.spirit_smelt.slots[2].empty, "None retained as an empty slot")
	_check(result.effects.size() == 2, "None does not produce a stat record")
	pack.bonuses["1"].supported = false
	_check(not Smith.quote(pack, {"kind":"spirit_smelt"}, ctx).ok, "unsupported pool rejected before consumption")
	pack.bonuses["1"].supported = true
	pack.tables.ItemBonus.append({"ItemClassID":400,"BonusID":12})
	_check(not Smith.quote(pack, {"kind":"spirit_smelt"}, ctx).ok, "unresolved installed expiry rejected")
	ctx.policy.smelt_expiry_unix = {"900":2000}
	q = Smith.quote(pack, {"kind":"spirit_smelt"}, ctx)
	_check(q.ok and q.expires_unix == 2000, "installation schedule uses explicit resolved timestamp")
	ctx.now_unix = 2001
	_check(not Smith.quote(pack, {"kind":"spirit_smelt"}, ctx).ok, "expired installation rejected")
	ctx = _context()
	ctx.target.source_id = 300
	ctx.materials[0].source_id = 500
	ctx.target.element_type = 1
	ctx.target.element_level = 2
	_check(not Smith.quote(pack, {"kind":"elemental_smith"}, ctx).ok, "element +2 rejected")
	ctx.target.element_level = 3
	q = Smith.quote(pack, {"kind":"elemental_smith"}, ctx)
	_check(q.ok and q.slots.size() == 2, "element +3 accepted with matching scroll")
	ctx.target.element_type = 2
	_check(not Smith.quote(pack, {"kind":"elemental_smith"}, ctx).ok, "wrong element scroll rejected")
	ctx.target.source_id = 301
	ctx.target.bless_code = 2
	ctx.materials[0].source_id = 501
	_check(not Smith.quote(pack, {"kind":"bless_reinforcement"}, ctx).ok, "bless probability interpretation requires policy")
	ctx.policy.bless_probability_column = "Prob1"
	q = Smith.quote(pack, {"kind":"bless_reinforcement"}, ctx)
	_check(q.ok and q.slots.size() == 1, "bless accepted with explicit Prob1 policy")
	pack.tables.ItemBlessReinforcementGrade[0].WeaponTypeID = 2
	q = Smith.quote(pack, {"kind":"bless_reinforcement"}, ctx)
	_check(not q.ok and str(q.get("error", "")).contains("등급 설정"), "grade gate joins weapon type exactly")
	pack.tables.ItemBlessReinforcementGrade[0].WeaponTypeID = 1
	pack.tables.ItemBlessReinforcementSlotAmount[0].GradeID = 5
	_check(not Smith.quote(pack, {"kind":"bless_reinforcement"}, ctx).ok, "slot amount joins raw equipment grade exactly")
	pack.tables.ItemBlessReinforcementSlotAmount[0].GradeID = 4
	pack.items["301"].raw.GradeID = 52
	pack.tables.ItemBlessReinforcement[0].GradeID = 52
	pack.tables.ItemBlessReinforcementBonus[0].Prob1 = 10050000
	q = Smith.quote(pack, {"kind":"bless_reinforcement"}, ctx)
	_check(not q.ok and str(q.get("error", "")).contains("등급 설정"), "unconfigured grade is gated before its unreachable probability anomaly")
	pack.items["301"].raw.GradeID = 4
	pack.tables.ItemBlessReinforcement[0].GradeID = 4
	_check(not Smith.quote(pack, {"kind":"bless_reinforcement"}, ctx).ok, "probability overflow never normalized")
	pack.tables.ItemBlessReinforcementBonus[0].Prob1 = 10000000
	pack.tables.ItemBonus.append({"ItemClassID":501,"BonusID":13})
	_check(not Smith.quote(pack, {"kind":"bless_reinforcement"}, ctx).ok, "artisan guarantee scroll forbidden")
	ctx = _context()
	ctx.policy.costs.clear()
	_check(not Smith.quote(pack, {"kind":"smelt"}, ctx).ok, "missing cost policy rejected")
	_test_saved_effects()
	print("equipment523 smith/smelt: %d checks, %d failures" % [checks, failures])
	print("EQUIPMENT523_SMITH_SMELT_RESULT ",JSON.stringify({"checks":checks,"failures":[] if failures == 0 else ["failed"]}))
	quit(1 if failures else 0)

func _test_saved_effects() -> void:
	# Production rules are JSON-loaded; preserve their numeric representation.
	var pack: Dictionary = JSON.parse_string(JSON.stringify(_pack()))
	var ctx: Dictionary = _context()
	var rng := RandomNumberGenerator.new()
	rng.seed = 523
	var q: Dictionary = Smith.quote(pack, {"kind":"smelt"}, ctx)
	var saved: Dictionary = Smith.roll(pack, q, rng).state
	_check(Smith.active_effects(pack, ctx.target, "smelt", saved, 1000).size() == 2, "authoritative saved smelt effects apply")
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(saved))
	_check(Smith.active_effects(pack, ctx.target, "smelt", reloaded, 1000).size() == 2, "JSON integral floats retain authoritative saved effects")
	for invalid: Variant in ["1", true, 1.5, 999, null]:
		var bad_ids: Dictionary = reloaded.duplicate(true)
		bad_ids.smelt.bonus_ids[0] = invalid
		_check(Smith.active_effects(pack, ctx.target, "smelt", bad_ids, 1000).is_empty(), "JSON malformed bonus identity cannot coerce into an effect")
	var altered: Dictionary = saved.duplicate(true)
	altered.smelt.slots[0].raw = pack.tables.ItemSmeltBonus[2].duplicate(true)
	_check(Smith.active_effects(pack, ctx.target, "smelt", altered, 1000).is_empty(), "different source pool cannot inject an otherwise valid bonus row")
	altered = saved.duplicate(true)
	altered.smelt.slots[0].raw.Prob = 1
	_check(Smith.active_effects(pack, ctx.target, "smelt", altered, 1000).is_empty(), "modified provenance row rejected")
	altered = saved.duplicate(true)
	altered.smelt.slots[1] = altered.smelt.slots[0].duplicate(true)
	altered.smelt.bonus_ids = [1,1]
	_check(Smith.active_effects(pack, ctx.target, "smelt", altered, 1000).is_empty(), "duplicate saved slot cannot double apply")
	altered = saved.duplicate(true)
	altered.smelt.erase("material_source_id")
	_check(Smith.active_effects(pack, ctx.target, "smelt", altered, 1000).is_empty() and altered.has("smelt"), "legacy evidence stays saved but inactive")
	ctx.target.instance_id = "other-physical"
	_check(Smith.active_effects(pack, ctx.target, "smelt", saved, 1000).is_empty(), "physical identity is bound")
	ctx = _context()
	ctx.target.source_id = 200
	ctx.target.level = 7
	ctx.materials[0].source_id = 400
	ctx.policy.spirit_bless_zero = "wildcard"
	q = Smith.quote(pack, {"kind":"spirit_smelt"}, ctx)
	saved = Smith.roll(pack, q, rng).state
	_check(Smith.active_effects(pack, ctx.target, "spirit_smelt", saved, 1000, ctx.policy).size() == 2, "spirit saved source pool and None slot verified")
	ctx.target.level = 0
	_check(Smith.active_effects(pack, ctx.target, "spirit_smelt", saved, 1000, ctx.policy).size() == 1, "downgrade closes saved higher slots without deletion")
	ctx.policy.spirit_bless_zero = "exact"
	_check(Smith.active_effects(pack, ctx.target, "spirit_smelt", saved, 1000, ctx.policy).is_empty(), "current BlessCode policy gates saved effects")
	ctx.policy.spirit_bless_zero = "wildcard"
	pack.tables.ItemBonus.append({"ItemClassID":400,"BonusID":12})
	ctx.policy.smelt_expiry_unix = {"900":2000}
	q = Smith.quote(pack, {"kind":"spirit_smelt"}, ctx)
	saved = Smith.roll(pack, q, rng).state
	_check(Smith.active_effects(pack, ctx.target, "spirit_smelt", saved, 1000, ctx.policy).size() == 1, "current schedule resolution permits temporal effects")
	_check(Smith.active_effects(pack, ctx.target, "spirit_smelt", saved, 2000, ctx.policy).is_empty(), "temporal saved effect expires at boundary")
	altered = saved.duplicate(true)
	altered.spirit_smelt.expires_unix = 9999
	_check(Smith.active_effects(pack, ctx.target, "spirit_smelt", altered, 1000, ctx.policy).is_empty(), "saved expiry cannot override current policy")
	pack.bonuses["12"].raw = {"Value":2030010105,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0}
	_check(not Smith.quote(pack, {"kind":"spirit_smelt"}, ctx).ok, "date-shaped expiry does not share target-zero key")
	ctx.policy.smelt_expiry_unix = {"2030010105":3000}
	q = Smith.quote(pack, {"kind":"spirit_smelt"}, ctx)
	_check(q.ok and q.expires_unix == 3000, "date-shaped expiry uses exact source Value key")
	ctx = _context()
	ctx.target.source_id = 300
	ctx.target.element_type = 1
	ctx.target.element_level = 3
	ctx.materials[0].source_id = 500
	q = Smith.quote(pack, {"kind":"elemental_smith"}, ctx)
	saved = Smith.roll(pack, q, rng).state
	_check(Smith.active_effects(pack, ctx.target, "elemental_smith", saved, 1000).size() == 2, "elemental saved rows match slot probability graph")
	ctx.target.element_type = 2
	_check(Smith.active_effects(pack, ctx.target, "elemental_smith", saved, 1000).is_empty(), "changing current element suspends old elemental smith effects")
	ctx.target.source_id = 301
	ctx.target.bless_code = 2
	ctx.materials[0].source_id = 501
	ctx.policy.bless_probability_column = "Prob1"
	q = Smith.quote(pack, {"kind":"bless_reinforcement"}, ctx)
	saved = Smith.roll(pack, q, rng).state
	_check(Smith.active_effects(pack, ctx.target, "bless_reinforcement", saved, 1000, ctx.policy).size() == 1, "bless saved row passes grade and slot configuration gates")
	ctx.target.bless_code = 1
	_check(Smith.active_effects(pack, ctx.target, "bless_reinforcement", saved, 1000, ctx.policy).is_empty(), "removing blessing suspends saved blessing effects")

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _context() -> Dictionary:
	var costs: Dictionary = {}
	for kind in ["smelt","spirit_smelt","elemental_smith","bless_reinforcement"]:
		costs[kind] = {"gold_cost":0,"material_amount":1}
	return {"target":{"source_id":100,"instance_id":"physical-a","level":0,"bless_code":1},"materials":[{"source_id":289162,"bless_code":1}],"policy":{"costs":costs},"now_unix":1000}

func _pack() -> Dictionary:
	var pack: Dictionary = {"source_sha256":"synthetic-test", "tables":{}, "items":{}, "bonuses":{}}
	for id in [100,200,289162,287532,300,301,400,500,501]:
		pack.items[str(id)] = {"raw":{"ID":id,"GradeID":4,"CategoryID":151 if id == 501 else 1}}
	for id in [1,2,3,10,11,12,13,14]:
		pack.bonuses[str(id)] = {"name":"Strength","supported":true,"raw":{"Value":1},"record":{"STR":1}}
	pack.bonuses["3"] = {"name":"None","supported":false,"raw":{"Value":0},"record":{}}
	pack.bonuses["10"] = {"name":"SpiritSmelt","raw":{"Value":62}}
	pack.bonuses["11"] = {"name":"DeleteTime","raw":{"Value":1999010100}}
	pack.bonuses["12"] = {"name":"SmeltExpireDate","raw":{"Value":0,"BonusApplicationTypeID":298,"BonusApplicationTargetID":900}}
	pack.bonuses["13"] = {"name":"GuaranteeBlessProb","raw":{"Value":1}}
	pack.bonuses["14"] = {"name":"ScrollElementalSmith","raw":{"Value":1}}
	pack.bonuses["15"] = {"name":"ScrollElementalType","raw":{"Value":1}}
	pack.bonuses["16"] = {"name":"WeaponType","raw":{"Value":1}}
	pack.tables.ItemBonus = [{"ItemClassID":400,"BonusID":10},{"ItemClassID":400,"BonusID":11},{"ItemClassID":500,"BonusID":14},{"ItemClassID":500,"BonusID":15},{"ItemClassID":300,"BonusID":16},{"ItemClassID":301,"BonusID":16}]
	pack.tables.ItemSmelt = [{"ID":2,"SlotAmount":2},{"ID":62,"SlotAmount":3}]
	pack.tables.ItemSmeltEntity = [{"ID":1,"ItemClassID":100,"ItemSmeltID":2}]
	pack.tables.ItemSpiritSmeltEntity = [{"ID":2,"ItemClassID":200,"ItemSmeltID":62,"BlessCode":0}]
	pack.tables.ItemSmeltSlotActive = []
	pack.tables.ItemSmeltBonus = []
	for slot in [1,2]:
		pack.tables.ItemSmeltBonus.append({"ID":slot,"ItemSmeltID":2,"SlotNumber":slot,"BonusID":slot,"Prob":10000000})
	for slot in [1,2,3]:
		pack.tables.ItemSmeltSlotActive.append({"ItemSmeltID":62,"SlotNumber":slot,"MinEnchant":[0,5,7][slot-1],"MaxEnchant":8})
		pack.tables.ItemSmeltBonus.append({"ID":slot+2,"ItemSmeltID":62,"SlotNumber":slot,"BonusID":slot,"Prob":10000000})
	pack.tables.ElementalSmith = [{"ID":1,"WeaponTypeID":1,"GradeID":4}]
	pack.tables.ElementalSmithProbability = []
	pack.tables.ElementalSmithBonus = []
	for slot in [1,2]:
		pack.tables.ElementalSmithProbability.append({"ElementalSmithID":1,"ItemBlessCodeID":1,"SlotNumber":slot,"ElementalSmithProbGroupID":slot})
		pack.tables.ElementalSmithBonus.append({"ID":slot,"ElementalSmithProbGroupID":slot,"ElementalTypeID":1 if slot == 1 else 0,"BonusID":slot,"Probability":10000000})
	pack.tables.ItemEquipSlot = [{"ItemClassID":301,"EquipSlotID":8}]
	pack.tables.ItemBlessReinforcement = [{"ID":1,"EquipSlotID":8,"WeaponTypeID":1,"GradeID":4,"IsTest":false}]
	pack.tables.ItemBlessReinforcementGrade = [{"EquipSlotID":8,"WeaponTypeID":1,"GradeID":4}]
	pack.tables.ItemBlessReinforcementSlotAmount = [{"EquipSlotID":8,"GradeID":4,"SlotAmount":1}]
	pack.tables.ItemBlessReinforcementBonus = [{"ID":1,"ItemBlessReinforcementID":1,"SlotNumber":1,"BonusID":1,"Prob1":10000000,"Prob2":0}]
	return pack
