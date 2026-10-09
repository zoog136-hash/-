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
	"고급": Color(0.30, 0.78, 0.38, 1.0),
	"희귀": Color(0.25, 0.56, 0.98, 1.0),
	"영웅": Color(0.92, 0.20, 0.20, 1.0),
	"전설": Color(0.66, 0.28, 0.96, 1.0),
	"신화": Color(1.0, 0.76, 0.20, 1.0),
	"유일": Color(0.16, 1.0, 0.68, 1.0)
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
	if selected_item != "" and int(inventory.get(_base_item_name(selected_item), 0)) <= 0:
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

func _base_item_name(reference: String) -> String:
	return reference.split("@@@", false, 1)[0]

func _ref_instance_id(reference: String) -> String:
	var pieces: PackedStringArray = reference.split("@@@", false, 1)
	return pieces[1] if pieces.size() > 1 else ""

func _inventory_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var instances: Dictionary = character_state.get("item_instances", {}) as Dictionary
	var names: Array = inventory.keys()
	names.sort()
	for raw_name: Variant in names:
		var item_name: String = str(raw_name)
		if int(inventory.get(item_name, 0)) <= 0:
			continue
		var instance_ids: Array[String] = []
		for instance_key: Variant in instances.keys():
			var physical: Variant = instances[instance_key]
			if physical is Dictionary and str((physical as Dictionary).get("name", "")) == item_name:
				instance_ids.append(str(instance_key))
		instance_ids.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
		if instance_ids.is_empty():
			entries.append({"name":item_name, "reference":item_name, "amount":int(inventory[item_name])})
		else:
			for id: String in instance_ids:
				entries.append({"name":item_name, "reference":item_name+"@@@"+id, "amount":1})
	return entries

func _refresh_inventory_grid() -> void:
	if item_grid == null:
		return
	_clear(item_grid)
	slot_buttons.clear()
	var visible_count: int = 0
	var search: String = search_line.text.strip_edges().to_lower() if search_line != null else ""
	var images: Dictionary = item_image_index.get("아이템", {}) as Dictionary
	var entries: Array[Dictionary] = _inventory_entries()
	for entry: Dictionary in entries:
		var item_name: String = str(entry["name"])
		var reference: String = str(entry["reference"])
		var amount: int = int(entry["amount"])
		var record: Dictionary = _find_item_record(item_name)
		if not _matches_category(record, item_name) or (search != "" and item_name.to_lower().find(search) < 0):
			continue
		visible_count += 1
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(96, 88)
		var grade: String = str(record.get("grade", "일반"))
		var equipped: bool = _is_item_equipped(reference)
		var equip_mark: String = "E " if equipped else ""
		var level: int = _enhance_level(reference)
		var level_mark: String = "+%d " % level if level > 0 else ""
		var badges: String = _status_badges(record, item_name)
		var badge_mark: String = badges + " " if badges != "" else ""
		button.text = "%s%s%s%s\nx%d" % [equip_mark, level_mark, badge_mark, _short_name(item_name), amount]
		button.tooltip_text = "%s%s%s" % [_enhanced_display_name(record, reference), " · 장착 중" if equipped else "", _status_tooltip(record, item_name)]
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _slot_style_for_grade(grade, reference == selected_item))
		button.add_theme_stylebox_override("hover", _slot_hover_style(grade))
		button.add_theme_stylebox_override("pressed", _slot_pressed_style(grade))
		var path: String = str(images.get(item_name, ""))
		if path != "" and ResourceLoader.exists(path):
			button.icon = load(path) as Texture2D
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 42)
		button.pressed.connect(_select_item.bind(reference))
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		item_grid.add_child(button)
		slot_buttons[reference] = button
	var occupied: int = entries.size()
	capacity_label.text = "%d / %d" % [occupied, max_slots]
	if visible_count == 0:
		var empty: Label = _label("표시할 아이템이 없습니다.", 14, TEXT_DIM)
		empty.custom_minimum_size = Vector2(350, 80)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_grid.add_child(empty)

func _enhancement_copy_labels(item_name: String) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	var instances: Dictionary = character_state.get("item_instances", {}) as Dictionary
	var levels: Array[int] = []
	for raw: Variant in instances.values():
		if raw is Dictionary and str((raw as Dictionary).get("name", "")) == item_name:
			levels.append(int((raw as Dictionary).get("level", 0)))
	levels.sort()
	for rank: int in levels:
		labels.append("+%d" % rank)
	return labels

func _enhance_level(item_reference: String) -> int:
	var id: String = _ref_instance_id(item_reference)
	var instances: Dictionary = character_state.get("item_instances", {}) as Dictionary
	if id != "" and instances.has(id):
		return maxi(0, int((instances[id] as Dictionary).get("level", 0)))
	var legacy: Dictionary = character_state.get("enhancement_levels", {}) as Dictionary
	return maxi(0, int(legacy.get(_base_item_name(item_reference), 0))) if id == "" else 0

func _bless_state(record: Dictionary, item_name: String) -> String:
	var explicit := str(record.get("bless_state", "")).to_lower()
	if explicit in ["blessed", "축복"]:
		return "blessed"
	if bool(record.get("blessed", false)) or item_name.find("축복받은") >= 0:
		return "blessed"
	return "normal"

func _is_engraved(record: Dictionary, item_name: String) -> bool:
	return bool(record.get("engraved", false)) or item_name.find("(각인)") >= 0 or item_name.find("각인") >= 0

func _status_badges(record: Dictionary, item_name: String) -> String:
	var badges := PackedStringArray()
	var state := _bless_state(record, item_name)
	if state == "blessed":
		badges.append("✦")
	if _is_engraved(record, item_name):
		badges.append("◆")
	return " ".join(badges)

func _enhanced_display_name(record: Dictionary, item_name: String) -> String:
	var level := _enhance_level(item_name)
	var prefix := "+%d " % level if level > 0 else ""
	var badges := _status_badges(record, item_name)
	return "%s%s%s" % [prefix, badges + " " if badges != "" else "", _base_item_name(item_name)]

func _status_tooltip(record: Dictionary, item_name: String) -> String:
	var parts := PackedStringArray()
	var state := _bless_state(record, item_name)
	if state == "blessed":
		parts.append("축복")
	if _is_engraved(record, item_name):
		parts.append("각인")
	return (" · " + " · ".join(parts)) if not parts.is_empty() else ""

func _grade_color(grade: String) -> Color:
	return GRADE_COLORS.get(grade, GRADE_COLORS["일반"]) as Color

func _grade_background(grade: String, selected: bool = false) -> Color:
	var color := _grade_color(grade)
	var strength := 0.22 if selected else 0.13
	return Color(
		lerpf(SLOT_BG.r, color.r, strength),
		lerpf(SLOT_BG.g, color.g, strength),
		lerpf(SLOT_BG.b, color.b, strength),
		0.99
	)

func _apply_grade_glow(style: StyleBoxFlat, grade: String, selected: bool = false) -> StyleBoxFlat:
	var color := _grade_color(grade)
	var is_high_grade := grade in ["영웅", "전설", "신화", "유일"]
	if is_high_grade:
		style.shadow_color = Color(color.r, color.g, color.b, 0.48 if selected else 0.28)
		style.shadow_size = 7 if selected else 4
		style.shadow_offset = Vector2.ZERO
	if grade == "유일":
		style.shadow_color = Color(0.16, 1.0, 0.68, 0.70 if selected else 0.46)
		style.shadow_size = 10 if selected else 7
	return style

func _slot_style_for_grade(grade: String, selected: bool) -> StyleBoxFlat:
	var color := _grade_color(grade)
	var style := _style(_grade_background(grade, selected), color.lightened(0.14) if selected else color, 2, 3 if selected else 2)
	return _apply_grade_glow(style, grade, selected)

func _slot_hover_style(grade: String) -> StyleBoxFlat:
	var color := _grade_color(grade)
	var style := _style(_grade_background(grade, true), color.lightened(0.14), 2, 3)
	return _apply_grade_glow(style, grade, true)

func _slot_pressed_style(grade: String) -> StyleBoxFlat:
	var color := _grade_color(grade)
	var style := _style(_grade_background(grade, true), color.lightened(0.20), 2, 3)
	return _apply_grade_glow(style, grade, true)

func _is_item_equipped(item_reference: String) -> bool:
	var item_name: String = _base_item_name(item_reference)
	var instance_id: String = _ref_instance_id(item_reference)
	var equipped: Dictionary = character_state.get("equipped_items", {}) as Dictionary
	for value: Variant in equipped.values():
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		if instance_id != "":
			if str(record.get("instance_id", "")) == instance_id and str(record.get("name", "")) == item_name:
				return true
		elif str(record.get("name", "")) == item_name:
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
		var record := _find_item_record(_base_item_name(str(key)))
		button.add_theme_stylebox_override("normal", _slot_style_for_grade(str(record.get("grade", "일반")), str(key) == selected_item))
	_refresh_detail(item_name)

func _find_item_record(item_name: String) -> Dictionary:
	item_name = _base_item_name(item_name)
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
	var selected_reference: String = item_name
	var selected_id: String = _ref_instance_id(item_name)
	item_name = _base_item_name(item_name)
	var record := _find_item_record(item_name)
	var amount := 1 if selected_id != "" else int(inventory.get(item_name, 0))
	var grade := str(record.get("grade", "일반"))
	var item_type := str(record.get("type", "기타"))
	var slot := str(record.get("slot", ""))
	var equipped := _is_item_equipped(selected_reference)
	var enhance_level := _enhance_level(selected_reference)
	var bless_state := _bless_state(record, item_name)
	var engraved := _is_engraved(record, item_name)
	detail_name.text = _enhanced_display_name(record, selected_reference)
	detail_grade.text = "%s%s · 보유 %d" % [grade, " · 장착중" if equipped else "", amount]
	detail_grade.add_theme_color_override("font_color", _grade_color(grade))
	detail_name.add_theme_color_override("font_color", _grade_color(grade))
	detail_type.text = "%s%s%s%s" % [item_type, (" · " + slot) if slot != "" else "", " · E" if equipped else "", " · ID:"+selected_id if selected_id != "" else ""]

	var images: Dictionary = item_image_index.get("아이템", {}) as Dictionary
	var path := str(images.get(item_name, ""))
	detail_icon.texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null

	var lines := PackedStringArray()
	if selected_id != "":
		var instances: Dictionary = character_state.get("item_instances", {}) as Dictionary
		var physical: Dictionary = instances.get(selected_id, {}) as Dictionary
		var elemental_level: int = int(physical.get("element_level", 0))
		if elemental_level > 0:
			var elemental_name: String = str({"fire":"화령","water":"수령","earth":"지령","wind":"풍령"}.get(str(physical.get("element", "")), ""))
			lines.append("[color=#f1d47a]속성 강화 %s %d단계[/color]" % [elemental_name, elemental_level])
	if enhance_level > 0:
		lines.append("[color=#ffd36a][b]강화 +%d[/b][/color]" % enhance_level)
	if bless_state == "blessed":
		lines.append("[color=#ffe77a]✦ 축복 아이템[/color]")
	elif bless_state == "cursed":
		lines.append("[color=#d76cff]☠ 저주 아이템[/color]")
	if engraved:
		lines.append("[color=#86d7ff]◆ 각인 아이템[/color]")
	if enhance_level > 0 or bless_state != "normal" or engraved:
		lines.append("")
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
	quickslot_requested.emit(_base_item_name(selected_item))

func _format_number(value: int) -> String:
	var source := str(absi(value))
	var out := ""
	while source.length() > 3:
		out = "," + source.right(3) + out
		source = source.left(source.length() - 3)
	out = source + out
	return ("-" if value < 0 else "") + out
