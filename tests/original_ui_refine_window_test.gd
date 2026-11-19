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
	_bag_tabs()
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

class FakeWorld extends Node:
	func _find_catalog_item_record(name: String) -> Dictionary:
		return {"slot":"consumable"} if name=="가루" else {}

## 전체 / 장비 / 소모 / 기타 filter the 연금 재료 slots (the bag's own split) and
## every tab, the 기본재료 slot and the 재료 button act (none stays _ignore).
func _bag_tabs() -> void:
	var window=REFINE.new()
	var world:=FakeWorld.new()
	var materials: Array[Dictionary]=[{"kind":"target","uid":"a","name":"검","enchant":7,"item_class_id":1},{"kind":"powder","uid":"","name":"가루","amount":3,"item_class_id":2}]
	check(window._shown(world,materials).size()==2,"전체 shows every material")
	window._tab="equip"
	var equip: Array[Dictionary]=window._shown(world,materials)
	check(equip.size()==1 and equip[0].uid=="a","장비 shows the refine targets")
	window._tab="consume"
	check(window._shown(world,materials).size()==1 and window._shown(world,materials)[0].kind=="powder","소모 shows the powder by its catalog record")
	window._tab="etc"
	check(window._shown(world,materials).is_empty(),"기타 is empty here")
	window._tab="equip"
	var spec: Dictionary=window._spec({},materials,{},{},equip)
	var tab: String=REFINE.P_INV+"Tab/"
	check(spec[tab+"Btn_Equipment_On"].visible and not spec[tab+"Btn_All_On"].visible and spec[tab+"Btn_All_Off"].visible,"the current tab shows its On state")
	var bound: bool=true
	for name: String in ["Btn_All","Btn_Equipment","Btn_Consume","Btn_Etc"]:
		var callable: Variant=spec[tab+name+"_Off"].get("activate")
		bound=bound and callable is Callable and (callable as Callable).get_method()=="_set_tab"
	check(bound,"every bag tab's Off button switches the tab")
	check(spec[REFINE.P_ITEM+"Btn_Material"].activate.get_method()=="_powder_info" and spec[REFINE.P_ITEM+"Nd_Slot/Refine_Slot/Nd_Slot/Common_Slot/Btn"].activate.get_method()=="_powder_info","the 기본재료 slot and 재료 button show the powder owned")
	check(spec.has(REFINE.P_INV+"ScrollView/Inventory_Slot_Set/Nd_Slot/Slot_1/Btn") and spec[REFINE.P_INV+"ScrollView/Inventory_Slot_Set/Nd_Slot/Slot_2/Text_Amount"].visible==false,"the slot rows follow the shown tab")
	check(window._set_tab("nope").get("code")=="source_refine_window_tab_unknown","an unknown tab is refused")
	# +100 / +1000 / 직접 입력: an amount between the table's endpoints, its
	# chance on the straight line between them (TWILIGHT 근사).
	var target: Dictionary={"kind":"target","uid":"a","min":10000,"max":20000,"min_percent":"10%","max_percent":"20%","input":{"MinAmount":10000,"MaxAmount":20000,"MinProbability":100000,"MaxProbability":200000}}
	window._mode="min"
	check(window.amount_of(target)==10000 and window.percent_of(target)=="10%","최소 keeps the table's amount and chance")
	window._mode="amount:15000"
	check(window.amount_of(target)==15000 and window.percent_of(target)=="15%","an amount halfway gets the halfway chance")
	window._mode="amount:99999"
	check(window.amount_of(target)==20000,"an amount past 최대 is clamped")
	window._mode="min"
	var buttons: Dictionary=window._spec({},materials,target,{},equip)
	for name: String in ["Btn_100","Btn_1000","Btn_Input"]:
		check(buttons[REFINE.P_ALL+"Nd_ButtonSet/"+name].displaystate and str(buttons[REFINE.P_ALL+"Nd_ButtonSet/"+name].activate.get_method()) in ["_amount_step","_amount_input"],name+" registers an amount with a target")
	window._mode="amount:12000"
	var labelled: Dictionary=window._spec({},materials,target,{},equip)
	check(str(labelled[REFINE.P_ITEM+"Nd_Probability/Label"].text).contains("TWILIGHT 근사") and str(labelled[REFINE.P_ITEM+"Nd_Slot/Refine_Slot/Nd_Slot/Common_Slot/Text_Amount"].text)=="12000","the chance between the endpoints is marked TWILIGHT 근사")
	window._mode="min"
	world.free()

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
