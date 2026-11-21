extends SceneTree
## Reward slots of the original 퀘스트 (Quest_Slot_Set), 미션 (Common_Slim_ItemSlot)
## and 지배석 퀘스트 windows were inert buttons (UI audit 2026-11-21). A tap now
## opens the original item information popup of the reward through the HUD's
## original controller (try_open_item_tooltip, as a bag item does); a second
## tap on the same reward closes it, and the popup closes with its window.
## Synthetic (no original files).
const INFO = preload("res://scripts/ui/original_ui/source_reward_item_info.gd")
var checks: int = 0
var failures: Array[String] = []

class FakePopup extends RefCounted:
	var reference: String = ""

class FakeController extends Node:
	var popup := FakePopup.new()
	var open: bool = false
	var calls: Array = []
	func try_open_item_tooltip(reference: String, title: String, item_class_id: int, grade_id: int, record: Dictionary = {}) -> Dictionary:
		calls.append([reference, title, item_class_id, grade_id, record.get("name", "")])
		popup.reference = reference
		open = true
		return {"ok":true,"handled":true,"title":title}
	func item_tooltip_is_open() -> bool: return open
	func item_tooltip() -> RefCounted: return popup
	func close_item_tooltip() -> void:
		open = false
		popup.reference = ""

class FakeWorld extends Node:
	func _catalog_item_from_source_id(source_id: String) -> Dictionary:
		if source_id == "m523:item:40308": return {"name":"아데나","source_item_class_id":40308,"source_grade_id":1,"source_display_name":"아데나"}
		return {}

class FakeHud extends Node:
	var original_main_ui_controller: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_REWARD_ITEM_INFO_FAIL: ", label)

func _initialize() -> void:
	var world := FakeWorld.new()
	var hud := FakeHud.new()
	var controller := FakeController.new()
	hud.original_main_ui_controller = controller
	world.add_child(hud)
	hud.add_child(controller)
	root.add_child(world)
	check(INFO.record_of(world, 40308).get("name") == "아데나" and INFO.record_of(world, 0).is_empty(), "the reward's catalog record by its original ItemClass")
	var opened: Dictionary = INFO.toggle(hud, 40308)
	check(opened.get("ok", false) and controller.calls.size() == 1 and controller.calls[0][2] == 40308 and controller.calls[0][3] == 1 and str(controller.calls[0][1]).length() > 0, "a reward tap opens the original item popup: " + str(controller.calls))
	var closed: Dictionary = INFO.toggle(hud, 40308)
	check(closed.get("closed", false) and not controller.open and controller.calls.size() == 1, "a second tap on the same reward closes it")
	check(not INFO.toggle(hud, 0).get("ok", true) and not INFO.toggle(null, 40308).get("ok", true), "no reward or no HUD: nothing opens")
	var quest: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_quest_window.gd")
	check(quest.contains("common[SLOT_BUTTON]={\"role\":\"button\",\"activate\":Callable(self,\"_reward_info\")"), "퀘스트 reward slots are bound")
	var routine: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_routine_page.gd")
	check(routine.contains("spec[prefix+\"Btn\"]={\"activate\":Callable(self,\"_reward_info\").bind(item_class)}") and not routine.contains("목표 미연결"), "미션 reward slots are bound, no developer words")
	var stone: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_domination_stone_window.gd")
	check(stone.contains("Quest_Slot_Set/Slot_%d/Btn\" % index]={\"activate\":Callable(self,\"_reward_info\")"), "지배석 퀘스트 reward slots are bound")
	var hud_text: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.count("original_main_ui_controller.close_item_tooltip()") >= 2, "the popup closes when its window closes or another opens")
	world.queue_free()
	print("ORIGINAL_UI_REWARD_ITEM_INFO_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
