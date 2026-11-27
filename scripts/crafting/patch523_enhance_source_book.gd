extends RefCounted
## Read enhancement family declarations from the pinned 523 archive, not
## the subset of items chosen by the independent crafting binder.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const NATIVE_FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const LEGACY_ACCESSORY_SLOTS: Array[String]=["ring","earring","seal","bracelet","necklace","belt","badge","crystal","catalyst","rune"]
const TABLES: Array[String]=["BmItemEnchantProView","ItemEnchantCostView","ItemEnchantProbabilityView",
	"ItemEnchantProbabilityGroup","ItemEnchantEquipGroupMapping","ItemEnchantScrollGroupMapping","ItemBlessEnchantProbability","Material"]
static var _identity: Dictionary={}
static var _tables: Dictionary={}
static var _groups: Dictionary={}
var data: Dictionary={}
var target: Dictionary={}
var scroll: Dictionary={}
var target_id: String
var scroll_id: String
var compiled: Object
var _legacy_equip: Dictionary={}

static func checked_native(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source_definition_archive")!=SOURCE.identity():return {}
	var definition: Dictionary=DROPS.current_original_definition(record)
	var canonical: Dictionary=definition.get("native_record",{})
	if canonical.is_empty() or not NATIVE_FIELDS.field(canonical,"source_condition_pending",[]).is_empty() or canonical.get("source_delete_time_unresolved",false):return {}
	var raw: Dictionary=definition.get("original_item",{})
	if raw.get("TestItem")!=false or not str(raw.get("ServiceRegionCode","")).is_empty() or definition.get("excluded",false):return {}
	return definition

static func declares_scroll(record: Dictionary) -> bool:
	var definition: Dictionary=checked_native(record)
	if definition.is_empty():return false
	var bless: int=int(record.get("source_bless_raw",1))
	for row: Dictionary in definition.get("item_bonus",[]):
		var b: Dictionary=row.get("bonus",{})
		var kind: int=int(b.get("BonusTypeID",0))
		if kind==2022 or (kind==8352 and int(b.get("BonusApplicationTypeID",0))==202 and int(b.get("BonusApplicationTargetID",0))==bless):return true
	return false

## The ordinary elemental scrolls carry group 21 plus one element. Scrolls
## carrying ScrollElementalSmith use the separate refinement transaction.
static func scroll_element(record: Dictionary) -> String:
	if NATIVE_FIELDS.field(record,"source_category_name")!="ScrollElementalEnchant":return ""
	var definition: Dictionary=checked_native(record)
	var element: String=""
	var group: bool=false
	for entry: Dictionary in definition.get("item_bonus",[]):
		var bonus: Dictionary=entry.get("bonus",{})
		var type: int=int(bonus.get("BonusTypeID",0))
		if type==8232:return ""
		if type not in [441,2022]:continue
		if entry.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0:return ""
		if type==2022:
			if group or bonus.get("Value")!=21:return ""
			group=true
		else:
			if not element.is_empty():return ""
			var source_type: String=str(SOURCE.row("ElementalType",int(bonus.get("Value",0))).get("Name",""))
			element=str({"Fire":"fire","Water":"water","Air":"wind","Earth":"earth"}.get(source_type,""))
			if element.is_empty():return ""
	return element if group else ""

func bind(detached_target: Dictionary, exact_target_id: String, detached_scroll: Dictionary, exact_scroll_id: String, compiled_book: Object, registered_legacy: Dictionary={}) -> bool:
	var identity: Dictionary=SOURCE.identity()
	if identity.is_empty():return false
	if not exact_target_id.is_valid_int() or not exact_scroll_id.is_valid_int():return false
	target=checked_native(detached_target) if detached_target.get("source_m_native_item",false) else DROPS.definition_id(exact_target_id)
	scroll=checked_native(detached_scroll) if detached_scroll.get("source_m_native_item",false) else DROPS.definition_id(exact_scroll_id)
	if target.is_empty() or scroll.is_empty() or target.get("excluded",false) or scroll.get("excluded",false):return false
	for row: Dictionary in [target,scroll]:
		var raw: Dictionary=row.get("original_item",{})
		if raw.get("TestItem")!=false or not str(raw.get("ServiceRegionCode","")).is_empty():return false
	if str(int(target.original_item.ID))!=exact_target_id or str(int(scroll.original_item.ID))!=exact_scroll_id:return false
	_legacy_equip={}
	if not registered_legacy.is_empty():
		# Old equipment stays on its existing inventory key. Only its original
		# enhancement tables are substituted for the incompatible compiled DTO.
		if not _legacy_equip_matches(detached_target,registered_legacy,exact_target_id):return false
		if target.get("source_input_identity")!=identity or target.get("source_reference",{}).get("ok")!=true:return false
		var slot: String=str(registered_legacy.get("slot",""))
		if slot=="weapon":
			if target.get("category",{}).get("Name")!="Weapon":return false
			if not target.get("equip_rows",[]).any(func(row: Dictionary) -> bool: return row.get("equip_slot",{}).get("Name")=="WeaponHold"):return false
		elif slot not in LEGACY_ACCESSORY_SLOTS or target.get("native_record",{}).get("slot")!=slot or target.get("equip_rows",[]).is_empty():return false
		if target.get("item_bonus",[]).any(func(row: Dictionary) -> bool: return row.get("bonus_type",{}).get("Name") in ["DeleteTime","StartDateTimeID","EndDateTimeID","ServerLimitSetID"]):return false
		_legacy_equip=registered_legacy
	if _identity!=identity:
		var loaded: Dictionary={}
		for table: String in TABLES:
			var rows: Array=SOURCE.rows(table)
			if rows.is_empty():return false
			loaded[table]=rows
		_identity=identity.duplicate(true);_tables=loaded;_groups.clear()
	data={"enchantment":_tables,"items":{exact_target_id:true,exact_scroll_id:true}}
	target_id=exact_target_id;scroll_id=exact_scroll_id;compiled=compiled_book
	return true

func catalog_identity_matches(record: Dictionary, id: String) -> bool:
	if id!=target_id:return false
	if record.get("source_m_native_item",false):return not checked_native(record).is_empty()
	if not _legacy_equip.is_empty():return _legacy_equip_matches(record,_legacy_equip,id)
	return compiled!=null and compiled.catalog_identity_matches(record,id)

func _legacy_equip_matches(record: Dictionary, registered: Dictionary, id: String) -> bool:
	if (registered.get("source")!="inven" or registered.get("sourceId")!=id
		or registered.get("sourceUrl")!="https://lineagem.inven.co.kr/db/item/"+id
		or not DROPS.matches(record,registered)):return false
	var raw: Dictionary=target.get("original_item",{})
	for field: String in ["IdentifiedDescID","DescID"]:
		var text: String=str(SOURCE.row("DescData_Korean",int(raw.get(field,0))).get("Description","")).strip_edges()
		if not text.is_empty() and text==registered.get("name"):return true
	return false

func item_entry(id: String) -> Dictionary:
	var row: Dictionary=target if id==target_id else scroll if id==scroll_id else {}
	# The rule only needs BonusID here. Use the verified original Bonus.ID.
	var refs: Array=[]
	for entry: Dictionary in row.get("item_bonus",[]):
		var b: Dictionary=entry.get("bonus",{})
		if b.has("ID"):refs.append({"BonusID":b.ID})
	return {"item_class":row.get("original_item",{}),"item_bonuses":refs}

func bonus_row(key: String) -> Dictionary:
	return SOURCE.row("Bonus",int(key))

## Keep full-axis original rows, but only examine the chosen probability
## group's stages for each inventory candidate. Avoid an all-groups scan
## for every safe-level and cost lookup when the chooser opens.
func enhancement_group_tables(group: int) -> Dictionary:
	if _groups.has(group):return _groups[group]
	var result: Dictionary=_tables.duplicate()
	for table: String in ["BmItemEnchantProView","ItemEnchantCostView","ItemEnchantProbabilityView"]:
		var rows: Array=[]
		for row: Dictionary in _tables[table]:
			if int(row.ItemEnchantProbabilityGroupID)==group:rows.append(row)
		result[table]=rows
	_groups[group]=result
	return result

func enhancement_evidence(equip_id: int, use_id: int, level: int, target_bless: int, scroll_bless: int) -> Dictionary:
	var equip_groups: Dictionary={}
	for entry: Dictionary in target.get("item_bonus",[]):
		var b: Dictionary=entry.get("bonus",{})
		if int(b.get("BonusTypeID",0))==2032:equip_groups[int(b.Value)]=true
	var scroll_groups: Dictionary={}
	for entry: Dictionary in scroll.get("item_bonus",[]):
		var b: Dictionary=entry.get("bonus",{})
		var kind: int=int(b.get("BonusTypeID",0))
		if kind==2022 or (kind==8352 and int(b.get("BonusApplicationTypeID",0))==202 and int(b.get("BonusApplicationTargetID",0))==scroll_bless):scroll_groups[int(b.Value)]=true
	var equip_probability: Dictionary={}
	for row: Dictionary in _tables.ItemEnchantEquipGroupMapping:
		if equip_groups.has(int(row.ItemEnchantEquipGroupID)):equip_probability[int(row.ItemEnchantProbabilityGroupID)]=true
	var matches: Dictionary={}
	for row: Dictionary in _tables.ItemEnchantScrollGroupMapping:
		var group: int=int(row.ItemEnchantProbabilityGroupID)
		if equip_probability.has(group) and scroll_groups.has(int(row.ItemEnchantScrollGroupID)):matches[group]=true
	# If two family declarations overlap, a published stage row can eliminate
	# one only when it declares no rows for this stage at all. A restricted
	# or rate-missing row remains a competing declaration: fail closed.
	if matches.size()>1:
		var declaring_stage: Dictionary={}
		for row: Dictionary in _tables.ItemEnchantProbabilityView:
			var group: int=int(row.ItemEnchantProbabilityGroupID)
			if matches.has(group) and int(row.EnchantLevel)==level:declaring_stage[group]=true
		if declaring_stage.size()==1:matches=declaring_stage
	var result: Dictionary={"groups":matches.keys(),"probabilities":[],"costs":[]}
	if str(equip_id)!=target_id or str(use_id)!=scroll_id or matches.size()!=1:return result
	var tables: Dictionary=enhancement_group_tables(int(matches.keys()[0]))
	for table: String in ["BmItemEnchantProView","ItemEnchantCostView"]:
		var out: Array=result.probabilities if table=="BmItemEnchantProView" else result.costs
		for row: Dictionary in tables[table]:
			if int(row.EnchantLevel)==level and int(row.TargetItemBlessCode) in [0,target_bless]:out.append(row)
	return result
