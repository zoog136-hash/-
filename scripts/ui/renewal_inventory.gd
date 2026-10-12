extends "res://scripts/ui/lineage_inventory_ui.gd"

const UI = preload("res://scripts/ui/renewal_theme.gd")
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
	z_index = 1
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.add_theme_stylebox_override("panel",UI.box(Color("211b16"),Color("473b2d"),2))
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
	var detail_stack: VBoxContainer = detail_panel.get_child(0)
	var close_row := HBoxContainer.new()
	close_row.add_child(UI.label("아이템 정보",15,UI.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(spacer)
	close_row.add_child(UI.button("닫기",func() -> void: detail_active=false; _reflow(),Vector2(52,30)))
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
	actions.add_child(UI.button("정보",open_detail,Vector2(64,34)))
	actions.add_child(UI.button("장비",func() -> void: controller.show_companion_equipment(),Vector2(64,34)))
	compact_tabs = HBoxContainer.new()
	compact_tabs.hide()
	layout.add_child(compact_tabs)
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

func _input(_event: InputEvent) -> void:
	# PointerTransfer owns clicks, long presses, scrolling and drops together.
	pass

func _select_item(reference: String) -> void:
	gesture_dragged = false
	super._select_item(reference)
	_reflow()

func open_detail() -> void:
	if selected_item.is_empty(): return
	detail_active = true
	_refresh_detail(selected_item)
	_reflow()

func show_inventory() -> void:
	gesture_dragged = false
	super.show_inventory()
	_reflow()

func _toggle_lock() -> void:
	if controller == null or selected_item.is_empty(): return
	controller.get_parent()._set_item_locked(selected_item,not bool(character_state.get("item_locks",{}).get(selected_item,false)))
	_refresh_detail(selected_item)

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
		var texture: Texture2D = _icon_for_reference(record, item_name, reference)
		button.icon = null
		button.text = ""
		button.custom_minimum_size = Vector2(72,72)
		button.tooltip_text += " · 끌어서 퀵슬롯 등록 / 터치: 길게 누른 후 이동"
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(7,7)
		icon.size = Vector2(58,58)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var level: int = _enhance_level(reference)
		var badge := UI.label("+%d" % level if level > 0 else "", 12, UI.GOLD)
		badge.position = Vector2(5, 2)
		button.add_child(badge)
		var equipped: bool = _is_item_equipped(reference)
		var amount: int = 1 if _ref_instance_id(reference) != "" else int(inventory.get(item_name, 0))
		var count := UI.label("E" if equipped else "×%d" % amount, 12, UI.GOLD if equipped else UI.TEXT)
		count.position = Vector2(33,49)
		count.size = Vector2(36,20)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(count)
		if bool(character_state.get("item_locks",{}).get(reference,false)):
			var lock_mark := TextureRect.new()
			lock_mark.texture = UI.icon("lock")
			lock_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock_mark.size = Vector2(18,18)
			lock_mark.position = Vector2(4,48)
			button.add_child(lock_mark)
		if _ref_instance_id(reference) != "":
			button.tooltip_text += " · 개체 ID:" + _ref_instance_id(reference)
	# Empty cells are real noninteractive slots, so the 4-column silhouette survives filtering.
	var count: int = item_grid.get_child_count()
	for i: int in range(maxi(0,20-count)):
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(72,72)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_stylebox_override("panel",UI.slot_frame())
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
	detail_icon.texture = _icon_for_reference(item, item_name, item_reference)
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
	if lock_button != null:
		lock_button.text = "잠금 해제" if bool(character_state.get("item_locks",{}).get(item_reference,false)) else "잠금"
	if _is_item_equipped(item_reference):
		detail_action.text = "해제"
		detail_action.disabled = false
		detail_action.tooltip_text = "선택한 장비의 장착을 해제합니다"
	detail_type.text = str(item.get("type","")) + (" · 각인" if _is_engraved(item,item_name) else "")

func _activate_selected() -> void:
	if selected_item.is_empty(): return
	if _is_item_equipped(selected_item): controller.get_parent()._unequip_item_reference(selected_item)
	else: item_activate_requested.emit(selected_item)
