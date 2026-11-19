extends SceneTree
## The HUD's native button router takes an original CheckBox (its script is
## source_checkbox, which extends source_button: it used to be refused by the
## exact script check) and asks the button itself whether it takes input; a
## binding may turn on touch for a button the client enables in code
## (문양 저장 / 복구 are authored touchEnabled off).
const ROUTER=preload("res://scripts/ui/original_ui/source_button_router.gd")
const BUTTON=preload("res://scripts/ui/original_ui/source_button.gd")
const CHECKBOX=preload("res://scripts/ui/original_ui/source_checkbox.gd")
var checks: int=0
var failures: Array[String]=[]
var fired: int=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_ROUTER_TOUCH_ENABLED_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _touch(router: Object, candidates: Array, pressed: bool) -> Dictionary:
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.pressed=pressed
	event.position=Vector2(25,-25)
	return router.route(event,Vector2(25,-25),candidates)

func _run() -> void:
	var holder:=Node2D.new()
	root.add_child(holder)
	var box=CHECKBOX.new()
	holder.add_child(box)
	box.bind_activation(func(_selected: bool) -> Dictionary:
		fired+=1
		return {"ok":true},Vector2(50,50),true)
	box.current_state="normal"
	check(ROUTER._actual_button(box),"a source_checkbox is a router button")
	var router=ROUTER.new()
	_touch(router,[box],true)
	var released: Dictionary=_touch(router,[box],false)
	check(fired==1 and released.get("activated",false),"the router delivers a tap to a CheckBox: "+str(released))
	var plain=BUTTON.new()
	holder.add_child(plain)
	plain.bind_activation(func() -> Dictionary: return {"ok":true},Vector2(50,50),false)
	check(not ROUTER._available(plain),"touchEnabled off (input ignored): the router skips it")
	var router_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_button_router.gd")
	check(router_text.contains("value.call(\"_input_available\")"),"the router asks the button whether it takes input")
	var scene_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(scene_text.count("bool(binding.get(\"touch_enabled\",widget.touchEnabled))")==2,"a binding's touch_enabled overrides the authored touchEnabled for buttons and boxes")
	var symbol: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_symbol_window.gd")
	check(symbol.contains("if str(pair[0]) in [\"Btn_Save\",\"Btn_Repair\"]:spec[key][\"touch_enabled\"]=true"),"문양 저장 / 복구 take a tap")
	holder.free()
	print("ORIGINAL_UI_ROUTER_TOUCH_ENABLED_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
