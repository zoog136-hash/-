extends RefCounted
## Exact native enhancement operands for the existing percentage-budget consumer.
## No flat-as-percent conversion, new hit, custody, save or combat ordering.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const ENHANCE=preload("res://scripts/crafting/patch523_enhancement.gd")
const OPTIONS=preload("res://scripts/item_options.gd")
const CONDITIONS=preload("res://scripts/loot/patch523_monster_drops.gd")
const INPUTS={"IgnoreDamageReductionPercent":"source_equipment_ignore_reduction_pct","IgnoreMeleeDamageReductionPercent":"source_equipment_ignore_melee_reduction_pct","IgnoreRangeDamageReductionPercent":"source_equipment_ignore_ranged_reduction_pct","IgnoreMagicDamageReductionPercent":"source_equipment_ignore_magic_reduction_pct"}
static var evidence: Dictionary={}

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _original(item_id: int,effects: Array,level: int,bless: int) -> Dictionary:
	var selectors: Dictionary={};var groups: Dictionary={};var seen: Dictionary={}
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",item_id):
		var bonus: Dictionary=SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary=SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if type.get("Name")!="EnchantBonusGroupID":continue
		var unit: Dictionary=SOURCE.row("Unit",int(type.get("UnitID",-1)))
		if link.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or not integer(bonus.get("Value")) or int(bonus.Value)<=0 or unit.get("Name")!="EnchantBonusGroupID":return {}
		for pair: Array in [["ItemBonus",link],["Bonus",bonus],["BonusType",type],["Unit",unit]]:
			if not SOURCE.declared_exclusion(pair[0],pair[1]).is_empty():return {}
		if selectors.has(int(bonus.Value)):return {}
		selectors[int(bonus.Value)]={"link":link,"bonus":bonus,"type":type,"unit":unit}
	for entry: Variant in effects:
		if not entry is Dictionary or not integer(entry.get("ID")) or not integer(entry.get("ItemEnchantBonusGroupID")) or not integer(entry.get("BlessCode")) or not integer(entry.get("EnchantLevel")):return {}
		var row: Dictionary=entry
		var originals: Array[Dictionary]=SOURCE.related("ItemEnchantBonus","ID",int(row.ID))
		if originals.size()!=1 or originals[0]!=row or seen.has(int(row.ID)) or not SOURCE.declared_exclusion("ItemEnchantBonus",row).is_empty():return {}
		seen[int(row.ID)]=true
		var group: int=int(row.ItemEnchantBonusGroupID)
		if not selectors.has(group):return {}
		if not groups.has(group):groups[group]=[]
		groups[group].append(row)
	var totals: Dictionary={};var used: Array=[]
	for group: int in groups:
		var codes: Dictionary={}
		for row: Dictionary in groups[group]:codes[int(row.BlessCode)]=true
		var selected: int=bless if codes.has(bless) else 0
		for row: Dictionary in groups[group]:
			if row.BlessCode!=selected:continue
			var bonus: Dictionary=SOURCE.row("Bonus",int(row.get("BonusID",-1)))
			var type: Dictionary=SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
			if not INPUTS.has(type.get("Name","")):continue
			var unit: Dictionary=SOURCE.row("Unit",int(type.get("UnitID",-1)))
			if type.get("UnitID")!=3 or unit.get("Name")!="Percentage" or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or not integer(bonus.get("Value")):return {}
			for pair: Array in [["Bonus",bonus],["BonusType",type],["Unit",unit]]:
				if not SOURCE.declared_exclusion(pair[0],pair[1]).is_empty():return {}
			# Whole-value families need their own exact base contract; none is assumed.
			if int(row.EnchantLevel)==0:return {}
			if int(row.EnchantLevel)!=level:continue
			var key: String=INPUTS[type.Name]
			totals[key]=float(totals.get(key,0))+float(bonus.Value)/10000.0
			used.append({"selector":selectors[group],"row":row,"bonus":bonus,"type":type,"unit":unit})
	return {"values":totals,"rows":used} if not used.is_empty() else {}

static func sum_equipped(world: Node,kind: String) -> float:
	evidence={}
	if not is_instance_valid(world) or kind not in ["melee","ranged","magic"]:return 0.0
	var identity: Dictionary=SOURCE.identity()
	if identity.is_empty():return 0.0
	var keys: Array=[INPUTS.IgnoreDamageReductionPercent,"source_equipment_ignore_"+kind+"_reduction_pct"]
	var total: float=0.0;var visited: Dictionary={}
	for slot: String in world.EQUIPMENT_SLOT_ORDER:
		var worn: Dictionary=world.equipped_items.get(slot,{})
		var uid: String=str(worn.get("instance_id",""))
		if uid.is_empty() or visited.has(uid):continue
		visited[uid]=true
		var physical: Dictionary=world.item_instances.get(uid,{})
		if physical.is_empty() or physical.get("name")!=worn.get("name") or not integer(physical.get("level")) or not world._is_instance_equipped(uid):continue
		var level: int=int(physical.level)
		if level<0 or level>20:continue
		var current: Dictionary=world._source_catalog_record("아이템",worn)
		if current.get("source")!="lineagem_patch523" or current.get("source_snapshot")!="patch523" or current.get("source_projection")!="current523_original_typed_game_dto_v1" or current.get("source_m_native_item")!=true or current.get("source_test_item")!=false or current.get("source_equipment_status")!="mapped" or current.get("source_legacy_catalog_alias",false) or current.get("source_legacy_stack_variant",false):continue
		if current.get("_patch523_effective_extras",false):continue
		var pending: Variant=current.get("source_condition_pending",[])
		if not pending is Array or not pending.is_empty() or not CONDITIONS.equipment_error(current,str(world.job_class),int(world.level),int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540))).is_empty():continue
		var id: Variant=current.get("source_item_class_id")
		if not integer(id) or int(id)<=0 or current.get("sourceId")!="m523:item:"+str(int(id)) or current.get("source_definition_archive")!=identity:continue
		var raw: Dictionary=SOURCE.row("ItemClass",int(id))
		if raw.is_empty() or raw!=current.get("source_original_item") or raw.get("TestItem")!=false or not SOURCE.declared_exclusion("ItemClass",raw).is_empty():continue
		if physical.has("sourceId") and physical.sourceId!=current.get("sourceId"):continue
		var bless: int=world.patch523_equipment.bless_code(physical)
		if bless not in [1,2]:continue
		# The existing base reader proves exact current ItemBonus rows, units and
		# mapped-ID non-duplication. Source-only base items need no invented model.
		var pinned: Variant=physical.get("record",{})
		if not pinned is Dictionary or pinned.get("sourceId")!=current.get("sourceId") or pinned.get("source_projection")!=current.get("source_projection") or pinned.get("source_definition_archive")!=identity or pinned.get("source_original_item")!=raw or CONDITIONS.current_owned_record(pinned).is_empty():continue
		var base_amount: float=0.0;var base_evidence: Dictionary={}
		for key: String in keys:
			OPTIONS.original_percent_input_evidence.erase(str(int(id))+":"+key)
			base_amount+=OPTIONS.additional_original_percent(current,key)
			var proof: Dictionary=OPTIONS.original_percent_input_evidence.get(str(int(id))+":"+key,{})
			if not proof.is_empty():base_evidence[key]=proof.duplicate(true)
		total+=base_amount
		evidence[uid]={"source":identity,"item_class_id":id,"level":level,"bless_code":bless,"kind":kind,"base_value":base_amount,"base_rows":base_evidence,"enhancement_value":0.0}
		var prepared: Dictionary=world._physical_enhancement_record(worn)
		var item_key: String=ENHANCE.item_id(prepared)
		if item_key!=str(int(id)) or prepared.get("source_projection")!=current.source_projection or prepared.get("source_definition_archive")!=identity or prepared.get("source_original_item")!=raw or not world.patch523_equipment.catalog_identity_matches(prepared,item_key):continue
		var canonical: Dictionary=world.patch523_equipment.record(item_key)
		var same_input: bool=true
		for field: String in ["source_definition_archive","source_original_item","source_mapped_bonuses","source_enchant_group_ids"]:
			if not current.has(field) or canonical.get(field)!=current[field] or prepared.get(field)!=current[field]:same_input=false;break
		if not same_input:continue
		var basis: Dictionary=prepared.get("patch523_effect_basis",{})
		if basis.get("selection")!="source_exact_level" or basis.get("sha256")!=world.patch523_equipment.digest or basis.get("bless_code")!=bless:continue
		var bound: Dictionary=world.patch523_equipment.data.get("items",{}).get(item_key,{})
		if bound.get("item_class")!=raw or not bound.get("enchant_effects") is Array:continue
		var source: Dictionary=_original(int(id),bound.enchant_effects,level,bless)
		if source.is_empty():continue
		var original_values: Dictionary=source.get("values",{})
		var compiled: Dictionary=world.patch523_equipment.data.get("equipment_runtime",{}).get(item_key,{}).get("extra_options",{}).get(str(bless),{}).get(str(level),{})
		var actual: Dictionary=prepared.get("enhancement_extra_options",{}).get(str(level),{})
		var amount: float=0.0;var matched: bool=true
		for key: String in keys:
			if not original_values.has(key):continue
			var expected: Variant=compiled.get(key)
			var value: Variant=actual.get(key)
			if current.has(key) or typeof(expected) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(expected)) or typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or expected!=original_values[key] or value!=expected:matched=false;break
			amount+=float(value)
		if not matched:continue
		total+=amount
		evidence[uid]["model_sha256"]=world.patch523_equipment.digest
		evidence[uid]["enhancement_rows"]=source.rows
		evidence[uid]["enhancement_value"]=amount
	return total if is_finite(total) else 0.0
