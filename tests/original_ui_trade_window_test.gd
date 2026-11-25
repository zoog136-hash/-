extends SceneTree
## The original 523 거래소 window (source_main_trade_window) over the offline
## trade runtime (scripts/exchange/trade523_market.gd). Without arguments (no
## original files): local offer limits, legacy settlement, save validation,
## money format, HUD wiring, and fail-closed registration. Real input:
## -- --pack=<private original main UI pack directory>: Trade_All mounts each
##    tab (검색 분류 / 목록 / 매물, 기존 매물 회수, 정산, 정산 내역) and
##    search / purchase popups over a fake market, without sale controls.
## -- --main or --targeted (with private original definitions and UI):
##    real Main buys exact local items and settles existing escrow, without
##    exposing any new sale registration. Targeted also exercises real CSBs,
##    a legacy physical stack, failed write, touch cancellation and reload.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_trade_window.gd")
const MARKET=preload("res://scripts/exchange/trade523_market.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const FROZEN=preload("res://scripts/exchange/frozen_exchange.gd")
const ICON_REGISTRY=preload("res://scripts/ui/source523_original_ui_icons.gd")
const SHOP_CATALOG=preload("res://scripts/shop/source523_shop_catalog.gd")
const ALICE: Dictionary={179094:"LargeSword",179134:"Rifle",185984:"Scythe",291612:"RunSword"}
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const HUD_CONTROLLER=preload("res://scripts/ui/original_ui/source_main_hud.gd")
var checks: int=0
var failures: Array[String]=[]
var messages: Array[String]=[]

class FakeShop extends RefCounted:
	var state: Dictionary={}
	func _now() -> int:
		return 1763300000

class FakeWorld extends Node:
	var source_shop:=FakeShop.new()
	var gold: int=5000
	var inventory: Dictionary={"다이아":100}

class FakeHud extends Node:
	var shown: Array[String]=[]
	func show_message(text: String) -> void:
		shown.append(text)

class FakeMarket extends RefCounted:
	var bought: Array=[]
	var reclaimable: bool=true
	var settled: int=0
	var sold: bool=false
	var large_count: int=0
	func categories() -> Array:
		return [{"id":1,"name":"무 기","children":[{"id":61,"name":"한손검"},{"id":71,"name":"도 끼"}]},{"id":41,"name":"소모품","children":[{"id":331,"name":"물 약"}]}]
	func category_name(id: int) -> String:
		return {1:"무 기",61:"한손검",41:"소모품"}.get(id,"")
	func search(_category: int, _query: String="") -> Array:
		if large_count>0:
			var rows: Array=[]
			for index: int in large_count:
				rows.append({"item_class_id":40001+index,"name":"근사 검 %d"%index,"min_price":120+index,"count":3,"approx":true,"grade":3})
			return rows
		return [{"item_class_id":366,"name":"가죽","min_price":1,"count":3,"approx":false,"grade":1},{"item_class_id":40001,"name":"근사 검","min_price":120,"count":3,"approx":true,"grade":3}]
	func listings(_id: int) -> Array:
		if large_count>0:
			var rows: Array=[]
			for index: int in large_count:rows.append(_row("approx:40001:%d"%index,true))
			return rows
		return [_row("snapshot:a",false),_row("approx:40001:0",true)]
	func _row(key: String, approx: bool) -> Dictionary:
		return {"key":key,"name":"근사 검","item_class_id":40001,"bundle_size":1,"bundle_price":120,"unit_price":120.0,"unit_price_display":120,"available":1,"enchant":0,"approx":approx,"grade":3}
	func listing(key: String) -> Dictionary:
		return _row(key,key.begins_with("approx"))
	func quote_buy(key: String) -> Dictionary:
		return {"ok":true,"row":listing(key),"total":120,"balance":500}
	func buy(key: String) -> Dictionary:
		bought.append(key)
		return {"ok":true,"message":"구매 완료"}
	func diamonds() -> int:
		return 500
	func reference_unit_price(_id: int) -> float:
		return 50.0
	func has_reclaimable() -> bool:
		return reclaimable
	func my_listings() -> Array:
		if not reclaimable:return []
		return [{"id":"1","name":"물약0","item_class_id":40002,"quantity":2,"price":100,"status":"sold" if sold else "selling","remaining_seconds":3600,"gross":100,"tax":7,"net":93,"sell_at":1763300300},{"id":"2","name":"물약1","item_class_id":40002,"quantity":1,"price":50,"status":"expired","remaining_seconds":0,"gross":50,"tax":3,"net":47,"sell_at":-1}]
	func take_back(_id: String) -> Dictionary:
		return {"ok":true,"message":"회수"}
	func settle_all() -> Dictionary:
		settled+=1
		return {"ok":true,"message":"정산 완료"}
	func history() -> Array:
		return [{"name":"물약0","item_class_id":40002,"quantity":2,"price":100,"gross":100,"net":93,"sold_at":1763300300,"at":1763300400}]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_rules()
	var pack_dir: String=""
	var main: bool=false
	var targeted: bool=false
	var fallback: bool=false
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
		if value=="--main":main=true
		if value=="--targeted":targeted=true
		if value=="--fallback":fallback=true
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	if main:await _real_main()
	if targeted:await _targeted_main()
	if fallback:await _fallback_main()
	if main or targeted:
		for pack: RefCounted in ICON_REGISTRY.packs_by_manifest.values():pack.release_cache_leases()
	for failure: String in failures:printerr("ORIGINAL_UI_TRADE_WINDOW_FAIL ",failure)
	print("ORIGINAL_UI_TRADE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty(),"main_checked":main or targeted}))
	quit(0 if failures.is_empty() else 1)

func _rules() -> void:
	check(MARKET.MIN_SALE_AMOUNT==10 and MARKET.MAX_SALE_AMOUNT==9999999,"original KR price bounds for local offers")
	var money: Dictionary=MARKET.settlement(1000)
	check(money.gross==1000 and money.tax==70 and money.net==930,"existing escrow keeps its 7% settlement rule: "+str(money))
	var market=MARKET.new()
	check(market.quote_sell("item@@@receipt",1,100).get("code")=="trade_sale_registration_removed" and market.register("item@@@receipt",1,100).get("code")=="trade_sale_registration_removed","direct stale API calls fail closed even without a market host")
	check(not market.has_method("_stage_removal") and not WINDOW.new().has_method("_register_confirmed"),"new sale escrow writer and native confirmation handlers are absent")
	check(MARKET.validate_state(MARKET.fresh_state()).is_empty(),"a fresh trade save validates")
	var bad: Dictionary=MARKET.fresh_state()
	bad.listings["5"]={"name":"x","item_class_id":1,"quantity":1,"price":10,"registered_at":0,"expires_at":1,"sell_at":-1,"kind":"stack"}
	check(not MARKET.validate_state(bad).is_empty(),"a listing id at or above next_id is refused")
	bad.next_id=6
	check(MARKET.validate_state(bad).is_empty(),"a stack listing validates")
	bad.listings["5"].kind="instance"
	check(not MARKET.validate_state(bad).is_empty(),"an equipment listing needs its stored instance")
	check(WINDOW._market_span(240,0,400,80)==Vector2i(0,6) and WINDOW._market_span(240,-18800,400,80)==Vector2i(234,240),"market spans include the first and last visible rows with one buffer row")
	check(WINDOW._money(9999)=="9999" and WINDOW._money(99999)=="9만9999" and WINDOW._money(20000)=="2만","the original 9만9999 money format")
	check(WINDOW._unit(0.005)=="0.01" and WINDOW._unit(120.0)=="120","unit prices keep two decimals below 100")
	check(HUD_CONTROLLER.FEATURE_WINDOWS.get("trade")==WINDOW,"the trade window is a registered feature window")
	var captured: Dictionary={"currency_unit_id":34,"currency_class_id":2,"item_class_id":366,"bundle_price":50,"bundle_size":10000,"enchant":0,"element":"","element_level":0,"attributes":{"blessed_type":1},"initial_bundles":77,"server_id":"server:1","listing_id":"untrusted-reference"}
	var equivalent: Dictionary=captured.duplicate(true)
	equivalent.bundle_price=100;equivalent.bundle_size=20000;equivalent.initial_bundles=999;equivalent.server_id="server:9";equivalent.listing_id="other"
	check(MARKET.captured_unit(captured)==MARKET.captured_unit(equivalent),"normalization alone crosses capture boundary")
	var first: Dictionary=MARKET.local_lot(10000,"material",MARKET.captured_unit(captured))
	var equal: Dictionary=MARKET.local_lot(10000,"material",MARKET.captured_unit(equivalent))
	equivalent.bundle_price=400
	var different: Dictionary=MARKET.local_lot(10000,"material",MARKET.captured_unit(equivalent))
	check(first==equal and first.size==1000 and different.size==first.size and different.price>first.price,"capture cannot set local size; distinct normalized price changes only price")
	for variant: Dictionary in [{"enchant":5},{"element_level":1},{"attributes":{"blessed_type":3}},{"currency_class_id":3}]:
		var bad_sample: Dictionary=captured.duplicate(true);bad_sample.merge(variant,true)
		check(MARKET.captured_unit(bad_sample)<0.0,"non-comparable capture ignored: "+str(variant))
	check(MARKET.local_lot(10000,"material",0.0).is_empty(),"no invented fallback price")
	var window=WINDOW.new()
	var hud:=FakeHud.new()
	var world:=FakeWorld.new()
	world.add_child(hud)
	root.add_child(world)
	var parent:=Node2D.new()
	check(window.open(parent).get("code")!="","the window does not open before it is configured")
	parent.free()
	world.queue_free()

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures with the Trade members")
	var fake:=FakeMarket.new()
	window.market=fake
	var opened: Dictionary=window.open(parent)
	check(opened.get("handled",false) and int(opened.filled.get("category_rows",0))==2 and int(opened.filled.get("items",-1))==0,"검색 tab: the original top categories, no items before a choice: "+str(opened).left(400))
	var picked: Dictionary=window._top_pressed(1)
	check(picked.get("handled",false) and int(picked.filled.category_rows)==4 and int(picked.filled.items)==2,"a top category opens its sub categories and lists its items: "+str(picked).left(300))
	var result: Dictionary=window._item_pressed(40001)
	check(result.get("handled",false) and int(result.filled.listings)==2,"판매 목록 lists the item's listings: "+str(result).left(300))
	var popup: Dictionary=window._listing_pressed("approx:40001:0")
	check(popup.get("handled",false) and popup.filled.get("popup_member")==WINDOW.BUY_POPUP,"a listing opens Trade_Popup_Buy: "+str(popup).left(300))
	window._buy_confirmed()
	check(fake.bought==["approx:40001:0"] and window.popup=="","확 인 buys the listing and closes the popup")
	var keypad: Dictionary=window._open_keypad()
	check(keypad.get("handled",false) and window.popup=="keypad","Btn_Search opens Trade_Popup_Keypad with its TextField: "+str(keypad).left(300))
	await process_frame
	window._editor.text="검"
	var searched: Dictionary=window._apply_query()
	check(searched.get("handled",false) and window.query=="검" and window.popup=="" and int(searched.filled.items)==2,"검색 applies the name and lists the matches")
	var reclaim: Dictionary=window._set_tab("sell")
	check(reclaim.get("handled",false) and int(reclaim.filled.mine)==2 and not reclaim.filled.has("bag"),"existing escrow uses the authored list without the inventory grid")
	var label_node: Node=_source_node(window,"Nd_Server/Nd_TabMenu/Btn_Sell_On/Label")
	var reclaim_label: Node=label_node.get_meta("source_text",null) if is_instance_valid(label_node) else null
	check(is_instance_valid(reclaim_label) and reclaim_label.original_options.text=="기존 매물 회수","the original tab displays the reclaim-only label")
	if is_instance_valid(reclaim_label):
		var title_width: float=reclaim_label.original_font.get_string_size(str(reclaim_label.original_options.text),HORIZONTAL_ALIGNMENT_LEFT,-1,int(reclaim_label.original_options.fontSize)).x
		check(title_width*reclaim_label.scale.x<=94.01,"the actual original-font caption fits its authored tab without overlap")
	check(_no_sale_controls(window),"the original inventory, re-register, registration input and confirmation are absent")
	fake.sold=true
	var calc: Dictionary=window._set_tab("calculate")
	check(calc.get("handled",false) and int(calc.filled.rows)==1,"정산 tab lists the sold listing")
	window._settle()
	check(fake.settled==1,"정 산 settles")
	var history: Dictionary=window._set_tab("history")
	check(history.get("handled",false) and int(history.filled.rows)==1,"정산 내역 lists the history")
	window._world_pressed()
	check(hud.shown.has("월드 거래소는 온라인 전용입니다 · 로컬 거래소를 이용하세요"),"월드 거래소 explains it is online-only")
	await _large_lists(window,fake)
	window._close_requested()
	check(not window.is_open(),"Btn_Close closes the window")
	await process_frame
	parent.queue_free()
	world.queue_free()

func _large_lists(window: RefCounted, fake: FakeMarket) -> void:
	fake.large_count=240
	var opened: Dictionary=window._set_tab("search")
	check(opened.get("ok",false) and opened.filled.items==240,"large category retains all 240 item rows")
	if not opened.get("ok",false):return
	var key: String=_list_key(window,WINDOW.ITEM_ROW)
	check(not key.is_empty(),"item list has a virtual scroll state")
	if key.is_empty():return
	var state: Dictionary=window._scrolls[key]
	var first: Node2D=state.mounted[0]
	window._scroll_to(key,-1.0)
	check(state.mounted.get(0)==first and state.mounted.size()<12,"same visible range reuses original item rows")
	window._scroll_to(key,state.min)
	await process_frame
	await process_frame
	check(state.mounted.has(239) and state.content.get_child_count()==state.mounted.size() and state.mounted.size()<12,"item scrolling reaches the final row and frees old scenes")
	var button: Callable=_row_action(state.mounted.get(239),&"_item_pressed")
	check(button.is_valid(),"the last row binds its original sale list button")
	if not button.is_valid():return
	var listings: Dictionary=button.call()
	check(listings.get("ok",false) and window.result_item==40240 and listings.filled.listings==240,"last item opens its exact ID and all listings")
	if not listings.get("ok",false):return
	key=_list_key(window,WINDOW.RESULT_ROW)
	check(not key.is_empty(),"listing list has a virtual scroll state")
	if key.is_empty():return
	state=window._scrolls[key]
	window._scroll_to(key,state.min)
	check(state.mounted.has(239) and state.mounted.size()<12,"last listing stays reachable with bounded live rows")
	button=_row_action(state.mounted.get(239),&"_listing_pressed")
	check(button.is_valid() and button.call().get("ok",false) and window.popup_key=="approx:40001:239","last listing opens the exact purchase popup")

static func _row_action(scene: Node2D, method: StringName) -> Callable:
	if not is_instance_valid(scene):return Callable()
	for binding: Dictionary in scene._bindings.values():
		var action: Variant=binding.get("activate")
		if action is Callable and action.get_method()==method:return action
	return Callable()

static func _list_key(window: RefCounted, member: String) -> String:
	for key: String in window._scrolls:
		if window._scrolls[key].get("member")==member:return key
	return ""

## The real Main: the HUD menu opens the original window over the real
## definitions, local stock, captured price references and saves (test wallet only).
func _real_main() -> void:
	var QA=load("res://tests/qa_class_selection.gd")
	var world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	check(QA.enter_game(world),"Main class selection")
	world.player.set_physics_process(false)
	var hud: Node=world.hud
	for _i: int in range(5):await process_frame
	var controller: Object=hud.get("original_main_ui_controller")
	check(controller!=null,"the original HUD controller exists")
	if controller==null:return
	hud.call("open_frozen_exchange")
	var status: Dictionary=hud.original_main_ui_status.get("trade_window",{})
	check(status.get("handled",false),"the HUD 거래소 opens Trade_All: "+str(status).left(400))
	var window: Object=controller.feature_window("trade")
	if window==null or not status.get("handled",false):return
	var market: Object=window.market
	check(market.categories().size()==6,"the six original top categories: "+str(market.categories().map(func(c: Dictionary) -> String: return str(c.name))))
	var found: Array=market.search(41)
	check(not found.is_empty(),"소모품 lists items: "+str(found.size()))
	var approx_id: int=0
	for row: Dictionary in market.search(1):
		if int(row.count)>0 and bool(row.get("local",false)):
			approx_id=int(row.item_class_id)
			break
	check(approx_id>0,"a real TWILIGHT weapon is offered locally")
	world.inventory["다이아"]=int(world.inventory.get("다이아",0))+100000
	world.gold=int(world.gold)+100000
	var before: int=int(world.inventory["다이아"])
	var listed: Array=market.listings(approx_id)
	if world._save_game(true)!=OK:
		# A headless run without the full original item / map pack keeps the
		# existing save protected: a purchase must then change nothing.
		var refused: Dictionary=market.buy(str(listed[0].key)) if not listed.is_empty() else {}
		check(not refused.get("ok",true) and int(world.inventory["다이아"])==before and market.listings(approx_id).size()==listed.size(),"a protected save refuses the purchase and keeps the wallet and stock")
		print("TRADE_MAIN_SAVE_PROTECTED ",JSON.stringify({"source_item_save_blocked":world.get("source_item_save_blocked"),"source_save_blocked":world.get("source_save_blocked")}))
		# Test only: lift the pack protections to exercise the commit path.
		for flag: String in ["source_item_save_blocked","source_save_blocked"]:
			if world.get(flag)==true:world.set(flag,false)
		world.source_shop.save_blocked=false
		if world._save_game(true)!=OK:
			print("TRADE_MAIN_SAVE_UNAVAILABLE")
			window._close_requested()
			await process_frame
			world.queue_free()
			return
	var bought: Dictionary=market.buy(str(listed[0].key)) if not listed.is_empty() else {}
	check(bought.get("ok",false) and int(world.inventory["다이아"])==before-int(listed[0].bundle_price),"buying an exact local listing pays its diamonds and saves: "+str(bought))
	check(market.listings(approx_id).size()==listed.size()-1,"the bought listing is gone for the day")
	var opened: Dictionary=window._top_pressed(1)
	check(opened.get("handled",false),"the window lists 무 기 in the real pack")
	var shop: Object=world.source_shop
	var trade: Dictionary=market.state()
	var now: int=int(shop._now())
	trade.next_id=2
	trade.listings["1"]=_legacy_row(approx_id,"기존 보관 장비",1,100,now,"sold","stack")
	shop.state[MARKET.STATE_KEY]=trade
	check(world._save_game(true)==OK,"test-only fixture installs an already sold listing")
	world._load_game(true)
	var mine: Array=market.my_listings()
	check(mine.size()==1 and str(mine[0].status)=="sold","an already sold listing remains after reload")
	var hidden: Dictionary=window._set_tab("sell")
	check(hidden.get("handled",false) and window.tab=="search" and not _has_reclaim_tab(window),"sold-only profiles never expose the reclaim tab")
	var diamonds: int=int(world.inventory["다이아"])
	var settled: Dictionary=market.settle_all()
	check(settled.get("ok",false) and int(world.inventory["다이아"])==diamonds+93 and market.history().size()==1,"settlement pays the retained net diamonds: "+str(settled))
	var calc: Dictionary=window._set_tab("history")
	check(calc.get("handled",false) and int(calc.filled.rows)==1,"settlement history is still visible")
	window._close_requested()
	await process_frame
	world.queue_free()

func _fallback_main() -> void:
	root.size=Vector2i(2048,919)
	var QA=load("res://tests/qa_class_selection.gd")
	var world=load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"fallback actual Main enters")
	await process_frame
	var saved: Dictionary=world.source_shop.export_state()
	await _tap_menu_trade(world.hud)
	check(world.hud.active_section=="exchange" and world.hud.workspace.find_child("LocalTradeUnavailable",true,false)!=null,"ordinary no-pack menu says original trade unavailable")
	check(world.hud.workspace.find_child("FrozenExchangePanel",true,false)==null and world.source_shop.export_state()==saved,"ordinary fallback does not expose captured spending or mutate saved commerce")
	world.queue_free();await process_frame

func _touch(control: Control) -> void:
	await _touch_position(control.get_global_transform_with_canvas()*(control.size*.5))

func _touch_position(position: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=7;event.pressed=pressed;event.position=position
		root.push_input(event,true)
		await process_frame

func _source_node(window: RefCounted, path: String) -> Node:
	var found: Dictionary=window._locate(window._scene,window._out,path)
	return found.player.source_nodes.get(found.offset) if found.get("ok",false) else null

func _source_area(window: RefCounted, path: String) -> Control:
	var node: Node=_source_node(window,path)
	var button: Node=node.get_meta("source_button",null) if is_instance_valid(node) else null
	return button.get("_input_area") if is_instance_valid(button) else null

func _has_reclaim_tab(window: RefCounted) -> bool:
	return is_instance_valid(_source_node(window,"Nd_Server/Nd_TabMenu/Btn_Sell_Off"))

func _no_sale_controls(window: RefCounted) -> bool:
	for key: String in window._out:
		if key.contains("/Trade_Popup_Input") or key.contains("/Trade_Popup_Register") or key.contains("/Trade_Inventory") or key.contains("/Btn_Re_Registration"):return false
	return not window.has_method("_bag_pressed") and not window.has_method("_input_confirmed") and not window.has_method("_register_confirmed")

static func _legacy_row(item_id: int, item_name: String, amount: int, price: int, now: int, status: String, kind: String, native_uid: String="", instance: Dictionary={}) -> Dictionary:
	return {"item_class_id":item_id,"name":item_name,"quantity":amount,"price":price,"registered_at":now-600,"expires_at":now-1 if status=="expired" else now+3600,"sell_at":now-20 if status=="sold" else -1,"kind":kind,"instance_id":native_uid,"instance":instance,"commission":1000}

func _check_registration_removed(w: Node, market: RefCounted, reference: String, physical_id: String) -> void:
	var state: Dictionary=market.state()
	var wallet: Dictionary=w.inventory.duplicate(true)
	var gold: int=w.gold
	var disk: String=FileAccess.get_sha256(w.save_path())
	var held: Dictionary=STACK.proof(w,physical_id)
	var quote: Dictionary=market.quote_sell(reference,2,100)
	var denied: Dictionary=market.register(reference,2,100)
	check(quote.get("code")=="trade_sale_registration_removed" and denied==quote,"old direct registration route is explicitly refused even for a valid exact physical receipt")
	check(market.state()==state and w.inventory==wallet and w.gold==gold and STACK.proof(w,physical_id)==held and FileAccess.get_sha256(w.save_path())==disk,"refused registration never touches escrow, fee, inventory, proof or disk")

func _tap_menu_trade(hud: Node) -> void:
	hud.toggle_menu()
	for frame: int in range(3):await process_frame
	var tile: Control=hud.workspace.find_child("MenuTile_exchange",true,false)
	check(is_instance_valid(tile) and tile.is_visible_in_tree(),"actual Main menu has the exchange touch target")
	if is_instance_valid(tile):
		hud.menu_scroll_view.ensure_control_visible(tile)
		await process_frame
		await _touch(tile)

static func _image_scenes(node: Node, found: Dictionary) -> void:
	if node.has_meta("source_asset_scene_evidence"):
		var evidence: Dictionary=node.get_meta("source_asset_scene_evidence")
		if evidence.get("member","").contains("_Myth_Alice.csb"):
			found[evidence.member]={"target":evidence.target,"playback":evidence.playback,"node":node,"player":node.get_meta("source_asset_scene")}
	for child: Node in node.get_children():_image_scenes(child,found)

func _targeted_main() -> void:
	var archive: String=OS.get_environment("TWILIGHT_EXACT_TRADE_DEFINITIONS")
	check(not archive.is_empty() and not FileAccess.file_exists("user://twilight_v20_save.json"),"targeted local-market fixture uses an empty profile with the exact source ZIP")
	if archive.is_empty():return
	root.size=Vector2i(2048,919)
	var QA=load("res://tests/qa_class_selection.gd")
	var w=load("res://Main.tscn").instantiate()
	root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000.0
	check(QA.enter_game(w),"actual Main character entered")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive)
	SOURCE.reset();SHOP_CATALOG.release()
	check(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"verified live original tables")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var ids: Array=ALICE.keys();ids.append_array([366,137])
	for id: int in ids:
		var native: Dictionary=w.source_item_definition(id).get("native_record",{})
		check(not native.is_empty(),"original registered catalog #"+str(id))
		if not native.is_empty():w.catalog_db["아이템"].append(native)
	w._index_catalog_item_sources()
	var catalog=SHOP_CATALOG.session()
	check(catalog.available(),"same authenticated shop settlement owner")
	if catalog.available():w.source_shop.bind_source(catalog)
	var h: Node=w.hud
	await _tap_menu_trade(h)
	var window: Object=h.original_main_ui_controller.feature_window("trade")
	check(is_instance_valid(window) and window.is_open(),"actual touch upstream opens original Trade_All")
	if not is_instance_valid(window) or not window.is_open():
		w.queue_free();await process_frame;return
	var market: RefCounted=window.market
	check(market.search(0,"앨리스").size()==4,"exact four installed Alice weapons appear even without price")
	window._open_keypad();await process_frame
	window._editor.text="앨리스"
	var searched: Dictionary=window._apply_query()
	check(searched.get("handled",false) and searched.filled.items==4,"native exact four Alice search rows")
	if searched.get("handled",false):
		var images: Dictionary={}
		_image_scenes(window._scene,images)
		for id: int in ALICE:
			var member: String="UI/CsbFile/icon/Fx_Item_Weapon_%s_Myth_Alice.csb"%ALICE[id]
			var visual: Dictionary=images.get(member,{})
			check(not visual.is_empty() and visual.target.member=="UI/CommonUi/Common_Slot.csb" and int(visual.target.node_offset)==15012 and visual.playback.playing and visual.node.is_visible_in_tree(),"actual native animated source slot #"+str(id))
			check(market.price_reference(id).is_empty() and market.listings(id).is_empty(),"no arbitrary market price or stock #"+str(id))
	var exact: Dictionary=market.price_reference(366)
	var quote_rows: Array=market.listings(366)
	check(exact.get("basis")=="exact" and quote_rows.size()==1 and quote_rows[0].key=="local:366" and quote_rows[0].bundle_size==1000 and quote_rows[0].enchant==0,"captured fraction is only price, local leather lot has exact ID and independent quantity")
	if quote_rows.size()!=1:
		w.queue_free();await process_frame;return
	var leather: Dictionary=quote_rows[0]
	var shop: Object=w.source_shop
	var frozen_state: Dictionary=FROZEN.fresh_state()
	var captured=preload("res://scripts/exchange/frozen_catalog.gd").new()
	check(captured.load_snapshot(),"real captured evidence loads")
	var observed: Dictionary=captured.rows()[0]
	var old_key: String=preload("res://scripts/exchange/frozen_catalog.gd").key(observed)
	frozen_state={"version":1,"snapshot_sha256":captured.sha256,"day":FROZEN.day_at(shop._now()),"consumed":{old_key:1}}
	shop.state[FROZEN.STATE_KEY]=frozen_state.duplicate(true)
	w.gold=50000;w.inventory["다이아"]=200000
	var initial: Error=w._save_game(true)
	check(initial==OK,"isolated test seed has actual saved wallet and pre-existing captured spend: "+error_string(initial))
	var disk_before: String=FileAccess.get_sha256(w.save_path())
	# Compare a post-reload value to the already-written JSON representation.
	# Godot's Dictionary equality otherwise treats parsed 1.0 and int 1 apart.
	var saved_json: Variant=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	var stored_capture: Dictionary=saved_json.get("source_shop",{}).get(FROZEN.STATE_KEY,{}) if saved_json is Dictionary else {}
	check(not stored_capture.is_empty() and int(stored_capture.consumed.get(old_key,0))==1,"the old captured purchase record is on disk before any local action")
	check(not market.buy("snapshot:"+old_key).get("ok",false) and not market.buy("approx:366:0").get("ok",false) and FileAccess.get_sha256(w.save_path())==disk_before,"neither stale imported lot nor old approximate key spends locally")
	window._reset_search();window._item_pressed(366)
	check(window._listing_pressed(leather.key).get("handled",false),"actual original buy popup opens")
	var bought: Dictionary=window._buy_confirmed()
	check(bought.get("ok",false) and bought.get("item_class_id")==366 and w.inventory["다이아"]==200000-int(leather.bundle_price),"original buy commits exact local leather + its referenced charge: "+str(bought))
	check(market.listings(366).is_empty() and shop.state[FROZEN.STATE_KEY]==frozen_state,"same-day local stock used; legacy frozen spend unmodified")
	if not bought.get("ok",false):w.queue_free();await process_frame;return
	var bought_uid: String="";var other_uid: String=""
	var staged: Dictionary=SUPPLY.stage(w,[{"item_class_id":366,"amount":3,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	check(staged.get("ok",false) and w._save_game(true,staged.get("overrides",{}))==OK,"seed another independent physical stack of the exact same name")
	if staged.get("ok",false):w.inventory=staged.overrides.inventory;w.item_instances=staged.overrides.item_instances
	var leather_name: String=""
	for uid: String in w.item_instances:
		var proof: Dictionary=STACK.proof(w,uid)
		if int(proof.get("record",{}).get("source_item_class_id",0))!=366:continue
		if proof.remaining==1000:bought_uid=uid;leather_name=str(w.item_instances[uid].name)
		if proof.remaining==3:other_uid=uid
	check(not bought_uid.is_empty() and not other_uid.is_empty(),"bought real use/supply receipt and same-name sibling remain distinct")
	if bought_uid.is_empty() or other_uid.is_empty():w.queue_free();await process_frame;return
	var selected: String=leather_name+"@@@"+bought_uid
	var sibling: String=leather_name+"@@@"+other_uid
	w.ui_preferences.item_locks[sibling]=true
	check(w._save_game(true)==OK,"same-name sibling lock is saved")
	_check_registration_removed(w,market,selected,bought_uid)
	check(not _has_reclaim_tab(window) and _no_sale_controls(window),"no old sell target or registration controls exist on a new profile")

	# A legacy save is a fixture, not the removed registration path. Put
	# four physical units in old escrow, keeping the same-name locked stack.
	var previous: Dictionary=STACK.proof(w,bought_uid)
	var removed: Dictionary=STACK.stage_debit(w,[{"physical_id":bought_uid,"quantity":4,"expected_quantity":previous.remaining,"expected_remaining":996,"source_native_stack_receipt":previous.receipt}])
	check(removed.get("ok",false),"test fixture stages exactly four legacy units: "+str(removed.get("reason","")))
	if not removed.get("ok",false):w.queue_free();await process_frame;return
	var legacy: Dictionary=market.state()
	var now: int=shop._now()
	legacy.next_id=4
	legacy.listings["1"]=_legacy_row(366,leather_name,2,100,now,"selling","native_stack",bought_uid)
	legacy.listings["2"]=_legacy_row(366,leather_name,1,50,now,"expired","native_stack",bought_uid)
	legacy.listings["3"]=_legacy_row(366,leather_name,1,150,now,"sold","native_stack",bought_uid)
	var seed: Dictionary=removed.overrides
	var shop_save: Dictionary=shop.export_state()
	shop_save[MARKET.STATE_KEY]=legacy
	seed["source_shop"]=shop_save
	check(w._save_game(true,seed)==OK,"three old escrow statuses persisted via test-only fixture")
	w._load_game(true)
	check(not shop.save_blocked and market.my_listings().map(func(r: Dictionary)->String:return str(r.status))==["selling","expired","sold"] and int(w.inventory[leather_name])==999 and STACK.proof(w,other_uid).get("remaining")==3,"legacy escrow reloads without consolidating/charging the locked same-name stack")
	_check_registration_removed(w,market,selected,bought_uid)
	window._refresh_pressed()
	await process_frame
	var reclaim_button: Control=_source_area(window,"Nd_Server/Nd_TabMenu/Btn_Sell_Off")
	check(is_instance_valid(reclaim_button) and reclaim_button.is_visible_in_tree(),"actual original reclaim tab exists only with earlier unclaimed stock")
	if not is_instance_valid(reclaim_button):w.queue_free();await process_frame;return
	var reclaim_position: Vector2=reclaim_button.get_global_transform_with_canvas()*(reclaim_button.size*.5)
	await _touch(reclaim_button)
	check(window.tab=="sell" and int(window.last_result.get("filled",{}).get("mine",0))==2 and _no_sale_controls(window),"real original touch opens only cancellable/expired holdings")
	check(not market.take_back("3").get("ok",false),"sold stock cannot be reclaimed as an item")
	var sale_hash: String=FileAccess.get_sha256(w.save_path())
	var initial_escrow: Dictionary=market.state()
	var wallet_before: Dictionary=w.inventory.duplicate(true)
	w.equipment_collections.test_save_writer=func(_path: String,_payload: Dictionary)->Error:return ERR_CANT_CREATE
	var refused: Dictionary=market.take_back("1")
	check(not refused.get("ok",false) and market.state()==initial_escrow and w.inventory==wallet_before and FileAccess.get_sha256(w.save_path())==sale_hash,"failed legacy reclaim keeps both escrow, wallet, inventory and previous disk")
	w.equipment_collections.test_save_writer=Callable()
	w._load_game(true)
	check(not shop.save_blocked,"normal reload clears only the earlier write-failure guard")
	window._refresh_pressed();await process_frame
	var cancel: Control=_source_area(window,"Nd_Server/Trade_Tab_Sell/Btn_Cancel")
	check(is_instance_valid(cancel) and cancel.is_visible_in_tree(),"original cancel-all touch owner exists")
	if is_instance_valid(cancel):await _touch(cancel)
	check(market.my_listings().size()==2 and int(w.inventory[leather_name])==1001 and STACK.proof(w,other_uid).get("remaining")==3,"actual cancel touch returns two units without changing the locked same-name stack")
	var expired: Control=_source_area(window,"Nd_Server/Trade_Tab_Sell/Nd_TotalAmount/Btn_Return_All")
	check(is_instance_valid(expired) and expired.is_visible_in_tree(),"original expired-return touch owner exists")
	if is_instance_valid(expired):await _touch(expired)
	check(market.my_listings().size()==1 and int(w.inventory[leather_name])==1002 and shop.state[FROZEN.STATE_KEY]==stored_capture,"actual expiry touch returns only its unit and capture history is unchanged")
	check(window.tab=="search" and not _has_reclaim_tab(window) and _no_sale_controls(window),"empty reclaim tab disappears after last return, even with sold escrow pending")
	var no_registration_hash: String=FileAccess.get_sha256(w.save_path())
	await _touch_position(reclaim_position)
	check(window.tab=="search" and window.popup=="" and FileAccess.get_sha256(w.save_path())==no_registration_hash,"touch at the former sale location never registers or mutates anything")
	var unpaid_hash: String=FileAccess.get_sha256(w.save_path())
	var unpaid_wallet: int=int(w.inventory["다이아"])
	w.equipment_collections.test_save_writer=func(_path: String,_payload: Dictionary)->Error:return ERR_CANT_CREATE
	check(not market.settle_all().get("ok",false) and int(w.inventory["다이아"])==unpaid_wallet and market.my_listings().size()==1 and market.history().is_empty() and FileAccess.get_sha256(w.save_path())==unpaid_hash,"failed settlement neither pays, drops an escrow, appends history nor rewrites disk")
	w.equipment_collections.test_save_writer=Callable()
	w._load_game(true)
	window._set_tab("calculate");await process_frame
	var settle: Control=_source_area(window,"Nd_Server/Trade_Tab_Calculate/Nd_Calculate/Btn_Calculate_All")
	check(is_instance_valid(settle) and settle.is_visible_in_tree(),"original settlement touch owner remains")
	var before_settle: int=int(w.inventory["다이아"])
	if is_instance_valid(settle):await _touch(settle)
	check(market.my_listings().is_empty() and int(w.inventory["다이아"])==before_settle+140 and market.history().size()==1,"sold listing settles once at the old net price")
	check(not market.settle_all().get("ok",false),"already settled proceeds cannot be taken twice")
	w._load_game(true)
	check(market.my_listings().is_empty() and int(w.inventory[leather_name])==1002 and int(w.inventory["다이아"])==before_settle+140 and market.history().size()==1 and shop.state[FROZEN.STATE_KEY]==stored_capture,"reclaim, proceeds and history all persist after a real disk reload")
	var history: Dictionary=window._set_tab("history")
	check(history.get("handled",false) and int(history.filled.rows)==1,"legacy settlement is drawn in the original history tab")
	window._set_tab("search")
	var tomorrow: int=(int(market.state().approx_day)+1)*86400-14400
	shop.test_clock=func()->int:return tomorrow-1
	check(market.listings(366).is_empty(),"no reset at 04:59:59 KST")
	shop.test_clock=func()->int:return tomorrow
	check(market.listings(366).size()==1 and market.listings(366)[0].key==leather.key,"same local product restocks at 05:00 KST")
	shop.test_clock=Callable()
	var trade_saved: Dictionary=market.state()
	for malformed: Variant in [null,[],{"version":1,"listings":{}}]:
		shop.state[MARKET.STATE_KEY]=malformed
		var exposed: Dictionary=window._refresh_pressed()
		check(exposed.get("handled",false) and not market.state_problem().is_empty() and not market.buy("local:366").get("ok",false) and shop.state[MARKET.STATE_KEY]==malformed,"malformed trade state keeps original payload and never crashes native reopen")
	shop.state[MARKET.STATE_KEY]=trade_saved
	window._close_requested();w.queue_free();await process_frame
