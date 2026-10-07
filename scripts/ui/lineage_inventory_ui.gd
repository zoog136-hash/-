extends Control
class_name TwilightInventoryUI

signal item_activate_requested(item_name: String)
signal quickslot_requested(item_name: String)

const GOLD := Color(0.82, 0.68, 0.40, 1.0)
const GOLD_BRIGHT := Color(0.98, 0.81, 0.42, 1.0)
const GOLD_SOFT := Color(0.68, 0.55, 0.32, 1.0)
const TEXT := Color(0.94, 0.90, 0.82, 1.0)
const TEXT_DIM := Color(0.68, 0.66, 0.60, 1.0)
const PANEL := Color(0.023, 0.025, 0.028, 0.97)
const SLOT_BG := Color(0.045, 0.047, 0.048, 0.98)

var inventory_panel: PanelContainer
var item_grid: GridContainer
var detail_panel: PanelContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_grade: Label
var detail_type: Label
var detail_text: RichTextLabel
var detail_action: Button
var quick_button: Button
var gold_label: Label
var capacity_label: Label
var search_line: LineEdit
var tab_buttons: Dictionary = {}
var slot_buttons: Dictionary = {}

var inventory: Dictionary = {}
var catalog_data: Dictionary = {}
var item_image_index: Dictionary = {}
var character_state: Dictionary = {}
var selected_item: String = ""
var category_filter: String = "전체"
var max_slots: int = 104

const CATEGORIES := ["전체", "장비", "소모품", "기타"]
const GRADE_COLORS := {
	"일반": Color(0.62, 0.64, 0.66, 1.0),
	"고급": Color(0.32, 0.78, 0.38, 1.0),
	"희귀": Color(0.28, 0.58, 0.98, 1.0),
	"영웅": Color(0.70, 0.36, 0.94, 1.0),
	"전설": Color(0.98, 0.56, 0.18, 1.0),
	"신화": Color(0.94, 0.24, 0.28, 1.0),
	"유일": Color(1.0, 0.82, 0.24, 1.0)
}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 190
	_build_inventory()
	inventory_panel.visible = false

func _style(bg: Color, border: Color = Color(0.28, 0.24, 0.17, 1.0), radius: int = 3, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = width
	s.border_width_top = width
	s.border_width_right = width
	s.border_width_bottom = width
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 7.0
	s.content_margin_right = 7.0
	s.content_margin_top = 5.0
	s.content_margin_bottom = 5.0
	return s

func _label(value: String, size: int = 14, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_inventory() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.name = "LineageInventoryPanel"
	inventory_panel.anchor_left = 0.16
	inventory_panel.anchor_top = 0.06
	inventory_panel.anchor_right = 0.98
	inventory_panel.anchor_bottom = 0.95
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_panel.add_theme_stylebox_override("panel", _style(PANEL, Color(0.48,0.39,0.23,1), 4, 1))
	add_child(inventory_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	inventory_panel.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 48.0
	header.add_theme_constant_override("separation", 7)
	root.add_child(header)

	var title := _label("인벤토리", 22, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	search_line = LineEdit.new()
	search_line.placeholder_text = "아이템 검색"
	search_line.custom_minimum_size = Vector2(210, 38)
	search_line.text_changed.connect(_on_search_changed)
	header.add_child(search_line)

	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(46, 38)
	close.add_theme_font_size_override("font_size", 23)
	close.add_theme_stylebox_override("normal", _style(Color(0.09,0.04,0.035,1), Color(0.42,0.22,0.16,1)))
	close.pressed.connect(func() -> void: inventory_panel.visible = false)
	header.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)
	for category: String in CATEGORIES:
		var button := Button.new()
		button.text = category
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(110, 34)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", _style(Color(0.045,0.045,0.042,1)))
		button.add_theme_stylebox_override("pressed", _style(Color(0.13,0.10,0.055,1), GOLD, 3, 1))
		button.pressed.connect(_set_category.bind(category))
		tabs.add_child(button)
		tab_buttons[category] = button
	_refresh_tabs()

	var divider := HSeparator.new()
	root.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 8
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	left.add_child(scroll)

	item_grid = GridContainer.new()
	item_grid.columns = 5
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 5)
	item_grid.add_theme_constant_override("v_separation", 5)
	item_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(item_grid)

	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 38.0
	left.add_child(footer)
	gold_label = _label("● 0", 15, Color(0.96,0.80,0.37,1))
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(gold_label)
	capacity_label = _label("0 / 104", 14, TEXT_DIM)
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(capacity_label)

	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(315, 0)
	detail_panel.add_theme_stylebox_override("panel", _style(Color(0.032,0.034,0.036,0.98), Color(0.34,0.29,0.19,1), 3, 1))
	body.add_child(detail_panel)

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 7)
	detail_panel.add_child(detail)

	var detail_header := HBoxContainer.new()
	detail_header.custom_minimum_size.y = 84.0
	detail_header.add_theme_constant_override("separation", 8)
	detail.add_child(detail_header)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(78,78)
	icon_frame.add_theme_stylebox_override("panel", _style(Color(0.02,0.02,0.02,1), Color(0.38,0.32,0.20,1)))
	detail_header.add_child(icon_frame)
	detail_icon = TextureRect.new()
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.add_child(detail_icon)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 2)
	detail_header.add_child(name_box)
	detail_name = _label("아이템을 선택하세요", 18, TEXT)
	detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_box.add_child(detail_name)
	detail_grade = _label("-", 13, GOLD)
	name_box.add_child(detail_grade)
	detail_type = _label("-", 12, TEXT_DIM)
	name_box.add_child(detail_type)

	var detail_sep := HSeparator.new()
	detail.add_child(detail_sep)
	detail_text = RichTextLabel.new()
	detail_text.bbcode_enabled = true
	detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_text.scroll_active = true
	detail_text.add_theme_font_size_override("normal_font_size", 14)
	detail_text.add_theme_color_override("default_color", TEXT)
	detail_text.text = "아이템을 누르면 상세 정보가 표시됩니다."
	detail.add_child(detail_text)

	var detail_buttons := HBoxContainer.new()
	detail_buttons.add_theme_constant_override("separation", 5)
	detail.add_child(detail_buttons)
	detail_action = Button.new()
	detail_action.text = "사용 / 장착"
	detail_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_action.custom_minimum_size.y = 42
	detail_action.disabled = true
	detail_action.add_theme_stylebox_override("normal", _style(Color(0.10,0.075,0.04,1), GOLD))
	detail_action.pressed.connect(_activate_selected)
	detail_buttons.add_child(detail_action)
	quick_button = Button.new()
	quick_button.text = "Q등록"
	quick_button.custom_minimum_size = Vector2(78,42)
	quick_button.disabled = true
	quick_button.add_theme_stylebox_override("normal", _style(Color(0.055,0.06,0.065,1), Color(0.30,0.32,0.34,1)))
	quick_button.pressed.connect(_quickslot_selected)
	detail_buttons.add_child(quick_button)

func set_catalog_data(data: Dictionary, images: Dictionary) -> void:
	catalog_data = data
	item_image_index = images
	_refresh_inventory_grid()

func set_character_state(state: Dictionary) -> void:
	character_state = state.duplicate(true)
	gold_label.text = "● %s" % _format_number(int(character_state.get("gold", 0)))
	_refresh_inventory_grid()
	if selected_item != "":
		_refresh_detail(selected_item)

func set_inventory(value: Dictionary) -> void:
	inventory = value.duplicate(true)
	if selected_item != "" and int(inventory.get(selected_item, 0)) <= 0:
		selected_item = ""
	_refresh_inventory_grid()
	if selected_item != "":
		_refresh_detail(selected_item)

func toggle_inventory() -> void:
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible:
		_refresh_inventory_grid()

func show_inventory() -> void:
	inventory_panel.visible = true
	_refresh_inventory_grid()

func hide_inventory() -> void:
	inventory_panel.visible = false

func _set_category(category: String) -> void:
	category_filter = category
	_refresh_tabs()
	_refresh_inventory_grid()

func _refresh_tabs() -> void:
	for key: Variant in tab_buttons.keys():
		var button := tab_buttons[key] as Button
		button.button_pressed = str(key) == category_filter

func _on_search_changed(_value: String) -> void:
	_refresh_inventory_grid()

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _refresh_inventory_grid() -> void:
	if item_grid == null:
		return
	_clear(item_grid)
	slot_buttons.clear()
	var names: Array = inventory.keys()
	names.sort()
	var visible_count := 0
	var search := search_line.text.strip_edges().to_lower() if search_line != null else ""
	var images: Dictionary = item_image_index.get("아이템", {}) as Dictionary
	for value: Variant in names:
		var item_name := str(value)
		var amount := int(inventory.get(item_name, 0))
		if amount <= 0:
			continue
		var record := _find_item_record(item_name)
		if not _matches_category(record, item_name):
			continue
		if search != "" and item_name.to_lower().find(search) < 0:
			continue
		visible_count += 1
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 88)
		var grade := str(record.get("grade", "일반"))
		var equipped := _is_item_equipped(item_name)
		var equip_mark := "E  " if equipped else ""
		button.text = "%s%s\nx%d" % [equip_mark, _short_name(item_name), amount]
		button.tooltip_text = "%s%s" % [item_name, " · 장착 중" if equipped else ""]
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _slot_style_for_grade(grade, item_name == selected_item))
		button.add_theme_stylebox_override("hover", _slot_hover_style(grade))
		button.add_theme_stylebox_override("pressed", _slot_pressed_style(grade))
		var path := str(images.get(item_name, ""))
		if path != "" and ResourceLoader.exists(path):
			button.icon = load(path) as Texture2D
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 42)
		button.pressed.connect(_select_item.bind(item_name))
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		item_grid.add_child(button)
		slot_buttons[item_name] = button

	var occupied := 0
	for value: Variant in inventory.keys():
		if int(inventory.get(value, 0)) > 0:
			occupied += 1
	capacity_label.text = "%d / %d" % [occupied, max_slots]
	if visible_count == 0:
		var empty := _label("표시할 아이템이 없습니다.", 14, TEXT_DIM)
		empty.custom_minimum_size = Vector2(350, 80)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_grid.add_child(empty)

func _grade_color(grade: String) -> Color:
	return GRADE_COLORS.get(grade, GRADE_COLORS["일반"]) as Color

func _slot_style_for_grade(grade: String, selected: bool) -> StyleBoxFlat:
	var color := _grade_color(grade)
	if selected:
		return _style(Color(0.13,0.10,0.05,1), color.lightened(0.16), 2, 3)
	return _style(SLOT_BG, color, 2, 2)

func _slot_hover_style(grade: String) -> StyleBoxFlat:
	var color := _grade_color(grade)
	return _style(Color(0.095,0.083,0.052,1), color.lightened(0.10), 2, 2)

func _slot_pressed_style(grade: String) -> StyleBoxFlat:
	var color := _grade_color(grade)
	return _style(Color(0.14,0.105,0.05,1), color.lightened(0.18), 2, 3)

func _is_item_equipped(item_name: String) -> bool:
	var equipped_items: Dictionary = character_state.get("equipped_items", {}) as Dictionary
	for value: Variant in equipped_items.values():
		if value is Dictionary:
			var record := value as Dictionary
			if str(record.get("name", "")) == item_name:
				return true
	return false

func _short_name(item_name: String) -> String:
	if item_name.length() <= 8:
		return item_name
	return item_name.left(7) + "…"

func _select_item(item_name: String) -> void:
	selected_item = item_name
	for key: Variant in slot_buttons.keys():
		var button := slot_buttons[key] as Button
		var record := _find_item_record(str(key))
		button.add_theme_stylebox_override("normal", _slot_style_for_grade(str(record.get("grade", "일반")), str(key) == selected_item))
	_refresh_detail(item_name)

func _find_item_record(item_name: String) -> Dictionary:
	var records: Array = catalog_data.get("아이템", []) as Array
	for value: Variant in records:
		if value is Dictionary:
			var record := value as Dictionary
			if str(record.get("name", "")) == item_name:
				return record
	return {"name":item_name, "grade":"일반", "type":"기타", "slot":"other"}

func _matches_category(record: Dictionary, item_name: String) -> bool:
	if category_filter == "전체":
		return true
	var slot := str(record.get("slot", "")).to_lower()
	var item_type := str(record.get("type", ""))
	if category_filter == "장비":
		return slot in ["weapon","offhand","helmet","tshirt","body","pants","cloak","shoulder","gaiters","gloves","boots","earring","ring","belt","bracelet","badge","seal","crystal","catalyst","rune","necklace","armor"]
	if category_filter == "소모품":
		return slot == "consumable" or item_type == "소모품" or item_name.find("물약") >= 0 or item_name.find("주문서") >= 0
	return not (slot in ["weapon","offhand","helmet","tshirt","body","pants","cloak","shoulder","gaiters","gloves","boots","earring","ring","belt","bracelet","badge","seal","crystal","catalyst","rune","necklace","armor","consumable"])

func _refresh_detail(item_name: String) -> void:
	var record := _find_item_record(item_name)
	var amount := int(inventory.get(item_name, 0))
	var grade := str(record.get("grade", "일반"))
	var item_type := str(record.get("type", "기타"))
	var slot := str(record.get("slot", ""))
	var equipped := _is_item_equipped(item_name)
	detail_name.text = item_name
	detail_grade.text = "%s%s · 보유 %d" % [grade, " · 장착중" if equipped else "", amount]
	detail_grade.add_theme_color_override("font_color", _grade_color(grade))
	detail_type.text = "%s%s%s" % [item_type, (" · " + slot) if slot != "" else "", " · E" if equipped else ""]

	var images: Dictionary = item_image_index.get("아이템", {}) as Dictionary
	var path := str(images.get(item_name, ""))
	detail_icon.texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null

	var lines := PackedStringArray()
	var desc := str(record.get("desc", "")).strip_edges()
	if desc != "":
		lines.append("[color=#d8c9aa]%s[/color]" % desc)
		lines.append("")
	if record.has("atk"):
		lines.append("공격력  [color=#f0cc74]+%d[/color]" % int(record.get("atk", 0)))
	if record.has("def"):
		lines.append("방어력  [color=#9fd4ff]+%d[/color]" % int(record.get("def", 0)))
	if record.has("hit"):
		lines.append("명중    [color=#f0cc74]+%d[/color]" % int(record.get("hit", 0)))
	if record.has("hpFlat"):
		lines.append("최대 HP [color=#8fd58f]+%d[/color]" % int(record.get("hpFlat", 0)))
	if record.has("heal"):
		lines.append("HP 회복 [color=#8fd58f]%d[/color]" % int(record.get("heal", 0)))
	if record.has("xp"):
		lines.append("경험치  [color=#dfb5ff]+%.0f%%[/color]" % (float(record.get("xp", 0.0)) * 100.0))
	if record.has("weight"):
		lines.append("")
		lines.append("무게    %d" % int(record.get("weight", 0)))
	if lines.is_empty():
		lines.append("등록된 상세 옵션이 없습니다.")
	detail_text.text = "\n".join(lines)

	var is_consumable := slot == "consumable" or item_type == "소모품" or item_name.find("물약") >= 0 or item_name.find("주문서") >= 0
	if is_consumable:
		detail_action.text = "사용"
	elif equipped:
		detail_action.text = "장착 중"
	else:
		detail_action.text = "장착 / 사용"
	detail_action.disabled = amount <= 0 or (equipped and not is_consumable)
	quick_button.disabled = amount <= 0 or not is_consumable

func _activate_selected() -> void:
	if selected_item == "":
		return
	item_activate_requested.emit(selected_item)

func _quickslot_selected() -> void:
	if selected_item == "":
		return
	quickslot_requested.emit(selected_item)

func _format_number(value: int) -> String:
	var source := str(absi(value))
	var out := ""
	while source.length() > 3:
		out = "," + source.right(3) + out
		source = source.left(source.length() - 3)
	out = source + out
	return ("-" if value < 0 else "") + out
