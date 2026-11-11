extends RefCounted
## The original 523 shop window: Shop_All (frame, 상점/보관함 tabs, mileage,
## close) with its Shop_Tab_List page. Every listed product of the original
## market is one original Shop_List_Slot card (title, original product
## picture, price) laid out two per column in the page's horizontal ListView,
## as the client's Shop_List_SlotSet does. Tapping a card runs the existing
## source523 shop purchase (quote, confirmation, payment, order box).
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
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
const PAGE_SCOPE: Array[int]=[41516,40880,32588,32156]
const LIST=32156
const LIST_SIZE:=Vector2(900,470)
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
const MAX_CARDS: int=120
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

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in [ROOT,TAB_LIST,CARD]:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_shop_window_member_missing","member":member}
	_pack=pack
	_hud=weakref(hud)
	return {"ok":true,"configured":true,"set_member":SET}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, panel: Control) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(panel):return _fail("source_shop_window_host_unavailable")
	_parent=weakref(parent)
	_panel=weakref(panel)
	_scroll=0.0
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _products() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var panel: Object=_panel.get_ref() if _panel!=null else null
	if panel==null:return result
	for entry: Dictionary in panel.get("filtered"):
		if str(entry.get("source_table",""))!="MarketPurchase_Korean":continue
		result.append(entry)
		if result.size()>=MAX_CARDS:break
	return result

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var panel: Object=_panel.get_ref() if _panel!=null else null
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if parent==null or panel==null or hud==null:return _fail("source_shop_window_host_unavailable")
	var world: Object=hud.get_parent()
	var bindings: Dictionary={CLOSE:{"role":"button","activate":Callable(self,"_close_requested")},SHOP_TAB_NORMAL:{"role":"button","visible":false,"activate":Callable(self,"_ignore")},SHOP_TAB_PRESSED:{"role":"button","visible":true,"activate":Callable(self,"_ignore")},STORAGE_TAB_NORMAL:{"role":"button","visible":true,"activate":Callable(self,"_storage_requested")},STORAGE_TAB_PRESSED:{"role":"button","visible":false,"activate":Callable(self,"_storage_requested")},STORAGE_NEW:{"visible":false}}
	bindings[MILEAGE_TEXT]={"role":"source_text","text":str(int(world.get("inventory").get("마일리지",0))) if world!=null else "0"}
	var page_bindings: Dictionary={LIST:{"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")}}
	_consume_touch(TAB_LIST,PAGE_SCOPE,page_bindings)
	bindings[TAB_PROJECT]={"role":"project","visible":true,"source_node_offsets":PAGE_SCOPE,"bindings":page_bindings}
	_consume_touch(ROOT,ROOT_SCOPE,bindings)
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,ROOT,ROOT_SCOPE,bindings)
	if not result.get("ok",false):next.free();return result
	var page: Dictionary=next.project_player([TAB_PROJECT])
	if not page.get("ok",false):next.free();return page
	var list_node: Variant=page.player.get("source_nodes").get(LIST)
	var content: Variant=list_node.get_meta("source_list_content",null) if is_instance_valid(list_node) else null
	if not content is Node2D:next.free();return _fail("source_shop_window_list_content_missing")
	var products: Array[Dictionary]=_products()
	for index: int in range(products.size()):
		var card: Dictionary=_card(products[index],panel)
		if not card.get("ok",false):continue
		var column: int=index/2
		# Cards are centred on (147 + column*294, 346|121) in the SlotSet's
		# 294x466 panel; the panel's lower-left is the list's lower-left.
		card.scene.position=Vector2(CARD_X+COLUMN_WIDTH*float(column),-CARD_Y[index%2])
		content.add_child(card.scene)
	var previous: Node2D=_scene
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_content=content
	var columns: int=ceili(float(products.size())/2.0)
	_scroll_min=minf(0.0,LIST_SIZE.x-COLUMN_WIDTH*float(columns))
	_scroll=clampf(_scroll,_scroll_min,0.0)
	content.position.x=_scroll
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	return {"ok":true,"handled":true,"member":ROOT,"cards":products.size()}

func _card(entry: Dictionary, panel: Object) -> Dictionary:
	var id: int=int(entry.id)
	var row: Dictionary=entry.get("source_row",{})
	var title: String=str(panel.get("catalog").label(int(row.get("DescID",0)))) if panel.get("catalog")!=null else str(entry.get("title",""))
	if title.is_empty():title=str(entry.get("title",""))
	var cash: Script=load("res://scripts/shop/source523_cash_market.gd")
	var price: String=("다이아 %d"%int(cash.entry(id).diamonds)) if cash.listed(id) else ""
	var scope: Array[int]=CARD_SCOPE.duplicate()
	var bindings: Dictionary={BUY:{"role":"button","activate":Callable(self,"_buy").bind(id)},PRICE:{"role":"source_text","text":price,"visible":not price.is_empty()},TITLE:{"role":"source_text","text":title}}
	for offset: int in HIDDEN_TEXTS:bindings[offset]={"role":"static_source_text","visible":false}
	var picture: Dictionary=panel.call("_entry_image",entry)
	var has_picture: bool=picture.get("texture") is Texture2D
	if has_picture:bindings[PICTURE]={"role":"source_asset_slot","visible":false}
	else:bindings[PICTURE]={"visible":false}
	_consume_touch(CARD,scope,bindings)
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,CARD,scope,bindings)
	if not result.get("ok",false):scene.free();return result
	if has_picture:
		var owner: Dictionary=picture.duplicate()
		owner["ok"]=true
		var uploaded: Dictionary=scene.set_bound_source_visual_result(PICTURE,owner)
		if uploaded.get("ok",false):scene.set_bound_visible(PICTURE,true)
	return {"ok":true,"scene":scene}

func _buy(id: int) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	var panel: Object=_panel.get_ref() if _panel!=null else null
	if panel==null:return _fail("source_shop_window_host_unavailable")
	var listing: Variant=panel.get("listing")
	for index: int in range(listing.item_count):
		if int(listing.get_item_metadata(index))!=id:continue
		listing.select(index)
		panel.call("_select",index)
		panel.call("_act")
		return {"ok":true,"existing_purchase_requested":true,"id":id}
	return _fail("source_shop_window_product_not_listed")

func _storage_requested() -> Dictionary:
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
	_moved+=delta
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.x=_scroll

## Touch-enabled original nodes in the mounted subtrees with no action of
## their own swallow their touch (as the client's modal window does).
func _consume_touch(member: String, scope: Array[int], bindings: Dictionary) -> void:
	var tree: Dictionary=_pack.scene(member).get("nodeTree",{})
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
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_consume_subtree(child,bindings)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
