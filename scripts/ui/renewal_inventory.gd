extends "res://scripts/ui/lineage_inventory_ui.gd"

const UI = preload("res://scripts/ui/renewal_theme.gd")
var sort_mode: int = 0
var inventory_fingerprint: String = ""
var weight_readout: Label
var weight_gauge: ProgressBar
var compact_tabs: HBoxContainer
var detail_active: bool = false
var inventory_left: Control
var grid_scroll: ScrollContainer
var gesture_index: int = -1
var gesture_mouse: bool = false
var gesture_distance: float = 0
var gesture_dragged: bool = false
var gesture_reference: String = ""
var gesture_button: Control
var gesture_origin: Vector2 = Vector2.ZERO
var gesture_last: Vector2 = Vector2.ZERO
var gesture_horizontal: float = 0.0
var gesture_equipping: bool = false

func _ready() -> void:
	super._ready()
	theme = UI.make_theme()
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.add_theme_stylebox_override("panel",UI.box(Color("0e1117"),UI.BRONZE,8))
	var header: HBoxContainer = inventory_panel.get_child(0).get_child(0)
	(header.get_child(0) as Label).text = "소지품"
	(header.get_child(0) as Label).add_theme_font_size_override("font_size",15)
	header.custom_minimum_size.y = 36
	(header.get_child(header.get_child_count()-1) as Button).hide()
	var sorter := OptionButton.new()
	sorter.name = "InventorySort"
	for label: String in ["이름순","등급순","수량순"]: sorter.add_item(label)
	sorter.item_selected.connect(func(index: int) -> void: sort_mode=index; _refresh_inventory_grid())
	header.add_child(sorter)
	search_line.custom_minimum_size = Vector2(110,34)
	detail_panel.custom_minimum_size.x = 260
	for b: Button in tab_buttons.values(): b.custom_minimum_size.x = 82
	weight_readout = UI.label("",11,UI.MUTED)
	(inventory_panel.get_child(0) as VBoxContainer).add_child(weight_readout)
	weight_gauge = ProgressBar.new()
	weight_gauge.name = "InventoryWeight"
	weight_gauge.show_percentage = false
	weight_gauge.custom_minimum_size.y = 7
	(inventory_panel.get_child(0) as VBoxContainer).add_child(weight_gauge)
	inventory_left = item_grid.get_parent().get_parent()
	grid_scroll = item_grid.get_parent()
	grid_scroll.name = "InventoryGridScroll"
	compact_tabs = HBoxContainer.new()
	compact_tabs.name = "InventoryCompactTabs"
	compact_tabs.add_child(UI.button("소지품 목록",func() -> void: detail_active=false; _reflow(),Vector2(112,34)))
	compact_tabs.add_child(UI.button("선택 상세",func() -> void: detail_active=true; _reflow(),Vector2(112,34)))
	var layout: VBoxContainer = inventory_panel.get_child(0)
	layout.add_child(compact_tabs)
	layout.move_child(compact_tabs,3)
	resized.connect(_reflow)
	_reflow()

func _reflow() -> void:
	if grid_scroll == null: return
	var compact: bool = inventory_panel.size.x < 720
	compact_tabs.visible = compact
	inventory_left.visible = not compact or not detail_active
	detail_panel.visible = not compact or detail_active
	detail_panel.custom_minimum_size.x = 0 if compact else 260
	var width: float = inventory_panel.size.x-26-(0 if compact else 270)
	item_grid.columns = clampi(floori(width/77.0),2,7)
	for button: Button in tab_buttons.values(): button.custom_minimum_size.x = 68

# Swipe a slot horizontally to equip; vertical gestures remain native scrolling.
# We emit the same authoritative inventory signal as the visible detail button.
func _gesture_start(event: InputEvent, reference: String, button: Control) -> void:
	if event is InputEventScreenTouch and event.pressed and not event.canceled and gesture_index == -1:
		gesture_index = event.index
		gesture_mouse = false
		gesture_origin = event.position
		gesture_last = event.position
		gesture_distance = 0.0
		gesture_horizontal = 0.0
		gesture_dragged = false
		gesture_equipping = false
		gesture_reference = reference
		gesture_button = button
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		gesture_mouse = true
		gesture_origin = event.position
		gesture_last = event.position
		gesture_distance = 0.0
		gesture_horizontal = 0.0
		gesture_dragged = false
		gesture_equipping = false
		gesture_reference = reference
		gesture_button = button

func _activate_dragged_equipment(reference: String) -> void:
	if reference.is_empty(): return
	var record: Dictionary = _find_item_record(reference)
	var slot: String = str(record.get("slot", ""))
	# Never use/purchase a potion because someone scrolled the inventory.
	gesture_dragged = false
	_select_item(reference)
	if not slot.is_empty() and slot not in ["none", "consumable", "material"]:
		item_activate_requested.emit(reference)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not inventory_panel.visible:
		gesture_index = -1
		gesture_mouse = false
		return
	var drag_delta: Vector2 = Vector2.ZERO
	if event is InputEventScreenDrag and event.index == gesture_index:
		drag_delta = event.relative
		gesture_last = event.position
	elif event is InputEventMouseMotion and gesture_mouse and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		drag_delta = event.relative
		gesture_last = event.position
	if drag_delta != Vector2.ZERO:
		gesture_horizontal += absf(drag_delta.x)
		gesture_distance += absf(drag_delta.y)
		var net: Vector2 = gesture_last - gesture_origin
		if gesture_equipping or (net.x > 72.0 and net.x > absf(net.y) * 1.2):
			gesture_dragged = true
			gesture_equipping = true
			get_viewport().set_input_as_handled()
		elif not gesture_equipping and gesture_distance > 8.0 and gesture_distance >= gesture_horizontal:
			gesture_dragged = true
			var bar: VScrollBar = grid_scroll.get_v_scroll_bar()
			grid_scroll.scroll_vertical = clampi(grid_scroll.scroll_vertical - roundi(drag_delta.y), 0, maxi(0, ceili(bar.max_value - bar.page)))
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == gesture_index and (not event.pressed or event.canceled):
		var was_equip: bool = gesture_equipping and not event.canceled
		var tapped: bool = not gesture_dragged and not event.canceled and is_instance_valid(gesture_button)
		if tapped:
			var local_point: Vector2 = gesture_button.get_global_transform_with_canvas().affine_inverse() * event.position
			tapped = Rect2(Vector2.ZERO, gesture_button.size).has_point(local_point)
		var reference: String = gesture_reference
		gesture_index = -1
		gesture_button = null
		gesture_equipping = false
		get_viewport().set_input_as_handled()
		if was_equip: _activate_dragged_equipment(reference)
		elif tapped: _select_item(reference)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and gesture_mouse:
		var was_equip: bool = gesture_equipping
		var reference: String = gesture_reference
		gesture_mouse = false
		gesture_button = null
		gesture_equipping = false
		if was_equip:
			get_viewport().set_input_as_handled()
			_activate_dragged_equipment(reference)
		elif gesture_dragged: get_viewport().set_input_as_handled()

func _select_item(item_name: String) -> void:
	if gesture_dragged: return
	super._select_item(item_name)
	detail_active = true
	_reflow()

func show_inventory() -> void:
	gesture_dragged = false
	detail_active = false
	super.show_inventory()
	_reflow()

func _slot_style_for_grade(grade: String, selected: bool) -> StyleBoxFlat:
	return UI.item_frame(grade,selected)

func _find_item_record(item_name: String) -> Dictionary:
	var instance_id: String = _ref_instance_id(item_name)
	if instance_id != "":
		var all_instances: Variant = character_state.get("item_instances", {})
		if all_instances is Dictionary:
			var item_data: Variant = (all_instances as Dictionary).get(instance_id, {})
			if item_data is Dictionary:
				var identified: Variant = (item_data as Dictionary).get("record", {})
				if identified is Dictionary and not (identified as Dictionary).is_empty() and str((identified as Dictionary).get("name", "")) == _base_item_name(item_name):
					return identified as Dictionary
	return super._find_item_record(item_name)

func _icon_for_reference(record: Dictionary, name_value: String, item_reference: String) -> Texture2D:
	if _ref_instance_id(item_reference) != "" and str(record.get("sourceId", "")) != "":
		var path: String = str(record.get("image_path", ""))
		if path != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return UI.item_icon(record, name_value, item_image_index.get("아이템", {}))

func _grade_color(value: String) -> Color:
	return UI.grade(value)

func set_inventory(value: Dictionary) -> void:
	if inventory == value:
		return
	super.set_inventory(value)

func set_character_state(value: Dictionary) -> void:
	var fingerprint := JSON.stringify([value.get("gold",0),value.get("equipped_items",{}),value.get("enhancement_levels",{}),value.get("item_instances",{})])
	character_state = value.duplicate(true)
	_refresh_weight()
	if fingerprint == inventory_fingerprint:
		return
	inventory_fingerprint = fingerprint
	gold_label.text = "아데나  "+_format_number(int(value.get("gold",0)))
	_refresh_inventory_grid()
	if selected_item != "":
		_refresh_detail(selected_item)

func _refresh_inventory_grid() -> void:
	super._refresh_inventory_grid()
	var references: Array = slot_buttons.keys()
	if sort_mode == 1:
		references.sort_custom(func(a: String, b: String) -> bool:
			var left_name: String = _base_item_name(a)
			var right_name: String = _base_item_name(b)
			var left_grade: int = UI.GRADES.keys().find(str(_find_item_record(a).get("grade", "일반")))
			var right_grade: int = UI.GRADES.keys().find(str(_find_item_record(b).get("grade", "일반")))
			return a < b if left_grade == right_grade else left_grade > right_grade)
	elif sort_mode == 2:
		references.sort_custom(func(a: String, b: String) -> bool:
			var left_count: int = 1 if _ref_instance_id(a) != "" else int(inventory.get(_base_item_name(a), 0))
			var right_count: int = 1 if _ref_instance_id(b) != "" else int(inventory.get(_base_item_name(b), 0))
			return a < b if left_count == right_count else left_count > right_count)
	else:
		references.sort()
	for index: int in range(references.size()):
		var reference: String = str(references[index])
		var item_name: String = _base_item_name(reference)
		var button: Button = slot_buttons[reference] as Button
		item_grid.move_child(button, index)
		var record: Dictionary = _find_item_record(reference)
		var texture: Texture2D = _icon_for_reference(record, item_name, reference)
		button.icon = null
		button.text = ""
		button.custom_minimum_size = Vector2(72,82)
		button.gui_input.connect(_gesture_start.bind(reference,button))
		button.tooltip_text += " · 아이콘을 오른쪽으로 끌면 장착/사용"
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(7,7)
		icon.size = Vector2(58,54)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var shown_name: String = _display_item_name(record, reference)
		var caption := UI.label(shown_name.left(6) + "…" if shown_name.length() > 7 else shown_name, 11)
		caption.position = Vector2(3,61)
		caption.size = Vector2(66,18)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.clip_text = true
		button.add_child(caption)
		var level: int = _enhance_level(reference)
		var badge := UI.label("+%d" % level if level > 0 else "", 12, UI.GOLD)
		badge.position = Vector2(5, 2)
		button.add_child(badge)
		var equipped: bool = _is_item_equipped(reference)
		var amount: int = 1 if _ref_instance_id(reference) != "" else int(inventory.get(item_name, 0))
		var count := UI.label("E" if equipped else "×%d" % amount, 12, UI.GOLD if equipped else UI.TEXT)
		count.position = Vector2(33,40)
		count.size = Vector2(36,20)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(count)
		if _ref_instance_id(reference) != "":
			button.tooltip_text += " · 개체 ID:" + _ref_instance_id(reference)
	_refresh_weight()
	_reflow()

func _refresh_weight() -> void:
	if weight_readout != null:
		var current_weight: float = float(character_state.get("current_weight", 0))
		var max_weight: float = float(character_state.get("max_weight", character_state.get("carrying_capacity", 0)))
		var ratio: float = 100*current_weight/maxf(1,max_weight)
		weight_readout.text = "무게  %.0f / %.0f  (%.1f%%)" % [current_weight,max_weight,ratio]
		weight_gauge.value = minf(100,ratio)

func _refresh_detail(item_reference: String) -> void:
	super._refresh_detail(item_reference)
	var item_name: String = _base_item_name(item_reference)
	var selected_id: String = _ref_instance_id(item_reference)
	var item: Dictionary = _find_item_record(item_reference)
	detail_icon.texture = _icon_for_reference(item, item_name, item_reference)
	var slot: String = str(item.get("slot", ""))
	var worn: Dictionary = character_state.get("equipped_items", {})
	var current: Variant = worn.get(slot, {})
	if current is Dictionary and not (current as Dictionary).is_empty() and str((current as Dictionary).get("name", "")) != item_name:
		detail_text.text += "\n\n[color=#d8b878]착용 장비와 비교[/color]\n" + UI.safe((current as Dictionary).get("name", ""))
		for pair: Array in [["atk", "공격력"], ["def", "방어력"], ["hit", "명중"], ["hpFlat", "최대 HP"]]:
			var delta: int = int(item.get(pair[0], 0)) - int((current as Dictionary).get(pair[0], 0))
			if delta != 0:
				detail_text.text += "\n%s  %s%d" % [pair[1], "+" if delta > 0 else "", delta]
	if selected_id != "":
		detail_text.text += "\n[color=#d8b878]선택한 장비 ID: %s[/color]" % UI.safe(selected_id)
	if _is_item_equipped(item_reference):
		detail_action.tooltip_text = "선택된 장비 개체가 장착 중입니다. 현재 게임은 일반 장비 해제를 제공하지 않습니다."
	else:
		detail_action.tooltip_text = ""
