extends "res://scripts/ui/native_touch_button.gd"
## Native tap ownership + explicit forwarding: accepting _gui_input prevents the
## generic gui_input signal from resetting a previous scroll gesture.
var scroll_host: Node
var scroll_area: ScrollContainer

func _gui_input(event: InputEvent) -> void:
	if scroll_host != null and event is InputEventScreenTouch and event.pressed and finger == -1 and not disabled:
		scroll_host._on_scroll_drag_input(event,scroll_area,self)
	super._gui_input(event)

func _input(event: InputEvent) -> void:
	if finger != -1 and event is InputEventScreenDrag and event.index == finger:
		moved = moved or event.position.distance_to(touch_origin) > 8.0
		if scroll_host != null: scroll_host._scroll_gesture_motion(event.relative.y)
		get_viewport().set_input_as_handled()
		return
	if finger != -1 and scroll_host != null and event is InputEventScreenTouch and event.index == finger and (not event.pressed or event.canceled):
		scroll_host._on_scroll_drag_input(event,scroll_area,self)
	super._input(event)
