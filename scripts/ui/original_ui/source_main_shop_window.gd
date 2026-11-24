extends RefCounted
## The original 523 shop window: Shop_All (frame, 상점/보관함 tabs, mileage,
## close) with its Shop_Tab_List page. Every listed product of the original
## market is one original Shop_List_Slot card (title, original product
## picture, price) laid out two per column in the page's horizontal ListView,
## as the client's Shop_List_SlotSet does.
## Tabs: the original BM shop categories (MarketDisplayCategoryType rows with
## DisplayOnBmShopCategory, in DisplayOrder, named by their DescID) in the
## page's Tab_1 bar; each tab is a copy of the page's own original tab button
## (Tab_2 Panel_Recommend: Btn_Normal / Btn_Pressed with its Label) and lists
## the products MarketDisplay files under that category (DisplayIndex order).
## A category with no sold product has no tab.
## Tapping a card quotes the offer (world.source_shop), opens the original
## quantity keypad (Common_Calculator) and buys with game currency only (다이아
## etc.; no real payment): the goods go into the bag in the same save, or stay
## in the 보관함 when the bag cannot take them (TWILIGHT 근사: the offline game
## receives the order box at once). Dragging a card scrolls the list (the
## button router forwards the finger to the list).
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const DEF=preload("res://scripts/resources/current523_definition_rows.gd")
const Calculator=preload("res://scripts/ui/original_ui/source_main_calculator.gd")
const Runtime=preload("res://scripts/shop/source523_shop_runtime.gd")
const Router=preload("res://scripts/ui/original_ui/source_button_router.gd")
const Store=preload("res://scripts/ui/original_ui/source_main_store_window.gd")
const ROOT="UI/Shop/Shop_All.csb"
const TAB_LIST="UI/Shop/Shop_Tab_List.csb"
const CARD="UI/Shop/Shop_List_Slot.csb"
const SET="UI/Shop/Shop_List_SlotSet.csb"
const CLOSE=324
const TAB_PROJECT=9504
const ROOT_SCOPE: Array[int]=[22568,22140,21740,21404,21068,20728,20348,19968,14432,9812,8324,TAB_PROJECT,CLOSE]
const MILEAGE_TEXT=8380
const SHOP_TAB_NORMAL=16604
const SHOP_TAB_PRESSED=14484
const STORAGE_TAB_NORMAL=12376
const STORAGE_TAB_PRESSED=10248
const STORAGE_NEW=9868
## Img_Line_1, Bg, ListView. The page's left column (Img_Line_2 over the
## Tab_2 / Shop_Tab_Recommend side list, 276 wide) is not mounted: this game
## has no side list, so the column was an empty space (user list 2026-11-21
## #14 "상점 탭 왼쪽 빈 공간 삭제"). The tab bar, line, frame and card list move
## left by its width and the tab bar / card list use that width.
const PAGE_SCOPE: Array[int]=[41516,32588,32156]
const LEFT_COLUMN: float=276.0
const SHIFTED: Array[int]=[41516,32588,32156,30896]
const LIST=32156
const LIST_SIZE:=Vector2(900.0+LEFT_COLUMN,470)
## The category tab bar (empty ListView) and the page's own tab button.
const TAB_BAR=30896
const TAB_BAR_WIDTH: float=910.0+LEFT_COLUMN
const TAB_SAMPLE_LIST=32900
const TAB_SAMPLE=36504
const TAB_NORMAL=38396
const TAB_PRESSED=36556
const TAB_NORMAL_LABEL=38836
const TAB_PRESSED_LABEL=36956
const TAB_ICONS: Array[int]=[38448,36612]
## Panel_Recommend's centre (Cocos) in its 65-high bar and its width.
const TAB_CENTRE:=Vector2(69.0,40.0)
const TAB_PITCH: float=138.0
const MARKET="MarketPurchase_Korean"
## Card nodes (Shop_List_Slot.csb).
const CARD_SCOPE: Array[int]=[11556,10324,4020]
const BUY=11556
const PRICE=11632
const PICTURE=10376
const TITLE=4072
const HIDDEN_TEXTS: Array[int]=[13448,13072,12296]
## Shop_List_SlotSet: column width and the two card centres (Cocos y up).
const COLUMN_WIDTH: float=294.0
const CARD_X: float=147.0
const CARD_Y: Array[float]=[346.0,121.0]
## Space kept between a list cut back to the screen and the screen edge.
const LIST_EDGE_MARGIN: float=8.0
## The runtime's refusal for an unaffordable price, and the client's line.
const SHORT_REASON: String="구매 재화가 부족합니다"
const DIAMOND: String="다이아"
const DIAMOND_SHORT_DESC: int=268491
## Card columns built beyond each edge of the list's view (the list is
## virtual: every product keeps its column, only those near the view exist);
## columns past KEEP_COLUMNS are freed.
const BUILD_COLUMNS: int=2
const KEEP_COLUMNS: int=4
signal closed
var _pack: RefCounted
var _hud: WeakRef
var _panel: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _content: Node2D
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
## [{id, order, name, products: [purchase id]}] of this opening.
var tabs: Array=[]
var tab: int=0
var _tab_content: Node2D
var _tab_scroll: float=0.0
var _tab_scroll_min: float=0.0
var _tab_moved: float=0.0
var calculator: RefCounted=Calculator.new()
## The current tab's products (every one; no cap) and the built cards
## (product index -> scene).
var products: Array[Dictionary]=[]
var _cards: Dictionary={}
var card_builds: int=0
var last_purchase: Dictionary={}
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in [ROOT,TAB_LIST,CARD]:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_shop_window_member_missing","member":member}
	_pack=pack
	_hud=weakref(hud)
	calculator.configure(pack)
	return {"ok":true,"configured":true,"set_member":SET}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, panel: Control) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(panel):return _fail("source_shop_window_host_unavailable")
	_parent=weakref(parent)
	_panel=weakref(panel)
	_scroll=0.0
	_tab_scroll=0.0
	tabs=tabs_of(served_entries(panel.get("entries")))
	tab=0
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	calculator.close()
	var previous: Node2D=_scene
	_scene=null
	_content=null
	_tab_content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

## The listed market entries of the current tab, in MarketDisplay order.
func _products() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var panel: Object=_panel.get_ref() if _panel!=null else null
	if panel==null:return result
	if tabs.is_empty():
		# No category rows (definitions unavailable): every listed product.
		for entry: Dictionary in panel.get("entries"):
			if str(entry.get("source_table",""))!=MARKET:continue
			result.append(entry)
		return result
	if tab<0 or tab>=tabs.size():return result
	var by_id: Dictionary={}
	for entry: Dictionary in panel.get("entries"):
		if str(entry.get("source_table",""))==MARKET:by_id[int(entry.id)]=entry
	for id: int in tabs[tab].products:
		if by_id.has(id):result.append(by_id[id])
	return result

## The market entries this game's server sells (world.source_shop.served_here):
## an offer of another server group (e.g. new-server event rows) is not listed.
func served_entries(entries: Array) -> Array:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var runtime: Object=hud.get_parent().get("source_shop") if hud!=null and hud.get_parent()!=null else null
	if runtime==null or not runtime.has_method("served_here"):return entries
	return entries.filter(func(entry: Variant) -> bool: return not entry is Dictionary or str(entry.get("source_table",""))!=MARKET or runtime.served_here(int(entry.id)))

## Original BM shop categories holding at least one of `entries` (the market
## rows the shop panel lists), each with its products in DisplayIndex order.
static func tabs_of(entries: Array) -> Array:
	var listed: Dictionary={}
	for entry: Variant in entries:
		if entry is Dictionary and str(entry.get("source_table",""))==MARKET:listed[int(entry.id)]=true
	var by_category: Dictionary={}
	for row: Dictionary in DEF.rows("MarketDisplay"):
		var id: int=int(row.get("PurchaseID",0))
		if not listed.has(id):continue
		var category: int=int(row.get("DisplayCategoryTypeID",0))
		if not by_category.has(category):by_category[category]=[]
		by_category[category].append([int(row.get("DisplayIndex",0)),int(row.get("ID",0)),id])
	var result: Array=[]
	for row: Dictionary in DEF.rows("MarketDisplayCategoryType"):
		var category: int=int(row.get("ID",0))
		if row.get("DisplayOnBmShopCategory")!=true or not by_category.has(category):continue
		var shown: Array=by_category[category]
		shown.sort()
		var listed_ids: Array[int]=[]
		for item: Array in shown:
			if not listed_ids.has(int(item[2])):listed_ids.append(int(item[2]))
		result.append({"id":category,"order":int(row.get("DisplayOrder",0)),"name":_label(int(row.get("DescID",0)),str(row.get("Name",""))),"products":listed_ids})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order<b.order or (a.order==b.order and a.id<b.id))
	return result

static func _label(desc_id: int, fallback: String) -> String:
	var text: String=str(DEF.row("DescData_Korean",desc_id).get("Description","")) if desc_id>0 else ""
	return text.strip_edges() if not text.strip_edges().is_empty() else fallback

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var panel: Object=_panel.get_ref() if _panel!=null else null
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if parent==null or panel==null or hud==null:return _fail("source_shop_window_host_unavailable")
	var world: Object=hud.get_parent()
	var bindings: Dictionary={CLOSE:{"role":"button","activate":Callable(self,"_close_requested")},SHOP_TAB_NORMAL:{"role":"button","visible":false,"activate":Callable(self,"_ignore")},SHOP_TAB_PRESSED:{"role":"button","visible":true,"activate":Callable(self,"_ignore")},STORAGE_TAB_NORMAL:{"role":"button","visible":true,"activate":Callable(self,"_storage_requested")},STORAGE_TAB_PRESSED:{"role":"button","visible":false,"activate":Callable(self,"_storage_requested")},STORAGE_NEW:{"visible":false}}
	bindings[MILEAGE_TEXT]={"role":"source_text","text":str(int(world.get("inventory").get("마일리지",0))) if world!=null else "0"}
	var page_bindings: Dictionary={LIST:{"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")}}
	var page_roots: Array[int]=PAGE_SCOPE.duplicate()
	if not tabs.is_empty():
		page_roots.append(TAB_BAR)
		page_bindings[TAB_BAR]={"role":"source_list","row_offsets":[]}
	var page_tree: Dictionary=_pack.scene(TAB_LIST).get("nodeTree",{})
	var page_scope: Array[int]=_subtree(page_tree,page_roots)
	_consume_touch(page_tree,PAGE_SCOPE,page_bindings)
	bindings[TAB_PROJECT]={"role":"project","visible":true,"source_node_offsets":page_scope,"bindings":page_bindings}
	var root_tree: Dictionary=_pack.scene(ROOT).get("nodeTree",{})
	_consume_touch(root_tree,ROOT_SCOPE,bindings)
	var root_scope: Array[int]=_subtree(root_tree,ROOT_SCOPE)
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,ROOT,root_scope,bindings)
	if not result.get("ok",false):next.free();return result
	var page: Dictionary=next.project_player([TAB_PROJECT])
	if not page.get("ok",false):next.free();return page
	for offset: int in SHIFTED:
		var moved: Variant=page.player.get("source_nodes").get(offset)
		if moved is Node2D:(moved as Node2D).position.x-=LEFT_COLUMN
		elif moved is Control:(moved as Control).position.x-=LEFT_COLUMN
	var list_node: Variant=page.player.get("source_nodes").get(LIST)
	var content: Variant=(list_node.get_meta("source_list_content") if list_node.has_meta("source_list_content") else null) if is_instance_valid(list_node) else null
	if not content is Node2D:next.free();return _fail("source_shop_window_list_content_missing")
	var tab_node: Variant=page.player.get("source_nodes").get(TAB_BAR)
	var tab_content: Variant=(tab_node.get_meta("source_list_content") if tab_node.has_meta("source_list_content") else null) if is_instance_valid(tab_node) else null
	var tabs_built: int=0
	if tab_content is Node2D:
		for index: int in range(tabs.size()):
			var button: Dictionary=_tab_button(index,page_tree)
			if not button.get("ok",false):continue
			tab_content.add_child(button.scene)
			tabs_built+=1
	products=_products()
	var previous: Node2D=_scene
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_content=content
	_tab_content=tab_content if tab_content is Node2D else null
	if _tab_content!=null:
		_tab_scroll_min=minf(0.0,fit_list(_tab_content,TAB_BAR_WIDTH)-TAB_PITCH*float(tabs.size()))
		_tab_scroll=clampf(_tab_scroll,_tab_scroll_min,0.0)
		_tab_content.position.x=_tab_scroll
	var columns: int=ceili(float(products.size())/2.0)
	_scroll_min=minf(0.0,fit_list(content,LIST_SIZE.x)-COLUMN_WIDTH*float(columns))
	_scroll=clampf(_scroll,_scroll_min,0.0)
	content.position.x=_scroll
	_cards.clear()
	_sync_cards()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"cards":products.size(),"built_cards":_cards.size(),"tabs":tabs.size(),"tabs_built":tabs_built,"tab":tab,"tab_name":str(tabs[tab].name) if tab<tabs.size() else ""}
	return last_result

## A clipped original list (Tab_1 tab bar, the card ListView) ends at the
## screen's edge when the 16:9 layout is wider than what the screen shows
## (Shop_All is authored wider than 1280): its clip is cut back to the shown
## width, so the list ends at a ListView edge as in the client and its last
## tab / column can be scrolled fully into view. Returns the width used.
static func fit_list(content: Node2D, nominal: float) -> float:
	var origin: Node=content.get_parent()
	var clip: Variant=origin.get_parent() if origin!=null else null
	if not clip is Control or not (clip as Control).is_inside_tree():return nominal
	var control: Control=clip
	var at: Transform2D=control.get_global_transform_with_canvas()
	var scale: float=absf(at.get_scale().x)
	if scale<=0.0:return nominal
	var shown: float=clampf((control.get_viewport_rect().end.x-at.origin.x)/scale-LIST_EDGE_MARGIN,TAB_PITCH,nominal)
	control.size.x=shown
	return shown

## Card columns [first, last] within `margin` columns of the list's view.
func card_columns(margin: int) -> Vector2i:
	var columns: int=ceili(float(products.size())/2.0)
	if columns==0:return Vector2i(0,-1)
	var first: int=floori(-_scroll/COLUMN_WIDTH)-margin
	var last: int=ceili((-_scroll+LIST_SIZE.x)/COLUMN_WIDTH)-1+margin
	return Vector2i(maxi(0,first),mini(columns-1,last))

## Builds the cards of columns that came near the view; frees far ones.
func _sync_cards() -> void:
	if not is_instance_valid(_content):return
	var panel: Object=_panel.get_ref() if _panel!=null else null
	if panel==null:return
	var keep: Vector2i=card_columns(KEEP_COLUMNS)
	for index: Variant in _cards.keys():
		var column: int=int(index)/2
		if column>=keep.x and column<=keep.y:continue
		var old: Variant=_cards[index]
		_cards.erase(index)
		if is_instance_valid(old):
			old.hide()
			old.queue_free()
	var wanted: Vector2i=card_columns(BUILD_COLUMNS)
	for column: int in range(wanted.x,wanted.y+1):
		for row: int in 2:
			var index: int=column*2+row
			if index>=products.size() or _cards.has(index):continue
			var card: Dictionary=_card(products[index],panel)
			if not card.get("ok",false):continue
			# Cards are centred on (147 + column*294, 346|121) in the SlotSet's
			# 294x466 panel; the panel's lower-left is the list's lower-left.
			card.scene.position=Vector2(CARD_X+COLUMN_WIDTH*float(column),-CARD_Y[row])
			_content.add_child(card.scene)
			_cards[index]=card.scene
			card_builds+=1

## One category tab: a copy of the page's original tab button (Panel_Recommend
## of Tab_2) placed in slot `index` of the Tab_1 bar.
func _tab_button(index: int, tree: Dictionary) -> Dictionary:
	var on: bool=index==tab
	var name: String=str(tabs[index].name)
	var scope: Array[int]=_subtree(tree,[TAB_SAMPLE])
	var bindings: Dictionary={TAB_SAMPLE_LIST:{"role":"source_list","row_offsets":[TAB_SAMPLE]},
		TAB_NORMAL:{"role":"button","visible":not on,"activate":Callable(self,"select_tab").bind(index)},
		TAB_PRESSED:{"role":"button","visible":on,"activate":Callable(self,"select_tab").bind(index)},
		TAB_NORMAL_LABEL:{"role":"source_text","text":name},TAB_PRESSED_LABEL:{"role":"source_text","text":name}}
	for offset: int in TAB_ICONS:bindings[offset]={"visible":false}
	_consume_touch(tree,[TAB_SAMPLE],bindings)
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,TAB_LIST,scope,bindings)
	if not result.get("ok",false):scene.free();return result
	var sample: Variant=scene.source_nodes.get(TAB_SAMPLE)
	if not sample is Node2D:scene.free();return _fail("source_shop_window_tab_sample_missing")
	# The sample's place inside its own scene (Node > Nd_List > Tab_2 list).
	# A clipping list's SourceClipRect is a Control (top-left origin, one list
	# height up): its offset belongs to the chain too.
	var at: Transform2D=Transform2D.IDENTITY
	var node: Node=sample
	while node!=null and node!=scene:
		if node is Node2D:at=(node as Node2D).transform*at
		elif node is Control:at=Transform2D(0.0,(node as Control).position)*at
		node=node.get_parent()
	scene.position=Vector2(TAB_CENTRE.x+TAB_PITCH*float(index),-TAB_CENTRE.y)-at.origin
	for offset: int in [TAB_NORMAL,TAB_PRESSED]:_forward_drag(scene,offset,Callable(self,"_tab_input"))
	return {"ok":true,"scene":scene}

func select_tab(index: int) -> Dictionary:
	if calculator.is_open():return {"ok":true,"ignored_under_keypad":true}
	if absf(_tab_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	if index<0 or index>=tabs.size():return {"ok":true,"empty":true}
	if index==tab:return {"ok":true,"tab":tab}
	tab=index
	_scroll=0.0
	return _stage()

func _tab_input(event: InputEvent) -> void:
	if not is_instance_valid(_tab_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		if event.pressed:_tab_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.x
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)!=0:delta=event.relative.x
	if delta==0.0:return
	var scale_x: float=absf(_tab_content.get_global_transform_with_canvas().get_scale().x)
	if scale_x>0.0:delta/=scale_x
	_tab_moved+=absf(delta)
	_tab_scroll=clampf(_tab_scroll+delta,_tab_scroll_min,0.0)
	_tab_content.position.x=_tab_scroll

## The button's finger drag goes to `input` (router meta; mouse GUI path).
static func _forward_drag(scene: Node2D, offset: int, input: Callable) -> void:
	var node: Variant=scene.source_nodes.get(offset)
	var button: Variant=node.get_meta("source_button") if is_instance_valid(node) and node.has_meta("source_button") else null
	if not is_instance_valid(button):return
	button.set_meta(Router.DRAG_META,input)
	var area: Variant=button.get("_input_area")
	if area is Control and not area.gui_input.is_connected(input):area.gui_input.connect(input)

func _card(entry: Dictionary, panel: Object) -> Dictionary:
	var id: int=int(entry.id)
	var row: Dictionary=entry.get("source_row",{})
	var title: String=str(panel.get("catalog").label(int(row.get("DescID",0)))) if panel.get("catalog")!=null else str(entry.get("title",""))
	if title.is_empty():title=str(entry.get("title",""))
	var price: String=""
	var catalog: Object=panel.get("catalog")
	if catalog!=null:
		var quote: Dictionary=catalog.payment_quote(id,1)
		if quote.get("ok",false) and int(quote.get("total",0))>0:
			price="%s %d"%[str(panel.call("_value_name",int(quote.unit_id),int(quote.class_id))),int(quote.total)]
	var bindings: Dictionary={BUY:{"role":"button","activate":Callable(self,"_buy").bind(id)},PRICE:{"role":"source_text","text":price,"visible":not price.is_empty()},TITLE:{"role":"source_text","text":title}}
	for offset: int in HIDDEN_TEXTS:bindings[offset]={"role":"static_source_text","visible":false}
	var picture: Dictionary=panel.call("_entry_image",entry)
	var has_picture: bool=picture.get("texture") is Texture2D
	if has_picture:bindings[PICTURE]={"role":"source_asset_slot","visible":false}
	else:bindings[PICTURE]={"visible":false}
	var tree: Dictionary=_pack.scene(CARD).get("nodeTree",{})
	var scope: Array[int]=_subtree(tree,CARD_SCOPE)
	_consume_touch(tree,scope,bindings)
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,CARD,scope,bindings)
	if not result.get("ok",false):scene.free();return result
	if has_picture:
		var owner: Dictionary=picture.duplicate()
		owner["ok"]=true
		var uploaded: Dictionary=scene.set_bound_source_visual_result(PICTURE,owner)
		if uploaded.get("ok",false):scene.set_bound_visible(PICTURE,true)
	_forward_drag(scene,BUY,Callable(self,"_list_input"))
	return {"ok":true,"scene":scene}

func _buy(id: int) -> Dictionary:
	if calculator.is_open():return {"ok":true,"ignored_under_keypad":true}
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if hud==null or parent==null:return _fail("source_shop_window_host_unavailable")
	var runtime: Object=hud.get_parent().get("source_shop")
	if runtime==null:return _fail("source_shop_window_runtime_missing")
	var quote: Dictionary=runtime.call("quote",id,1)
	if not quote.get("ok",false):
		var reason: String=str(quote.get("reason","구매할 수 없는 상품입니다"))
		if reason==SHORT_REASON:reason=shortage_text(id)
		hud.call("show_message",reason)
		return {"ok":true,"refused":reason}
	var limit: int=Store.affordable(quote,hud.get_parent())
	if limit<1:
		var short: String=shortage_text(id)
		hud.call("show_message",short)
		return {"ok":true,"refused":short}
	var opened: Dictionary=calculator.open(parent,limit,Callable(self,"purchase").bind(id))
	if opened.get("handled",false):return {"ok":true,"requested":id,"calculator":true,"maximum":limit}
	hud.call("confirm_action","유료 상점 · 구매","%s\n구매할 수량을 선택하세요" % str(quote.get("name","")),"구매",func(amount: int) -> void: purchase(amount,id),limit)
	return {"ok":true,"requested":id,"calculator":false,"maximum":limit}

## The refusal of an offer the wallet cannot pay: the client's own line for
## 다이아 (DescData 268491); other game currencies use the same sentence with
## their name (TWILIGHT 근사: the client text names only 다이아).
func shortage_text(id: int) -> String:
	var panel: Object=_panel.get_ref() if _panel!=null else null
	var catalog: Object=panel.get("catalog") if panel!=null else null
	var name: String=""
	if catalog!=null:
		var price: Dictionary=catalog.payment_quote(id,1)
		if price.get("ok",false):name=str(panel.call("_value_name",int(price.unit_id),int(price.class_id)))
	var original: String=str(DEF.row("DescData_Korean",DIAMOND_SHORT_DESC).get("Description","")).strip_edges()
	if original.is_empty():original="보유한 다이아가 부족하여 아이템을 구매할 수 없습니다."
	if name.is_empty() or name==DIAMOND:return original
	return original.replace(DIAMOND+"가",name+("이" if _has_final(name) else "가"))

static func _has_final(word: String) -> bool:
	var code: int=word.unicode_at(word.length()-1) if not word.is_empty() else 0
	return code>=0xAC00 and code<=0xD7A3 and (code-0xAC00)%28!=0

## Pays `amount` of offer `id` with game currency; the goods go to the bag
## (the 보관함 keeps them when the bag cannot take them).
func purchase(amount: int, id: int) -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_shop_window_host_unavailable")
	var world: Object=hud.get_parent()
	var result: Dictionary=world.get("source_shop").call("buy",id,amount,Runtime.Delivery.BAG_OR_BOX)
	last_purchase=result
	hud.call("show_message",str(result.get("reason","거래를 완료했습니다")))
	if result.get("ok",false):
		world.call("_update_hud")
		hud.call("refresh_inventory",world.get("inventory"))
	refresh()
	return result

func _storage_requested() -> Dictionary:
	if calculator.is_open():return {"ok":true,"ignored_under_keypad":true}
	# The order box (보관함) stays in the existing shop panel.
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var panel: Object=_panel.get_ref() if _panel!=null else null
	close()
	if panel!=null and panel.get("mode")!=null:
		panel.mode.select(4)
		panel.call("_build_entries")
	if hud!=null and hud.get("workspace") is CanvasItem:hud.workspace.show()
	return {"ok":true,"existing_order_box":true}

func _ignore() -> Dictionary:
	return {"ok":true}

func _close_requested() -> Dictionary:
	if calculator.is_open():return {"ok":true,"ignored_under_keypad":true}
	close()
	closed.emit()
	return {"ok":true,"closed":true}

func _list_input(event: InputEvent) -> void:
	if not is_instance_valid(_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed
		if event.pressed:_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.x
	elif event is InputEventMouseMotion and _drag:delta=event.relative.x
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=COLUMN_WIDTH*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_x: float=absf(_content.get_global_transform_with_canvas().get_scale().x)
	if scale_x>0.0 and not event is InputEventMouseButton:delta/=scale_x
	_moved+=absf(delta)
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.x=_scroll
	_sync_cards()

## Touch-enabled original nodes in the mounted subtrees with no action of
## their own swallow their touch (as the client's modal window does).
static func _consume_touch(tree: Dictionary, scope: Array[int], bindings: Dictionary) -> void:
	for offset: int in scope:_consume_subtree(Scene._node_at_offset(tree,offset),bindings)

static func _consume_subtree(node: Dictionary, bindings: Dictionary) -> void:
	if node.is_empty():return
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var offset: int=int(node.get("_offset",-1))
	if bool(widget.get("touchEnabled",false)) and node.get("classname")!="ProjectNode":
		var binding: Dictionary=bindings.get(offset,{})
		if not binding.has("role") and not binding.has("input"):
			binding["role"]="consume"
			bindings[offset]=binding
	# Labels the window does not drive keep the client's authored text.
	if node.get("classname") in ["Text","TextBMFont"] and not bindings.get(offset,{}).has("role"):
		var label: Dictionary=bindings.get(offset,{})
		label["role"]="static_source_text"
		bindings[offset]=label
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_consume_subtree(child,bindings)

## A node scope keeps only the listed nodes and their ancestors: list every
## descendant of each mounted node (a nested ProjectNode keeps its own scope).
static func _subtree(tree: Dictionary, roots: Array[int]) -> Array[int]:
	var result: Array[int]=[]
	for offset: int in roots:_collect(Scene._node_at_offset(tree,offset),result)
	return result

static func _collect(node: Dictionary, result: Array[int]) -> void:
	if node.is_empty():return
	var offset: int=int(node.get("_offset",-1))
	if offset not in result:result.append(offset)
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_collect(child,result)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
