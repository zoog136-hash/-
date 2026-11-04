extends RefCounted
## Exact source identity and separate engraved stacks; supply-only items add no effect.
const Rules=preload("res://scripts/consumable_rules.gd")
const PATH: String="res://data/shop/source523_npc_consumables.json"
static func install(world, catalog) -> Dictionary:
	var settings: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var result: Dictionary={}
	if not settings is Dictionary or settings.get("schema")!="twilight.source523.npc-consumables.v1" or settings.get("enabled")!=true or not settings.get("items") is Dictionary or not settings.get("origin") is String:return result
	var changed: bool=false
	for id: String in settings.items:
		if not id.is_valid_int():continue
		var original: Dictionary=catalog.record("ItemClass",int(id))
		var name: String=str(settings.items[id])
		var supply_only: bool=id in settings.get("supply_only_ids",[])
		var spec: Dictionary=Rules.definition(name)
		if supply_only:
			if id!="126424" or name!="잊혀진 귀환 주문서 (각인)" or int(original.get("GradeID",0))!=1:continue
			var offer: Dictionary=catalog.merchant_offer(16884)
			var sale: Dictionary=offer.get("goods",{})
			if int(sale.get("MerchantsID",0))!=514 or int(sale.get("ItemClassID",0))!=int(id) or int(sale.get("DialogActionTypeID",0))!=1 or int(sale.get("ItemBlessCodeID",0))!=1 or int(sale.get("Enchant",-1))!=0 or int(sale.get("ElementalEnchant",-1))!=0 or int(sale.get("Amount",0))!=1:continue
			spec={"name":name,"grade":"일반","type":"이동주문서","slot":"consumable","kind":"regional_return_supply","desc":str(settings.get("supply_origin","지역 귀환 기능 연결 후 사용"))}
		if original.is_empty() or catalog.label(int(original.get("DescID",0)))!=name or original.get("TestItem",false) or (not supply_only and spec.get("kind","") not in ["return","teleport","regen","food"]):continue
		var record: Dictionary=world._find_catalog_item_record(name)
		if not record.is_empty():
			var identity: String=str(record.get("source523_shop_item_id",record.get("native_item_id",record.get("sourceId",""))))
			if identity!=id:continue
			if supply_only:
				if record.get("source_bless_raw",1)!=1 or int(record.get("source_item_class_id",126424))!=126424 or record.get("slot")!="consumable" or record.get("grade")!="일반" or str(record.get("bless_state","")).to_lower() in ["blessed","cursed","축복","저주"]:continue
				_supply_metadata(record,original,str(spec.desc))
		else:
			record=spec.duplicate(true)
			record["name"]=name
			record["source"]="twilight-shop523-consumable"
			record["source523_shop_item_id"]=int(id)
			record["source523_shop_use_origin"]=str(settings.origin)
			record["desc"]=str(spec.get("desc",""))+" · "+str(settings.origin)
			record["weight"]=world._find_catalog_item_record(str(spec.name)).get("weight",0)
			if supply_only:
				record["desc"]=str(spec.desc)
				_supply_metadata(record,original,str(spec.desc))
				record["weight"]=int(world.item_weight_index.get("귀환 주문서",3))
			world.item_db.append(record.duplicate(true))
			world.catalog_db["아이템"].append(record)
			changed=true
		result["4:"+id]={"name":name,"record":record.duplicate(true)}
	if changed:world._index_item_weights()
	return result

static func _supply_metadata(record: Dictionary, original: Dictionary, origin: String) -> void:
	# Add supplier identity to the exact host definition; keep its existing use/desc.
	record.merge({"source523_shop_item_id":126424,"source523_shop_supply_only":true,
		"source523_shop_use_origin":origin,"source_item_class_id":126424,"source_bless_raw":1,
		"source_is_consumable":true,"source_test_item":false,"source_weight_raw":original.get("Weight",0)},true)
