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
	require_true(hud.get_node_or_null("Root/V20GameplayHUD") != null, "V20 gameplay HUD root")
	require_true(hud.v20_status_name != null, "Status name")
	require_true(hud.v20_auto_button != null, "AUTO button")
	require_true(hud.v20_target_panel != null, "Target panel")
	require_true(hud.v20_potion_count != null, "Potion count")
	require_true(hud.v20_leaf_count != null, "Leaf count")
	require_true(not hud.get_node("Root/TopLeft").visible, "Legacy top-left hidden")
	require_true(not hud.get_node("Root/RightControls").visible, "Legacy combat buttons hidden")
	hud.set_quick_items({"HP 물약":33, "초록 잎":77})
	hud.set_quest_progress(3, 9)
	hud.set_auto(true)
	hud.show_target("테스트 몬스터", 88, 100)
	await process_frame
	require_true(hud.v20_auto_button.text == "AUTO ON", "AUTO ON display")
	require_true(hud.v20_target_panel.visible, "Target panel visible")
	require_true(hud.v20_potion_count.text == "33", "Potion count")
	require_true(hud.v20_leaf_count.text == "77", "Leaf count")
	require_true(hud.v20_quest_text.text.find("(3/9)") >= 0, "Quest progress")
	hud.clear_target()
	require_true(not hud.v20_target_panel.visible, "Target clear")
	print("V20 HUD TEST PASS")
	quit(0)
