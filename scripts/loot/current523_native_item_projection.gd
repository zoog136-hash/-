extends RefCounted
## Current ItemData -> existing game DTO. This supplies no ownership or save.
## Slot/stat/formula mappings retain the public patch523_item_definitions.py ABI.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const SLOT_MAP={"Head":"helmet","Torso":"body","Shirt":"tshirt","Cloak":"cloak","Leg":"gaiters","Foot":"boots","Hand":"gloves","WeaponHold":"weapon","Finger":"ring","Neck":"necklace","Waist":"belt","Ear":"earring","ShieldHold":"offhand","Quiver":"offhand","Rune":"rune","SpellRune":"rune","Badge":"seal","Insignia":"badge","Spaulder":"shoulder","Bangle_normal":"bracelet","Bangle_BM":"bracelet","Crest":"crystal","Catalyst":"catalyst","DominationStone":"domination_stone","Relic":"relic_item","FishingRod":"fishing_rod"}
const FLAT={"WeaponSmallDamage":"small_damage","WeaponLargeDamage":"large_damage","WeaponHitBonus":"hit","WeaponDamageBonus":"additionalDamage","ArmorClass":"def","ArmorClassBonus":"def","Strength":"strFlat","Dexterity":"dexFlat","Constitution":"conFlat","Intelligence":"intFlat","Wisdom":"wisFlat","Charisma":"chaFlat","HPPlus":"hpFlat","MPPlus":"mpFlat","MagicResist":"mr","DamageReduction":"damage_reduction","SpellPower":"sp","MeleeDamage":"meleeDamage","RangeDamage":"rangedDamage","MagicDamage":"magicDamage","MeleeHit":"meleeHit","RangeHit":"rangedHit","MagicHit":"magicHit","PVEDamageReduction":"pve_damage_reduction","PVPDamageReduction":"pvp_damage_reduction","PVPMeleeAdditionDamage":"pvp_melee_damage","PVPRangeAdditionDamage":"pvp_ranged_damage","PVPMagicAdditionDamage":"pvp_magic_damage","PVEMeleeAdditionDamage":"pve_melee_damage","PVERangeAdditionDamage":"pve_ranged_damage","PVEMagicAdditionDamage":"pve_magic_damage","PierceMeleeEvasion":"melee_evasion_ignore","PierceRangeEvasion":"ranged_evasion_ignore","PierceMeleeDamageReduction":"melee_reduction_ignore","PierceRangeDamageReduction":"ranged_reduction_ignore","PierceMagicDamageReduction":"magic_reduction_ignore","HPPotionIncreaseStatic":"potionHealFlat"}
const HP=["HPRestoration","HPRestorationDiceNumber","HPRestorationDiceSpotCount"]
const MP=["MPRestoration","MPRestorationDiceNumber","MPRestorationDiceSpotCount"]

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0
## Table JSON numbers are floats. `in`, `match` and Array/Dictionary equality
## are type-strict, so an integral one is compared as the int it is; any other
## value (fractional, string, null) is returned unchanged and still fails.
static func whole(value: Variant) -> Variant:
	return int(value) if typeof(value)==TYPE_FLOAT and integer(value) else value
static func label(id: Variant) -> String:
	if not integer(id) or int(id)<=0:return ""
	return str(SOURCE.row("DescData_Korean",int(id)).get("Description","")).strip_edges()
## SpecialResistance / HitSpecialResistance on equipment: application type
## SpecialResistanceType with the status as target, unit Percentage shown
## through its UIUnit Denominator (50000 -> 5). The statuses TWILIGHT has
## (stun/hold/fear/poison/silence) feed the existing *_resistance/_accuracy
## record fields; Ice/Lapidification/Sleep/Dark etc. stay unhandled.
const STATUS_BONUS={"SpecialResistance":"_resistance","HitSpecialResistance":"_accuracy"}
const STATUS_PREFIX={"Stun":"stun","Hold":"hold","Fear":"fear","Poison":"poison","Silence":"silence"}
static func status_field(row: Dictionary) -> Dictionary:
	var bonus: Dictionary=row.get("bonus",{})
	if row.get("IsPossession")!=false or not integer(bonus.get("Value")) or int(bonus.Value)<=0 or not integer(bonus.get("BonusApplicationTypeID")) or not integer(bonus.get("BonusApplicationTargetID")):return {}
	if str(SOURCE.row("BonusApplicationType",int(bonus.BonusApplicationTypeID)).get("Name",""))!="SpecialResistanceType":return {}
	var type: String=str(SOURCE.row("SpecialResistanceType",int(bonus.BonusApplicationTargetID)).get("Name",""))
	if not STATUS_PREFIX.has(type):return {}
	var display: Array[Dictionary]=SOURCE.related("UIUnit","UnitID",int(row.get("unit",{}).get("ID",-1)))
	if display.size()!=1 or not integer(display[0].get("Denominator")) or int(display[0].Denominator)<=0 or int(bonus.Value)%int(display[0].Denominator)!=0:return {}
	return {"field":STATUS_PREFIX[type]+STATUS_BONUS[str(row.bonus_type.Name)],"value":int(bonus.Value)/int(display[0].Denominator),"type":type,"denominator":int(display[0].Denominator)}

static func direct(row: Dictionary) -> bool:
	return row.get("IsPossession")==false and row.get("bonus",{}).get("BonusApplicationTypeID")==0 and row.get("bonus",{}).get("BonusApplicationTargetID")==0
static func values(rows: Array,names: Array) -> Dictionary:
	var result: Dictionary={}
	for row: Dictionary in rows:
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""))
		if name_value not in names or not direct(row) or row.get("unit",{}).get("Name")!="Value" or not integer(row.get("bonus",{}).get("Value")):continue
		if not result.has(name_value):result[name_value]=[]
		result[name_value].append(int(row.bonus.Value))
	return result
static func formula(rows: Array,names: Array) -> Dictionary:
	var grouped: Dictionary=values(rows,names);var result: Dictionary={}
	for name_value: String in grouped:
		if grouped[name_value].size()!=1:return {}
		result[name_value]=int(grouped[name_value][0])
	if result.is_empty():return {}
	var base: int=int(result.get(names[0],0));var count: int=int(result.get(names[1],0));var sides: int=int(result.get(names[2],0))
	if base<0 or count<0 or count>1000 or sides<0 or sides>1000000 or (count>0)!=(sides>0) or base+count*sides<=0 or base>9007199254740991-count*sides:return {}
	return result
static func consume_metadata(rows: Array,raw: Dictionary,category: Dictionary,permitted: Dictionary={},require_delay: bool=true) -> Dictionary:
	var reasons: Array=[];var grouped: Dictionary={}
	var units: Dictionary={"MPRestoration":"Value","MPRestorationDiceNumber":"Value","MPRestorationDiceSpotCount":"Value","ItemConsumeDelay":"MilliSeconds","ItemConsumeEffectSpriteID":"SpriteID"}
	if not permitted.is_empty():units=permitted.duplicate(true)
	if category.get("IsConsumable")!=true:reasons.append("source_category_not_consumable")
	if raw.get("TargettingTypeID")!=1:reasons.append("unsupported_targetting_type")
	if not str(raw.get("ServiceRegionCode","")).is_empty():reasons.append("source_service_region_context_required")
	for row: Dictionary in rows:
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""))
		# Item lifetime: record() projects DeleteTime to source_delete_time_raw
		# and use eligibility refuses the item once it is reached (the client's
		# expiry). Only a lifetime that cannot be resolved still blocks use.
		if name_value=="DeleteTime":
			if delete_time_stamp(row)<=0:reasons.append("source_item_lifetime_unresolved")
			continue
		# The game has no lifetime extension, so this flag only forbids one.
		if name_value=="CannotExtendDeleteTime":
			if not direct(row) or row.get("unit",{}).get("Name")!="TrueFalse" or whole(row.get("bonus",{}).get("Value")) not in [0,1]:reasons.append("unsupported_item_bonus_unit_or_value:"+name_value)
			continue
		if not direct(row):reasons.append("conditional_or_possession_item_bonus:"+name_value);continue
		if not units.has(name_value):reasons.append("source_item_lifetime_unresolved" if name_value=="DeleteTime" else "source_infinite_amount_not_supported" if name_value=="InfiniteAmount" else "unsupported_item_bonus:"+name_value);continue
		if row.get("unit",{}).get("Name")!=units[name_value] or not integer(row.get("bonus",{}).get("Value")):reasons.append("unsupported_item_bonus_unit_or_value:"+name_value);continue
		if not grouped.has(name_value):grouped[name_value]=[]
		grouped[name_value].append(int(row.bonus.Value))
	if grouped.get("ItemConsumeDelay",[]).size()>1 or (require_delay and grouped.get("ItemConsumeDelay",[]).is_empty()):reasons.append("missing_or_ambiguous_consume_delay")
	elif not grouped.get("ItemConsumeDelay",[]).is_empty() and int(grouped.ItemConsumeDelay[0])<0:reasons.append("invalid_consume_delay")
	if grouped.get("ItemConsumeEffectSpriteID",[]).size()>1:reasons.append("ambiguous_consume_sprite")
	return {"targetting_type_id":raw.get("TargettingTypeID"),"can_use_when_invisible":raw.get("CanUseWhenInvisible"),"consume_delay_ms":grouped.get("ItemConsumeDelay",[null])[0],"consume_effect_sprite_id":grouped.get("ItemConsumeEffectSpriteID",[0])[0],"blocked_reasons":reasons}

static func date_value(raw: Dictionary) -> int:
	for field: String in ["Year","Month","Day","Hour","Minute"]:
		if not integer(raw.get(field)):return 0
	var text: String="%04d-%02d-%02dT%02d:%02d:00" % [int(raw.Year),int(raw.Month),int(raw.Day),int(raw.Hour),int(raw.Minute)]
	if int(raw.Year)<1 or int(raw.Year)>9999 or int(raw.Month)<1 or int(raw.Month)>12 or int(raw.Day)<1 or int(raw.Day)>31 or int(raw.Hour)<0 or int(raw.Hour)>23 or int(raw.Minute)<0 or int(raw.Minute)>59:return 0
	var stamp: int=Time.get_unix_time_from_datetime_string(text)
	if Time.get_datetime_string_from_unix_time(stamp)!=text:return 0
	return int("%04d%02d%02d%02d%02d" % [int(raw.Year),int(raw.Month),int(raw.Day),int(raw.Hour),int(raw.Minute)])

## A DeleteTime bonus as the local yyyymmddhhmm deadline the client applies,
## or 0 when its representation is not resolved: either a DateTimes_Korean
## reference (BonusApplicationTypeID 298, Value 0) or a direct yyyymmddhh value.
static func delete_time_stamp(row: Dictionary) -> int:
	if row.get("bonus_type",{}).get("Name")!="DeleteTime" or row.get("IsPossession")!=false or row.get("unit",{}).get("Name")!="Time":return 0
	var bonus: Dictionary=row.get("bonus",{})
	if bonus.get("BonusApplicationTypeID")==298 and bonus.get("Value")==0 and integer(bonus.get("BonusApplicationTargetID")):
		return date_value(SOURCE.row("DateTimes_Korean",int(bonus.BonusApplicationTargetID)))
	if direct(row) and integer(bonus.get("Value")) and str(int(bonus.Value)).length()==10:
		var encoded: String=str(int(bonus.Value))
		return date_value({"Year":int(encoded.substr(0,4)),"Month":int(encoded.substr(4,2)),"Day":int(encoded.substr(6,2)),"Hour":int(encoded.substr(8,2)),"Minute":0})
	return 0

static func record(definition: Dictionary) -> Dictionary:
	var raw: Dictionary=definition.get("original_item",{});var category: Dictionary=definition.get("category",{});var grade: Dictionary=definition.get("grade",{})
	if SOURCE.identity().is_empty() or raw.is_empty() or raw.get("TestItem")!=false or definition.get("source_input_identity")!=SOURCE.identity() or SOURCE.row("ItemClass",int(raw.get("ID",0)))!=raw or category.is_empty() or grade.is_empty() or definition.get("excluded",false):return {}
	var item_id: int=int(raw.ID);var display: String=label(raw.get("IdentifiedDescID"))
	if display.is_empty():display=label(raw.get("DescID"))
	var grade_label: String=label(grade.get("DescID"))
	if display.is_empty() or grade_label.is_empty():return {}
	var equips: Array=definition.get("equip_rows",[]);var classes: Array=definition.get("class_rows",[]);var rows: Array=definition.get("item_bonus",[])
	if definition.get("source_reference",{}).get("ok")!=true:return {}
	for row: Dictionary in rows:
		if not row.get("bonus_type",{}).get("Name") is String or not row.get("unit",{}).get("Name") is String or not integer(row.get("ID")) or not integer(row.get("bonus",{}).get("ID")):return {}
	var slot_names: Array=[];var slot_ids: Array=[];var mapped: Dictionary={};var bad_slot: bool=false
	for equip: Dictionary in equips:
		var name_value: String=str(equip.get("equip_slot",{}).get("Name",""))
		slot_names.append(name_value);slot_ids.append(equip.get("EquipSlotID"))
		if not SLOT_MAP.has(name_value) or (name_value=="DominationStone" and equip.get("EquipSlotID")!=293):bad_slot=true
		else:mapped[SLOT_MAP[name_value]]=true
	var equipment: bool=not equips.is_empty() and mapped.size()==1 and not bad_slot
	var slot: String=str(mapped.keys()[0]) if equipment else "material"
	if equips.is_empty():
		if category.get("Name")=="Currency":slot="currency"
		elif category.get("Name")=="Potion" or category.get("IsConsumable")==true:slot="consumable"
	var class_ids: Array=[];var class_names: Array=[];var unresolved_classes: Array=[]
	for entry: Dictionary in classes:
		class_ids.append(entry.get("ClassID"));var source_class_label: String=label(entry.get("class",{}).get("DescID"));class_names.append(source_class_label)
		if source_class_label.is_empty():unresolved_classes.append(entry.get("ClassID"))
	var out: Dictionary={"name":display+" · 원본#"+str(item_id),"source_display_name":display,"source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":item_id,"sourceId":"m523:item:"+str(item_id),"sourceUrl":"","source_m_native_item":true,"source_bless_raw":1,"grade":grade_label,"source_grade_id":grade.ID,"slot":slot,"type":label(category.get("DescID")),"source_category_id":category.ID,"source_category_name":category.Name,"source_test_item":false,"source_is_trash":raw.get("IsTrash",false),"source_label_status":"source_descriptor","source_category_is_activatable":category.get("IsActivatable",false),"source_is_stackable":category.get("IsStackable",false),"source_is_consumable":category.get("IsConsumable",false),"source_weight":raw.get("Weight",0),"source_weight_unit":"unverified_source_units","source_equip_slots":slot_names,"source_equip_slot_ids":slot_ids,"source_equipment_status":"mapped" if equipment else "unsupported_source_slot" if bad_slot else "ambiguous_source_equip_slots" if not equips.is_empty() else "no_source_equip_slot","source_class_ids":class_ids,"source_class_names":class_names,"source_unresolved_class_ids":unresolved_classes,"source_definition_archive":SOURCE.identity(),"source_projection":"current523_original_typed_game_dto_v1","source_original_item":raw.duplicate(true)}
	out["source_icon_id"]=raw.get("IconID",0)
	out["source_sprite_id"]=raw.get("SpriteID",0)
	out["source_sprite_animation_id"]=raw.get("SpriteAnimationID",0)
	out["source_image_status"]="current_original_image_owner_not_observed"
	if str(out.type).is_empty():out.type=category.Name
	if equipment:
		var slot_label: String=label(equips[0].equip_slot.get("DescID"))
		if not slot_label.is_empty():out.type=slot_label
	for suffix: String in ["min","max"]:
		out["source_level_limit_"+suffix]=raw.get("LevelLimit"+suffix.capitalize(),0)
		out["source_max_level_limit_"+suffix]=raw.get("MaxLevelLimit"+suffix.capitalize(),0)
	for key: String in ["Tradable","Storable","Droppable","Deletable"]:
		out[key.to_lower()]=raw.get("Is"+key,false);out["source_is_"+key.to_lower()]=raw.get("Is"+key,false)
	var pending_conditions: Array=[]
	if not str(raw.get("ServiceRegionCode","")).is_empty():pending_conditions.append("source_service_region_context_required")
	for field: String in ["ServerLimitSetID","ServerLimitsetID"]:
		if raw.has(field) and (not integer(raw[field]) or int(raw[field])!=0):pending_conditions.append("source_item_server_context_required")
	for pair: Array in [["StartDateTimeID","source_start_time_raw"],["EndDateTimeID","source_end_time_raw"]]:
		if not raw.has(pair[0]) or raw[pair[0]]==0:continue
		var stamp: int=date_value(SOURCE.row("DateTimes_Korean",int(raw[pair[0]]))) if integer(raw[pair[0]]) else 0
		if stamp<=0:pending_conditions.append("source_item_date_reference_unresolved")
		else:out[pair[1]]=stamp
	var deadlines: Array=[];var delete_unknown: bool=false
	for row: Dictionary in rows:
		if row.bonus_type.Name!="DeleteTime":continue
		var stamp: int=delete_time_stamp(row)
		if stamp<=0:delete_unknown=true
		else:deadlines.append(stamp)
	if delete_unknown:out["source_delete_time_unresolved"]=true
	elif not deadlines.is_empty():deadlines.sort();out["source_delete_time_raw"]=deadlines[0]
	for row: Dictionary in rows:
		if row.bonus_type.Name=="CannotExtendDeleteTime" and direct(row) and row.unit.Name=="TrueFalse" and whole(row.bonus.get("Value"))==1:out["source_cannot_extend_delete_time"]=true
	out["source_condition_pending"]=pending_conditions
	var handled: Dictionary={};var applied: Array=[];var unknown: Array=[]
	for index: int in range(rows.size()):
		var row: Dictionary=rows[index];var name_value: String=str(row.get("bonus_type",{}).get("Name",""));var unit: String=str(row.get("unit",{}).get("Name",""));var amount: Variant=row.get("bonus",{}).get("Value")
		if equipment and name_value in STATUS_BONUS and unit=="Percentage":
			var status: Dictionary=status_field(row)
			if not status.is_empty():
				out[status.field]=int(out.get(status.field,0))+int(status.value);handled[index]=true;applied.append({"item_bonus_id":row.ID,"bonus_id":row.bonus.ID,"field":status.field,"value":status.value,"source_special_resistance_type":status.type,"source_denominator":status.denominator})
			continue
		if not direct(row) or not integer(amount):continue
		if equipment and unit=="Value" and FLAT.has(name_value):
			var field: String=FLAT[name_value];out[field]=int(out.get(field,0))+int(amount);handled[index]=true;applied.append({"item_bonus_id":row.ID,"bonus_id":row.bonus.ID,"field":field,"value":amount})
		elif equipment and unit=="Percentage" and name_value in ["MoveSpeedBonus","AttackSpeedBonus","HPPotionIncreasePercent","ExperienceAdditionPercent"]:
			var field: String={"MoveSpeedBonus":"speed","AttackSpeedBonus":"attackSpeed","HPPotionIncreasePercent":"potionHealPct","ExperienceAdditionPercent":"xp"}[name_value]
			if name_value=="ExperienceAdditionPercent":
				var ui: Array[Dictionary]=SOURCE.related("UIUnit","UnitID",int(row.unit.ID))
				if ui.size()!=1 or ui[0].get("Denominator")!=10000:continue
			var denominator: int=1000000 if name_value in ["MoveSpeedBonus","ExperienceAdditionPercent"] else 10000
			out[field]=float(out.get(field,1.0 if field=="speed" else 0.0))+float(amount)/denominator;handled[index]=true;applied.append({"item_bonus_id":row.ID,"bonus_id":row.bonus.ID,"field":field,"value":float(amount)/denominator,"source_denominator":denominator})
		elif equipment and name_value in ["IsTwoHanded","CanEquipWithTwoHanded"] and unit=="TrueFalse" and int(amount) in [0,1]:
			var field: String="source_is_two_handed" if name_value=="IsTwoHanded" else "source_can_equip_with_two_handed"
			if out.has(field) and out[field]!=bool(amount):return {}
			out[field]=bool(amount);handled[index]=true
		elif equipment and slot=="weapon" and name_value=="WeaponType" and unit=="WeaponTypeID":
			var weapon: Dictionary=SOURCE.row("WeaponType",int(amount));var weapon_label: String=label(weapon.get("DescID"))
			if weapon.is_empty() or weapon_label.is_empty():continue
			if out.has("source_weapon_type_id") and out.source_weapon_type_id!=weapon.ID:return {}
			out.type=weapon_label;out["source_weapon_type_id"]=weapon.ID;out["source_weapon_type_name"]=weapon.Name;handled[index]=true
		elif name_value=="EnchantBonusGroupID" and unit=="EnchantBonusGroupID":
			if not out.has("source_enchant_group_ids"):out["source_enchant_group_ids"]=[]
			out.source_enchant_group_ids.append(int(amount))
	var hp: Dictionary=formula(rows,HP) if category.Name=="Potion" else {}
	if slot=="consumable" and not hp.is_empty():
		hp["kind"]="source_hp_dice";hp["routing_policy"]="heal_is_base_or_positive_indicator_not_expected_value";out["heal_spec"]=hp;out["heal"]=maxi(1,int(hp.get("HPRestoration",0)))
		for index: int in range(rows.size()):
			if rows[index].bonus_type.Name in HP and direct(rows[index]) and rows[index].unit.Name=="Value":handled[index]=true
	var mp: Dictionary=formula(rows,MP)
	if not mp.is_empty():
		var spec: Dictionary=consume_metadata(rows,raw,category)
		spec.merge(mp);spec["kind"]="source_mp_dice";spec["source_snapshot"]="patch523";spec["source_item_class_id"]=item_id;spec["base"]=int(mp.get("MPRestoration",0));spec["dice_number"]=int(mp.get("MPRestorationDiceNumber",0));spec["dice_spot_count"]=int(mp.get("MPRestorationDiceSpotCount",0));spec["source_item_bonus_ids"]=[]
		for row: Dictionary in rows:spec.source_item_bonus_ids.append(row.ID)
		spec["item_requirements"]={"targetting_type_id":raw.get("TargettingTypeID"),"service_region_code":raw.get("ServiceRegionCode",""),"can_use_when_invisible":raw.get("CanUseWhenInvisible",false)}
		spec["activation_status"]="unrestricted" if spec.blocked_reasons.is_empty() else "blocked";out["source_use_spec"]=spec
		if spec.blocked_reasons.is_empty():
			for index: int in range(rows.size()):handled[index]=true
	var timed: Dictionary=timed_buff(definition)
	if not timed.is_empty():
		out["source_use_spec"]=timed
		if timed.get("activation_status")=="unrestricted":
			for index: int in range(rows.size()):handled[index]=true
	var bag: Dictionary=reward_bag(definition)
	if not bag.is_empty():
		out["source_use_spec"]=bag
		if bag.get("activation_status")=="unrestricted":
			for index: int in range(rows.size()):handled[index]=true
	var skill_book: Dictionary=source_skill_book(definition)
	if not skill_book.is_empty():
		out["source_use_spec"]=skill_book
		if skill_book.get("activation_status")=="unrestricted":
			for index: int in range(rows.size()):handled[index]=true
	var selection: Dictionary=selectable_reward(definition)
	if not selection.is_empty():
		out["source_use_spec"]=selection
		if selection.get("activation_status")=="unrestricted":
			for index: int in range(rows.size()):handled[index]=true
	var fixed_card: Dictionary=source_fixed_card(definition)
	if not fixed_card.is_empty():
		out["source_use_spec"]=fixed_card
		if fixed_card.get("activation_status")=="unrestricted":
			for index: int in range(rows.size()):handled[index]=true
	var bless_scroll: Dictionary=source_bless_scroll(definition)
	if not bless_scroll.is_empty():
		out["source_use_spec"]=bless_scroll
		if bless_scroll.get("activation_status")=="unrestricted":
			for index: int in range(rows.size()):handled[index]=true
	var mastery: Dictionary=source_mastery_points(definition)
	if not mastery.is_empty():
		out["source_use_spec"]=mastery
		if mastery.get("activation_status")=="unrestricted":
			for index: int in range(rows.size()):handled[index]=true
	for index: int in range(rows.size()):
		if handled.has(index):continue
		var row: Dictionary=rows[index]
		unknown.append({"item_bonus_id":row.ID,"bonus_id":row.bonus.ID,"bonus_type":row.bonus_type.Name,"reason":"current_original_positive_or_conditional_effect_owner_required"})
	out["source_mapped_bonuses"]=applied;out["source_unhandled_bonuses"]=unknown;out["source_unhandled_bonus_ids"]=[]
	for row: Dictionary in unknown:out.source_unhandled_bonus_ids.append(row.bonus_id)
	out["source_effect_status"]="partial" if not unknown.is_empty() or (slot=="consumable" and not out.has("heal_spec") and not out.has("source_use_spec")) or not unresolved_classes.is_empty() or bad_slot else "represented_source_fields"
	out["source_effect_scope"]="existing_flat_equipment_hp_mp_finite_buff_original_bag_selection_and_book_learning_projection; other_typed_effects_preserved_pending"
	if slot=="consumable" and not out.has("source_use_spec") and not out.has("heal_spec"):out["source_use_spec"]={"kind":"current_source_effect_pending","activation_status":"blocked","blocked_reasons":["current_typed_effect_owner_required"]}
	out["source_catalog_eligible"]=true;out["source_acquisition_policy"]="verified_supplier_only_no_fabricated_supply"
	# Every native record names the same archive; one shared instance instead
	# of ~30,000 copies (records are replaced, never edited in place).
	out["source_definition_archive"]=_archive_identity()
	# source_entities (full original entity graphs) are read only by the
	# original selection claim. Lucky bags are drawn from their rewards and
	# never read their entity graphs, so bags do not keep a copy of them.
	var use_spec: Variant=out.get("source_use_spec")
	if use_spec is Dictionary and use_spec.get("kind") in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]:use_spec.erase("source_entities")
	return out

static var _identity_cache: Dictionary={}
static func _archive_identity() -> Dictionary:
	var current: Dictionary=_inputs().identity()
	if _identity_cache!=current:_identity_cache=current
	return _identity_cache

const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const TEMPLATE_BAKE:="native_item_templates"
const TEMPLATE_SCHEMA:="twilight.current523.native-item-templates.v3"

## The verified original as register() reads it. Production always uses this
## default (SOURCE); standalone tests substitute synthetic rows here.
class RegisterInputs extends RefCounted:
	func identity() -> Dictionary: return SOURCE.identity()
	func verified_key() -> String: return SOURCE.verified_key()
	func row_count(table: String) -> int: return SOURCE.row_count(table)
	func row_at(table: String,index: int) -> Dictionary: return SOURCE.row_at(table,index)
	func declared_exclusion(table: String,row: Dictionary) -> Dictionary: return SOURCE.declared_exclusion(table,row)
static var register_inputs: RegisterInputs=null
static var _default_inputs: RegisterInputs=null
static func _inputs() -> RegisterInputs:
	if register_inputs!=null:return register_inputs
	if _default_inputs==null:_default_inputs=RegisterInputs.new()
	return _default_inputs

## Test-only fault injection for the template writer (never set in
## production): "create", "write:<n>" (the n-th record write fails),
## "finish" (index/close fails), "commit" (publish fails), "reopen" (the
## committed file does not reopen).
static var template_fault: String=""

static func _template_key() -> String:
	return BAKE.key([_inputs().verified_key(),TEMPLATE_SCHEMA,BAKE.global_code_key()])

## Baked native records by ItemClass ID (one var per record, offsets indexed).
class TemplateStore extends RefCounted:
	var file: FileAccess
	var offsets: Dictionary={}
	## One pool for every key and text read back, so ~30,000 decoded records
	## share their strings as the projected records shared their literals.
	var strings: Dictionary={}
	## Interning is for the ~30,000 records registration keeps; later reads
	## (template fields of one item) are short-lived and are not pooled.
	var interning: bool=true
	## The full record (light part + heavy fields, in the original key order).
	func record(id: String) -> Variant:
		if not offsets.has(id):return null
		file.seek(int(offsets[id]))
		var light: Variant=file.get_var()
		var heavy: Variant=file.get_var()
		if not light is Dictionary or not heavy is Dictionary or not heavy.get("keys") is Array or not heavy.get("fields") is Dictionary:return null
		var result: Dictionary={}
		for key: Variant in heavy.keys:
			if (light as Dictionary).has(key):result[key]=light[key]
			elif (heavy.fields as Dictionary).has(key):result[key]=heavy.fields[key]
		return _shared(result) if interning else result
	## The light catalog form (FIELDS.slim() of the record) without decoding
	## the heavy fields.
	func light(id: String) -> Variant:
		if not offsets.has(id):return null
		file.seek(int(offsets[id]))
		var value: Variant=file.get_var()
		if not value is Dictionary:return null
		if (value as Dictionary).is_empty():return value # pending: no native record
		value[FIELDS.MARK]=true
		return _shared(value) if interning else value
	func _shared(value: Variant) -> Variant:
		if value is String:
			var known: Variant=strings.get(value)
			if known==null:strings[value]=value;return value
			return known
		if value is Dictionary:
			var result: Dictionary={}
			for key: Variant in value:result[_shared(key)]=_shared(value[key])
			return result
		if value is Array and not (value as Array).is_typed():
			for index: int in (value as Array).size():value[index]=_shared(value[index])
		return value

## Streams native records into the template bake one at a time. Every step
## reports its result: add() is false once a write failed (the writer then
## stays failed), finish() is {ok, stage} and removes its part file on any
## failure; abort() discards it.
class TemplateWriter extends RefCounted:
	var file: FileAccess
	var part: String=""
	var ids: PackedStringArray=[]
	var positions: PackedInt64Array=[]
	var ok: bool=true
	## Injected fault (tests only; "" in production), see template_fault.
	var fault: String=""
	var fault_at: int=-1
	static func start(injected: String="") -> TemplateWriter:
		var path: String=BAKE.data_path(TEMPLATE_BAKE)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if injected=="create":return null
		var writer:=TemplateWriter.new()
		writer.fault=injected
		writer.part=path+".part"
		writer.file=FileAccess.open(writer.part,FileAccess.WRITE)
		if injected.begins_with("write:"):writer.fault_at=int(injected.trim_prefix("write:"))
		return writer if writer.file!=null else null
	func add(id: String,record: Dictionary) -> bool:
		if not ok or file==null:return false
		var light: Dictionary={};var fields: Dictionary={}
		for key: Variant in record:
			if key in FIELDS.HEAVY:fields[key]=record[key]
			else:light[key]=record[key]
		ids.append(id);positions.append(file.get_position())
		var stored: bool=file.store_var(light)
		stored=file.store_var({"keys":record.keys(),"fields":fields}) and stored
		ok=stored and file.get_error()==OK and ids.size()!=fault_at
		return ok
	func abort() -> void:
		if file!=null:file.close()
		file=null
		if not part.is_empty():DirAccess.remove_absolute(part)
		ok=false
	func finish(value_key: String) -> Dictionary:
		if not ok or file==null:
			abort()
			return {"ok":false,"stage":"write"}
		var index_position: int=file.get_position()
		var stored: bool=file.store_var({"schema":TEMPLATE_SCHEMA,"ids":ids,"offsets":positions})
		stored=file.store_64(index_position) and stored
		stored=stored and file.get_error()==OK and fault!="finish"
		file.close()
		file=null
		if not stored:
			DirAccess.remove_absolute(part)
			return {"ok":false,"stage":"finish"}
		if fault=="commit" or not BAKE.commit_file(TEMPLATE_BAKE,value_key,part):
			DirAccess.remove_absolute(part)
			return {"ok":false,"stage":"commit"}
		return {"ok":true}

static func _open_templates() -> TemplateStore:
	var path: String=BAKE.verified_file(TEMPLATE_BAKE,_template_key())
	if path.is_empty():return null
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<8:return null
	file.seek(file.get_length()-8)
	var index_position: int=file.get_64()
	if index_position<0 or index_position>=file.get_length()-8:return null
	file.seek(index_position)
	var index: Variant=file.get_var()
	if not index is Dictionary or index.get("schema")!=TEMPLATE_SCHEMA or not index.get("ids") is PackedStringArray or not index.get("offsets") is PackedInt64Array or (index.ids as PackedStringArray).size()!=(index.offsets as PackedInt64Array).size():return null
	var store:=TemplateStore.new()
	store.file=file
	for position: int in (index.ids as PackedStringArray).size():store.offsets[index.ids[position]]=index.offsets[position]
	return store

## Template store failure of this process, keyed by the template key: the
## same failed cold pass is not repeated by the second registration of this
## start (it is retried on the next start, or after clear_template_failure()).
static var _template_failure: Dictionary={}
static func template_problem() -> String:
	return str(_template_failure.get("message",""))
static func clear_template_failure() -> void:
	_template_failure={}

## Safe stop of a cold registration whose template bake could not be created,
## written, committed or reopened. The catalog and document are left exactly
## as they were (no native record is published without a readable template,
## and no full record is kept as a resident fallback); saved items, their
## quantity and enhancement are not touched. The partial file is removed.
static func _template_stop(stage: String,writer: TemplateWriter,identity: Dictionary,value_key: String) -> Dictionary:
	if writer!=null:writer.abort()
	# A commit that failed half way may have left an unpublished data file.
	if stage=="commit":BAKE.clear(TEMPLATE_BAKE)
	var message: String="원본 아이템 템플릿을 기기 저장소에 만들지 못했습니다(단계: "+stage+"). 저장 공간과 쓰기 권한을 확인한 뒤 게임을 다시 시작하면 다시 시도합니다. 보유 아이템·수량·강화 상태는 변경하지 않았습니다."
	_template_failure={"key":value_key,"stage":stage,"message":message}
	print("CURRENT523_NATIVE_TEMPLATE_STORE_STOPPED "+JSON.stringify({"stage":stage}))
	return {"ok":false,"reason":"native_item_template_store_failed","stage":stage,"message":message,"retry":"next_start","source_definition_archive":identity,"ownership_changed":false,"executed_gameplay":false}

const BOOT_LOG=preload("res://scripts/boot/boot_progress_log.gd")
## Boot progress wrapper: one begin/end line around the whole registration.
static func register(owner: Script,catalog: Dictionary,document: Dictionary) -> Dictionary:
	var boot_started: int=BOOT_LOG.begin("item_register",{})
	var result: Dictionary=_register_logged(owner,catalog,document)
	BOOT_LOG.end("item_register",boot_started,{"ok":bool(result.get("ok",false)),"reason":str(result.get("reason",""))})
	return result
static func _register_logged(owner: Script,catalog: Dictionary,document: Dictionary) -> Dictionary:
	var src: RegisterInputs=_inputs()
	if src.identity().is_empty() or not catalog.get("아이템",[]) is Array:return {"ok":false,"reason":"current_original_catalog_input_unavailable"}
	# World._load_data registers through the drop owner and again through the
	# craft catalog with the same inputs. The pass is deterministic and only
	# replaces native records with themselves, so an identical second pass on
	# the same catalog reuses the first result instead of describing ~34,700
	# items again (about 80 s on desktop, far longer on a phone).
	var contract: Variant=catalog.get("patch523_crafting_catalog_contract",{})
	if contract is Dictionary and contract.get("mode")=="current_original_native_projection" and contract.get("source_definition_archive")==src.identity() and document.get("native_item_ids")==contract.get("registered_definition_ids") and document.get("current_registration_pending")==contract.get("pending"):
		var registered: int=0
		for record: Variant in catalog.get("아이템",[]):
			if record is Dictionary and record.get("source_m_native_item")==true and record.get("source_definition_archive")==src.identity():registered+=1
		if registered>=int(document.get("current_native_registered_count",-1)):
			return {"ok":true,"registered_count":int(document.current_native_registered_count),"pending":contract.pending.duplicate(),"source_definition_archive":src.identity(),"ownership_changed":false,"executed_gameplay":false,"reused_registration":true}
	# TWILIGHT_NATIVE_FIELDS_EAGER=1 keeps full records resident (comparison/escape hatch).
	var lazy: bool=OS.get_environment("TWILIGHT_NATIVE_FIELDS_EAGER")!="1"
	# Item templates (Lineage M style): every native record is a pure function
	# of the verified original and this code, so it is baked once on the
	# device and read back by ID on later starts instead of describing every
	# item again. Any code/data change or damaged file rebuilds the bake.
	var templates: TemplateStore=_open_templates()
	var value_key: String=_template_key()
	if templates==null and lazy and not _template_failure.is_empty() and _template_failure.get("key")==value_key:
		return _template_stop(str(_template_failure.stage),null,src.identity(),value_key)
	var writer: TemplateWriter=null if templates!=null else TemplateWriter.start(template_fault)
	if templates==null and writer==null and lazy:return _template_stop("create",null,src.identity(),value_key)
	# Records are replaced, never edited in place, so a shallow copy keeps the
	# input catalog untouched without a second deep copy of every record.
	var records: Array=catalog.get("아이템",[]).duplicate(false);var positions: Dictionary={};var pending: Dictionary={};var admitted: Array=[]
	for index: int in range(records.size()):
		if not records[index] is Dictionary:continue
		var key: String=str(records[index].get("sourceId",""))
		if not positions.has(key):positions[key]=[]
		positions[key].append(index)
	# The owner caches a full original description per item. Registering all
	# ~34,700 ItemClass rows kept every description (~185 KB each in memory),
	# >6 GB, and Android killed the game for LOW_MEMORY. Only the projected
	# record is needed here; descriptions this loop created are dropped again
	# and rebuilt on demand by definition_id(). Entries cached before (drop and
	# reward items) stay.
	# The owner keeps only a bounded definition cache plus an index of IDs
	# read before; its accessors answer exactly as the former dictionaries.
	var indexed: bool=owner.has_method("has_definition") and owner.has_method("transient_definition")
	var cache: Dictionary=owner.call("data") if not indexed else {}
	var references: Dictionary=cache.get("source_item_references",{})
	var definitions: Dictionary=cache.get("item_definitions",{})
	var placed: Array[int]=[]
	# Cold pass (no readable template): each record is built, written to the
	# template part file and immediately reduced to its light form, so at most
	# one full record is alive at a time (the batch is one record); the full
	# record is never kept until the end of the loop. The light records stay
	# local (`records`) and are published only after the template file is
	# committed, reopened and checked to hold every written ID. Their display
	# names (a template field) are kept beside them for identity comparisons
	# against later rows of this same pass, until the pass ends.
	var staged_display: Dictionary={}
	# Light baked records below are read through FIELDS.field(), so their
	# templates are reachable while registering (bound again after the loop).
	if templates!=null and lazy:FIELDS.bind(templates)
	# Rows are streamed from the packed reader, not materialized all at once.
	for row_index: int in src.row_count("ItemClass"):
		var raw: Dictionary=src.row_at("ItemClass",row_index)
		if not integer(raw.get("ID")) or int(raw.ID)<=0 or raw.get("TestItem")!=false or not src.declared_exclusion("ItemClass",raw).is_empty():continue
		var id: String=str(int(raw.ID));var cached: bool=bool(owner.call("has_definition",id)) if indexed else (references.has(id) or definitions.has(id))
		var current: Dictionary={}
		var built: bool=false
		var baked: Variant=(templates.light(id) if lazy else templates.record(id)) if templates!=null else null
		if baked is Dictionary:
			current=baked
			if current.get("source_definition_archive")==_archive_identity():current["source_definition_archive"]=_archive_identity()
		else:
			# An ID not read before is built without being remembered (the
			# former read-then-erase), so the bounded cache keeps its entries.
			var definition: Dictionary=owner.call("definition_id",id) if cached or not indexed else owner.call("transient_definition",id)
			current=definition.get("native_record",{})
			definition={}
			if not cached and not indexed:
				references.erase(id);definitions.erase(id)
			if writer!=null and not writer.add(id,current):
				if lazy:return _template_stop("write",writer,src.identity(),value_key)
				# Eager comparison mode keeps full records anyway; it only
				# loses the bake, as before.
				writer.abort();writer=null
			built=writer!=null and lazy
		if current.is_empty():pending[id]="current_native_dto_unavailable";continue
		var key: String=str(current.sourceId);var previous: Array=positions.get(key,[])
		if previous.size()>1:pending[id]="ambiguous_registered_source_identity";continue
		if previous.size()==1:
			var saved: Dictionary=records[int(previous[0])]
			var typed_supply: bool=saved.get("source_current523_awakening_supply")==true and saved.get("source_item")==raw and saved.get("source_definition_archive")==src.identity()
			if typed_supply:admitted.append(id);continue
			var saved_display: Variant=staged_display[int(previous[0])] if staged_display.has(int(previous[0])) else FIELDS.field(saved,"source_display_name")
			if saved.get("source")!="lineagem_patch523" or saved.get("source_snapshot")!="patch523" or saved.get("source_item_class_id")!=raw.ID or saved.get("source_m_native_item")!=true or saved.get("name")!=current.name or saved_display!=FIELDS.field(current,"source_display_name"):
				pending[id]="unverified_registered_source_identity_preserved";continue
			records[int(previous[0])]=_placed(current,cached,built)
			if built:staged_display[int(previous[0])]=FIELDS.field(current,"source_display_name")
			else:staged_display.erase(int(previous[0]))
			placed.append(int(previous[0]))
		else:
			records.append(_placed(current,cached,built));positions[key]=[records.size()-1]
			if built:staged_display[records.size()-1]=FIELDS.field(current,"source_display_name")
			placed.append(records.size()-1)
		admitted.append(id)
		current={}
	staged_display={}
	var store: TemplateStore=templates
	if writer!=null:
		var finished: Dictionary=writer.finish(value_key)
		if not finished.ok and lazy:return _template_stop(str(finished.stage),writer,src.identity(),value_key)
		store=_open_templates() if finished.ok and template_fault!="reopen" else null
		# Two-phase publish: the light records built above are exposed only
		# when the committed template file reopens and holds every written ID.
		if lazy:
			var readable: bool=store!=null
			if readable:
				for written: String in writer.ids:
					if not store.offsets.has(written):readable=false;break
			if not readable:
				store=null
				BAKE.clear(TEMPLATE_BAKE)
				return _template_stop("reopen",null,src.identity(),value_key)
	elif templates==null:store=_open_templates()
	_template_failure={}
	# The catalog keeps the light identity of each record just registered; its
	# heavy fields are read from the baked template when used (FIELDS.full()).
	if store!=null:
		store.interning=false
		store.strings.clear()
	if store!=null and lazy:
		FIELDS.bind(store)
		for index: int in placed:
			if not FIELDS.lazy(records[index]):records[index]=FIELDS.slim(records[index])
	catalog["아이템"]=records
	catalog["patch523_crafting_catalog_contract"]={"mode":"current_original_native_projection","source_definition_archive":src.identity(),"registered_definition_ids":admitted.duplicate(),"normal_ids":admitted.size(),"pending":pending.duplicate(),"full_native_coverage_observed":false}
	document["native_item_ids"]=admitted.duplicate();document["current_registration_pending"]=pending.duplicate();document["current_native_registered_count"]=admitted.size()
	return {"ok":true,"registered_count":admitted.size(),"pending":pending,"source_definition_archive":src.identity(),"ownership_changed":false,"executed_gameplay":false}

## The record registration places in the catalog: a cold-built record is
## reduced to its light form at once (FIELDS.slim(), as the former end-of-loop
## pass did); a cached owner definition is never shared with the catalog.
static func _placed(current: Dictionary,cached: bool,built: bool) -> Dictionary:
	if built:
		var light: Dictionary=FIELDS.slim(current)
		return light.duplicate(true) if cached else light
	return current.duplicate(true) if cached else current

# Existing equipment stat consumer, evaluated from the same current original
# ItemEnchantBonus/Bonus/BonusType/Unit rows as the public compiler. Saved item
# identity and enhancement level remain with the existing physical owner.
static func enchant_stats(item: Dictionary,level: int,bless: int) -> Dictionary:
	item=FIELDS.full(item)
	var id: Variant=item.get("source_item_class_id")
	if not integer(id) or int(id)<=0 or level<0 or bless not in [1,2,3] or item.get("source_projection")!="current523_original_typed_game_dto_v1" or item.get("source_definition_archive")!=SOURCE.identity() or item.get("source_original_item")!=SOURCE.row("ItemClass",int(id)):return {}
	var names: Dictionary={"WeaponHitBonus":"accuracy","WeaponDamageBonus":"damage","ArmorClass":"defense","ArmorClassBonus":"defense","HPPlus":"hp","MPPlus":"mp","MagicResist":"mr","SpellPower":"sp","DamageReduction":"reduction","MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","MeleeHit":"melee_accuracy","RangeHit":"ranged_accuracy","MagicHit":"magic_accuracy","Strength":"str","Dexterity":"dex","Constitution":"con","Intelligence":"int","Wisdom":"wis","Charisma":"cha","HPPotionIncreaseStatic":"potion_heal_flat"}
	var result: Dictionary={}
	for group: Variant in item.get("source_enchant_group_ids",[]):
		if not integer(group) or int(group)<=0:continue
		for row: Dictionary in SOURCE.related("ItemEnchantBonus","ItemEnchantBonusGroupID",int(group)):
			if not SOURCE.declared_exclusion("ItemEnchantBonus",row).is_empty() or row.get("EnchantLevel")!=level or whole(row.get("BlessCode")) not in [0,bless]:continue
			if not integer(row.get("BonusID")):continue
			var bonus: Dictionary=SOURCE.row("Bonus",int(row.BonusID))
			if not SOURCE.declared_exclusion("Bonus",bonus).is_empty() or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or not integer(bonus.get("BonusTypeID")) or not integer(bonus.get("Value")):continue
			var kind: Dictionary=SOURCE.row("BonusType",int(bonus.BonusTypeID))
			if not integer(kind.get("UnitID")):continue
			var unit: Dictionary=SOURCE.row("Unit",int(kind.UnitID))
			var stat: String=str(names.get(str(kind.get("Name","")),"")) if unit.get("Name")=="Value" else ""
			var divisor: int=1
			if kind.get("Name")=="HPPotionIncreasePercent" and unit.get("Name")=="Percentage":stat="potion_heal_pct";divisor=10000
			if not stat.is_empty():result[stat]=float(result.get(stat,0.0))+float(bonus.Value)/divisor
	return result

# Port of the already-public _timed_buff_spec. The original read graph is
# supplied by ItemData -> current523_buff_data; no duplicate table loader.
static func timed_buff(definition: Dictionary) -> Dictionary:
	var rows: Array=definition.get("item_bonus",[]);var references: Array=[]
	for row: Dictionary in rows:
		if row.get("bonus_type",{}).get("Name")=="BuffClassID":references.append(row)
	if references.size()!=1 or references[0].get("unit",{}).get("Name")!="BuffClassID" or not integer(references[0].get("bonus",{}).get("Value")):return {}
	var id: int=int(references[0].bonus.Value);var graphs: Array=[]
	for reference: Dictionary in definition.get("source_typed_references",[]):
		if reference.get("item_bonus_id")==references[0].get("ID") and reference.get("id")==id and reference.get("buff_definition") is Dictionary:graphs.append(reference.buff_definition)
	if graphs.size()!=1:return {}
	var graph: Dictionary=graphs[0]
	if graph.get("source")!=SOURCE.identity() or graph.get("ok")!=true or graph.get("excluded",false):return {}
	var buff: Dictionary=graph.get("buff_class",{});var group: Dictionary=graph.get("group",{})
	if buff.get("ID")!=id or group.get("ID")!=buff.get("BuffGroupID") or not SOURCE.declared_exclusion("BuffClass",buff).is_empty() or not SOURCE.declared_exclusion("BuffGroup",group).is_empty():return {}
	var raw: Dictionary=definition.original_item
	var spec: Dictionary=consume_metadata(rows,raw,definition.category,{"BuffClassID":"BuffClassID","BuffDuration":"Seconds","ItemConsumeDelay":"MilliSeconds","ItemConsumeEffectSpriteID":"SpriteID"})
	var reasons: Array=spec.blocked_reasons;var durations: Array=[]
	for row: Dictionary in rows:
		if row.bonus_type.Name=="BuffDuration" and direct(row) and row.unit.Name=="Seconds" and integer(row.bonus.get("Value")):durations.append(int(row.bonus.Value))
	var duration: int=int(durations[0]) if durations.size()==1 else 0
	if duration<=0:reasons.append("missing_or_ambiguous_positive_duration")
	var fields: Dictionary={"ArmorClass":"def","ArmorClassBonus":"def","Strength":"strFlat","Dexterity":"dexFlat","Constitution":"conFlat","Intelligence":"intFlat","Wisdom":"wisFlat","Charisma":"chaFlat","HPPlus":"hp_flat","MPPlus":"mp_flat","MagicResist":"mr","DamageReduction":"damage_reduction","SpellPower":"sp","MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","MagicDamage":"magic_damage","MeleeHit":"melee_accuracy","RangeHit":"ranged_accuracy","MagicHit":"magic_accuracy","PVEDamageReduction":"pve_damage_reduction","PVPDamageReduction":"pvp_damage_reduction"}
	# Percentage effects the existing buff consumers read as whole percent
	# points: the original value over its UIUnit Denominator (10000), e.g.
	# ExperienceAdditionPercent 100000 = 10 %. A fraction of a point is not
	# truncated; that effect stays unsupported.
	var percent_fields: Dictionary={"ExperienceAdditionPercent":"xp","MoveSpeedBonus":"move_speed","AttackSpeedBonus":"attack_speed"}
	var linked: Array=[];var typed: Dictionary={}
	for effect: Dictionary in graph.get("bonuses",[]):
		var row: Dictionary=effect.get("link",{}).duplicate(true);var bonus: Dictionary=effect.get("bonus",{});var kind: Dictionary=effect.get("type",{});var unit: Dictionary=effect.get("unit",{})
		row["bonus"]=bonus;row["bonus_type"]=kind;row["unit"]=unit;linked.append(row)
		if not SOURCE.declared_exclusion("BuffBonus",effect.get("link",{})).is_empty() or not SOURCE.declared_exclusion("Bonus",bonus).is_empty() or not SOURCE.declared_exclusion("BonusType",kind).is_empty():reasons.append("source_declared_buff_effect_exclusion");continue
		var conditional: bool=bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0
		for key: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
			if row.get(key)!=0:conditional=true
		var name_value: String=str(kind.get("Name",""))
		if conditional:reasons.append("conditional_buff_effect:"+name_value)
		elif percent_fields.has(name_value) and unit.get("Name")=="Percentage" and integer(bonus.get("Value")):
			var scale: Array[Dictionary]=SOURCE.related("UIUnit","UnitID",int(unit.get("ID",-1)))
			if scale.size()!=1 or whole(scale[0].get("Denominator"))!=10000 or int(bonus.Value)%10000!=0:reasons.append("unsupported_buff_effect:"+name_value)
			else:typed[percent_fields[name_value]]=int(typed.get(percent_fields[name_value],0))+int(bonus.Value)/10000
		elif unit.get("Name")!="Value" or not integer(bonus.get("Value")) or not fields.has(name_value):reasons.append("unsupported_buff_effect:"+name_value)
		else:typed[fields[name_value]]=int(typed.get(fields[name_value],0))+int(bonus.Value)
	if linked.is_empty() or typed.is_empty():reasons.append("no_supported_buff_effects")
	if buff.get("IsGood")!=true or buff.get("IsBuffGroup")!=true:reasons.append("unsupported_buff_kind")
	if buff.get("IsEraseOnTimeEnd")!=true:reasons.append("source_buff_timer_semantics_unresolved")
	for key: String in ["IsEraseOnAttack","IsEraseOnAttacked","IsEraseOnMove","IsEraseOnSpellCastAndShieldIt","IsEraseOnSkillCastAndShieldIt","IsEraseOnItemUse","IsEraseOnSpellAttacked","IsEraseOnSkillAttacked","IsEraseOnCast","IsEraseOnHealed","IsEraseOnTargetChanged","IsEraseOnAttackedLimitations"]:
		if buff.get(key,0):reasons.append("unsupported_buff_action_rule:"+key)
	for key: String in ["MaxHPPercent","EraseOnLevel","MaxStackCount","MPCostPercent","MinMPCost","IsAbsoluteTimeBuff","IsOverlapByPlayer","IsDecreaseStackOnTimeEnd","IsObtainItemBuff"]:
		if buff.get(key,0):reasons.append("unsupported_buff_state_rule:"+key)
	if group.get("IsAllowPriority")!=false or group.get("IsEraseBySpellLevel")!=false or buff.get("BuffGroupPriority")!=1:reasons.append("unsupported_buff_priority_or_spell_level_rule")
	if not group.get("IsAllowOverlap") is bool or not buff.get("IsImmuneToDead") is bool or not buff.get("IsImmuneToCancellation") is bool:reasons.append("missing_buff_lifecycle_flags")
	var unique: Array=[]
	for reason: String in reasons:
		if reason not in unique:unique.append(reason)
	spec["kind"]="source_timed_buff";spec["source_snapshot"]="patch523";spec["source_item_class_id"]=int(raw.ID);spec["buff_class_id"]=id;spec["duration_seconds"]=duration;spec["typed_effects"]=typed;spec["source_buff_class"]=buff.duplicate(true);spec["source_buff_group"]=group.duplicate(true);spec["source_buff_bonus"]=linked
	spec["source_item_bonus_ids"]=[]
	for row: Dictionary in rows:spec.source_item_bonus_ids.append(row.ID)
	spec["item_requirements"]={"targetting_type_id":raw.get("TargettingTypeID"),"service_region_code":raw.get("ServiceRegionCode",""),"can_use_when_invisible":raw.get("CanUseWhenInvisible",false)}
	spec["activation_status"]="unrestricted" if unique.is_empty() else "blocked";spec["blocked_reasons"]=unique
	return spec

# Same public compiler _source_reward_bag_spec contract, supplied by the
# existing ItemData -> RewardData graph. This does not grant any reward.
static func reward_bag(definition: Dictionary) -> Dictionary:
	var rows: Array=definition.get("item_bonus",[]);var refs: Array=[]
	for row: Dictionary in rows:
		if row.get("bonus_type",{}).get("Name")=="LuckyBagClassID":refs.append(row)
	if refs.size()!=1 or refs[0].get("unit",{}).get("Name")!="LuckyBagClassID" or not integer(refs[0].get("bonus",{}).get("Value")):return {}
	var id: int=int(refs[0].bonus.Value);var graphs: Array=[]
	for reference: Dictionary in definition.get("source_typed_references",[]):
		if reference.get("item_bonus_id")==refs[0].ID and reference.get("id")==id and reference.get("bag") is Dictionary:graphs.append(reference.bag)
	if graphs.size()!=1:return {}
	var graph: Dictionary=graphs[0];var bag: Dictionary=graph.get("lucky_bag_class",{})
	if graph.get("identity")!=SOURCE.identity() or graph.get("join_complete")!=true or bag.get("ID")!=id or graph.get("entities",[]).is_empty() or not SOURCE.declared_exclusion("LuckyBagClass",bag).is_empty():return {}
	var spec: Dictionary=consume_metadata(rows,definition.original_item,definition.category,{"LuckyBagClassID":"LuckyBagClassID"},false)
	if spec.get("consume_delay_ms")==null:spec.erase("consume_delay_ms")
	var reasons: Array=spec.blocked_reasons;var distribution: Array=[];var active: Dictionary={};var domain: Array=[]
	for row: Dictionary in SOURCE.rows("Class"):
		if integer(row.get("ID")) and int(row.ID)>0 and row.get("CanCreateClient")==true:active[int(row.ID)]=row
	for row: Dictionary in definition.get("class_rows",[]):
		if not integer(row.get("ClassID")):distribution.append("unsupported_lucky_bag_root_class");continue
		if int(row.ClassID) not in domain:domain.append(int(row.ClassID))
	if domain.is_empty():domain=active.keys()
	domain.sort()
	for class_id: int in domain:
		if not active.has(class_id):distribution.append("unsupported_lucky_bag_root_class")
	var rewards: Array=[];var linked: Array=[];var types: Dictionary={};var weighted: Array=[]
	for entity: Dictionary in graph.entities:
		var row: Dictionary=entity.get("row",{});var type: Dictionary=entity.get("entity_type",{});var item: Dictionary=entity.get("item_class",{})
		if not integer(row.get("LuckyBagEntityTypeID")) or int(row.LuckyBagEntityTypeID) not in [0,1]:return {}
		var kind: int=int(row.LuckyBagEntityTypeID);types[kind]=true
		if type.get("ID")!=kind or type.get("Name")!=({0:"Probability",1:"IsGiven"}[kind]):distribution.append("unsupported_lucky_bag_entity_type")
		if not SOURCE.declared_exclusion("LuckyBagEntityView",row).is_empty() or not SOURCE.declared_exclusion("LuckyBagEntityType",type).is_empty():reasons.append("source_declared_bag_entity_exclusion")
		var classes: Array=[];var limits: Array=[]
		for limit: Dictionary in entity.get("class_limits",[]):
			var raw: Dictionary=limit.get("row",{});var character: Dictionary=limit.get("character_class",{})
			if not integer(raw.get("ClassID")) or character.get("ID")!=raw.get("ClassID"):distribution.append("unsupported_lucky_bag_entity_class");continue
			classes.append(int(raw.ClassID));var original: Dictionary=raw.duplicate(true);original["class"]=character;limits.append(original)
		if (row.get("LimitClass")==10000 and not classes.is_empty()) or (row.get("LimitClass")!=10000 and whole(row.get("LimitClass")) not in classes):distribution.append("unresolved_lucky_bag_class_limit")
		for class_id: int in classes:
			if not active.has(class_id):distribution.append("unsupported_lucky_bag_entity_class")
		var eligible: bool=classes.is_empty()
		for class_id: int in classes:
			if class_id in domain:eligible=true
		var positive: bool=kind==1 or (integer(row.get("Probability")) and int(row.Probability)>0)
		if eligible and positive and (item.get("TestItem")!=false or not SOURCE.declared_exclusion("ItemClass",item).is_empty()):reasons.append("source_test_or_excluded_reward_item")
		var enchant: Variant=row.get("ItemEnchant");var level_ok: bool=integer(enchant) and int(enchant)>=0
		if level_ok and int(enchant)>0:
			var slots: Dictionary={};var equip_rows: Array=SOURCE.related("ItemEquipSlot","ItemClassID",int(item.get("ID",0)))
			if equip_rows.is_empty():level_ok=false
			for equip: Dictionary in equip_rows:
				var slot: Dictionary=SOURCE.row("EquipSlot",int(equip.get("EquipSlotID",-1)));var name_value: String=str(slot.get("Name",""));slots[equip.get("EquipSlotID")]=true
				if not SLOT_MAP.has(name_value) or (name_value=="DominationStone" and equip.get("EquipSlotID")!=293):level_ok=false
			if slots.size()!=1:level_ok=false
		if not integer(row.get("ItemAmount")) or int(row.ItemAmount)<1 or whole(row.get("ItemBlessCodeID")) not in [1,2,3] or not level_ok:reasons.append("unsupported_lucky_bag_reward_amount_or_variant")
		var original: Dictionary=row.duplicate(true);original["entity_type"]=type.duplicate(true);original["class_limits"]=limits;linked.append(original)
		var reward: Dictionary={"source_entity_id":row.get("ID"),"item_class_id":row.get("ItemClassID"),"amount":row.get("ItemAmount"),"bless_raw":row.get("ItemBlessCodeID"),"enchant":enchant,"class_ids":classes,"entity_type_id":kind,"entity_type":type.get("Name"),"probability_raw":row.get("Probability")}
		rewards.append(reward)
		if kind==0:weighted.append(reward)
	var totals: Dictionary={}
	if not weighted.is_empty():
		if domain.is_empty():distribution.append("unresolved_lucky_bag_source_class_scope")
		for reward: Dictionary in weighted:
			if not integer(reward.probability_raw) or int(reward.probability_raw)<0:distribution.append("invalid_lucky_bag_probability")
		for class_id: int in domain:
			var total: int=0
			for reward: Dictionary in weighted:
				if (reward.class_ids.is_empty() or class_id in reward.class_ids) and integer(reward.probability_raw) and int(reward.probability_raw)>=0:total+=int(reward.probability_raw)
			totals[str(class_id)]=total
			if total!=10000000:distribution.append("incomplete_lucky_bag_probability_for_class:"+str(class_id))
	var unique: Array=[]
	for reason: String in reasons+distribution:
		if reason not in unique:unique.append(reason)
	spec["kind"]="guaranteed_bag" if weighted.is_empty() else ("source_weighted_bag" if types.size()==1 else "mixed_rewards_bag")
	spec["source_snapshot"]="patch523";spec["source_item_class_id"]=definition.original_item.ID;spec["lucky_bag_class_id"]=id;spec["original_lucky_bag_class"]=bag.duplicate(true);spec["source_entities"]=linked;spec["rewards"]=rewards;spec["source_item_bonus_ids"]=[]
	for row: Dictionary in rows:spec.source_item_bonus_ids.append(row.ID)
	spec["item_requirements"]={"targetting_type_id":definition.original_item.get("TargettingTypeID"),"service_region_code":definition.original_item.get("ServiceRegionCode",""),"can_use_when_invisible":definition.original_item.get("CanUseWhenInvisible",false)}
	spec["activation_status"]="unrestricted" if unique.is_empty() else "blocked";spec["blocked_reasons"]=unique
	if not weighted.is_empty():
		spec["class_probability_totals"]=totals;spec["source_class_domain"]=domain;spec["source_class_domain_origin"]="ItemClassLimit" if not definition.get("class_rows",[]).is_empty() else "Class.CanCreateClient";spec["reward_selection_model"]="local_single_weighted_draw";spec["random_draw_count"]=1;spec["draw_count_origin"]="local_policy_not_source_count";spec["selection_configuration_key"]="patch523_reward_bag_draw_count"
		if distribution.is_empty():spec["source_probability_denominator"]=10000000
	return spec

static func selectable_rule(node: Dictionary,active: Dictionary,reasons: Array) -> void:
	var row: Dictionary=node.get("row",{})
	for pair: Array in [["RewardGetTimeTypeID",1],["RewardEnhancementTypeID",1],["Ranking",0]]:
		if not integer(row.get(pair[0])) or int(row[pair[0]])!=pair[1]:reasons.append("unsupported_select_reward_rule:"+pair[0])
	for key: String in ["UseImmediately","ClanOnly"]:
		if not row.get(key) is bool or row[key]!=false:reasons.append("unsupported_select_reward_rule:"+key)
	if not node.get("attributes",[]).is_empty():reasons.append("unsupported_select_reward_attributes")
	var id: Variant=row.get("CharacterClassID")
	if not integer(id) or (int(id)!=0 and not active.has(int(id))):reasons.append("unsupported_select_reward_class")
	if node.get("excluded",false) or not SOURCE.declared_exclusion("Reward",row).is_empty():reasons.append("source_excluded_select_reward")

static func selectable_reward(definition: Dictionary) -> Dictionary:
	var rows: Array=definition.get("item_bonus",[]);var refs: Array=[]
	for row: Dictionary in rows:
		if row.get("bonus_type",{}).get("Name")=="SelectRewardClassID":refs.append(row)
	if refs.size()!=1 or not integer(refs[0].get("bonus",{}).get("Value")):return {}
	var id: int=int(refs[0].bonus.Value);var graphs: Array=[]
	for reference: Dictionary in definition.get("source_typed_references",[]):
		if reference.get("item_bonus_id")==refs[0].ID and reference.get("id")==id and reference.get("reward") is Dictionary:graphs.append(reference.reward)
	if graphs.size()!=1:return {}
	var graph: Dictionary=graphs[0]
	if graph.get("identity")!=SOURCE.identity() or graph.get("join_complete")!=true:return {}
	var root_node: Dictionary=graph.get("rewards",{}).get(str(id),{});var root: Dictionary=root_node.get("row",{})
	if root.get("ID")!=id:return {}
	var spec: Dictionary=consume_metadata(rows,definition.original_item,definition.category,{"SelectRewardClassID":"RewardID"},false)
	if spec.get("consume_delay_ms")==null:spec.erase("consume_delay_ms")
	var reasons: Array=spec.blocked_reasons;var active: Dictionary={};var domain: Array=[]
	for row: Dictionary in SOURCE.rows("Class"):
		if integer(row.get("ID")) and int(row.ID)>0 and row.get("CanCreateClient")==true:active[int(row.ID)]=row
	for row: Dictionary in definition.get("class_rows",[]):
		if integer(row.get("ClassID")) and int(row.ClassID) not in domain:domain.append(int(row.ClassID))
	if domain.is_empty():domain=active.keys()
	domain.sort()
	if domain.is_empty():reasons.append("unsupported_select_reward_root_class")
	for class_id: int in domain:
		if not active.has(class_id):reasons.append("unsupported_select_reward_root_class")
	selectable_rule(root_node,active,reasons)
	var selection: Dictionary={};var linked: Array=[];var rewards: Array=[];var initial_rule: bool=false
	if root_node.get("reward_type",{}).get("ID")!=111 or root_node.get("reward_type",{}).get("Name")!="SelectReward":reasons.append("unsupported_select_reward_root_type")
	else:
		var selected_node: Dictionary=graph.get("selections",{}).get(str(int(root.get("RewardClassID",0))),{})
		selection=selected_node.get("row",{})
		if selected_node.get("excluded",false) or not SOURCE.declared_exclusion("SelectReward",selection).is_empty():reasons.append("source_excluded_select_reward_group")
		if not integer(selection.get("SelectMaxCount")) or int(selection.SelectMaxCount)!=1:reasons.append("unsupported_select_reward_max_count")
		if selected_node.get("entities",[]).is_empty():reasons.append("empty_select_reward")
		for edge: Dictionary in selected_node.get("entities",[]):
			var entity: Dictionary=edge.get("row",{});var child: Dictionary=graph.get("rewards",{}).get(str(int(entity.get("RewardID",0))),{});var row: Dictionary=child.get("row",{})
			if edge.get("excluded",false) or not SOURCE.declared_exclusion("SelectRewardEntity",entity).is_empty():reasons.append("source_excluded_select_reward_entity")
			selectable_rule(child,active,reasons)
			var original: Dictionary=entity.duplicate(true);var detail: Dictionary=row.duplicate(true);detail["reward_type"]=child.get("reward_type",{});detail["character_class"]=child.get("character_class",{});detail["attributes"]=child.get("attributes",[]);original["reward"]=detail;linked.append(original)
			if child.get("reward_type",{}).get("ID")!=2 or child.get("reward_type",{}).get("Name")!="Item":reasons.append("unsupported_select_reward_output_type");continue
			var item: Dictionary=child.get("item_class",{});var class_ids: Array=[]
			if integer(row.get("CharacterClassID")) and int(row.CharacterClassID)!=0:class_ids.append(int(row.CharacterClassID))
			var eligible: bool=false
			for class_id: int in domain:
				if (class_ids.is_empty() or class_id in class_ids) and (root.get("CharacterClassID")==0 or root.get("CharacterClassID")==class_id):eligible=true
			if eligible and (item.get("TestItem")!=false or child.get("excluded",false) or not SOURCE.declared_exclusion("ItemClass",item).is_empty()):reasons.append("source_test_or_excluded_reward_item")
			if not integer(row.get("Amount")) or int(row.Amount)<1 or whole(row.get("ItemBlessCodeID")) not in [1,2,3]:reasons.append("unsupported_select_reward_amount_or_variant")
			var needs: bool=not SOURCE.related("ItemEquipSlot","ItemClassID",int(item.get("ID",0))).is_empty();initial_rule=initial_rule or needs
			rewards.append({"source_entity_id":entity.get("ID"),"reward_id":row.get("ID"),"item_class_id":item.get("ID"),"amount":row.get("Amount"),"bless_raw":row.get("ItemBlessCodeID"),"class_ids":class_ids,"enchant":null,"enchant_origin":"source_reward_has_no_initial_enchant_field","requires_local_initial_enchant_rule":needs})
	var counts: Dictionary={}
	for class_id: int in domain:
		var count: int=0
		if whole(root.get("CharacterClassID")) in [0,class_id]:
			for reward: Dictionary in rewards:
				if reward.class_ids.is_empty() or class_id in reward.class_ids:count+=1
		counts[str(class_id)]=count
		if count==0:reasons.append("no_eligible_select_reward_for_source_class")
	var unique: Array=[]
	for reason: String in reasons:
		if reason not in unique:unique.append(reason)
	spec["kind"]="source_selectable_reward";spec["source_snapshot"]="patch523";spec["source_item_class_id"]=definition.original_item.ID;spec["reward_id"]=id;spec["original_reward"]=root_node.duplicate(true);spec["select_reward_id"]=selection.get("ID");spec["original_select_reward"]=selection;spec["select_max_count"]=selection.get("SelectMaxCount");spec["source_entities"]=linked;spec["rewards"]=rewards;spec["source_class_domain"]=domain;spec["class_eligible_option_counts"]=counts;spec["selection_model"]="explicit_source_entity_choice";spec["source_item_bonus_ids"]=[]
	for row: Dictionary in rows:spec.source_item_bonus_ids.append(row.ID)
	spec["item_requirements"]={"targetting_type_id":definition.original_item.get("TargettingTypeID"),"service_region_code":definition.original_item.get("ServiceRegionCode",""),"can_use_when_invisible":definition.original_item.get("CanUseWhenInvisible",false)}
	if initial_rule:spec["local_rule_required"]="select_reward_initial_enchant";spec["source_initial_enchant"]=null;spec["initial_enchant_configuration_key"]="patch523_select_reward_initial_enchant"
	spec["activation_status"]="unrestricted" if unique.is_empty() else "blocked";spec["blocked_reasons"]=unique
	return spec


## Card items (ItemCategory BuffCardDrawer) whose single BuffCardID is a
## Polymorph, MagicDoll or HolyStuff (relic) collection card: using one grants
## exactly that original card to the existing card owner. The card itself is
## bound by the use owner (source ID, deck, grade, merge/swap flags) at use.
const CARD_DECKS={1:["PolymorphCardDeck","변신"],2:["MagicDollCardDeck","마법인형"],98:["HolyStuffCardDeck","성물"]}
static func source_fixed_card(definition: Dictionary) -> Dictionary:
	var rows: Array=definition.get("item_bonus",[]);var refs: Array=[]
	for row: Dictionary in rows:
		if row.get("bonus_type",{}).get("Name")=="BuffCardID":refs.append(row)
	if refs.size()!=1 or not integer(refs[0].get("bonus",{}).get("Value")):return {}
	var id: int=int(refs[0].bonus.Value);var joins: Array=[]
	for ref: Dictionary in definition.get("source_typed_references",[]):
		if ref.get("item_bonus_id")==refs[0].ID and ref.get("unit")=="BuffCardID" and ref.get("id")==id:joins.append(ref)
	if joins.size()!=1:return {}
	var card: Dictionary=joins[0].get("card",{});var deck: Dictionary=joins[0].get("deck",{})
	var deck_id: Variant=whole(deck.get("ID"))
	if card.get("ID")!=id or not CARD_DECKS.has(deck_id) or deck.get("Name")!=CARD_DECKS[deck_id][0] or whole(card.get("BuffCardDeckID"))!=deck_id:return {}
	var spec: Dictionary=consume_metadata(rows,definition.original_item,definition.category,{"BuffCardID":"BuffCardID","ItemConsumeEffectSpriteID":"SpriteID","BuffCardCannotSwap":"TrueFalse"},false)
	if spec.get("consume_delay_ms")==null:spec.erase("consume_delay_ms")
	var reasons: Array=spec.blocked_reasons
	if definition.category.get("Name")!="BuffCardDrawer" or deck.get("CharacterBased")!=false:reasons.append("unsupported_card_item_category_or_deck")
	if not SOURCE.declared_exclusion("BuffCard",card).is_empty() or not SOURCE.declared_exclusion("BuffCardDeck",deck).is_empty():reasons.append("source_excluded_card")
	# A defined server set is checked at use against the current server profile
	# (current523_server_profile.gd); a set without original rows stays closed.
	var server: Variant=card.get("ServerLimitSetID",0)
	if not integer(server):reasons.append("invalid_card_server_limit")
	elif int(server)!=0 and SOURCE.related("ServerLimit","ServerLimitSetID",int(server)).is_empty():reasons.append("server_definition_missing")
	if card.get("StartDateTimeID",0)!=0 or card.get("EndDateTimeID",0)!=0:reasons.append("source_card_date_context_required")
	var swap: Array=[]
	for row: Dictionary in rows:
		if row.get("bonus_type",{}).get("Name")=="BuffCardCannotSwap":swap.append(whole(row.get("bonus",{}).get("Value")))
	if swap.size()>1:reasons.append("ambiguous_card_flag:BuffCardCannotSwap")
	for value: Variant in swap:
		if value not in [0,1]:reasons.append("invalid_card_flag:BuffCardCannotSwap")
	var unique: Array=[]
	for reason: String in reasons:
		if reason not in unique:unique.append(reason)
	spec.merge({"kind":"fixed_card","source_snapshot":"patch523","source_item_class_id":definition.original_item.ID,"card_kind":CARD_DECKS[deck_id][1],"card_id":id,"deck_id":deck_id,"original_card":card.duplicate(true),"original_deck":deck.duplicate(true),"buff_card_cannot_swap":swap==[1],"server_limit_set_id":server,"source_item_bonus_ids":[],"item_requirements":{"targetting_type_id":definition.original_item.get("TargettingTypeID"),"service_region_code":definition.original_item.get("ServiceRegionCode",""),"can_use_when_invisible":definition.original_item.get("CanUseWhenInvisible",false)},"activation_status":"unrestricted" if unique.is_empty() else "blocked","blocked_reasons":unique})
	for row: Dictionary in rows:spec.source_item_bonus_ids.append(row.ID)
	return spec


## Weapon mastery point items (ItemCategory MasteryPointRecharger): one
## MasteryWeaponPointAmount row whose BonusApplicationType is WeaponType (22)
## gives Value points to its BonusApplicationTargetID weapon type, normalized
## by the existing mastery owner through the original MasteryWeaponType rows.
static func source_mastery_points(definition: Dictionary) -> Dictionary:
	var raw: Dictionary=definition.get("original_item",{});var category: Dictionary=definition.get("category",{})
	if category.get("Name")!="MasteryPointRecharger" or raw.is_empty():return {}
	var reasons: Array=[];var grants: Array=[];var ids: Array=[]
	if category.get("IsConsumable")!=true:reasons.append("source_category_not_consumable")
	if whole(raw.get("TargettingTypeID"))!=1:reasons.append("unsupported_targetting_type")
	if not str(raw.get("ServiceRegionCode","")).is_empty():reasons.append("source_service_region_context_required")
	var application: Dictionary=SOURCE.row("BonusApplicationType",22)
	for row: Dictionary in definition.get("item_bonus",[]):
		ids.append(row.get("ID"))
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""));var bonus: Dictionary=row.get("bonus",{})
		if name_value=="DeleteTime":
			if delete_time_stamp(row)<=0:reasons.append("source_item_lifetime_unresolved")
			continue
		if name_value=="CannotExtendDeleteTime" and direct(row) and row.get("unit",{}).get("Name")=="TrueFalse" and whole(bonus.get("Value")) in [0,1]:continue
		if name_value=="MasteryWeaponPointAmount":
			if row.get("IsPossession")!=false or whole(bonus.get("BonusApplicationTypeID"))!=22 or (not application.is_empty() and application.get("Name")!="WeaponType") or row.get("unit",{}).get("Name")!="Value" or not integer(bonus.get("Value")) or int(bonus.Value)<=0 or not integer(bonus.get("BonusApplicationTargetID")) or int(bonus.BonusApplicationTargetID)<=0:reasons.append("unsupported_mastery_point_row")
			else:grants.append({"points":int(bonus.Value),"weapon_type":int(bonus.BonusApplicationTargetID)})
			continue
		reasons.append("unsupported_item_bonus:"+name_value)
	if grants.size()!=1:reasons.append("missing_or_ambiguous_mastery_points")
	var unique: Array=[]
	for reason: String in reasons:
		if reason not in unique:unique.append(reason)
	var grant: Dictionary=grants[0] if grants.size()==1 else {}
	return {"kind":"weapon_mastery_points","source_snapshot":"patch523","source_item_class_id":raw.get("ID"),"points":grant.get("points",0),"weapon_type":grant.get("weapon_type",0),"source_item_bonus_ids":ids,"item_requirements":{"targetting_type_id":raw.get("TargettingTypeID"),"service_region_code":raw.get("ServiceRegionCode",""),"can_use_when_invisible":raw.get("CanUseWhenInvisible",false)},"activation_status":"unrestricted" if unique.is_empty() else "blocked","blocked_reasons":unique}

## Equipment bless scrolls (ItemCategory ScrollBless, item target). The
## blessing itself is the existing equipment blessing owner; its success rate
## is the target's original BlessSuccessRate row, and GuaranteeBlessProb makes
## it certain. Lifetime rows follow the item lifetime rule.
static func source_bless_scroll(definition: Dictionary) -> Dictionary:
	var raw: Dictionary=definition.get("original_item",{});var category: Dictionary=definition.get("category",{})
	if category.get("Name")!="ScrollBless" or raw.is_empty():return {}
	var reasons: Array=[];var guarantee: Array=[];var ids: Array=[]
	if category.get("IsConsumable")!=true:reasons.append("source_category_not_consumable")
	if whole(raw.get("TargettingTypeID"))!=8:reasons.append("unsupported_targetting_type")
	if not str(raw.get("ServiceRegionCode","")).is_empty():reasons.append("source_service_region_context_required")
	for row: Dictionary in definition.get("item_bonus",[]):
		ids.append(row.get("ID"))
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""))
		if name_value=="DeleteTime":
			if delete_time_stamp(row)<=0:reasons.append("source_item_lifetime_unresolved")
			continue
		if name_value in ["CannotExtendDeleteTime","GuaranteeBlessProb"] and direct(row) and row.get("unit",{}).get("Name")=="TrueFalse" and whole(row.get("bonus",{}).get("Value")) in [0,1]:
			if name_value=="GuaranteeBlessProb":guarantee.append(whole(row.bonus.Value))
			continue
		reasons.append("unsupported_item_bonus:"+name_value)
	if guarantee.size()>1:reasons.append("ambiguous_bless_guarantee")
	var unique: Array=[]
	for reason: String in reasons:
		if reason not in unique:unique.append(reason)
	return {"kind":"equipment_bless","source_snapshot":"patch523","source_item_class_id":raw.get("ID"),"guaranteed":guarantee==[1],"rate_table":"BlessSuccessRate","source_item_bonus_ids":ids,"item_requirements":{"targetting_type_id":raw.get("TargettingTypeID"),"service_region_code":raw.get("ServiceRegionCode",""),"can_use_when_invisible":raw.get("CanUseWhenInvisible",false)},"activation_status":"unrestricted" if unique.is_empty() else "blocked","blocked_reasons":unique}


# Public _source_skill_book_spec semantics using the existing typed ItemData
# card/deck/spell graph. No new source reader or spell runtime is introduced.
static func source_skill_book(definition: Dictionary) -> Dictionary:
	var rows: Array=definition.get("item_bonus",[]);var refs: Array=[]
	for row: Dictionary in rows:
		if row.get("bonus_type",{}).get("Name")=="BuffCardID":refs.append(row)
	if refs.size()!=1 or not integer(refs[0].get("bonus",{}).get("Value")):return {}
	var id: int=int(refs[0].bonus.Value);var joins: Array=[]
	for ref: Dictionary in definition.get("source_typed_references",[]):
		if ref.get("item_bonus_id")==refs[0].ID and ref.get("unit")=="BuffCardID" and ref.get("id")==id:joins.append(ref)
	if joins.size()!=1:return {}
	var card: Dictionary=joins[0].get("card",{});var deck: Dictionary=joins[0].get("deck",{})
	if card.get("ID")!=id or deck.get("ID")!=41 or deck.get("Name")!="Spell":return {}
	var spec: Dictionary=consume_metadata(rows,definition.original_item,definition.category,{"BuffCardID":"BuffCardID","ItemConsumeEffectSpriteID":"SpriteID","BuffCardCannotSwap":"TrueFalse","CannotStackCard":"TrueFalse"},false)
	if spec.get("consume_delay_ms")==null:spec.erase("consume_delay_ms")
	var reasons: Array=spec.blocked_reasons
	if definition.category.get("Name")!="BuffCardDrawer" or deck.get("CharacterBased")!=true:reasons.append("unsupported_source_skill_card_category_or_deck")
	if card.get("BuffClassID")!=0:reasons.append("source_skill_card_has_additional_buff")
	var graph: Dictionary=joins[0].get("spell",{});var spell: Dictionary=graph.get("spell_class",{})
	var spell_id: Variant=card.get("SpellClassID")
	if not integer(spell_id) or int(spell_id)<=0 or spell.get("ID")!=spell_id or graph.get("source")!=SOURCE.identity() or spell!=SOURCE.row("SpellClass",int(spell_id)):reasons.append("invalid_source_skill_card_spell_id")
	if spell.get("TestSpell")!=false or not SOURCE.declared_exclusion("SpellClass",spell).is_empty():reasons.append("source_test_or_excluded_spell")
	if not SOURCE.declared_exclusion("BuffCard",card).is_empty() or not SOURCE.declared_exclusion("BuffCardDeck",deck).is_empty():reasons.append("source_excluded_skill_card")
	var flags: Dictionary={}
	for kind: String in ["BuffCardCannotSwap","CannotStackCard"]:
		var values: Array=[]
		for row: Dictionary in rows:
			if row.get("bonus_type",{}).get("Name")==kind:values.append(whole(row.get("bonus",{}).get("Value")))
		if values.size()>1:reasons.append("ambiguous_skill_card_flag:"+kind)
		for value: Variant in values:
			if not integer(value) or value not in [0,1]:reasons.append("invalid_skill_card_flag:"+kind)
		flags["buff_card_cannot_swap" if kind=="BuffCardCannotSwap" else "cannot_stack_card"]=values==[1]
	var server: Variant=card.get("ServerLimitSetID",0);var server_rows: Array=[]
	if not integer(server):reasons.append("invalid_skill_card_server_limit")
	elif int(server)!=0:
		server_rows=SOURCE.related("ServerLimit","ServerLimitSetID",int(server))
		if server_rows.is_empty():reasons.append("server_definition_missing") # A defined set is checked at learning.
	if card.get("StartDateTimeID",0)!=0 or card.get("EndDateTimeID",0)!=0:reasons.append("source_skill_card_date_context_required")
	var limits: Array=[];var tutorials: Array=[]
	for edge: Dictionary in graph.get("learn_limits",[]):
		var row: Dictionary=edge.get("link",{}).duplicate(true)
		row["class"]=edge.get("class",{}).duplicate(true)
		if edge.get("limit_buff_card",{})!={}:row["limit_buff_card"]=edge.limit_buff_card.duplicate(true)
		if row.get("IsTutorialSpell")==true:tutorials.append(row);continue
		limits.append(row)
		if row.get("IsTutorialSpell")!=false:reasons.append("unsupported_skill_tutorial_rule")
		if not integer(row.get("CharacterMinLevel")) or int(row.CharacterMinLevel)<0:reasons.append("unsupported_skill_min_level")
		if not integer(row.get("ClassID")) or int(row.ClassID)<=0 or row.get("class",{}).get("CanCreateClient")!=true:reasons.append("unsupported_skill_learn_class")
		if row.get("CharacterPolymorphGradeID")!=0:reasons.append("source_skill_polymorph_grade_requirement_unresolved")
		if row.get("LimitBuffCardID")!=0:reasons.append("source_skill_limit_card_requirement_unresolved")
		if not SOURCE.declared_exclusion("SpellLearnLimit",edge.get("link",{})).is_empty():reasons.append("source_excluded_skill_learn_limit")
	if limits.is_empty():reasons.append("missing_non_tutorial_source_skill_learn_limit")
	# Reuse the exact existing source-profile serializer. Its SHA is confirmed
	# against the actually loaded owner/binding again at learning, not assumed.
	var binding_document: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/player_skills523_bindings.json"))
	var row_digests: Array=[]
	if binding_document is Dictionary and binding_document.get("skills") is Dictionary:
		for bound: Variant in binding_document.skills.values():
			if bound is Dictionary and bound.get("spell_id")==spell_id and bound.get("row_sha256") is String and bound.row_sha256 not in row_digests:row_digests.append(bound.row_sha256)
	var expected_row_sha: String=str(row_digests[0]) if row_digests.size()==1 else ""
	var row_json: String=preload("res://scripts/skills/player_skills523.gd")._source_row_json(spell,expected_row_sha)
	if row_json.is_empty():reasons.append("source_spell_row_serialization_unavailable")
	var unique: Array=[]
	for reason: String in reasons:
		if reason not in unique:unique.append(reason)
	spec.merge(flags)
	spec.merge({"kind":"source_skill_book","source_snapshot":"patch523","source_item_class_id":definition.original_item.ID,"card_id":id,"deck_id":deck.ID,"original_card":card.duplicate(true),"original_deck":deck.duplicate(true),"spell_class_id":spell_id,"source_spell_class":spell.duplicate(true),"source_spell_row_json":row_json,"source_spell_row_sha256":row_json.sha256_text(),"source_spell_group_mastery_required":spell.get("IsRequireSpellGroupMastery"),"source_learn_limits":limits,"source_tutorial_learn_limits":tutorials,"server_limit_set_id":server,"server_limits":server_rows,"start_datetime_id":card.get("StartDateTimeID",0),"end_datetime_id":card.get("EndDateTimeID",0),"runtime_dependency":"source523_skill_catalog","host_binding_policy":"exact_SpellClassID_and_canonical_source_row_SHA256","runtime_binding_required":true,"source_item_bonus_ids":[],"item_requirements":{"targetting_type_id":definition.original_item.get("TargettingTypeID"),"service_region_code":definition.original_item.get("ServiceRegionCode",""),"can_use_when_invisible":definition.original_item.get("CanUseWhenInvisible",false)},"activation_status":"unrestricted" if unique.is_empty() else "blocked","blocked_reasons":unique})
	for row: Dictionary in rows:spec.source_item_bonus_ids.append(row.ID)
	return spec
