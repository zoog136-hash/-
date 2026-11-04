extends SceneTree
## Opt-in private-source contract audit. No Main, acquisition, save, or art claims.
## Run explicitly with -- --equipment523-rules=<private JSON> [--equipment523-sha256=<SHA>].
## Every source row/probability stays unchanged. Ownership, physical IDs, current
## enchant/bless/element states and the single-target hit host are synthetic fixtures.
const C = preload("res://scripts/equipment523/common.gd")
const Smith = preload("res://scripts/equipment523/smith_smelt.gd")
const Alchemy = preload("res://scripts/equipment523/alchemy.gd")
const Sets = preload("res://scripts/equipment523/set_invoke.gd")
const PACK_SHA := "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700"
var pack: Dictionary = {}
var policy: Dictionary = {}
var checks: int = 0
var failures: Array[String] = []
var domains: Dictionary = {}
var selectors: Dictionary = {}
var equip_slots: Dictionary = {}
var representatives: Dictionary = {}
var host_sources: Dictionary = {}
var host_warnings: Dictionary = {}
var rng := RandomNumberGenerator.new()

class HitHost extends Node:
	var rng := RandomNumberGenerator.new()
	var skill_cooldowns: Dictionary = {}
	var player := Node2D.new()
	func _world_to_cell(position: Vector2) -> Vector2i: return Vector2i(position)
	func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return true

class HitVictim extends Node2D:
	var hp: int = 1000000000
	var dead: bool = false
	func take_damage(amount: int, _critical: bool, _kind: String) -> void:
		hp -= amount
		dead = hp <= 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path: String = ""
	var digest: String = PACK_SHA
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-rules="): path = arg.trim_prefix("--equipment523-rules=")
		if arg.begins_with("--equipment523-sha256="): digest = arg.trim_prefix("--equipment523-sha256=")
	_check("pack", not path.is_empty() and FileAccess.file_exists(path), "explicit private rules file is required")
	if not failures.is_empty():
		_finish()
		return
	_check("pack", digest.length() == 64 and FileAccess.get_sha256(path) == digest, "private JSON SHA256 matches the provided expected digest")
	var parser := JSON.new()
	var parse_code: Error = parser.parse(FileAccess.get_file_as_string(path))
	_check("pack", parse_code == OK and parser.data is Dictionary, "private pack JSON parses as a dictionary")
	if not failures.is_empty():
		_finish()
		return
	pack = parser.data
	_check("pack", pack.get("schema") == C.SCHEMA and pack.get("source_sha256") == C.SOURCE_SHA, "pack schema and original archive SHA are pinned")
	for key: String in ["tables", "items", "bonuses", "audit"]:
		_check("pack", pack.get(key) is Dictionary, "pack dictionary " + key)
	if not failures.is_empty():
		_finish()
		return
	var policy_parser := JSON.new()
	var policy_code: Error = policy_parser.parse(FileAccess.get_file_as_string("res://data/equipment523/policy.json"))
	_check("pack", policy_code == OK and policy_parser.data is Dictionary, "current explicit TWILIGHT policy parses")
	if not failures.is_empty():
		_finish()
		return
	policy = policy_parser.data
	rng.seed = 52320261104
	_index()
	_elemental()
	_bless()
	_smelt()
	_alchemy()
	_sets()
	_invoke()
	_check("pack",FileAccess.get_sha256(path) == digest,"private source file bytes remain unchanged after all contract checks")
	_finish()

func _check(domain: String, ok: bool, label: String) -> void:
	checks += 1
	if not domains.has(domain): domains[domain] = {"checks":0,"failures":0,"runtime_cases":0,"reference_rows":0,"external_dependencies":[]}
	domains[domain].checks += 1
	if not ok:
		failures.append(domain + ": " + label)
		domains[domain].failures += 1

func _note(domain: String, value: Variant) -> void:
	if not domains.has(domain): domains[domain] = {"checks":0,"failures":0,"runtime_cases":0,"reference_rows":0,"external_dependencies":[]}
	domains[domain].external_dependencies.append(value)

func _finish() -> void:
	print("EQUIPMENT523_SOURCE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"by_domain":domains,
		"scope":{"type":"PRIVATE_SOURCE_CONTRACT_WITH_SYNTHETIC_OWNERSHIP", "main_loaded":false,
			"normal_acquisition_verified":false,"save_reload_verified":false,"original_art_verified":false,
			"source_probabilities_modified":false,"current_item_metadata":"exact private pack raw IDs, grades, weapon and equip-slot selectors",
			"runtime_context":"synthetic physical IDs and current enchant/bless/element; source reachability gaps are separate",
			"invoke_host":"synthetic single target at zero distance with clear line of sight; no Main spatial or visual verification"}}))
	quit(0 if failures.is_empty() else 1)

func _index() -> void:
	for binding: Dictionary in pack.get("bindings",{}).values(): host_sources[str(int(binding.get("source_id",0)))] = true
	for row: Dictionary in C.rows(pack,"ItemBonus"):
		var key: String = str(int(row.ItemClassID))
		var bonus: Dictionary = C.bonus(pack,int(row.BonusID))
		if not selectors.has(key): selectors[key] = {}
		var name: String = str(bonus.get("name",""))
		# Match runtime first-selector semantics, without changing source rows.
		if not selectors[key].has(name): selectors[key][name] = int(bonus.get("raw",{}).get("Value",0))
	for row: Dictionary in C.rows(pack,"ItemEquipSlot"):
		var key: String = str(int(row.ItemClassID))
		if not equip_slots.has(key): equip_slots[key] = []
		equip_slots[key].append(int(row.EquipSlotID))
	for key: String in pack.items:
		var raw: Dictionary = pack.items[key].get("raw",{})
		if bool(raw.get("TestItem",false)): continue
		var weapon: int = _value(int(key),"WeaponType")
		var grade: int = int(raw.get("GradeID",0))
		var combo: String = "%d:%d" % [weapon,grade]
		if not representatives.has(combo): representatives[combo] = int(key)
		for slot: Variant in equip_slots.get(key,[]):
			var slot_combo: String = "%d:%d:%d" % [int(slot),weapon,grade]
			if not representatives.has(slot_combo): representatives[slot_combo] = int(key)

func _value(id: int, key: String) -> int:
	return int(selectors.get(str(id),{}).get(key,0))

func _host_registration(domain: String, id: int) -> void:
	var key: String = domain+":"+str(id)
	if host_sources.has(str(id)) or host_warnings.has(key): return
	host_warnings[key] = true
	_note(domain,{"source_id":id,"reason":"no exact current Main catalog binding in pack; domain kernel fixture only, not playable acquisition/equip verification"})

func _target(id: int, level: int = 0, bless: int = 1) -> Dictionary:
	return {"source_id":id,"instance_id":"source-fixture-"+str(id),"level":level,"bless_code":bless,
		"element_type":0,"element_level":0,"locked":false,"equipped":true,"state":{},
		"record":{"source_item_class_id":id,"sourceId":"m523:item:"+str(id)},"fixture_only":true}

func _material(id: int, bless: int = 1) -> Dictionary:
	return {"source_id":id,"instance_id":"material-fixture-"+str(id),"bless_code":bless,"amount":1,"locked":false,"equipped":false}

func _sum(rows: Array, field: String) -> int:
	var total: int = 0
	for row: Dictionary in rows: total += int(row.get(field,0))
	return total

func _smith_case(domain: String, kind: String, target: Dictionary, material: Dictionary, label: String) -> void:
	_host_registration(domain,int(target.source_id))
	_host_registration(domain,int(material.source_id))
	var context: Dictionary = {"target":target,"materials":[material],"policy":policy,"now_unix":2000000000}
	var q: Dictionary = Smith.quote(pack,{"kind":kind,"target_id":target.instance_id},context)
	_check(domain,q.get("ok",false),label+" quote: "+str(q.get("error","")))
	if not q.get("ok",false): return
	var rolled: Dictionary = Smith.roll(pack,q,rng)
	_check(domain,rolled.get("ok",false),label+" source-weighted roll")
	if not rolled.get("ok",false): return
	domains[domain].runtime_cases += 1
	var state: Dictionary = rolled.state
	var expected: Array = []
	for selected: Dictionary in state[kind].slots:
		var info: Dictionary = C.bonus(pack,int(selected.bonus_id))
		if bool(info.get("supported",false)) and not info.get("record",{}).is_empty(): expected.append(int(selected.bonus_id))
	var active: Array[Dictionary] = Smith.active_effects(pack,target,kind,state,2000000000,policy)
	var actual: Array = []
	for record: Dictionary in active: actual.append(int(record.get("equipment523_bonus_id",0)))
	_check(domain,actual == expected,label+" active effects match selected authoritative bonus IDs")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(state))
	_check(domain,Smith.active_effects(pack,target,kind,restored,2000000000,policy) == active,label+" state JSON roundtrip (not Main/save-file verification)")

func _elemental() -> void:
	var domain := "elemental_smith"
	var definitions: Array = C.rows(pack,"ElementalSmith")
	_check(domain,definitions.size() == 114,"all 114 source eligibility configurations retained")
	domains[domain].reference_rows = definitions.size()
	var scrolls: Dictionary = {}
	for key: String in selectors:
		if _value(int(key),"ScrollElementalSmith") == 1 and not bool(C.item(pack,int(key)).get("raw",{}).get("TestItem",false)):
			var element: int = _value(int(key),"ScrollElementalType")
			if not scrolls.has(element): scrolls[element] = int(key)
	_check(domain,scrolls.size() == 4,"exact source scroll selectors cover four elements")
	for definition: Dictionary in definitions:
		var source: int = int(representatives.get("%d:%d" % [int(definition.WeaponTypeID),int(definition.GradeID)],0))
		if source == 0: _note(domain,{"config_id":int(definition.ID),"reason":"no non-test source item with exact original weapon-type/grade selectors"})
		for element: int in [1,2,3,4]:
			for bless: int in [1,2]:
				var parents: Array = []
				for row: Dictionary in C.rows(pack,"ElementalSmithProbability"):
					if int(row.ElementalSmithID) == int(definition.ID) and int(row.ItemBlessCodeID) == bless: parents.append(row)
				_check(domain,parents.size() == 2,"two source slots config=%d element=%d material_bless=%d" % [int(definition.ID),element,bless])
				for parent: Dictionary in parents:
					var pool: Array = []
					for row: Dictionary in C.rows(pack,"ElementalSmithBonus"):
						if int(row.ElementalSmithProbGroupID) == int(parent.ElementalSmithProbGroupID) and int(row.ElementalTypeID) in [0,element]: pool.append(row)
					_check(domain,_sum(pool,"Probability") == 10000000,"exact element-filtered probability pool parent="+str(int(parent.ID))+" element="+str(element))
				if source == 0 or not scrolls.has(element): continue
				var target: Dictionary = _target(source)
				target.element_type = element
				target.element_level = 3
				_smith_case(domain,"elemental_smith",target,_material(int(scrolls[element]),bless),"config=%d element=%d material_bless=%d" % [int(definition.ID),element,bless])

func _bless() -> void:
	var domain := "bless_reinforcement"
	var enabled: Array = pack.audit.get("domains",{}).get("five_smith_smelt",{}).get("bless_eligibility",{}).get("runtime_enabled_config_ids",[])
	_check(domain,enabled.size() == 51,"source grade/slot/test eligibility exposes 51 enabled configurations")
	domains[domain].reference_rows = C.rows(pack,"ItemBlessReinforcementBonus").size()
	var pools: Dictionary = {}
	for row: Dictionary in C.rows(pack,"ItemBlessReinforcementBonus"):
		var key: String = "%d:%d" % [int(row.ItemBlessReinforcementID),int(row.SlotNumber)]
		pools[key] = int(pools.get(key,0)) + int(row.Prob1)
		_check(domain,int(row.Prob2) == 0 and not C.bonus(pack,int(row.BonusID)).is_empty(),"Prob2 zero and bonus reference row="+str(int(row.ID)))
	for key: String in pools:
		var expected: int = 10050000 if key == "1521:2" else 10000000
		_check(domain,int(pools[key]) == expected,"source probability retained without normalizing pool="+key)
	_check(domain,pools.size() == 282 and int(pools.get("1521:2",0)) == 10050000,"known 100.5 percent source anomaly remains visible")
	var material: int = 0
	for key: String in pack.items:
		var raw: Dictionary = pack.items[key].get("raw",{})
		if int(raw.get("CategoryID",0)) == 151 and not bool(raw.get("TestItem",false)) and _value(int(key),"GuaranteeBlessProb") == 0:
			material = int(key)
			break
	_check(domain,material > 0,"original ordinary blessing scroll exists")
	for config_id: Variant in enabled:
		var config: Dictionary = C.find(pack,"ItemBlessReinforcement",int(config_id))
		var combo: String = "%d:%d:%d" % [int(config.get("EquipSlotID",0)),int(config.get("WeaponTypeID",0)),int(config.get("GradeID",0))]
		var source: int = int(representatives.get(combo,0))
		if source == 0:
			_note(domain,{"config_id":int(config_id),"reason":"no non-test source item with exact original equip-slot/weapon-type/grade selectors"})
			continue
		_smith_case(domain,"bless_reinforcement",_target(source,0,2),_material(material),"config="+str(int(config_id)))

func _smelt() -> void:
	var domain := "smelt"
	var entities: Array = C.rows(pack,"ItemSmeltEntity")
	_check(domain,entities.size() == 65 and not C.item(pack,289162).is_empty(),"65 original normal-smelt targets and life stone retained")
	domains[domain].reference_rows = entities.size()
	var pools: Dictionary = {}
	var none_count: int = 0
	for row: Dictionary in C.rows(pack,"ItemSmeltBonus"):
		var key: String = "%d:%d" % [int(row.ItemSmeltID),int(row.SlotNumber)]
		pools[key] = int(pools.get(key,0)) + int(row.Prob)
		if C.bonus(pack,int(row.BonusID)).get("name") == "None":
			none_count += 1
			_check(domain,int(row.Prob) == 7000000 and int(row.SlotNumber) == 3,"source empty third slot keeps exactly 70 percent")
	for key: String in pools: _check(domain,int(pools[key]) == 10000000,"normal/spirit exact source slot pool="+key)
	_check(domain,none_count == 4 and pools.size() == 30,"all four source None rows and thirty slot pools retained")
	for entity: Dictionary in entities:
		_check(domain,not C.item(pack,int(entity.ItemClassID)).is_empty(),"normal smelt original target exists="+str(int(entity.ItemClassID)))
		_smith_case(domain,"smelt",_target(int(entity.ItemClassID)),_material(289162),"target="+str(int(entity.ItemClassID)))
	var spirit := "spirit_smelt"
	var spirit_rows: Array = C.rows(pack,"ItemSpiritSmeltEntity")
	_check(spirit,spirit_rows.size() == 16,"all sixteen original spirit target/pool selectors retained")
	domains[spirit].reference_rows = spirit_rows.size()
	var permanent: Dictionary = {}
	for key: String in selectors:
		var selected: Dictionary = selectors[key]
		var pool: int = int(selected.get("SpiritSmelt",0))
		if pool > 0 and not selected.has("DeleteTime") and not selected.has("SmeltExpireDate") and not permanent.has(pool): permanent[pool] = int(key)
	var saw_none: bool = false
	for entity: Dictionary in spirit_rows:
		var pool: int = int(entity.ItemSmeltID)
		_check(spirit,permanent.has(pool),"permanent original spirit core pool="+str(pool))
		if not permanent.has(pool): continue
		for level: int in [0,5,7]:
			var target: Dictionary = _target(int(entity.ItemClassID),level,1 if int(entity.BlessCode) == 0 else int(entity.BlessCode))
			_smith_case(spirit,"spirit_smelt",target,_material(int(permanent[pool])),"target=%d pool=%d enchant=%d" % [int(entity.ItemClassID),pool,level])
			if level != 7 or saw_none: continue
			var q: Dictionary = Smith.quote(pack,{"kind":"spirit_smelt","target_id":target.instance_id},{"target":target,"materials":[_material(int(permanent[pool]))],"policy":policy,"now_unix":2000000000})
			if not q.get("ok",false): continue
			for _attempt: int in range(64):
				var rolled: Dictionary = Smith.roll(pack,q,rng)
				if not rolled.get("ok",false): break
				for selected: Dictionary in rolled.state.spirit_smelt.slots:
					if bool(selected.get("empty",false)): saw_none = true
				if saw_none: break
	_check(spirit,saw_none,"unmodified source weights produce a genuine empty third slot")

func _alchemy() -> void:
	var domain := "alchemy"
	var pools: Dictionary = {}
	for row: Dictionary in C.rows(pack,"AlchemyResult"):
		var key: String = "%d:%d:%d:%d" % [int(row.RecipeTypeID),int(row.PriceLow),int(row.PriceHigh),int(row.ServerLimitSetID)]
		pools[key] = int(pools.get(key,0)) + int(row.Probability)
		_check(domain,not C.item(pack,int(row.ItemClassID)).is_empty() and int(row.Amount) > 0 and int(row.PriceLow) <= int(row.PriceHigh),"exact output identity/quantity/range row="+str(int(row.ID)))
	_check(domain,pools.size() == 61,"all 61 original recipe/interval/server pools retained")
	for key: String in pools: _check(domain,int(pools[key]) == 10000000,"source probability pool="+key)
	domains[domain].reference_rows = C.rows(pack,"AlchemyResult").size()
	for recipe: int in [63,113]:
		var materials: Array = []
		var ids: Array = []
		var rare_count: int = 0
		for row: Dictionary in C.rows(pack,"AlchemyItem"):
			if int(row.RecipeTypeID) != recipe: continue
			var raw: Dictionary = C.item(pack,int(row.ItemClassID)).get("raw",{})
			var grade: Dictionary = C.find(pack,"Grade",int(raw.get("GradeID",0)))
			var value: int = int(grade.get("GradeValue",0))
			if bool(raw.get("TestItem",false)) or value < 3 or rare_count >= 3: continue
			var info: Dictionary = _target(int(row.ItemClassID))
			_host_registration(domain,int(row.ItemClassID))
			info.equipped = false
			materials.append(info)
			ids.append(info.instance_id)
			rare_count += 1
			if rare_count == 3: break
		_check(domain,materials.size() == 3,"three distinct original rare-or-higher recipe members="+str(recipe))
		var action: Dictionary = {"kind":"alchemy","recipe_type":recipe,"material_ids":ids}
		var q: Dictionary = Alchemy.quote(pack,action,{"materials":materials,"policy":policy,"player_level":99})
		_check(domain,q.get("ok",false),"original recipe quote="+str(recipe)+" "+str(q.get("error","")))
		if not q.get("ok",false): continue
		var result: Dictionary = Alchemy.roll(pack,q,rng)
		_check(domain,result.get("ok",false),"original recipe weighted roll="+str(recipe))
		if result.get("ok",false):
			domains[domain].runtime_cases += 1
			_host_registration(domain,int(result.output.source_id))
			var authoritative: Dictionary = C.find(pack,"AlchemyResult",int(result.result_id))
			_check(domain,int(result.output.source_id) == int(authoritative.ItemClassID) and int(result.output.amount) == int(authoritative.Amount) and int(result.output.level) == int(authoritative.Enchant) and int(result.output.bless_code) == int(authoritative.BlessCode),"all selected source reward fields preserved")
		for disabled: int in [74,84,94]:
			action.recipe_type = disabled
			_check(domain,not Alchemy.quote(pack,action,{"materials":materials,"policy":policy,"player_level":99}).get("ok",false),"inactive recipe rejected="+str(disabled))

func _sets() -> void:
	var domain := "sets"
	_check(domain,C.rows(pack,"ItemSet").size() == 47 and C.rows(pack,"ItemForItemSet").size() == 219,"47 source sets and 219 memberships retained")
	domains[domain].reference_rows = C.rows(pack,"ItemSetBonus").size()
	for row: Dictionary in C.rows(pack,"ItemSetBonus"):
		if not bool(C.bonus(pack,int(row.BonusID)).get("supported",false)):
			_note(domain,{"set_id":int(row.ItemSetID),"bonus_id":int(row.BonusID),"reason":"original bonus retained but numeric host mapping is unsupported"})
	for definition: Dictionary in C.rows(pack,"ItemSet"):
		if int(definition.get("BuffClassID",0)) != 0:
			_note(domain,{"set_id":int(definition.ID),"buff_id":int(definition.BuffClassID),"reason":"source set BuffClass relationship is not a verified Main buff execution"})
		var members: Array = []
		for member: Dictionary in C.rows(pack,"ItemForItemSet"):
			if int(member.ItemSetID) != int(definition.ID): continue
			_check(domain,not C.item(pack,int(member.ItemClassID)).is_empty(),"exact set member source item exists")
			_host_registration(domain,int(member.ItemClassID))
			members.append(_target(int(member.ItemClassID)))
		_check(domain,not members.is_empty(),"set has original members="+str(int(definition.ID)))
		if members.is_empty(): continue
		for count: int in range(1,members.size()+1):
			var worn: Array = members.slice(0,count)
			var result: Dictionary = Sets.equipped(pack,worn,policy)
			var matched: Dictionary = _set_detail(result,int(definition.ID))
			var expected: Array = []
			var threshold: int = 0
			for row: Dictionary in C.rows(pack,"ItemSetBonus"):
				if int(row.ItemSetID) == int(definition.ID) and int(row.CompletionDegree) <= count:
					threshold = maxi(threshold,int(row.CompletionDegree))
					if str(policy.get("set_threshold_mode","")) == "cumulative": expected.append(int(row.BonusID))
			_check(domain,int(matched.get("count",-1)) == count and int(matched.get("threshold",-1)) == threshold and matched.get("bonus_ids",[]) == expected,"exact original membership and cumulative threshold set=%d count=%d" % [int(definition.ID),count])
			var expected_records: Array = []
			for detail: Dictionary in result.get("details",[]):
				for bonus_id: Variant in detail.get("bonus_ids",[]):
					var bonus: Dictionary = C.bonus(pack,int(bonus_id))
					if bool(bonus.get("supported",false)) and not bonus.get("record",{}).is_empty(): expected_records.append(int(bonus_id))
			var actual_records: Array = []
			for record: Dictionary in result.get("records",[]): actual_records.append(int(record.get("equipment523_bonus_id",0)))
			_check(domain,actual_records == expected_records,"only supported exact set bonuses become active numeric records")
			var duplicate: Array = worn.duplicate(true)
			duplicate.append(worn[0].duplicate(true))
			var same_source: Dictionary = worn[0].duplicate(true)
			same_source.instance_id = "other-physical-same-source"
			duplicate.append(same_source)
			_check(domain,_set_detail(Sets.equipped(pack,duplicate,policy),int(definition.ID)) == matched,"duplicate physical/source identities cannot increase set count")
			domains[domain].runtime_cases += 1

func _set_detail(result: Dictionary, id: int) -> Dictionary:
	for detail: Dictionary in result.get("details",[]):
		if int(detail.get("set_id",0)) == id: return detail
	return {}

func _invoke() -> void:
	var domain := "invoke"
	_check(domain,C.rows(pack,"ItemInvokeReplacement").size() == 18 and C.rows(pack,"ItemInvokeReplacementEntityView").size() == 330,"18 source replacements and 330 weighted candidates retained")
	domains[domain].reference_rows = C.rows(pack,"ItemInvokeReplacementBonus").size()
	var variable: int = 0
	var all_slots: int = 0
	var saw_none: bool = false
	var executable_target: Dictionary = {}
	var executable_effect: Dictionary = {}
	var none_quote: Dictionary = {}
	var noted_options: Dictionary = {}
	for definition: Dictionary in C.rows(pack,"ItemInvokeReplacement"):
		var source: int = 0
		for key: String in selectors:
			if _value(int(key),"ItemInvokeReplacementID") == int(definition.ID) and not bool(C.item(pack,int(key)).get("raw",{}).get("TestItem",false)):
				source = int(key)
				break
		var slot_rows: Dictionary = Sets.slots(pack,int(definition.ID))
		if source == 0: _note(domain,{"replacement_id":int(definition.ID),"reason":"no original non-test ItemBonus replacement selector; no synthetic item mapping invented"})
		for slot: Variant in slot_rows:
			all_slots += 1
			var choices: Array = slot_rows[slot]
			_check(domain,_sum(choices,"Prob") == 1000000,"exact source slot probability replacement=%d slot=%s" % [int(definition.ID),str(slot)])
			for row: Dictionary in choices: _check(domain,not C.find(pack,"ItemInvokeReplacementBonusGroup",int(row.ItemInvokeReplacementBonusGroupID)).is_empty(),"source candidate group reference")
			if choices.size() <= 1: continue
			variable += 1
			if source == 0: continue
			_host_registration(domain,source)
			var target: Dictionary = _target(source)
			var q: Dictionary = Sets.quote(pack,"invoke_replacement",{"target":target,"materials":[_material(169994)],"policy":policy,"invoke_slot":int(slot)})
			_check(domain,q.get("ok",false),"reachable original variable slot quotes")
			if not q.get("ok",false): continue
			for candidate: Dictionary in choices:
				if int(candidate.Prob) > 0 and C.find(pack,"ItemInvokeReplacementBonusGroup",int(candidate.ItemInvokeReplacementBonusGroupID)).get("Name") == "None": none_quote = q
			var rolled: Dictionary = Sets.roll(pack,q,rng)
			_check(domain,rolled.get("ok",false),"reachable original variable slot rolls")
			if not rolled.get("ok",false): continue
			domains[domain].runtime_cases += 1
			target.state = rolled.state
			var selected: Dictionary = rolled.state.invoke_replacement.slots[str(slot)]
			var group: Dictionary = C.find(pack,"ItemInvokeReplacementBonusGroup",int(selected.group_id))
			if group.get("Name") == "None":
				saw_none = true
				_check(domain,Sets.effects(pack,target,policy).is_empty(),"source None additional slot contributes no fabricated invoke effect")
			for effect: Dictionary in Sets.effects(pack,target,policy):
				_check(domain,int(effect.group_id) == int(selected.group_id) and int(effect.slot) == int(slot),"selected original slot is the only additional effect source")
				var contract: Dictionary = Sets.spell_contract(pack,effect.option)
				if not contract.get("ok",false) and not noted_options.has(int(effect.option.ID)):
					noted_options[int(effect.option.ID)] = true
					_note(domain,{"invoke_option_id":int(effect.option.ID),"reason":"source option retained but runtime spell contract blocked: "+str(contract.get("error",""))})
				if executable_target.is_empty() and int(effect.probability) > 0 and contract.get("ok",false):
					executable_target = target.duplicate(true)
					executable_effect = effect
	_check(domain,all_slots == 78 and variable == 36,"all 78 source slots audited: 36 variable and 42 fixed original slots")
	var option_types: Dictionary = {}
	for link: Dictionary in C.rows(pack,"ItemInvokeReplacementBonus"):
		_check(domain,not C.find(pack,"ItemInvokeReplacementBonusGroup",int(link.ItemInvokeReplacementBonusGroupID)).is_empty() and not C.bonus(pack,int(link.BonusID)).is_empty(),"exact invoke group/enchant/bless/bonus row reference="+str(int(link.ID)))
		var bonus: Dictionary = C.bonus(pack,int(link.BonusID))
		var raw: Dictionary = bonus.get("raw",{})
		var option: Dictionary = C.find(pack,"InvokeOption",int(raw.get("BonusApplicationTargetID",0)))
		_check(domain,bonus.get("type",{}).get("Name") == "InvokeOption" and int(bonus.get("type",{}).get("UnitID",0)) == 3 and int(raw.get("BonusApplicationTypeID",0)) == 10 and not option.is_empty() and int(raw.get("Value",-1)) >= 0 and int(raw.get("Value",-1)) <= 1000000,"polymorphic option namespace, unit and original trigger probability row="+str(int(link.ID)))
		var type_key: String = str(int(option.get("InvokeOptionTypeID",0)))
		option_types[type_key] = int(option_types.get(type_key,0))+1
	_check(domain,int(option_types.get("1",0)) == 910 and int(option_types.get("38",0)) == 64,"all source spell/aura relationship rows preserved: 910 spell, 64 special")
	domains[domain]["source_option_type_rows"] = option_types
	if not saw_none and not none_quote.is_empty():
		for _attempt: int in range(256):
			var rolled: Dictionary = Sets.roll(pack,none_quote,rng)
			if not rolled.get("ok",false): break
			var selected: Dictionary = rolled.state.invoke_replacement.slots[str(int(none_quote._slot))]
			if C.find(pack,"ItemInvokeReplacementBonusGroup",int(selected.group_id)).get("Name") == "None":
				saw_none = true
				var empty_target: Dictionary = none_quote._target.duplicate(true)
				if empty_target.get("state",{}).is_empty():
					empty_target.state = rolled.state
					_check(domain,Sets.effects(pack,empty_target,policy).is_empty(),"source None selection contributes no fabricated invoke effect")
				break
	_check(domain,saw_none,"source-weighted additional-slot roll reaches None without probability mutation")
	_check(domain,not executable_target.is_empty(),"at least one original selected fixed single-target spell is executable")
	if not executable_target.is_empty(): _invoke_hit(domain,executable_target,executable_effect)

func _invoke_hit(domain: String, target: Dictionary, effect: Dictionary) -> void:
	var host := HitHost.new()
	var victim := HitVictim.new()
	host.rng.seed = 523
	var kind: String = str({0:"melee",1:"melee",2:"ranged",3:"magic"}.get(int(effect.option.get("AttackTypeID",0)),"melee"))
	var fired: Array = []
	for _attempt: int in range(4096):
		host.skill_cooldowns.clear() # Independent synthetic hit trials, never a modified source cooldown.
		fired = Sets.on_hit(pack,host,[target],policy,victim,kind,true,bool(effect.option.get("BySpellAttack",false)))
		if not fired.is_empty(): break
	_check(domain,not fired.is_empty() and victim.hp < 1000000000,"actual source probability and fixed-spell contract execute against synthetic hit host")
	if not fired.is_empty():
		var before: int = victim.hp
		var seed_before: int = host.rng.state
		var second: Array = Sets.on_hit(pack,host,[target],policy,victim,kind,true,bool(effect.option.get("BySpellAttack",false)))
		var contract: Dictionary = Sets.spell_contract(pack,effect.option)
		if int(contract.get("spell",{}).get("CastDelay",0)) > 0: _check(domain,second.is_empty() and victim.hp == before and host.rng.state == seed_before,"exact source cooldown blocks repeated immediate invoke without an extra RNG roll")
	host.player.free()
	host.free()
	victim.free()
