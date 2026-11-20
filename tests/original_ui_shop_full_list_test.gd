extends SceneTree
## The original shop window lists every market product of a tab (no 120 cap,
## the original order and purchase rules unchanged) as a virtual list: only
## the card columns near the 900-wide view exist, scrolling builds the
## columns that come in and frees the far ones. Synthetic (no original files).
##   godot --headless --path <repo> --script res://tests/original_ui_shop_full_list_test.gd
const SHOP=preload("res://scripts/ui/original_ui/source_main_shop_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePanel extends Control:
	var entries: Array=[]

class ShopWindow extends "res://scripts/ui/original_ui/source_main_shop_window.gd":
	var made: int=0
	func _card(entry: Dictionary, _panel: Object) -> Dictionary:
		made+=1
		var scene:=Node2D.new()
		scene.set_meta("id",int(entry.id))
		return {"ok":true,"scene":scene}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_SHOP_FULL_LIST_FAIL: "+label)

func _initialize() -> void:
	var panel:=FakePanel.new()
	root.add_child(panel)
	for index: int in range(400):panel.entries.append({"id":1000+index,"source_table":SHOP.MARKET})
	panel.entries.append({"id":5,"source_table":"Other"})
	var window:=ShopWindow.new()
	window._panel=weakref(panel)
	window.tabs=[]
	var listed: Array[Dictionary]=window._products()
	check(listed.size()==400,"every listed market product (no 120 cap): %d" % listed.size())
	check(int(listed[0].id)==1000 and int(listed[-1].id)==1399,"the panel's order is kept")
	window.tabs=[{"id":1,"order":1,"name":"t","products":[1399,1000,1200]}]
	window.tab=0
	var tabbed: Array[Dictionary]=window._products()
	check(tabbed.map(func(e: Dictionary) -> int:return int(e.id))==[1399,1000,1200],"a tab keeps its MarketDisplay order")
	window.tabs=[]
	window.products=listed
	window._content=Node2D.new()
	root.add_child(window._content)
	window._scroll=0.0
	window._sync_cards()
	var columns: int=ceili(900.0/SHOP.COLUMN_WIDTH)+SHOP.BUILD_COLUMNS
	check(window._cards.size()<=columns*2 and window._cards.size()>=6,"only columns near the view are built (%d)" % window._cards.size())
	var first: Node2D=window._cards[0]
	check(first.position==Vector2(SHOP.CARD_X,-SHOP.CARD_Y[0]) and (window._cards[1] as Node2D).position==Vector2(SHOP.CARD_X,-SHOP.CARD_Y[1]),"cards keep the SlotSet places")
	window._scroll_min=minf(0.0,SHOP.LIST_SIZE.x-SHOP.COLUMN_WIDTH*200.0)
	var drag:=InputEventScreenDrag.new()
	drag.relative=Vector2(-SHOP.COLUMN_WIDTH*100.0,0.0)
	window._list_input(drag)
	var range_now: Vector2i=window.card_columns(0)
	check(range_now.x==100 and window._cards.has(200) and not window._cards.has(0),"scrolling builds the columns in view and frees far ones (%s)" % str(range_now))
	var placed: Node2D=window._cards[201]
	check(placed.position==Vector2(SHOP.CARD_X+SHOP.COLUMN_WIDTH*100.0,-SHOP.CARD_Y[1]) and int(placed.get_meta("id"))==1201,"a scrolled-in card is its own product in its own column")
	drag.relative.x=-1e7
	window._list_input(drag)
	check(window._cards.has(399),"the last product is reachable")
	check(window.made<=60,"far fewer cards made than products (%d)" % window.made)
	window._content.free()
	panel.free()
	print("ORIGINAL_UI_SHOP_FULL_LIST_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
