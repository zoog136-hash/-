extends SceneTree
## User list 2026-11-26 #9: no awakening effect. The phone's UI44 main pack
## (5263d925) lacks UI/Change/Change_Upgrade_Skill_Awaken.csb and
## UI/CommonUi/Common_MessageBox.csb, and its icon selection has no
## complete_pack, so the original result scene could not mount and only the
## TWILIGHT reveal ran. A main UI pack built from this checkout carries both
## scenes; the selected pack must then be used directly.
##   godot --headless --path <repo> --script res://tests/awakening_result_ui_pack_test.gd
const RESULT_PACK = preload("res://scripts/ui/original_ui/source_awakening_result_pack.gd")
const BUILDER = "res://tools/ui/build_client523_main_ui_pack.py"
var checks: int = 0
var failures: Array[String] = []

class FakePack extends RefCounted:
	var manifest: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("AWAKENING_RESULT_UI_PACK_FAIL: " + label)

func _pack(members: Dictionary) -> FakePack:
	var pack := FakePack.new()
	pack.manifest = {"files":{}, "scenes":{}}
	for member: String in members:
		pack.manifest.files[member] = {"sha256":members[member]}
		pack.manifest.scenes[member] = {}
	return pack

func _initialize() -> void:
	var full := _pack({RESULT_PACK.MEMBER:RESULT_PACK.SOURCE_SHA, RESULT_PACK.REVIEW:RESULT_PACK.REVIEW_SHA})
	check(RESULT_PACK.resolve(full) == full, "a selected UI pack with the pinned result scene is used directly")
	check(RESULT_PACK.resolve(full, RESULT_PACK.REVIEW) == full, "a selected UI pack with the pinned review dialog is used directly")
	var altered := _pack({RESULT_PACK.MEMBER:"0".repeat(64), RESULT_PACK.REVIEW:"1".repeat(64)})
	OS.set_environment("TWILIGHT_SOURCE523_UI_ICONS", "")
	check(RESULT_PACK.resolve(altered) == null and RESULT_PACK.resolve(altered, RESULT_PACK.REVIEW) == null, "a different scene byte pin is never mounted")
	var ui44 := _pack({"UI/Change/Change_Awaken_Option.csb":"a".repeat(64)})
	check(RESULT_PACK.resolve(ui44) == null, "UI44 without the scene and without complete_pack has no original result")
	check(RESULT_PACK.resolve(full, "UI/Change/Other.csb") == null, "only the two pinned members are served")
	# The staged CI project may omit tools/; the checkout always has it.
	var builder: String = FileAccess.get_file_as_string(BUILDER) if FileAccess.file_exists(BUILDER) else "\"scripts/ui/original_ui/source_awakening_result_pack.gd\""
	check(builder.contains("\"scripts/ui/original_ui/source_awakening_result_pack.gd\""), "the main UI pack builder collects scenes named by the result pack")
	var code: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_awakening_result_pack.gd")
	check(code.contains("const MEMBER = \"" + RESULT_PACK.MEMBER + "\"") and code.contains("const REVIEW = \"" + RESULT_PACK.REVIEW + "\""), "both scenes are double-quoted members the builder regex reads")
	print("AWAKENING_RESULT_UI_PACK_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
