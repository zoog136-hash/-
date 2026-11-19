extends SceneTree
## The installed original UI add-on is shown (설정 정보 tab, loading screen)
## and an add-on older than the expected one (ui42) asks once for a reinstall
## without holding the game (source_ui_pack_version).
const VERSION=preload("res://scripts/ui/original_ui/source_ui_pack_version.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends RefCounted:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_PACK_VERSION_FAIL: ",label)

func _initialize() -> void:
	var current: Dictionary=VERSION.describe(VERSION.EXPECTED_SHA256)
	check(current.installed and current.name=="ui42" and current.sha8=="335af82d" and not current.outdated,"ui42 is current: "+str(current))
	check(VERSION.label(current)=="UI 팩 ui42 (335af82d)","the readable label")
	var old: Dictionary=VERSION.describe("1137CCBCA08C61FB64607C01BB4CCD1B19D06DD58B34B95320B0AB74656B87EF")
	check(old.name=="ui41" and old.outdated and VERSION.label(old)=="UI 팩 ui41 (1137ccbc) · 오래됨","ui41 is old (any case): "+str(old))
	check(VERSION.describe("21daecf510dc83ca9b155c80227b2d6812dd34155a3a69dbbbdd3b4354092d3d").name=="ui40","older published builds have names")
	var scenes: Dictionary={}
	for member: String in VERSION.EXPECTED_SCENES:scenes[member]={}
	var newer: Dictionary=VERSION.describe("ab".repeat(32),scenes)
	check(newer.name=="확인되지 않은 팩" and not newer.outdated,"an unknown pack with every expected scene is current")
	scenes.erase("UI/Main/Hud_LevelUp.csb")
	var lacking: Dictionary=VERSION.describe("ab".repeat(32),scenes)
	check(lacking.outdated and lacking.missing_scenes==["UI/Main/Hud_LevelUp.csb"],"an unknown pack without an expected scene is old")
	check(VERSION.describe("ab".repeat(32)).outdated,"an unknown pack whose scenes are unknown is old")
	var none: Dictionary=VERSION.describe("")
	check(not none.installed and not none.outdated and VERSION.label(none)=="UI 팩 설치 안 됨","no pack: nothing to warn")
	check(VERSION.KNOWN.get(VERSION.EXPECTED_SHA256)==VERSION.EXPECTED_NAME and VERSION.KNOWN.size()==12,"the expected build is in the table")
	var hud:=FakeHud.new()
	check(not VERSION.warn_once(hud,current) and hud.messages.is_empty(),"a current pack says nothing")
	check(VERSION.warn_once(hud,old) and hud.messages==[VERSION.WARNING],"an old pack asks for a reinstall")
	check(not VERSION.warn_once(hud,old) and hud.messages.size()==1,"only once per run")
	check(VERSION.WARNING=="UI 리소스 팩이 오래됐습니다. twilight523-addon-ui.zip(최신)을 다시 설치하세요","the requested wording")
	var loading: String=FileAccess.get_file_as_string("res://scripts/boot/loading_screen.gd")
	check(loading.contains("PACK_VERSION.installed()") and loading.contains("PACK_VERSION.WARNING") and loading.contains("_refresh_ui_pack()"),"the loading screen shows the installed pack and the notice")
	var option: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_option_window.gd")
	check(option.contains("PackVersion.label(pack_info)") and option.contains("RightContents/Version/Text_Desc"),"the 설정 정보 tab shows the installed pack under the version")
	var main: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main.contains("PackVersion.warn_once(hud,pack_info)") and not main.contains("PackVersion.describe(str(pack.get(\"manifest_sha256\")),pack.get(\"manifest\").get(\"scenes\",{}) if pack.get(\"manifest\") is Dictionary else null)\n\treturn _fail"),"the bound HUD warns once and keeps binding")
	print("ORIGINAL_UI_PACK_VERSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
