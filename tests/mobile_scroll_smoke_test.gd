extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("MOBILE SCROLL FAIL: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_fail("Main.tscn load failed")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var hud: Node = world.get_node("HUD")

	var inventory_scroll: ScrollContainer = hud.get("inventory_scroll") as ScrollContainer
	var inventory_list: VBoxContainer = hud.get("inventory_list") as VBoxContainer
	var utility_scroll: ScrollContainer = hud.get("utility_scroll") as ScrollContainer
	var utility_body: VBoxContainer = hud.get("utility_body") as VBoxContainer
	if inventory_scroll == null or utility_scroll == null:
		_fail("scroll containers were not initialized")
	else:
		if inventory_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			_fail("inventory vertical scrolling is disabled")
		if utility_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			_fail("utility vertical scrolling is disabled")
	if inventory_list == null or inventory_list.mouse_filter != Control.MOUSE_FILTER_PASS:
		_fail("inventory list does not pass drag input to ScrollContainer")
	if utility_body == null or utility_body.mouse_filter != Control.MOUSE_FILTER_PASS:
		_fail("utility body does not pass drag input to ScrollContainer")

	# Skills are built from rows containing buttons. Every row/button should PASS
	# drag input instead of blocking the utility ScrollContainer.
	hud.call("open_skills")
	await process_frame
	for child: Node in utility_body.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_PASS:
			_fail("skill panel child blocks touch scrolling: " + child.name)
			break

	# Catalog ItemList uses an explicit native-touch drag path.
	hud.call("open_catalog", "변신")
	await process_frame
	var catalog_list: ItemList = hud.get("catalog_list") as ItemList
	if catalog_list == null:
		_fail("catalog list missing")
	else:
		var bar: VScrollBar = catalog_list.get_v_scroll_bar()
		if bar != null and bar.max_value > bar.min_value:
			bar.value = bar.min_value
			var touch: InputEventScreenTouch = InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = true
			touch.position = Vector2(100, 300)
			hud.call("_on_catalog_list_gui_input", touch)
			var drag: InputEventScreenDrag = InputEventScreenDrag.new()
			drag.index = 0
			drag.position = Vector2(100, 220)
			drag.relative = Vector2(0, -80)
			hud.call("_on_catalog_list_gui_input", drag)
			if not bool(hud.get("catalog_touch_dragged")):
				_fail("catalog drag gesture was not recognized")
			if bar.value <= bar.min_value:
				_fail("catalog drag did not move the vertical scrollbar")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("MOBILE_SCROLL_SMOKE_OK: inventory, skill and catalog touch scrolling validated")
		quit(0)
	else:
		print("MOBILE_SCROLL_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
