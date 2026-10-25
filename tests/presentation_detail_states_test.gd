extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var captures: Array = []
var capture_dir: String = ""
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures.append(why); printerr("DETAIL_STATE_FAIL "+why)
func _capture(label: String) -> void:
	if capture_dir.is_empty(): return
	for frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var error: Error = pixels.save_png(capture_dir+"/"+label+".png")
	_check(error == OK,"capture "+label)
	captures.append({"name":label,"size":[pixels.get_width(),pixels.get_height()],"error":error})
func _run() -> void:
	capture_dir = OS.get_environment("TWILIGHT_DETAIL_CAPTURE_DIR")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	seed(20261025)
	root.size = Vector2i(1280,720)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for frame: int in range(12): await process_frame
	_check(QA.enter_game(world),"actual class selection")
	world.save_timer = -10000
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	# Real catalog equipment fixture through the existing equip/acquire service.
	for raw: Variant in world.catalog_db.get("아이템",[]):
		if raw is Dictionary and world._equipment_slot_base(raw) == "weapon":
			world._equip_or_acquire_item(raw,true)
			break
	world._update_hud()
	var hud: Node = world.hud
	var bag: Control = hud.lineage_inventory_ui
	var reference: String = ""
	for entry: Dictionary in bag._inventory_entries():
		if bag._is_item_equipped(str(entry.reference)):
			reference = str(entry.reference)
			break
	_check(not reference.is_empty(),"actual catalog physical equipped item")
	if reference.is_empty():
		world.queue_free(); quit(1); return
	world._set_item_locked(reference,true)
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var instances_before: Dictionary = world.item_instances.duplicate(true)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size = extent
		if not capture_dir.is_empty(): DisplayServer.window_set_size(extent)
		for frame: int in range(3): await process_frame
		hud._close_workspace()
		hud.toggle_inventory()
		bag._select_item(reference)
		bag.open_detail()
		for frame: int in range(3): await process_frame
		var button: Button = bag.slot_buttons[reference]
		var normal: StyleBoxFlat = button.get_theme_stylebox("normal")
		for state: String in ["hover","pressed"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state)
			_check(style.border_width_left == normal.border_width_left and style.border_color == normal.border_color,"selected border persists "+state)
		_check(bag.detail_grade.text.contains("장착중") and bag.detail_type.text.contains("잠금") and bag.detail_type.text.contains("선택됨"),"equipped selected locked are explicit")
		_check(bag.lock_button.text == "잠금 해제" and bag.lock_button.icon != null,"locked action and glyph agree")
		_check(bag.detail_grade.autowrap_mode != TextServer.AUTOWRAP_OFF,"Korean state text wraps")
		_check(button.get_node_or_null("InventoryLocked") != null,"physical item lock marker exists")
		await _capture("equipped-locked-%dx%d" % [extent.x,extent.y])
		world.gold = 100000000
		world._update_hud()
		hud.open_shop()
		var shop: Control = hud.shop_view
		var wanted: String = "축복받은 오림의 장신구 마법 주문서 (각인)"
		var chosen: int = -1
		for index: int in range(shop.filtered.size()):
			if str(shop.filtered[index][0]) == wanted: chosen = index; break
		_check(chosen >= 0,"actual long Korean shop product")
		if chosen < 0: continue
		shop.listing.select(chosen)
		shop.listing.ensure_current_is_visible()
		shop._select(chosen)
		shop.purchase_quantity.value = 99
		for frame: int in range(3): await process_frame
		_check(shop.detail.text.contains(wanted) and shop.detail.text.contains("44,550,000"),"untruncated actual name and exact grouped total")
		_check(shop.detail.text.contains("[table=2]") and shop.detail.text.contains("[right]"),"numeric units right aligned")
		_check(not shop.purchase.disabled,"affordable original rule remains enabled")
		await _capture("shop-long-name-%dx%d" % [extent.x,extent.y])
		world.gold = 0
		world._update_hud()
		shop._refresh_selection()
		var reason: Label = shop.find_child("ShopPurchaseState",true,false)
		_check(shop.purchase.disabled,"insufficient wallet remains disabled")
		_check(shop.wallet.text == "보유 아데나  0","wallet and disabled state agree after update")
		_check(reason != null and reason.is_visible_in_tree() and reason.text == "아데나가 부족합니다","disabled reason visible without hovering")
		await _capture("shop-disabled-%dx%d" % [extent.x,extent.y])
		shop.search_field.text = "존재하지않는상품검증"
		shop._refresh()
		_check(shop.selected.is_empty() and shop.purchase.disabled and shop.purchase.text == "상품 선택","empty search clears stale purchase caption")
	_check(world.inventory == inventory_before and world.item_instances == instances_before,"view selection/quantity/filter never alter inventory or physical IDs")
	if not capture_dir.is_empty():
		var report := FileAccess.open(capture_dir+"/capture.json",FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"fixture":"real catalog physical equipment equipped and locked through world actions; shop catalog unchanged; isolated wallet fixture100000000 then0; no purchase invoked","engine":Engine.get_version_info().string},"\t"))
	world.queue_free()
	await process_frame
	print("DETAIL_STATE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
