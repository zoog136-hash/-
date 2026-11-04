extends "res://tests/source523_npc_local_main_test.gd"
const RETURN: String="귀환 주문서 (각인)"
const DEDICATED: String="잊혀진 귀환 주문서 (각인)"

func buy_and_receive(panel: Node, world: Node, id: int, quantity: int) -> bool:
	panel.mode.select(1);panel.mode.item_selected.emit(1);panel.search.text=str(id);panel._filter()
	for index: int in range(panel.listing.item_count):
		if int(panel.listing.get_item_metadata(index))==id:panel._select(index)
	panel.quantity.value=quantity;await frames()
	check(not panel.purchase.disabled,"real NPC purchase is enabled: "+str(id))
	tap(panel.purchase);await frames()
	var confirmation: Control=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"real purchase confirmation");return false
	tap(confirmation.confirm_button);await frames()
	check(world.source_shop.orders().size()==1,"purchase creates one durable inbox order")
	if world.source_shop.orders().size()!=1:return false
	var order: String=str(world.source_shop.orders()[0].id)
	tap(panel.purchase);await frames();confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"real receipt confirmation");return false
	tap(confirmation.confirm_button);await frames()
	check(world.source_shop.orders().is_empty() and not world.source_shop.claim(order).ok,"receipt grants once and rejects replay")
	return true

func run() -> void:
	root.size=Vector2i(960,540);DisplayServer.window_set_size(root.size)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="):capture_directory=arg.trim_prefix("--source523-capture-dir=")
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(QA.enter_game(world),"actual combined Main class selection")
	freeze(world);world.level=80;world.gold=200000
	check(int(world.inventory.get(RETURN,0))==0 and int(world.inventory.get(DEDICATED,0))==0,"neither source scroll is supplied by a fixture or free registration")
	check(not world.get_regional_return_enabled(),"old/default preference remains off")
	var legacy: int=int(world.inventory.get("귀환 주문서",0))
	world.hud.open_shop();await frames()
	tap(world.hud.shop_view.find_child("Source523Shop",true,false));await frames()
	var panel: Node=world.hud.shop_view.find_child("Source523ShopPanel",true,false)
	check(panel!=null,"source shop is mounted in the same consumer executable")
	if panel==null:world.queue_free();quit(1);return
	if not await buy_and_receive(panel,world,1949,1):world.queue_free();quit(1);return
	if not await buy_and_receive(panel,world,16884,3):world.queue_free();quit(1);return
	check(int(world.gold)==49000 and int(world.inventory.get(RETURN,0))==1 and int(world.inventory.get(DEDICATED,0))==3,"original1000 plus3x50000 payment yields exact purchased source stacks")
	check(int(world.inventory.get("귀환 주문서",0))==legacy,"old generic stack is never coalesced")
	check(world.regional_return_stack(RETURN).item_class_id==239 and world.regional_return_stack(DEDICATED).item_class_id==126424,"consumer accepts actual supplier Normal identities")
	world._on_quickslot_assignment_requested(0,"item",RETURN)
	check(world._save_game(true)==OK,"purchased original key and existing stable skill IDs save before projection")
	world._load_game(true);freeze(world)
	var slots: Array=world.quickslots.duplicate(true)
	check(str(slots[0].id)==RETURN,"original purchased key registers without rewriting ownership")
	world.hud.open_settings_info();await frames()
	var toggle: CheckButton=world.hud.find_child("RegionalReturnEnabled",true,false)
	check(toggle!=null,"real combined settings UI exposes regional return toggle")
	if toggle==null:world.queue_free();quit(1);return
	toggle.button_pressed=true;await frames()
	check(world.get_regional_return_enabled() and str(world.hud.quickslot_entries[0].id)==RETURN,"setting enables while unrelated Aden keeps original slot")
	world._set_map("source_70",false);freeze(world);await frames()
	check(world.active_map_id=="source_70" and world.field_map!=null,"unchanged real source70 assets and reviewed field load")
	if world.active_map_id!="source_70" or world.field_map==null:world.queue_free();quit(1);return
	check(str(world.hud.quickslot_entries[0].id)==DEDICATED and world.quickslots==slots,"map entry projects target in HUD while preserving saved authored slots")
	check(world.regional_return_status().contains("TWILIGHT 대응"),"host-map estimate remains visible; no M terrain equivalence claim")
	var probes: Array=world.SOURCE_MAP84.policy()["source_70"].walk_probes
	var other: Vector2=world.field_map.coordinates.to_world(Vector2(probes[1][0],probes[1][1]))
	var spawn: Vector2=world._spawn_position()
	world.player.global_position=other
	world.hud._park_shared_panels();world.hud.workspace.hide();await frames()
	await capture("purchased-source70-slot")
	tap(world.hud.v20_quickslot_buttons[0]);await frames()
	check(world.player.global_position==spawn and int(world.inventory.get(DEDICATED,0))==2,"actual HUD touch consumes one purchased dedicated scroll and returns to existing map entry")
	check(int(world.inventory.get(RETURN,0))==1 and int(world.inventory.get("귀환 주문서",0))==legacy and int(world.gold)==49000,"regional consumption never spends ordinary keys or debits shop funds again")
	var path: String=world.save_path()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(saved.inventory.get(DEDICATED,0))==2 and saved.ui_preferences.regional_return_enabled==true and str(saved.quickslots[0].id)==RETURN,"consumer save includes preference, original key, paid receipts and reduced dedicated quantity")
	check(saved.source_shop.orders.size()==2 and str(saved.source_shop.orders["2"].status)=="claimed","shop receipt state survives consumer's same save write")
	await capture("purchased-return-consumed")
	world._set_map("aden_world",false);freeze(world);await frames()
	check(str(world.hud.quickslot_entries[0].id)==RETURN and world.quickslots==slots,"region exit restores purchased original key in the real HUD")
	world._load_game(true);freeze(world);await frames()
	check(world.active_map_id=="source_70" and str(world.hud.quickslot_entries[0].id)==DEDICATED and int(world.inventory.get(DEDICATED,0))==2,"reload restores actual consumer state and paid source ownership")
	world.set_regional_return_enabled(false);await frames()
	check(str(world.hud.quickslot_entries[0].id)==RETURN and world.quickslots==slots,"setting off restores original key without consuming either stack")
	world.set_regional_return_enabled(true);world.player.global_position=other
	check(world._save_game(true)==OK,"pre-failure actual combined state saves")
	var before: PackedByteArray=FileAccess.get_file_as_bytes(path)
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
	tap(world.hud.v20_quickslot_buttons[0]);await frames()
	check(world.player.global_position==other and int(world.inventory.get(DEDICATED,0))==2,"real writer failure rolls regional movement and exact supplied key back")
	check(FileAccess.get_file_as_bytes(path)==before and world.source_shop.orders().is_empty(),"failed consumer save preserves durable shop receipts and bytes")
	world.equipment_collections.test_save_writer=Callable()
	world.player.apply_stun(1.0)
	tap(world.hud.v20_quickslot_buttons[0]);await frames()
	check(world.player.global_position==other and int(world.inventory.get(DEDICATED,0))==2,"stun consumes no purchased scroll and moves nowhere")
	world.player.clear_status_effects()
	var record: Dictionary=world._find_catalog_item_record(DEDICATED)
	record.source_bless_raw=2
	tap(world.hud.v20_quickslot_buttons[0]);await frames()
	check(world.player.global_position==other and int(world.inventory.get(DEDICATED,0))==2 and int(world.inventory.get(RETURN,0))==1,"invalid blessing never consumes, coalesces or falls back to the ordinary purchased key")
	record.source_bless_raw=1
	check(world._save_game(true)==OK,"valid combined original slots and purchased source quantities saved for fresh process")
	check(world.quickslots==slots and not world.source_shop.claim("2").ok,"final save retains authored slots and duplicate-receipt protection")
	await capture("combined-return-protected")
	world.queue_free();await frames()
	print("SOURCE523_REGIONAL_PURCHASE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_host_maps":1,"M_laboratory_maps_executed":0,"target_supply":"actual paid NPC purchase, not fixture"}))
	quit(1 if failures else 0)
