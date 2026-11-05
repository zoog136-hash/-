extends SceneTree
## Opt-in, exact private-source coverage. This does not load Main, acquire items,
## render art, alter saves, roll probabilities, or reconstruct server formulas.
## Supply PackStore's four --equipment523-{rules,sha256,effects,effects-sha256}
## arguments plus --equipment523-remaining-audit=<private audit JSON> and
## --equipment523-remaining-audit-sha256=<expected SHA256> after Godot's --.
## Positive cases use the merged original rows. Negative cases only isolate and
## corrupt existing original rows; no invented source IDs fill missing coverage.
const C = preload("res://scripts/equipment523/common.gd")
const PackStore = preload("res://scripts/equipment523/pack_store.gd")
const Debuff = preload("res://scripts/equipment523/invoke_debuff.gd")
const SetEffects = preload("res://scripts/equipment523/set_effects.gd")
const SetInvoke = preload("res://scripts/equipment523/set_invoke.gd")

var pack: Dictionary = {}
var base: Dictionary = {}
var audit: Dictionary = {}
var policy: Dictionary = {}
var checks: int = 0
var failures: Array[String] = []
var files: Dictionary = {}
var reference: Dictionary = {}
var coverage: Dictionary = {"debuff_rows":0,"debuff_spells":0,"debuff_contracts_ok":0,"set_links":0,"set_definitions":0,"set_contracts_ok":0,"negative_cases":0}
var boundaries: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-") and arg.contains("="):
			var split: int = arg.find("=")
			args[arg.left(split)] = arg.substr(split+1)
	for pair: Array in [["--equipment523-rules","--equipment523-sha256"],["--equipment523-effects","--equipment523-effects-sha256"],["--equipment523-remaining-audit","--equipment523-remaining-audit-sha256"]]:
		var path: String = str(args.get(pair[0],""))
		var digest: String = str(args.get(pair[1],""))
		_check(not path.is_empty() and FileAccess.file_exists(path),"explicit private input: "+str(pair[0]))
		_check(digest.length() == 64 and not path.is_empty() and FileAccess.get_sha256(path) == digest,"expected input SHA: "+str(pair[0]))
		files[path] = digest
	if not failures.is_empty():
		_finish()
		return
	var store = PackStore.new()
	var loaded: Dictionary = store.startup()
	_check(bool(loaded.get("ok",false)),"PackStore.startup verifies base and effects: "+str(loaded.get("error","")))
	_check(store.sha256 == args["--equipment523-sha256"] and store.effects_sha256 == args["--equipment523-effects-sha256"],"startup actually selected both explicit private packs")
	if not failures.is_empty():
		_finish()
		return
	pack = store.pack
	base = store.base_pack
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args["--equipment523-remaining-audit"])))
	_check(parsed is Dictionary,"independent private source audit parses")
	if not parsed is Dictionary:
		_finish()
		return
	audit = parsed
	_check(audit.get("schema") == "equipment523-remaining-private-audit-v1","independent audit schema")
	_check(audit.get("base_cache",{}).get("sha256") == store.sha256 and audit.get("base_cache",{}).get("source_sha256") == C.SOURCE_SHA,"audit pins the original archive and the unchanged base cache")
	_check(pack.get("source_sha256") == C.SOURCE_SHA and pack.get("schema") == C.SCHEMA,"merged pack remains in the original namespace")
	var policy_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment523/policy.json"))
	_check(policy_value is Dictionary,"explicit current host policy parses")
	if not policy_value is Dictionary or not failures.is_empty():
		_finish()
		return
	policy = policy_value
	var before_tables: String = JSON.stringify(pack.get("tables",{}))
	var before_bonuses: String = JSON.stringify(pack.get("bonuses",{}))
	_reference_graph()
	_base_unchanged()
	if failures.is_empty():
		_invoke_rows()
		_set_rows()
	_check(JSON.stringify(pack.get("tables",{})) == before_tables and JSON.stringify(pack.get("bonuses",{})) == before_bonuses,"contracts and negative cases never alter merged source rows or probabilities")
	for path: String in files:
		_check(FileAccess.get_sha256(path) == str(files[path]),"private input bytes remain unchanged")
	_finish()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _negative(ok: bool, label: String) -> void:
	coverage.negative_cases += 1
	_check(ok,label)

func _finish() -> void:
	print("EQUIPMENT523_REMAINING_SOURCE_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"coverage":coverage,"boundaries":boundaries,"scope":{"type":"EXACT_PRIVATE_SOURCE_CONTRACTS_AND_REJECTION_CONDITIONS","main_loaded":false,"normal_acquisition_verified":false,"save_reload_verified":false,"original_art_verified":false,"source_probabilities_modified":false,"positive_source_fixtures_invented":false,"ownership":"only source-bound synthetic physical identities for set counting","negative_cases":"isolated tampering of existing original rows","server_equivalence_claimed":false}}))
	quit(0 if failures.is_empty() else 1)

func _same(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return is_finite(float(left)) and is_finite(float(right)) and float(left) == float(right)
	if typeof(left) != typeof(right): return false
	if left is Dictionary:
		if left.size() != right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not _same(left[key],right[key]): return false
		return true
	if left is Array:
		if left.size() != right.size(): return false
		for i: int in range(left.size()):
			if not _same(left[i],right[i]): return false
		return true
	return left == right

func _row_key(row: Dictionary) -> String:
	if row.has("ID"): return str(int(row.ID))
	if row.has("ItemSetID") and row.has("ItemClassID"):
		return "%d|%d" % [int(row.ItemSetID),int(row.ItemClassID)]
	# ItemEquipSlot and ItemEnchantEquipGroupMapping also have natural keys.
	var fields: Array = row.keys()
	fields.sort()
	var parts: Array = []
	for field: Variant in fields: parts.append([field,row[field]])
	return JSON.stringify(parts)

func _index(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in rows:
		var key: String = _row_key(row)
		_check(not out.has(key),"source row identity is unique: "+key)
		out[key] = row
	return out

func _reference_graph() -> void:
	var source_rows: Dictionary = audit.get("minimal_referenced_source_rows",{})
	var required: Dictionary = {}
	for section: String in ["gameplay_graph_rows","typed_contract_metadata"]:
		for name: String in audit.get("minimal_additional_dependencies",{}).get(section,{}): required[name] = true
	for name: String in ["ItemInvokeReplacement","ItemInvokeReplacementEntityView","ItemInvokeReplacementBonusGroup","ItemInvokeReplacementBonus","ItemSet","ItemForItemSet","ItemSetBonus"]: required[name] = true
	_check(required.size() > 20 and source_rows.size() >= required.size(),"audit supplies the entire mechanical and typed metadata closure")
	for name: String in required:
		_check(source_rows.get(name) is Array,"audit source table exists: "+name)
		if not source_rows.get(name) is Array: continue
		reference[name] = _index(source_rows[name])
		var current: Dictionary = _index(C.rows(pack,name))
		for key: String in reference[name]:
			_check(current.has(key) and _same(current.get(key,{}),reference[name][key]),"merged original graph matches independently audited "+name+":"+key)
	# Description and status-visual enums are evidence boundaries, not fabricated
	# mechanical definitions. Their absence must not be filled with test IDs.
	boundaries["source_missing_definitions"] = audit.get("additional_source_missing_definitions",[])
	_check(audit.get("source_missing_references",[]).is_empty(),"independent audit has no dangling typed mechanical join")
	_check(int(audit.get("roots",{}).get("debuff_bonus_rows",0)) == 126 and int(audit.get("roots",{}).get("set_special_bonus_rows",0)) == 22,"audit independently covers all requested source roots")

func _base_unchanged() -> void:
	for name: String in base.get("tables",{}):
		var merged: Dictionary = _index(C.rows(pack,name))
		var unchanged: bool = true
		for row: Dictionary in C.rows(base,name):
			if not merged.has(_row_key(row)) or not _same(row,merged.get(_row_key(row),{})): unchanged = false
		_check(unchanged,"effects extension preserves every base row: "+name)
	for id: String in base.get("bonuses",{}):
		_check(_same(base.bonuses[id],pack.get("bonuses",{}).get(id,{})),"base typed bonus wrapper preserved: "+id)

func _typed_bonus(id: int) -> Dictionary:
	var value: Dictionary = C.bonus(pack,id)
	var raw: Dictionary = value.get("raw",{})
	var kind: Dictionary = value.get("type",{})
	_check(not raw.is_empty() and int(raw.get("ID",0)) == id,"real source Bonus exists: "+str(id))
	_check(_same(raw,C.find(pack,"Bonus",id)),"typed wrapper preserves raw Bonus: "+str(id))
	_check(_same(kind,C.find(pack,"BonusType",int(raw.get("BonusTypeID",0)))),"typed wrapper preserves BonusType: "+str(id))
	_check(not C.find(pack,"Unit",int(kind.get("UnitID",0))).is_empty(),"source unit enum exists: "+str(id))
	_check(not C.find(pack,"BonusApplicationType",int(raw.get("BonusApplicationTypeID",-1))).is_empty(),"source application namespace exists: "+str(id))
	return value

func _links(table: String, field: String, id: int) -> Array:
	var out: Array = []
	for row: Dictionary in C.rows(pack,table):
		if int(row.get(field,-1)) == id: out.append(row)
	return out

func _spell_values(id: int) -> Dictionary:
	var values: Dictionary = {}
	for row: Dictionary in _links("SpellBonus","SpellClassID",id):
		var value: Dictionary = _typed_bonus(int(row.get("BonusID",0)))
		var name: String = str(value.get("type",{}).get("Name",""))
		_check(not values.has(name) and int(row.get("MinSpellLevel",-1)) == 0,"unconditional unique source spell selector: "+str(id)+":"+name)
		values[name] = value.get("raw",{}).get("Value",0)
	return values

func _invoke_rows() -> void:
	var slots: Dictionary = {}
	for candidate: Dictionary in C.rows(pack,"ItemInvokeReplacementEntityView"):
		var key: String = "%d|%d" % [int(candidate.ItemInvokeReplacementID),int(candidate.SlotNumber)]
		if not slots.has(key): slots[key] = []
		slots[key].append(candidate)
	var variable_groups: Dictionary = {}
	var fixed_groups: Dictionary = {}
	var variable_slots: int = 0
	for key: String in slots:
		var candidates: Array = slots[key]
		var total: int = 0
		for candidate: Dictionary in candidates:
			_check(float(candidate.get("Prob",-1)) == float(int(candidate.get("Prob",-1))) and int(candidate.get("Prob",-1)) >= 0,"original candidate weight is a nonnegative integer")
			total += int(candidate.get("Prob",0))
			var group_id: int = int(candidate.get("ItemInvokeReplacementBonusGroupID",0))
			_check(not C.find(pack,"ItemInvokeReplacementBonusGroup",group_id).is_empty(),"weighted candidate group exists")
			if candidates.size() > 1: variable_groups[str(group_id)] = true
			else: fixed_groups[str(group_id)] = true
		_check(total == 1000000,"original probability sum is unchanged: "+key)
		if candidates.size() > 1: variable_slots += 1
	_check(slots.size() == 78 and variable_slots == 36 and slots.size()-variable_slots == 42,"all 36 variable and 42 fixed original slots are audited")
	var damage_rows: int = 0
	var fixed_rows: int = 0
	var unreferenced_rows: int = 0
	var damage_spells: Dictionary = {}
	var debuff_spells: Dictionary = {}
	var debuff_options: Dictionary = {}
	var seen_rows: Dictionary = {}
	var option_types: Dictionary = {}
	for link: Dictionary in C.rows(pack,"ItemInvokeReplacementBonus"):
		var value: Dictionary = _typed_bonus(int(link.get("BonusID",0)))
		var raw: Dictionary = value.get("raw",{})
		var kind: Dictionary = value.get("type",{})
		_check(kind.get("Name") == "InvokeOption" and int(kind.get("UnitID",0)) == 3 and int(raw.get("BonusApplicationTypeID",0)) == 10,"every original replacement row retains typed invoke probability")
		_check(float(raw.get("Value",-1)) == float(int(raw.get("Value",-1))) and int(raw.get("Value",-1)) >= 0 and int(raw.get("Value",-1)) <= 1000000,"source proc probability remains in its original integer domain")
		var option: Dictionary = C.find(pack,"InvokeOption",int(raw.get("BonusApplicationTargetID",0)))
		var type_key: String = str(int(option.get("InvokeOptionTypeID",0)))
		option_types[type_key] = int(option_types.get(type_key,0))+1
		var group_key: String = str(int(link.get("ItemInvokeReplacementBonusGroupID",0)))
		if not variable_groups.has(group_key):
			if fixed_groups.has(group_key): fixed_rows += 1
			else: unreferenced_rows += 1
			continue
		_check(not seen_rows.has(str(int(link.ID))),"each original variable bonus row is checked once")
		seen_rows[str(int(link.ID))] = true
		var parsed: Dictionary = SetInvoke.spell_contract(pack,option,policy)
		if parsed.get("kind") == "damage":
			damage_rows += 1
			damage_spells[str(int(parsed.get("spell",{}).get("ID",0)))] = true
			continue
		coverage.debuff_rows += 1
		_check(reference.get("ItemInvokeReplacementBonus",{}).has(str(int(link.ID))),"debuff row is in the independent126-row source audit")
		_check(bool(parsed.get("ok",false)) and parsed.get("kind") == "debuff","set-invoke dispatch accepts original debuff row "+str(int(link.ID)))
		var debuff: Dictionary = Debuff.contract(pack,option,policy)
		_check(bool(debuff.get("ok",false)),"Debuff.contract succeeds for original row "+str(int(link.ID))+": "+str(debuff.get("error","")))
		if not debuff.get("ok",false): continue
		coverage.debuff_contracts_ok += 1
		var spell_id: int = int(debuff.get("spell",{}).get("ID",0))
		debuff_spells[str(spell_id)] = true
		debuff_options[str(int(option.ID))] = option
		_debuff_metadata(debuff,option)
	coverage.debuff_spells = debuff_spells.size()
	_check(int(coverage.debuff_rows) == 126 and int(coverage.debuff_contracts_ok) == 126 and debuff_spells.size() == 7,"all126 original debuff rows and all7 spells execute their contracts")
	_check(damage_rows == 144 and damage_spells.size() == 8 and seen_rows.size() == 270,"the separate144 fixed-damage rows and8 spells retain their contracts")
	_check(fixed_rows == 672 and unreferenced_rows == 32 and fixed_rows+unreferenced_rows == 704,"704 out-of-scope rows remain672 fixed-slot plus32 unreferenced rows")
	_check(int(option_types.get("1",0)) == 910 and int(option_types.get("38",0)) == 64,"all974 original spell/aura relationship rows remain unchanged")
	boundaries["invoke"] = {"variable_slots":variable_slots,"variable_rows":seen_rows.size(),"fixed_damage_rows":damage_rows,"fixed_damage_spells":damage_spells.size(),"fixed_slot_rows_outside_new_debuff_scope":fixed_rows,"unreferenced_rows":unreferenced_rows,"out_of_scope_total":fixed_rows+unreferenced_rows}
	for option: Dictionary in debuff_options.values(): _debuff_negative(option)

func _debuff_metadata(parsed: Dictionary, option: Dictionary) -> void:
	var spell: Dictionary = C.find(pack,"SpellClass",int(option.get("Param1",0)))
	var values: Dictionary = _spell_values(int(spell.ID))
	var buff: Dictionary = C.find(pack,"BuffClass",int(values.get("BuffClassID",0)))
	var group: Dictionary = C.find(pack,"BuffGroup",int(buff.get("BuffGroupID",0)))
	_check(_same(parsed.spell,spell) and _same(parsed.buff,buff) and _same(parsed.group,group),"returned spell, lifecycle, group overlap and priority metadata are exact original rows")
	_check(float(parsed.duration_min) == float(values.get("SpellDebuffMinDuration",-1)) and float(parsed.duration_max) == float(values.get("SpellDebuffMaxDuration",-1)),"returned duration endpoints equal the Seconds-typed source values")
	for link: Dictionary in _links("SpellBonus","SpellClassID",int(spell.ID)):
		var entry: Dictionary = C.bonus(pack,int(link.BonusID))
		if entry.get("type",{}).get("Name") in ["SpellDebuffMinDuration","SpellDebuffMaxDuration"]:
			_check(int(entry.type.get("UnitID",0)) == 17 and C.find(pack,"Unit",17).get("Name") == "Seconds","duration is explicitly Seconds, not CastDelay conversion")
	var context: Dictionary = {}
	for field: String in ["AlignmentTypeID","AlignmentChangeAmount","IsPierceCounterMagic","IsPierceCounterAssult"]: context[field] = spell.get(field,0)
	_check(_same(parsed.get("source_context",{}),context),"counter and alignment metadata remain visible under explicit PvE policy")
	var expected_status: Dictionary = {}
	var expected_numeric: Dictionary = {}
	var expected_healing: Dictionary = {}
	var control_fields: Dictionary = {}
	for link: Dictionary in _links("BuffBonus","BuffClassID",int(buff.ID)):
		var entry: Dictionary = _typed_bonus(int(link.BonusID))
		var raw: Dictionary = entry.raw
		var name: String = str(entry.type.Name)
		var value: float = float(raw.Value)
		match name:
			"MeleeDamage": expected_numeric.melee_damage = value
			"RangeDamage": expected_numeric.ranged_damage = value
			"MeleeHit": expected_numeric.melee_accuracy = value
			"ArmorClassBonus": expected_status.ac = -value
			"RangeEvasion": expected_status.er = value
			"MeleeEvasion": expected_status.dg = value
			"DamageReduction": expected_status.reduction = value
			"SpecialResistance":
				_check(int(entry.type.UnitID) == 3 and int(raw.BonusApplicationTypeID) == 2 and C.find(pack,"SpecialResistanceType",int(raw.BonusApplicationTargetID)).get("Name") == "Stun","effect resistance target6 is typed Stun, independent of petrification2")
				expected_status["status_resistance_"+str(int(raw.BonusApplicationTargetID))] = value/10000.0
			"HPPotionDecreasePercent": expected_healing.potion = int(raw.Value)
			"HPHealDecreasePercent": expected_healing.magic = int(raw.Value)
			"StatusEffectID": control_fields[name] = int(raw.Value)
			_:
				_check(name.begins_with("Cannot") and int(entry.type.UnitID) == 20 and value == 1.0,"every remaining original buff effect has an exact control contract")
				control_fields[name] = true
	_check(_same(parsed.status,expected_status) and _same(parsed.numeric,expected_numeric) and _same(parsed.healing,expected_healing),"every source buff scalar and recovery weight reaches the contract without dropped or duplicated fields")
	var source_control: int = int(values.get("SpecialResistanceTypeID",0))
	_check(int(parsed.source_control) == source_control,"control keeps its original resistance axis")
	if source_control != 0:
		var name: String = str(C.find(pack,"SpecialResistanceType",source_control).get("Name",""))
		_check(name in ["Lapidification","Hold"] and parsed.control == ("stun" if name == "Lapidification" else "hold"),"source petrification/hold and the explicit host mapping remain distinguishable")
		_check(control_fields.has("CannotMove") and control_fields.has("StatusEffectID"),"control lifecycle retains original movement and visual-state selectors")
	else: _check(str(parsed.control).is_empty() and control_fields.is_empty(),"scalar debuff does not invent a control state")
	_check(_links("BuffStack","BuffClassID",int(buff.ID)).is_empty(),"all7 original variable debuffs have no separate stack-bonus path")

func _negative_pack() -> Dictionary:
	# Copy on write below: original source arrays/wrappers are never changed.
	return {"source_sha256":pack.get("source_sha256"),"tables":pack.tables.duplicate(false),"bonuses":pack.bonuses.duplicate(false),"items":pack.get("items",{})}

func _change_row(negative: Dictionary, table: String, id: int, field: String, value: Variant) -> void:
	var changed: Array = C.rows(negative,table).duplicate(false)
	var found: bool = false
	for i: int in range(changed.size()):
		if int(changed[i].get("ID",0)) != id: continue
		var row: Dictionary = changed[i].duplicate(true)
		row[field] = value
		changed[i] = row
		found = true
		break
	_check(found,"negative case refers to an existing original "+table+":"+str(id))
	negative.tables[table] = changed
	negative.erase("_indexes")

func _remove_row(negative: Dictionary, table: String, id: int) -> void:
	var kept: Array = []
	var found: bool = false
	for row: Dictionary in C.rows(negative,table):
		if int(row.get("ID",0)) == id: found = true
		else: kept.append(row)
	_check(found,"removed negative definition was an actual original row")
	negative.tables[table] = kept
	negative.erase("_indexes")

func _change_bonus(negative: Dictionary, id: int, section: String, field: String, value: Variant) -> void:
	var entry: Dictionary = C.bonus(negative,id).duplicate(true)
	_check(not entry.is_empty(),"negative typed selector uses an existing original Bonus")
	if entry.is_empty(): return
	entry[section][field] = value
	negative.bonuses[str(id)] = entry

func _debuff_negative(option: Dictionary) -> void:
	var original: Dictionary = Debuff.contract(pack,option,policy)
	if not original.get("ok",false): return
	var spell_id: int = int(original.spell.ID)
	var buff_id: int = int(original.buff.ID)
	var group_id: int = int(original.group.ID)
	_negative(not Debuff.contract(base,option,policy).get("ok",false),"base-only pack cannot fabricate missing original buff definitions")
	for field: String in ["invoke_debuff_mode","invoke_debuff_stack_mode","invoke_debuff_hit_mode","invoke_debuff_world_rules"]:
		var wrong_policy: Dictionary = policy.duplicate(true)
		wrong_policy.erase(field)
		_negative(not Debuff.contract(pack,option,wrong_policy).get("ok",false),"original spell refuses missing host policy: "+field)
	for field: String in ["Param2","Param3","Param5","Param6","MaterialTypeID","MaterialAmount","WeaponGroupID","ShieldTypeID","SuccessedInvokeOptionID","TargetKind","SiegeTargetKind","IsAmmoAttack"]:
		var wrong_option: Dictionary = option.duplicate(true)
		wrong_option[field] = true if field == "IsAmmoAttack" else 1
		_negative(not Debuff.contract(pack,wrong_option,policy).get("ok",false),"original option refuses an added unsupported condition: "+field)
	for field: String in ["HPCost","MPCost","VPCost","SpellMaterialTypeID","SpellMaterialItemAmount","TargetAreaRadius","SpellCompositionNode","CopySpellClassID","MinCastRange","BackwardPathCount","TargetLimitCount","SiegeTargetKindID","HideCasterTime","IsAttackRange","IsChargeSpell","IsRequireSpellGroupMastery"]:
		var wrong: Dictionary = _negative_pack()
		_change_row(wrong,"SpellClass",spell_id,field,1)
		_negative(not Debuff.contract(wrong,option,policy).get("ok",false),"actual original spell refuses unsupported scope/cost/mode: "+field)
	for field: String in ["IsEraseOnAttack","IsEraseOnAttacked","IsEraseOnMove","IsEraseOnSpellCastAndShieldIt","IsEraseOnSkillCastAndShieldIt","IsEraseOnItemUse","IsEraseOnSpellAttacked","IsEraseOnSkillAttacked","IsEraseOnCast","IsEraseOnHealed","IsEraseOnTargetChanged","IsDecreaseStackOnTimeEnd","MaxHPPercent","EraseOnLevel","MaxStackCount","MPCostPercent","MinMPCost","IsEraseOnAttackedLimitations","IsAbsoluteTimeBuff","IsObtainItemBuff","IsOverlapByPlayer","IsImmuneToDead","IsBuffGroup"]:
		var wrong: Dictionary = _negative_pack()
		_change_row(wrong,"BuffClass",buff_id,field,1)
		_negative(not Debuff.contract(wrong,option,policy).get("ok",false),"actual source lifecycle refuses an unsupported condition: "+field)
	for field: String in ["IsAllowOverlap","IsEraseBySpellLevel"]:
		var wrong: Dictionary = _negative_pack()
		_change_row(wrong,"BuffGroup",group_id,field,true)
		_negative(not Debuff.contract(wrong,option,policy).get("ok",false),"actual source group refuses unsupported mode: "+field)
	var missing: Dictionary = _negative_pack()
	_remove_row(missing,"BuffGroup",group_id)
	_negative(not Debuff.contract(missing,option,policy).get("ok",false),"missing real group is not replaced with a fixture")
	missing = _negative_pack()
	_remove_row(missing,"BuffClass",buff_id)
	_negative(not Debuff.contract(missing,option,policy).get("ok",false),"missing real buff is not replaced with a fixture")
	for change: Array in [["SpellClass",spell_id,"TargettingTypeID",1],["SpellClass",spell_id,"TargetKindID",2],["SpellClass",spell_id,"TestSpell",true],["BuffClass",buff_id,"IsGood",true],["BuffClass",buff_id,"IsEraseOnTimeEnd",false]]:
		var wrong: Dictionary = _negative_pack()
		_change_row(wrong,str(change[0]),int(change[1]),str(change[2]),change[3])
		_negative(not Debuff.contract(wrong,option,policy).get("ok",false),"existing source definition refuses wrong target/test/lifecycle semantics")
	for table: String in ["SpellBonus","BuffBonus"]:
		var field: String = "SpellClassID" if table == "SpellBonus" else "BuffClassID"
		var owner: int = spell_id if table == "SpellBonus" else buff_id
		for link: Dictionary in _links(table,field,owner):
			var qualifiers: Array = ["MinSpellLevel"] if table == "SpellBonus" else ["CharacterLevel","CharacterClass","MinSpellLevel"]
			for qualifier: String in qualifiers:
				var conditional: Dictionary = _negative_pack()
				_change_row(conditional,table,int(link.ID),qualifier,1)
				_negative(not Debuff.contract(conditional,option,policy).get("ok",false),"every original effect rejects an added source qualifier: "+qualifier)
			var wrong: Dictionary = _negative_pack()
			var entry: Dictionary = C.bonus(pack,int(link.BonusID))
			_change_bonus(wrong,int(link.BonusID),"type","UnitID",3 if int(entry.type.UnitID) != 3 else 1)
			_negative(not Debuff.contract(wrong,option,policy).get("ok",false),"every original effect rejects an incompatible unit")
			wrong = _negative_pack()
			_change_bonus(wrong,int(link.BonusID),"raw","BonusApplicationTargetID",2 if int(entry.raw.BonusApplicationTargetID) != 2 else 6)
			_negative(not Debuff.contract(wrong,option,policy).get("ok",false),"every original effect rejects a different application target")
			if table == "SpellBonus":
				var name: String = str(entry.type.Name)
				if name == "SpellDebuffMinDuration" or name == "SpellDebuffMaxDuration":
					wrong = _negative_pack()
					_change_bonus(wrong,int(link.BonusID),"raw","Value",0 if name == "SpellDebuffMinDuration" else float(original.duration_min)-1.0)
					_negative(not Debuff.contract(wrong,option,policy).get("ok",false),"original duration refuses zero or reversed endpoints")
	if float(original.duration_min) != float(original.duration_max):
		var wrong_policy: Dictionary = policy.duplicate(true)
		wrong_policy.erase("invoke_debuff_duration_mode")
		_negative(not Debuff.contract(pack,option,wrong_policy).get("ok",false),"original variable duration requires explicit distribution policy")
	if int(original.source_control) != 0:
		var wrong_policy: Dictionary = policy.duplicate(true)
		wrong_policy.erase("invoke_debuff_control_map")
		_negative(not Debuff.contract(pack,option,wrong_policy).get("ok",false),"original resistance axis requires explicit host control mapping")

func _set_rows() -> void:
	var contracts: Array = SetEffects.contracts(pack)
	var sets: Dictionary = {}
	var actual_links: Dictionary = {}
	_check(contracts.size() == 22,"all22 special set links have contracts, including the inactive test definition")
	for parsed: Dictionary in contracts:
		coverage.set_links += 1
		_check(bool(parsed.get("ok",false)),"special set contract succeeds: "+str(parsed.get("bonus_id",0))+" "+str(parsed.get("error","")))
		if not parsed.get("ok",false): continue
		coverage.set_contracts_ok += 1
		var link: Dictionary = parsed.get("link",{})
		var id: int = int(parsed.get("bonus_id",0))
		actual_links[str(int(link.get("ID",0)))] = true
		sets[str(int(parsed.set_id))] = true
		_check(_same(link,reference.get("ItemSetBonus",{}).get(str(int(link.get("ID",0))),{})),"special contract retains exact set/threshold/source bonus link")
		var entry: Dictionary = _typed_bonus(id)
		_check(_same(parsed.get("raw",{}),entry.raw),"special contract retains original typed value and target")
		_set_metadata(parsed,entry)
		var wrong: Dictionary = _negative_pack()
		_change_bonus(wrong,id,"type","UnitID",1 if int(entry.type.UnitID) != 1 else 3)
		_negative(not SetEffects.contract(wrong,link).get("ok",false),"each original special set link rejects an incompatible unit")
	coverage.set_definitions = sets.size()
	_check(int(coverage.set_contracts_ok) == 22 and sets.size() == 12,"all22 contracts and all12 original set definitions are covered")
	_check(actual_links.size() == reference.get("ItemSetBonus",{}).size(),"no audited special source link was omitted")
	var test_definition: Dictionary = C.find(pack,"ItemSet",10451)
	_check(not test_definition.is_empty() and str(test_definition.get("Name","")).contains("[테스트]"),"source test-set metadata is retained")
	var test_targets: Array = _source_targets(10451)
	_check(not test_targets.is_empty(),"test-set exclusion uses actual original members, not substitute IDs")
	var resolved: Dictionary = SetEffects.resolve(pack,test_targets,policy)
	_negative(not resolved.get("set_ids",[]).has(10451),"test definition remains inactive even with all actual source members")
	var test_links: Array = _links("ItemSetBonus","ItemSetID",10451)
	for values: String in ["records","invokes","intervals","buffs","drains"]:
		for active: Dictionary in resolved.get(values,[]):
			_negative(int(active.get("set_id",active.get("equipment523_set_id",0))) != 10451,"test set cannot reach active special consumers")
	boundaries["sets"] = {"structural_links":contracts.size(),"structural_sets":sets.size(),"test_set_id":10451,"test_source_bonus_links":test_links.size(),"normal_acquisition_verified":false}
	boundaries.sets.merge(_set_source_eligibility(reference.get("ItemSetBonus",{}).values()),true)
	var honor_targets: Array = _source_targets(10401)
	var runtime = SetEffects.new()
	runtime.sync(pack,honor_targets,policy,{"zone_allowed":false})
	_negative(runtime.markers.is_empty(),"original honor marker remains inactive without source siege-zone eligibility")
	runtime.sync(pack,honor_targets,policy,{"zone_allowed":true})
	_check(runtime.markers.has("67271") and int(runtime.markers.get("67271",{}).get("numeric_effects",-1)) == 0,"eligible source honor marker contributes no fabricated numeric effects")
	runtime.clear()
	_set_counting_negative()

func _set_source_eligibility(special_links: Array) -> Dictionary:
	# Reporting only. Source test flags and distinct non-test original membership
	# determine reachability; these counts do not prove acquisition or ownership.
	var details: Dictionary = {}
	var eligible_links: int = 0
	var ineligible_links: int = 0
	var test_special_links: int = 0
	for link: Dictionary in special_links:
		var set_id: int = int(link.get("ItemSetID",0))
		var key: String = str(set_id)
		if not details.has(key):
			var definition: Dictionary = C.find(pack,"ItemSet",set_id)
			var members: Dictionary = {}
			var non_test_members: Dictionary = {}
			var missing_members: Dictionary = {}
			for member: Dictionary in _links("ItemForItemSet","ItemSetID",set_id):
				var source: int = int(member.get("ItemClassID",0))
				members[str(source)] = true
				var item: Dictionary = C.item(pack,source)
				if item.is_empty(): missing_members[str(source)] = true
				elif not bool(item.get("raw",{}).get("TestItem",false)): non_test_members[str(source)] = true
			var test_definition: bool = bool(definition.get("IsTest",false)) or str(definition.get("Name","")).contains("[테스트]")
			details[key] = {"set_id":set_id,"definition_present":not definition.is_empty(),"test_definition":test_definition,"source_member_count":members.size(),"non_test_source_member_count":non_test_members.size(),"missing_source_member_count":missing_members.size(),"eligible_special_links":0,"ineligible_special_links":0}
		var detail: Dictionary = details[key]
		var threshold: int = int(link.get("CompletionDegree",0))
		var eligible: bool = bool(detail.definition_present) and not bool(detail.test_definition) and threshold > 0 and int(detail.non_test_source_member_count) >= threshold
		if eligible:
			eligible_links += 1
			detail.eligible_special_links += 1
		else:
			ineligible_links += 1
			detail.ineligible_special_links += 1
		if set_id == 10451: test_special_links += 1
	var eligible_sets: int = 0
	var ineligible_sets: int = 0
	for detail: Dictionary in details.values():
		if int(detail.eligible_special_links) > 0: eligible_sets += 1
		else: ineligible_sets += 1
	return {"eligible_sets":eligible_sets,"eligible_special_links":eligible_links,"ineligible_sets":ineligible_sets,"ineligible_special_links":ineligible_links,"test_special_contract_links":test_special_links,"source_eligibility_details":details.values(),"eligibility_basis":"original definition test flags and distinct non-test source members satisfying each special threshold; no acquisition or ownership claim"}

func _set_metadata(parsed: Dictionary, entry: Dictionary) -> void:
	var raw: Dictionary = entry.raw
	var name: String = str(entry.type.Name)
	match str(parsed.kind):
		"stat":
			var key: String = {"CastSpeedBonus":"equipment523_set_cast_speed_pct","ElementalResistance":"element_resist_all","HitSpecialResistance":"fear_accuracy"}.get(name,"")
			_check(not key.is_empty() and parsed.record.size() == 1 and float(parsed.record.get(key,-1)) == float(raw.Value)/10000.0,"typed set percentage retains its exact channel and scaling")
			if name == "ElementalResistance": _check(C.find(pack,"ElementalType",int(raw.BonusApplicationTargetID)).get("Name") == "All","resistance target5 is All, not one element")
			if name == "HitSpecialResistance": _check(C.find(pack,"SpecialResistanceType",int(raw.BonusApplicationTargetID)).get("Name") == "Fear","special accuracy target8 remains Fear")
		"drain": _check(int(parsed.value) == int(raw.Value) and parsed.resource == ("hp" if name == "AttackDrainHP" else "mp"),"drain amount and resource stay source values before host policy")
		"reveal": _check(bool(parsed.enabled) == (int(raw.Value) == 1) and parsed.flag == SetEffects.FLAGS.get(name),"source boolean reveal capability is exact")
		"description":
			_check(int(parsed.description_id) == int(raw.BonusApplicationTargetID),"FixedDesc is prose only, never an additional invoke")
			var caption: Dictionary = C.find(pack,"DescData_Korean",int(parsed.description_id))
			_check(not str(caption.get("Description","")).is_empty() and parsed.description == caption.Description,"the exact referenced source caption is available to the UI")
			var displayed: int = 0
			for detail: Dictionary in SetInvoke.equipped(pack,_source_targets(int(parsed.set_id)),policy).get("details",[]):
				if int(detail.get("set_id",0)) != int(parsed.set_id): continue
				for text: Dictionary in detail.get("effects",[]):
					if text.get("description") == caption.get("Description"): displayed += 1
			_check(displayed == 1,"the source caption is shown once without another proc")
		"marker":
			var buff: Dictionary = C.find(pack,"BuffClass",int(raw.Value))
			_check(int(buff.get("ID",0)) == 67271 and _same(parsed.buff,buff),"honor set marker is the exact original Buff67271")
			_check(_links("BuffBonus","BuffClassID",67271).is_empty() and _links("BuffStack","BuffClassID",67271).is_empty(),"source marker has no invented numeric or stack effects")
			_check(int(C.find(pack,"ItemSet",int(parsed.set_id)).get("BuffClassID",0)) == int(raw.Value),"direct set marker and set bonus refer to one buff without doubling")
			_check(C.find(pack,"BuffGroup",int(buff.get("BuffGroupID",0))).get("Name") == "Buff_Normal","empty marker still retains its exact source group metadata")
		"invoke":
			var option: Dictionary = C.find(pack,"InvokeOption",int(raw.BonusApplicationTargetID))
			var spell: Dictionary = C.find(pack,"SpellClass",int(option.Param1))
			var values: Dictionary = _spell_values(int(spell.ID))
			var next_spell: Dictionary = C.find(pack,"SpellClass",int(values.get("NextSpellClassID",0)))
			var next_values: Dictionary = _spell_values(int(next_spell.get("ID",0)))
			_check(_same(parsed.option,option) and _same(parsed.spell,spell) and _same(parsed.next_spell,next_spell),"Yahi invoke follows the exact typed next-spell graph")
			_check(C.find(pack,"TargetKind",int(spell.TargetKindID)).get("Name") == "PCButMe" and bool(option.Param4),"Yahi retains its original PC target and main-target-only restriction")
			_check(int(parsed.probability) == int(raw.Value) and int(parsed.duration) == int(values.get("SpellDebuffMinDuration",0)) and int(parsed.duration) == int(values.get("SpellDebuffMaxDuration",0)) and int(parsed.duration) == int(next_values.get("SpellBuffDuration",0)),"Yahi proc probability and both Seconds-typed durations are unchanged")
			var total: int = 0
			for stack: Dictionary in _links("BuffStack","BuffClassID",int(parsed.buff.ID)):
				_check(int(stack.StackCount) == 1 and not bool(stack.isAdditionalStack),"Yahi exact original stack condition is retained")
				for link: Dictionary in _links("BuffStackBonus","BuffStackID",int(stack.ID)):
					var value: Dictionary = _typed_bonus(int(link.BonusID))
					_check(value.type.Name == "PVPDamageReduction" and int(value.type.UnitID) == 1,"Yahi stack reduction stays a typed PvP value")
					total += int(value.raw.Value)
			_check(int(parsed.reduction) == total and parsed.stack_rows.size() == 1,"Yahi does not drop the separate stack-bonus path")
			_negative(not SetEffects.contract(base,parsed.link).get("ok",false),"base-only Yahi graph cannot be replaced with a positive fixture")
			var wrong: Dictionary = _negative_pack()
			_remove_row(wrong,"SpellClass",int(next_spell.ID))
			_negative(not SetEffects.contract(wrong,parsed.link).get("ok",false),"missing original next spell rejects Yahi")
		"interval": _interval_metadata(parsed)
		_: _check(false,"unexpected special contract kind: "+str(parsed.kind))

func _interval_metadata(parsed: Dictionary) -> void:
	var interval: Dictionary = parsed.interval
	var category_id: int = int(parsed.raw.Value)
	_check(int(interval.category.ID) == category_id and int(interval.row.IntervalBonusCategory) == category_id,"selector Value is IntervalBonusCategoryID, not IntervalBonus rowID")
	_check(int(interval.row.ID) != category_id and _same(interval.row,C.find(pack,"IntervalBonus",int(interval.row.ID))),"the different interval rowID is joined through its category field")
	_check(_same(interval.category,C.find(pack,"IntervalBonusCategory",category_id)),"HP interval retains exact category definition")
	_check(float(interval.low) == float(interval.row.Low) and float(interval.high) == float(interval.row.High),"HP endpoints are source values; boundary inclusion is host policy")
	var invoke_value: Dictionary = _typed_bonus(int(interval.row.BonusID))
	var option: Dictionary = C.find(pack,"InvokeOption",int(invoke_value.raw.BonusApplicationTargetID))
	var kind: Dictionary = C.find(pack,"InvokeOptionType",int(option.InvokeOptionTypeID))
	_check(_same(interval.option,option) and int(option.InvokeOptionTypeID) == 2 and bool(kind.IsDefence),"guard follows a typed Defence_Spell, not attack spell dispatch")
	_check(int(option.Param3) == 1 and str(kind.get("Param3Description","")).contains("PC") and int(kind.get("Param3Unit",-1)) == 0,"PC-attack-only flag is Param3's inline source contract, not TargetKind inference")
	var spell: Dictionary = C.find(pack,"SpellClass",int(option.Param1))
	var values: Dictionary = _spell_values(int(spell.ID))
	_check(_same(interval.spell,spell) and int(interval.duration) == int(values.get("SpellBuffDuration",0)),"guard duration is exact Seconds-typed source value")
	_check(not C.find(pack,"SpellCastGroup",int(spell.CastGroupID)).is_empty(),"guard keeps original CastGroup metadata without assuming delay units")
	var source_hits: int = 0
	var source_group: int = 0
	for link: Dictionary in _links("BuffBonus","BuffClassID",int(interval.buff.ID)):
		var value: Dictionary = _typed_bonus(int(link.BonusID))
		if value.type.Name == "CounterAssult":
			source_hits = int(value.raw.Value)
			source_group = int(value.raw.BonusApplicationTargetID)
			_check(int(value.type.UnitID) == 1 and int(value.raw.BonusApplicationTypeID) == 381,"guard counter uses UniversalGroup, not a resistance or probability namespace")
	_check(int(interval.hits) == source_hits,"guard charge count is the exact source amount")
	var attacks: Array = []
	for member: Dictionary in _links("UniversalGroupSet","GroupID",source_group):
		_check(int(member.UnitID) == 10431 and C.find(pack,"Unit",10431).get("Name") == "AttackTypeID","guard group members have AttackTypeID units")
		_check(not C.find(pack,"AttackType",int(member.Value)).is_empty(),"guard attack type is a real source enum")
		attacks.append(int(member.Value))
	var returned: Array = interval.attack_types.duplicate()
	attacks.sort()
	returned.sort()
	_check(_same(returned,attacks) and not attacks.has(3),"guard retains all four physical attack axes and excludes magic3")
	_negative(not SetEffects.contract(base,parsed.link).get("ok",false),"base-only missing guard graph is rejected")
	var wrong: Dictionary = _negative_pack()
	_change_row(wrong,"InvokeOption",int(option.ID),"Param3",0)
	_negative(not SetEffects.contract(wrong,parsed.link).get("ok",false),"changing actual PC-only guard condition is rejected")
	wrong = _negative_pack()
	var member: Dictionary = _links("UniversalGroupSet","GroupID",source_group)[0]
	_change_row(wrong,"UniversalGroupSet",int(member.ID),"UnitID",1)
	_negative(not SetEffects.contract(wrong,parsed.link).get("ok",false),"guard refuses an incorrectly typed existing group member")
	boundaries["guard_delay"] = "CastDelay raw value and source CastGroup are preserved; seconds conversion and highest-stage selection remain explicit host policy"

func _source_targets(set_id: int) -> Array:
	var out: Array = []
	for member: Dictionary in _links("ItemForItemSet","ItemSetID",set_id):
		var source: int = int(member.ItemClassID)
		_check(not C.item(pack,source).is_empty(),"set counting uses an existing exact original item: "+str(source))
		if C.item(pack,source).is_empty(): continue
		out.append({"source_id":source,"instance_id":"source-contract:%d:%d" % [set_id,source],"equipped":true})
	return out

func _set_counting_negative() -> void:
	# Use an actual non-test multi-piece set from the independent audit. Missing
	# membership is a failure, never a reason to manufacture a replacement item.
	for id: String in reference.get("ItemSet",{}):
		var definition: Dictionary = C.find(pack,"ItemSet",int(id))
		if str(definition.get("Name","")).contains("[테스트]"): continue
		var threshold: int = 2147483647
		for link: Dictionary in _links("ItemSetBonus","ItemSetID",int(id)): threshold = mini(threshold,int(link.CompletionDegree))
		var targets: Array = _source_targets(int(id))
		if threshold <= 1 or targets.size() < threshold: continue
		var complete: Dictionary = SetEffects.resolve(pack,targets,policy)
		if not complete.get("set_ids",[]).has(int(id)): continue
		var duplicates: Array = []
		var repeated_physical: Array = []
		var unequipped: Array = []
		for i: int in range(targets.size()):
			var same_source: Dictionary = targets[0].duplicate(true)
			same_source.instance_id = str(same_source.instance_id)+":"+str(i)
			duplicates.append(same_source)
			var same_physical: Dictionary = targets[i].duplicate(true)
			same_physical.instance_id = str(targets[0].instance_id)
			repeated_physical.append(same_physical)
			var inactive: Dictionary = targets[i].duplicate(true)
			inactive.equipped = false
			unequipped.append(inactive)
		_negative(not SetEffects.resolve(pack,duplicates,policy).get("set_ids",[]).has(int(id)),"multiple physical copies of one original item do not complete a multi-piece set")
		_negative(not SetEffects.resolve(pack,repeated_physical,policy).get("set_ids",[]).has(int(id)),"one physical identity cannot count as multiple original items")
		_negative(not SetEffects.resolve(pack,unequipped,policy).get("set_ids",[]).has(int(id)),"owned but unequipped original items do not activate the set")
		boundaries["set_counting_original_set_id"] = int(id)
		return
	_check(false,"an audited actual non-test multi-piece set must be available for counting conditions")
