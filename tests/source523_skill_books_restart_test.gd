extends "res://tests/source523_npc_local_main_test.gd"
const BOOKS=preload("res://scripts/shop/source523_skill_books.gd")
func run() -> void:
	if OS.get_environment("TWILIGHT_SOURCE_BOOK_TEST")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():printerr("REQUIRES_PREVIOUS_ISOLATED_SOURCE_BOOK_PROFILE");quit(2);return
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(not world.source_save_blocked and world.source_shop.catalog.available(),"fresh Main loads original paid source-book state")
	var count:int=0
	for id:String in world.source_shop.state.orders:
		var order:Dictionary=world.source_shop.state.orders[id]
		if order.kind!="merchant":continue
		var offer:Dictionary=world.source_shop.catalog.merchant_offer(int(order.offer_id))
		if int(offer.goods.MerchantsID)!=10:continue
		var spec:Dictionary=BOOKS.contract(int(offer.goods.ItemClassID))
		check(not spec.is_empty() and int(world.original_skills.catalog.learned.get(str(spec.get("skill_id","")),0))==1,"fresh process retains each actually purchased learned ID")
		var record:Dictionary=world._find_catalog_item_record(str(order.display_name))
		var original:Dictionary=world.source_shop.catalog.record("ItemClass",int(offer.goods.ItemClassID))
		check(record.get("grade")=="일반" and int(record.get("source_max_stack",0))==int(original.MaxStackAmount) and record.get("storable")==original.IsStorable,"fresh source-book metadata preserves original grade, stack and storage flags")
		check(int(world.inventory.get(str(order.display_name),0))==0 and order.status=="claimed" and not world.source_shop.claim(id).ok,"fresh process cannot replay paid source-book receipt or consumption")
		count+=1
	check(count==65,"all65 previous actual paid book receipts survive the fresh process")
	print("SOURCE523_BOOK_RESTART_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_previous_paid_books":count}))
	world.queue_free();await frames();quit(1 if failures else 0)
