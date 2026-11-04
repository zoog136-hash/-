extends "res://scripts/ui/renewal_confirmation.gd"
## Scrollable multi-item cart; uses the existing modal's single-commit/cancel flow.
var cart_scroll: ScrollContainer
const TouchButton = preload("res://scripts/ui/native_touch_button.gd")

func configure(title: String, description: String, action: String, accept: Callable, maximum: int = 0) -> void:
	super.configure(title,description,action,accept,maximum)
	for button: Button in [confirm_button,cancel_button]:
		button.set_script(TouchButton)
		# The base modal already added these nodes to the tree before attaching
		# the touch script. Enable its global release handler explicitly.
		button.set_process_input(true)
		var cancel: Callable = Callable(button,"_cancel_touch")
		if not button.visibility_changed.is_connected(cancel): button.visibility_changed.connect(cancel)
		if not get_window().focus_exited.is_connected(cancel): get_window().focus_exited.connect(cancel)
	var col: VBoxContainer = panel.get_child(0)
	var body: Label = col.get_child(2)
	col.remove_child(body)
	cart_scroll = ScrollContainer.new()
	cart_scroll.name = "AutoCartScroll"
	cart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(cart_scroll)
	col.move_child(cart_scroll,2)
	cart_scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _fit() -> void:
	if cart_scroll != null:
		cart_scroll.custom_minimum_size = Vector2(0,clampf(size.y-250,80,300))
	super._fit()
