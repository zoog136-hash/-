extends SceneTree
## A touch on an open TWILIGHT window (menu/workspace) must not reach the
## original HUD chrome button drawn beneath it (menu open + tap → AUTO).
## Synthetic: a chrome button covered by a visible workspace stops taking the
## pointer, an uncovered one, an original window (z >= 140) and a
## workspace-attached control (absolute z) keep it, and closing the workspace
## restores the covered button.
const HUD_SCRIPT=preload("res://scripts/ui/original_ui/source_main_hud.gd")
const BUTTON=preload("res://scripts/ui/original_ui/source_button.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var workspace: Control
	var detail_window: Control
	var companion_window: Control

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_CHROME_INPUT_BLOCK_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _button(parent: Node2D, rect: Rect2) -> Control:
	var holder:=Node2D.new()
	parent.add_child(holder)
	var button=BUTTON.new()
	holder.add_child(button)
	holder.set_meta("source_button",button)
	var area:=Control.new()
	area.position=rect.position
	area.size=rect.size
	area.mouse_filter=Control.MOUSE_FILTER_STOP
	holder.add_child(area)
	button.set("_input_area",area)
	return area

func _run() -> void:
	var canvas:=Control.new()
	canvas.size=Vector2(1280,720)
	root.add_child(canvas)
	var hud:=FakeHud.new()
	root.add_child(hud)
	hud.workspace=Control.new()
	hud.workspace.position=Vector2(800,80)
	hud.workspace.size=Vector2(460,600)
	canvas.add_child(hud.workspace)
	var controller=HUD_SCRIPT.new()
	var coordinates:=Node2D.new()
	canvas.add_child(coordinates)
	controller.set("_coordinates",coordinates)
	controller.set("_hud",weakref(hud))
	var chrome:=Node2D.new()
	coordinates.add_child(chrome)
	var auto_area: Control=_button(chrome,Rect2(1045,469,101,101))
	var menu_area: Control=_button(chrome,Rect2(1204,0,78,78))
	var window:=Node2D.new()
	window.z_index=150
	coordinates.add_child(window)
	var window_area: Control=_button(window,Rect2(900,300,100,40))
	var attached:=Node2D.new()
	attached.z_as_relative=false
	attached.z_index=1
	coordinates.add_child(attached)
	var attached_area: Control=_button(attached,Rect2(900,400,100,40))
	controller.call("_sync_chrome_input_block",hud)
	check(auto_area.mouse_filter==Control.MOUSE_FILTER_IGNORE,"the chrome AUTO button under the open workspace stops taking the pointer")
	check(menu_area.mouse_filter==Control.MOUSE_FILTER_STOP,"the uncovered menu button keeps its input")
	check(window_area.mouse_filter==Control.MOUSE_FILTER_STOP,"an original window above the workspace keeps its input")
	check(attached_area.mouse_filter==Control.MOUSE_FILTER_STOP,"a workspace-attached original control keeps its input")
	check(int(controller.get("chrome_blocked_buttons"))==1,"one chrome button is blocked")
	hud.workspace.hide()
	controller.call("_sync_chrome_input_block",hud)
	check(auto_area.mouse_filter==Control.MOUSE_FILTER_STOP and not auto_area.has_meta("chrome_block_filter"),"closing the workspace restores the AUTO button")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(text.contains("class ChromeInputSync") and text.contains("_coordinates.add_child(input_sync)"),"every press syncs the block before the GUI delivers it")
	controller.free()
	print("ORIGINAL_UI_CHROME_INPUT_BLOCK_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
