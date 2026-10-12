extends VBoxContainer

# Geometry adapter: original selection handlers and action signals stay intact.
const UI = preload("res://scripts/ui/renewal_theme.gd")
var panes: HBoxContainer
var tabs: HBoxContainer
var listing: Control
var details: Control
var detail_active: bool = false
var detail_width: float = 280
var touch_index: int = -1
var touch_distance: float = 0
var touch_dragged: bool = false

func configure(list_control: Control, detail_control: Control, width: float = 280) -> void:
	listing = list_control
	details = detail_control
	detail_width = width
	tabs = HBoxContainer.new()
	tabs.name = "BrowserCompactTabs"
	tabs.add_child(UI.button("목록",func() -> void: detail_active=false; reflow(),Vector2(104,34)))
	tabs.add_child(UI.button("선택 상세",func() -> void: detail_active=true; reflow(),Vector2(104,34)))
	add_child(tabs)
	panes = HBoxContainer.new()
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_theme_constant_override("separation",12)
	add_child(panes)
	listing.reparent(panes)
	details.reparent(panes)
	resized.connect(reflow)
	reflow()

func reflow() -> void:
	if listing == null: return
	var compact: bool = size.x < 660
	tabs.visible = compact
	listing.visible = not compact or not detail_active
	details.visible = not compact or detail_active
	details.custom_minimum_size.x = 0 if compact else detail_width
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	(tabs.get_child(0) as Button).disabled = not detail_active
	(tabs.get_child(1) as Button).disabled = detail_active

func enable_item_touch() -> void:
	listing.gui_input.connect(_item_touch_start)
func _item_touch_start(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not event.canceled and touch_index == -1:
		touch_index = event.index
		touch_distance = 0
		touch_dragged = false
func _input(event: InputEvent) -> void:
	if touch_index == -1 or not listing.is_visible_in_tree(): return
	var items: ItemList = listing as ItemList
	if event is InputEventScreenDrag and event.index == touch_index:
		touch_distance += event.relative.length()
		if touch_distance > 8:
			touch_dragged = true
			var scrollbar: VScrollBar = items.get_v_scroll_bar()
			scrollbar.value = clampf(scrollbar.value-event.relative.y,scrollbar.min_value,maxf(scrollbar.min_value,scrollbar.max_value-scrollbar.page))
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == touch_index and (not event.pressed or event.canceled):
		touch_index = -1
		get_viewport().set_input_as_handled()
		var local_point: Vector2 = items.get_global_transform_with_canvas().affine_inverse()*event.position
		if not event.canceled and not touch_dragged and Rect2(Vector2.ZERO,items.size).has_point(local_point):
			var index: int = items.get_item_at_position(local_point,true)
			if index >= 0:
				items.select(index)
				items.item_selected.emit(index)
