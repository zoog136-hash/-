extends "res://tests/source523_regional_purchase_main_test.gd"
const RECOVERY=preload("res://scripts/shop/source523_restoration.gd")

func run() -> void:
	if OS.get_environment("TWILIGHT_SOURCE_RECOVERY_TEST")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		printerr("REQUIRES_ISOLATED_SOURCE_RECOVERY_PROFILE");quit(2);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="):capture_directory=arg.trim_prefix("--source523-capture-dir=")
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(QA.enter_game(world),"actual Main character selection")
	freeze(world);world.gold=1000000;world.level=80
	world.hud.open_shop();await frames();tap(world.hud.shop_view.find_child("Source523Shop",true,false));await frames()
	var panel: Node=world.hud.shop_view.find_child("Source523ShopPanel",true,false)
	check(panel!=null,"actual original shop UI")
	if panel==null:world.queue_free();quit(1);return
	var expected_inventory: Dictionary={};var total_paid: int=0
	for sale_id: int in [1930,1931,37718]:
		var quote: Dictionary=world.source_shop.quote_merchant(sale_id,2)
		check(quote.ok,"exact normal original recovery item is available")
		if not quote.ok:world.queue_free();quit(1);return
		var name: String=str(quote.name)
		var legacy: int=int(world.inventory.get("HP 물약",0))
		check(int(world.inventory.get(name,0))==0,"definition registration never grants recovery items")
		if not await buy_and_receive(panel,world,sale_id,2):world.queue_free();quit(1);return
		total_paid+=int(quote.payment.amount)
		world.hp=world._effective_max_hp()-500;world.item_use_cooldowns.clear()
		check(world._save_game(true)==OK,"paid source item and old HP saved")
		var old_hp: int=int(world.hp);var old_rng: int=world.rng.state
		var bytes_before: PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
		world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
		world._on_inventory_item_activated(name)
		check(int(world.inventory.get(name,0))==2 and int(world.hp)==old_hp and world.rng.state==old_rng,"failed source healing restores exact source quantity, HP and RNG")
		check(world.item_use_cooldowns.is_empty() and FileAccess.get_file_as_bytes(world.save_path())==bytes_before,"failed healing preserves shared cooldown and exact durable receipts")
		world.equipment_collections.test_save_writer=Callable()
		var record: Dictionary=world._find_catalog_item_record(name)
		record.source_bless_raw=2;world._on_inventory_item_activated(name)
		check(int(world.inventory.get(name,0))==2 and int(world.hp)==old_hp,"blessing mismatch cannot heal or consume")
		record.source_bless_raw=1
		world.hud.show_companion_bag();await frames()
		var bag=world.hud.lineage_inventory_ui
		bag._select_item(name);bag.open_detail();await frames()
		check(not bag.detail_action.disabled,"real inventory recovery action is enabled")
		tap(bag.detail_action);await frames()
		check(int(world.inventory.get(name,0))==1 and int(world.hp)>old_hp,"actual inventory UI consumes one bought source stack and heals")
		check(int(world.inventory.get("HP 물약",0))==legacy,"legacy user-balanced potion stack is untouched")
		var after_hp: int=int(world.hp)
		world._on_inventory_item_activated(name)
		check(int(world.inventory.get(name,0))==1 and int(world.hp)==after_hp,"existing shared potion cooldown blocks duplicate use")
		world.item_use_cooldowns.clear();world.hp=world._effective_max_hp()
		world._on_inventory_item_activated(name)
		check(int(world.inventory.get(name,0))==1,"full HP preserves source potion")
		expected_inventory[name]=1
	check(int(world.gold)==1000000-total_paid,"all three original source prices charged exactly")
	check(world._save_game(true)==OK,"source quantities and claimed receipts save")
	world._load_game(true);freeze(world)
	for name: String in expected_inventory:check(int(world.inventory.get(name,0))==1,"saved exact engraved recovery stack survives reload")
	check(world.source_shop.orders().is_empty(),"all recovery receipts remain claimed")
	await capture("source-recovery-purchased-used-saved")
	print("SOURCE523_RECOVERY_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_paid_recovery_items":3,"total_paid":total_paid}))
	world.queue_free();await frames();quit(1 if failures else 0)
