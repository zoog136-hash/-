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

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var hud_script: Script = load("res://scripts/ui/renewal_hud.gd")
	var retired: Array = hud_script.get_script_constant_map().get("RETIRED_SECTIONS", [])
	check(retired.has("spell_groups") and retired.has("protection523") and retired.has("clan_emblem523") and retired.size() == 3, "the three retired sections: " + str(retired))
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	await check_live_menu(retired)
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


func check_live_menu(retired: Array) -> void:
	root.size = Vector2i(2048,919)
	DisplayServer.window_set_size(root.size)
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000
	await process_frame
	await process_frame
	var hud: Node = world.hud
	hud.toggle_menu()
	for n: int in 5: await process_frame
	var grid: GridContainer = hud.workspace.find_child("MenuGrid",true,false) as GridContainer
	check(grid != null and grid.get_child_count() >= 35, "the actual original 전체 메뉴 grid is present")
	if grid != null and grid.get_child_count() >= 35:
		for id: String in retired:
			check(grid.get_node_or_null("MenuTile_"+id)==null, "retired tile is not instantiated: "+id)
		var gap: Control = grid.get_child(7) as Control
		check(gap != null and str(gap.name)=="OriginalMenuSpace_7" and not gap is Button
			and gap.mouse_filter==Control.MOUSE_FILTER_IGNORE and gap.position.is_equal_approx(Vector2(140,67)),
			"the original unavailable cell stays a non-interactive gap at row 2, column 3")
		var settings: Button = grid.get_node_or_null("MenuTile_settings") as Button
		check(settings != null and settings.get_index()==28, "the neighboring live menu structure keeps settings at the original index")
		if settings != null:
			var point: Vector2 = root.get_final_transform() * (settings.get_global_transform_with_canvas() * (settings.size*0.5))
			for pressed: bool in [true,false]:
				var event:=InputEventScreenTouch.new()
				event.index=0;event.pressed=pressed;event.position=point
				Input.parse_input_event(event)
				await process_frame
			await process_frame
			check(str(hud.active_section)=="settings", "a real touch still routes the original settings tile")
	world.queue_free()
	await process_frame
