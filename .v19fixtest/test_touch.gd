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
	var synthetic: Dictionary = {}
	for category: String in ["변신", "마법인형", "성물", "아이템"]:
		var rows: Array = []
		for i: int in range(4):
			rows.append({"name":"%s 테스트 %d" % [category, i], "grade":"테스트", "type":"테스트", "sourceId":str(i), "sourceOptions":[]})
		synthetic[category] = rows
	hud.set_catalog_data(synthetic, {})
	for category: String in ["변신", "마법인형", "성물", "아이템"]:
		hud.open_catalog(category)
		await process_frame
		hud.catalog_list.force_update_list_size()
		await process_frame
		var rect: Rect2 = hud.catalog_list.get_item_rect(2, true)
		require_true(rect.size.y > 0.0, category + " third row rect")
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = rect.get_center()
		hud._on_catalog_list_gui_input(touch)
		require_true(hud.catalog_list.is_selected(2), category + " touch selected index 2")
		require_true(str(hud.selected_catalog_record.get("name", "")) == "%s 테스트 2" % category, category + " selected record")
	print("V19.2 TOUCH SELECTION TEST PASS")
	quit(0)
