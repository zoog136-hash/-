extends SceneTree
## Production widget/window with a small fake API: focused drag/config guards.
## This does not replace the actual Main/field/save movement test.
const VIEW=preload("res://scripts/ui/auto_hunting_destinations.gd")
const WINDOW=preload("res://scripts/ui/renewal_window.gd")
class TestHUD extends Node:
	var workspace: Control
class TestWorld extends Node:
	var hud=TestHUD.new()
	var settings={"enabled":true,"end_inclusive":true,"search_order":"center_first"}
	var moves:int=0
	func auto_hunting_destinations()->Dictionary:
		return {"entries":[{"schedule":{"ID":4,"RecommendLevel":17},"teleport":{"TeleportCost":8000},"currency":{"Name":"Adena"},"prerequisites":[],"hunting_territory":null,
			"destinations":[{"territory":{"Name":"unit destination"},"link":{"ID":662}}]}]}
	func auto_hunting_local_settings()->Dictionary:return settings.duplicate(true)
	func auto_hunting_set_local_settings(value:Dictionary)->Dictionary:settings=value.duplicate(true);return {"ok":true}
	func auto_hunting_movement_assessment(_id:int,_link:int)->Dictionary:return {"ok":true,"reason":"unit quote"}
	func auto_hunting_move(_id:int,_link:int)->Dictionary:moves+=1;return {"ok":true,"reason":"unit move"}
var failures:Array[String]=[]
var checks:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("AUTO_HUNT_LOCAL_UI_FAIL: ",label)
func run()->void:
	var world=TestWorld.new();root.add_child(world);world.add_child(world.hud)
	world.hud.workspace=WINDOW.new();world.hud.add_child(world.hud.workspace)
	var scroll:=ScrollContainer.new();world.hud.workspace.mount(scroll)
	var col:=VBoxContainer.new();scroll.add_child(col)
	var view=VIEW.new();col.add_child(view);view.configure(world)
	await process_frame
	check(view.owner_scroll==scroll,"existing scroll ancestor bound")
	for control:Control in [view.move_button,view.local_enabled,view.end_rule,view.search_order]:
		check(control.gui_input.get_connections().size()>0,"charged/config controls register existing drag capture")
	world.hud.workspace.scroll_gestures[scroll.get_instance_id()]={"dragged":true}
	view.move_button.pressed.emit()
	check(world.moves==0,"drag release cannot spend fee")
	view.local_enabled.button_pressed=false
	check(world.settings.enabled and view.local_enabled.button_pressed,"drag release cannot toggle or persist policy")
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	view.end_rule.gui_input.emit(press)
	view.end_rule.select(1);view.end_rule.item_selected.emit(1)
	check(not world.settings.end_inclusive,"next dropdown press resets stale drag state")
	view.move_button.gui_input.emit(press);view.move_button.pressed.emit()
	check(world.moves==1,"next deliberate action can execute")
	check(view.get_children().find(view.move_button.get_parent())<view.get_children().find(view.local_enabled),"movement action precedes optional settings")
	print("AUTO_HUNT_LOCAL_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_api":true}))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
