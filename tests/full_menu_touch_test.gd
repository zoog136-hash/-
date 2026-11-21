extends SceneTree
## 전체 메뉴 on Android touch (user report 2026-11-19 "이상태에서 닫기 버튼이
## 안눌러지고"): the project runs with emulate_mouse_from_touch off, and the
## old category OptionButton opened a PopupMenu that ignored touches, stayed
## open and swallowed every tap, the close X included. The category row is now
## plain buttons. Real InputEventScreenTouch through Input, phone resolution.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FULL_MENU_TOUCH_FAIL: " + label)

func _initialize() -> void: call_deferred("run")

func frames(count: int = 3) -> void:
	for frame: int in count: await process_frame

func window_point(control: Control) -> Vector2:
	return root.get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))

func touch(control: Control) -> void:
	var at: Vector2 = window_point(control)
	var down := InputEventScreenTouch.new(); down.index = 0; down.pressed = true; down.position = at
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventScreenTouch.new(); up.index = 0; up.pressed = false; up.position = at
	Input.parse_input_event(up)
	await frames(3)

func popups_open() -> int:
	var open: int = 0
	for window: Window in root.find_children("*", "PopupMenu", true, false):
		if window.visible: open += 1
	return open

func run() -> void:
	check(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true), "the Android touch setting under test (no mouse emulation)")
	root.size = Vector2i(2408, 1080); DisplayServer.window_set_size(root.size)
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "actual Main class confirmation")
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.save_timer = -100000.0
	await frames(6)
	var hud: Node = world.hud
	hud.toggle_menu(); await frames(5)
	var close: Button = hud.workspace.find_child("CloseWindow", true, false) as Button
	check(close != null and close.is_visible_in_tree(), "menu close X is shown")
	check(hud.workspace.find_children("*", "OptionButton", true, false).is_empty(), "the full menu has no popup dropdown")
	check(hud.menu_category_buttons.size() == 4, "four category buttons")
	if close == null or hud.menu_category_buttons.size() != 4:
		await finish(world); return
	await touch(hud.menu_category_buttons[3])
	var shown: int = hud.menu_tiles.filter(func(tile: Control) -> bool: return tile.visible).size()
	check(hud.menu_category_index == 3 and shown > 0 and shown < hud.menu_tiles.size() and popups_open() == 0, "a category tap filters the tiles with no popup left open")
	await touch(close)
	check(not hud.workspace.visible, "X closes the menu right after a category tap")
	hud.toggle_menu(); await frames(5)
	check(hud.menu_category_index == 0 and hud.menu_tiles.all(func(tile: Control) -> bool: return tile.visible), "reopen starts on 전체")
	await touch(hud.menu_category_buttons[1]); await touch(hud.menu_category_buttons[0])
	var tile: Button = hud.workspace.find_child("MenuTile_character", true, false) as Button
	check(tile != null and tile.is_visible_in_tree(), "character tile shown on 전체")
	if tile != null:
		# The original menu order (2026-11-21) puts 캐릭터 after the original tiles.
		hud.menu_scroll_view.ensure_control_visible(tile); await frames(3)
		await touch(tile)
		check(str(hud.active_section) == "character", "a tile tap opens its window")
	if str(hud.active_section) != "": hud.call("_close_workspace")
	await frames(3)
	await original_order_and_save(hud)
	await dropdown(hud)
	await finish(world)

## Any OptionButton popup (OptionButton, MenuButton, PopupMenu) on the actual
## HUD, through popup_touch_bridge.gd: a row tap selects it, a tap outside
## closes it and reaches the control under the finger.
func dropdown(hud: Node) -> void:
	var host: Control = hud.get_node("Root")
	var choice := OptionButton.new(); choice.name = "TouchProbeChoice"
	for label: String in ["가","나","다","라"]: choice.add_item(label)
	choice.position = Vector2(300, 200); choice.size = Vector2(220, 44)
	var other := Button.new(); other.name = "TouchProbeOther"; other.text = "X"
	other.position = Vector2(700, 120); other.size = Vector2(60, 44)
	var presses: Array[int] = [0]
	other.pressed.connect(func() -> void: presses[0] += 1)
	host.add_child(choice); host.add_child(other)
	choice.z_index = 300; other.z_index = 300
	await frames(2)
	await touch(choice)
	var popup: PopupMenu = choice.get_popup()
	check(popup.visible, "a touch opens the OptionButton list")
	var row: Vector2 = root.get_final_transform() * (Vector2(popup.position) + Vector2(popup.size.x * 0.5, popup.size.y * (2.5 / 4.0)))
	await touch_at(row)
	check(choice.selected == 2 and not popup.visible, "a touch on a row selects it and closes the list (selected %d)" % choice.selected)
	await touch(choice)
	check(popup.visible, "the list opens again")
	await touch(other)
	check(not popup.visible and presses[0] == 1, "a touch outside closes the list and presses the control under it (presses %d)" % presses[0])
	await touch(other)
	check(presses[0] == 2, "with no list open a touch presses once (presses %d)" % presses[0])
	choice.queue_free(); other.queue_free()
	await frames(2)

func touch_at(at: Vector2) -> void:
	var down := InputEventScreenTouch.new(); down.index = 0; down.pressed = true; down.position = at
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventScreenTouch.new(); up.index = 0; up.pressed = false; up.position = at
	Input.parse_input_event(up)
	await frames(3)

func finish(world: Node) -> void:
	world.queue_free()
	await process_frame
	print("FULL_MENU_TOUCH_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

## User list 2026-11-21 #3 / #18: the tiles follow the original 523 전체 메뉴
## order (MainMenuUIButtons: 제작, 거래소, 변신, 마법인형, 성물, ...), the
## TWILIGHT-only ones after them, and a 저장 tile runs the manual save.
func original_order_and_save(hud: Node) -> void:
	hud.toggle_menu(); await frames(5)
	var ids: Array[String] = []
	for tile: Control in hud.menu_tiles: ids.append(str(tile.name).trim_prefix("MenuTile_"))
	var order: Array = hud.get_script().get_script_constant_map().get("ORIGINAL_MENU_ORDER", [])
	check(ids.slice(0, 5) == ["crafting","exchange","변신","마법인형","성물"], "the menu starts like the original grid: " + str(ids.slice(0, 6)))
	var positions: Array[int] = []
	for id: String in order:
		if ids.has(id): positions.append(ids.find(id))
	var sorted_positions: Array[int] = positions.duplicate(); sorted_positions.sort()
	check(positions == sorted_positions and positions.size() >= 18, "every original-tile section keeps the client's order")
	check(ids.find("character") > ids.find("monsterbook523"), "TWILIGHT-only tiles come after the original ones")
	# The real save handler is held off (CI shares user://); only the signal is counted.
	var held: Array = hud.save_pressed.get_connections()
	for connection: Dictionary in held: hud.save_pressed.disconnect(connection.callable)
	var saved: Array = [0]
	var on_save := func() -> void: saved[0] += 1
	hud.save_pressed.connect(on_save)
	var save: Button = hud.workspace.find_child("MenuTile_save", true, false) as Button
	check(save != null, "a 저장 tile is in the menu")
	if save != null:
		hud.menu_scroll_view.ensure_control_visible(save); await frames(3)
		await touch(save)
		check(int(saved[0]) == 1, "the 저장 tile runs the manual save once")
	hud.save_pressed.disconnect(on_save)
	for connection: Dictionary in held: hud.save_pressed.connect(connection.callable)
	if str(hud.active_section) != "": hud.call("_close_workspace")
	await frames(3)
