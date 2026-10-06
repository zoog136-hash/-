extends SceneTree

func require_true(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAIL: " + message)
		quit(1)

func _init() -> void:
	call_deferred("run_tests")

func _make_rows(category: String, count: int) -> Array:
	var rows: Array = []
	for i: int in range(count):
		rows.append({
			"name": "%s 테스트 %04d" % [category, i],
			"grade": "테스트",
			"type": "테스트",
			"sourceId": str(i),
			"sourceOptions": []
		})
	return rows

func run_tests() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	require_true(scene != null, "Main scene load")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var hud: Node = world.get_node("HUD")
	var synthetic: Dictionary = {
		"변신": _make_rows("변신", 413),
		"마법인형": _make_rows("마법인형", 166),
		"성물": _make_rows("성물", 144),
		"아이템": _make_rows("아이템", 2129)
	}
	hud.set_catalog_data(synthetic, {})
	var expected_pages: Dictionary = {
		"변신": 11,
		"마법인형": 5,
		"성물": 4,
		"아이템": 54
	}
	for category: String in ["변신", "마법인형", "성물", "아이템"]:
		hud.open_catalog(category)
		await process_frame
		require_true(hud._catalog_page_count() == int(expected_pages[category]), category + " page count")
		require_true(hud.catalog_page == 0, category + " starts page 1")
		require_true(hud.catalog_results.size() == 40, category + " first page size")
		hud._catalog_next_page()
		require_true(hud.catalog_page == 1, category + " next page")
		require_true(str(hud.catalog_results[0].get("sourceId", "")) == "40", category + " second page begins at item 40")
		hud._catalog_last_page()
		require_true(hud.catalog_page == int(expected_pages[category]) - 1, category + " last page")
		var expected_last_size: int = int(synthetic[category].size()) - (int(expected_pages[category]) - 1) * 40
		require_true(hud.catalog_results.size() == expected_last_size, category + " last page size")
		hud._catalog_first_page()
		require_true(hud.catalog_page == 0, category + " first page button")
	print("V19.3 PAGING TEST PASS")
	quit(0)
