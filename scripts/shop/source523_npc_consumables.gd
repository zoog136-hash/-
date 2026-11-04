extends RefCounted
## Exact source identity, separate engraved stack, existing host use implementation.
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
		var spec: Dictionary=Rules.definition(name)
		if original.is_empty() or catalog.label(int(original.get("DescID",0)))!=name or original.get("TestItem",false) or spec.get("kind","") not in ["return","teleport","regen","food"]:continue
		var record: Dictionary=world._find_catalog_item_record(name)
		if not record.is_empty():
			var identity: String=str(record.get("source523_shop_item_id",record.get("native_item_id",record.get("sourceId",""))))
			if identity!=id:continue
		else:
			record=spec.duplicate(true)
			record["name"]=name
			record["source"]="twilight-shop523-consumable"
			record["source523_shop_item_id"]=int(id)
			record["source523_shop_use_origin"]=str(settings.origin)
			record["desc"]=str(spec.get("desc",""))+" · "+str(settings.origin)
			record["weight"]=world._find_catalog_item_record(str(spec.name)).get("weight",0)
			world.item_db.append(record.duplicate(true))
			world.catalog_db["아이템"].append(record)
			changed=true
		result["4:"+id]={"name":name,"record":record.duplicate(true)}
	if changed:world._index_item_weights()
	return result
