extends "res://scripts/ui/native_touch_button.gd"
## Native tap ownership + explicit forwarding: accepting _gui_input prevents the
## generic gui_input signal from resetting a previous scroll gesture.
var scroll_host: Node
var scroll_area: ScrollContainer
signal feedback_changed(active: bool)
var feedback_active: bool = false

func _feedback(active: bool) -> void:
	if active==feedback_active: return
	feedback_active=active
	feedback_changed.emit(active)
	queue_redraw()

func _cancel_touch() -> void:
	super._cancel_touch()
	_feedback(false)

func _gui_input(event: InputEvent) -> void:
	if scroll_host != null and event is InputEventScreenTouch and event.pressed and finger == -1 and not disabled:
		scroll_host._on_scroll_drag_input(event,scroll_area,self)
	super._gui_input(event)
	_feedback(finger!=-1 and not moved)

func _input(event: InputEvent) -> void:
	if finger != -1 and event is InputEventScreenDrag and event.index == finger:
		moved = moved or event.position.distance_to(touch_origin) > 8.0
		_feedback(not moved)
		if scroll_host != null: scroll_host._scroll_gesture_motion(event.relative.y)
		get_viewport().set_input_as_handled()
		return
	if finger != -1 and scroll_host != null and event is InputEventScreenTouch and event.index == finger and (not event.pressed or event.canceled):
		scroll_host._on_scroll_drag_input(event,scroll_area,self)
	super._input(event)
	_feedback(finger!=-1 and not moved)

func _draw() -> void:
	if feedback_active:
		draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color(1,.86,.58,.45),false,1)
