extends Button
class_name TwilightGroundLoot

const VISUAL = preload("res://scripts/loot/drop_visual.gd")
var loot_id: String = ""
var visible_since: int = 0
var visual: TwilightDropVisual

func configure(record: Dictionary, icon: Texture2D, slot: String) -> void:
	loot_id = str(record["id"])
	name = "GroundLoot_" + loot_id
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(56, 52)
	size = custom_minimum_size
	position = Vector2(float(record["position"][0]), float(record["position"][1])) - Vector2(28, 36)
	z_index = 20
	visible_since = Time.get_ticks_msec()
	for key: String in ["id", "item_name", "grade", "quantity"]:
		set_meta(key, record[key])
	set_meta("world_position", Vector2(float(record["position"][0]), float(record["position"][1])))
	tooltip_text = "%s · %s ×%d · 선택 후 다시 눌러 줍기" % [record["item_name"], record["grade"], record["quantity"]]
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, empty)
	visual = VISUAL.new()
	visual.position = Vector2(28, 36)
	visual.configure(str(record["grade"]), icon, slot)
	add_child(visual)

func set_selected(value: bool) -> void:
	visual.selected = value
	visual.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	# Native touch is independent of desktop mouse emulation.
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and not event.canceled:
			pressed.emit()
		accept_event()
