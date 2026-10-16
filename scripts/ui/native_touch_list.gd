extends ItemList

# Select on release, not press. A scroll/cancel never commits a destination.
var finger: int = -1
var touch_origin: Vector2
var touch_last: Vector2
var touch_row: int = -1
var touch_identity: Variant
var touch_text: String = ""
var scrolling: bool = false

func _ready() -> void:
	get_window().focus_exited.connect(_cancel_touch)
	visibility_changed.connect(_cancel_touch)
	resized.connect(_cancel_touch)

func _cancel_touch() -> void:
	finger = -1
	touch_row = -1
	scrolling = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed and not event.canceled:
		if finger != -1:
			accept_event()
			return
		finger = event.index
		touch_origin = get_global_transform_with_canvas() * event.position
		touch_last = touch_origin
		touch_row = get_item_at_position(event.position, true)
		touch_identity = get_item_metadata(touch_row) if touch_row >= 0 else null
		touch_text = get_item_text(touch_row) if touch_row >= 0 else ""
		scrolling = false
		accept_event()

func _input(event: InputEvent) -> void:
	if finger == -1: return
	if not is_visible_in_tree():
		_cancel_touch()
		return
	if event is InputEventScreenDrag and event.index == finger:
		if event.position.distance_to(touch_origin) > 10.0: scrolling = true
		if scrolling:
			var scale_y: float = get_global_transform_with_canvas().y.length()
			get_v_scroll_bar().value -= (event.position.y-touch_last.y) / maxf(scale_y, 0.01)
		touch_last = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == finger and (not event.pressed or event.canceled):
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var row: int = get_item_at_position(local, true)
		var commit: bool = not event.canceled and not scrolling and event.position.distance_to(touch_origin) <= 10.0 and Rect2(Vector2.ZERO,size).has_point(local) and row == touch_row and row >= 0 and row < item_count and not is_item_disabled(row) and get_item_metadata(row) == touch_identity and get_item_text(row) == touch_text
		_cancel_touch()
		get_viewport().set_input_as_handled()
		if commit:
			select(row)
			item_selected.emit(row)
