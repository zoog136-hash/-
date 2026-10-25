extends "res://scripts/ui/lineage_inventory_ui.gd"

const UI = preload("res://scripts/ui/renewal_theme.gd")
const NATIVE_BUTTON = preload("res://scripts/ui/native_touch_button.gd")
const ITEM_NAME_DURATION_MS: int = 5000
const ITEM_NAME_GAP: float = 4.0
var item_name_hint: Label
var item_name_reference: String = ""
var item_name_until: int = 0
var controller: Node
var search_row: HBoxContainer
var expand_button: Button
var lock_button: Button
var sort_mode: int = 0
var inventory_fingerprint: String = ""
var weight_readout: Label
var weight_gauge: ProgressBar
var compact_tabs: HBoxContainer
var detail_active: bool = false
var detail_layout_queued: bool = false
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
	item_grid.draw.connect(_draw_slot_recesses)
	item_grid.sort_children.connect(item_grid.queue_redraw)
	z_index = 1
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.add_theme_stylebox_override("panel",UI.box(Color("17140f"),Color("514131"),2))
	var layout: VBoxContainer = inventory_panel.get_child(0)
	layout.add_theme_constant_override("separation",3)
	var header: HBoxContainer = layout.get_child(0)
	var body: HBoxContainer = layout.get_child(3)
	inventory_left = body.get_child(0)
	grid_scroll = item_grid.get_parent()
	(inventory_left.get_child(1) as Control).custom_minimum_size.y = 22
	gold_label.add_theme_font_size_override("font_size",12)
	capacity_label.add_theme_font_size_override("font_size",11)
	grid_scroll.name = "InventoryGridScroll"
	grid_scroll.add_theme_stylebox_override("panel",UI.box(Color("15120f"),Color("4b3d2e"),5))
	item_grid.add_theme_constant_override("h_separation",8)
	item_grid.add_theme_constant_override("v_separation",8)
	item_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	search_row = HBoxContainer.new()
	layout.add_child(search_row)
	layout.move_child(search_row,2)
	search_line.reparent(search_row)
	search_line.custom_minimum_size = Vector2(130,32)
	search_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sorter := OptionButton.new()
	sorter.name = "InventorySort"
	for title: String in ["사용자순","등급순","수량순","이름순"]: sorter.add_item(title)
	sorter.item_selected.connect(func(index: int) -> void: sort_mode=index; _refresh_inventory_grid())
	search_row.add_child(sorter)
	search_row.hide()
	header.hide()
	for button: Button in tab_buttons.values():
		button.custom_minimum_size = Vector2(68,32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.reparent(self)
	detail_panel.z_index = 10
	detail_panel.custom_minimum_size = Vector2(300,0)
	detail_panel.add_theme_stylebox_override("panel",UI.chrome_panel(Color("181714"),UI.BRONZE,12))
	detail_panel.minimum_size_changed.connect(_queue_detail_layout)
	detail_grade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_type.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail_stack: VBoxContainer = detail_panel.get_child(0)
	var close_row := HBoxContainer.new()
	close_row.add_child(UI.label("아이템 정보",15,UI.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(spacer)
	var detail_close: Button = UI.button("닫기",func() -> void: detail_active=false; _reflow(),Vector2(52,30))
	detail_close.set_script(NATIVE_BUTTON)
	detail_close.name = "InventoryDetailClose"
	close_row.add_child(detail_close)
	detail_stack.add_child(close_row)
	detail_stack.move_child(close_row,0)
	lock_button = UI.button("잠금",_toggle_lock,Vector2(0,32))
	lock_button.name = "InventoryLock"
	detail_stack.add_child(lock_button)
	weight_readout = UI.label("",11,UI.MUTED)
	layout.add_child(weight_readout)
	weight_readout.hide()
	weight_gauge = ProgressBar.new()
	weight_gauge.name = "InventoryWeight"
	weight_gauge.show_percentage = false
	weight_gauge.custom_minimum_size.y = 4
	layout.add_child(weight_gauge)
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	actions.add_child(UI.button("검색",func() -> void: search_row.visible=not search_row.visible,Vector2(64,34)))
	expand_button = UI.button("확장",_toggle_expanded,Vector2(62,34))
	expand_button.name = "ExpandInventory"
	actions.add_child(expand_button)
	var detail_button: Button = UI.button("상세정보",open_detail,Vector2(86,34))
	detail_button.set_script(NATIVE_BUTTON)
	detail_button.name = "InventoryDetail"
	actions.add_child(detail_button)
	actions.add_child(UI.button("장비",func() -> void: controller.show_companion_equipment(),Vector2(64,34)))
	compact_tabs = HBoxContainer.new()
	compact_tabs.hide()
	layout.add_child(compact_tabs)
	# A sibling of the scroll container: the name is not clipped by its top row.
	item_name_hint = UI.label("",14,UI.TEXT)
	item_name_hint.name = "InventoryItemName"
	item_name_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_name_hint.focus_mode = Control.FOCUS_NONE
	item_name_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_name_hint.add_theme_color_override("font_outline_color",Color.BLACK)
	item_name_hint.add_theme_constant_override("outline_size",4)
	item_name_hint.z_index = 20
	add_child(item_name_hint)
	_hide_item_name()
	visibility_changed.connect(_inventory_visibility_changed)
	inventory_panel.visibility_changed.connect(_inventory_visibility_changed)
	resized.connect(_reflow)
	inventory_panel.resized.connect(_reflow)
	_reflow()

func _toggle_expanded() -> void:
	var window: Control = get_parent().get_parent().get_parent()
	var expanded: bool = not window.get_meta("expanded",false)
	window.set_meta("expanded",expanded)
	expand_button.text = "기본" if expanded else "확장"
	window.fit_viewport()
	_reflow()

func _reflow() -> void:
	if grid_scroll == null: return
	var width: float = inventory_panel.size.x
	# Do not infer columns from a stale container minimum after reparenting.
	var window: Node = get_parent().get_parent().get_parent() if is_inside_tree() else null
	item_grid.columns = 8 if window != null and window.get_meta("expanded",false) else 4
	inventory_left.show()
	var small: bool = get_window().size.x < 760
	detail_panel.position = Vector2(0 if small else -318,0 if small else -54)
	detail_panel.size = Vector2(width if small else 310,minf(508,maxf(260,inventory_panel.size.y+(0 if small else 54))))
	detail_panel.visible = detail_active and not selected_item.is_empty()
	compact_tabs.hide()

func _queue_detail_layout() -> void:
	if detail_layout_queued or not detail_active: return
	detail_layout_queued = true
	call_deferred("_settle_detail_layout")

func _settle_detail_layout() -> void:
	detail_layout_queued = false
	if is_inside_tree() and detail_active:
		# Wrapped labels can temporarily enlarge the popup while their width
		# settles. Shrink it back to the viewport budget once that minimum changes.
		_reflow()

func _input(_event: InputEvent) -> void:
	# PointerTransfer owns clicks, long presses, scrolling and drops together.
	pass

func _select_item(reference: String) -> void:
	gesture_dragged = false
	var previous: String = selected_item
	super._select_item(reference)
	_refresh_slot_states([previous,reference])
	# A selection never opens details, including when changing the selected item.
	detail_active = false
	_reflow()
	_show_item_name(reference)

func _show_item_name(reference: String) -> void:
	if item_name_hint == null or not slot_buttons.has(reference):
		_hide_item_name()
		return
	var record: Dictionary = _find_item_record(reference)
	item_name_reference = reference
	item_name_hint.text = _enhanced_display_name(record,reference)
	item_name_hint.add_theme_color_override("font_color",_grade_color(str(record.get("grade","일반"))))
	# One deadline, replaced on each click; old callbacks cannot hide a new name.
	item_name_until = Time.get_ticks_msec()+ITEM_NAME_DURATION_MS
	set_process(true)
	_update_item_name()

func _hide_item_name() -> void:
	item_name_reference = ""
	item_name_until = 0
	if item_name_hint != null: item_name_hint.hide()
	set_process(false)
	# Deliberately do not clear selected_item or its highlighted item border.

func _inventory_visibility_changed() -> void:
	if not is_visible_in_tree() or not inventory_panel.is_visible_in_tree():
		_hide_item_name()
		detail_active = false
		detail_panel.hide()

func _process(_delta: float) -> void:
	_update_item_name()

func _update_item_name() -> void:
	if item_name_reference.is_empty(): return
	if Time.get_ticks_msec() >= item_name_until or not inventory_panel.is_visible_in_tree() or selected_item != item_name_reference or not slot_buttons.has(item_name_reference):
		_hide_item_name()
		return
	# Resolve the current button by physical reference after sort/equip/redraw.
	var button: Control = slot_buttons[item_name_reference] as Control
	if not is_instance_valid(button) or not button.is_visible_in_tree():
		_hide_item_name()
		return
	var slot_rect: Rect2 = button.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,button.size)
	var scroll_rect: Rect2 = grid_scroll.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,grid_scroll.size)
	# A scrolled-out/clipped slot must not leave a floating name over another row.
	if not scroll_rect.grow(1.0).encloses(slot_rect):
		item_name_hint.hide()
		return
	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var local_slot: Rect2 = inverse*slot_rect
	var viewport_bounds: Rect2 = inverse*get_viewport_rect()
	var font: Font = item_name_hint.get_theme_font("font")
	var font_size: int = item_name_hint.get_theme_font_size("font_size")
	var natural_width: float = font.get_string_size(item_name_hint.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+12.0
	var label_width: float = minf(natural_width,maxf(1.0,viewport_bounds.size.x-16.0))
	item_name_hint.size = Vector2(label_width,0)
	item_name_hint.size.y = item_name_hint.get_minimum_size().y
	item_name_hint.position = Vector2(
		clampf(local_slot.get_center().x-label_width*0.5,viewport_bounds.position.x+8.0,viewport_bounds.end.x-label_width-8.0),
		local_slot.position.y-item_name_hint.size.y-ITEM_NAME_GAP)
	item_name_hint.visible = item_name_hint.position.y >= viewport_bounds.position.y

func open_detail() -> void:
	if selected_item.is_empty(): return
	_hide_item_name()
	detail_active = true
	_refresh_detail(selected_item)
	_reflow()
	_queue_detail_layout()

func show_inventory() -> void:
	gesture_dragged = false
	super.show_inventory()
	_reflow()

func _toggle_lock() -> void:
	if controller == null or selected_item.is_empty(): return
	controller.get_parent()._set_item_locked(selected_item,not bool(character_state.get("item_locks",{}).get(selected_item,false)))
	_refresh_detail(selected_item)

func _slot_style_for_grade(grade: String, selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = UI.item_frame(grade,selected)
	if selected:
		style.set_border_width_all(2)
		style.border_color = _grade_color(grade).lightened(0.25)
		style.bg_color = style.bg_color.lightened(0.08)
	# Keep the existing flat grade/selection border above the grid's batched
	# inset texture. Hover/press tint it without covering the slot relief.
	style.bg_color.a = .12 if selected else .035
	return style

func _draw_slot_recesses() -> void:
	var style: StyleBoxTexture = UI.slot_recess()
	for child: Node in item_grid.get_children():
		if child is Control and child.visible:
			item_grid.draw_style_box(style,Rect2(child.position+Vector2(3,3),child.size-Vector2(6,6)))

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
	return UI.item_icon(record, name_value, item_image_index.get("아이템", {}))

func _grade_color(value: String) -> Color:
	return UI.grade(value)

func set_inventory(value: Dictionary) -> void:
	if inventory == value:
		return
	super.set_inventory(value)

func set_character_state(value: Dictionary) -> void:
	var fingerprint := JSON.stringify([value.get("gold",0),value.get("equipped_items",{}),value.get("enhancement_levels",{}),value.get("item_instances",{}),value.get("item_locks",{})])
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
	var old_scroll: int = grid_scroll.scroll_vertical if grid_scroll != null else 0
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
		if controller != null and sort_mode == 0:
			var order: Array = controller.get_parent().ui_preferences.get("inventory_order",[])
			references.sort_custom(func(a: String,b: String) -> bool:
				var ai: int = order.find(a)
				var bi: int = order.find(b)
				if ai == bi: return a < b
				return (ai if ai >= 0 else 100000) < (bi if bi >= 0 else 100000))
	for index: int in range(references.size()):
		var reference: String = str(references[index])
		var item_name: String = _base_item_name(reference)
		var button: Button = slot_buttons[reference] as Button
		item_grid.move_child(button, index)
		var record: Dictionary = _find_item_record(reference)
		button.icon = null
		button.text = ""
		button.custom_minimum_size = Vector2(72,72)
		button.tooltip_text = "" # Only the timed, grade-colored name is shown.
		var icon := TextureRect.new()
		UI.apply_item_visual(icon,record,item_name,item_image_index.get("아이템",{}),"inventory")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(7,7)
		icon.size = Vector2(58,58)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var level: int = _enhance_level(reference)
		var badge := UI.label("+%d" % level if level > 0 else "", 12, UI.GOLD)
		badge.name = "InventoryEnhancement"
		badge.position = Vector2(25, 2)
		badge.size = Vector2(42,18)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(badge)
		var equipped: bool = _is_item_equipped(reference)
		var amount: int = 1 if _ref_instance_id(reference) != "" else int(inventory.get(item_name, 0))
		if equipped:
			var mark := UI.label("E",13,Color("f5f4e9"))
			mark.name = "InventoryEquipped"
			mark.position = Vector2(4,4)
			mark.size = Vector2(17,18)
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var blue := UI.box(Color("26577c"),Color("87afc8"),0)
			blue.shadow_size = 0
			mark.add_theme_stylebox_override("normal",blue)
			button.add_child(mark)
		var count := UI.label(UI.number_text(amount) if amount > 1 or _ref_instance_id(reference).is_empty() else "", 13, UI.GOLD)
		count.name = "InventoryQuantity"
		var locked: bool = bool(character_state.get("item_locks",{}).get(reference,false))
		count.position = Vector2(24 if locked else 4,49)
		count.size = Vector2(44 if locked else 64,20)
		count.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		count.tooltip_text = "보유 "+UI.number_text(amount)+"개"
		count.add_theme_color_override("font_outline_color",Color.BLACK)
		count.add_theme_constant_override("outline_size",2)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(count)
		if bool(character_state.get("item_locks",{}).get(reference,false)):
			var lock_mark := TextureRect.new()
			lock_mark.name = "InventoryLocked"
			lock_mark.texture = UI.icon("lock")
			lock_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock_mark.size = Vector2(18,18)
			lock_mark.position = Vector2(4,48)
			button.add_child(lock_mark)
	_refresh_slot_states()
	# Empty cells are real noninteractive slots, so the 4-column silhouette survives filtering.
	var count: int = item_grid.get_child_count()
	for i: int in range(maxi(0,20-count)):
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(72,72)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var empty_style: StyleBoxFlat = UI.slot_frame()
		empty_style.bg_color.a = 0
		empty.add_theme_stylebox_override("panel",empty_style)
		item_grid.add_child(empty)
	_refresh_weight()
	_reflow()
	if grid_scroll != null: grid_scroll.set_deferred("scroll_vertical",old_scroll)

func reorder(source: String, target: String) -> void:
	if source == target or not slot_buttons.has(source) or not slot_buttons.has(target): return
	var order: Array = []
	for child: Node in item_grid.get_children():
		for reference: String in slot_buttons:
			if slot_buttons[reference] == child: order.append(reference)
	var a: int = order.find(source)
	var b: int = order.find(target)
	order[a] = target
	order[b] = source
	controller.get_parent().ui_preferences["inventory_order"] = order
	sort_mode = 0
	_refresh_inventory_grid()
	controller.get_parent()._save_game(true)

func _refresh_weight() -> void:
	if weight_readout != null:
		var current_weight: float = float(character_state.get("current_weight", 0))
		var max_weight: float = float(character_state.get("max_weight", character_state.get("carrying_capacity", 0)))
		var ratio: float = 100*current_weight/maxf(1,max_weight)
		weight_readout.text = "무게  %.0f / %.0f  (%.1f%%)" % [current_weight,max_weight,ratio]
		weight_gauge.value = minf(100,ratio)
		weight_gauge.tooltip_text = weight_readout.text
		capacity_label.text = "%d%% · %s" % [roundi(ratio),capacity_label.text.get_slice(" · ",capacity_label.text.get_slice_count(" · ")-1)]

func _refresh_detail(item_reference: String) -> void:
	super._refresh_detail(item_reference)
	var item_name: String = _base_item_name(item_reference)
	var selected_id: String = _ref_instance_id(item_reference)
	var item: Dictionary = _find_item_record(item_reference)
	UI.apply_item_visual(detail_icon,item,item_name,item_image_index.get("아이템",{}),"detail")
	var lines := PackedStringArray()
	for raw: Variant in item.get("sourceOptions",[]):
		var option: String = str(raw)
		if option.contains("PVP") or option.contains("PvP") or option.contains("손상") or option.contains("저주"): continue
		lines.append(UI.safe(option))
	if lines.is_empty():
		for spec: Array in [["atk","공격력"],["def","방어력"],["hit","명중"],["hpFlat","최대 HP"],["mpFlat","최대 MP"],["heal","HP 회복"]]:
			if item.has(spec[0]) and float(item[spec[0]]) != 0:
				lines.append("%s  %s" % [spec[1],str(item[spec[0]])])
		var description: String = str(item.get("desc",item.get("description","")))
		if not description.is_empty(): lines.append(UI.safe(description))
	if not selected_id.is_empty(): lines.append("강화  +%d" % _enhance_level(item_reference))
	detail_text.text = "\n".join(lines) if not lines.is_empty() else "표시할 추가 효과가 없습니다."
	if controller != null:
		var reason: String = controller.get_parent()._quickslot_registration_error("item",item_name)
		quick_button.disabled = not reason.is_empty()
		quick_button.tooltip_text = reason if not reason.is_empty() else "퀵슬롯을 선택해 등록합니다"
	var slot: String = str(item.get("slot", ""))
	var worn: Dictionary = character_state.get("equipped_items", {})
	var current: Variant = worn.get(slot, {})
	if current is Dictionary and not (current as Dictionary).is_empty() and str((current as Dictionary).get("name", "")) != item_name:
		detail_text.text += "\n\n[color=#d8b878]착용 장비와 비교[/color]\n" + UI.safe((current as Dictionary).get("name", ""))
		for pair: Array in [["atk", "공격력"], ["def", "방어력"], ["hit", "명중"], ["hpFlat", "최대 HP"]]:
			var delta: int = int(item.get(pair[0], 0)) - int((current as Dictionary).get(pair[0], 0))
			if delta != 0:
				detail_text.text += "\n%s  %s%d" % [pair[1], "+" if delta > 0 else "", delta]
	var locked: bool = bool(character_state.get("item_locks",{}).get(item_reference,false))
	if lock_button != null:
		lock_button.text = "잠금 해제" if locked else "잠금"
		lock_button.icon = UI.icon("lock") if locked else null
		lock_button.tooltip_text = "아이템 잠금 상태를 해제합니다" if locked else "선택한 아이템을 잠급니다"
	if _is_item_equipped(item_reference):
		detail_action.text = "해제"
		detail_action.disabled = false
		detail_action.tooltip_text = "선택한 장비의 장착을 해제합니다"
	detail_type.text = str(item.get("type","")) + (" · 각인" if _is_engraved(item,item_name) else "")
	detail_type.text += " · 선택됨"+(" · 잠금" if locked else "")
	if detail_icon.get_meta("item_visual",{}).get("status","") == "self_authored_substitute":
		detail_type.text += " · 대체 아이콘 ◇"

func _activate_selected() -> void:
	if selected_item.is_empty(): return
	if _is_item_equipped(selected_item): controller.get_parent()._unequip_item_reference(selected_item)
	else: item_activate_requested.emit(selected_item)

func _refresh_slot_states(references: Array = []) -> void:
	# Hover/press must not erase the persistent selected-item border.
	for reference: String in (slot_buttons.keys() if references.is_empty() else references):
		if not slot_buttons.has(reference): continue
		var button: Button = slot_buttons[reference]
		var selected: bool = reference == selected_item
		var grade_name: String = str(_find_item_record(reference).get("grade","일반"))
		for state: String in ["hover","pressed"]:
			var style: StyleBoxFlat = _slot_style_for_grade(grade_name,selected)
			if state == "hover":
				style.bg_color = style.bg_color.lightened(.035)
				style.bg_color.a = .16
			if state == "pressed":
				style.bg_color = style.bg_color.darkened(.08)
				style.bg_color.a = .22
			button.add_theme_stylebox_override(state,style)
	item_grid.queue_redraw()
