extends RefCounted
## The original 523 quantity keypad (UI/CommonUi/Common_Calculator.csb): the
## count in Label_Volume, digits 0-9, ← (Btn_Back), 최대 (Btn_Max), -/+ and
## 취소 / 확 인 (Btn_Select, its Disabled look while the count is 0). The
## window only edits a count between 1 and the caller's maximum; the caller
## owns what the count buys (NPC 상점, 유료 상점). Nothing is drawn here: an
## unconnected original node keeps its authored look, the two popup effect
## projects (Fx_Popup_*) stay out.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const ROOT="UI/CommonUi/Common_Calculator.csb"
## Centre of the 1200x675 design (the other original popups' layout point).
const LAYOUT_POSITION=Vector2(600.0,-337.5)
const DIGITS: int=10
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _scene: Node2D
var _out: Dictionary={}
var _accept: Callable=Callable()
var value: int=1
var maximum: int=1
## The next digit replaces the shown count (the count shown on open is a hint).
var _fresh: bool=true
var last_result: Dictionary={}

func configure(pack: RefCounted) -> Dictionary:
	if pack==null or not pack.manifest.get("scenes",{}).has(ROOT):return {"ok":false,"handled":false,"code":"source_calculator_member_missing","member":ROOT}
	_pack=pack
	_tree=NamedTree.new(pack)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## Opens the keypad over `parent` with the count 1..`limit`; `accept` gets the
## chosen count on 확 인.
func open(parent: Node, limit: int, accept: Callable, z: int=190) -> Dictionary:
	if _pack==null or not is_instance_valid(parent):return _fail("source_calculator_host_unavailable")
	close()
	maximum=clampi(limit,1,1000)
	value=1
	_fresh=true
	var spec: Dictionary={}
	for name: String in ["Fx_Popup_LeftUp","Fx_Popup_RightBottom"]:spec[name]={"exclude":true}
	spec["Label_Volume"]={"role":"source_text","text":str(value)}
	for digit: int in range(DIGITS):spec["Nd_Keypad/Btn_No_%d" % digit]={"activate":Callable(self,"press_digit").bind(digit)}
	spec["Nd_Keypad/Btn_Back"]={"activate":Callable(self,"press_back")}
	spec["Nd_Keypad/Btn_Max"]={"activate":Callable(self,"press_max")}
	spec["Btn_Minus"]={"activate":Callable(self,"step").bind(-1)}
	spec["Btn_Plus"]={"activate":Callable(self,"step").bind(1)}
	spec["Btn_Cancel"]={"activate":Callable(self,"cancel")}
	spec["Btn_Select"]={"activate":Callable(self,"select")}
	spec["Btn_Select/Normal"]={"visible":true}
	spec["Btn_Select/Disabled"]={"visible":false}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	_accept=accept
	_scene=built.scene
	_out=out
	_scene.position=LAYOUT_POSITION
	parent.add_child(_scene)
	_scene.z_index=z
	last_result={"ok":true,"handled":true,"member":ROOT,"maximum":maximum}
	return last_result

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_out={}
	_accept=Callable()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func press_digit(digit: int) -> Dictionary:
	var next: int=digit if _fresh else value*10+digit
	_fresh=false
	value=mini(next,maximum)
	return _show()

func press_back() -> Dictionary:
	_fresh=false
	@warning_ignore("integer_division")
	value=value/10
	return _show()

func press_max() -> Dictionary:
	_fresh=true
	value=maximum
	return _show()

func step(delta: int) -> Dictionary:
	_fresh=true
	value=clampi(value+delta,1,maximum)
	return _show()

func select() -> Dictionary:
	if value<1:return {"ok":true,"refused":"count_zero"}
	if not is_open():return _fail("source_calculator_closed")
	var count: int=value
	var accept: Callable=_accept
	close()
	closed.emit()
	if accept.is_valid():accept.call(count)
	return {"ok":true,"selected":count}

func cancel() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"cancelled":true}

func _show() -> Dictionary:
	if not is_open():return _fail("source_calculator_closed")
	var shown: Dictionary=_set_text("Label_Volume",str(value))
	_set_visible("Btn_Select/Normal",value>=1)
	_set_visible("Btn_Select/Disabled",value<1)
	return {"ok":shown.get("ok",false),"value":value}

func _set_text(suffix: String, text: String) -> Dictionary:
	var located: Dictionary=NamedTree.locate(_scene,_out,suffix)
	if not located.get("ok",false):return located
	return located.player.set_bound_text(located.offset,text)

func _set_visible(suffix: String, shown: bool) -> void:
	var located: Dictionary=NamedTree.locate(_scene,_out,suffix)
	if located.get("ok",false):located.player.set_bound_visible(located.offset,shown)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
