extends SceneTree
## The 제작 tab dispatches to the spellbook owner and respects its refusal
## when the selected original UI has no matching scene.
const PRODUCTION=preload("res://scripts/ui/original_ui/source_main_production_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var opened: int=0
	var accepts: bool=false
	func open_gacha_craft523() -> bool:
		opened+=1
		return accepts

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
	var blocked: Dictionary=window._open_gacha()
	check(blocked.get("code")=="source_gacha_craft_window_unavailable" and hud.opened==1,"the 이벤트 tab respects a missing original scene")
	hud.accepts=true
	var routed: Dictionary=window._open_gacha()
	check(routed.get("routed","")=="open_gacha_craft523" and hud.opened==2,"the 이벤트 tab reports an opening only if its owner accepts it")
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_production_window.gd")
	check(source.contains("\"Nd_TabMenu/Btn_Event_Off/Label\"]={\"role\":\"source_text\",\"text\":\"비법서 제작\"}") and source.contains("if world.has_method(\"patch523_gacha_craft_owned\"):"),"the 이벤트 tab is named 비법서 제작 when the world has it")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("source_gacha_craft_window_unavailable") and renewal.contains("screen.show_gacha_books(book_id,book_uid)"),"the HUD preserves the offline book owner's input and refuses a missing selected scene")
	hud.queue_free()
	print("ORIGINAL_UI_GACHA_ENTRY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
