extends Button

signal activated
signal edit_requested
signal auto_requested
signal page_requested(direction: int)
signal entry_dropped(data: Dictionary)
var payload: Dictionary = {}
var contact: int = -1
var held: float = 0.0
var origin: Vector2
var delta_total: Vector2
var consumed: bool = false
var mouse_down: bool = false

func _ready() -> void:
	pressed.connect(func() -> void:
		if not consumed: activated.emit())

func _process(delta: float) -> void:
	if contact < 0 and not mouse_down: return
	held += delta
	if held >= 0.55 and not consumed and delta_total.length() < 12:
		consumed = true
		edit_requested.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			edit_requested.emit()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _start(event.position); mouse_down = true
			else: mouse_down = false
	elif event is InputEventMouseMotion and mouse_down:
		delta_total = event.position - origin
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled and contact < 0:
			contact = event.index
			_start(event.position)
		elif event.index == contact and (not event.pressed or event.canceled):
			contact = -1
			if not consumed and not event.canceled:
				if delta_total.y > 28 and absf(delta_total.y) > absf(delta_total.x): auto_requested.emit()
				elif absf(delta_total.x) > 35: page_requested.emit(-1 if delta_total.x > 0 else 1)
				elif delta_total.length() < 12: activated.emit()
			consumed = true
		accept_event()
	elif event is InputEventScreenDrag and event.index == contact:
		delta_total += event.relative
		accept_event()

func _start(point: Vector2) -> void:
	origin = point
	delta_total = Vector2.ZERO
	held = 0
	consumed = false

func _get_drag_data(_at_position: Vector2) -> Variant:
	if payload.is_empty(): return null
	consumed = true
	var preview := Label.new()
	preview.text = str(payload.get("id", "슬롯 이동"))
	set_drag_preview(preview)
	return payload.duplicate()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind", "") in ["skill", "item", "slot"]

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	entry_dropped.emit(data)
