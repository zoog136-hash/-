extends SceneTree
## The original 523 거래소 window (source_main_trade_window) over the offline
## trade runtime (scripts/exchange/trade523_market.gd). Without arguments (no
## original files): the original KR policy values, the TWILIGHT 근사 tax /
## buyer delay, the save validation, the money format, the HUD wiring and
## fail-closed configuration. Real input:
## -- --pack=<private original main UI pack directory>: Trade_All mounts each
##    tab (검색 분류 / 목록 / 매물, 판매 + 소지품, 정산, 정산 내역) and the
##    buy / sell input / register / search popups over a fake market.
## -- --main (with the private 523 definitions and UI pack environment): the
##    real Main opens the window from the HUD and buys a TWILIGHT 근사 listing,
##    registers a bag item, lets the simulated buyer take it and settles.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_trade_window.gd")
const MARKET=preload("res://scripts/exchange/trade523_market.gd")
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
	var registered: Array=[]
	var settled: int=0
	var sold: bool=false
	func categories() -> Array:
		return [{"id":1,"name":"무 기","children":[{"id":61,"name":"한손검"},{"id":71,"name":"도 끼"}]},{"id":41,"name":"소모품","children":[{"id":331,"name":"물 약"}]}]
	func category_name(id: int) -> String:
		return {1:"무 기",61:"한손검",41:"소모품"}.get(id,"")
	func search(_category: int, _query: String="") -> Array:
		return [{"item_class_id":366,"name":"가죽","min_price":1,"count":3,"approx":false,"grade":1},{"item_class_id":40001,"name":"근사 검","min_price":120,"count":3,"approx":true,"grade":3}]
	func listings(_id: int) -> Array:
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
	func bag_entries() -> Array:
		var rows: Array=[]
		for index: int in range(9):
			rows.append({"reference":"물약%d" % index,"name":"물약%d" % index,"instance_id":"","count":5,"record":{"name":"물약","slot":"consumable"},"item_class_id":40002,"equipment":false,"level":0,"registrable":index!=8,"reason":"거래소 거래 불가 아이템입니다"})
		return rows
	func entry(reference: String) -> Dictionary:
		for row: Dictionary in bag_entries():
			if row.reference==reference:return row
		return {}
	func quote_sell(reference: String, quantity: int, price: int) -> Dictionary:
		return {"ok":true,"entry":entry(reference),"quantity":quantity,"price":price,"unit_price":float(price)/float(quantity),"gross":price,"tax":price*7/100,"net":price-price*7/100,"commission":1000,"low_warning":false}
	func register(reference: String, quantity: int, price: int) -> Dictionary:
		registered.append([reference,quantity,price])
		return {"ok":true,"message":"판매 등록"}
	func my_listings() -> Array:
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
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
		if value=="--main":main=true
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	if main:await _real_main()
	print("ORIGINAL_UI_TRADE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty(),"main_checked":main}))
	quit(0 if failures.is_empty() else 1)

func _rules() -> void:
	# ItemTradeMarketPolicyValue (KR): the original limits the runtime uses.
	check(MARKET.MAX_SELL_COUNT==30 and MARKET.MIN_SALE_AMOUNT==10 and MARKET.MAX_SALE_AMOUNT==9999999 and MARKET.SALE_MINUTES==4320 and MARKET.MAX_FAVORITES==30,"original KR trade market policy values")
	var money: Dictionary=MARKET.settlement(1000)
	check(money.gross==1000 and money.tax==70 and money.net==930 and money.commission==MARKET.COMMISSION,"TWILIGHT 근사 7% tax and commission: "+str(money))
	check(MARKET.sale_delay(80.0,100.0)==5 and MARKET.sale_delay(100.0,100.0)==30 and MARKET.sale_delay(115.0,100.0)==180 and MARKET.sale_delay(150.0,100.0)==1440 and MARKET.sale_delay(151.0,100.0)==-1,"TWILIGHT 근사 buyer delay by price against the lowest listing")
	check(MARKET.validate_state(MARKET.fresh_state()).is_empty(),"a fresh trade save validates")
	var bad: Dictionary=MARKET.fresh_state()
	bad.listings["5"]={"name":"x","item_class_id":1,"quantity":1,"price":10,"registered_at":0,"expires_at":1,"sell_at":-1,"kind":"stack"}
	check(not MARKET.validate_state(bad).is_empty(),"a listing id at or above next_id is refused")
	bad.next_id=6
	check(MARKET.validate_state(bad).is_empty(),"a stack listing validates")
	bad.listings["5"].kind="instance"
	check(not MARKET.validate_state(bad).is_empty(),"an equipment listing needs its stored instance")
	check(WINDOW._money(9999)=="9999" and WINDOW._money(99999)=="9만9999" and WINDOW._money(20000)=="2만","the original 9만9999 money format")
	check(WINDOW._unit(0.005)=="0.01" and WINDOW._unit(120.0)=="120","unit prices keep two decimals below 100")
	check(HUD_CONTROLLER.FEATURE_WINDOWS.get("trade")==WINDOW,"the trade window is a registered feature window")
	var hud_source: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_source.contains("func open_frozen_exchange() -> void:\n\t_open_window(\"exchange\",\"거래소 · 초기 실측 고정\",\"\")\n\tif _open_original_feature(\"trade\"):return"),"the HUD 거래소 menu opens the original window first")
	var window=WINDOW.new()
	var hud:=FakeHud.new()
	var world:=FakeWorld.new()
	world.add_child(hud)
	root.add_child(world)
	check(window.open(Node2D.new()).get("code")!="","the window does not open before it is configured")
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
	var sell: Dictionary=window._set_tab("sell")
	check(sell.get("handled",false) and int(sell.filled.mine)==2 and int(sell.filled.bag)==9,"판매 tab: my listings and the 소지품 grid (3 Inventory_Slot_Set lines): "+str(sell).left(300))
	var refused: Dictionary=window._bag_pressed(8)
	check(not refused.get("ok",true) and window.popup=="","a non-tradable bag item explains instead of opening the input")
	var input: Dictionary=window._bag_pressed(0)
	check(input.get("handled",false) and window.popup=="input" and window.input_price==50,"a bag item opens Trade_Popup_Input at the lowest unit price: "+str(input).left(300))
	window._digit(3)
	check(window.input_count==5,"the count keypad caps at the owned count")
	window._set_field("price")
	window._delete();window._delete()
	window._digit(2);window._digit(4);window._digit(0)
	check(window.input_price==240,"the price keypad edits the total price")
	var confirm: Dictionary=window._input_confirmed()
	check(confirm.get("handled",false) and confirm.filled.get("popup_member")==WINDOW.REGISTER_POPUP,"확 인 opens Trade_Popup_Register: "+str(confirm).left(300))
	window._register_confirmed()
	check(fake.registered==[["물약0",5,240]] and window.popup=="","the register popup registers the count and price")
	fake.sold=true
	var calc: Dictionary=window._set_tab("calculate")
	check(calc.get("handled",false) and int(calc.filled.rows)==1,"정산 tab lists the sold listing")
	window._settle()
	check(fake.settled==1,"정 산 settles")
	var history: Dictionary=window._set_tab("history")
	check(history.get("handled",false) and int(history.filled.rows)==1,"정산 내역 lists the history")
	window._world_pressed()
	check(hud.shown.has("월드 거래소는 온라인 전용입니다 · 서버 거래소를 이용하세요"),"월드 거래소 explains it is online-only")
	window._close_requested()
	check(not window.is_open(),"Btn_Close closes the window")
	await process_frame
	parent.queue_free()
	world.queue_free()

## The real Main: the HUD menu opens the original window over the real
## definitions, frozen snapshot and saves (test wallet only).
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
		if bool(row.approx):
			approx_id=int(row.item_class_id)
			break
	check(approx_id>0,"a weapon without a snapshot row has TWILIGHT 근사 listings")
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
	check(bought.get("ok",false) and int(world.inventory["다이아"])==before-int(listed[0].bundle_price),"buying a 근사 listing pays its diamonds and saves: "+str(bought))
	check(market.listings(approx_id).size()==listed.size()-1,"the bought listing is gone for the day")
	var opened: Dictionary=window._top_pressed(1)
	check(opened.get("handled",false),"the window lists 무 기 in the real pack")
	var entry: Dictionary={}
	for row: Dictionary in market.bag_entries():
		if bool(row.registrable) and int(row.item_class_id)==approx_id:entry=row
	check(not entry.is_empty(),"the bought weapon is a registrable bag entry")
	if entry.is_empty():return
	var price: int=maxi(10,int(market.reference_unit_price(approx_id)*0.8))
	var gold_before: int=int(world.gold)
	var registered: Dictionary=market.register(str(entry.reference),1,price)
	check(registered.get("ok",false) and int(world.gold)==gold_before-MARKET.COMMISSION and market.entry(str(entry.reference)).is_empty(),"판매 등록 takes the item and the commission: "+str(registered))
	var shop: Object=world.source_shop
	var now: int=int(shop._now())
	shop.test_clock=func() -> int: return now+600
	var mine: Array=market.my_listings()
	check(mine.size()==1 and str(mine[0].status)=="sold","a listing below the lowest price sells to the simulated buyer")
	var diamonds: int=int(world.inventory["다이아"])
	var settled: Dictionary=market.settle_all()
	check(settled.get("ok",false) and int(world.inventory["다이아"])==diamonds+price-price*MARKET.TAX_PERCENT/100 and market.history().size()==1,"정산 pays the net diamonds: "+str(settled))
	var sell_tab: Dictionary=window._set_tab("sell")
	check(sell_tab.get("handled",false),"the 판매 tab mounts the real bag: "+str(sell_tab).left(300))
	var calc: Dictionary=window._set_tab("history")
	check(calc.get("handled",false) and int(calc.filled.rows)==1,"정산 내역 shows the settlement")
	shop.test_clock=Callable()
	window._close_requested()
	await process_frame
	world.queue_free()
