extends RefCounted
## Touch for every popup list (OptionButton / MenuButton / PopupMenu).
##
## The project runs with input_devices/pointing/emulate_mouse_from_touch off
## (native touch buttons). A PopupMenu only reads mouse events, and while it is
## open the root window hands every other event to it: on Android an opened
## dropdown ignored its rows, never closed, and swallowed each tap on the
## screen, a window's close X included (user report 2026-11-19, 전체 메뉴).
##
## While a PopupMenu is open, each real finger event on the root window is
## also given as the matching mouse event (press/release/drag). The popup then
## behaves as with a mouse: a row tap selects it, a tap outside closes it and
## reaches the control under the finger, a drag scrolls a long list. Nothing
## changes while no popup is open. Emulated touches (made from the mouse by
## emulate_touch_from_mouse) are left alone, so a mouse is never doubled.
static var _installed: WeakRef = null
static var _finger: int = -1

static func install(window: Window) -> void:
	if window == null: return
	if _installed != null and _installed.get_ref() == window: return
	_installed = weakref(window)
	_finger = -1
	window.window_input.connect(_on_window_input.bind(weakref(window)))

static func popup_open(window: Window) -> bool:
	if window == null: return false
	# Only the open embedded windows (a few at most), not the whole tree.
	for sub: Window in window.get_embedded_subwindows():
		if sub is PopupMenu and sub.visible: return true
	return false

static func _on_window_input(event: InputEvent, window_ref: WeakRef) -> void:
	var window: Window = window_ref.get_ref() as Window
	if window == null: return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.device == InputEvent.DEVICE_ID_EMULATION: return
		if touch.pressed and not touch.canceled:
			if _finger != -1 or not popup_open(window): return
			_finger = touch.index
			Input.parse_input_event(mouse_button(touch.position, true))
		elif touch.index == _finger:
			_finger = -1
			Input.parse_input_event(mouse_button(touch.position, false))
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.device == InputEvent.DEVICE_ID_EMULATION or drag.index != _finger: return
		var motion := InputEventMouseMotion.new()
		motion.position = drag.position
		motion.global_position = drag.position
		motion.relative = drag.relative
		motion.velocity = drag.velocity
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)

static func mouse_button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.global_position = at
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return button
