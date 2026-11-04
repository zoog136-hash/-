extends "res://tests/source523_npc_local_main_test.gd"
const ITEM: String="잊혀진 귀환 주문서 (각인)"
func run() -> void:
	root.size=Vector2i(960,540);DisplayServer.window_set_size(root.size)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="):capture_directory=arg.trim_prefix("--source523-capture-dir=")
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(QA.enter_game(world),"actual Main/class selection")
	freeze(world)
	var runtime=world.source_shop
	check(runtime.catalog!=null and runtime.catalog.available(),"same verified explicit shop pack loaded at startup")
	if runtime.catalog==null or not runtime.catalog.available():world.queue_free();quit(1);return
	var definition: Dictionary=world._find_catalog_item_record(ITEM)
	check(int(definition.get("source523_shop_item_id",0))==126424 and int(definition.get("source_item_class_id",0))==126424 and definition.get("source_bless_raw")==1,"exact ID and explicit Normal blessing registered before shop visit")
	check(definition.get("name")==ITEM and definition.get("source")=="twilight-shop523-consumable" and definition.get("slot")=="consumable" and definition.get("source_is_consumable")==true and definition.get("grade")=="일반" and definition.get("source_test_item")==false,"canonical non-native supply key fits the PR252 normal-stack consumer contract")
	check(definition.get("source523_shop_supply_only")==true and not definition.get("source_m_native_item",false) and str(definition.get("desc","")).contains("지역 귀환 기능 연결 후"),"catalog clearly exposes supply-only scope without impersonating another supplier")
	world.level=79
	check(not runtime.quote_merchant(16884).ok,"existing level80 access gate is preserved")
	world.level=80;world.gold=200000
	var before: int=int(world.inventory.get(ITEM,0))
	var ordinary: int=int(world.inventory.get("귀환 주문서 (각인)",0))
	var old_plain: int=int(world.inventory.get("귀환 주문서",0))
	check(before==0,"catalog registration never grants a free supply stack")
	check(not runtime.quote_merchant(17234).ok,"Action2 buyback row remains non-supply")
	var quote: Dictionary=runtime.quote_merchant(16884,2)
	check(quote.ok and str(quote.name)==ITEM and int(quote.payment.amount)==100000 and int(quote.payment.unit_id)==201 and int(quote.payment.class_id)==1,"original Cost50000/Percentage100/Amount1 gives two units for100000 Adena")
	if not quote.ok:world.queue_free();quit(1);return
	check(world._save_game(true)==OK,"isolated baseline save")
	var path: String=world.save_path()
	var baseline: PackedByteArray=FileAccess.get_file_as_bytes(path)
	world.gold=49999
	check(not runtime.buy_merchant(16884).ok and int(world.gold)==49999 and runtime.orders().is_empty(),"insufficient funds charge nothing and create no order")
	check(FileAccess.get_file_as_bytes(path)==baseline,"insufficient funds preserve durable save bytes")
	world.gold=200000
	world.hud.open_shop();await frames()
	tap(world.hud.shop_view.find_child("Source523Shop",true,false));await frames()
	var panel: Node=world.hud.shop_view.find_child("Source523ShopPanel",true,false)
	check(panel!=null,"existing ordinary shop opens source supply UI")
	if panel==null:world.queue_free();quit(1);return
	panel.mode.select(1);panel.mode.item_selected.emit(1);panel.search.text="16884";panel._filter()
	for index: int in range(panel.listing.item_count):
		if int(panel.listing.get_item_metadata(index))==16884:panel._select(index)
	panel.quantity.value=2;await frames()
	check(not panel.purchase.disabled and panel.detail.text.contains("아이즈") and panel.detail.text.contains("지역 귀환 기능 연결 후"),"existing island NPC UI exposes exact item and supply-only boundary")
	await capture("dedicated-return-available")
	tap(panel.purchase);await frames()
	var confirmation: Control=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"supply purchase confirmation");world.queue_free();quit(1);return
	tap(confirmation.cancel_button);await frames()
	check(int(world.gold)==200000 and runtime.orders().is_empty() and FileAccess.get_file_as_bytes(path)==baseline,"UI cancellation preserves money, orders and exact save")
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
	tap(panel.purchase);await frames();confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"failed-write purchase confirmation");world.queue_free();quit(1);return
	tap(confirmation.confirm_button);await frames()
	check(int(world.gold)==200000 and runtime.orders().is_empty() and int(world.inventory.get(ITEM,0))==before and FileAccess.get_file_as_bytes(path)==baseline,"UI purchase writer failure rolls back wallet, stack, order and bytes")
	world.equipment_collections.test_save_writer=Callable()
	tap(panel.purchase);await frames();confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"successful supply purchase confirmation");world.queue_free();quit(1);return
	tap(confirmation.confirm_button);await frames()
	check(int(world.gold)==100000 and int(world.inventory.get(ITEM,0))==before and runtime.orders().size()==1,"successful UI purchase debits original price and leaves goods in inbox")
	if runtime.orders().size()!=1:world.queue_free();quit(1);return
	var order: String=str(runtime.orders()[0].id)
	var paid: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var stored: Dictionary=JSON.parse_string(paid.get_string_from_utf8())
	check(stored.source_shop.orders[order].goods.size()==1 and int(stored.source_shop.orders[order].goods[0].unit_id)==4 and int(stored.source_shop.orders[order].goods[0].class_id)==126424 and int(stored.source_shop.orders[order].goods[0].amount)==2,"paid order preserves exact original item ID and quantity")
	check(panel.mode.selected==4 and panel.detail.text.contains(ITEM),"real UI enters paid pending supply inbox")
	await capture("dedicated-return-inbox")
	var weight: int=int(world.item_weight_index.get(ITEM,3))
	world.item_weight_index[ITEM]=1000000
	check(not runtime.claim(order).ok and runtime.orders().size()==1 and int(world.inventory.get(ITEM,0))==before and int(world.gold)==100000,"overweight receipt keeps paid order without goods or second debit")
	check(FileAccess.get_file_as_bytes(path)==paid,"overweight receipt preserves exact paid save")
	world.item_weight_index[ITEM]=weight
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
	check(not runtime.claim(order).ok and runtime.orders().size()==1 and int(world.inventory.get(ITEM,0))==before and FileAccess.get_file_as_bytes(path)==paid,"receipt writer failure preserves paid order, stack and durable bytes")
	world.equipment_collections.test_save_writer=Callable()
	world._load_game(true);freeze(world)
	check(runtime.orders().size()==1 and int(world.gold)==100000 and int(world.inventory.get(ITEM,0))==before,"reload restores paid pending supplier transaction")
	panel._build_entries();await frames()
	tap(panel.purchase);await frames();confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"supply receipt confirmation");world.queue_free();quit(1);return
	tap(confirmation.confirm_button);await frames()
	check(int(world.inventory.get(ITEM,0))==before+2 and int(world.gold)==100000 and runtime.orders().is_empty(),"actual inbox UI grants exact canonical stack without recharging")
	check(int(world.inventory.get("귀환 주문서 (각인)",0))==ordinary and int(world.inventory.get("귀환 주문서",0))==old_plain,"dedicated supply never merges into ordinary return stacks")
	check(not runtime.claim(order).ok,"duplicate dedicated receipt rejected")
	world.hud.show_companion_bag();await frames()
	var bag=world.hud.lineage_inventory_ui;bag._select_item(ITEM);bag.open_detail();await frames()
	check(bag.detail_text.text.contains("지역 귀환 기능 연결 후"),"inventory detail records separate consumption dependency")
	await capture("dedicated-return-received")
	var position: Vector2=world.player.global_position
	tap(bag.detail_action);await frames()
	check(int(world.inventory.get(ITEM,0))==before+2 and world.player.global_position==position,"supply branch adds no generic return fallback or duplicated movement effect")
	check(world._save_game(true)==OK,"received exact source supply saves")
	world._load_game(true);freeze(world)
	check(int(world.inventory.get(ITEM,0))==before+2 and not runtime.claim(order).ok,"received source stack and replay protection survive reload")
	world.queue_free();await frames()
	print("SOURCE523_RETURN_SUPPLY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
