extends RichTextLabel

# Capture a finger only while this text has overflow. Other gestures remain
# available to its enclosing inspector; this never activates an action.
var finger: int=-1
var origin: Vector2
var last: Vector2
var moved: bool=false

func _ready() -> void:
	bind_gestures()

func bind_gestures() -> void:
	if not visibility_changed.is_connected(_cancel_touch):visibility_changed.connect(_cancel_touch)
	if not get_window().focus_exited.is_connected(_cancel_touch):get_window().focus_exited.connect(_cancel_touch)
	set_process_input(false)

func _cancel_touch() -> void:
	finger=-1
	moved=false
	set_process_input(false)

func _gui_input(event: InputEvent) -> void:
	if not scroll_active or get_v_scroll_bar().max_value<=get_v_scroll_bar().page:return
	if event is InputEventScreenTouch and event.device!=InputEvent.DEVICE_ID_EMULATION and event.pressed and not event.canceled and finger==-1:
		finger=event.index
		origin=get_global_transform_with_canvas()*event.position
		last=origin
		moved=false
		set_process_input(true)
		accept_event()

func _input(event: InputEvent) -> void:
	if finger==-1:return
	if not is_visible_in_tree():_cancel_touch();return
	if event is InputEventScreenDrag and event.index==finger:
		moved=moved or event.position.distance_to(origin)>10.
		if moved:
			get_v_scroll_bar().value-=(event.position.y-last.y)/maxf(.01,get_global_transform_with_canvas().y.length())
		last=event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index==finger and (not event.pressed or event.canceled):
		_cancel_touch()
		get_viewport().set_input_as_handled()
