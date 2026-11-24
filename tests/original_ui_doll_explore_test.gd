extends SceneTree
## User list 2026-11-21 #10: 인형 탐험 as the original 523 마법인형 탐험 page
## (Change_WinTotal + Change_ExploreView), reusing the 변신 파견 window for
## MagicDollExpedition deck 2 (one doll per spot). Synthetic (no original
## files): the window is registered, names its original members, fails
## closed without them, keeps deck 2 / the explore page / its spot and card
## state nodes, selects one doll at a time, and the 인형 탐험 menu tile, the
## 마법인형 탐험 tab and the HUD open it first (no unrelated screen substituted).
const EXPLORE=preload("res://scripts/ui/original_ui/source_main_doll_explore_window.gd")
const DISPATCH=preload("res://scripts/ui/original_ui/source_main_card_dispatch_window.gd")
const HUD_CONTROLLER=preload("res://scripts/ui/original_ui/source_main_hud.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}
	func scene(_member: String) -> Dictionary:return {}

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_DOLL_EXPLORE_FAIL: ",label)

func _initialize() -> void:
	check(HUD_CONTROLLER.FEATURE_WINDOWS.get("doll_explore")==EXPLORE,"doll_explore is a registered feature window")
	var window=EXPLORE.new()
	check(window.deck==2 and DISPATCH.new().deck==1,"마법인형 deck 2; the 변신 파견 window keeps deck 1")
	check(window._page()=="Change_ExploreView" and window._tab()=="explore" and window._p()=="Change_ExploreView/Nd_Explore/" and window._spot_member()=="UI/Change/Change_Explore_Btn.csb","the explore page, its prefix and spot button")
	var members: Array[String]=window.required_members()
	for member: String in ["UI/Change/Change_Explore_Btn.csb","UI/Change/Change_Card_A_Explore.csb","UI/Change/Change_Popup_Explore_Set.csb","UI/Change/Change_Popup_Explore_Info.csb","UI/Change/Change_List_Explore_Buff.csb"]:
		check(members.has(member),"requires "+member)
	var hud:=FakeHud.new()
	root.add_child(hud)
	var configured: Dictionary=EXPLORE.new().configure(FakePack.new(),hud)
	check(not configured.get("ok",true),"fails closed without the original members")
	var idle: Dictionary=window._spot_spec({"ID":7,"Name":"말하는 섬"},{})
	check(idle["Panel_Spot/Btn_Spot"].visible==true and idle["Panel_Spot/Btn_Explore"].visible==false and idle["Btn_Spot/Label"].text=="말하는 섬","an idle spot shows Btn_Spot with its name")
	var running: Dictionary=window._spot_spec({"ID":7,"Name":"말하는 섬"},{"status":"running"})
	check(running["Panel_Spot/Btn_Explore"].visible==true and running["Btn_Explore/Nd_Title/Label_Spot"].text=="말하는 섬" and running["Btn_Explore/CardSample"].get("exclude",false),"a running spot shows 탐험 중")
	check(EXPLORE.DOLL_DECK==2,"the doll deck constant")
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_doll_explore_window.gd")
	check(source.contains("party.clear()\n\t\tparty.append(identity)"),"a tap selects one doll (the previous one is replaced)")
	hud.queue_free()
	print("ORIGINAL_UI_DOLL_EXPLORE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
