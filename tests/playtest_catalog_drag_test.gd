extends SceneTree

# Playtest-only QA: runtime-authoritative catalog grants, 100M Adena and window drag.
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("PLAYTEST_UI_FAIL: " + label)

func _run() -> void:
	# Headless windows default to 64x64; exercise title motion at the game's
	# actual PC surface instead of clamping an oversized title to that stub.
	root.size = Vector2i(1280,720)
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	_check(scene != null, "Main scene available")
	if scene == null:
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	for frame: int in range(8):
		await process_frame
	var hud: Node = world.get_node("HUD")
	_check(hud.has_signal("playtest_catalog_grant_requested"), "Test catalog grant connected")
	_check(hud.has_signal("playtest_aden_grant_requested"), "Test gold grant connected")
	_check(int(world.get("gold")) >= 100000000, "Fresh playtest starts with >=100M Adena")
	world.set("gold", 1234)
	hud.call("open_catalog", "아이템")
	await process_frame
	var workspace: Control = hud.get("workspace") as Control
	_check(workspace != null and workspace.visible, "Item catalog workspace opened")
	var gold_button: Button = workspace.find_child("PlaytestAden",true,false) as Button
	var grant_button: Button = workspace.find_child("PlaytestGrantSelected",true,false) as Button
	var scroll_button: Button = workspace.find_child("PlaytestScroll0",true,false) as Button
	_check(gold_button != null and gold_button.visible, "100M Adena button in catalog")
	_check(grant_button != null and grant_button.visible, "Selected item grant button")
	_check(scroll_button != null and scroll_button.visible, "Convenience scroll grant button")
	if gold_button != null:
		gold_button.pressed.emit()
		_check(int(world.get("gold")) == 100000000, "100M Adena granted via UI signal")
	if scroll_button != null:
		var item_name: String = "무기 마법 주문서 (각인)"
		var prior: int = int((world.get("inventory") as Dictionary).get(item_name,0))
		scroll_button.pressed.emit()
		_check(int((world.get("inventory") as Dictionary).get(item_name,0)) == prior + 10, "Scrolls grant 10 via world inventory")
		world.call("_save_game",true)
		world.call("_load_game",true)
		_check(int((world.get("inventory") as Dictionary).get(item_name,0)) == prior + 10, "Scroll grant persists across save/load")

	# Real catalog selection generates physical equipment IDs rather than
	# enhancing every copy under one name.
	var swords_before: int = int((world.get("inventory") as Dictionary).get("낡은 장검",0))
	world.call("_grant_playtest_catalog_item","낡은 장검",2)
	_check(int((world.get("inventory") as Dictionary).get("낡은 장검",0)) == swords_before+2, "Grant two separate physical swords")
	var count: int = 0
	var id_seen: Dictionary = {}
	for raw: Variant in (world.get("item_instances") as Dictionary).keys():
		var data: Dictionary = (world.get("item_instances") as Dictionary)[raw] as Dictionary
		if str(data.get("name","")) == "낡은 장검":
			count += 1
			id_seen[str(raw)] = true
	_check(count == swords_before+2 and id_seen.size() == count,"Each granted sword has its own stable ID")
	var dragged_from: Vector2 = workspace.position
	var start: InputEventMouseButton = InputEventMouseButton.new()
	start.button_index = MOUSE_BUTTON_LEFT
	start.pressed = true
	workspace.call("_on_title_drag_input",start)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(77,28)
	workspace.call("_on_title_drag_input",motion)
	var stop: InputEventMouseButton = InputEventMouseButton.new()
	stop.button_index = MOUSE_BUTTON_LEFT
	stop.pressed = false
	workspace.call("_on_title_drag_input",stop)
	_check(workspace.position.distance_to(dragged_from) > 12.0, "Window moves when title dragged by mouse")
	var moved: Vector2 = workspace.position
	hud.call("open_shop")
	await process_frame
	_check(workspace.position.distance_to(moved) < 1.0, "Position preserved across shop/catalog navigation")
	var first_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	first_touch.pressed = true
	workspace.call("_on_title_drag_input",first_touch)
	var mobile_drag: InputEventScreenDrag = InputEventScreenDrag.new()
	mobile_drag.relative = Vector2(-38,12)
	workspace.call("_on_title_drag_input",mobile_drag)
	first_touch.pressed = false
	workspace.call("_on_title_drag_input",first_touch)
	_check(workspace.position.distance_to(moved) > 4.0, "Window moves with touchscreen title drag")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("PLAYTEST_CATALOG_DRAG_OK %d checks" % checks)
		quit(0)
	else:
		print("PLAYTEST_CATALOG_DRAG_FAILED %d/%d" % [failures.size(),checks])
		quit(1)
