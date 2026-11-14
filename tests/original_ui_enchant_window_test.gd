extends SceneTree
## Original 523 장비 강화 window (source_main_enchant_window). Synthetic (no
## original files): the window names the exact client CSBs and fails closed
## without them, its texts come from the existing candidate fields, the HUD
## opens it before the TWILIGHT forge (and reports the fallback), and the
## 강화 시작 button asks through the forge's existing confirmation.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_enchant_window.gd")
const FORGE=preload("res://scripts/ui/renewal_forge.gd")
const ENCHANT=preload("res://scripts/original_enhancement.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeController extends Node:
	var handles: bool=true
	var opened: Array=[]
	func try_open_enchant_window(scroll: String, candidates: Array) -> Dictionary:
		opened.append([scroll,candidates.size()])
		return {"ok":handles,"handled":handles} if handles else {"ok":false,"handled":false,"code":"source_enchant_window_member_missing"}

class ConfirmHost extends Node:
	signal enhancement_requested(scroll_name: String, target_name: String)
	var asked: Array=[]
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		asked.append([title,body,action])
		callback.call(1)
		return null

class RoutingHud extends "res://scripts/ui/renewal_hud.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _sync_screen_focus() -> void:pass
	func _open_window(section: String, _title: String, _description: String) -> void:
		active_section=section
		workspace.show()
	var messages: Array[String]=[]
	func show_message(text: String) -> void:messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_ENCHANT_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.ROOT=="UI/EnchantScene.csb" and WINDOW.ALL=="UI/FloatingUi/Enchant_All.csb" and WINDOW.INVENTORY=="UI/FloatingUi/Enchant_Inventory.csb" and WINDOW.TEXT_SET=="UI/FloatingUi/Enchant_Text_Set.csb","the window names the client's EnchantScene members")
	check(WINDOW.REQUIRED.has("UI/FloatingUi/Inventory_Slot_Set.csb") and WINDOW.REQUIRED.has("UI/CommonUi/Common_Slot.csb"),"the bag rows are the original Inventory_Slot_Set / Common_Slot")
	var pack:=FakePack.new()
	var host:=Node.new()
	var configured: Dictionary=WINDOW.new().configure(pack,host)
	check(not configured.get("ok",true) and configured.get("code")=="source_enchant_window_member_missing" and configured.get("member")==WINDOW.ROOT,"the window fails closed without its CSBs")
	for member: String in WINDOW.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.scenes.erase(WINDOW.TEXT_SET)
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.TEXT_SET,"a missing nested member is named")
	host.free()
	_texts()
	_confirmation()
	_hud_routing()
	_sources()
	print("ORIGINAL_UI_ENCHANT_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _texts() -> void:
	check(WINDOW._title({"name":"마법 지팡이","level":11})=="+11 마법 지팡이를 강화 하시겠습니까?","the title follows the client's authored sentence")
	check(WINDOW._title({"name":"장검 · 원본#702","level":7})=="+7 장검을 강화 하시겠습니까?","a final consonant takes 을 and the source id suffix is not shown")
	check(WINDOW._title({"name":"단검","level":0})=="단검을 강화 하시겠습니까?","+0 shows no level")
	var window=WINDOW.new()
	var rows: Array[Dictionary]=window._stat_rows({"stats_now":{"damage":3,"accuracy":3,"mr":0},"stats_next":{"damage":4,"accuracy":4,"mr":0}})
	check(rows.size()==2 and rows[0].label==ENCHANT.stat_label("damage") and rows[0].now=="3" and rows[0].next=="4(+1)","stat rows show the current and the success value")
	var defense: Array[Dictionary]=window._stat_rows({"stats_now":{"defense":2},"stats_next":{"defense":3}})
	check(defense.size()==1 and defense[0].label=="AC" and defense[0].now=="-2" and defense[0].next=="-3(-1)","AC is shown as the negative value")
	check(window._stat_rows({}).is_empty(),"no stat fields -> no rows")
	check(ENCHANT.stat_label("damage")=="추가 대미지" and ENCHANT.stat_values("weapon",3).get("damage")==3,"stat labels and values come from original_enhancement")
	check(ENCHANT.summary("weapon",3).contains("추가 대미지 +3.00") and ENCHANT.summary("weapon",3).contains("명중 +3.00"),"the enhancement summary text is unchanged")
	check(WINDOW._number(1000)=="1,000" and WINDOW._number(0)=="0","the fee is grouped like the client's amount text")

func _confirmation() -> void:
	var host:=ConfirmHost.new()
	var emitted: Array=[]
	host.enhancement_requested.connect(func(scroll: String, target: String) -> void: emitted.append([scroll,target]))
	var entry: Dictionary={"name":"장검","level":2,"target_id":"장검@@@abc","count":1,"cost":1000,"success_chance":50.0,"decrease_chance":0.0,"destroy_chance":10.0}
	check(FORGE.confirm_target(host,"무기 마법 주문서",entry),"the forge confirmation accepts the target")
	check(host.asked.size()==1 and host.asked[0][0]=="강화 확인" and str(host.asked[0][1]).contains("장검 +2"),"강화 시작 asks through the existing 강화 확인")
	check(emitted==[["무기 마법 주문서","장검@@@abc"]],"accepting emits the existing enhancement request")
	check(not FORGE.confirm_target(host,"무기 마법 주문서",{}) and host.asked.size()==1,"an entry without a target is not asked")
	host.free()

func _hud_routing() -> void:
	var instance: Node=preload("res://scenes/ui/HUD.tscn").instantiate()
	instance.set_script(RoutingHud)
	var hud: RoutingHud=instance as RoutingHud
	hud.workspace=PanelContainer.new()
	hud.get_node("Root").add_child(hud.workspace)
	var controller:=FakeController.new()
	hud.add_child(controller)
	hud.original_main_ui_controller=controller
	check(hud._open_original_enchant("무기 마법 주문서",[{"target_id":"a"}]),"the original window is tried first")
	check(controller.opened==[["무기 마법 주문서",1]] and not hud.workspace.visible,"the candidates reach the original window and the workspace hides")
	check(hud.original_main_ui_status.get("enchant_window",{}).get("handled",false),"the original window status is recorded")
	controller.handles=false
	hud.workspace.show()
	check(not hud._open_original_enchant("무기 마법 주문서",[]),"without the window the TWILIGHT forge stays the fallback")
	check(hud.messages.size()==1 and hud.messages[0].begins_with("장비 강화") and hud.messages[0].contains("UI 추가 리소스가 오래되었습니다"),"the fallback is told to the player (outdated add-on)")
	hud.original_main_ui_controller=null
	check(not hud._open_original_enchant("무기 마법 주문서",[]) and hud.messages.size()==1,"without the original UI controller nothing is reported")
	hud.free()

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("if _open_original_enchant(scroll_name,candidates): return") and hud_text.contains("if _open_original_enchant(\"\",[]): return"),"the enhancement window and the scroll chooser open the original window first")
	check(hud_text.contains("close_enchant_window()"),"closing the workspace closes the original enchant window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_enchant_window","func enchant_window_is_open","func close_enchant_window"]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var world_text: String=FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world_text.contains("\"stats_now\": ENCHANT.stat_values") and world_text.contains("\"stats_next\": ENCHANT.stat_values"),"the candidates carry the numbers behind bonus_text")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_enchant_window.gd")
	check(not text.contains("Image.create") and not text.contains("ImageTexture.create_from_image") and not text.contains("draw_rect"),"no picture is drawn in the enchant window")
	check(text.contains("Forge.confirm_target(") and text.contains("inventory_item_activated.emit"),"강화 시작 and the 주문서 tab use the existing owners")
