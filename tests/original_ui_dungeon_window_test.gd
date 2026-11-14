extends SceneTree
## Original 523 던전 list window (source_main_dungeon_window). Synthetic (no
## original files): the window names the client's Mission members and fails
## closed without them, maps the existing screen's categories to the original
## pages (party excluded), formats its rows, keeps only whole rows in a list,
## leaves every action to the existing dungeon screen, and the HUD opens it
## over the mounted screen with a fallback.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_dungeon_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_DUNGEON_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.ROOT=="UI/Mission/Mission_Dungeon_All.csb" and WINDOW.TAB=="UI/Mission/Mission_List_Dungeon.csb","the window is Mission_Dungeon_All with Mission_List_Dungeon tabs")
	check(WINDOW.PAGES=={"special":"Mission_Dungeon_Special","tower":"Mission_Dungeon_TrialTower","orim":"Mission_Dungeon_TracesOrim"},"특수 / 시련의 탑 / 오림의 흔적 map to their original pages")
	check(WINDOW.TIME=="UI/Mission/Mission_Popup_Time.csb" and WINDOW.TIME_ROW=="UI/Mission/Mission_List_Time.csb" and WINDOW.SPECIAL_ROW=="UI/Mission/Mission_DungeonSpecial_Btn.csb","시간 충전석 is Mission_Popup_Time; special rows are Mission_DungeonSpecial_Btn")
	check(WINDOW.OTHER.has("Mission_Dungeon_PartyDungeon") and WINDOW.OTHER.has("Mission_Dungeon_Trial") and not WINDOW.OTHER.has("Mission_Dungeon_TrialTower"),"party and the other categories are never mounted")
	check(WINDOW.FAMILY=={"tower":0,"tower_hard":1,"orim":2,"orim_hard":3,"special":4,"rechargers":5},"the families are the existing view's")
	check(WINDOW.LAYOUT_POSITION==Vector2(600.0,-337.5),"the window sits at MissionScene's Mission_Dungeon_All_Layout")
	var tabs: Array=[]
	for pair: Array in WINDOW.TABS:tabs.append(pair[0])
	check(tabs==["special","tower","orim"],"tabs follow UIDungeonCategory ViewOrder (특수, 시련), then 오림")
	var pack:=FakePack.new()
	var host:=Node.new()
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.ROOT,"the window fails closed without its CSBs")
	for member: String in WINDOW.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.scenes.erase(WINDOW.TIME_ROW)
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.TIME_ROW,"a missing row member is named")
	host.free()
	_model()
	_scroller()
	_sources()
	print("ORIGINAL_UI_DUNGEON_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _model() -> void:
	check(WINDOW.clock_text(3660)=="01시간01분" and WINDOW.clock_text(0)=="00시간00분" and WINDOW.clock_text(-5)=="00시간00분","time pools read 00시간00분")
	check(WINDOW.number_text(1234567)=="1,234,567" and WINDOW.number_text(0)=="0","costs group by thousands")
	var entry: Dictionary={"destinations":[{"place":{"name":"상아탑 4층","time_groups":[{"row":{"ID":7}},{"row":{"ID":9}}]}},{"place":{"name":"상아탑 4층","time_groups":[]}},{"place":{"name":"상아탑 5층"}}],
		"prerequisites":[{"type":"MinLevel","row":{"Value":45}},{"type":"MinLevel","row":{"Value":50}},{"type":"MaxLevel","row":{"Value":90}}]}
	check(WINDOW.special_name(entry)=="상아탑 4층 / 상아탑 5층" and WINDOW.special_name({})=="목적지 확인 필요","a special row names its destinations once")
	check(WINDOW.special_level(entry)==50,"the entry level is the highest MinLevel")
	check(WINDOW.special_groups(entry)==[7,9] and WINDOW.special_groups({}).is_empty(),"the time pools are the first destination's groups")
	var rewards: Array=[{"type":"Item","row":{"Amount":3},"item":{"row":{"ID":41},"name":"주문서"}},{"type":"Exp","row":{"Amount":900},"item":null}]
	check(WINDOW.reward_slots(rewards)==[{"class_id":41,"name":"주문서","amount":3},{"class_id":0,"name":"경험치","amount":900}],"reward rows become slots (experience has no item picture)")
	var tower: Array=[{"stage":{"ID":4,"StageIndex":1}},{"stage":{"ID":14,"StageIndex":2}},{"stage":{"ID":24,"StageIndex":3}}]
	check(WINDOW.best_floor({"4":{},"14":{}},tower)==2 and WINDOW.best_floor({},tower)==0,"최고 도달층 is the highest cleared floor of the mode")
	var chargers: Array=[{"row":0,"name":"A","owned":0},{"row":1,"name":"A","owned":2},{"row":2,"name":"B","owned":0},{"row":3,"name":"C","owned":1}]
	var listed: Array=WINDOW.recharger_list(chargers)
	check(listed.size()==3 and int(listed[0].row)==1 and int(listed[1].row)==3 and int(listed[2].row)==2,"one charger row per name, owned first")

func _scroller() -> void:
	var content:=Node2D.new()
	var rows: Array[Node2D]=[]
	for i: int in range(5):
		var row:=Node2D.new()
		content.add_child(row)
		rows.append(row)
	var scroll=WINDOW.Scroller.new()
	scroll.bind(content,rows,100.0,250.0,true)
	check(rows[0].visible and rows[1].visible and not rows[2].visible,"only whole rows inside the list show")
	check(is_equal_approx(scroll.minimum,-250.0),"the list scrolls to its last row")
	scroll.at=-100.0
	scroll._apply()
	check(not rows[0].visible and rows[1].visible and rows[2].visible and is_equal_approx(content.position.x,-100.0),"a horizontal list moves along x")
	content.free()

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("try_open_dungeon_window(view)") and hud_text.contains("_report_original_fallback(\"던전\",native)"),"던전 opens the original window over the mounted screen and reports a fallback")
	check(hud_text.contains("close_dungeon_window()") and hud_text.contains("refresh_dungeon_window()") and hud_text.contains("original_main_ui_controller.dungeon_window_is_open()"),"closing, ESC and dungeon progress reach the window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_dungeon_window","func dungeon_window_is_open","func refresh_dungeon_window","func close_dungeon_window"," or dungeon_window_is_open() or "]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_dungeon_window.gd")
	check(text.contains("bound._perform(action)") and text.contains("bound._play_action(action)") and text.contains("bound._play_action(\"begin\")"),"every action is the existing dungeon screen's")
	check(text.contains("hud.confirm_action("),"actions go through the HUD's confirmation")
	check(text.contains("\"Panel/Img_Special\":{\"visible\":false}"),"dungeon thumbnails without an original picture stay empty")
	check(not text.contains("Image.create") and not text.contains("draw_rect") and not text.contains("PartyDungeon_Btn"),"no picture is drawn and no party dungeon row is built")
	var scene_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(scene_text.contains("elif str(value.value).is_empty():") and scene_text.contains("key==\"HangulWordFind\"") and scene_text.contains("key==\"LineBreakSymbols\""),"an empty event key and the Text line-break hints need no owner")
