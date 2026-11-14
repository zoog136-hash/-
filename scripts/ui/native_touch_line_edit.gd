extends LineEdit
## Android runs with emulate_mouse_from_touch off (native touch buttons), so a
## plain LineEdit never sees a click and cannot be focused by a tap. A short tap
## on the field focuses it, starts editing and raises the on-screen keyboard.
var finger: int = -1
var touch_origin: Vector2

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch or event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event.pressed and not event.canceled:
		if finger == -1:
			finger = event.index
			touch_origin = event.position
	elif event.index == finger:
		var tap: bool = not event.canceled and event.position.distance_to(touch_origin) <= 16.0
		finger = -1
		if tap and editable and not is_editing():
			grab_focus()
			edit()
			accept_event()
