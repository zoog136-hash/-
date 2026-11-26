extends SceneTree
## The installed original UI add-on is shown (설정 정보 tab, loading screen)
## and an add-on older than the expected one (ui45) asks once for a reinstall
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
	check(current.installed and current.name=="ui45" and current.sha8=="47e593f4" and not current.outdated,"ui45 is current: "+str(current))
	check(VERSION.label(current)=="UI 팩 ui45 (47e593f4)","the readable label")
	# 2026-11-26: ui45 adds the skill awakening result, the common message box
	# and the skill-compose recovery scenes, and the whole bag tooltip (#924).
	var ui44: Dictionary=VERSION.describe("5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c")
	check(ui44.name=="ui44" and ui44.outdated and VERSION.label(ui44)=="UI 팩 ui44 (5263d925) · 오래됨","ui44 is a known old build: "+str(ui44))
	# 2026-11-22: ui43 (7a2b5985) and ui44 were not in the table, so the phone
	# showed "확인되지 않은 팩" and installed() parsed the whole 66 MB manifest
	# on every loading screen. ui43 lacks the 마법인형 탐험 scenes (#811).
	var ui43: Dictionary=VERSION.describe("7a2b59859b8c8abdead63e19fa4cd1c602c0324b7e0ca81d3e36e37186122371")
	check(ui43.name=="ui43" and ui43.outdated and VERSION.label(ui43)=="UI 팩 ui43 (7a2b5985) · 오래됨","ui43 is a known old build: "+str(ui43))
	check(VERSION.EXPECTED_SCENES.has("UI/Change/Change_Upgrade_Skill_Awaken.csb") and VERSION.EXPECTED_SCENES.has("UI/CommonUi/Common_MessageBox.csb") and VERSION.EXPECTED_SCENES.size()==3,"the scenes ui45 added")
	check(VERSION.describe("335af82d2794bafa4a9273cb309cde3a59f06a764467e66b58e29321c98eebaa").outdated,"ui42 is old now")
	var old: Dictionary=VERSION.describe("1137CCBCA08C61FB64607C01BB4CCD1B19D06DD58B34B95320B0AB74656B87EF")
	check(old.name=="ui41" and old.outdated and VERSION.label(old)=="UI 팩 ui41 (1137ccbc) · 오래됨","ui41 is old (any case): "+str(old))
	check(VERSION.describe("21daecf510dc83ca9b155c80227b2d6812dd34155a3a69dbbbdd3b4354092d3d").name=="ui40","older published builds have names")
	var scenes: Dictionary={}
	for member: String in VERSION.EXPECTED_SCENES:scenes[member]={}
	var newer: Dictionary=VERSION.describe("ab".repeat(32),scenes)
	check(newer.name=="확인되지 않은 팩" and not newer.outdated,"an unknown pack with every expected scene is current")
	scenes.erase("UI/CommonUi/Common_MessageBox.csb")
	var lacking: Dictionary=VERSION.describe("ab".repeat(32),scenes)
	check(lacking.outdated and lacking.missing_scenes==["UI/CommonUi/Common_MessageBox.csb"],"an unknown pack without an expected scene is old")
	check(VERSION.describe("ab".repeat(32)).outdated,"an unknown pack whose scenes are unknown is old")
	var none: Dictionary=VERSION.describe("")
	check(not none.installed and not none.outdated and VERSION.label(none)=="UI 팩 설치 안 됨","no pack: nothing to warn")
	check(VERSION.KNOWN.get(VERSION.EXPECTED_SHA256)==VERSION.EXPECTED_NAME and VERSION.KNOWN.size()==15,"the expected build is in the table")
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
