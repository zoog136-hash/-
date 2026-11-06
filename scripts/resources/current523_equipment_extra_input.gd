extends RefCounted
## Missing native enhancement operands for the existing shared receiver.
## Read-only: the existing equipment/rules owners retain physical/save authority.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ENHANCE = preload("res://scripts/crafting/patch523_enhancement.gd")
const OPTIONS = preload("res://scripts/inven_option_adapter.gd")
const CATALOG_EFFECTS = preload("res://scripts/catalog_effects.gd")
# Only names with an established gameplay receiver are admitted. The last
# operand is the original Unit.Name; percentage raw values use divisor10000.
const OPERANDS = {
	"healing_magic_pct":{"HPHealIncreasePercent":["Percentage",10000]},
	"equipment523_element_crit_resist_pct":{"ElementalCriticalResistance":["Percentage",10000]},
	"mpRecoveryTick":{"RegenMP":["Value",1]},
	"adena_drop_pct":{"IncreaseNpcItemDropAmount":["ValuePercent",1,5,26]},
	"stun_accuracy":{"HitSpecialResistance":["Percentage",10000,2,"Stun"]},
	"fear_accuracy":{"HitSpecialResistance":["Percentage",10000,2,"Fear"]},
	"hold_resistance":{"SpecialResistance":["Percentage",10000,2,"Hold"]},
	"fear_resistance":{"SpecialResistance":["Percentage",10000,2,"Fear"]},
	"source_final_blow_stun_chance_pct":{"FinalBlowProbability":["Percentage",10000,2,"Stun"]},
	"source_stun_magic_damage":{"MagicDamage":["Value",1,2,"Stun"]},
	"source_elemental_flat_fire":{"ElementalDamage":["Value",1,3,"fire"]},
	"source_elemental_flat_water":{"ElementalDamage":["Value",1,3,"water"]},
	"source_elemental_flat_wind":{"ElementalDamage":["Value",1,3,"wind"]},
	"source_elemental_flat_earth":{"ElementalDamage":["Value",1,3,"earth"]},
	"melee_crit":{"MeleeCritical":["ValuePercent",1]},
	"ranged_crit":{"RangeCritical":["ValuePercent",1]},
	"magic_crit":{"MagicCritical":["ValuePercent",1]},
	"dg":{"MeleeEvasion":["Value",1]},
	"er":{"RangeEvasion":["Value",1]},
	"attackSpeed":{"AttackSpeedBonus":["Percentage",10000]},
	"speedBonusPct":{"MoveSpeedBonus":["Percentage",10000]},
	"magicDamage":{"MagicDamage":["Value",1]},
	"pve_damage_reduction":{"PVEDamageReduction":["Value",1]},
	"pve_melee_damage":{"PVEMeleeAdditionDamage":["Value",1]},
	"pve_ranged_damage":{"PVERangeAdditionDamage":["Value",1]},
	"pve_magic_damage":{"PVEMagicAdditionDamage":["Value",1]},
	"melee_evasion_ignore":{"PierceMeleeEvasion":["Value",1]},
	"ranged_evasion_ignore":{"PierceRangeEvasion":["Value",1]},
	"damage_reduction_ignore":{"PierceDamageReduction":["Value",1]},
	"magic_penetration_pct":{"PierceMagicShieldPercent":["ValuePercent",1]},
	"castSpeed":{"CastSpeedBonus":["Percentage",10000]},
	"dot_damage_reduction_pct":{"PoisonDamageReductionPercent":["Percentage",10000]},
	"strPercent":{"StrengthScale":["Percentage",10000]},
	"dexPercent":{"DexterityScale":["Percentage",10000]},
	"intPercent":{"IntelligenceScale":["Percentage",10000]},
	"melee_critical_resistance":{"MeleeCriticalResist":["Percentage",10000]},
	"ranged_critical_resistance":{"RangeCriticalResist":["Percentage",10000]},
	"melee_damage_reduction_pct":{"MeleeDamageReductionPercent":["Percentage",10000]},
	"ranged_damage_reduction_pct":{"RangeDamageReductionPercent":["Percentage",10000]},
	"magic_damage_reduction_pct":{"MagicDamageReductionPercent":["Percentage",10000]},
	"pve_damage_reduction_pct":{"PVEDamageReductionPercent":["Percentage",10000],"DamageReductionPercent":["Percentage",10000]},
	"damage_amp_pct":{"PierceDamageReductionPercent":["Percentage",10000],"PVEPierceDamageReductionPercent":["Percentage",10000]},
	"source_attack_drain_hp":{"AttackDrainHP":["Value",1]},
	"source_attack_drain_mp":{"AttackDrainMP":["Value",1]},
	"source_undead_damage_max":{"UndeadAdditionalMaxDamage":["Value",1]},
	"source_final_blow_chance_pct":{"FinalBlowProbability":["Percentage",10000]},
	"source_final_blow_amp_pct":{"FinalBlowAdditionalScale":["Percentage",10000]}}
# Each whitelisted item/key has its own held-source zero baseline and units.
# A different source item/key must establish its own owner baseline first.
const WHOLE_ZERO_FAMILIES = {
	"213621:attackSpeed":12241,
	"233812:pve_damage_reduction":12922,
	"233812:pve_damage_reduction_pct":12922,
	"233812:adena_drop_pct":12922,
	"233812:source_undead_damage_max":12922,
	"425:damage_amp_pct":10712,
	"226348:stun_accuracy":12468,
	"226348:fear_accuracy":12468,
	"226358:fear_resistance":12488}
static var evidence: Dictionary = {}

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _application_matches(bonus: Dictionary, operand: Array) -> bool:
	if not integer(bonus.get("BonusApplicationTypeID")) or not integer(bonus.get("BonusApplicationTargetID")): return false
	var application: int = int(bonus.BonusApplicationTypeID)
	var target: int = int(bonus.BonusApplicationTargetID)
	if operand.size()==2: return application==0 and target==0
	if application!=operand[2]: return false
	if application==2:
		var status: Dictionary = SOURCE.row("SpecialResistanceType",target)
		return not status.is_empty() and SOURCE.declared_exclusion("SpecialResistanceType",status).is_empty() and status.get("Name")==operand[3]
	if application==3:
		# Reuse the already configured compiler/receiver channel contract.
		# This is not a new inferred elemental target namespace.
		var channels: Variant = ENHANCE.policy().get("source_elemental_target_channels",{})
		return channels is Dictionary and channels.get(str(target))==operand[3]
	return application==5 and target==operand[3]

static func _original_delta(item_id: int, effects: Array, level: int, blessing: int, key: String, allow_whole: bool = false) -> Dictionary:
	var groups: Dictionary = {}; var selectors: Dictionary = {}
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",item_id):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if type.get("Name")!="EnchantBonusGroupID": continue
		var unit: Dictionary = SOURCE.row("Unit",int(type.get("UnitID",-1)))
		if unit.get("Name")!="EnchantBonusGroupID" or not SOURCE.declared_exclusion("Unit",unit).is_empty(): continue
		if link.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or not integer(bonus.get("Value")): continue
		if not SOURCE.declared_exclusion("ItemBonus",link).is_empty() or not SOURCE.declared_exclusion("Bonus",bonus).is_empty() or not SOURCE.declared_exclusion("BonusType",type).is_empty(): continue
		if selectors.has(int(bonus.Value)): return {}
		selectors[int(bonus.Value)]={"link":link,"bonus":bonus,"type":type,"unit":unit}
	var seen_rows: Dictionary = {}
	for row: Variant in effects:
		if not row is Dictionary or not integer(row.get("ID")) or not integer(row.get("ItemEnchantBonusGroupID")) or not integer(row.get("BlessCode")): return {}
		var originals: Array[Dictionary] = SOURCE.related("ItemEnchantBonus","ID",int(row.ID))
		if originals.size()!=1 or originals[0]!=row or not SOURCE.declared_exclusion("ItemEnchantBonus",row).is_empty(): return {}
		if seen_rows.has(int(row.ID)): return {}
		seen_rows[int(row.ID)]=true
		var group: int = int(row.ItemEnchantBonusGroupID)
		if not groups.has(group): groups[group]=[]
		groups[group].append(row)
	var total: float = 0.0; var used: Array = []; var zero_rows: Array = []
	for group: int in groups:
		if not selectors.has(group): continue
		var codes: Dictionary = {}
		for row: Dictionary in groups[group]: codes[int(row.BlessCode)]=true
		var selected_code: int = blessing if codes.has(blessing) else 0
		for row: Dictionary in groups[group]:
			if row.BlessCode!=selected_code: continue
			var bonus: Dictionary = SOURCE.row("Bonus",int(row.get("BonusID",-1)))
			var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
			if not OPERANDS[key].has(type.get("Name","")): continue
			var operand: Array = OPERANDS[key][type.Name]
			if not _application_matches(bonus,operand): continue
			var unit: Dictionary = SOURCE.row("Unit",int(type.get("UnitID",-1)))
			if unit.get("Name")!=operand[0] or not integer(row.get("EnchantLevel")): return {}
			for pair: Array in [["Bonus",bonus],["BonusType",type],["Unit",unit]]:
				if not SOURCE.declared_exclusion(pair[0],pair[1]).is_empty(): return {}
			var value: Variant = bonus.get("Value")
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return {}
			# A whole family is admitted only with its exact established baseline.
			if allow_whole and group!=WHOLE_ZERO_FAMILIES.get(str(item_id)+":"+key,-1): return {}
			if int(row.EnchantLevel)==0:
				if not allow_whole: return {}
				zero_rows.append(row)
			if int(row.EnchantLevel)!=level: continue
			total+=float(value)/float(operand[1]) # Preserve the original declared unit.
			used.append({"selector":selectors[group],"row":row,"bonus":bonus,"type":type,"unit":unit})
	return {"value":total,"rows":used,"zero_rows":zero_rows} if not used.is_empty() and is_finite(total) else {}

static func _whole_zero_baseline(world: Node, item_key: String, key: String, current: Dictionary, expected: Dictionary) -> Dictionary:
	# No base-key/unit/scale policy is generalized beyond these held families.
	if not WHOLE_ZERO_FAMILIES.has(item_key+":"+key) or expected.keys().size()!=3 or expected.get("base_key")!=key or not integer(expected.get("scale")) or expected.get("scale")!=1: return {}
	var whole: Variant = expected.get("total")
	if typeof(whole) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(whole)): return {}
	for row: Dictionary in SOURCE.related("ItemBonus","ItemClassID",int(item_key)):
		var bonus: Dictionary = SOURCE.row("Bonus",int(row.get("BonusID",-1)))
		var kind: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if OPERANDS[key].has(kind.get("Name","")): return {} # No base operand in these originals.
	var canonical: Dictionary = world.patch523_equipment.record(item_key)
	for field: String in ["source","source_snapshot","source_projection","sourceId","source_definition_archive","source_original_item","slot"]:
		if canonical.get(field)!=current.get(field): return {}
	if canonical.get("source_m_native_item")!=true or not world.patch523_equipment.catalog_identity_matches(canonical,item_key): return {}
	var annotated: Dictionary = OPTIONS.annotate(canonical)
	var baseline: Variant = annotated.get(key,0)
	if typeof(baseline) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(baseline)) or baseline!=0: return {}
	var current_base: Variant = current.get(key,0)
	if typeof(current_base) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(current_base)) or current_base!=baseline: return {}
	if key=="attackSpeed" and (CATALOG_EFFECTS.attack_speed_percent(canonical)!=0 or CATALOG_EFFECTS.attack_speed_percent(current)!=0): return {}
	var status_receiver: String = {"stun_accuracy":"_record_stun_accuracy","fear_accuracy":"_record_fear_accuracy","fear_resistance":"_record_fear_resistance"}.get(key,"")
	if not status_receiver.is_empty():
		if not world.has_method(status_receiver) or world.call(status_receiver,canonical)!=0 or world.call(status_receiver,current)!=0: return {}
	return {"total":whole,"base_key":key,"base":baseline,"scale":1,"delta":float(whole)-float(baseline)}

static func sum_native(world: Node, key: String) -> float:
	if not OPERANDS.has(key) or not is_instance_valid(world): return 0.0
	evidence[key]={}
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty(): return 0.0
	var total: float = 0.0; var visited: Dictionary = {}
	for slot: String in world.EQUIPMENT_SLOT_ORDER:
		var worn: Dictionary = world.equipped_items.get(slot,{})
		var physical_id: String = str(worn.get("instance_id",""))
		if physical_id.is_empty() or visited.has(physical_id): continue
		visited[physical_id]=true
		var physical: Dictionary = world.item_instances.get(physical_id,{})
		if physical.is_empty() or physical.get("name")!=worn.get("name") or not integer(physical.get("level",0)): continue
		var level: int = int(physical.get("level",0))
		if level<0 or level>20: continue # No missing-rank extrapolation.
		var current: Dictionary = world._source_catalog_record("아이템",worn)
		if current.get("source")!="lineagem_patch523" or current.get("source_snapshot")!="patch523" or current.get("source_projection")!="current523_original_typed_game_dto_v1" or current.get("source_m_native_item")!=true or current.get("source_test_item")!=false or current.get("source_equipment_status")!="mapped" or current.get("source_legacy_catalog_alias",false) or current.get("source_legacy_stack_variant",false): continue
		if current.get("_patch523_effective_extras",false) and current.has(key): continue # Already in the normal sum.
		var id: Variant = current.get("source_item_class_id")
		if not integer(id) or int(id)<=0 or current.get("sourceId")!="m523:item:"+str(int(id)) or current.get("source_definition_archive")!=identity: continue
		var raw: Dictionary = SOURCE.row("ItemClass",int(id))
		if raw.is_empty() or raw!=current.get("source_original_item") or raw.get("TestItem")!=false or not SOURCE.declared_exclusion("ItemClass",raw).is_empty(): continue
		if physical.has("sourceId") and physical.sourceId!=current.get("sourceId"): continue
		var blessing: int = world.patch523_equipment.bless_code(physical)
		if blessing not in [1,2]: continue
		var prepared: Dictionary = world._physical_enhancement_record(worn)
		if prepared.get("source")!="lineagem_patch523" or prepared.get("source_snapshot")!="patch523" or prepared.get("source_projection")!="current523_original_typed_game_dto_v1" or prepared.get("source_m_native_item")!=true or prepared.get("sourceId")!=current.get("sourceId") or prepared.get("source_item_class_id")!=id or prepared.get("source_definition_archive")!=identity or prepared.get("source_original_item")!=raw: continue
		var basis: Dictionary = prepared.get("patch523_effect_basis",{})
		var item_key: String = ENHANCE.item_id(prepared)
		if item_key!=str(int(id)) or basis.get("selection")!="source_exact_level" or basis.get("sha256")!=world.patch523_equipment.digest or not world.patch523_equipment.catalog_identity_matches(prepared,item_key): continue
		var bound: Dictionary = world.patch523_equipment.data.get("items",{}).get(item_key,{})
		if bound.get("item_class")!=raw: continue
		var expected: Variant = world.patch523_equipment.data.get("equipment_runtime",{}).get(item_key,{}).get("extra_options",{}).get(str(blessing),{}).get(str(level),{}).get(key)
		var actual: Variant = prepared.get("enhancement_extra_options",{}).get(str(level),{}).get(key)
		if typeof(actual) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(actual)): continue
		var whole_basis: Dictionary = {}
		var source_total: Variant = expected
		if expected is Dictionary:
			whole_basis = _whole_zero_baseline(world,item_key,key,current,expected)
			if whole_basis.is_empty() or actual!=whole_basis.delta: continue
			source_total = whole_basis.total
		elif typeof(expected) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(expected)) or actual!=expected: continue
		var effects: Variant = bound.get("enchant_effects")
		if not effects is Array: continue
		var source: Dictionary = _original_delta(int(id),effects,level,blessing,key,not whole_basis.is_empty())
		if source.is_empty() or source.value!=source_total or (not whole_basis.is_empty() and source.zero_rows.is_empty()): continue
		total+=float(actual)
		evidence[key][physical_id]={"source":identity,"item_class_id":id,"level":level,"bless_code":blessing,"rows":source.rows,"value":actual,"whole_basis":whole_basis,"model_sha256":world.patch523_equipment.digest}
	return total if is_finite(total) else 0.0
