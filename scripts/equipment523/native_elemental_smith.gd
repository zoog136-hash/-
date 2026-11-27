extends RefCounted
## A scoped view of the installed 523 tables for a selected weapon and scroll.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const CATALOG = preload("res://scripts/equipment523/native_catalog.gd")
const SCHEMA = "source523_elemental_smith_v1"
const TABLE_COUNTS = {"ElementalSmith":114,"ElementalSmithAbleLevel":6,"ElementalSmithBonus":98,"ElementalSmithProbability":456}
const SELECTORS = [31, 441, 2032, 8232]
const ELEMENTS = {1:"fire", 2:"water", 3:"wind", 4:"earth"}

static var _identity: Dictionary = {}
static var _rules: Dictionary = {}

static func input(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or not CATALOG.same(record.get("source_definition_archive"),SOURCE.identity()):return {}
	var category: String=str(FIELDS.field(record,"source_category_name",""))
	if not category.is_empty() and category!="ScrollElementalEnchant":return {}
	if category.is_empty() and SOURCE.row("ItemClass",int(record.get("source_item_class_id",0))).get("CategoryID")!=131:return {}
	var definition: Dictionary=DROPS.item_definition(record)
	var item: Dictionary=definition.get("original_item",{})
	if item.get("TestItem")!=false or item.get("CategoryID")!=131 or item.get("TargettingTypeID")!=9 or item.get("ServiceRegionCode")!="":return {}
	if not FIELDS.field(definition.get("native_record",{}),"source_condition_pending",[]).is_empty():return {}
	var element: int=0
	var smith: bool=false
	var cutoff: int=0
	for row: Dictionary in definition.get("item_bonus",[]):
		var bonus: Dictionary=row.get("bonus",{})
		var type: int=int(bonus.get("BonusTypeID",0))
		if type==492:
			if cutoff!=0:return {}
			cutoff=PROJECTION.delete_time_stamp(row)
			if cutoff<=0:return {}
			continue
		if row.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0:return {}
		match type:
			441:
				var value: Variant=bonus.get("Value")
				if element!=0 or not PROJECTION.integer(value) or not ELEMENTS.has(int(value)):return {}
				element=int(value)
			8232:
				if smith or bonus.get("Value")!=1:return {}
				smith=true
			_:return {}
	if not smith or element==0:return {}
	return {"item_id":int(item.ID),"element":ELEMENTS[element],"cutoff":cutoff}

## Compact owned items can omit display metadata. Recover it from the same
## active item ID while checking all identity fields that are still present.
static func original_record(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or not CATALOG.same(record.get("source_definition_archive"),SOURCE.identity()):return {}
	var original: Dictionary=DROPS.current_owned_record(record)
	if original.is_empty():return {}
	for key: String in CATALOG.IDENTITY_FIELDS:
		if FIELDS.has_field(record,key) and not CATALOG.same(FIELDS.field(record,key),FIELDS.field(original,key)):
			return {}
	return original

## This use contract follows the absolute deletion date, like limited spirit
## smelting; installing an offline event rotation does not reopen these scrolls.
static func period_error(contract: Dictionary, now: int, offset: int) -> String:
	var cutoff: int=int(contract.get("cutoff",0))
	if cutoff==0:return ""
	var stamp: int=DROPS.source_deadline_unix(cutoff,offset)
	if stamp<0:return "원본 세공 주문서의 사용 기한을 확인할 수 없습니다"
	return "원본 세공 주문서 사용 기한 만료 · 주문서 보존" if now>=stamp else ""

static func scope(target_id: int, material_id: int) -> Dictionary:
	var identity: Dictionary=SOURCE.identity()
	if identity.is_empty() or target_id<=0 or material_id<=0 or target_id==material_id:return {}
	if _identity!=identity:
		_rules=_prepare()
		_identity=identity
	if _rules.is_empty():return {}
	var tables: Dictionary=_rules.tables.duplicate(false)
	var bonuses: Dictionary=_rules.bonuses.duplicate(false)
	var items: Dictionary={}
	var selectors: Array[Dictionary]=[]
	for id: int in [target_id,material_id]:
		var original: Dictionary=SOURCE.row("ItemClass",id)
		if original.get("ID")!=id or original.get("TestItem")!=false:return {}
		items[str(id)]={"raw":original}
		for row: Dictionary in SOURCE.related("ItemBonus","ItemClassID",id):
			if row.get("IsPossession")!=false:continue
			var bonus: Dictionary=SOURCE.row("Bonus",int(row.get("BonusID",0)))
			if not SELECTORS.has(int(bonus.get("BonusTypeID",0))):continue
			var type: Dictionary=SOURCE.row("BonusType",int(bonus.BonusTypeID))
			bonuses[str(int(bonus.ID))]={"name":type.get("Name",""),"raw":bonus}
			selectors.append(row)
	tables["ItemBonus"]=selectors
	return {"schema":SCHEMA,"source_sha256":SOURCE.SOURCE_SHA,"tables":tables,"items":items,"bonuses":bonuses}

static func _prepare() -> Dictionary:
	var tables: Dictionary={}
	for name: String in TABLE_COUNTS:
		var rows: Array=SOURCE.rows(name)
		if rows.size()!=TABLE_COUNTS[name]:return {}
		tables[name]=rows
	var bonuses: Dictionary={}
	for row: Dictionary in tables.ElementalSmithBonus:
		var bonus: Dictionary=SOURCE.row("Bonus",int(row.get("BonusID",0)))
		if bonus.is_empty():return {}
		var type: Dictionary=SOURCE.row("BonusType",int(bonus.BonusTypeID))
		var field: Dictionary=_effect(bonus,type)
		if field.is_empty():return {}
		bonuses[str(int(bonus.ID))]={"name":type.Name,"raw":bonus,"supported":true,"record":field}
	return {"tables":tables,"bonuses":bonuses}

## Same native damage channels and percent units as the full equipment compiler.
static func _effect(bonus: Dictionary, type: Dictionary) -> Dictionary:
	var value: Variant=bonus.get("Value")
	if not PROJECTION.integer(value) or float(value)<=0:return {}
	var application: int=int(bonus.get("BonusApplicationTypeID",-1))
	var target: int=int(bonus.get("BonusApplicationTargetID",-1))
	if type.get("Name")=="OptionalElementalDamage" and type.get("UnitID")==1 and application==3 and ELEMENTS.has(target):
		return {"equipment523_element_flat_"+ELEMENTS[target]:int(value)}
	if type.get("Name")=="ElementalCriticalProbability" and type.get("UnitID")==3 and application==0 and target==0:
		return {"equipment523_element_crit_pct":float(value)/10000.0}
	return {}
