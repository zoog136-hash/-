extends "res://tests/source523_npc_local_main_test.gd"
const TicketWorld=preload("res://tests/source523_ticket_world_fixture.gd")
func run() -> void:
	if OS.get_environment("TWILIGHT_TICKET_CONTRACT_TEST")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():printerr("REQUIRES_PREVIOUS_ISOLATED_TICKET_CONTRACT_PROFILE");quit(2);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="):capture_directory=arg.trim_prefix("--source523-capture-dir=")
	var world:Node=load("res://Main.tscn").instantiate();world.set_script(TicketWorld);root.add_child(world);freeze(world)
	var consumer=world.source_shop.inventory_tickets;var random_before:int=consumer.random.state
	consumer.configure(world.source_shop)
	check(consumer.random.state==random_before,"reopening/rebinding a source catalogue never reseeds pending native ticket RNG")
	var name:String=str(consumer.runtime.catalog.record("ItemClass",254088).Name)+" (탐험 254088:1:0)"
	var before:PackedByteArray=FileAccess.get_file_as_bytes(world.save_path());var state:Dictionary=world.source_shop.export_state()
	world.hud.show_companion_bag();await frames();var bag=world.hud.lineage_inventory_ui
	bag._select_item(name);bag.open_detail();await frames()
	check(bag.detail_action.text=="사용" and not bag.detail_action.disabled and bag.detail_text.text.contains("TWILIGHT 소지 티켓1개"),"actual typed expedition-ticket detail shows use action and local policy before consumption")
	check(bag.quick_button.disabled,"native random tickets cannot be accidentally assigned to automatic quickslot consumption")
	await capture("owned-native-ticket-policy-detail")
	tap(bag.detail_action);await frames()
	check(int(world.inventory.get(name,0))==2 and not world.hud.is_card_reveal_busy(),"actual inventory route preserves relic stock when positive native card25162 is unavailable")
	check(world.source_shop.export_state()==state and FileAccess.get_file_as_bytes(world.save_path())==before,"blocked UI use preserves durable ticket RNG/counter and issuer bytes")
	print("SOURCE523_TICKET_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":"existing controlled issuer fixture profile, no new ticket/card grant"}))
	world.queue_free();await frames();quit(1 if failures else 0)
