extends "res://tests/source523_regional_purchase_main_test.gd"
const WISDOM=preload("res://scripts/shop/source523_wisdom.gd")
func run() -> void:
	if OS.get_environment("TWILIGHT_SOURCE_WISDOM_TEST")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():printerr("REQUIRES_ISOLATED_SOURCE_WISDOM_PROFILE");quit(2);return
	var world:Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(QA.enter_game(world),"actual Main class selection");freeze(world);world.level=80;world.gold=100000
	world.hud.open_shop();await frames();tap(world.hud.shop_view.find_child("Source523Shop",true,false));await frames()
	var panel:Node=world.hud.shop_view.find_child("Source523ShopPanel",true,false)
	check(panel!=null,"actual source shop UI")
	if panel==null:world.queue_free();quit(1);return
	var name:String=str(WISDOM.DATA.data.name)
	for id:int in [1943,16954]:
		if not await buy_and_receive(panel,world,id,2):world.queue_free();quit(1);return
	check(int(world.inventory.get(name,0))==4 and int(world.gold)==96000,"both real NPCs supply exact original1000 price and separate engraved key")
	var original_sp:int=world._spell_power_stat();var record:Dictionary=world._find_catalog_item_record(name)
	check(world._save_game(true)==OK,"paid wisdom baseline saved")
	var before:PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
	world.equipment_collections.test_save_writer=func(_path:String,_data:Dictionary)->Error:return ERR_CANT_CREATE
	world._on_inventory_item_activated(name)
	check(int(world.inventory.get(name,0))==4 and not world.active_item_buffs.has(name) and world._spell_power_stat()==original_sp,"failed write restores exact source item and buff/SP state")
	check(FileAccess.get_file_as_bytes(world.save_path())==before,"failed wisdom write preserves durable receipts")
	world.equipment_collections.test_save_writer=Callable()
	record.source_bless_raw=2;world._on_inventory_item_activated(name)
	check(int(world.inventory.get(name,0))==4 and not world.active_item_buffs.has(name),"wrong blessing is preserved")
	record.source_bless_raw=1
	world.hud.show_companion_bag();await frames();var bag=world.hud.lineage_inventory_ui
	bag._select_item(name);bag.open_detail();await frames();check(not bag.detail_action.disabled,"actual inventory exposes wisdom use")
	tap(bag.detail_action);await frames()
	check(int(world.inventory.get(name,0))==3 and world._spell_power_stat()==original_sp+2,"actual inventory use consumes paid source stack and adds original SP2")
	world._on_inventory_item_activated(name)
	check(int(world.inventory.get(name,0))==3,"shared same-item use cooldown prevents immediate repeat")
	world.mp=0;world._tick_item_buffs(30.0)
	check(int(world.mp)==2 and int(world.active_item_buffs[name].remaining)==270,"original regen2 reaches existing host30s tick and buff duration")
	check(world._save_game(true)==OK,"wisdom lifecycle saves")
	world._load_game(true);freeze(world)
	check(int(world.inventory.get(name,0))==3 and int(world.active_item_buffs[name].remaining)==270 and world._spell_power_stat()==original_sp+2,"source duration, exact quantity and SP survive reload")
	world._tick_item_buffs(270.0)
	check(not world.active_item_buffs.has(name) and world._spell_power_stat()==original_sp,"original timed buff expiration removes SP")
	world.item_use_cooldowns.clear();world._on_inventory_item_activated(name)
	check(int(world.inventory.get(name,0))==2 and world.active_item_buffs.has(name),"another actual paid unit can refresh a nonstacking source group")
	world._respawn_player("source buff death contract probe")
	check(not world.active_item_buffs.has(name) and world._spell_power_stat()==original_sp,"native non-death-immune buff clears through existing respawn hook")
	check(world._save_game(true)==OK and world.source_shop.orders().is_empty(),"consumption/death retains claimed supplier receipts")
	print("SOURCE523_WISDOM_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_paid_npc_rows":2,"regen_and_death":"controlled lifecycle probes; no original combat equivalence claim"}))
	world.queue_free();await frames();quit(1 if failures else 0)
