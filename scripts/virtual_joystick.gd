extends Control
class_name TwilightVirtualJoystick

signal vector_changed(value: Vector2)

const DEAD_ZONE: float = 0.16
const DIRECTION_STEP: float = PI / 4.0

var active_touch: int = -1
var value: Vector2 = Vector2.ZERO
var mouse_active: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_EXIT_TREE:
			_release_pointer()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_release_pointer()
		NOTIFICATION_RESIZED:
			_release_pointer()
			queue_redraw()

func _release_pointer() -> void:
	active_touch = -1
	mouse_active = false
	_set_value(Vector2.ZERO)

func _gui_input(event: InputEvent) -> void:
	# GUI dispatch already transforms positions to this Control's local space,
	# including captured drags outside its rect. Never guess the coordinate space
	# from whether the point is inside: that double-transform reverses directions.
	# https://docs.godotengine.org/en/4.7/classes/class_control.html#class-control-private-method-gui-input
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if (touch.canceled or not touch.pressed) and touch.index == active_touch:
			_release_pointer()
		elif touch.pressed and not touch.canceled and active_touch == -1 and not mouse_active:
			active_touch = touch.index
			_update_value(touch.position)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == active_touch:
			_update_value(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			# One pointer owns the stick. Emulated or simultaneous mouse events must
			# not reset a native contact that is still down.
			if active_touch != -1:
				accept_event()
				return
			mouse_active = mouse_button.pressed and not mouse_button.canceled
			if mouse_active:
				_update_value(mouse_button.position)
			else:
				_set_value(Vector2.ZERO)
			accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		var motion: InputEventMouseMotion = event
		_update_value(motion.position)
		accept_event()

func _update_value(local_pos: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.38
	if radius <= 1.0:
		return
	var raw: Vector2 = (local_pos - center) / radius
	if raw.length() < DEAD_ZONE:
		_set_value(Vector2.ZERO)
		return

	# Player movement uses a normalized vector, so snap the stick angle to
	# 45-degree increments. This gives reliable 8-direction movement including
	# all four diagonals on touch and mouse.
	var angle: float = raw.angle()
	var snapped_angle: float = roundf(angle / DIRECTION_STEP) * DIRECTION_STEP
	_set_value(Vector2(cos(snapped_angle), sin(snapped_angle)))

func _set_value(next_value: Vector2) -> void:
	var normalized: Vector2 = next_value.limit_length(1.0)
	var changed: bool = not value.is_equal_approx(normalized)
	value = normalized
	vector_changed.emit(value)
	if changed:
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.38
	draw_circle(center, radius, Color(0.04, 0.04, 0.05, 0.48))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.72, 0.62, 0.39, 0.85), 3.0)
	var knob: Vector2 = center + value * radius * 0.72
	draw_circle(knob, radius * 0.34, Color(0.70, 0.62, 0.47, 0.78))
	draw_arc(knob, radius * 0.34, 0.0, TAU, 32, Color(0.95, 0.89, 0.72, 0.9), 2.0)
