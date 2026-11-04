extends SceneTree

const Domain = preload("res://scripts/unconfirmed523/jade_grail_domain.gd")
const DURATIONS: Dictionary = {123412: 600, 130541: 2592000, 139101: 2592000, 139931: 2592000, 169373: 864000, 174863: 864000, 181194: 864000, 188674: 2592000, 195112: 2592000, 195254: 1209600, 197781: 2592000, 255643: 2592000}
var checked: int = 0
var failures: Array[String] = []

class Fixture extends RefCounted:
	var data: Dictionary = {}
	var root_path: String = ""
	func rows(table: String) -> Array:
		if not root_path.is_empty() and not data.has(table):
			var path: String = root_path.path_join(table + ".json")
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix(String.chr(0xfeff))) if FileAccess.file_exists(path) else {}
			data[table] = parsed.get("rows", []) if parsed is Dictionary else []
		return data.get(table, [])
	func row(table: String, id: int) -> Dictionary:
		for value: Dictionary in rows(table):
			if int(value.get("ID", 0)) == id:
				return value
		return {}

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checked += 1
	if not value:
		failures.append(label)
		printerr("JADE_GRAIL_FAIL: " + label)

func _context() -> Dictionary:
	return {"nowUnix": 1546300800, "allow_test_items": true, "level": 70, "class_id": 1, "region": "KR", "world_no": 1,
		"owned": {"338438": 4, "338448": 1, "338458": 1, "355334": 1000}, "currencies": {"1": 1000000},
		"instances": {"a": {"sourceID": 338438, "instance_id": "a"}, "b": {"sourceID": 338438, "instance_id": "b"}, "c": {"sourceID": 338438, "instance_id": "c"}, "d": {"sourceID": 338438, "instance_id": "d"}, "hero": {"sourceID": 338448, "instance_id": "hero"}, "legend": {"sourceID": 338458, "instance_id": "legend"}},
		"ain": {"blessing": 0, "dragon_orb_expires_at": 0, "last_orb_purchase_month": "2019-01", "auto_recharge": true, "spend_remainder": 0.5}}

func _run() -> void:
	var source: Fixture = _fixture()
	var fixture_domain = Domain.new()
	fixture_domain.setup(source)
	_exercise(fixture_domain, "fixture")
	var source_path: String = OS.get_environment("TWILIGHT_SOURCE523_DIR")
	if not source_path.is_empty():
		var actual: Fixture = Fixture.new()
		actual.root_path = source_path
		var actual_domain = Domain.new()
		actual_domain.setup(actual)
		_exercise(actual_domain, "source523")
		_check(actual.rows("ItemGraceBonus").size() == 27, "source523 canonical 27 grace pool rows")
		_check(actual.rows("ItemGraceSetBonus").size() == 112, "source523 all112 set effect rows")
		_check(actual.rows("ItemGracePrefixForSet").size() == 84, "source523 all84 prefix requirements")
		_check(actual_domain._jade.size() == 12, "source523 exactly12 rechargeable items")
		_audit_source_effects(actual_domain)
		if OS.get_environment("TWILIGHT_523_ALLOW_TEST_SOURCE") == "1" and ResourceLoader.exists("res://scripts/unconfirmed523/source523.gd"):
			var facade_script: GDScript = load("res://scripts/unconfirmed523/source523.gd")
			var facade = facade_script.new()
			var configured: Dictionary = facade.configure_directory(source_path)
			_check(configured.get("ok", false), "source facade test-only directory configured")
			if configured.get("ok", false):
				var facade_domain = Domain.new()
				facade_domain.setup(facade)
				_exercise(facade_domain, "source523_facade")
	else:
		print("JADE_GRAIL_SOURCE523_NOT_RUN: set TWILIGHT_SOURCE523_DIR to the verified Content directory")
	if failures.is_empty():
		print("UNCONFIRMED523_JADE_GRAIL_OK: %d assertions" % checked)
		quit(0)
	else:
		printerr("UNCONFIRMED523_JADE_GRAIL_FAILED: " + ", ".join(failures))
		quit(1)

func _audit_source_effects(domain) -> void:
	var all_links: Array = domain._rows("ItemGraceBonus").duplicate(true)
	all_links.append_array(domain._rows("ItemGraceSetBonus"))
	for link: Dictionary in domain._rows("ItemBonus"):
		if int(link.get("ItemClassID",0)) in [338438,338448,338458] and bool(link.get("IsPossession",false)): all_links.append(link)
	var ids: Dictionary = {}
	var families: Dictionary = {}
	var zero_count: int = 0
	for link: Dictionary in all_links:
		var id: int = int(link.get("BonusID",0))
		if id == 0: zero_count += 1; continue
		ids[id] = true
		var raw: Dictionary = domain._row("Bonus",id)
		var type_id: int = int(raw.get("BonusTypeID",0))
		var unit: int = int(domain._row("BonusType",type_id).get("UnitID",0))
		var output: Dictionary = {"stats":{},"conditional_stats":{"undead":{},"pvp":{}},"effects":[],"unsupported":[]}
		domain._add_effect(output,id,{}, {"origin":"raw_audit"})
		_check(output.effects.size() == 1 and int(output.effects[0].raw_value) == int(raw.get("Value",0)) and int(output.effects[0].unit_id) == unit,"source effect preserves raw value and unit " + str(id))
		_check(int(raw.get("BonusApplicationTypeID",0)) == 0 and int(raw.get("BonusApplicationTargetID",0)) == 0 and domain.STAT_KEYS.has(type_id) or type_id == 12338,"source full grail application and type audit " + str(id))
		if type_id in [5681,5691,5701,7304,7818,11134]:
			if not families.has(type_id): families[type_id] = []
			families[type_id].append(id)
			var effect: Dictionary = output.effects[0]
			if type_id in [7304,7818,11134]:
				_check(output.stats.is_empty() and not effect.applied and str(effect.reason).ends_with("_context_required") and not output.conditional_stats[effect.condition].is_empty(),"source target-scoped effect never leaks to ordinary stats " + str(id))
			else:
				_check(unit == 3 and int(raw.Value) == 10000 and is_equal_approx(float(effect.value),1.0),"source channel percentage raw10000 is one percentage point " + str(id))
	_check(all_links.size() == 152 and zero_count == 6 and ids.size() == 146,"source all152grail links and146nonzero IDs covered including sixempty absolute qualifications")
	var expected: Dictionary = {5681:[2251904],5691:[2251934],5701:[2251964],7304:[2252034,2252044,2252054],7818:[],11134:[]}
	for id: int in range(2250064,2250204,10): expected[7818].append(id)
	for id: int in range(2250204,2250334,10): expected[11134].append(id)
	expected[11134].append(2250374)
	for type_id: int in expected:
		families[type_id].sort(); expected[type_id].sort()
		_check(families[type_id] == expected[type_id],"source complete conditional family exact IDs " + str(type_id))
	var reachable: Dictionary = {}
	var passes: Dictionary = {}
	for tier: Dictionary in domain._rows("PassSystemLevel"):
		for field: String in ["RewardID","PremiumRewardID"]:
			var reward: Dictionary = domain._row("Reward",int(tier.get(field,0)))
			if int(reward.get("RewardTypeID",0)) != 184: continue
			reachable[int(reward.ID)] = int(reward.RewardClassID)
			passes[int(tier.PassSystemID)] = true
	var hp_ids: Array = []; var exp_count: int = 0; var unique_bonus: Dictionary = {}
	for id: int in reachable:
		var bonus: Dictionary = domain._row("Bonus",int(reachable[id]))
		unique_bonus[int(reachable[id])] = true
		var type_id: int = int(bonus.get("BonusTypeID",0))
		_check(int(bonus.get("BonusApplicationTypeID",0)) == 0 and int(bonus.get("BonusApplicationTargetID",0)) == 0 and type_id in [17,133],"source reachable pass184 has no unresolved condition " + str(id))
		if type_id == 17:
			hp_ids.append(int(bonus.ID))
			_check(int(bonus.Value) == 30000 and int(domain._row("BonusType",type_id).UnitID) == 1,"source pass HP bonus is literal30000HP " + str(id))
		else:
			exp_count += 1
			_check(int(bonus.Value) in [20000,30000,50000,100000] and int(domain._row("BonusType",type_id).UnitID) == 3,"source pass XP bonus uses exact percentage units " + str(id))
	hp_ids.sort()
	_check(reachable.size() == 59 and passes.size() == 29 and unique_bonus.size() == 59 and exp_count == 55 and hp_ids == [2133354,2133364,2133834,2133844],"source complete59reachablepass184audit55EXPand4HP across29passes")
	_check(not reachable.has(381814) and not reachable.has(381824) and not reachable.has(408318),"source orphaned Reward184 rows are not claimed reachable")
	for id: int in passes:
		_check(int(domain._row("PassSystem",id).get("PassSystemTypeID",0)) == 12,"source reachable bonus belongs to season pass " + str(id))
	var direct_xp: Dictionary = {}
	for link: Dictionary in domain._rows("QuestReward"):
		var reward: Dictionary = domain._row("Reward",int(link.get("RewardID",0)))
		if int(reward.get("RewardTypeID",0)) != 172: continue
		direct_xp[int(reward.ID)] = true
		_check(int(domain._row("PassSystem",int(reward.get("RewardClassID",0))).get("PassSystemTypeID",0)) == 12 and int(reward.get("Amount",0)) > 0,"source exact direct pass XP target and amount " + str(reward.ID))
	var all_xp: Dictionary = {}
	for reward: Dictionary in domain._rows("Reward"):
		if int(reward.get("RewardTypeID",0)) == 172: all_xp[int(reward.ID)] = true
	_check(all_xp.size() == 894 and direct_xp.size() == 894 and all_xp == direct_xp,"all894rawReward172 leaves have directQuestRewardedges for future caller port")

func _exercise(domain, scope: String) -> void:
	var state: Dictionary = domain.initial_state()
	var context: Dictionary = _context()
	_check(domain.validate_state(state).is_empty(), scope + " initial state valid")
	var before: Dictionary = state.duplicate(true)
	domain.view(context, state)
	domain.view(context, state)
	_check(state == before, scope + " views do not roll or mutate")
	for item_id: Variant in DURATIONS:
		var use_context: Dictionary = context.duplicate(true)
		use_context.owned[str(item_id)] = 1
		var proposal: Dictionary = domain.propose({"op": "jade_use", "item_id": item_id}, use_context, state)
		_check(bool(proposal.get("ok", false)), scope + " recharge sourceID " + str(item_id))
		if proposal.get("ok", false):
			_check(int(proposal.ain.dragon_orb_expires_at) == int(context.nowUnix) + int(DURATIONS[item_id]), scope + " preserve raw duration " + str(item_id))
			_check(not proposal.state.jade.has("expires_at") and proposal.ain.last_orb_purchase_month == "2019-01" and proposal.ain.auto_recharge and is_equal_approx(float(proposal.ain.spend_remainder), 0.5), scope + " single ain timer and existing monthly contract")
	_check(state == before and int(context.ain.dragon_orb_expires_at) == 0, scope + " jade stages inputs")
	for material: int in [124662, 163154, 191124, 195284]:
		context.owned[str(material)] = 1
		_check(not domain.propose({"op": "jade_use", "item_id": material}, context, state).get("ok", false), scope + " same-name material cannot recharge " + str(material))
	var production_context: Dictionary = context.duplicate(true)
	production_context.erase("allow_test_items")
	production_context.owned["123412"] = 1
	_check(domain.propose({"op": "jade_use", "item_id": 123412}, production_context, state).get("error") == "source_test_item", scope + " production rejects source TestItem")
	context.owned["139931"] = 1
	context.ain.dragon_orb_expires_at = int(context.nowUnix) + 86401
	_check(domain.propose({"op": "jade_use", "item_id": 139931}, context, state).get("error") == "jade_reuse_requires_final_24_hours", scope + " reject reuse before final24h")
	context.ain.dragon_orb_expires_at = int(context.nowUnix) + 86400
	var renewed: Dictionary = domain.propose({"op": "jade_use", "item_id": 139931}, context, state)
	_check(renewed.get("ok", false) and int(renewed.ain.dragon_orb_expires_at) == int(context.nowUnix) + 2592000, scope + " inclusive final24h resets from use")
	context.ain = renewed.ain
	state = renewed.state
	var status: Dictionary = domain.jade_status(context, state)
	_check(status.active and int(status.protection_level) == 1 and is_equal_approx(float(status.exp_multiplier), 4.0) and is_equal_approx(float(status.adena_multiplier), 1.5) and status.protected_drops, scope + " zero blessing protection")
	context.nowUnix = int(context.ain.dragon_orb_expires_at)
	var observed: Dictionary = domain.propose({"op": "observe"}, context, state)
	state = observed.state
	_check(not domain.jade_status(context, state).active, scope + " offline expiry boundary")
	context.nowUnix = int(context.nowUnix) - 1
	_check(domain.propose({"op": "jade_use", "item_id": 139931}, context, state).get("error") == "clock_rollback" and not domain.jade_status(context, state).active, scope + " rollback cannot reactivate persisted expiry")
	var corrupt: Dictionary = state.duplicate(true)
	corrupt.rng_state = 0
	_check(not domain.validate_state(corrupt).is_empty() and not domain.propose({"op": "observe"}, context, corrupt).get("ok", false), scope + " corrupt seed rejected")
	corrupt = state.duplicate(true)
	corrupt.rng_state = 2.5
	_check(not domain.validate_state(corrupt).is_empty(), scope + " fractional seed rejected")
	context = _context()
	context.owned["188674"] = 1
	context.level = 86
	_check(not domain.propose({"op": "jade_use", "item_id": 188674}, context, domain.initial_state()).get("ok", false), scope + " shining level86 rejected")
	context.level = 85
	var shiny: Dictionary = domain.propose({"op": "jade_use", "item_id": 188674}, context, domain.initial_state())
	_check(shiny.get("ok", false), scope + " shining level85 accepted")
	if shiny.get("ok", false):
		context.ain = shiny.ain
		_check(int(domain.jade_status(context, shiny.state).protection_level) == 2, scope + " shiny source fixedlevel2")
		context.level = 86
		_check(not domain.jade_status(context, shiny.state).active, scope + " shiny erased on86")
	context = _context()
	context.nowUnix = 1793780000
	context.owned["195254"] = 1
	_check(domain.propose({"op": "jade_use", "item_id": 195254}, context, domain.initial_state()).get("error") == "source_item_expired", scope + " historical source expiration enforced")
	context = _context()
	state = domain.initial_state()
	before = state.duplicate(true)
	var first: Dictionary = domain.propose({"op": "grail_roll", "instance_id": "a"}, context, state)
	var repeat: Dictionary = domain.propose({"op": "grail_roll", "instance_id": "a"}, context, state)
	_check(first.get("ok", false) and first == repeat, scope + " deterministic staged rolls")
	_check(state == before and int(context.owned["355334"]) == 1000, scope + " roll inputs untouched")
	if first.get("ok", false):
		_check(first.costs == [{"kind": "item", "id": 355334, "amount": 2}, {"kind": "currency", "id": 1, "amount": 10000}] and first.rewards.is_empty(), scope + " source cost2scrolls10000Adena no grants")
		_check(first.state.grails.size() == 1 and first.state.grails.has("a") and not first.state.grails.has("b"), scope + " physical sibling isolation")
		var second: Dictionary = domain.propose({"op": "grail_roll", "instance_id": "a"}, context, first.state)
		_check(second.get("ok", false) and second.state.grails.size() == 1 and int(second.state.rng_state) != int(first.state.rng_state), scope + " reroll replaces and advances persisted RNG")
	for pair: Array in [["hero", 10], ["legend", 50]]:
		var rolled: Dictionary = domain.propose({"op": "grail_roll", "instance_id": pair[0]}, context, state)
		_check(rolled.get("ok", false) and int(rolled.costs[0].amount) == int(pair[1]), scope + " rarity sourcecost " + str(pair[1]))
	var missing: Dictionary = context.duplicate(true)
	missing.instances.a.sourceID = 124662
	_check(not domain.propose({"op": "grail_roll", "instance_id": "a"}, missing, state).get("ok", false), scope + " no name-based grail match")
	missing = context.duplicate(true)
	missing.owned["355334"] = 1
	_check(domain.propose({"op": "grail_roll", "instance_id": "a"}, missing, state).get("error") == "grail_insufficient_cost", scope + " reject insufficient resources")
	var rng: Dictionary = {"rng_state": 52371}
	var none_count: int = 0
	var first_count: int = 0
	var guaranteed_base: bool = true
	for _index: int in range(10000):
		var prefix: int = domain._roll_prefix(4, 1, rng)
		none_count += 1 if prefix == 0 else 0
		first_count += 1 if prefix == 4 else 0
		guaranteed_base = guaranteed_base and domain._roll_prefix(4, 2, rng) > 0
	_check(guaranteed_base, scope + " guaranteed base in10000 deterministic draws")
	_check(none_count > 5700 and none_count < 6300 and first_count > 1750 and first_count < 2250, scope + " source absolute denominator leaves60percent empty")
	state = domain.initial_state()
	for instance_id: String in ["a", "b", "c", "d"]:
		state.grails[instance_id] = {"item_id": 338438, "grace_id": 4, "absolute_prefix_id": 14, "base_prefix_id": 24}
	var bonuses: Dictionary = domain.bonuses(context, state)
	var set_effects: int = 0
	for effect: Dictionary in bonuses.effects:
		if int(effect.get("set_id", 0)) == 74:
			set_effects += 1
	_check(set_effects == 6, scope + " all six source2and4 threshold set effects despite absoluteBonusID0")
	_check(is_equal_approx(float(bonuses.stats.get("max_hp", 0)), 200.0) and is_equal_approx(float(bonuses.stats.get("exp_bonus_pct", 0)), 10.0), scope + " possession base effects stack by owned physicalcopy")
	missing = context.duplicate(true)
	missing.instances.erase("d")
	var reduced: Dictionary = domain.bonuses(missing, state)
	var four_active: bool = false
	for effect: Dictionary in reduced.effects:
		if effect.get("origin") == "set" and int(effect.get("threshold", 0)) == 4:
			four_active = true
	_check(not four_active, scope + " sold physicalcopy stops set bonus without deleting saved graces")
	var expired: Dictionary = context.duplicate(true)
	expired.instances.a.expires_at = int(context.nowUnix)
	_check(not domain.propose({"op": "grail_roll", "instance_id": "a"}, expired, state).get("ok", false), scope + " expired physicalcopy rejected")
	var rollback_state: Dictionary = state.duplicate(true)
	rollback_state.latest_at = int(context.nowUnix) + 100
	expired = context.duplicate(true)
	expired.instances.a.expires_at = int(context.nowUnix) + 50
	_check(is_equal_approx(float(domain.bonuses(expired, rollback_state).stats.get("max_hp", 0)), 150.0), scope + " physical expiry cannot rollback into possession effects")
	var pvp_context: Dictionary = _context()
	pvp_context.owned["338458"] = 2
	pvp_context.instances.legend2 = {"sourceID": 338458, "instance_id": "legend2"}
	var pvp_state: Dictionary = domain.initial_state()
	for instance_id: String in ["legend", "legend2"]:
		pvp_state.grails[instance_id] = {"item_id": 338458, "grace_id": 24, "absolute_prefix_id": 4, "base_prefix_id": 24}
	var conditional: Dictionary = domain.bonuses(pvp_context, pvp_state)
	_check(not conditional.stats.has("pvp_damage_reduction_pct") and is_equal_approx(float(conditional.conditional_stats.pvp.get("pvp_damage_reduction_pct", 0)), 1.0), scope + " source1e4 equals1percent and PvP is conditional")
	var flagged: bool = false
	for effect: Dictionary in conditional.unsupported:
		flagged = flagged or effect.get("reason") == "pvp_context_required"
	_check(flagged, scope + " unsupported PvP context explicit")
	pvp_context.pvp = true
	_check(is_equal_approx(float(domain.bonuses(pvp_context, pvp_state).stats.get("pvp_damage_reduction_pct", 0)), 1.0), scope + " source PvP bonus applies only with matchingcontext")
	var synthetic: Dictionary = state.duplicate(true)
	synthetic.grails.a.base_prefix_id = 999999
	_check(not domain.validate_state(synthetic).is_empty(), scope + " corrupt prefix rejected")

func _fixture() -> Fixture:
	# Minimal synthetic table contracts; the optional second run reads the verified
	# full source directory. No originals, grants, or production fallback are added.
	var source: Fixture = Fixture.new()
	var data: Dictionary = {"ItemClass": [], "ItemBonus": [], "Bonus": [], "BonusType": [], "BuffClass": [{"ID": 54252, "EraseOnLevel": 0}, {"ID": 66574, "EraseOnLevel": 86}, {"ID": 67731, "EraseOnLevel": 86}], "BuffBonus": [], "EinasadBenefit": [], "CurrencyUnitClass": [{"ID": 3614, "CurrencyID": 2964, "UnitID": 4, "ClassID": 355334, "ForGive": false}], "ItemGrace": [], "ItemGraceCost": [], "ItemGraceSlot": [{"ID": 4, "SlotNumber": 1, "GraceProbabilityTotal": 1000000}, {"ID": 14, "SlotNumber": 2, "GraceProbabilityTotal": 0}], "ItemGracePrefix": [], "ItemGraceBonus": [], "ItemGraceSet": [{"ID": 74, "GraceID": 4}], "ItemGracePrefixForSet": [{"ID": 1, "GraceSetID": 74, "GracePrefixID": 14}, {"ID": 2, "GraceSetID": 74, "GracePrefixID": 24}], "ItemGraceSetBonus": []}
	var next_id: int = 1
	for item_id: Variant in DURATIONS:
		data.ItemClass.append({"ID": item_id, "CategoryID": 10291, "Name": "same fixture name", "TestItem": int(item_id) in [123412, 139101, 139931, 195112], "LevelLimitMax": 85 if int(item_id) == 188674 else 74 if int(item_id) == 139101 else 0})
		for value: Array in [[109, DURATIONS[item_id]], [3851, 14 if int(item_id) in [188674, 197781, 255643] else 1]]:
			data.Bonus.append({"ID": next_id, "BonusTypeID": value[0], "Value": value[1]})
			data.ItemBonus.append({"ID": next_id, "ItemClassID": item_id, "BonusID": next_id, "IsPossession": false})
			next_id += 1
	data.Bonus.append({"ID": next_id, "BonusTypeID": 492, "Value": 2021102005})
	data.ItemBonus.append({"ID": next_id, "ItemClassID": 195254, "BonusID": next_id, "IsPossession": false})
	next_id += 1
	for item_id: int in [124662, 163154, 191124, 195284]:
		data.ItemClass.append({"ID": item_id, "CategoryID": 10, "Name": "same fixture name"})
	for values: Array in [[54252, 1], [66574, 2], [67731, 2]]:
		data.Bonus.append({"ID": next_id, "BonusTypeID": 3632, "Value": values[1]})
		data.BuffBonus.append({"ID": next_id, "BuffClassID": values[0], "BonusID": next_id})
		next_id += 1
	for level: int in range(3):
		for values: Array in [[2, [0, 300, 600][level]], [12, [0, 50, 100][level]]]:
			data.EinasadBenefit.append({"ID": next_id, "Level": level, "EinasadBenefitTypeID": values[0], "Value": values[1]})
			next_id += 1
	for type_id: int in [1, 2, 4, 10, 11, 17, 37, 133, 12338]:
		data.BonusType.append({"ID": type_id, "UnitID": 3 if type_id == 133 else 1})
	for values: Array in [[338438, 3, 4, 2], [338448, 4, 14, 10], [338458, 5, 24, 50]]:
		data.ItemClass.append({"ID": values[0], "CategoryID": 10622, "GradeID": values[1], "Name": "same fixture name"})
		data.ItemGrace.append({"ID": values[2], "GradeID": values[1], "ItemCategoryID": 10622})
		data.ItemGraceCost.append({"ID": values[2], "GraceID": values[2], "ScrollConsumeAmount": values[3], "AdenaCost": 10000})
		for prefix: int in [4, 14, 24, 34, 44, 54, 64, 74, 84]:
			var position: int = [4, 14, 24, 34, 44, 54, 64, 74, 84].find(prefix)
			data.ItemGraceBonus.append({"ID": next_id, "GraceID": values[2], "GracePrefixID": prefix, "BonusID": 0 if prefix < 24 else next_id, "Probability": [200000, 200000, 60000, 60000, 60000, 130000, 130000, 280000, 280000][position]})
			if prefix >= 24:
				data.Bonus.append({"ID": next_id, "BonusTypeID": 2, "Value": 1})
			next_id += 1
		var base: Array = [[17, 50], [133, 10000]] if int(values[0]) == 338438 else [[2, 1], [11, 1], [37, 1], [133, 20000]] if int(values[0]) == 338448 else [[1, 1], [10, 1], [4, 1], [133, 40000]]
		base.append([12338, 1])
		for bonus: Array in base:
			data.ItemBonus.append({"ID": next_id, "ItemClassID": values[0], "BonusID": next_id, "IsPossession": true})
			data.Bonus.append({"ID": next_id, "BonusTypeID": bonus[0], "Value": bonus[1]})
			next_id += 1
	for prefix: int in [4, 14, 24, 34, 44, 54, 64, 74, 84]:
		data.ItemGracePrefix.append({"ID": prefix, "SlotNumber": 1 if prefix < 24 else 2})
	for threshold: int in [2, 4]:
		for type_id: int in [1, 10, 4]:
			data.ItemGraceSetBonus.append({"ID": next_id, "GraceSetID": 74, "ItemCount": threshold, "BonusID": next_id})
			data.Bonus.append({"ID": next_id, "BonusTypeID": type_id, "Value": 1 if threshold == 2 else 2})
			next_id += 1
	data.ItemGraceSet.append({"ID": 284, "GraceID": 24})
	data.ItemGracePrefixForSet.append({"ID": 564, "GraceSetID": 284, "GracePrefixID": 4})
	data.ItemGracePrefixForSet.append({"ID": 574, "GraceSetID": 284, "GracePrefixID": 24})
	data.ItemGraceSetBonus.append({"ID": 584, "GraceSetID": 284, "ItemCount": 2, "BonusID": 2250064})
	data.Bonus.append({"ID": 2250064, "BonusTypeID": 7818, "Value": 10000})
	data.BonusType.append({"ID": 7818, "UnitID": 3})
	source.data = data
	return source
