extends SceneTree

# Actual Main/HUD, native screen-touch input and isolated test saves. Run with
# TWILIGHT_UI_TEST_ISOLATED=1 and an isolated XDG_DATA_HOME. Optional captures:
# -- --capture-option-awakening-ui; TWILIGHT_AWAKENING_UI_CAPTURE_DIR selects it.
const QA = preload("res://tests/qa_class_selection.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const Core = preload("res://scripts/cards/option_awakening_service.gd")
var world
var hud
var assertions: int = 0
var failures: Array[String] = []
var feed_requests: int = 0
var attempt_requests: int = 0
var captures: Array[Dictionary] = []
var layout_metrics: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		print("OPTION_AWAKENING_UI_FAIL: " + message)

func _settle(frames: int = 4) -> void:
	for frame: int in range(frames):
		await process_frame

func _point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _canvas_rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	return Rect2(transform * Vector2.ZERO, transform.basis_xform(control.size))

func _visible_rect(control: Control) -> Rect2:
	var rectangle: Rect2 = _canvas_rect(control)
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			rectangle = rectangle.intersection(_canvas_rect(ancestor as Control))
		ancestor = ancestor.get_parent()
	return rectangle

func _touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _tap(control: Control, index: int = 81) -> void:
	var position: Vector2 = _point(control)
	_touch(index, position, true)
	_touch(index, position, false)

func _drag(index: int, position: Vector2, delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = delta
	root.push_input(event, true)

func _control(id: String) -> Control:
	return hud.option_awakening_view.find_child(id, true, false) as Control

func _find_target(category: String, grade: String, with_pending: bool = false) -> String:
	for identity: String in world.option_awakening.core.definitions[category]:
		var row: Dictionary = world.option_awakening.core.definitions[category][identity]
		if str(row.grade) == grade and (not with_pending or not row.pending_options.is_empty()):
			return identity
	return ""

func _select_catalog(category: String, identity: String) -> void:
	var record: Dictionary = world.option_awakening.core.catalog[category][identity]
	hud.open_catalog(category)
	hud.catalog_search.text = str(record.name)
	hud._refresh_catalog_list(str(record.name))
	for index: int in range(hud.catalog_results.size()):
		if Cards.card_id(hud.catalog_results[index]) == identity:
			hud._select_catalog_index(index)
			return
	_check(false, "real catalog target is reachable: " + identity)

func _seed_materials() -> void:
	for category: String in Cards.CATEGORIES:
		var amount: int = 0
		for record: Dictionary in world.catalog_db[category]:
			if str(record.get("grade", "")) != "희귀":
				continue
			var identity: String = Cards.card_id(record)
			world.card_draw_fusion.owned[category][identity] = true
			world.card_draw_fusion.spare[category][identity] = 7
			amount += 1
			if amount >= 20:
				break

func _capture(label: String) -> void:
	if not "--capture-option-awakening-ui" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await _settle(3)
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("TWILIGHT_AWAKENING_UI_CAPTURE_DIR")
	if folder.is_empty():
		folder = "user://option-awakening-ui"
	DirAccess.make_dir_recursive_absolute(folder)
	var image: Image = root.get_texture().get_image()
	var path: String = folder.path_join(label + ".png")
	_check(image.save_png(path) == OK, "OpenGL capture saved: " + label)
	captures.append({"name": label, "path": path, "window": str(root.size), "active_texture": str(image.get_size()), "renderer": RenderingServer.get_current_rendering_method()})

func _run() -> void:
	if OS.get_environment("TWILIGHT_UI_TEST_ISOLATED") != "1":
		_check(false, "refusing UI fixture writes without explicit isolated test profile")
		_finish()
		return
	root.size = Vector2i(1280, 720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await _settle(8)
	_check(QA.enter_game(world), "startup class selection uses the real confirmation")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children():
		monster.set_process(false)
		monster.set_physics_process(false)
	hud = world.hud
	_check(world.option_awakening.problem.is_empty(), "actual awakening runtime is configured")
	if not world.option_awakening.problem.is_empty():
		_finish()
		return
	world.option_awakening.progress = Core.fresh_state()
	world.gold = 30000000
	_seed_materials()
	var target_id: String = _find_target("변신", "영웅")
	_check(not target_id.is_empty(), "real hero target exists")
	world._update_hud()
	_select_catalog("변신", target_id)
	await _settle()
	_check(hud.option_awakening_button.visible and hud.option_awakening_button.disabled, "unowned card has a visible, disabled awakening entry")
	world.card_draw_fusion.owned["변신"][target_id] = true
	world._update_hud()
	_check(not hud.option_awakening_button.disabled, "owned hero card can enter awakening")
	hud._set_catalog_detail_view(true)
	var selected_query: String = hud.catalog_search.text
	_tap(hud.option_awakening_button)
	await _settle()
	_check(hud.active_section == "option_awakening", "native catalog entry opens the real fullscreen awakening view")
	_check(not hud.option_awakening_view.snapshot.is_empty(), "world supplies authoritative snapshot")
	_check(_control("AwakeningFeed").disabled and _control("AwakeningAttempt").disabled, "empty selection and incomplete XP cannot be consumed")
	_check(_control("AwakeningPolicy").text.contains("TWILIGHT"), "local XP/cost/refund policy is disclosed")
	_check(_control("AwakeningCollectionProgress").text.contains("지원 각성 컬렉션 · 4개"), "supported collection progress is visible without implying a complete original collection catalog")
	var list: ItemList = _control("AwakeningMaterials") as ItemList
	_check(list.item_count >= 10, "material list contains real duplicate IDs")
	_check(list.get_v_scroll_bar().max_value > list.get_v_scroll_bar().page, "real material list overflows before scroll test")
	var before_spares: Dictionary = world.card_draw_fusion.spare.duplicate(true)
	var row_point: Vector2 = list.get_global_transform_with_canvas() * list.get_item_rect(0).get_center()
	_touch(82, row_point, true)
	_drag(82, row_point + Vector2(0, -65), Vector2(0, -65))
	_touch(82, row_point + Vector2(0, -65), false)
	await _settle(2)
	_check(list.get_v_scroll_bar().value > 0.0, "native material swipe scrolls")
	_check(hud.option_awakening_view.selected_materials.is_empty(), "material swipe never selects consumption quantities")
	_check(world.card_draw_fusion.spare == before_spares, "material swipe never consumes cards")
	list.get_v_scroll_bar().value = 0
	await _settle(2)
	row_point = list.get_global_transform_with_canvas() * list.get_item_rect(0).get_center()
	_touch(83, row_point, true)
	_touch(83, row_point, false)
	await _settle(2)
	var material_id: String = str(list.get_item_metadata(0))
	_check(not _control("AwakeningMaterialIncrease").disabled, "native row release selects a stable material ID")
	_tap(_control("AwakeningMaterialIncrease"))
	_check(int(hud.option_awakening_view.selected_materials.get(material_id, 0)) == 1, "plus selects one duplicate without consuming it")
	var plus: Control = _control("AwakeningMaterialIncrease")
	var plus_point: Vector2 = _point(plus)
	_touch(84, plus_point, true)
	_drag(84, plus_point + Vector2(20, 0), Vector2(20, 0))
	_touch(84, plus_point + Vector2(20, 0), false)
	_check(int(hud.option_awakening_view.selected_materials.get(material_id, 0)) == 1, "dragged quantity touch is canceled")
	_touch(85, plus_point, true)
	_touch(85, plus_point, false, true)
	_check(int(hud.option_awakening_view.selected_materials.get(material_id, 0)) == 1, "canceled quantity touch is canceled")
	_tap(_control("AwakeningFeed"))
	await _settle(2)
	_check(hud.option_awakening_view.is_review_open(), "feed requires explicit final confirmation")
	_check(world.card_draw_fusion.spare == before_spares, "opening feed confirmation leaves materials untouched")
	_tap(_control("AwakeningConfirmCancel"))
	_check(not hud.option_awakening_view.is_review_open(), "native cancel returns to material selection")
	_check(world.card_draw_fusion.spare == before_spares, "cancel preserves materials")
	_tap(_control("AwakeningFeed"))
	await _settle(2)
	var refreshed: Dictionary = world.option_awakening.view("변신", target_id)
	refreshed["revision"] = int(refreshed.revision) + 1
	hud.set_option_awakening_view(refreshed)
	_check(not hud.option_awakening_view.is_review_open(), "a fresh snapshot invalidates an open consumption confirmation")
	hud.set_option_awakening_view(world.option_awakening.view("변신", target_id))
	hud._go_back()
	await _settle()
	_check(hud.active_section == "변신" and Cards.card_id(hud.selected_catalog_record) == target_id, "back restores category and exact selected ID")
	_check(hud.catalog_search.text == selected_query and hud.catalog_details_active, "back restores query and detail pane")
	_tap(hud.option_awakening_button)
	await _settle()
	list = _control("AwakeningMaterials") as ItemList
	row_point = list.get_global_transform_with_canvas() * list.get_item_rect(0).get_center()
	_touch(86, row_point, true)
	_touch(86, row_point, false)
	_tap(_control("AwakeningMaterialFill"))
	_check(int(hud.option_awakening_view.selected_materials.get(material_id, 0)) == 4, "fill chooses only four 25-XP duplicates for remaining 100 XP")
	_check(_control("AwakeningMaterialIncrease").disabled, "extra cards cannot be added after XP is covered")
	await _capture("materials_1280x720")
	_tap(_control("AwakeningFeed"))
	await _settle()
	await _capture("feed_confirmation_1280x720")
	hud.option_awakening_feed_requested.connect(func(_category: String, _identity: String, _materials: Dictionary) -> void: feed_requests += 1)
	var confirm: Button = _control("AwakeningConfirmCommit") as Button
	var original_gold: int = int(world.gold)
	_tap(confirm)
	confirm.pressed.emit() # A queued second release must not resubmit the old review.
	await _settle()
	_check(feed_requests == 1, "double feed confirmation emits one authoritative request")
	_check(int(world.card_draw_fusion.spare["변신"][material_id]) == int(before_spares["변신"][material_id]) - 4, "feed consumes exactly reviewed duplicate quantity")
	_check(bool(world.card_draw_fusion.owned["변신"][material_id]), "feed preserves first-owned material card")
	_check(int(world.gold) == original_gold, "experience feed does not charge attempt Adena")
	_check(int(hud.option_awakening_view.snapshot.experience) == 100, "durable feed refreshes visible experience")
	_check(not _control("AwakeningAttempt").disabled and _control("AwakeningFeed").disabled, "full XP enables the separate awakening attempt")
	_tap(_control("AwakeningAttempt"))
	await _settle()
	_check(_control("AwakeningConfirmationDetails").text.contains("20 / 100"), "attempt confirmation discloses configured failure refund")
	_check(_control("AwakeningConfirmationDetails").text.contains("16.5%"), "attempt confirmation displays the source-backed hero chance")
	await _capture("attempt_confirmation_1280x720")
	hud.option_awakening_attempt_requested.connect(func(_category: String, _identity: String) -> void: attempt_requests += 1)
	confirm = _control("AwakeningConfirmCommit") as Button
	_tap(confirm)
	confirm.pressed.emit()
	await _settle()
	_check(attempt_requests == 1 and int(world.gold) == original_gold - 100000, "double attempt confirmation charges once")
	_check(hud.is_option_awakening_busy(), "saved result creates the separate awakening reveal")
	_check(hud.blocks_world_input(Vector2(10, 10)) and hud.blocks_keyboard_input(), "awakening reveal blocks world and keyboard input")
	if hud.is_option_awakening_busy():
		hud.option_awakening_reveal.skip_to_result()
		await _capture("saved_result_1280x720")
		hud.option_awakening_reveal.close_reveal()
		await _settle()
	_check(not hud.is_option_awakening_busy(), "closing the result releases its own modal lock")
	# Presentation-only awake state verifies markers without another RNG/save write.
	var live_state: Dictionary = world.option_awakening.export_state()
	var awake_display: Dictionary = live_state.duplicate(true)
	awake_display.cards["변신"][target_id] = {"experience": 0, "awakened": true, "attempts": 1, "failures": 0}
	hud.set_option_awakening_state(awake_display)
	_select_catalog("변신", target_id)
	await _settle()
	_check(hud.catalog_list.get_item_tooltip(0).begins_with("[각성]") and str(hud.catalog_list.get_item_metadata(0))==target_id and hud.catalog_card_chrome.quantities.is_visible_in_tree(), "portrait grid preserves the exact awakened card ID and its visible status layer")
	_check(hud.option_awakening_catalog_border.visible, "catalog detail mounts the persistent awakened border")
	hud.apply_option_awakening_settings({"reduced_motion": true, "impact_intensity": 0.0, "effect_detail": "low"})
	_check(hud.option_awakening_catalog_border.visible and not hud.option_awakening_catalog_border.is_processing(), "reduced motion retains the static status border")
	_check(world.option_awakening.export_state() == live_state, "status rendering never mutates authoritative awakening state")
	await _capture("catalog_awakened_1280x720")
	hud.set_option_awakening_state(live_state)
	var option_texts: Array[String] = []
	for category: String in Cards.CATEGORIES:
		var category_target: String = _find_target(category, "영웅")
		world.card_draw_fusion.owned[category][category_target] = true
		hud.set_option_awakening_view(world.option_awakening.view(category, category_target))
		await _settle()
		_check(hud.option_awakening_view.snapshot.category == category, "category remains distinct: " + category)
		_check(not _control("AwakeningOptions").text.is_empty(), "actual category bonus options visible: " + category)
		option_texts.append(_control("AwakeningOptions").text)
	_check(option_texts[0] != option_texts[1] and option_texts[1] != option_texts[2], "three categories show their own option data")
	var pending_target: String = _find_target("변신", "유일", true)
	_check(not pending_target.is_empty(), "actual unsupported innate effect fixture exists")
	if not pending_target.is_empty():
		world.card_draw_fusion.owned["변신"][pending_target] = true
		hud.set_option_awakening_view(world.option_awakening.view("변신", pending_target))
		await _settle()
		_check(_control("AwakeningOptions").text.contains("효과 미지원"), "unsupported innate effects are never labeled as applied")
		await _capture("unique_options_1280x720")
	# Use an unconsumed hero for responsive material controls.
	var layout_snapshot: Dictionary = world.option_awakening.view("변신", target_id).duplicate(true)
	layout_snapshot["experience"] = 0
	layout_snapshot["awakened"] = false
	layout_snapshot["can_feed"] = true
	layout_snapshot["can_awaken"] = false
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(540, 960)]:
		root.size = extent
		await _settle()
		hud.set_option_awakening_view(layout_snapshot)
		hud.workspace.fit_viewport()
		await _settle()
		var view: Control = hud.option_awakening_view
		var compact_tabs: Control = _control("AwakeningCompactTabs")
		if compact_tabs.is_visible_in_tree():
			_tap(compact_tabs.get_child(1))
			await _settle()
		if not _control("AwakeningClearMaterials").disabled:
			_tap(_control("AwakeningClearMaterials"))
			await _settle(2)
		_check(_control("AwakeningMaterialsPane").is_visible_in_tree(), "materials reachable at " + str(extent))
		var scale_y: float = root.get_final_transform().y.length()
		if compact_tabs.is_visible_in_tree():
			for tab: Control in compact_tabs.get_children():
				_check(_visible_rect(tab).size.y * scale_y >= 44.0, "compact tab keeps 44 unclipped physical pixels " + str(extent))
		var visible_body: Rect2 = _visible_rect(_control("AwakeningMaterialsPane"))
		var visible_list: Rect2 = _visible_rect(_control("AwakeningMaterials"))
		_check(visible_body.size.y * scale_y >= 70.0, "at least 70 physical pixels of actual material content survive clipping " + str(extent))
		_check(visible_list.size.y * scale_y >= 58.0, "at least one real material row is visible " + str(extent))
		list = _control("AwakeningMaterials") as ItemList
		list.get_v_scroll_bar().value = 0
		await _settle(2)
		var first_row: Rect2 = list.get_item_rect(0)
		var first_transform: Transform2D = list.get_global_transform_with_canvas()
		var row_visible: Rect2 = Rect2(first_transform * first_row.position, first_transform.basis_xform(first_row.size)).intersection(_visible_rect(list))
		var visible_point: Vector2 = row_visible.get_center()
		_touch(92, visible_point, true)
		_touch(92, visible_point, false)
		_tap(_control("AwakeningMaterialIncrease"), 93)
		await _settle()
		_check(int(view.selected_materials.get(str(list.get_item_metadata(0)), 0)) == 1, "native touch reaches a visible row and quantity button " + str(extent))
		var final_transform: Transform2D = root.get_final_transform() * hud.workspace.get_global_transform_with_canvas()
		var end: Vector2 = final_transform * hud.workspace.size
		_check(end.x <= extent.x + 2 and end.y <= extent.y + 2, "fullscreen workspace fits physical window " + str(extent))
		for id: String in ["AwakeningFeed", "AwakeningAttempt", "AwakeningMaterialIncrease", "AwakeningMaterialDecrease", "AwakeningMaterialFill"]:
			var button: Control = _control(id)
			var transform: Transform2D = root.get_final_transform() * button.get_global_transform_with_canvas()
			var physical_size: Vector2 = transform.basis_xform(button.size)
			_check(physical_size.y >= 44.0, "native action remains at least 44 physical pixels: " + id + " " + str(extent))
			_check(_visible_rect(button).size.y * scale_y >= 44.0, "native action has 44 unclipped physical pixels: " + id + " " + str(extent))
		var footer: Control = _control("AwakeningActions")
		_check(footer.position.y + footer.size.y <= view.size.y + 1.0, "consumption footer stays reachable without body scroll " + str(extent))
		layout_metrics.append({"window": str(extent), "body_visible_px": visible_body.size.y * scale_y, "material_list_visible_px": visible_list.size.y * scale_y, "footer_height_px": _visible_rect(footer).size.y * scale_y})
		await _capture("responsive_%dx%d" % [extent.x, extent.y])
	world.queue_free()
	await _settle(2)
	_finish()

func _finish() -> void:
	print("OPTION_AWAKENING_UI_RESULT " + JSON.stringify({"assertions": assertions, "failures": failures, "layout_metrics": layout_metrics, "captures": captures}))
	if failures.is_empty():
		print("OPTION_AWAKENING_UI_OK")
	quit(0 if failures.is_empty() else 1)
