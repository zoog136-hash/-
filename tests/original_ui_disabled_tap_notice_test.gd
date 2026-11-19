extends SceneTree
## Original buttons drawn disabled because a condition is not met still answer
## a tap with the reason (displaystate is a look, not a lock): 장비 강화
## 강 화 시 작, the 사망 복구 recovery buttons and an unsupported 파견 buff.
const ENCHANT=preload("res://scripts/ui/original_ui/source_main_enchant_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_DISABLED_TAP_NOTICE_FAIL: ",label)

func _initialize() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var window=ENCHANT.new()
	window._hud=weakref(hud)
	var result: Dictionary=window._enchant_requested()
	check(not result.get("ok",true) and hud.messages==["강화할 장비를 고르세요"],"강 화 시 작 without a target says so: "+str(hud.messages))
	var death: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_death_window.gd")
	check(death.contains("\"지금은 복구할 수 없습니다\"") and death.contains("\"복구할 수 있는 아이템이 없습니다\""),"a refused recovery always says why")
	var dispatch=preload("res://scripts/ui/original_ui/source_main_card_dispatch_window.gd").new()
	dispatch._hud=weakref(hud)
	check(dispatch._buff_unsupported().get("code")=="card_dispatch_buff_unsupported" and hud.messages[-1]=="이 파견 버프는 TWILIGHT에서 지원하지 않습니다","an unsupported 파견 buff says so instead of being picked")
	hud.free()
	print("ORIGINAL_UI_DISABLED_TAP_NOTICE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
