extends RefCounted
const DATA=preload("res://data/shop/source523_ammo.json")

static func definition(record: Dictionary) -> Dictionary:
	var spec: Dictionary=DATA.data.items.get(str(int(record.get("source_item_class_id",0))),{})
	if spec.is_empty() or record.get("source")!="twilight-shop523-ammo" or record.get("source_bless_raw")!=1 or record.get("name")!=spec.name or record.get("slot")!="ammo":return {}
	return spec

static func install(world,catalog) -> Dictionary:
	var result: Dictionary={};var changed: bool=false
	for id: String in DATA.data.items:
		var spec: Dictionary=DATA.data.items[id]
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
