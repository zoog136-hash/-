extends SceneTree

func fail(message: String) -> void:
	push_error("TEST FAIL: " + message)
	quit(1)

func require_true(value: bool, message: String) -> bool:
	if not value:
		fail(message)
		return false
	return true

func _init() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if not require_true(scene != null, "Main scene load"): return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var hud: Node = world.get_node("HUD")
	if not require_true(hud != null, "HUD exists"): return
	world.process_mode = Node.PROCESS_MODE_DISABLED

	if not require_true(hud.get_node_or_null("Root/V20GameplayHUD") != null, "V20 gameplay HUD root"): return
	if not require_true(hud.v20_status_name != null, "Status name"): return
	if not require_true(hud.v20_auto_button != null, "AUTO button"): return
	if not require_true(hud.v20_target_panel != null, "Target panel"): return
	if not require_true(hud.v20_potion_count != null, "Potion count"): return
	if not require_true(hud.v20_leaf_count != null, "Leaf count"): return
	if not require_true(not hud.get_node("Root/TopLeft").visible, "Legacy top-left hidden"): return
	if not require_true(not hud.get_node("Root/RightControls").visible, "Legacy combat buttons hidden"): return

	hud.set_quick_items({"HP 물약":33, "초록 잎":77})
	hud.set_quest_progress(3, 9)
	hud.set_auto(true)
	hud.show_target("테스트 몬스터", 88, 100)

	if not require_true(hud.v20_auto_button.text == "AUTO ON", "AUTO ON display"): return
	if not require_true(hud.v20_target_panel.visible, "Target panel visible"): return
	if not require_true(hud.v20_potion_count.text == "33", "Potion count"): return
	if not require_true(hud.v20_leaf_count.text == "77", "Leaf count"): return
	if not require_true(hud.v20_quest_text.text.find("(3/9)") >= 0, "Quest progress"): return
	if not require_true(hud.v20_target_name.text == "테스트 몬스터", "Target name"): return
	if not require_true(int(hud.v20_target_hp.value) == 88, "Target HP"): return

	hud.clear_target()
	if not require_true(not hud.v20_target_panel.visible, "Target clear"): return

	print("V20 HUD TEST PASS")
	quit(0)
