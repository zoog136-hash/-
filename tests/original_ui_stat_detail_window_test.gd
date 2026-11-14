extends SceneTree
## Original 523 상세 능력치 (source_main_stat_detail_window). Synthetic (no
## original files): the window names the client's CharacterInfo_StatInfo_Detail
## members and fails closed without them, groups the status sheet's values
## into STR / DEX / CON / INT / WIS cards and an ETC card with the sheet's
## labels and number text, and the HUD opens it before the TWILIGHT sheet.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_stat_detail_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_STAT_DETAIL_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.ROOT=="UI/FloatingUi/CharacterInfo_StatInfo_Detail.csb" and WINDOW.CARD=="UI/FloatingUi/CharacterInfo_StatInfo_Detail_List.csb" and WINDOW.LINE=="UI/FloatingUi/CharacterInfo_StatInfo_Detail_Text.csb","the window names the client's stat detail members")
	check(WINDOW.LAYOUT_POSITION==Vector2(766.0,-345.0),"the window sits at FloatingUiScene's CharacterInfo_StatInfo_Detail_Layout")
	var pack:=FakePack.new()
	var host:=Node.new()
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.ROOT,"the window fails closed without its CSBs")
	for member: String in WINDOW.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.scenes.erase(WINDOW.LINE)
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.LINE,"a missing line member is named")
	host.free()
	var model: Dictionary=WINDOW.groups({"melee_damage":12,"melee_critical":3,"max_hp":500,"ac":-5,"attack_interval":0.75,"stun_resistance":4})
	var left: Array=model.left
	check(left.size()==3 and left[0].code=="STR" and left[1].code=="DEX" and left[2].code=="CON","only the attributes with values get a card, in STR DEX CON INT WIS order")
	check(left[0].rows==[["근거리 대미지","12"],["근거리 치명타","3%"]],"lines use the sheet's labels and number text")
	check(left[1].rows==[["물리 방어력 (AC)","-5"]],"AC is listed under DEX like the sheet")
	var right: Array=model.right
	check(right.size()==1 and right[0].code=="ETC" and right[0].rows==[["공격 간격","0.8초"],["스턴 내성","4"]],"the other statistics form the ETC card in the sheet's order")
	check(WINDOW.groups({}).left.is_empty() and WINDOW.groups({}).right.is_empty(),"no values -> no cards")
	_sources()
	print("ORIGINAL_UI_STAT_DETAIL_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("try_open_stat_detail_window()") and hud_text.contains("_report_original_fallback(\"상세 능력치\",native)"),"상세 능력치 opens the original window first and reports a fallback")
	check(hud_text.contains("close_stat_detail_window()"),"ESC and closing the workspace close the window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_stat_detail_window","func stat_detail_window_is_open","stat_detail_window_is_open() or death_window_is_open()"]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var scene_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(scene_text.contains("var nine_size: Variant") and scene_text.contains("stretched is Vector2 and bool(options.scale9Enabled)"),"a scale-9 card can grow to its rows")
	var tree_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_named_tree.gd")
	check(tree_text.contains("if bool(widget.get(\"touchEnabled\",false)):binding[\"input\"]"),"a list without touch takes no input")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_stat_detail_window.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
