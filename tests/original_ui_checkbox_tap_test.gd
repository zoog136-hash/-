extends SceneTree
## Original CheckBoxes take a finger like original Buttons: the HUD's native
## button router collects source_checkbox too, and a binding with
## tap_when_disabled keeps the authored disabled look (Cocos displaystate =
## setBright, a look only) while its tap still runs the callback
## (카드 컬렉션 member cards: CB_Check never reacted to a touch).
const BUTTON=preload("res://scripts/ui/original_ui/source_button.gd")
const CHECKBOX=preload("res://scripts/ui/original_ui/source_checkbox.gd")
const HUD=preload("res://scripts/ui/original_ui/source_main_hud.gd")
var checks: int=0
var failures: Array[String]=[]
var fired: int=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_CHECKBOX_TAP_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _touch(button: Object, pressed: bool) -> Dictionary:
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.pressed=pressed
	event.position=Vector2(25,-25)
	return button.handle_native_touch(event,Vector2(25,-25))

func _run() -> void:
	var holder:=Node2D.new()
	root.add_child(holder)
	var button=BUTTON.new()
	holder.add_child(button)
	button.bind_activation(func() -> Dictionary:
		fired+=1
		return {"ok":true},Vector2(50,50),true)
	button.current_state="disabled"
	check(not button._input_available(),"a disabled button takes no tap by default")
	_touch(button,true);_touch(button,false)
	check(fired==0,"nothing runs for a plain disabled button")
	button.disabled_tap=true
	check(button._input_available(),"tap_when_disabled takes the tap")
	_touch(button,true)
	check(button.current_state=="disabled","the press keeps the disabled look")
	var released: Dictionary=_touch(button,false)
	check(fired==1 and released.get("activated",false) and button.current_state=="disabled","the release runs the callback and keeps the look")
	button.disabled_tap=false
	button.current_state="normal"
	check(button._input_available(),"a normal button is unchanged")
	# The router's candidates include an original CheckBox.
	var node:=Node2D.new()
	holder.add_child(node)
	var box=CHECKBOX.new()
	node.add_child(box)
	node.set_meta("source_checkbox",box)
	var found: Array=[]
	HUD._collect_native_buttons(holder,found)
	check(found.has(box) and found.has(button)==false,"the router collects a source_checkbox node: "+str(found.size()))
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(text.contains("checkbox.disabled_tap=true") and text.contains("button.disabled_tap=true"),"sprite_scene applies tap_when_disabled to buttons and boxes")
	var collection: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_card_collection_window.gd")
	check(collection.contains("card.spec[\"Panel_Root/CB_Check\"][\"tap_when_disabled\"]=true"),"collection member cards take their tap")
	holder.free()
	print("ORIGINAL_UI_CHECKBOX_TAP_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
