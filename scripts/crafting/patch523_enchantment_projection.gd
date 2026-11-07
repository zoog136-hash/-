extends RefCounted
## Data projection port of tools/equipment/patch523_enhancement.py.
## This builds the existing equipment_runtime model, never an execution plan.
const POLICY_PATH := "res://data/crafting/patch523_enhancement_policy.json"
const FIELDS := {
	"WeaponDamageBonus":["damage",null,1],"WeaponHitBonus":["accuracy",null,1],
	"ArmorClass":["defense",null,1],"HPPlus":["hp","hpFlat",1],
	"MPPlus":["mp","mpFlat",1],"CarryPlus":["capacity","weightBonus",100],
	"MagicResist":["mr","mr",1],"SpellPower":["sp","sp",1],
	"MeleeDamage":["melee_damage","meleeDamage",1],"RangeDamage":["ranged_damage","rangedDamage",1],
	"MeleeHit":["melee_accuracy","meleeHit",1],"RangeHit":["ranged_accuracy","rangedHit",1],
	"MagicHit":["magic_accuracy","magicHit",1],"DamageReduction":["reduction","damage_reduction",1],
	"HPPotionIncreaseStatic":["potion_heal_flat","potionHealFlat",1],
	"HPPotionIncreasePercent":["potion_heal_pct","potionHealPct",10000],
	"ExperienceAdditionPercent":["xp_pct","xp",10000],
	"EinasadSavingPercent":["ain_saving_pct","blessing_consumption_reduction_pct",10000],
	"PotionConsumeDelayDecreasePercent":["potion_cooldown_pct","potionCooldownPct",10000],
	"_stun":["stun_resistance","stun_resistance",10000]}
const EXTRA := {
	"IgnoreDamageReductionPercent":["source_equipment_ignore_reduction_pct",10000],
	"IgnoreMeleeDamageReductionPercent":["source_equipment_ignore_melee_reduction_pct",10000],
	"IgnoreRangeDamageReductionPercent":["source_equipment_ignore_ranged_reduction_pct",10000],
	"IgnoreMagicDamageReductionPercent":["source_equipment_ignore_magic_reduction_pct",10000],
	"ElementalCriticalResistance":["equipment523_element_crit_resist_pct",10000],
	"Strength":["strFlat",1],"Dexterity":["dexFlat",1],"Intelligence":["intFlat",1],
	"RangeEvasion":["er",1],"MeleeEvasion":["dg",1],"RegenMP":["mpRecoveryTick",1],
	"MagicDamage":["magicDamage",1],"AttackSpeedBonus":["attackSpeed",10000],
	"MoveSpeedBonus":["speedBonusPct",10000],
	"PVEDamageReduction":["pve_damage_reduction",1],"PVPDamageReduction":["pve_damage_reduction",1],
	"PVEDamageReductionPercent":["pve_damage_reduction_pct",10000],
	"MeleeCritical":["melee_crit",1],"RangeCritical":["ranged_crit",1],"MagicCritical":["magic_crit",1],
	"PierceDamageReduction":["damage_reduction_ignore",1],
	"PierceMeleeDamageReduction":["source_melee_flat_reduction_ignore",1],
	"PierceRangeDamageReduction":["source_ranged_flat_reduction_ignore",1],
	"PierceMagicDamageReduction":["source_magic_flat_reduction_ignore",1],
	"PiercePVPDamageReduction":["source_pvp_flat_reduction_ignore",1],
	"PVPSpellByLevelAdditionLevel":["source_pvp_status_success_level",1],
	"_fear_flat_ignore":["source_fear_flat_reduction_ignore",1],
	"PVPMeleeAdditionDamage":["pve_melee_damage",1],"PVEMeleeAdditionDamage":["pve_melee_damage",1],
	"PVPRangeAdditionDamage":["pve_ranged_damage",1],"PVERangeAdditionDamage":["pve_ranged_damage",1],
	"PVPMagicAdditionDamage":["pve_magic_damage",1],"PVEMagicAdditionDamage":["pve_magic_damage",1],
	"PierceMeleeEvasion":["melee_evasion_ignore",1],"PierceRangeEvasion":["ranged_evasion_ignore",1],
	"PierceDamageReductionPercent":["damage_amp_pct",10000],
	"PVEPierceDamageReductionPercent":["damage_amp_pct",10000],
	"DamageReductionPercent":["pve_damage_reduction_pct",10000],
	"_adena_drop":["adena_drop_pct",1],"HPHealIncreasePercent":["healing_magic_pct",10000],
	"CastSpeedBonus":["castSpeed",10000],
	"PierceMagicShieldPercent":["magic_penetration_pct",1],
	"MeleeCriticalResist":["melee_critical_resistance",10000],
	"RangeCriticalResist":["ranged_critical_resistance",10000],
	"MeleeDamageReductionPercent":["melee_damage_reduction_pct",10000],
	"RangeDamageReductionPercent":["ranged_damage_reduction_pct",10000],
	"MagicDamageReductionPercent":["magic_damage_reduction_pct",10000],
	"PoisonDamageReductionPercent":["dot_damage_reduction_pct",10000],
	"StrengthScale":["strPercent",10000],"DexterityScale":["dexPercent",10000],
	"IntelligenceScale":["intPercent",10000],
	"AttackDrainHP":["source_attack_drain_hp",1],"AttackDrainMP":["source_attack_drain_mp",1],
	"UndeadAdditionalMaxDamage":["source_undead_damage_max",1],
	"FinalBlowProbability":["source_final_blow_chance_pct",10000],
	"FinalBlowAdditionalScale":["source_final_blow_amp_pct",10000],
	"_final_blow_stun":["source_final_blow_stun_chance_pct",10000],
	"_stun_magic":["source_stun_magic_damage",1]}
var problem: String = ""

func _fail(message: String) -> Dictionary:
	problem = message
	return {}

func _required(row: Dictionary, fields: Array, context: String) -> bool:
	for field: String in fields:
		if not row.has(field):
			problem = context+": missing "+field
			return false
	return true

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _zero(value: Variant) -> bool:
	# Python's source comparison accepts False == 0 for native option flags.
	return not value if value is bool else (_number(value) and value==0)

func qualified_name(bonus: Dictionary, name: String, resistance_types: Dictionary, elemental_targets: Dictionary = {}) -> Variant:
	if not _required(bonus,["BonusApplicationTypeID","BonusApplicationTargetID"],"qualified_name"): return null
	var application: Variant = bonus.BonusApplicationTypeID
	var target: Variant = bonus.BonusApplicationTargetID
	if not bool(application) and not bool(target):
		return null if name in ["HitSpecialResistance","SpecialResistance","IncreaseNpcItemDropAmount"] else name
	var status: String = str(resistance_types.get(int(target),"")).to_lower()
	if name=="MagicDamage" and application==2 and status=="stun": return "_stun_magic"
	if name=="PierceDamageReduction" and application==2 and status=="fear": return "_fear_flat_ignore"
	if name=="FinalBlowProbability" and application==2 and status=="stun": return "_final_blow_stun"
	if name in ["HitSpecialResistance","SpecialResistance"] and application==2:
		if status in ["stun","hold","fear","poison","silence"]:
			return "_hit_"+status if name=="HitSpecialResistance" else ("_stun" if status=="stun" else "_resist_"+status)
	if name=="ElementalDamage" and application==3:
		var channel: Variant = elemental_targets.get(str(int(target)))
		if channel in ["fire","water","wind","earth"]: return "_elemental_"+str(channel)
	if name=="IncreaseNpcItemDropAmount" and application==5 and target==26: return "_adena_drop"
	return null

func _bonus(row: Dictionary, bonuses: Dictionary, types: Dictionary) -> Dictionary:
	if not _required(row,["BonusID"],"enchant effect") or not _integer(row.get("BonusID")): return _fail("enchant effect BonusID")
	var bonus: Variant = bonuses.get(str(int(row.BonusID)))
	if not bonus is Dictionary: return _fail("missing enchant Bonus: "+str(int(row.BonusID)))
	if not _required(bonus,["BonusTypeID","Value","BonusApplicationTypeID","BonusApplicationTargetID"],"Bonus"): return {}
	if not _integer(bonus.BonusTypeID) or not _integer(bonus.BonusApplicationTypeID) or not _integer(bonus.BonusApplicationTargetID) or not _number(bonus.Value): return _fail("invalid numeric enchant Bonus")
	var type: Variant = types.get(int(bonus.BonusTypeID))
	if not type is Dictionary: return _fail("missing enchant BonusType: "+str(int(bonus.BonusTypeID)))
	if not _required(type,["Name","UnitID"],"BonusType"): return {}
	if not type.Name is String or not _integer(type.UnitID): return _fail("invalid enchant BonusType")
	return {"bonus":bonus,"type":type}

func _live_invoke(option: Dictionary, type: Dictionary, bonus: Dictionary) -> bool:
	var kind: Variant = option.get("InvokeOptionTypeID")
	if kind not in [3,5,6] or type.UnitID!=3 or bonus.Value<0 or bonus.Value>1000000: return false
	var param: Variant = option.get("Param1",-1)
	if not _number(param): problem = "InvokeOption Param1"; return false
	if kind==6 and (typeof(option.get("BySpellAttack"))!=TYPE_BOOL or option.BySpellAttack or option.get("AttackTypeID") not in [0,1,2] or param<1000000): return false
	for key: String in ["Param2","Param3","Param4","Param5","Param6","MaterialTypeID","MaterialAmount","IsAmmoAttack","WeaponGroupID","ShieldTypeID","SuccessedInvokeOptionID","TargetKind","SiegeTargetKind"]:
		if not _zero(option.get(key,0)): return false
	return option.get("AttackTypeID") in [0,1,2,3] and param>=0

func build(tables: Dictionary, bound_items: Dictionary, bonuses: Dictionary) -> Dictionary:
	problem = ""
	if not tables.get("BonusType") is Array: return _fail("missing BonusType table")
	var types: Dictionary = {}
	var elemental_units := true
	for row: Variant in tables.BonusType:
		if not row is Dictionary or not _required(row,["ID","Name"],"BonusType"): return _fail("BonusType row")
		if not _integer(row.ID) or not row.Name is String: return _fail("BonusType identity")
		types[int(row.ID)] = row
		if row.Name=="ElementalDamage":
			if not row.has("UnitID"): return _fail("ElementalDamage UnitID")
			if row.UnitID!=1: elemental_units = false
	var invoke_options: Dictionary = {}
	if not tables.get("InvokeOption",[]) is Array: return _fail("InvokeOption table")
	for row: Variant in tables.get("InvokeOption",[]):
		if not row is Dictionary or not row.has("ID") or not _integer(row.ID): return _fail("InvokeOption row")
		invoke_options[int(row.ID)] = row
	var resistance_types: Dictionary = {}
	if not tables.get("SpecialResistanceType",[]) is Array: return _fail("SpecialResistanceType table")
	for row: Variant in tables.get("SpecialResistanceType",[]):
		if not row is Dictionary or not _required(row,["ID","Name"],"SpecialResistanceType"): return _fail("SpecialResistanceType row")
		if not _integer(row.ID) or not row.Name is String: return _fail("SpecialResistanceType identity")
		resistance_types[int(row.ID)] = row.Name
	var file := FileAccess.open(POLICY_PATH,FileAccess.READ)
	if file==null: return _fail("enhancement policy unavailable: "+POLICY_PATH)
	var parser := JSON.new()
	if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary: return _fail("enhancement policy JSON")
	file.close()
	var elemental_targets: Variant = parser.data.get("source_elemental_target_channels",{}) if elemental_units else {}
	if elemental_targets==null: elemental_targets = {}
	if not elemental_targets is Dictionary: return _fail("source_elemental_target_channels")
	var extra_fields: Dictionary = EXTRA.duplicate(true)
	for channel: String in ["fire","water","wind","earth"]: extra_fields["_elemental_"+channel] = ["source_elemental_flat_"+channel,1]
	for status: String in ["stun","hold","fear","poison","silence"]:
		extra_fields["_hit_"+status] = [status+"_accuracy",10000]
		if status!="stun": extra_fields["_resist_"+status] = [status+"_resistance",10000]
	if not tables.get("ItemBlessBonus",[]) is Array: return _fail("ItemBlessBonus table")
	var result: Dictionary = {}
	for iid: Variant in bound_items:
		var item: Variant = bound_items[iid]
		if not item is Dictionary or not item.get("item_class") is Dictionary or not item.get("catalog_record") is Dictionary: return _fail("bound equipment item")
		var raw: Dictionary = item.item_class
		var canonical: Dictionary = item.catalog_record
		if bool(raw.get("TestItem",false)) or canonical.get("slot") in ["consumable","material","currency",""]: continue
		if not item.get("enchant_effects") is Array: return _fail("enchant_effects")
		var options: Dictionary = {}
		var extras: Dictionary = {}
		var invokes: Dictionary = {}
		var skipped: Dictionary = {}
		for bless: int in [1,2]:
			var by_rank: Dictionary = {}
			var extra_rank: Dictionary = {}
			var invoke_rank: Dictionary = {}
			var groups: Dictionary = {}
			for row: Variant in item.enchant_effects:
				if not row is Dictionary or not _required(row,["ItemEnchantBonusGroupID","BlessCode","EnchantLevel"],"enchant effect"): return _fail("enchant effect row")
				if not _integer(row.ItemEnchantBonusGroupID) or not _integer(row.BlessCode) or not _integer(row.EnchantLevel): return _fail("enchant effect condition")
				var group: int = int(row.ItemEnchantBonusGroupID)
				if not groups.has(group): groups[group] = []
				groups[group].append(row)
			var selected: Array = []
			for rows: Array in groups.values():
				var codes: Dictionary = {}
				for row: Dictionary in rows: codes[int(row.BlessCode)] = true
				var code: int = bless if codes.has(bless) else 0
				for row: Dictionary in rows:
					if row.BlessCode==code: selected.append(row)
			for level: int in range(22):
				var totals: Dictionary = {}
				var extra: Dictionary = {}
				var live_invokes: Array = []
				for row: Dictionary in selected:
					if row.EnchantLevel!=level: continue
					if not row.has("ID") or not _integer(row.ID): return _fail("enchant effect ID")
					var detail: Dictionary = _bonus(row,bonuses,types)
					if detail.is_empty(): return {}
					var b: Dictionary = detail.bonus
					var type: Dictionary = detail.type
					var name: Variant = type.Name
					if name=="InvokeOption" and b.BonusApplicationTypeID==10:
						var option: Dictionary = invoke_options.get(int(b.BonusApplicationTargetID),{})
						if _live_invoke(option,type,b):
							live_invokes.append({"row_id":row.ID,"probability":b.Value,"option":option,
								"kind":{3:"attack_fixed_damage",5:"defence_flat_reduction",6:"attack_weapon_scale"}[int(option.InvokeOptionTypeID)]})
							continue
						if not problem.is_empty(): return {}
					if name in ["PierceMeleeDamageReduction","PierceRangeDamageReduction","PierceMagicDamageReduction","PiercePVPDamageReduction","PVPSpellByLevelAdditionLevel","PierceDamageReduction"] and type.UnitID!=1:
						skipped[int(row.ID)] = true; continue
					if name in ["FinalBlowProbability","FinalBlowAdditionalScale"] and type.UnitID!=3:
						skipped[int(row.ID)] = true; continue
					if name in ["IgnoreDamageReductionPercent","IgnoreMeleeDamageReductionPercent","IgnoreRangeDamageReductionPercent","IgnoreMagicDamageReductionPercent"] and type.UnitID!=3:
						skipped[int(row.ID)] = true; continue
					if name=="PierceMagicShieldPercent" and type.UnitID!=211:
						skipped[int(row.ID)] = true; continue
					if name=="ElementalCriticalResistance" and type.UnitID!=3:
						skipped[int(row.ID)] = true; continue
					if name=="MagicDamage" and b.BonusApplicationTypeID==2 and type.UnitID!=1: name = null
					else: name = qualified_name(b,str(name),resistance_types,elemental_targets)
					if not problem.is_empty(): return {}
					if name==null: skipped[int(row.ID)] = true; continue
					if FIELDS.has(name):
						var spec: Array = FIELDS[name]
						var key: String = spec[0]
						totals[key] = totals.get(key,0)+float(b.Value)/float(spec[2])
					elif extra_fields.has(name):
						var spec: Array = extra_fields[name]
						var key: String = spec[0]
						extra[key] = extra.get(key,0)+float(b.Value)/float(spec[1])
					else: skipped[int(row.ID)] = true
				var zero_keys: Dictionary = {}
				for row: Dictionary in selected:
					if row.EnchantLevel!=0: continue
					var detail: Dictionary = _bonus(row,bonuses,types)
					if detail.is_empty(): return {}
					var name: Variant = qualified_name(detail.bonus,str(detail.type.Name),resistance_types,elemental_targets)
					if not problem.is_empty(): return {}
					if name!=null and FIELDS.has(name): zero_keys[name] = true
				for name: String in zero_keys:
					var spec: Array = FIELDS[name]
					var key: String = spec[0]
					var host: Variant = spec[1]
					if totals.has(key) and host!=null and not str(host).is_empty():
						totals[key] = {"total":totals[key],"base_key":host,"scale":100 if host=="xp" else 1}
				for row: Dictionary in selected:
					if row.EnchantLevel!=0: continue
					var detail: Dictionary = _bonus(row,bonuses,types)
					if detail.is_empty(): return {}
					var name: Variant = qualified_name(detail.bonus,str(detail.type.Name),resistance_types,elemental_targets)
					if not problem.is_empty(): return {}
					if name!=null and extra_fields.has(name):
						var key: String = extra_fields[name][0]
						var base_key: String = {"AttackDrainHP":"hpAbsorption","AttackDrainMP":"mpAbsorption"}.get(name,key)
						if extra.has(key) and not extra[key] is Dictionary: extra[key] = {"total":extra[key],"base_key":base_key,"scale":1}
				by_rank[str(level)] = totals
				extra_rank[str(level)] = extra
				invoke_rank[str(level)] = live_invokes
			options[str(bless)] = by_rank
			extras[str(bless)] = extra_rank
			invokes[str(bless)] = invoke_rank
		var blessing: Dictionary = {}
		for value: Variant in tables.get("ItemBlessBonus",[]):
			if not value is Dictionary: return _fail("ItemBlessBonus row")
			var b: Dictionary = value
			if not _required(b,["ItemCategoryID","GradeID","IsTest","IsPossession","BonusApplicationTypeID","BonusApplicationTargetID"],"ItemBlessBonus") or not _required(raw,["CategoryID","GradeID"],"item_class"): return {}
			if b.ItemCategoryID!=raw.CategoryID or b.GradeID!=raw.GradeID or bool(b.IsTest) or bool(b.IsPossession) or b.BonusApplicationTypeID!=0 or b.BonusApplicationTargetID!=0: continue
			if not _required(b,["BonusTypeID","Value"],"ItemBlessBonus") or not _integer(b.BonusTypeID) or not _number(b.Value): return _fail("ItemBlessBonus value")
			var type: Variant = types.get(int(b.BonusTypeID))
			if not type is Dictionary or not type.get("Name") is String: return _fail("ItemBlessBonus type")
			var name: String = "ArmorClass" if type.Name=="ArmorClassBonus" else str(type.Name)
			if FIELDS.has(name):
				var spec: Array = FIELDS[name]
				blessing[str(spec[0])] = float(b.Value)/float(spec[2])
		var skipped_ids: Array = skipped.keys()
		skipped_ids.sort()
		result[iid] = {"options":options,"extra_options":extras,"invokes":invokes,"blessing":blessing,
			"category_id":raw.get("CategoryID",0),"grade_id":raw.get("GradeID",0),
			"material_id":raw.get("MaterialID",0),"unconnected_effect_row_ids":skipped_ids}
	return result

