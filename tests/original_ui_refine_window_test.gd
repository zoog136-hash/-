extends SceneTree
## Original 523 질서의 연금 window (source_main_refine_window) and 용해
## confirmation (source_main_dissolve_popup). Synthetic (no original files):
## the windows name the exact client CSBs and fail closed when the pack lacks
## them, the HUD routes 질서의 연금 to the original window first and falls back
## to the existing 용해·질서의 연금 panel, and the panel asks through the
## original confirmation only when the controller handles it.
const REFINE=preload("res://scripts/ui/original_ui/source_main_refine_window.gd")
const DISSOLVE=preload("res://scripts/ui/original_ui/source_main_dissolve_popup.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeController extends Node:
	var handles: bool=true
	var refine_opened: int=0
	func try_open_refine_window(_world: Node) -> Dictionary:
		refine_opened+=1
		return {"ok":handles,"handled":handles}

class RoutingHud extends "res://scripts/ui/renewal_hud.gd":
	var fallback_opened: int=0
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _sync_screen_focus() -> void:pass
	func _open_window(section: String, _title: String, _description: String) -> void:
		active_section=section
		workspace.show()
	func open_bless_refine523() -> void:fallback_opened+=1
	var messages: Array[String]=[]
	func show_message(text: String) -> void:messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_REFINE_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(REFINE.ROOT=="UI/RefineScene.csb" and REFINE.ALL=="UI/Refine/Refine_All.csb" and REFINE.ITEM=="UI/Refine/Refine_Item.csb" and REFINE.INVENTORY=="UI/Refine/Refine_Inventory.csb","the refine window names the client's RefineScene members")
	check(REFINE.REQUIRED.has("UI/FloatingUi/Inventory_Slot_Set.csb") and REFINE.REQUIRED.has("UI/CommonUi/Common_Slot.csb"),"the bag rows are the original Inventory_Slot_Set / Common_Slot")
	check(DISSOLVE.ROOT=="UI/CommonUi/Common_MessageBox_Dissolution.csb","the dissolve confirmation is Common_MessageBox_Dissolution")
	var pack:=FakePack.new()
	var host:=Node.new()
	var refine: Dictionary=REFINE.new().configure(pack,host)
	check(not refine.get("ok",true) and refine.get("code")=="source_refine_window_member_missing" and refine.get("member")==REFINE.ROOT,"the refine window fails closed without its CSBs")
	var dissolve: Dictionary=DISSOLVE.new().configure(pack)
	check(not dissolve.get("ok",true) and dissolve.get("code")=="source_dissolve_popup_member_missing","the dissolve popup fails closed without its CSB")
	for member: String in REFINE.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.scenes.erase("UI/FloatingUi/Inventory_Slot_Set.csb")
	check(REFINE.new().configure(pack,host).get("member")=="UI/FloatingUi/Inventory_Slot_Set.csb","a missing nested member is named")
	host.free()
	check(REFINE._number(100000)=="100,000" and REFINE._number(0)=="0" and REFINE._number(1234567)=="1,234,567","the Adena cost is grouped like the client's amount text")
	_hud_routing()
	_sources()
	print("ORIGINAL_UI_REFINE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _hud_routing() -> void:
	# The actual HUD scene with only its window chrome replaced by counters.
	var instance: Node=preload("res://scenes/ui/HUD.tscn").instantiate()
	instance.set_script(RoutingHud)
	var hud: RoutingHud=instance as RoutingHud
	hud.workspace=PanelContainer.new()
	hud.get_node("Root").add_child(hud.workspace)
	var controller:=FakeController.new()
	hud.add_child(controller)
	hud.original_main_ui_controller=controller
	hud.open_refine523()
	check(controller.refine_opened==1 and hud.fallback_opened==0 and not hud.workspace.visible,"질서의 연금 opens the original window and hides the workspace")
	check(hud.original_main_ui_status.get("refine_window",{}).get("handled",false),"the original window status is recorded")
	controller.handles=false
	hud.open_refine523()
	check(controller.refine_opened==2 and hud.fallback_opened==1,"without the original window the existing 용해·질서의 연금 panel opens")
	check(hud.messages.size()==1 and hud.messages[0].begins_with("질서의 연금"),"the fallback is told to the player")
	hud.original_main_ui_controller=null
	hud.open_refine523()
	check(hud.fallback_opened==2,"without the original UI controller the panel opens")
	hud.free()

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("\"refine523\": open_refine523()") and hud_text.contains("[\"refine523\",\"질서의 연금\"]"),"the menu lists 질서의 연금 and navigates to it")
	check(hud_text.contains("close_refine_window()") and hud_text.contains("close_dissolve_confirm()"),"closing the workspace closes the original refine window and confirmation")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_refine_window","func refine_window_is_open","func try_open_dissolve_confirm","func dissolve_confirm_is_open"]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var panel_text: String=FileAccess.get_file_as_string("res://scripts/refine523/bless_refine523_panel.gd")
	check(panel_text.contains("try_open_dissolve_confirm") and panel_text.contains("SERVICE.dissolve(world(),ids)"),"용해 asks through the original confirmation and keeps the direct path without it")
	for path: String in ["res://scripts/ui/original_ui/source_main_refine_window.gd","res://scripts/ui/original_ui/source_main_dissolve_popup.gd"]:
		var text: String=FileAccess.get_file_as_string(path)
		check(not text.contains("Image.create") and not text.contains("ImageTexture.create_from_image") and not text.contains("draw_rect"),"no picture is drawn in "+path.get_file())
