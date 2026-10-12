extends Control

const UI = preload("res://scripts/ui/renewal_theme.gd")
var committed: bool = false
var confirm_button: Button
var cancel_button: Button
var quantity: SpinBox
var panel: PanelContainer
var callback: Callable
var previous_focus: Control

func configure(title: String, description: String, action: String, accept: Callable, maximum: int = 0) -> void:
	name = "TwilightConfirmation"
	z_index = 400
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	callback = accept
	previous_focus = get_viewport().gui_get_focus_owner()
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.48)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",UI.chrome_panel(Color("211d17"),UI.GOLD,18))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",16)
	panel.add_child(col)
	col.add_child(UI.label(title,19,UI.GOLD))
	col.add_child(HSeparator.new())
	var body := UI.label(description,14,UI.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	if maximum > 0:
		quantity = SpinBox.new()
		quantity.name = "ConfirmationQuantity"
		quantity.min_value = 1
		quantity.max_value = maximum
		quantity.step = 1
		quantity.value = 1
		quantity.custom_minimum_size.y = 38
		col.add_child(quantity)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	cancel_button = UI.button("취소",dismiss,Vector2(130,42))
	cancel_button.name = "CancelTransaction"
	row.add_child(cancel_button)
	confirm_button = UI.button(action,_accept,Vector2(130,42))
	confirm_button.name = "ConfirmTransaction"
	row.add_child(confirm_button)
	get_viewport().size_changed.connect(_fit)
	call_deferred("_fit")
	cancel_button.grab_focus()

func _fit() -> void:
	panel.size = Vector2(minf(460,size.x-32),0)
	panel.position = (size-panel.size)*.5

func _accept() -> void:
	if committed: return
	committed = true
	confirm_button.disabled = true
	var count: int = int(quantity.value) if quantity != null else 1
	# Hide before the callback can replace the originating shop/warehouse view.
	hide()
	# Release the stable modal name before a quantity step opens its confirmation.
	name = "CompletedConfirmation"
	queue_free()
	if callback.is_valid(): callback.call(count)

func dismiss() -> void:
	committed = true
	hide()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()
	queue_free()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		dismiss()
		get_viewport().set_input_as_handled()
