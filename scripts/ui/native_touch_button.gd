extends Button

var finger: int = -1
var touch_origin: Vector2
var moved: bool = false

func _ready() -> void:
	get_window().focus_exited.connect(_cancel_touch)
	visibility_changed.connect(_cancel_touch)

func _cancel_touch() -> void:
	finger = -1
	moved = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed and not event.canceled:
		if finger == -1 and not disabled:
			finger = event.index
			touch_origin = get_global_transform_with_canvas() * event.position
			moved = false
		accept_event()

func _input(event: InputEvent) -> void:
	if finger == -1: return
	if not is_visible_in_tree() or disabled:
		_cancel_touch()
		return
	if event is InputEventScreenDrag and event.index == finger:
		moved = moved or event.position.distance_to(touch_origin) > 12.0
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == finger and (not event.pressed or event.canceled):
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var commit: bool = not event.canceled and not moved and event.position.distance_to(touch_origin) <= 12.0 and Rect2(Vector2.ZERO,size).has_point(local)
		_cancel_touch()
		get_viewport().set_input_as_handled()
		if commit:
			if toggle_mode: set_pressed(not button_pressed)
			pressed.emit()
