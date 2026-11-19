extends SceneTree
## The original 523 대장간 window (source_main_forge_window.gd) over the
## existing 대장간 연마 feature (honing523_service). Without arguments (no
## original files): the +N text, a tap chooses a listed weapon, 연마 runs the
## quote -> confirmation -> attempt, the probability button shows the rule's
## chance, 제작 says it has no feature and the menu opens the window. Real
## input: -- --pack=<private original main UI pack directory>: Forge_All
## mounts the weapons (Inventory_Slot_Set lines), the chosen weapon and its
## material rows.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_forge_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class TestWindow extends "res://scripts/ui/original_ui/source_main_forge_window.gd":
	var calls: Array=[]
	var weapons: Array=[{"uid":"w1","label":"+9 진명황의 집행검","ok":true,"reason":"","percent":"33%","honed":false},
		{"uid":"w2","label":"+7 파멸의 대검","ok":false,"reason":"연마 재료가 부족합니다","percent":"","honed":false},
		{"uid":"w3","label":"+8 바람의 검","ok":false,"reason":"이미 연마된 무기입니다","percent":"","honed":true}]
	func candidates() -> Array:
		return weapons
	func quote(uid: String) -> Dictionary:
		calls.append(["quote",uid])
		var rule: Dictionary={"probability":330000,"costs":[{"item_class_id":1001,"amount":2},{"item_class_id":1002,"amount":1}],"epithet":{"name":"태고의"}}
		return {"ok":uid=="w1","rule":rule,"percent":"33%","reason":"" if uid=="w1" else "연마 재료가 부족합니다"}
	func attempt(uid: String) -> Dictionary:
		calls.append(["attempt",uid])
		return {"ok":true,"success":true,"detail":"대장간 연마 성공"}
	func owned(item_class_id: int) -> int:
		return 4 if item_class_id==1001 else 0
	func item_class(_uid: String) -> int:
		return 0

class FakeHud extends Node:
	var messages: Array[String]=[]
	var confirmations: Array=[]
	var logs: Array=[]
	func show_message(text: String) -> void:
		messages.append(text)
	func append_log(text: String) -> void:
		logs.append(text)
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		confirmations.append([title,body,action])
		callback.call(1)
		return null

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=Node.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	return {"world":world,"hud":hud}

func _run() -> void:
	check(WINDOW.enchant_text("+9 진명황의 집행검")=="+9" and WINDOW.enchant_text("이름")=="","+N of a weapon label")
	var host: Dictionary=_host()
	var window:=TestWindow.new()
	window._hud=weakref(host.hud)
	window._weapons=window.candidates()
	window._pressed(1)
	check(window.selected=="w2" and host.hud.messages[-1]=="연마 재료가 부족합니다","a weapon the service refuses is chosen with its reason")
	window._pressed(1)
	check(window.selected=="","a second tap clears the choice")
	check(not window._hone().get("ok",true) and host.hud.messages[-1]=="연마할 무기를 고르세요","no weapon: nothing runs")
	window._pressed(0)
	window._probability()
	check(host.hud.messages[-1].begins_with("연마 성공 확률 33%") and host.hud.messages[-1].contains("태고의"),"확률 shows the original rule's chance: "+host.hud.messages[-1])
	window._hone()
	check(window.calls[-1]==["attempt","w1"] and host.hud.confirmations[-1][1].contains("성공 확률 33%") and host.hud.logs[-1]=="대장간 연마 성공","연마 confirms and runs the attempt: "+str(window.calls.slice(-2)))
	window._craft_missing()
	check(host.hud.messages[-1].contains("제작"),"제작 has no TWILIGHT feature")
	# Bag tabs: every candidate is a weapon; 소모 / 기타 list nothing and keep the choice.
	window.selected="w1"
	window.bag_tab="consume"
	var spec: Dictionary=window._spec()
	check(window._weapons.is_empty() and window.selected=="w1" and str(window._current().get("uid",""))=="w1","소모 lists no weapon and keeps the chosen one")
	check(spec[WINDOW.P_INV+"Tab/Btn_Consume_On"].visible and spec[WINDOW.P_INV+"Tab/Btn_All_Off"].visible and not spec[WINDOW.P_INV+"Tab/Btn_All_On"].visible,"the current bag tab shows its On state")
	var tabs_bound: bool=true
	for name: String in ["Btn_All","Btn_Equipment","Btn_Consume","Btn_Etc"]:
		var callable: Variant=spec[WINDOW.P_INV+"Tab/"+name+"_Off"].get("activate")
		tabs_bound=tabs_bound and callable is Callable and (callable as Callable).get_method()=="_set_bag_tab"
	check(tabs_bound,"every bag tab's Off button switches the tab")
	window.bag_tab="equip"
	window._spec()
	check(window._weapons.size()==3,"장비 lists every weapon")
	check(window._set_bag_tab("nope").get("code")=="source_forge_window_tab_unknown","an unknown tab is refused")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("[\"forge523\",\"대장간\"]") and renewal.contains("_open_original_feature(\"forge\")"),"the menu opens the original window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_FORGE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host: Dictionary=_host()
	var parent:=Node2D.new()
	root.add_child(parent)
	var window:=TestWindow.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent)
	check(opened.get("handled",false) and int(opened.filled.weapons)==3 and int(opened.filled.lines)==1,"Forge_All mounts the weapons: "+str(opened).left(300))
	var chosen: Dictionary=window._pressed(0)
	check(chosen.get("handled",false) and chosen.filled.selected=="w1" and int(chosen.filled.materials)==2,"the chosen weapon mounts with its material rows: "+str(chosen).left(300))
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
