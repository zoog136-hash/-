extends SceneTree
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const Runtime = preload("res://scripts/shop/source523_shop_runtime.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: int = 0
var capture_directory: String = ""

func _init() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames() -> void:
	for unused: int in range(6): await process_frame

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * .5)
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 96
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)

func freeze(world: Node) -> void:
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)

func capture(label: String) -> void:
	if capture_directory.is_empty(): return
	check(DisplayServer.get_name() != "headless", "capture requires actual renderer")
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(label+".png")) == OK,"captured " + label)

func _run() -> void:
	root.size = Vector2i(960,540) if "--source523-small-ui" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="): capture_directory = arg.trim_prefix("--source523-capture-dir=")
	var source = Catalog.session()
	check(source.available(), "actual 523 pack selected and byte verified")
	if not source.available(): quit(1);return
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	freeze(world)
	check(QA.enter_game(world), "actual Main class selection")
	freeze(world)
	# Isolated QA funding uses the real bag; no production grant or debug UI added.
	world.inventory["다이아"] = 1000
	world.source_shop.bind_source(source)
	world._update_hud()
	check(world._save_game(true) == OK, "actual baseline save")
	var path: String = world.save_path()
	var baseline_hash: String = FileAccess.get_sha256(path)
	var before_gold: int = int(world.gold)
	var before_dragon: int = int(world.inventory.get("드래곤의 다이아몬드",0))
	var before_mileage: int = int(world.inventory.get("마일리지",0))
	var physical: Dictionary = world.item_instances.duplicate(true)
	var source_quote: Dictionary = world.source_shop.quote(1381,1)
	check(source_quote.ok, "actual original product binds to functional existing inventory: " + str(source_quote.get("reason","")))
	if not source_quote.ok: world.queue_free();quit(1);return
	check(int(source_quote.payment.amount)==120 and source_quote.goods.size()==2,"original 120-diamond price and separate mileage bonus")
	world.hud.open_shop()
	await frames()
	var shop: Node = world.hud.shop_view
	tap(shop.find_child("Source523Shop",true,false))
	await frames()
	var panel: Node = shop.find_child("Source523ShopPanel",true,false)
	check(panel != null, "source commerce opens from existing shop by touch")
	if panel == null: world.queue_free();quit(1);return
	panel.all_definitions.button_pressed=true
	panel.search.text="1381"
	panel._filter()
	for index: int in range(panel.listing.item_count):
		if int(panel.listing.get_item_metadata(index))==1381: panel._select(index)
	await frames()
	check(not panel.purchase.disabled, "real funded purchase button enabled")
	tap(panel.purchase)
	await frames()
	var confirmation: Control = world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(confirmation != null,"purchase uses actual confirmation")
	if confirmation == null: world.queue_free();quit(1);return
	tap(confirmation.cancel_button)
	await frames()
	check(world.inventory["다이아"]==1000 and world.source_shop.orders().is_empty() and FileAccess.get_sha256(path)==baseline_hash,"cancel consumes nothing and writes nothing")
	tap(panel.purchase)
	await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(confirmation != null,"second confirmation is a fresh transaction")
	if confirmation == null: world.queue_free();quit(1);return
	await capture("purchase-confirmation")
	tap(confirmation.confirm_button)
	await frames()
	check(world.inventory["다이아"]==880 and world.gold==before_gold,"actual UI deducts exactly original currency and retains adena")
	check(int(world.inventory.get("드래곤의 다이아몬드",0))==before_dragon,"payment does not grant inventory goods")
	check(panel.mode.selected==4 and panel.listing.item_count==1,"UI moves to actual pending inbox")
	check(panel.detail.text.contains("마일리지 ×240") and not panel.detail.text.contains("VIPBonusPoint"),"inbox displays usable currency names")
	var orders: Array = world.source_shop.orders()
	check(orders.size()==1,"one persisted order")
	if orders.size()!=1: world.queue_free();quit(1);return
	var order_id: String = str(orders[0].id)
	var paid_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var paid: Dictionary = JSON.parse_string(paid_bytes.get_string_from_utf8())
	check(paid.source_shop.orders[order_id].status=="pending" and paid.inventory["다이아"]==880,"one save holds debit and pending order")
	await capture("paid-inbox")
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
	check(not world.source_shop.buy(1381).ok and world.inventory["다이아"]==880 and world.source_shop.orders().size()==1,"actual failed save cannot charge another purchase")
	check(not world.source_shop.claim(order_id).ok and int(world.inventory.get("드래곤의 다이아몬드",0))==before_dragon,"actual failed receipt save grants no goods")
	check(FileAccess.get_file_as_bytes(path)==paid_bytes,"failed purchase/receipt preserve exact durable bytes")
	world.equipment_collections.test_save_writer=Callable()
	var old_weight: int = int(world.item_weight_index.get("드래곤의 다이아몬드",3))
	world.item_weight_index["드래곤의 다이아몬드"]=1000000
	check(not world.source_shop.claim(order_id).ok and world.source_shop.orders().size()==1,"actual overweight receipt keeps paid order")
	world.item_weight_index["드래곤의 다이아몬드"]=old_weight
	world._load_game(true)
	freeze(world)
	check(world.source_shop.orders().size()==1 and world.inventory["다이아"]==880,"restart restores pending order and paid currency")
	panel._build_entries()
	await frames()
	tap(panel.purchase)
	await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(confirmation != null,"inbox receipt uses actual confirmation")
	if confirmation == null: world.queue_free();quit(1);return
	tap(confirmation.confirm_button)
	await frames()
	check(int(world.inventory.get("드래곤의 다이아몬드",0))==before_dragon+10 and int(world.inventory.get("마일리지",0))==before_mileage+240,"actual receipt grants original product and bonus")
	check(world.inventory["다이아"]==880 and world.gold==before_gold,"receipt never charges again")
	check(JSON.parse_string(JSON.stringify(world.item_instances))==JSON.parse_string(JSON.stringify(physical)),"existing physical gear and enhancements preserved")
	check(panel.listing.item_count==0 and panel.purchase.disabled and panel.result_label.text.contains("수령 완료"),"actual result clears inbox and shows receipt success")
	await capture("receipt-result")
	check(not world.source_shop.claim(order_id).ok,"repeated receipt rejected")
	world._load_game(true)
	freeze(world)
	check(not world.source_shop.claim(order_id).ok and world.inventory["다이아"]==880,"restart preserves non-repeatable receipt")
	panel.mode.select(1)
	panel.mode.item_selected.emit(1)
	panel.search.text="1952"
	panel._build_entries()
	for index: int in range(panel.listing.item_count):
		if int(panel.listing.get_item_metadata(index))==1952:panel._select(index)
	check(panel.purchase.disabled and panel.detail.text.contains("TWILIGHT 자체 최종가") and panel.detail.text.find("1회 가격: 300")<panel.detail.text.find("구매 횟수"),"actual NPC screen prioritizes local price provenance while technical activation remains independent")
	await capture("npc-price-and-condition")
	# Explicit QA availability for this one original row, not a production default.
	world.source_shop.merchant_prices={"1952":{"goods_sha256":world.source_shop.merchant_signature(1952),"time_unrestricted":true}}
	var merchant_gold: int=int(world.gold)
	var stones: int=int(world.inventory.get("마력의 돌 (각인)",0))
	panel.quantity.value=2
	panel._refresh_action()
	check(not panel.purchase.disabled,"verified NPC availability uses actual transaction UI")
	tap(panel.purchase)
	await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(confirmation!=null,"NPC purchase uses real confirmation")
	if confirmation==null:world.queue_free();quit(1);return
	await capture("npc-purchase-confirmation")
	tap(confirmation.confirm_button)
	await frames()
	check(world.gold==merchant_gold-600 and panel.mode.selected==4 and panel.listing.item_count==1,"NPC quantity purchase atomically debits and opens inbox")
	var merchant_orders: Array=world.source_shop.orders()
	check(merchant_orders.size()==1 and merchant_orders[0].kind=="merchant" and str(panel.listing.get_item_text(0)).contains("마력의 돌"),"NPC inbox names are resolved independently of market purchase IDs")
	if merchant_orders.size()!=1:world.queue_free();quit(1);return
	var merchant_order_id: String=str(merchant_orders[0].id)
	tap(panel.purchase)
	await frames()
	confirmation=world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(confirmation!=null,"NPC inbox receipt uses actual confirmation")
	if confirmation==null:world.queue_free();quit(1);return
	tap(confirmation.confirm_button)
	await frames()
	check(world.gold==merchant_gold-600 and int(world.inventory.get("마력의 돌 (각인)",0))==stones+2 and panel.listing.item_count==0,"actual NPC receipt grants bundle with no duplicate debit")
	check(not world.source_shop.claim(merchant_order_id).ok,"NPC duplicate receipt rejected")
	await capture("npc-receipt-result")
	world.source_shop.merchant_prices.clear()
	panel.mode.select(3)
	panel.mode.item_selected.emit(3)
	panel.search.text=""
	panel._build_entries()
	check(panel.listing.item_count==3 and panel.purchase.disabled and panel.availability_label.text.contains("기간"),"actual expired cumulative events remain inactive in connected reward UI")
	await capture("cumulative-inactive")
	var valid_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var malformed: Dictionary = JSON.parse_string(valid_bytes.get_string_from_utf8())
	malformed.source_shop.orders[order_id].goods[0].amount=-1
	check(Writer.write(path,malformed)==OK,"malformed-load fixture written only to isolated profile")
	var malformed_sha: String = FileAccess.get_sha256(path)
	world.gold=123
	world._load_game(true)
	check(world.source_shop.save_blocked and world.gold==123,"bad commerce state rejected before progression mutation")
	check(world._save_game(true)!=OK and FileAccess.get_sha256(path)==malformed_sha,"bad state cannot overwrite original bytes")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(valid_bytes);file.close()
	world._load_game(true)
	freeze(world)
	check(not world.source_shop.save_blocked,"valid original save clears commerce guard")
	var historical: Dictionary = JSON.parse_string(valid_bytes.get_string_from_utf8())
	historical.erase(Runtime.SAVE_KEY)
	check(Writer.write(path,historical)==OK,"historical save without commerce field")
	var historical_sha: String = FileAccess.get_sha256(path)
	world._load_game(true)
	freeze(world)
	check(FileAccess.get_sha256(path)==historical_sha and FileAccess.get_sha256(path+".pre-source-shop-"+historical_sha)==historical_sha,"commerce migration preserves exact original and hash-named backup")
	check(world.source_shop.orders().is_empty() and world.inventory["다이아"]==880,"old saves keep inventory without fabricated orders")
	world.queue_free()
	await frames()
	print("SOURCE_SHOP_COMMERCE_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
