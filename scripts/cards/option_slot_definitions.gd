extends RefCounted
## Exact source declarations. Card ownership stays in the existing save namespace.
## A slot reference alone never unlocks a summon or grants a second awakening.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const MAP: Dictionary={"HPPlus":"hpFlat","HPPlusPercent":"hpPct","Strength":"strFlat","Dexterity":"dexFlat",
	"Intelligence":"intFlat","CarryPlus":"weightBonus","ArmorClass":"def","AttackSpeedBonus":"attackSpeed",
	"MoveSpeedBonus":"moveSpeedPct","ExperienceAdditionPercent":"xp","EinasadSavingPercent":"blessing_consumption_reduction_pct",
	"SpellCastDelayDecreasePercent":"skillCooldownPct","PierceDamageReduction":"damage_reduction_ignore","MeleeHit":"meleeHit",
	"RangeHit":"rangedHit","MagicHit":"magicHit","HPPotionIncreaseStatic":"potionHealFlat","SpellPower":"sp"}
static var problem: String=""
static var source_input_identity: Dictionary={}
static var declared_exclusion: Dictionary={}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _fail(reason: String) -> Dictionary:
	problem=reason
	return {}

static func _row(table: String,value: Variant) -> Dictionary:
	if not _integer(value) or value<0:return _fail("invalid_source_reference:"+table)
	var raw: Dictionary=SOURCE.row(table,int(value))
	if raw.is_empty():return _fail("missing_or_ambiguous_source_reference:"+table+":"+str(int(value))+":"+SOURCE.problem())
	var exclusion: Dictionary=SOURCE.declared_exclusion(table,raw)
	if not exclusion.is_empty():
		declared_exclusion=exclusion
		return _fail("source_declared_dummy:"+table+":"+str(int(value)))
	return raw

static func _key(identity: String,slot: int) -> String:
	var parts: PackedStringArray=identity.split(":")
	if parts.size()!=4 or parts[0]!="source" or parts[1] not in ["m508","m523"] or slot not in [1,11]:return ""
	for index: int in [2,3]:
		if not parts[index].is_valid_int() or str(int(parts[index]))!=parts[index] or int(parts[index])<=0:return ""
	return parts[2]+":"+parts[3]+":"+str(slot)

static func group_for(identity: String,slot: int) -> Dictionary:
	var key: String=_key(identity,slot)
	problem="";declared_exclusion={};source_input_identity=SOURCE.identity()
	if key.is_empty():return _fail("invalid_source_card_identity_or_slot")
	if source_input_identity.is_empty():return _fail("current523_source_unavailable:"+SOURCE.problem())
	var parts: PackedStringArray=key.split(":")
	var card_id: int=int(parts[1])
	var card: Dictionary=_row("BuffCard",card_id)
	if card.is_empty():return {}
	if not _integer(card.get("BuffCardDeckID")) or int(card.BuffCardDeckID)!=int(parts[0]):return _fail("source_card_deck_mismatch:"+identity)
	var groups: Array[Dictionary]=[]
	var secondary: Array[Dictionary]=[]
	for raw: Dictionary in SOURCE.related("BuffCardOptionAwakenGroup","BuffCardID",card_id):
		if not _integer(raw.get("SlotIndex")):return _fail("invalid_source_slot_index:"+identity)
		if int(raw.SlotIndex)==slot:groups.append(raw)
		elif slot==1 and int(raw.SlotIndex)==11:secondary.append(raw)
	if groups.size()!=1:return _fail(("missing_source_slot_group:" if groups.is_empty() else "ambiguous_source_slot_group:")+key)
	var group: Dictionary=_row("BuffCardOptionAwakenGroup",groups[0].get("ID"))
	if group.is_empty():return {}
	if group.get("BuffCardID")!=card_id or group.get("SlotIndex")!=slot:return _fail("source_slot_group_identity_mismatch:"+key)
	var effects: Array[Dictionary]=[]
	for link: Dictionary in SOURCE.related("BuffCardOptionAwakenLevelBonus","BuffCardOptionAwakenGroupID",int(group.ID)):
		if not _integer(link.get("ID")) or not _integer(link.get("Level")):return _fail("invalid_source_level_link:"+key)
		var bonus: Dictionary=_row("Bonus",link.get("BonusID"))
		if bonus.is_empty():return {}
		if typeof(bonus.get("Value")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(bonus.Value)) or not _integer(bonus.get("BonusApplicationTypeID")) or not _integer(bonus.get("BonusApplicationTargetID")):return _fail("invalid_source_bonus:"+str(bonus.ID))
		var type_row: Dictionary=_row("BonusType",bonus.get("BonusTypeID"))
		if type_row.is_empty():return {}
		var unit: Dictionary=_row("Unit",type_row.get("UnitID"))
		if unit.is_empty():return {}
		if not type_row.get("Name") is String or not unit.get("Name") is String:return _fail("invalid_source_option_type_or_unit:"+key)
		var ui_rows: Array[Dictionary]=SOURCE.related("UIUnit","UnitID",int(unit.ID))
		if ui_rows.size()>1:return _fail("ambiguous_source_display_unit:"+str(unit.ID))
		var ui: Dictionary=ui_rows[0] if ui_rows.size()==1 else {}
		if not ui.is_empty() and not _integer(ui.get("Denominator")):return _fail("invalid_source_display_denominator:"+str(unit.ID))
		effects.append({"link":link,"bonus":bonus,"type":type_row,"unit":unit,"ui_unit":ui})
	if effects.is_empty():return _fail("missing_source_level_bonus:"+key)
	if not _integer(card.get("ServerLimitSetID")) or not _integer(group.get("ServerLimitsetID")) or card.ServerLimitSetID<0 or group.ServerLimitsetID<0:return _fail("invalid_source_server_limit:"+key)
	var servers: Array[Dictionary]=[]
	var limit_ids: Dictionary={int(card.ServerLimitSetID):true,int(group.ServerLimitsetID):true}
	for id: int in limit_ids:
		if id!=0:servers.append_array(SOURCE.related("ServerLimit","ServerLimitSetID",id))
	return {"identity":identity,"source_snapshot":"patch523","source_input_identity":source_input_identity.duplicate(true),
		"card":card,"group":group,"effects":effects,"secondary_groups":secondary,"source_server_limits":servers,
		"reference_only":true,"awakening_authorized":false}

static func compatible_primary(identity: String) -> bool:
	return not group_for(identity,1).is_empty()

static func apply_reviewed_primary(row: Dictionary) -> Dictionary:
	# Existing source card IDs, ownership and saved awakening flags survive.
	var latest: Dictionary=group_for(str(row.id),1)
	var result: Dictionary=row.duplicate(true)
	result.stats={};result.applied_options=[];result.pending_options=[]
	result["source_available"]=not latest.is_empty()
	result["source_input_identity"]=source_input_identity.duplicate(true)
	if latest.is_empty():
		result["source_problem"]=problem
		result["native_source"]={"available":false,"card":{},"group":{},"effects":[],"limits":[],"secondary_groups":[],"problem":problem}
		result.pending_options.append(problem)
		result.bonus_options=result.pending_options.duplicate()
		if not declared_exclusion.is_empty():result["excluded"]=true;result["declared_exclusion"]=declared_exclusion.duplicate(true)
		return result
	result["native_source"]={"available":true,"card":latest.card,"group":latest.group,"effects":latest.effects,
		"slot_snapshot":"patch523","source_input_identity":latest.source_input_identity,
		"limits":[latest.card.ServerLimitSetID,latest.group.ServerLimitsetID],"secondary_groups":latest.secondary_groups}
	result["source_server_limits"]=latest.source_server_limits
	for effect: Dictionary in result.native_source.effects:
		var amount: float=float(effect.bonus.Value)
		var unit_name: String=str(effect.unit.Name)
		var denominator: float=float(effect.ui_unit.get("Denominator",0))
		if unit_name in ["Percentage","ValuePercent","Weight"] and denominator>0:amount/=denominator
		var supported: bool=int(effect.link.Level)==1 and int(effect.bonus.BonusApplicationTypeID)==0 and int(effect.bonus.BonusApplicationTargetID)==0 and MAP.has(effect.type.Name) and (unit_name=="Value" or (unit_name in ["Percentage","ValuePercent","Weight"] and denominator>0))
		effect.runtime_supported=supported
		var label: String=source_label(effect)
		if supported:
			var key: String=MAP[effect.type.Name]
			result.stats[key]=float(result.stats.get(key,0))+amount
			result.applied_options.append(label)
		else:result.pending_options.append(label)
	if not latest.secondary_groups.is_empty():result.pending_options.append("원본 추가 옵션 슬롯 11 · 기존 단일 각성 상태와 별도 처리 필요")
	result.bonus_options=result.applied_options+result.pending_options
	return result

static func source_label(effect: Dictionary) -> String:
	var text: String=str(effect.type.Name)
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
