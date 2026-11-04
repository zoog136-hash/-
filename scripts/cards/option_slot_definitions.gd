extends RefCounted
## Exact source declarations. Card ownership stays in the existing save namespace.
## A slot reference alone never unlocks a summon or grants a second awakening.
const DATA=preload("res://data/cards/patch523_option_slots.json")
static var _cache: Dictionary={}

static func _key(identity: String,slot: int) -> String:
	var parts: PackedStringArray=identity.split(":")
	if parts.size()!=4 or parts[0]!="source" or parts[1] not in ["m508","m523"] or slot not in [1,11]:return ""
	for index: int in [2,3]:
		if not parts[index].is_valid_int() or str(int(parts[index]))!=parts[index] or int(parts[index])<=0:return ""
	return parts[2]+":"+parts[3]+":"+str(slot)

static func group_for(identity: String,slot: int) -> Dictionary:
	var key: String=_key(identity,slot)
	if not DATA.data.groups.has(key):return {}
	if not _cache.has(key):
		var row: Dictionary=DATA.data.groups[key]
		var effects: Array[Dictionary]=[]
		for link: Dictionary in row.links:
			var bonus: Dictionary=DATA.data.bonuses[str(int(link.BonusID))]
			var type_row: Dictionary=DATA.data.types[str(int(bonus.BonusTypeID))]
			var unit_key: String=str(int(type_row.UnitID))
			effects.append({"link":link,"bonus":bonus,"type":type_row,"unit":DATA.data.units[unit_key],"ui_unit":DATA.data.ui_units.get(unit_key,{})})
		_cache[key]={"identity":identity,"source_snapshot":"patch523","card":row.card,"group":row.group,"effects":effects}
	return _cache[key].duplicate(true)

static func compatible_primary(identity: String) -> bool:
	if identity.begins_with("source:m523:"):
		return preload("res://data/cards/patch523_new_cards.json").data.skill_cards.has(identity)
	return _key(identity,1) in DATA.data.reviewed_primary_keys

static func apply_reviewed_primary(row: Dictionary) -> Dictionary:
	# Existing source card IDs, ownership and saved awakening flags survive.
	# Only the explicitly reviewed Mariela Level0 -> Level1 delta is activated.
	if not _key(str(row.id),1) in DATA.data.changed_primary_keys:return row
	var latest: Dictionary=group_for(str(row.id),1)
	var result: Dictionary=row.duplicate(true)
	result.native_source.card=latest.card
	result.native_source.group=latest.group
	result.native_source.effects=latest.effects
	result.native_source.slot_snapshot="patch523"
	result.stats={};result.applied_options=[];result.pending_options=[]
	var mapping: Dictionary={"PierceDamageReduction":"damage_reduction_ignore","EinasadSavingPercent":"blessing_consumption_reduction_pct","CarryPlus":"weightBonus","ExperienceAdditionPercent":"xp"}
	for effect: Dictionary in result.native_source.effects:
		var amount: float=float(effect.bonus.Value)
		var unit_name: String=str(effect.unit.Name)
		var denominator: float=float(effect.ui_unit.get("Denominator",0))
		if unit_name in ["Percentage","ValuePercent","Weight"] and denominator>0:amount/=denominator
		var supported: bool=int(effect.link.Level)==1 and int(effect.bonus.BonusApplicationTypeID)==0 and int(effect.bonus.BonusApplicationTargetID)==0 and mapping.has(effect.type.Name) and (unit_name=="Value" or (unit_name in ["Percentage","ValuePercent","Weight"] and denominator>0))
		effect.runtime_supported=supported
		var label: String=source_label(effect)
		if supported:
			var key: String=mapping[effect.type.Name]
			result.stats[key]=float(result.stats.get(key,0))+amount
			result.applied_options.append(label)
		else:result.pending_options.append(label)
	result.bonus_options=result.applied_options+result.pending_options
	return result

static func source_label(effect: Dictionary) -> String:
	var text: String=str(DATA.data.type_labels.get(str(int(effect.type.ID)),effect.type.Name))
	var amount: float=float(effect.bonus.Value)
	var unit_name: String=str(effect.unit.Name)
	var denominator: float=float(effect.ui_unit.get("Denominator",0))
	if unit_name in ["Percentage","ValuePercent","Weight"] and denominator>0:amount/=denominator
	var suffix: String="%" if unit_name in ["Percentage","ValuePercent"] and denominator>0 else ""
	return text+" "+str(amount).trim_suffix(".0")+suffix

static func labels(group: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	for effect: Dictionary in group.get("effects",[]):
		var name_value: String=str(effect.type.Name)
		if name_value=="StatusEffectID":
			result.append("각성 시각 효과");continue
		if name_value=="ArmorClassBonus" and effect.unit.Name=="Value" and int(effect.bonus.Value)>=0:
			# The existing def consumer displays an AC reduction for this bonus.
			result.append("AC -"+str(int(effect.bonus.Value)));continue
		result.append(source_label(effect))
	return result

static func view(identity: String) -> Array[Dictionary]:
	# References for existing source identities only. No new catalog grant occurs.
	if not compatible_primary(identity):return []
	var result: Array[Dictionary]=[]
	for slot: int in [1,11]:
		var row: Dictionary=group_for(identity,slot)
		if row.is_empty():continue
		row.labels=labels(row)
		result.append(row)
	return result
