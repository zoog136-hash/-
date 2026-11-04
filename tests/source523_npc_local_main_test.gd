extends SceneTree
const Catalog=preload("res://scripts/shop/source523_shop_catalog.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: int=0
var capture_directory: String=""
func _init() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func frames() -> void:
	for unused: int in range(6):await process_frame
func freeze(world: Node) -> void:
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
func tap(control: Control) -> void:
	var position: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=97;event.position=position;event.pressed=pressed
		root.push_input(event,true)
func capture(label: String) -> void:
	if capture_directory.is_empty():return
	check(DisplayServer.get_name()!="headless","actual renderer required")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(label+".png"))==OK,"captured "+label)
func run() -> void:
	root.size=Vector2i(960,540)
	DisplayServer.window_set_size(root.size)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="):capture_directory=arg.trim_prefix("--source523-capture-dir=")
	var source=Catalog.session()
	check(source.available(),"actual original shop pack selected")
	if not source.available():quit(1);return
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(QA.enter_game(world),"actual Main class selection")
	freeze(world)
	var runtime=world.source_shop
	runtime.bind_source(source)
	check(runtime.merchant_prices.is_empty(),"no QA-only NPC availability override")
	check(not runtime.npc_definitions.loaded_sha256.is_empty(),"actual separate NPC definitions loaded")
	var quote: Dictionary=runtime.quote_merchant(1952,2)
	var market_gate: Dictionary=runtime.quote(1381)
	check(quote.ok,"default Serin rules enable real source goods: "+str(quote.get("reason","")))
	if not quote.ok:world.queue_free();quit(1);return
	check(int(quote.payment.unit_id)==201 and int(quote.payment.class_id)==1 and int(quote.payment.amount)==600,"currency comes from original NPC units; local final price uses original 300 base")
	check(str(quote.rule_origin).contains("TWILIGHT") and str(quote.npc_label).contains("세린"),"estimated availability is labelled separately from source currency")
	check(not runtime.quote_merchant(37728).ok and not runtime.quote_merchant(37738).ok,"inner-castle and event groups remain outside configured local NPC scope")
	check(world._save_game(true)==OK,"actual baseline save")
	var path: String=world.save_path()
	var original_sha: String=FileAccess.get_sha256(path)
	var gold: int=int(world.gold)
	var stones: int=int(world.inventory.get("마력의 돌 (각인)",0))
	var physical: Variant=JSON.parse_string(JSON.stringify(world.item_instances))
	world.hud.open_shop();await frames()
	tap(world.hud.shop_view.find_child("Source523Shop",true,false));await frames()
	var panel: Node=world.hud.shop_view.find_child("Source523ShopPanel",true,false)
	check(panel!=null,"NPC commerce opens from ordinary shop UI")
	if panel==null:world.queue_free();quit(1);return
	panel.mode.select(1);panel.mode.item_selected.emit(1)
	panel.search.text="1952";panel._filter()
	for index: int in range(panel.listing.item_count):
		if int(panel.listing.get_item_metadata(index))==1952:panel._select(index)
	panel.quantity.value=2
	await frames()
	check(not panel.purchase.disabled and panel.detail.text.contains("TWILIGHT 오프라인 가정") and panel.detail.text.contains("세린"),"UI exposes default NPC availability and explicit local assumptions")
	check(panel.availability_label.text.contains("600 아데나") and panel.availability_label.text.contains("TWILIGHT"),"small-screen action area shows total price and local provenance")
	await capture("serin-available")
	tap(panel.purchase);await frames()
	var confirmation: Control=world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(confirmation!=null,"actual NPC purchase confirmation")
	if confirmation==null:world.queue_free();quit(1);return
	tap(confirmation.cancel_button);await frames()
	check(world.gold==gold and runtime.orders().is_empty() and FileAccess.get_sha256(path)==original_sha,"cancel preserves wallet and exact saved bytes")
	tap(panel.purchase);await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(confirmation!=null,"second NPC confirmation")
	if confirmation==null:world.queue_free();quit(1);return
	await capture("serin-confirmation")
	tap(confirmation.confirm_button);await frames()
	check(world.gold==gold-600 and int(world.inventory.get("마력의 돌 (각인)",0))==stones,"default NPC payment debits real Adena and keeps goods in inbox")
	check(panel.mode.selected==4 and runtime.orders().size()==1,"actual pending inbox after purchase")
	if runtime.orders().size()!=1:world.queue_free();quit(1);return
	var order_id: String=str(runtime.orders()[0].id)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(str(saved.source_shop.orders[order_id].pack_sha256)==source.loaded_sha256,"existing shop pack identity is preserved for paid orders")
	check(saved.source_shop.get("npc_rule_hashes",{}).has("13") and saved.source_shop.orders[order_id].has("npc_pack_sha256"),"local rule and NPC source identities persist with debit")
	check(panel.detail.text.contains("TWILIGHT 오프라인 가정"),"inbox retains estimated rule provenance")
	await capture("serin-paid-inbox")
	world._load_game(true);freeze(world)
	check(world.gold==gold-600 and runtime.orders().size()==1,"restart restores payment and pending NPC order")
	var old_rules: Dictionary=runtime.npc_definitions.rules.duplicate(true)
	runtime.npc_definitions.rules.zero_hours_are_open=false
	check(not runtime.quote_merchant(1952).ok,"zero-hour local assumption can be disabled")
	runtime.npc_definitions.rules=old_rules.duplicate(true)
	runtime.npc_definitions.rules.merchants[0].label="changed local rule"
	check(not runtime.quote_merchant(1952).ok,"changed availability policy cannot silently replace saved purchase policy")
	runtime.npc_definitions.rules.enabled=false
	panel._build_entries();await frames()
	tap(panel.purchase);await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(confirmation!=null,"paid order remains receivable after new NPC trading is disabled")
	if confirmation==null:world.queue_free();quit(1);return
	tap(confirmation.confirm_button);await frames()
	check(world.gold==gold-600 and int(world.inventory.get("마력의 돌 (각인)",0))==stones+2,"NPC receipt grants actual materials without new debit despite later policy disable")
	check(panel.listing.item_count==0 and panel.result_label.text.contains("수령 완료"),"actual receipt result clears inbox")
	check(JSON.parse_string(JSON.stringify(world.item_instances))==physical,"existing physical equipment and enhancements preserved")
	check(not runtime.claim(order_id).ok,"duplicate NPC receipt rejected")
	await capture("serin-receipt")
	world._load_game(true);freeze(world)
	check(not runtime.claim(order_id).ok and world.gold==gold-600,"restart does not repeat NPC receipt")
	runtime.npc_definitions.rules=old_rules
	var market_after: Dictionary=runtime.quote(1381)
	check(market_after.ok==market_gate.ok and market_after.get("reason","")==market_gate.get("reason",""),"NPC-specific policy leaves ordinary market eligibility unchanged")
	# The new normal-equipment path uses source semantics, never a blessed grant.
	var helmet: String="기사의 면갑 (각인)"
	var old_instances: Dictionary=world.item_instances.duplicate(true)
	var helmet_before: int=int(world.inventory.get(helmet,0))
	var gold_before_gear: int=int(world.gold)
	quote=runtime.quote_merchant(2171,2)
	check(quote.ok and quote.npc_label.contains("글렌") and int(quote.payment.amount)==10000,"ordinary equipment uses source Cost 1000 and Percentage 500 for two units")
	if not quote.ok:world.queue_free();quit(1);return
	panel.mode.select(1);panel.mode.item_selected.emit(1)
	panel.search.text="2171";panel._filter()
	for index: int in range(panel.listing.item_count):
		if int(panel.listing.get_item_metadata(index))==2171:panel._select(index)
	panel.quantity.value=2;await frames()
	check(not panel.purchase.disabled and panel.detail.text.contains("글렌"),"Glenn's equipment stock is exposed through the real shop UI")
	await capture("glenn-available")
	tap(panel.purchase);await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"Glenn purchase confirmation");world.queue_free();quit(1);return
	tap(confirmation.confirm_button);await frames()
	check(world.gold==gold_before_gear-10000 and int(world.inventory.get(helmet,0))==helmet_before,"equipment payment remains separate from inventory receipt")
	var gear_order: String=str(runtime.orders()[0].id)
	tap(panel.purchase);await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"equipment receipt confirmation");world.queue_free();quit(1);return
	tap(confirmation.confirm_button);await frames()
	var new_ids: Array=[]
	for id: String in world.item_instances:
		if not old_instances.has(id):new_ids.append(id)
	check(new_ids.size()==2 and int(world.inventory.get(helmet,0))==helmet_before+2,"equipment receipt creates two independent physical instances")
	check(new_ids.all(func(id: String)->bool:return world.item_instances[id].name==helmet and int(world.item_instances[id].level)==0 and not world.item_instances[id].get("blessed",false)),"source Normal/+0 does not grant blessings or enhancements")
	check(old_instances.keys().all(func(id: String)->bool:return JSON.parse_string(JSON.stringify(world.item_instances[id]))==JSON.parse_string(JSON.stringify(old_instances[id]))),"existing physical gear records are unchanged")
	world._equip_reference_in_slot(helmet+"@@@"+str(new_ids[0]),"helmet")
	check(str(world.equipped_items.get("helmet",{}).get("instance_id",""))==str(new_ids[0]),"new NPC equipment can be worn using the existing equipment system")
	check(world._save_game(true)==OK,"new NPC equipment can be saved after wear")
	await capture("glenn-equipped")
	world._load_game(true);freeze(world)
	check(not runtime.claim(gear_order).ok and world.item_instances.has(str(new_ids[0])) and world.item_instances.has(str(new_ids[1])) and str(world.equipped_items.get("helmet",{}).get("instance_id",""))==str(new_ids[0]),"worn equipment identities and non-repeatable receipt survive reload")
	world.queue_free();await frames()
	print("SOURCE523_NPC_LOCAL_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
