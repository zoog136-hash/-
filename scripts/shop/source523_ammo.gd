extends RefCounted
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
# Existing host combat policy only. These are not recovered native damage rules.
const DATA={"data":{"damage_policy":"uniform_size_die","estimated_undead_bonus":2,"estimated_undead_materials":[14,17,22],"origin":"원본 크기별 탄약 수치 · TWILIGHT 1~최댓값 주사위/별도 합산 · 은/미스릴/오리하루콘 언데드 +2 자체값"}}
# Reviewed ordinary-ammunition scope from build_source523_ammo.py.
const FAMILIES={337:"화살",389:"화살",477:"화살",478:"화살",236381:"화살",369:"스팅",30633:"스팅",75174:"총알",110724:"총알",110734:"총알",179693:"총알"}
const BONUS_NAMES=["WeaponSmallDamage","WeaponLargeDamage","AmmoEffectSpriteID","AmmoExplosionSpriteID"]
static var source_identity: Dictionary={}
static var source_problem: String=""
static var input_problems: Dictionary={}
static var _source_items: Dictionary={}
static var _items_ready: bool=false

static func _items() -> Dictionary:
	var identity: Dictionary=SOURCE.identity()
	if identity.is_empty():source_problem=SOURCE.problem();return {}
	if _items_ready:
		source_problem="원본 탄약 입력 보류: "+str(input_problems) if not input_problems.is_empty() else ""
		return _source_items
	var items: Dictionary={}
	var issues: Dictionary={}
	for id: int in FAMILIES:
		var parsed: Dictionary=_item_input(id)
		if not parsed.get("error","").is_empty():issues[str(id)]=str(parsed.error)
		else:items[str(id)]=parsed.spec
	_source_items=items
	input_problems=issues
	# This is the original archive identity, not a generated/memory model SHA.
	source_identity=identity.duplicate(true)
	source_problem="원본 탄약 입력 보류: "+str(issues) if not issues.is_empty() else ""
	_items_ready=true
	return _source_items

static func _item_input(id: int) -> Dictionary:
	var item: Dictionary=SOURCE.row("ItemClass",id)
	if item.is_empty():return {"error":"source_ItemClass_unavailable"}
	if item.get("TestItem")!=false or not SOURCE.declared_exclusion("ItemClass",item).is_empty():return {"error":"source_item_excluded"}
	var values: Dictionary={}
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",id):
		var bonus: Dictionary=SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary=SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1))) if not bonus.is_empty() else {}
		if bonus.is_empty() or type.is_empty():return {"error":"source_ammo_bonus_join_unavailable"}
		var kind: String=str(type.get("Name",""))
		if kind not in BONUS_NAMES or link.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or values.has(kind):return {"error":"conditional_unsupported_or_duplicate_ammo_bonus"}
		if not SOURCE.declared_exclusion("ItemBonus",link).is_empty() or not SOURCE.declared_exclusion("Bonus",bonus).is_empty() or not SOURCE.declared_exclusion("BonusType",type).is_empty():return {"error":"source_ammo_bonus_excluded"}
		if not _integer(bonus.get("Value")):return {"error":"source_ammo_bonus_value_unavailable"}
		values[kind]=bonus.Value
	if not values.has("WeaponSmallDamage") or not values.has("WeaponLargeDamage") or not _integer(item.get("MaterialID")):return {"error":"source_ammo_damage_or_material_unavailable"}
	var label: Dictionary=SOURCE.row("DescData_Korean",int(item.get("DescID",0)))
	if not label.get("Description") is String or str(label.Description).is_empty():return {"error":"source_ammo_label_unavailable"}
	return {"spec":{"name":str(label.Description),"family":str(FAMILIES[id]),"small":values.WeaponSmallDamage,"large":values.WeaponLargeDamage,"material":item.MaterialID}}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func definition(record: Dictionary) -> Dictionary:
	var spec: Dictionary=_items().get(str(int(record.get("source_item_class_id",0))),{})
	if spec.is_empty() or record.get("source")!="twilight-shop523-ammo" or record.get("source_bless_raw")!=1 or record.get("name")!=spec.name or record.get("slot")!="ammo":return {}
	return spec

static func install(world,catalog) -> Dictionary:
	var result: Dictionary={};var changed: bool=false
	var items: Dictionary=_items()
	for id: String in items:
		var spec: Dictionary=items[id]
		var item: Dictionary=catalog.record("ItemClass",int(id))
		if item.is_empty() or item.get("TestItem",true) or catalog.label(int(item.get("DescID",0)))!=spec.name:continue
		var name: String=str(spec.name)
		var record: Dictionary=world._find_catalog_item_record(name)
		var fresh: bool=record.is_empty()
		if not record.is_empty() and definition(record).is_empty():continue
		if record.is_empty():
			record={"name":name,"grade":"일반","slot":"ammo","type":"탄약","source":"twilight-shop523-ammo","source_item_class_id":int(id),"source523_shop_item_id":int(id),"source_bless_raw":1,"source523_shop_use_origin":str(DATA.data.origin),"weight":0,"desc":"%s 계열 · 소형 %d / 대형 %d · %s" % [str(spec.family),int(spec.small),int(spec.large),str(DATA.data.origin)]}
		record.merge({"source_weight_raw":item.get("Weight",0),"source_max_stack":int(item.get("MaxStackAmount",0)),"droppable":item.get("IsDroppable",false),"storable":item.get("IsStorable",false),"source_is_tradable":item.get("IsTradable",false)},true)
		if fresh:
			world.item_db.append(record.duplicate(true));world.catalog_db["아이템"].append(record);changed=true
		result["4:"+id]={"name":name,"record":record.duplicate(true)}
	if changed:world._index_item_weights()
	return result

static func selected(world,family: String) -> Dictionary:
	var record: Dictionary=world._find_catalog_item_record(str(world.equipped_ammo))
	var spec: Dictionary=definition(record)
	return record.duplicate(true) if not spec.is_empty() and spec.family==family else {}

static func roll(record: Dictionary,target,rng: RandomNumberGenerator) -> int:
	var spec: Dictionary=definition(record)
	if spec.is_empty() or target==null or DATA.data.damage_policy!="uniform_size_die":return 0
	var maximum: int=int(spec.large) if str(target.get_meta("size_class","small")).to_lower()=="large" else int(spec.small)
	var result: int=rng.randi_range(1,maximum) if maximum>0 else 0
	if target.is_undead() and int(spec.material) in DATA.data.estimated_undead_materials:result+=int(DATA.data.estimated_undead_bonus)
	return result
