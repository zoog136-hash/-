extends SceneTree
## 비법서 제작 entry of the original 523 제작 window (TWILIGHT 근사): the
## original Production_All has no GachaCraft entry, so its 이벤트 tab (named
## 비법서 제작) opens the existing crafting screen with the 비법서 제작 panel.
const PRODUCTION=preload("res://scripts/ui/original_ui/source_main_production_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var opened: int=0
	func open_gacha_craft523() -> void:
		opened+=1

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var window=PRODUCTION.new()
	window._hud=weakref(hud)
	var routed: Dictionary=window._open_gacha()
	check(routed.get("routed","")=="open_gacha_craft523" and hud.opened==1,"the 이벤트 tab routes to the 비법서 제작 screen")
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_production_window.gd")
	check(source.contains("\"Nd_TabMenu/Btn_Event_Off/Label\"]={\"role\":\"source_text\",\"text\":\"비법서 제작\"}") and source.contains("if world.has_method(\"patch523_gacha_craft_owned\"):"),"the 이벤트 tab is named 비법서 제작 when the world has it")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("func open_gacha_craft523(") and renewal.contains("screen.show_gacha_books(book_id,book_uid)"),"the HUD opens the crafting screen with the chosen book")
	hud.queue_free()
	print("ORIGINAL_UI_GACHA_ENTRY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
