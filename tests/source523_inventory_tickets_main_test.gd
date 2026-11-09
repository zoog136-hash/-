extends "res://tests/source523_npc_local_main_test.gd"
const TicketWorld=preload("res://tests/source523_ticket_world_fixture.gd")
const TicketRules=preload("res://scripts/shop/source523_inventory_tickets.gd")

func close_reveal(world:Node) -> void:
	if is_instance_valid(world.hud.card_reveal_stage):world.hud.card_reveal_stage.close_reveal()
	await frames()

func total_cards(world:Node) -> int:
	var total:int=0
	for category:String in world.card_draw_fusion.CATEGORIES:
		total+=world.card_draw_fusion.owned[category].size()
		for count:Variant in world.card_draw_fusion.spare[category].values():total+=int(count)
	return total

func run() -> void:
	if OS.get_environment("TWILIGHT_TICKET_CONTRACT_TEST")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():printerr("REQUIRES_ISOLATED_TICKET_CONTRACT_PROFILE");quit(2);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="):capture_directory=arg.trim_prefix("--source523-capture-dir=")
	var world:Node=load("res://Main.tscn").instantiate();world.set_script(TicketWorld);root.add_child(world);freeze(world)
	check(QA.enter_game(world),"actual Main class selection with explicitly controlled issuer ledger fixture");freeze(world)
	var runtime=world.source_shop;var consumer=runtime.inventory_tickets
	check(not consumer.loaded_sha.is_empty() and consumer.problem.is_empty(),"private six-ticket extension verified against installed original shop input")
	if consumer.loaded_sha.is_empty():world.queue_free();await frames();quit(1);return
	var keys:Dictionary={};var pool_before:Dictionary=world.card_draw_fusion.known_ids.duplicate(true)
	var gold:int=int(world.gold);var rng_before:int=world.card_draw_fusion.rng.state
	var pity_before:Dictionary=world.card_draw_fusion.pity.duplicate(true)
	for id:int in TicketRules.IDS:
		var spec:Dictionary=consumer.document.tickets[str(id)]
		var key:String=str(id)+":1:0";var original:Dictionary=consumer.runtime.catalog.record("ItemClass",id);var name:String=str(original.Name)+" (탐험 "+key+")"
		keys[id]=name
		# QA-owned stock only, not a production ticket/card grant or expedition run.
		world.expedition_local.state.issued[key]=name;world.inventory[name]=2
		world.catalog_db["아이템"].append({"name":name,"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:expedition:"+key,"source_item_class_id":id,"source_item":original.duplicate(true),"expedition_key":key,"slot":"material","type":"탐험 보상","grade":"일반","weight":0})
	world._index_item_weights()
	check(world._save_game(true)==OK,"controlled owned-ticket and issuer proof baseline saved")
	var blocked:Dictionary=runtime.quote_inventory_ticket(str(keys[254088]))
	check(not blocked.ok and blocked.get("missing_card_ids",[])==[25162] and int(world.inventory[str(keys[254088])])==2,"positive-weight missing native card25162 blocks entire original relic pool without shrinking or free registration")
	var received:int=0
	for id:int in [166744,342064,342074,352054,352064]:
		var name:String=str(keys[id]);var quote:Dictionary=runtime.quote_inventory_ticket(name)
		check(quote.ok and int(quote.bless_raw)==1 and int(quote.enchant)==0,"issued exact Normal key has complete original pool")
		if not quote.ok:world.queue_free();await frames();quit(1);return
		check(not runtime.quote_inventory_ticket(name,{"index":0}).ok,"random ticket cannot choose or inject a selected card")
		var old_cards:Dictionary=world.card_draw_fusion.export_state();var old_inventory:Dictionary=world.inventory.duplicate(true)
		var bytes_before:PackedByteArray=FileAccess.get_file_as_bytes(world.save_path());var native_rng:int=consumer.random.state
		world.equipment_collections.test_save_writer=func(_path:String,_data:Dictionary)->Error:return ERR_CANT_CREATE
		check(not runtime.use_inventory_ticket(name).ok,"ticket use obeys actual atomic save failure")
		check(world.inventory==old_inventory and world.card_draw_fusion.export_state()==old_cards and consumer.random.state==native_rng,"failed ticket write preserves exact source stack/cards/native RNG")
		check(FileAccess.get_file_as_bytes(world.save_path())==bytes_before,"failed native redemption preserves durable issuer/commerce bytes")
		world.equipment_collections.test_save_writer=Callable()
		var record:Dictionary=world._find_catalog_item_record(name)
		record.expedition_key=str(id)+":2:0"
		check(not runtime.use_inventory_ticket(name).ok and world.inventory==old_inventory,"different blessing tuple cannot consume Normal proof")
		record.expedition_key=str(id)+":1:0"
		record.source_expires_at=1
		check(not runtime.use_inventory_ticket(name).ok and world.inventory==old_inventory,"existing expired provider deadline is never extended")
		record.erase("source_expires_at")
		var before:int=total_cards(world)
		var used:Dictionary=runtime.use_inventory_ticket(name)
		check(used.ok and used.get("handled")==true and int(used.consumed)==1 and int(used.count)==int(quote.draw_count),"actual API consumes one exact owned ticket for original result count")
		check(int(world.inventory.get(name,0))==1 and total_cards(world)==before+int(quote.draw_count),"one-ticket debit and original card/duplicate credit publish together")
		check(world.card_draw_fusion.known_ids==pool_before and world.card_draw_fusion.rng.state==rng_before,"existing701 pool and generic draw RNG unchanged")
		check(world.hud.is_card_reveal_busy(),"existing card reveal UI presents committed native results")
		await close_reveal(world)
		world._load_game(true);freeze(world)
		check(int(world.inventory.get(name,0))==1 and total_cards(world)==before+int(quote.draw_count),"native result/count and exact issuer key survive reload")
		# Exercise the real inventory action for the second owned fixture unit.
		world.hud.show_companion_bag();await frames();var bag=world.hud.lineage_inventory_ui
		bag._select_item(name);bag.open_detail();await frames()
		check(not bag.detail_action.disabled,"typed expedition material exposes existing inventory action")
		tap(bag.detail_action);await frames()
		check(int(world.inventory.get(name,0))==0 and total_cards(world)==before+2*int(quote.draw_count),"real inventory event routes to native ticket consumer, not material/equipment fallback")
		await close_reveal(world)
		check(not runtime.use_inventory_ticket(name).ok,"empty exact source stack cannot replay a draw")
		received+=2*int(quote.draw_count)
	check(int(world.gold)==gold and world.card_draw_fusion.pity==pity_before,"owned-ticket use charges no linked market price and does not modify generic fusion pity")
	check(int(runtime.state.ticket_redemption.uses)==10,"successful one-ticket consumption counter persists, failed uses do not increment")
	check(int(world.inventory[str(keys[254088])])==2,"unavailable original relic pool retains owned stock")
	check(world._save_game(true)==OK,"source redemption/RNG/issuer and card results saved for fresh process")
	await capture("owned-ticket-committed-result")
	print("SOURCE523_TICKET_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"fixture_owned_ticket_types_used":5,"cards_or_duplicates_received":received,"actual_expedition_acquisition_runs":0,"unavailable_native_card":25162}))
	world.queue_free();await frames();quit(1 if failures else 0)
