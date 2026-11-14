extends SceneTree
## Original 523 텔레포트 tab for 지역 이동 (source_main_teleport_window).
## Synthetic (no original files): the window names the client's Map_All /
## Map_Tab_Teleport / Map_List_Button, fails closed without them (or when the
## pack's Map_All scope lacks the frame / tab), lists the existing 지역 이동
## destinations with their level and price, and the HUD opens it before the
## TWILIGHT list. The pack keeps the world map's Android scope.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_teleport_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{},"node_scopes":{}}

class FakeWorld extends Node:
	var maps: Array=[{"id":"aden_world","name":"아덴 월드"},{"id":"oman_3","name":"오만의 탑 3층"},{"id":"gone","name":"없는 맵"}]
	var maps_by_id: Dictionary={"aden_world":{"id":"aden_world"},"oman_3":{"id":"oman_3"}}
	var active_map_id: String="aden_world"
	var level: int=30
	var gold: int=100000

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_TELEPORT_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.ALL=="UI/Map/Map_All.csb" and WINDOW.TAB=="UI/Map/Map_Tab_Teleport.csb" and WINDOW.ROW=="UI/Map/Map_List_Button.csb","the window names the client's map members")
	check(WINDOW.ROOTS==[32176,29168,9052,31108],"Map_All frame, top menu, tab bar and the teleport tab are mounted")
	var pack:=FakePack.new()
	var host:=Node.new()
	check(WINDOW.new().configure(pack,host).get("code")=="source_teleport_window_member_missing","the window fails closed without its CSBs")
	for member: String in WINDOW.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.node_scopes[WINDOW.ALL]=[35332,34904,30312,29552,29228,31656]
	var old: Dictionary=WINDOW.new().configure(pack,host)
	check(not old.get("ok",true) and old.get("member")==WINDOW.ALL,"an older pack whose Map_All scope is the world map only is reported as outdated")
	pack.manifest.node_scopes[WINDOW.ALL]=[32176,29168,9052,31108,35332]
	check(WINDOW.new().configure(pack,host).get("ok",false),"a pack with the teleport roots configures")
	host.free()
	var world:=FakeWorld.new()
	var rows: Array[Dictionary]=WINDOW.destinations(world)
	check(rows.size()==2 and rows[0].id=="aden_world" and rows[1].id=="oman_3","the destinations are the existing loaded maps")
	check(rows[1].min_level==35 and rows[1].price==2500,"level and price come from the existing teleport policy")
	world.free()
	check(WINDOW._number(1500)=="1,500","the fee is grouped like the client's amount text")
	_sources()
	print("ORIGINAL_UI_TELEPORT_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("try_open_teleport_window(get_parent())") and hud_text.contains("_report_original_fallback(\"지역 이동\",native)"),"지역 이동 opens the original tab first and reports a fallback")
	check(hud_text.contains("close_teleport_window()"),"closing the workspace closes the window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_teleport_window","func teleport_window_is_open"," or teleport_window_is_open() or "]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_teleport_window.gd")
	check(text.contains("emit_signal(\"npc_teleport_requested\"") and text.contains("POLICY.quote("),"이동하기 uses the existing quote and move")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
	var scene_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(scene_text.contains("button_options.text=title_binding"),"an authored button title can carry a live text")
	# The pack tool's scopes (tools/ui, outside the exported project) are
	# checked against a built pack by the Android world-map contract.
