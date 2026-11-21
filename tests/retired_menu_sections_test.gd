extends SceneTree
## User list 2026-11-21 #1/#5/#6: 스킬 계열 전환, 불멸·파멸 가호 and 혈맹 문장 are
## TWILIGHT screens without an original client menu. They leave the player's
## screens: no 전체 메뉴 tile, _navigate ignores them, and their other entries
## (TWILIGHT 스킬 browser button, original Skill_All 속성 변경 / 디버프,
## 장비 정보 가호 제작, 원본 혈맹 정보 Btn_Set, TWILIGHT 혈맹 panel button) are
## hidden. Their saved state (protection523 etc.) is untouched.
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("RETIRED_MENU_SECTIONS_FAIL: " + label)

func _initialize() -> void:
	var hud_script: Script = load("res://scripts/ui/renewal_hud.gd")
	var retired: Array = hud_script.get_script_constant_map().get("RETIRED_SECTIONS", [])
	check(retired.has("spell_groups") and retired.has("protection523") and retired.has("clan_emblem523") and retired.size() == 3, "the three retired sections: " + str(retired))
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud.contains("if section_id in RETIRED_SECTIONS: continue"), "no 전체 메뉴 tile for a retired section")
	check(hud.contains("\tif section in RETIRED_SECTIONS:\n\t\treturn"), "_navigate ignores a retired section")
	var skill: Script = load("res://scripts/ui/original_ui/source_main_skill_window.gd")
	check(skill.get_script_constant_map().get("GROUP_CONVERSION_SHOWN", true) == false, "original 속성 변경 / 디버프 buttons stay hidden")
	check(not FileAccess.get_file_as_string("res://scripts/ui/renewal_skills.gd").contains("OpenSpellGroupConversion"), "the TWILIGHT skill browser has no 계열 전환 button")
	check(load("res://scripts/ui/patch523_equipment_info.gd").get_script_constant_map().get("PROTECTION_ENTRY_SHOWN", true) == false, "no 가호 제작 entry")
	check(FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_clan_window.gd").contains("spec[p+\"Nd_Symbol/Btn_Set\"]={\"visible\":false"), "원본 혈맹 정보 hides the mark set button")
	check(not FileAccess.get_file_as_string("res://scripts/clan523/clan523_panel.gd").contains("Clan523Emblem"), "the TWILIGHT 혈맹 panel has no 문장 button")
	var world: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world.contains("\"protection523\": protection523.snapshot(),"), "the 가호 state is still saved")
	print("RETIRED_MENU_SECTIONS_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
