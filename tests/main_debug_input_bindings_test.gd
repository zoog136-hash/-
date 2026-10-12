extends SceneTree

var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func matches(action: String, code: Key) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return InputMap.event_is_action(event, action)

func _initialize() -> void:
	check(matches("move_left", KEY_LEFT), "Left arrow moves left")
	check(matches("move_right", KEY_RIGHT), "Right arrow moves right")
	check(matches("move_up", KEY_UP), "Up arrow remains unchanged")
	check(matches("move_down", KEY_DOWN), "Down arrow remains unchanged")
	check(matches("move_left", KEY_A), "A remains bound")
	check(matches("move_right", KEY_D), "D remains bound")
	check(matches("move_up", KEY_W), "W remains bound")
	check(matches("move_down", KEY_S), "S remains bound")
	check(matches("open_map", KEY_TAB), "Tab opens map")
	check(matches("save_game", KEY_F5), "F5 saves as documented")
	check(matches("load_game", KEY_F9), "F9 loads as documented")
	check(not matches("load_game", KEY_F5), "F5 must never trigger load")
	check(not matches("move_left", KEY_INSERT), "Insert must not move left")
	check(not matches("move_right", KEY_PAUSE), "Pause must not move right")
	if failures.is_empty():
		print("MAIN_DEBUG_INPUT_BINDINGS_OK")
	else:
		for failure: String in failures:
			print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
