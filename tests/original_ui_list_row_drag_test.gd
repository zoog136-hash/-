extends SceneTree
## A finger that lands on a list row's button still scrolls the list in the
## original feature windows (source_main_window_kit): each row button hands
## its drag to the list through the native button router (DRAG_META), as the
## NPC store and the shop already do. Lists whose rows are all buttons used to
## stay put on a phone (문양 효과 목록, 카드 컬렉션 행). Every original
## ListView with its own input handler does the same for the rows a window adds
## (sprite_scene: 하딘의 텔레포트 목적지, 퀘스트, 변신 카드; user report
## 2026-11-20 "하딘의 텔레포트 목록 드래그가 안되고").
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
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

var scrolled: float=0.0
var pressed_list: int=0

func _list_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:pressed_list+=1
	if event is InputEventScreenDrag:scrolled+=event.relative.y

func _ignore_input(_event: InputEvent) -> void:
	pass

func _row_button(content: Node2D) -> Object:
	var row:=Node2D.new()
	var button=BUTTON.new()
	row.add_child(button)
	button.bind_activation(func() -> Dictionary:
		fired+=1
		return {"ok":true},Vector2(50,50),true)
	button.current_state="normal"
	row.set_meta("source_button",button)
	content.add_child(row)
	return button

## A ListView's rows, authored or added later (NamedTree.add_row, a window's
## own placement), forward their buttons' drags to the list's input.
func _list_view_rows() -> void:
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(text.contains("inner.child_entered_tree.connect(forward_row_drags.bind(direct_binding.input))"),"an original ListView with an input hands every row's drags to it")
	check(SCENE.ROUTER_DRAG_META==ROUTER.DRAG_META,"the scene names the router's drag meta")
	check(SCENE._list_drag_input(Callable(self,"_list_input")) and not SCENE._list_drag_input(Callable(self,"_ignore_input")) and not SCENE._list_drag_input(null),"an inert list input is not a scroll target")
	var holder:=Node2D.new()
	root.add_child(holder)
	var content:=Node2D.new()
	holder.add_child(content)
	content.child_entered_tree.connect(SCENE.forward_row_drags.bind(Callable(self,"_list_input")))
	var button: Object=_row_button(content)
	check(button.get_meta(ROUTER.DRAG_META,Callable())==Callable(self,"_list_input") and button.has_meta(SCENE.LIST_DRAG_AUTO_META),"a row added to the list forwards its button's drag to the list")
	var router=ROUTER.new()
	var before: int=fired
	var at: Vector2=(button.get("_input_area") as Control).get_global_rect().get_center()
	router.route(_event("press",at),at,[button])
	for i: int in 6:router.route(_event("drag",at+Vector2(0,-10*(i+1)),Vector2(0,-10)),at+Vector2(0,-10*(i+1)),[button])
	router.route(_event("release",at+Vector2(0,-60)),at+Vector2(0,-60),[button])
	check(scrolled<=-50.0 and pressed_list==1 and fired==before,"a drag on a teleport row scrolls the list without selecting it: "+str(scrolled))
	router.route(_event("press",at),at,[button])
	router.route(_event("release",at),at,[button])
	check(fired==before+1,"a tap on the row still selects it")
	# A window's own forwarding (window kit: nested lists) replaces the default.
	var window=KIT.new()
	window._scrolls["Rows"]={"content":content,"min":-500.0,"value":0.0}
	window._forward_row_drags(button.get_parent(),"Rows")
	var forward: Variant=button.get_meta(ROUTER.DRAG_META)
	check(forward is Callable and (forward as Callable).get_method()==&"_list_input" and (forward as Callable).get_object()==window and not button.has_meta(SCENE.LIST_DRAG_AUTO_META),"the window kit's own row forward replaces the list default")
	# A button that already forwards elsewhere keeps it.
	var other:=Node2D.new()
	holder.add_child(other)
	var own: Object=_row_button(other)
	own.set_meta(ROUTER.DRAG_META,Callable(self,"_initialize"))
	other.remove_child(own.get_parent())
	content.add_child(own.get_parent())
	check(own.get_meta(ROUTER.DRAG_META)==Callable(self,"_initialize"),"a row button's own forward is kept by the list")
	holder.free()
