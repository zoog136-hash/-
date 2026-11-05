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
static func label(id: Variant) -> String:
	if not integer(id) or int(id)<=0:return ""
	return str(SOURCE.row("DescData_Korean",int(id)).get("Description","")).strip_edges()
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
static func consume_metadata(rows: Array,raw: Dictionary,category: Dictionary) -> Dictionary:
	var reasons: Array=[];var grouped: Dictionary={}
	var units: Dictionary={"MPRestoration":"Value","MPRestorationDiceNumber":"Value","MPRestorationDiceSpotCount":"Value","ItemConsumeDelay":"MilliSeconds","ItemConsumeEffectSpriteID":"SpriteID"}
	if category.get("IsConsumable")!=true:reasons.append("source_category_not_consumable")
	if raw.get("TargettingTypeID")!=1:reasons.append("unsupported_targetting_type")
	if not str(raw.get("ServiceRegionCode","")).is_empty():reasons.append("source_service_region_context_required")
	for row: Dictionary in rows:
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""))
		if not direct(row):reasons.append("conditional_or_possession_item_bonus:"+name_value);continue
		if not units.has(name_value):reasons.append("source_item_lifetime_unresolved" if name_value=="DeleteTime" else "source_infinite_amount_not_supported" if name_value=="InfiniteAmount" else "unsupported_item_bonus:"+name_value);continue
		if row.get("unit",{}).get("Name")!=units[name_value] or not integer(row.get("bonus",{}).get("Value")):reasons.append("unsupported_item_bonus_unit_or_value:"+name_value);continue
		if not grouped.has(name_value):grouped[name_value]=[]
		grouped[name_value].append(int(row.bonus.Value))
	if grouped.get("ItemConsumeDelay",[]).size()!=1:reasons.append("missing_or_ambiguous_consume_delay")
	elif int(grouped.ItemConsumeDelay[0])<0:reasons.append("invalid_consume_delay")
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
		class_ids.append(entry.get("ClassID"));var class_name: String=label(entry.get("class",{}).get("DescID"));class_names.append(class_name)
		if class_name.is_empty():unresolved_classes.append(entry.get("ClassID"))
	var out: Dictionary={"name":display+" · 원본#"+str(item_id),"source_display_name":display,"source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":item_id,"sourceId":"m523:item:"+str(item_id),"sourceUrl":"","source_m_native_item":true,"source_bless_raw":1,"grade":grade_label,"source_grade_id":grade.ID,"slot":slot,"type":label(category.get("DescID")),"source_category_id":category.ID,"source_category_name":category.Name,"source_test_item":false,"source_is_trash":raw.get("IsTrash",false),"source_label_status":"source_descriptor","source_category_is_activatable":category.get("IsActivatable",false),"source_is_stackable":category.get("IsStackable",false),"source_is_consumable":category.get("IsConsumable",false),"source_weight":raw.get("Weight",0),"source_weight_unit":"unverified_source_units","source_equip_slots":slot_names,"source_equip_slot_ids":slot_ids,"source_equipment_status":"mapped" if equipment else "unsupported_source_slot" if bad_slot else "ambiguous_source_equip_slots" if not equips.is_empty() else "no_source_equip_slot","source_class_ids":class_ids,"source_class_names":class_names,"source_unresolved_class_ids":unresolved_classes,"source_definition_archive":SOURCE.identity(),"source_projection":"current523_original_typed_game_dto_v1","source_original_item":raw.duplicate(true)}
	out["source_icon_id"]=raw.get("IconID",0)
	out["source_sprite_id"]=raw.get("Sprite",0)
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
		if row.get("IsPossession")!=false or row.unit.Name!="Time":delete_unknown=true;continue
		var stamp: int=0
		if row.bonus.get("BonusApplicationTypeID")==298 and row.bonus.get("Value")==0 and integer(row.bonus.get("BonusApplicationTargetID")):
			stamp=date_value(SOURCE.row("DateTimes_Korean",int(row.bonus.BonusApplicationTargetID)))
		elif direct(row) and integer(row.bonus.get("Value")) and str(int(row.bonus.Value)).length()==10:
			var encoded: String=str(int(row.bonus.Value));stamp=date_value({"Year":int(encoded.substr(0,4)),"Month":int(encoded.substr(4,2)),"Day":int(encoded.substr(6,2)),"Hour":int(encoded.substr(8,2)),"Minute":0})
		if stamp<=0:delete_unknown=true
		else:deadlines.append(stamp)
	if delete_unknown:out["source_delete_time_unresolved"]=true
	elif not deadlines.is_empty():deadlines.sort();out["source_delete_time_raw"]=deadlines[0]
	out["source_condition_pending"]=pending_conditions
	var handled: Dictionary={};var applied: Array=[];var unknown: Array=[]
	for index: int in range(rows.size()):
		var row: Dictionary=rows[index];var name_value: String=str(row.get("bonus_type",{}).get("Name",""));var unit: String=str(row.get("unit",{}).get("Name",""));var amount: Variant=row.get("bonus",{}).get("Value")
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
		spec["activation_status"]="unrestricted" if spec.blocked_reasons.is_empty() else "blocked";out["source_use_spec"]=spec
		if spec.blocked_reasons.is_empty():
			for index: int in range(rows.size()):handled[index]=true
	for index: int in range(rows.size()):
		if handled.has(index):continue
		var row: Dictionary=rows[index]
		unknown.append({"item_bonus_id":row.ID,"bonus_id":row.bonus.ID,"bonus_type":row.bonus_type.Name,"reason":"current_original_positive_or_conditional_effect_owner_required"})
	out["source_mapped_bonuses"]=applied;out["source_unhandled_bonuses"]=unknown;out["source_unhandled_bonus_ids"]=[]
	for row: Dictionary in unknown:out.source_unhandled_bonus_ids.append(row.bonus_id)
	out["source_effect_status"]="partial" if not unknown.is_empty() or (slot=="consumable" and not out.has("heal_spec") and not out.has("source_use_spec")) or not unresolved_classes.is_empty() or bad_slot else "represented_source_fields"
	out["source_effect_scope"]="existing_flat_equipment_and_hp_mp_formula_projection; other_typed_effects_preserved_pending"
	if slot=="consumable" and not out.has("source_use_spec") and not out.has("heal_spec"):out["source_use_spec"]={"kind":"current_source_effect_pending","activation_status":"blocked","blocked_reasons":["current_typed_effect_owner_required"]}
	out["source_catalog_eligible"]=true;out["source_acquisition_policy"]="verified_supplier_only_no_fabricated_supply"
	return out

static func register(owner: Script,catalog: Dictionary,document: Dictionary) -> Dictionary:
	if SOURCE.identity().is_empty() or not catalog.get("아이템",[]) is Array:return {"ok":false,"reason":"current_original_catalog_input_unavailable"}
	var records: Array=catalog.get("아이템",[]).duplicate(true);var positions: Dictionary={};var pending: Dictionary={};var admitted: Array=[]
	for index: int in range(records.size()):
		if not records[index] is Dictionary:continue
		var key: String=str(records[index].get("sourceId",""))
		if not positions.has(key):positions[key]=[]
		positions[key].append(index)
	for raw: Dictionary in SOURCE.rows("ItemClass"):
		if not integer(raw.get("ID")) or int(raw.ID)<=0 or raw.get("TestItem")!=false or not SOURCE.declared_exclusion("ItemClass",raw).is_empty():continue
		var id: String=str(int(raw.ID));var definition: Dictionary=owner.call("definition_id",id)
		var current: Dictionary=definition.get("native_record",{})
		if current.is_empty():pending[id]="current_native_dto_unavailable";continue
		var key: String=str(current.sourceId);var previous: Array=positions.get(key,[])
		if previous.size()>1:pending[id]="ambiguous_registered_source_identity";continue
		if previous.size()==1:
			var saved: Dictionary=records[int(previous[0])]
			var typed_supply: bool=saved.get("source_current523_awakening_supply")==true and saved.get("source_item")==raw and saved.get("source_definition_archive")==SOURCE.identity()
			if typed_supply:admitted.append(id);continue
			if saved.get("source")!="lineagem_patch523" or saved.get("source_snapshot")!="patch523" or saved.get("source_item_class_id")!=raw.ID or saved.get("source_m_native_item")!=true or saved.get("name")!=current.name or saved.get("source_display_name")!=current.source_display_name:
				pending[id]="unverified_registered_source_identity_preserved";continue
			records[int(previous[0])]=current.duplicate(true)
		else:
			records.append(current.duplicate(true));positions[key]=[records.size()-1]
		admitted.append(id)
	catalog["아이템"]=records
	catalog["patch523_crafting_catalog_contract"]={"mode":"current_original_native_projection","source_definition_archive":SOURCE.identity(),"registered_definition_ids":admitted.duplicate(),"normal_ids":admitted.size(),"pending":pending.duplicate(),"full_native_coverage_observed":false}
	document["native_item_ids"]=admitted.duplicate();document["current_registration_pending"]=pending.duplicate();document["current_native_registered_count"]=admitted.size()
	return {"ok":true,"registered_count":admitted.size(),"pending":pending,"source_definition_archive":SOURCE.identity(),"ownership_changed":false,"executed_gameplay":false}

# Existing equipment stat consumer, evaluated from the same current original
# ItemEnchantBonus/Bonus/BonusType/Unit rows as the public compiler. Saved item
# identity and enhancement level remain with the existing physical owner.
static func enchant_stats(item: Dictionary,level: int,bless: int) -> Dictionary:
	var id: Variant=item.get("source_item_class_id")
	if not integer(id) or int(id)<=0 or level<0 or bless not in [1,2,3] or item.get("source_projection")!="current523_original_typed_game_dto_v1" or item.get("source_definition_archive")!=SOURCE.identity() or item.get("source_original_item")!=SOURCE.row("ItemClass",int(id)):return {}
	var names: Dictionary={"WeaponHitBonus":"accuracy","WeaponDamageBonus":"damage","ArmorClass":"defense","ArmorClassBonus":"defense","HPPlus":"hp","MPPlus":"mp","MagicResist":"mr","SpellPower":"sp","DamageReduction":"reduction","MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","MeleeHit":"melee_accuracy","RangeHit":"ranged_accuracy","MagicHit":"magic_accuracy","Strength":"str","Dexterity":"dex","Constitution":"con","Intelligence":"int","Wisdom":"wis","Charisma":"cha","HPPotionIncreaseStatic":"potion_heal_flat"}
	var result: Dictionary={}
	for group: Variant in item.get("source_enchant_group_ids",[]):
		if not integer(group) or int(group)<=0:continue
		for row: Dictionary in SOURCE.related("ItemEnchantBonus","ItemEnchantBonusGroupID",int(group)):
			if not SOURCE.declared_exclusion("ItemEnchantBonus",row).is_empty() or row.get("EnchantLevel")!=level or row.get("BlessCode") not in [0,bless]:continue
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
