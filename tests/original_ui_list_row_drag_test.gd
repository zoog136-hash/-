extends SceneTree
## A finger that lands on a list row's button still scrolls the list in the
## original feature windows (source_main_window_kit): each row button hands
## its drag to the list through the native button router (DRAG_META), as the
## NPC store and the shop already do. Lists whose rows are all buttons used to
## stay put on a phone (문양 효과 목록, 카드 컬렉션 행).
const KIT=preload("res://scripts/ui/original_ui/source_main_window_kit.gd")
const ROUTER=preload("res://scripts/ui/original_ui/source_button_router.gd")
const BUTTON=preload("res://scripts/ui/original_ui/source_button.gd")
var checks: int=0
var failures: Array[String]=[]
var fired: int=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_LIST_ROW_DRAG_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _event(kind: String, at: Vector2, relative: Vector2=Vector2.ZERO) -> InputEvent:
	if kind=="drag":
		var drag:=InputEventScreenDrag.new()
		drag.index=0;drag.position=at;drag.relative=relative
		return drag
	var touch:=InputEventScreenTouch.new()
	touch.index=0;touch.position=at;touch.pressed=kind=="press"
	return touch

func _run() -> void:
	var holder:=Node2D.new()
	root.add_child(holder)
	var content:=Node2D.new()
	holder.add_child(content)
	var row:=Node2D.new()
	content.add_child(row)
	var button=BUTTON.new()
	row.add_child(button)
	button.bind_activation(func() -> Dictionary:
		fired+=1
		return {"ok":true},Vector2(50,50),true)
	button.current_state="normal"
	row.set_meta("source_button",button)
	var window=KIT.new()
	window._scrolls["Rows"]={"content":content,"min":-500.0,"value":0.0}
	window._forward_row_drags(row,"Rows")
	check(button.has_meta(ROUTER.DRAG_META),"a row button hands its drag to the list")
	var router=ROUTER.new()
	router.route(_event("press",Vector2(25,-25)),Vector2(25,-25),[button])
	for i: int in 6:router.route(_event("drag",Vector2(25,-25-10*(i+1)),Vector2(0,-10)),Vector2(25,-25-10*(i+1)),[button])
	router.route(_event("release",Vector2(25,-85)),Vector2(25,-85),[button])
	check(float(window._scrolls["Rows"].value)<-30.0 and fired==0,"a drag that starts on the button scrolls the list and does not tap: "+str(window._scrolls["Rows"].value))
	# The row moved with the list: tap it where it is now.
	var at: Vector2=(button.get("_input_area") as Control).get_global_rect().get_center()
	router.route(_event("press",at),at,[button])
	router.route(_event("release",at),at,[button])
	check(fired==1,"a tap without a drag still presses the button")
	var own:=Callable(self,"_initialize")
	button.set_meta(ROUTER.DRAG_META,own)
	window._forward_row_drags(row,"Rows")
	check(button.get_meta(ROUTER.DRAG_META)==own,"a row's own drag forward is kept")
	# A row's own horizontal card list inside the vertical list: a vertical
	# drag scrolls the outer list, a horizontal one the inner list.
	var outer:=Node2D.new();holder.add_child(outer)
	var inner:=Node2D.new();holder.add_child(inner)
	window._scrolls["Outer"]={"content":outer,"min":-500.0,"value":0.0}
	window._scrolls["Inner"]={"content":inner,"min":-500.0,"value":0.0,"axis":"x"}
	var card:=Node2D.new();holder.add_child(card)
	card.set_meta(KIT.ROW_LIST_META,"Outer")
	var card_row:=Node2D.new();card.add_child(card_row)
	check(KIT._outer_list_key(card_row)=="Outer","a node inside an outer row finds the outer list")
	window._nested_list_input(_event("press",Vector2.ZERO),"Inner","Outer")
	window._nested_list_input(_event("drag",Vector2.ZERO,Vector2(0,-40)),"Inner","Outer")
	check(float(window._scrolls["Outer"].value)<-30.0 and float(window._scrolls["Inner"].value)==0.0,"a vertical drag on an inner card scrolls the outer list")
	window._nested_list_input(_event("drag",Vector2.ZERO,Vector2(-40,0)),"Inner","Outer")
	check(float(window._scrolls["Inner"].value)<-30.0,"a horizontal drag scrolls the inner card list")
	holder.free()
	print("ORIGINAL_UI_LIST_ROW_DRAG_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
