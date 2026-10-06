extends SceneTree

func require_true(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAIL: " + message)
		quit(1)

func _init() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	require_true(scene != null, "Main scene load")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var hud: Node = world.get_node("HUD")
	require_true(hud != null, "HUD exists")
	require_true(hud.has_method("set_quick_items"), "V20 quick item method")
	require_true(hud.has_method("set_quest_progress"), "V20 quest method")
	require_true(hud.get_node_or_null("Root/V20GameplayHUD") != null, "V20 gameplay HUD root")
	hud.set_quick_items(33, 77)
	hud.set_quest_progress(3, 9)
	hud.set_auto(true)
	hud.show_target("테스트 몬스터", 88, 100)
	await process_frame
	require_true(hud.v20_auto_label.text.find("ON") >= 0, "AUTO ON display")
	require_true(hud.v20_target_panel.visible, "Target panel visible")
	require_true(hud.v20_red_count.text == "33", "Red potion count")
	require_true(hud.v20_purple_count.text == "77", "Purple potion count")
	print("V20 HUD TEST PASS")
	quit(0)
