extends Control
class_name TwilightVirtualJoystick

signal vector_changed(value: Vector2)

var active_touch: int = -1
var value: Vector2 = Vector2.ZERO
var mouse_active: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and active_touch == -1:
			active_touch = touch.index
			_update_value(_viewport_to_local(touch.position))
			accept_event()
		elif not touch.pressed and touch.index == active_touch:
			active_touch = -1
			_set_value(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == active_touch:
			_update_value(_viewport_to_local(drag.position))
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			mouse_active = mouse_button.pressed
			if mouse_active:
				# Mouse events received by Control._gui_input() are already local.
				_update_value(mouse_button.position)
			else:
				_set_value(Vector2.ZERO)
			accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		var motion: InputEventMouseMotion = event
		# Mouse motion received by Control._gui_input() is already local.
		_update_value(motion.position)
		accept_event()

func _viewport_to_local(viewport_pos: Vector2) -> Vector2:
	# Native touch events keep viewport coordinates even in Control._gui_input().
	# Convert through the full canvas transform so the joystick remains correct
	# with CanvasLayer, camera and stretch transforms on Android.
	return get_global_transform_with_canvas().affine_inverse() * viewport_pos

func _update_value(local_pos: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.38
	if radius <= 1.0:
		return
	_set_value((local_pos - center) / radius)

func _set_value(next_value: Vector2) -> void:
	value = next_value.limit_length(1.0)
	vector_changed.emit(value)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.38
	draw_circle(center, radius, Color(0.04, 0.04, 0.05, 0.48))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.72, 0.62, 0.39, 0.85), 3.0)
	var knob: Vector2 = center + value * radius * 0.72
	draw_circle(knob, radius * 0.34, Color(0.70, 0.62, 0.47, 0.78))
	draw_arc(knob, radius * 0.34, 0.0, TAU, 32, Color(0.95, 0.89, 0.72, 0.9), 2.0)
