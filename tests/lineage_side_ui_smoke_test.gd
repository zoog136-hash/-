extends SceneTree

const SIDE_UI_SCRIPT := preload("res://scripts/ui/lineage_side_ui.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	failures.append(message)
	print("SIDE UI FAIL: " + message)

func _run() -> void:
	var ui := SIDE_UI_SCRIPT.new()
	get_root().add_child(ui)
	await process_frame

	var character_panel: PanelContainer = ui.get("character_panel") as PanelContainer
	var menu_panel: PanelContainer = ui.get("menu_panel") as PanelContainer
	if character_panel == null:
		_fail("character panel was not built")
	if menu_panel == null:
		_fail("menu panel was not built")

	if character_panel != null and character_panel.visible:
		_fail("character panel must start hidden")
	if menu_panel != null and menu_panel.visible:
		_fail("menu panel must start hidden")

	ui.call("toggle_menu")
	await process_frame
	if menu_panel == null or not menu_panel.visible:
		_fail("menu toggle did not open right menu")

	var menu_buttons := menu_panel.find_children("*", "Button", true, false) if menu_panel != null else []
	if menu_buttons.size() < 16:
		_fail("expected at least 16 menu buttons, got %d" % menu_buttons.size())

	var state := {
		"character_name":"황혼의 기사",
		"job_class":"기사",
		"level":35,
		"hp":1832,
		"max_hp":1832,
		"mp":315,
		"max_mp":375,
		"attack":42,
		"defense":19,
		"str":18,
		"dex":12,
		"con":17,
		"int":9,
		"wis":11,
		"cha":10,
		"stat_points":3,
		"current_weight":1240,
		"max_weight":3100,
		"equipped_items":{
			"weapon":{"name":"낡은 장검"},
			"helmet":{"name":"무관의 투구"},
			"body":{"name":"무관의 갑옷"}
		}
	}
	ui.call("show_character", state)
	await process_frame
	if character_panel == null or not character_panel.visible:
		_fail("character panel did not open")
	if menu_panel != null and menu_panel.visible:
		_fail("menu should close when character panel opens")

	var character_name: Label = ui.get("character_name") as Label
	var character_level: Label = ui.get("character_level") as Label
	var weight_label: Label = ui.get("weight_label") as Label
	if character_name == null or character_name.text != "황혼의 기사":
		_fail("character name did not refresh")
	if character_level == null or character_level.text != "Lv. 35":
		_fail("character level did not refresh")
	if weight_label == null or weight_label.text.find("1240 / 3100") < 0:
		_fail("weight text did not refresh")

	var equipment_buttons: Dictionary = ui.get("equipment_buttons") as Dictionary
	var weapon_button: Button = equipment_buttons.get("weapon") as Button
	if weapon_button == null or weapon_button.text.find("낡은 장검") < 0:
		_fail("weapon slot did not refresh")

	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("LINEAGE_SIDE_UI_SMOKE_OK")
		quit(0)
	else:
		print("LINEAGE_SIDE_UI_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
