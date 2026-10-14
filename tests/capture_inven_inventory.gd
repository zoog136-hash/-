extends SceneTree
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var errors: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for i: int in range(12): await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await settle()
	if not CLASS_QA.enter_game(world): quit(1); return
	world.save_timer = -10000
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.inventory.clear()
	world.item_instances.clear()
	world.equipped_items.clear()
	var targets: Array[String] = ["훈련용 활","낡은 장검","강철 한손검","천상의 활","천상의 지팡이","미스릴의 갑옷","용기의 목걸이","HP 물약","강력 HP 물약","마나 회복 물약","무기 마법 주문서 (각인)","갑옷 마법 주문서 (각인)","화령의 무기 강화 주문서","드래곤의 루비","드래곤의 사파이어","드래곤의 다이아몬드","힘센 한우 스테이크","날쌘 연어 찜","영리한 칠면조 구이","엘릭서","희귀 제작 비법서","화살","총알"]
	for item_name: String in targets:
		world._grant_playtest_catalog_item(item_name,1)
	world._update_hud()
	var folder: String = OS.get_environment("TWILIGHT_INVEN_CAPTURES")
	DirAccess.make_dir_recursive_absolute(folder)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = extent
		DisplayServer.window_set_size(extent)
		world.hud._fit_hud()
		world.hud._close_workspace()
		world.hud.toggle_inventory()
		world.hud.lineage_inventory_ui.sort_mode = 1
		world.hud.lineage_inventory_ui._refresh_inventory_grid()
		await settle()
		await RenderingServer.frame_post_draw
		var result: Error = root.get_texture().get_image().save_png(folder+"/inventory-%dx%d.png" % [extent.x,extent.y])
		if result != OK: errors.append("inventory PNG save failed")
		var ui: Node = world.hud.lineage_inventory_ui
		for reference: String in ui.slot_buttons:
			if reference.begins_with("훈련용 활"):
				ui._select_item(reference)
				break
		ui.open_detail()
		await settle()
		await RenderingServer.frame_post_draw
		result = root.get_texture().get_image().save_png(folder+"/detail-%dx%d.png" % [extent.x,extent.y])
		if result != OK: errors.append("detail PNG save failed")
	print("INVEN_CAPTURE_RESULT ",JSON.stringify({"errors":errors,"inventory_count":world.inventory.size()}))
	world.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
