extends RefCounted
## Base-item InvokeOption rows of current 523 weapons (ItemBonus, application
## type InvokeOption, target = InvokeOption ID) compiled into the existing
## `source_invoke_options` that world._roll_weapon_damage (claw / dual blade)
## and patch523_weapon_bleed (rifle bleed) already consume.
##
## Same contract as the former published compiler
## (tools/monsters/patch523_item_definitions.py `_invoke_options` /
## `_source_bleed`), now read from the current original tables:
## - InvokeOptionType 9 Attack_AddCriticalProbability -> normal_attack_additional_critical
## - InvokeOptionType 6 Attack_WeaponDamageScale (Param1 = scale, millionths) -> normal_attack_weapon_scale
## - InvokeOptionType 1 Attack_Spell, option 611 -> SpellClass 17564 [총사] 출혈 -> normal_attack_source_bleed
## Probability is the bonus Value: unit Percentage, UIUnit Denominator 10000
## (180000 -> 18%), i.e. millionths of one attack.
## Every other invoke row is kept as a blocked entry with its reason.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPORTED := {"9:Attack_AddCriticalProbability":"normal_attack_additional_critical","6:Attack_WeaponDamageScale":"normal_attack_weapon_scale"}
const CONDITIONS: Array[String] = ["AttackTypeID","MaterialTypeID","MaterialAmount","WeaponGroupID","Param1","Param2","Param3","Param4","Param5","Param6","ShieldTypeID","SuccessedInvokeOptionID","IsAmmoAttack","TargetKind","SiegeTargetKind"]
const BUFF_ACTIONS: Array[String] = ["IsEraseOnAttack","IsEraseOnAttacked","IsEraseOnMove","IsEraseOnSpellCastAndShieldIt","IsEraseOnSkillCastAndShieldIt","IsEraseOnItemUse","IsEraseOnSpellAttacked","IsEraseOnSkillAttacked","IsEraseOnCast","IsEraseOnHealed","IsEraseOnTargetChanged","IsEraseOnAttackedLimitations"]

static func _int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

## Table JSON numbers are floats; a set flag or a non-zero number is "on".
static func _on(value: Variant) -> bool:
	if typeof(value)==TYPE_BOOL: return bool(value)
	if typeof(value) in [TYPE_INT,TYPE_FLOAT]: return float(value)!=0.0
	return value!=null and str(value)!=""

static func _effect_rows(table: String, key: String, id: int) -> Array:
	var result: Array = []
	for link: Dictionary in SOURCE.related(table,key,id):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		var unit: Dictionary = SOURCE.row("Unit",int(type.get("UnitID",-1)))
		var row: Dictionary = link.duplicate(true)
		row["bonus"] = bonus; row["bonus_type"] = type; row["unit"] = unit
		result.append(row)
	return result

## rows: ItemBonus links with "bonus", "bonus_type", "unit" (as the current
## definition reference carries them). record: the projected native record.
static func compile(rows: Array, record: Dictionary) -> Array:
	var result: Array = []
	var equipment: bool = str(record.get("slot","")) not in ["","currency","consumable","material"]
	for row: Variant in rows:
		if not row is Dictionary or str(row.get("bonus_type",{}).get("Name",""))!="InvokeOption": continue
		var bonus: Dictionary = row.get("bonus",{})
		var application: Dictionary = SOURCE.row("BonusApplicationType",int(bonus.get("BonusApplicationTypeID",-1)))
		if application.get("Name")!="InvokeOption":
			result.append({"item_bonus":row.duplicate(true),"application_type":application,"activation_status":"blocked","blocked_reasons":["unsupported_invoke_application_type"],"kind":"unsupported_source_invoke"})
			continue
		var option: Dictionary = SOURCE.row("InvokeOption",int(bonus.get("BonusApplicationTargetID",-1)))
		var kind: Dictionary = SOURCE.row("InvokeOptionType",int(option.get("InvokeOptionTypeID",-1)))
		var ui_units: Array[Dictionary] = SOURCE.related("UIUnit","UnitID",int(row.get("unit",{}).get("ID",-1)))
		var reasons: Array = []
		if option.is_empty() or kind.is_empty(): reasons.append("source_invoke_option_row_missing")
		var supported: String = str(SUPPORTED.get(str(int(kind.get("ID",-1)))+":"+str(kind.get("Name","")),""))
		var is_bleed: bool = int(kind.get("ID",-1))==1 and kind.get("Name")=="Attack_Spell" and int(option.get("ID",-1))==611 and int(option.get("Param1",-1))==17564
		if is_bleed:
			supported = "normal_attack_source_bleed"
			if int(kind.get("Param1Unit",-1))!=12 or SOURCE.row("Unit",12).get("Name")!="SpellClassID": reasons.append("unsupported_source_bleed_spell_reference_unit")
		if supported.is_empty(): reasons.append("source_invoke_effect_not_implemented")
		var is_scale: bool = supported=="normal_attack_weapon_scale"
		if is_scale and (not _int(option.get("Param1")) or int(option.Param1)<=0): reasons.append("unsupported_invoke_weapon_scale")
		if not equipment or str(record.get("slot",""))!="weapon": reasons.append("source_invoke_requires_weapon")
		var value: Variant = bonus.get("Value")
		if row.get("IsPossession")!=false or row.get("unit",{}).get("Name")!="Percentage" or not _int(value) or int(value)<0 or int(value)>1000000 or ui_units.size()!=1 or not _int(ui_units[0].get("Denominator")) or int(ui_units[0].Denominator)!=10000:
			reasons.append("unsupported_invoke_probability_units")
		if kind.get("IsDefence")!=false or option.get("BySpellAttack")!=false: reasons.append("unsupported_invoke_attack_trigger")
		for name: String in CONDITIONS:
			if name=="Param1" and (is_scale or is_bleed): continue
			if _on(option.get(name,0)): reasons.append("unsupported_invoke_condition:"+name)
		var compiled: Dictionary = {"item_bonus":row.duplicate(true),"application_type":application,"invoke_option":option,"invoke_option_type":kind,
			"ui_unit":ui_units[0] if ui_units.size()==1 else {},"probability_raw":int(value) if _int(value) else 0,"probability_denominator":1000000}
		if is_scale:
			# Source type/Param1 establish the ratio. The weapon-component
			# boundary is the existing configurable TWILIGHT setting.
			compiled.merge({"scale_raw":int(option.Param1) if _int(option.get("Param1")) else 0,"scale_denominator":1000000,
				"component_boundary_origin":"local_estimate_based_on_primary_experiment","configuration_key":"patch523_weapon_double_scope"},true)
		if is_bleed:
			var bleed: Array = _bleed(option)
			compiled.merge(bleed[0],true)
			reasons.append_array(bleed[1])
		var unique: Array = []
		for reason: Variant in reasons:
			if not unique.has(reason): unique.append(reason)
		compiled["blocked_reasons"] = unique
		compiled["activation_status"] = "blocked" if not unique.is_empty() else "unrestricted"
		compiled["kind"] = supported if unique.is_empty() else "unsupported_source_invoke"
		result.append(compiled)
	return result

## The exact 17564 -> BuffClass 51984 chain. Tick interval and the
## MaxHPPercent meaning stay the existing TWILIGHT settings
## (patch523_bleed_tick_interval_seconds / patch523_bleed_max_hp_rule).
static func _bleed(option: Dictionary) -> Array:
	var reasons: Array = []
	var spell: Dictionary = SOURCE.row("SpellClass",int(option.get("Param1",-1)))
	var spell_effects: Array = _effect_rows("SpellBonus","SpellClassID",int(spell.get("ID",-1)))
	var expected_spell: Dictionary = {"SpecialResistanceTypeID":["SpecialResistanceTypeID",22],"SpellDebuffMaxDuration":["Seconds",3],"SpellDebuffMinDuration":["Seconds",3],"BuffClassID":["BuffClassID",51984]}
	var spell_values: Dictionary = {}
	for row: Dictionary in spell_effects:
		var name: String = str(row.bonus_type.get("Name","")); var b: Dictionary = row.bonus
		if spell_values.has(name) or not expected_spell.has(name) or not _int(row.get("MinSpellLevel")) or int(row.MinSpellLevel)!=0 or int(b.get("BonusApplicationTypeID",-1))!=0 or int(b.get("BonusApplicationTargetID",-1))!=0 or not _int(b.get("Value")) or row.unit.get("Name")!=expected_spell[name][0] or int(b.Value)!=int(expected_spell[name][1]):
			reasons.append("unsupported_source_bleed_spell_effect:"+name)
		spell_values[name] = int(b.get("Value",0)) if _int(b.get("Value")) else 0
	if spell_values.size()!=expected_spell.size(): reasons.append("incomplete_source_bleed_spell_effects")
	var buff: Dictionary = SOURCE.row("BuffClass",51984)
	var group: Dictionary = SOURCE.row("BuffGroup",int(buff.get("BuffGroupID",-1)))
	var buff_effects: Array = _effect_rows("BuffBonus","BuffClassID",51984)
	var expected_buff: Dictionary = {"PoisonDamageDiceSpotCount":["Value",1],"PoisonDamageDiceNumber":["Value",10],"PoisonDamageMotion":["TrueFalse",1],"StatusEffectID":["StatusEffectID",16372]}
	var values: Dictionary = {}
	for row: Dictionary in buff_effects:
		var name: String = str(row.bonus_type.get("Name","")); var b: Dictionary = row.bonus
		var conditional: bool = false
		for key: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
			if not _int(row.get(key)) or int(row[key])!=0: conditional = true
		if values.has(name) or not expected_buff.has(name) or conditional or int(b.get("BonusApplicationTypeID",-1))!=0 or int(b.get("BonusApplicationTargetID",-1))!=0 or not _int(b.get("Value")) or row.unit.get("Name")!=expected_buff[name][0] or int(b.Value)!=int(expected_buff[name][1]):
			reasons.append("unsupported_source_bleed_buff_effect:"+name)
		values[name] = int(b.get("Value",0)) if _int(b.get("Value")) else 0
	if values.size()!=expected_buff.size(): reasons.append("incomplete_source_bleed_buff_effects")
	var material: Dictionary = SOURCE.row("SpellMaterialType",int(spell.get("SpellMaterialTypeID",-1)))
	var targetting: Dictionary = SOURCE.row("TargettingType",int(spell.get("TargettingTypeID",-1)))
	var target: Dictionary = SOURCE.row("TargetKind",int(spell.get("TargetKindID",-1)))
	var category: Dictionary = SOURCE.row("SpellCategory",int(spell.get("SpellCategoryID",-1)))
	var resistance: Dictionary = SOURCE.row("SpecialResistanceType",22)
	if int(spell.get("ID",-1))!=17564 or int(material.get("ID",-1))!=0 or material.get("Name")!="None" or int(targetting.get("ID",-1))!=2 or targetting.get("Name")!="SingleObject" or int(target.get("ID",-1))!=2 or target.get("Name")!="All" or int(category.get("ID",-1))!=8 or category.get("Name")!="SpellDebuff" or int(resistance.get("ID",-1))!=22 or resistance.get("Name")!="Poison":
		reasons.append("unsupported_source_bleed_spell_kind")
	if spell.get("TestSpell")!=false: reasons.append("source_bleed_test_spell")
	for name: String in ["HPCost","MPCost","VPCost","SpellMaterialItemAmount","CastDelay","TargetAreaRadius","SiegeTargetKindID","SpellCompositionNode","MinCastRange","TargetLimitCount","CopySpellClassID","IsChargeSpell","IsRequireSpellGroupMastery","SpellGroupLevel","BackwardPathCount"]:
		if _on(spell.get(name,0)): reasons.append("unsupported_source_bleed_spell_rule:"+name)
	if int(buff.get("ID",-1))!=51984 or int(group.get("ID",-1))!=564 or buff.get("IsGood")!=false or buff.get("IsBuffGroup")!=false or not _int(buff.get("BuffGroupPriority")) or int(buff.BuffGroupPriority)!=0 or not _int(buff.get("MaxHPPercent")) or int(buff.MaxHPPercent)!=50 or buff.get("IsEraseOnTimeEnd")!=true or buff.get("IsImmuneToDead")!=false or buff.get("IsImmuneToCancellation")!=false or group.get("IsAllowOverlap")!=false or group.get("IsAllowPriority")!=false or group.get("IsEraseBySpellLevel")!=false:
		reasons.append("unsupported_source_bleed_lifecycle")
	for name: String in BUFF_ACTIONS+["MaxStackCount","EraseOnLevel","IsAbsoluteTimeBuff","MPCostPercent","MinMPCost","IsOverlapByPlayer","IsDecreaseStackOnTimeEnd","IsObtainItemBuff"]:
		if _on(buff.get(name,0)): reasons.append("unsupported_source_bleed_buff_rule:"+name)
	return [{"spell_class_id":int(spell.get("ID",0)),"buff_class_id":int(buff.get("ID",0)),
		"duration_seconds":int(spell_values.get("SpellDebuffMinDuration",0)),
		"damage_dice_number":int(values.get("PoisonDamageDiceNumber",0)),"damage_dice_spot_count":int(values.get("PoisonDamageDiceSpotCount",0)),
		"source_max_hp_percent":int(buff.get("MaxHPPercent",0)),"source_spell_class":spell,
		"local_interpretation":{"origin":"local_estimate_after_source_and_public_research","tick_interval_seconds":0.75,"tick_interval_origin":"existing_host_default",
			"tick_interval_configuration_key":"patch523_bleed_tick_interval_seconds","max_hp_percent_semantics":"total_bleed_damage_cap",
			"max_hp_percent_origin":"local_estimate","max_hp_percent_configuration_key":"patch523_bleed_max_hp_rule"}},reasons]
