extends SceneTree
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const Shop = preload("res://scripts/shop/shop_catalog.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: int = 0
var capture_directory: String = ""

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(960, 540) if "--source523-small-ui" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source523-capture-dir="): capture_directory = argument.trim_prefix("--source523-capture-dir=")
	if not Catalog.session().available():
		push_error("Select a verified original pack with --source523-shop-pack and --source523-shop-sha256")
		quit(1)
		return
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	check(QA.enter_game(world), "actual class selection confirmed")
	world.player.set_physics_process(false)
	var save_path: String = world.save_path()
	check(world._save_game(true) == OK, "actual Main save can be written in isolated test user data")
	var before_gold: int = world.gold
	var before_inventory: Dictionary = world.inventory.duplicate(true)
	var before_instances: Dictionary = world.item_instances.duplicate(true)
	var before_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	var before_prices: Array = Shop.GOODS.duplicate(true)
	world.hud.open_shop()
	await process_frame
	await process_frame
	var shop: Node = world.hud.shop_view
	var source_button: Button = shop.find_child("Source523Shop", true, false)
	check(source_button != null and source_button.visible and not source_button.disabled, "source view available from actual shop")
	if source_button == null:
		world.queue_free()
		quit(1)
		return
	tap(source_button)
	await process_frame
	await process_frame
	var panel: Node = shop.find_child("Source523ShopPanel", true, false)
	check(panel != null and panel.is_visible_in_tree(), "source shop view opens")
	if panel != null:
		check(panel.listing.item_count > 0 and panel.filtered.size() > 0, "actual current display rows listed")
		check(panel.purchase.disabled, "incomplete commerce cannot purchase")
		for unused: int in range(6): await process_frame
		if panel.listing.item_count > 2:
			var point: Vector2 = panel.listing.get_global_transform_with_canvas() * panel.listing.get_item_rect(2).get_center()
			var selected_id: int = int(panel.listing.get_item_metadata(2))
			touch(point, true)
			touch(point, false)
			await process_frame
			check(panel.detail.text.contains("상품 번호: %d" % selected_id), "native touch selects a source item through actual UI")
		panel.all_definitions.button_pressed = true
		panel.search.text = "1381"
		panel._filter()
		check(panel.filtered.any(func(entry: Dictionary) -> bool: return int(entry.id) == 1381), "actual product searchable by exact source ID")
		for index: int in range(panel.listing.item_count):
			if int(panel.listing.get_item_metadata(index)) == 1381: panel._select(index)
		check(panel.detail.text.contains("120") and panel.detail.text.contains("10"), "actual market price and bundle shown")
		await capture("market")
		panel.mode.select(1)
		panel.search.text = "17751"
		panel._build_entries()
		check(panel.detail.text.contains("0 / 7"), "actual separate NPC clan constraints shown")
		await capture("merchant")
		panel.mode.select(2)
		panel.search.text = "3034"
		panel._build_entries()
		check(panel.detail.text.contains("지급용 원천 없음"), "consume-only currency has no fabricated give source")
		await capture("currency")
		panel.mode.select(3)
		panel.search.text = ""
		panel._build_entries()
		check(panel.filtered.size() == 3 and panel.detail.text.contains("보관함 수령"), "actual cumulative definitions and receipt boundary shown")
		check(panel.detail.text.contains("1단계") and panel.detail.text.contains("6단계"), "all cumulative reward steps shown")
		await capture("cumulative")
		tap(panel.find_child("SourceShopBack", true, false))
		await process_frame
		check(source_button.is_visible_in_tree(), "back restores original shop")
	check(world.gold == before_gold and world.inventory == before_inventory and world.item_instances == before_instances, "browsing preserves economy and physical instances")
	check(FileAccess.get_file_as_bytes(save_path) == before_save, "browsing preserves save bytes")
	check(Shop.GOODS == before_prices, "source prices never overwrite local shop policy")
	world.queue_free()
	await process_frame
	print("Source523 actual Main/UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func touch(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 92
	event.position = point
	event.pressed = down
	root.push_input(event, true)

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * .5)
	touch(point, true)
	touch(point, false)

func capture(label: String) -> void:
	if capture_directory.is_empty(): return
	check(DisplayServer.get_name() != "headless", "captures require a real renderer")
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(label + ".png")) == OK, "rendered " + label + " capture")
