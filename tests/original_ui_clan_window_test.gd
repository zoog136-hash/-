extends SceneTree
## Original 523 혈맹 (source_main_clan_window). Synthetic (no original files):
## the window names the client's Clan members and fails closed without them,
## the 주간 기부 보상 list scrolls and hides rows outside it, numbers group like
## the client, the HUD opens it before the TWILIGHT panel. Also the bag rule:
## a single tap in the original bag keeps TWILIGHT's floating item name.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_clan_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_CLAN_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.ALL=="UI/Clan/Clan_All.csb" and WINDOW.FOUNDATION=="UI/Clan/Clan_Tab_Foundation.csb" and WINDOW.INFO=="UI/Clan/Clan_Tab_Join_Info.csb" and WINDOW.DONATE=="UI/Clan/Clan_Popup_Join_Donate.csb","the window names the client's clan members")
	check(WINDOW.LAYOUT_POSITION==Vector2(600.0,-337.5),"the window sits at ClanScene's Clan_WinTotal_Layout")
	var pack:=FakePack.new()
	var host:=Node.new()
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.ALL,"the window fails closed without its CSBs")
	for member: String in WINDOW.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.scenes.erase(WINDOW.WEEKLY_ROW)
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.WEEKLY_ROW,"a missing weekly row member is named")
	pack.manifest.scenes[WINDOW.WEEKLY_ROW]={}
	check(WINDOW.new().configure(pack,host).get("ok",false),"all members -> configured")
	host.free()
	check(WINDOW._number(0)=="0" and WINDOW._number(999)=="999" and WINDOW._number(200000)=="200,000" and WINDOW._number(1234567)=="1,234,567","numbers group by thousands")
	check(WINDOW.POINT_OFF_FRAME==0.0 and WINDOW.POINT_COMPLETE_FRAME==135.0,"point slots use their Off / Complete clips")
	_weekly()
	_sources()
	print("ORIGINAL_UI_CLAN_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _weekly() -> void:
	var window=WINDOW.new()
	var scroll: RefCounted=window.weekly_scroll()
	var content:=Node2D.new()
	root.add_child(content)
	var rows: Array[Node2D]=[]
	for index: int in 6:
		var row:=Node2D.new()
		content.add_child(row)
		rows.append(row)
	scroll.bind(content,rows,110.0,300.0)
	check(scroll.minimum==-360.0 and content.position.y==0.0,"six 110 px rows in a 300 px list scroll by 360 px")
	check(scroll.visible_rows()==3 and rows[0].visible and rows[2].visible and not rows[3].visible,"rows below the list are hidden")
	var drag:=InputEventScreenDrag.new()
	drag.relative=Vector2(0.0,-1000.0)
	scroll.input(drag)
	check(scroll.y==-360.0 and content.position.y==-360.0,"a drag is clamped to the last row")
	check(not rows[0].visible and not rows[2].visible and rows[3].visible and rows[5].visible,"scrolled rows show, rows above hide")
	scroll.scroll_to(50.0)
	check(scroll.y==0.0 and rows[0].visible,"scrolling past the top stops at the first row")
	content.free()

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("try_open_clan_window(get_parent())") and hud_text.contains("_report_original_fallback(\"혈맹\",native)"),"혈맹 opens the original window first and reports a fallback")
	check(hud_text.contains("close_clan_window()") and hud_text.contains("clan_window_is_open()"),"ESC and closing the workspace close the window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_clan_window","func clan_window_is_open","func close_clan_window"]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var scene_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(scene_text.contains("elif key==\"textid\":"),"the clan tabs' textid property is kept as metadata")
	check(scene_text.contains("(event as Dictionary).keys()==[\"EventSound\"]"),"a sound-only frame event keeps its node")
	check(scene_text.contains("if not _whole(alpha) or int(alpha)<0"),"a whole-number float opacity is the original opacity")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_clan_window.gd")
	check(text.contains("clan523") or text.contains("Clan."),"rules stay in the clan523 runtime")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
	# Bag: one tap keeps TWILIGHT's floating name over the tapped original slot.
	check(main_text.contains("if _inventory_name_view!=null and _inventory_name_view.is_open():_inventory_name_view.close()") and not main_text.contains("_inventory_name_view.refresh(_coordinates)"),"the original bag does not mount the ToolTip name header")
	check(main_text.contains("context[\"host\"]=canvas"),"the original bag hands its canvas to the bag's name label")
	var bag_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_inventory.gd")
	check(bag_text.contains("_host_item_name(native.get(\"host\") as Control if native_active else self)"),"the bag's own item name is placed over the original slot")
	check(bag_text.contains("item_name_hint.reparent(host,false)") and bag_text.contains("NOTIFICATION_PREDELETE"),"the name label moves to the HUD canvas and is freed with the bag")
