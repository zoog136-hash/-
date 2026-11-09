extends "res://tests/source523_npc_local_main_test.gd"
const TicketWorld=preload("res://tests/source523_ticket_world_fixture.gd")
func run() -> void:
	if OS.get_environment("TWILIGHT_TICKET_CONTRACT_TEST")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():printerr("REQUIRES_PREVIOUS_ISOLATED_TICKET_CONTRACT_PROFILE");quit(2);return
	var world:Node=load("res://Main.tscn").instantiate();world.set_script(TicketWorld);root.add_child(world);freeze(world)
	var runtime=world.source_shop;var consumer=runtime.inventory_tickets
	check(not world.source_save_blocked and int(runtime.state.get("ticket_redemption",{}).get("uses",0))==10,"fresh Main retains ten committed fixture-owned ticket uses")
	check(world.expedition_local.state.issued.size()==6,"contract-only issuer ledger restored by fixture save hook")
	var before:PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
	var cards:Dictionary=world.card_draw_fusion.export_state();var state:Dictionary=runtime.export_state()
	var good_key:String=str(consumer.runtime.catalog.record("ItemClass",166744).Name)+" (탐험 166744:1:0)"
	check(int(world.inventory.get(good_key,0))==0 and not runtime.use_inventory_ticket(good_key).ok,"fresh empty source stack cannot replay committed native result")
	var relic_key:String=str(consumer.runtime.catalog.record("ItemClass",254088).Name)+" (탐험 254088:1:0)"
	var blocked:Dictionary=runtime.quote_inventory_ticket(relic_key)
	check(not blocked.ok and blocked.get("missing_card_ids",[])==[25162] and int(world.inventory.get(relic_key,0))==2,"fresh exact relic ticket retains full original pool and missing positive-weight card25162")
	# Nonpersistent quote-isolation probes; no ticket/card issuance or redemption.
	world.inventory[good_key]=1
	var quoted:Dictionary=runtime.quote_inventory_ticket(good_key)
	check(quoted.ok and int(quoted.draw_count)==1,"existing registered issuer identity validates an isolated quote probe")
	if quoted.ok:
		var pool:String=str(int(quoted.grants[0].pool_id));var original_name:String=str(quoted.pools[pool][0].entry.record.name)
		quoted.grants[0].count=999;quoted.pools[pool][0].entry.record.name="invalid caller mutation"
		var again:Dictionary=runtime.quote_inventory_ticket(good_key)
		check(again.ok and int(again.draw_count)==1 and str(again.pools[pool][0].entry.record.name)==original_name,"quote grant/card data cannot mutate source policy or registered701 records")
		var control:=Control.new();world.hud.card_reveal_stage=control
		check(not runtime.use_inventory_ticket(good_key).ok and int(world.inventory.get(good_key,0))==1,"result presentation reentry preserves ticket")
		world.hud.card_reveal_stage=null;control.free()
	world.inventory.erase(good_key)
	check(world.card_draw_fusion.export_state()==cards and runtime.export_state()==state and FileAccess.get_file_as_bytes(world.save_path())==before,"all fresh replay/quote probes preserve exact durable cards, ticket RNG/counters and issuer bytes")
	print("SOURCE523_TICKET_RESTART_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"issuer":"controlled contract ledger, not an expedition completion"}))
	world.queue_free();await frames();quit(1 if failures else 0)
