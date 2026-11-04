extends "res://tests/source523_npc_local_main_test.gd"
class DefinitionHost extends Node:
	var item_db: Array=[]
	var catalog_db: Dictionary={"아이템":[]}
	var item_weight_index: Dictionary={}
	var inventory: Dictionary={}
	func _find_catalog_item_record(name: String) -> Dictionary:
		for record: Dictionary in catalog_db["아이템"]:
			if record.name==name:return record
		return {}
	func _index_item_weights() -> void:pass

func run() -> void:
	var source=Catalog.session()
	for identity: String in ["126424","wrong-id","cursed","bless-state"]:
		var host=DefinitionHost.new()
		var original: Dictionary={"name":"잊혀진 귀환 주문서 (각인)","sourceId":"126424" if identity!="wrong-id" else "99","grade":"일반","slot":"consumable","desc":"existing regional consumer definition"}
		if identity=="cursed":original["source_bless_raw"]=2
		if identity=="bless-state":original.merge({"source_bless_raw":1,"bless_state":"cursed"})
		host.catalog_db["아이템"].append(original)
		var bindings: Dictionary=preload("res://scripts/shop/source523_npc_consumables.gd").install(host,source)
		check(bindings.has("4:126424")== (identity=="126424"),"existing exact host definition coexists; wrong ID/blessing is rejected: "+identity)
		check(original.desc=="existing regional consumer definition" and host.inventory.is_empty(),"supplier decoration preserves prior use description and grants nothing: "+identity)
		if identity=="126424":check(original.get("source_bless_raw")==1 and original.get("source523_shop_item_id")==126424,"original Normal sale provides explicit supply metadata to the existing host definition")
		if identity=="cursed":check(original.get("source_bless_raw")==2 and not original.has("source523_shop_item_id"),"cursed exact-name stack is never changed into Normal")
		host.free()
	var item: String="잊혀진 귀환 주문서 (각인)"
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(world.source_shop.catalog!=null and world.source_shop.catalog.available(),"same explicit source pack binds on fresh startup")
	check(world.hud.shop_view==null,"catalog is available before first shop visit")
	var record: Dictionary=world._find_catalog_item_record(item)
	check(record.get("name")==item and record.get("source523_shop_item_id")==126424 and record.get("source_item_class_id")==126424 and record.get("source_bless_raw")==1,"fresh process registers exact dedicated key and explicit Normal identity")
	check(record.get("source_is_consumable")==true and record.get("source523_shop_supply_only")==true,"fresh startup preserves consumable supply contract without an effect")
	check(int(world.inventory.get(item,0))==2 and int(world.gold)==100000 and world.source_shop.orders().is_empty(),"actual paid supply and wallet survive process restart with no pending grant")
	var available: int=0
	for sale: Dictionary in world.source_shop.catalog.rows("MerchantGoods"):
		if int(sale.MerchantsID)==514 and world.source_shop.quote_merchant(int(sale.ID)).ok:available+=1
	check(available==17,"island stock has existing16 goods plus the one exact dedicated return supply")
	var path: String=world.save_path();var before: PackedByteArray=FileAccess.get_file_as_bytes(path)
	check(not world.source_shop.claim("1").ok and int(world.inventory.get(item,0))==2 and FileAccess.get_file_as_bytes(path)==before,"process restart cannot duplicate paid receipt or overwrite save on rejection")
	world.queue_free();await frames()
	print("SOURCE523_RETURN_SUPPLY_RESTART_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
