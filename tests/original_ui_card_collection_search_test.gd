extends SceneTree
## The original card collection window's 검색 bar and 효과 button are not
## inert: the query filters by collection or member card name (phone keyboard
## on a native touch LineEdit), 효과 steps through the listed collections'
## effects back to 모든 효과, and 초기화 clears both
## (source_main_card_collection_window).
const WINDOW=preload("res://scripts/ui/original_ui/source_main_card_collection_window.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_CARD_COLLECTION_SEARCH_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var window=WINDOW.new()
	window._rows=[
		{"name":"용사의 길","grade":"일반","completed":false,"met_count":1,"requirements":[{"name":"데스나이트"}],"effects":[{"key":"str","unit":"flat","label":"힘 +1","value":1}]},
		{"name":"마법사의 탑","grade":"일반","completed":true,"met_count":2,"requirements":[{"name":"케레니스"},{"name":"Baphomet"}],"effects":[{"key":"int","unit":"flat","label":"지능 +1","value":1},{"key":"str","unit":"flat","label":"힘 +2","value":2}]},
		{"name":"사냥꾼","grade":"고급","completed":false,"met_count":0,"requirements":[{"name":"궁수"}],"effects":[{"key":"dex","unit":"flat","label":"민첩 +1","value":1}]}]
	check(window._filtered().size()==3,"no filter lists every collection")
	window.query="데스"
	check(window._filtered().size()==1 and window._filtered()[0].name=="용사의 길","a member card name finds its collection")
	window.query="baph"
	check(window._filtered().size()==1 and window._filtered()[0].name=="마법사의 탑","the query ignores letter case")
	window.query="사냥"
	check(window._filtered().size()==1,"a collection name finds it")
	window.set_query("  없는이름 ")
	check(window.query=="없는이름" and window._filtered().is_empty(),"set_query trims and filters (window closed: nothing staged)")
	window.query=""
	check(window.effect_choices()==["str:flat","int:flat","dex:flat"],"효과 choices are the listed collections' effects in order: "+str(window.effect_choices()))
	window._effect_filter()
	check(window.effect_key=="str:flat" and window._filtered().size()==2 and window._effect_title(window.effect_key)=="힘 +1","효과 selects the first effect: "+window._effect_title(window.effect_key))
	window._effect_filter()
	check(window.effect_key=="int:flat" and window._filtered().size()==1,"the next tap selects the next effect")
	window._effect_filter()
	window._effect_filter()
	check(window.effect_key=="" and window._effect_title("")=="모든 효과" and window._filtered().size()==3,"after the last effect it is 모든 효과 again")
	window.effect_key="dex:flat"
	window.query="궁"
	window.grade="고급"
	window._reset()
	check(window.query=="" and window.effect_key=="" and window.grade=="전체","초기화 clears the query and the effect")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_card_collection_window.gd")
	check(not text.contains("source_collection_search_not_connected") and not text.contains("source_collection_effect_filter_not_connected"),"no not-connected stub remains")
	check(text.contains("spec[P+\"Nd_SearchBar/Btn_Search/Text\"]") and text.contains("spec[P+\"Btn_Sort2/Enable/Text_Sort\"]"),"the bar shows the query and the button its effect in the original texts")
	print("ORIGINAL_UI_CARD_COLLECTION_SEARCH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
