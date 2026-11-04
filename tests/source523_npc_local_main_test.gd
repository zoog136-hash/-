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
	await exercise_general_npc(world,panel)
	world.queue_free();await frames()
	print("SOURCE523_NPC_LOCAL_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)

func exercise_general_npc(world: Node, panel: Node) -> void:
	var runtime=world.source_shop
	check(not runtime.quote_merchant(16964).ok,"80-level access remains closed below the configured gate")
	world.level=80
	var quote: Dictionary=runtime.quote_merchant(16964,2)
	check(quote.ok and str(quote.npc_label).contains("아이즈") and str(quote.rule_origin).contains("지역 입장/이동 미제공"),"general island vendor has exact source identity and explicit remote-access provenance")
	if not quote.ok:return
	var stock: Dictionary={}
	var coverage: Array=[]
	for row: Dictionary in runtime.catalog.rows("MerchantGoods"):
		var status: Dictionary=runtime.quote_merchant(int(row.ID))
		var key: String=str(int(row.MerchantsID))
		if not stock.has(key):stock[key]={"ready":0,"blocked":0}
		stock[key]["ready" if status.ok else "blocked"]+=1
		coverage.append({"merchant_id":int(row.MerchantsID),"goods_id":int(row.ID),"ready":status.ok,"reason":str(status.get("reason",""))})
	check(coverage.size()==4328 and stock.size()==192,"actual runtime classifies every original NPC sale row and all groups")
	check(int(stock["13"].ready)==16 and int(stock["40"].ready)==34 and int(stock["514"].ready)==17,"all executable normal stocks are checked through the existing quote engine")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-coverage-output="):
			var file:=FileAccess.open(arg.trim_prefix("--source523-coverage-output="),FileAccess.WRITE)
			file.store_string(JSON.stringify({"scope":"actual Main, level80, isolated QA wallet; no grant by audit","groups":stock,"rows":coverage},"  "));file.close()
	var material_names: Array=[]
	for key: String in runtime._bindings:
		if runtime._bindings[key].get("record",{}).has("source523_shop_item_id") and not runtime._bindings[key].record.get("source523_shop_supply_only",false):material_names.append(str(runtime._bindings[key].name))
	check(material_names.size()==6 and not material_names.has("드래곤의 용옥"),"only six exact engraved existing-use items are registered; orb and skill books excluded")
	var record: Dictionary=world._find_catalog_item_record("마나 회복 물약 (각인)")
	check(int(record.get("source523_shop_item_id",0))==385 and str(record.desc).contains("TWILIGHT"),"source ID and existing host effect are labelled in inventory data")
	var before_rows: int=world.catalog_db["아이템"].size()
	preload("res://scripts/shop/source523_npc_consumables.gd").install(world,runtime.catalog)
	check(world.catalog_db["아이템"].size()==before_rows,"reloading the adapter never duplicates item definitions")
	var mana_before: int=int(world.inventory.get("마나 회복 물약 (각인)",0))
	var base_mana: int=int(world.inventory.get("마나 회복 물약",0))
	var gold_before: int=int(world.gold)
	panel.mode.select(1);panel.mode.item_selected.emit(1)
	panel.search.text="16964";panel._filter()
	for index: int in range(panel.listing.item_count):
		if int(panel.listing.get_item_metadata(index))==16964:panel._select(index)
	panel.quantity.value=2;await frames()
	check(not panel.purchase.disabled and panel.detail.text.contains("아이즈") and panel.detail.text.contains("기존 소모품 효과 재사용"),"real shop detail exposes new NPC and configured host-use provenance")
	await capture("island-mana-available")
	tap(panel.purchase);await frames()
	var confirmation: Control=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"island purchase confirmation");return
	tap(confirmation.confirm_button);await frames()
	check(int(world.gold)==gold_before-int(quote.payment.amount) and int(world.inventory.get("마나 회복 물약 (각인)",0))==mana_before,"island purchase atomically debits the source price before receipt")
	var order: String=str(runtime.orders()[0].id)
	check(world._save_game(true)==OK,"new merchant pending order saves")
	world._load_game(true);freeze(world)
	check(runtime.orders().size()==1 and int(world.gold)==gold_before-int(quote.payment.amount),"new merchant pending payment reloads")
	panel._build_entries();await frames()
	tap(panel.purchase);await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	if confirmation==null:check(false,"island receipt confirmation");return
	tap(confirmation.confirm_button);await frames()
	check(int(world.inventory.get("마나 회복 물약 (각인)",0))==mana_before+2 and int(world.inventory.get("마나 회복 물약",0))==base_mana,"receipt preserves separate engraved and existing unengraved stacks")
	check(not runtime.claim(order).ok,"new NPC receipt cannot be replayed")
	world.hud.show_companion_bag();await frames()
	var bag=world.hud.lineage_inventory_ui
	bag._select_item("마나 회복 물약 (각인)");bag.open_detail();await frames()
	check(bag.is_visible_in_tree() and bag.detail_action.is_visible_in_tree() and not bag.detail_action.disabled,"new source consumable opens a usable real inventory detail")
	await capture("island-mana-inventory")
	tap(bag.detail_action);await frames()
	check(int(world.inventory.get("마나 회복 물약 (각인)",0))==mana_before+1 and world.active_item_buffs.has("마나 회복 물약 (각인)"),"actual inventory action consumes one purchased item and starts existing mana regeneration")
	check(int(world.inventory.get("마나 회복 물약",0))==base_mana,"source item use leaves old stacks unchanged")
	check(world._save_game(true)==OK,"consumed source stack and buff persist through real save writer")
	world._load_game(true);freeze(world)
	check(int(world.inventory.get("마나 회복 물약 (각인)",0))==mana_before+1 and world.active_item_buffs.has("마나 회복 물약 (각인)") and not runtime.claim(order).ok,"restart preserves use/buff and never restores paid receipt")
	await capture("island-mana-used")
	await exercise_all_executable_stock(world,coverage)


func exercise_all_executable_stock(world: Node, coverage: Array) -> void:
	var runtime=world.source_shop
	# Isolated QA stats fund/carry the complete batch; production balance is untouched.
	world.gold=100000000
	world.con_stat=1000
	var completed: int=0
	for row: Dictionary in coverage:
		if not row.ready:continue
		var quote: Dictionary=runtime.quote_merchant(int(row.goods_id))
		var name: String=str(quote.get("name",""))
		var before: int=int(world.inventory.get(name,0))
		var payment: int=int(quote.get("payment",{}).get("amount",0))
		var gold: int=int(world.gold)
		var purchase: Dictionary=runtime.buy_merchant(int(row.goods_id))
		check(purchase.ok and int(world.gold)==gold-payment,"all executable stock debits source-priced payment: "+str(row.goods_id))
		if not purchase.ok:continue
		var order: String=str(purchase.order_id)
		check(int(world.inventory.get(name,0))==before,"all stock waits for receipt: "+str(row.goods_id))
		var receipt: Dictionary=runtime.claim(order)
		check(receipt.ok and int(world.inventory.get(name,0))==before+int(runtime.catalog.merchant_offer(int(row.goods_id)).goods.Amount),"all executable stock grants exact real items: "+str(row.goods_id)+" "+str(receipt.get("reason","")))
		check(not runtime.claim(order).ok,"all executable stock rejects replay: "+str(row.goods_id))
		if receipt.ok:completed+=1
	check(completed==67,"every executable stock item has completed a real durable payment and receipt")
	world.hud.show_companion_bag();await frames()
	var bag=world.hud.lineage_inventory_ui
	var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/source523_npc_consumables.json"))
	for id: String in settings.items:
		if id in settings.get("supply_only_ids",[]):continue
		var name: String=str(settings.items[id])
		var spec: Dictionary=preload("res://scripts/consumable_rules.gd").definition(name)
		if not spec.get("classes",[]).is_empty():world.job_class=str(spec.classes[0])
		world._update_hud();await frames()
		var before: int=int(world.inventory.get(name,0))
		check(before>0,"purchased usable stack exists: "+id)
		bag._select_item(name);bag.open_detail();await frames()
		check(not bag.detail_action.disabled,"existing-use item exposes the inventory action: "+id)
		tap(bag.detail_action);await frames()
		check(int(world.inventory.get(name,0))==before-1,"real inventory action consumes exact source stack once: "+id)
	check(world._save_game(true)==OK,"complete stock and all six source uses save")
	var expected: Dictionary=JSON.parse_string(JSON.stringify(world.inventory))
	world._load_game(true);freeze(world)
	check(JSON.parse_string(JSON.stringify(world.inventory))==expected and runtime.orders().is_empty(),"all executable stock and uses survive restart with no pending/replayed orders")
