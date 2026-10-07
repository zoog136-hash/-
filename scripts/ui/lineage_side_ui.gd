extends Control
class_name TwilightSideUI

signal action_requested(action_id: String)
signal stat_increase_requested(stat_name: String)

const GOLD := Color(0.82, 0.68, 0.40, 1.0)
const GOLD_SOFT := Color(0.68, 0.55, 0.32, 1.0)
const TEXT := Color(0.94, 0.90, 0.82, 1.0)
const TEXT_DIM := Color(0.68, 0.66, 0.60, 1.0)
const PANEL := Color(0.025, 0.027, 0.030, 0.96)
const PANEL_SOFT := Color(0.045, 0.047, 0.050, 0.94)
const SLOT_BG := Color(0.055, 0.055, 0.052, 0.94)

var character_panel: PanelContainer
var menu_panel: PanelContainer
var character_preview: TextureRect
var character_name: Label
var character_job: Label
var character_level: Label
var hp_label: Label
var mp_label: Label
var attack_label: Label
var defense_label: Label
var stat_summary: RichTextLabel
var equipment_grid: GridContainer
var weight_bar: ProgressBar
var weight_label: Label
var stat_points_label: Label
var tab_equipment: Button
var tab_stats: Button
var equipment_page: Control
var stats_page: Control
var character_state: Dictionary = {}
var equipment_buttons: Dictionary = {}

const EQUIPMENT_SLOTS: Array = [
	["helmet", "투구"], ["necklace", "목걸이"], ["weapon", "무기"], ["offhand", "보조"],
	["tshirt", "티셔츠"], ["cloak", "망토"], ["body", "갑옷"], ["gloves", "장갑"],
	["ring1", "반지 I"], ["ring2", "반지 II"], ["belt", "벨트"], ["boots", "신발"]
]

const MENU_ITEMS: Array = [
	["shop", "상점", "◈"],
	["inventory", "인벤토리", "▣"],
	["skills", "스킬", "✦"],
	["quest", "퀘스트", "◆"],
	["character", "캐릭터", "♙"],
	["transform", "변신", "♜"],
	["doll", "마법인형", "♟"],
	["relic", "성물", "✧"],
	["itemdb", "아이템", "▤"],
	["map", "월드맵", "⌖"],
	["craft", "제작", "⚒"],
	["macro", "자동사냥", "◎"],
	["save", "저장", "▰"],
	["load", "불러오기", "▱"],
	["settings", "설정", "⚙"],
	["close", "닫기", "×"]
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 180
	_build_character_panel()
	_build_menu_panel()
	hide_all()

func _style(bg: Color = PANEL, border: Color = GOLD_SOFT, radius: int = 4, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _button_style(bg: Color, border: Color = GOLD_SOFT) -> StyleBoxFlat:
	return _style(bg, border, 3, 1)

func _label(text_value: String, size: int = 15, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 5)
	return sep

func _panel_base() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style())
	return panel

func _build_character_panel() -> void:
	character_panel = _panel_base()
	character_panel.name = "CharacterInfoPanel"
	character_panel.anchor_left = 0.0
	character_panel.anchor_top = 0.0
	character_panel.anchor_right = 0.49
	character_panel.anchor_bottom = 1.0
	character_panel.offset_left = 8.0
	character_panel.offset_top = 8.0
	character_panel.offset_right = -4.0
	character_panel.offset_bottom = -8.0
	add_child(character_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	character_panel.add_child(outer)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 48.0
	header.add_theme_constant_override("separation", 6)
	outer.add_child(header)

	var title := _label("캐릭터 정보", 22, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	tab_equipment = Button.new()
	tab_equipment.text = "장비"
	tab_equipment.custom_minimum_size = Vector2(76, 38)
	tab_equipment.add_theme_stylebox_override("normal", _button_style(Color(0.09, 0.08, 0.055, 0.96), GOLD))
	tab_equipment.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.14, 0.075, 1.0), GOLD))
	tab_equipment.pressed.connect(_show_equipment_page)
	header.add_child(tab_equipment)

	tab_stats = Button.new()
	tab_stats.text = "스탯"
	tab_stats.custom_minimum_size = Vector2(76, 38)
	tab_stats.add_theme_stylebox_override("normal", _button_style(Color(0.06, 0.06, 0.055, 0.96), GOLD_SOFT))
	tab_stats.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.14, 0.075, 1.0), GOLD))
	tab_stats.pressed.connect(_show_stats_page)
	header.add_child(tab_stats)

	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 38)
	close.add_theme_font_size_override("font_size", 23)
	close.add_theme_color_override("font_color", TEXT)
	close.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.045, 0.04, 0.96), Color(0.42, 0.24, 0.18, 1.0)))
	close.pressed.connect(func() -> void: character_panel.visible = false)
	header.add_child(close)

	outer.add_child(_separator())

	var identity := HBoxContainer.new()
	identity.custom_minimum_size.y = 82.0
	identity.add_theme_constant_override("separation", 10)
	outer.add_child(identity)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(74, 74)
	portrait_frame.add_theme_stylebox_override("panel", _style(Color(0.02,0.02,0.02,1), GOLD, 37, 2))
	identity.add_child(portrait_frame)
	character_preview = TextureRect.new()
	character_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(character_preview)

	var id_box := VBoxContainer.new()
	id_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_box.add_theme_constant_override("separation", 2)
	identity.add_child(id_box)
	character_name = _label("황혼의 기사", 20, TEXT)
	id_box.add_child(character_name)
	character_job = _label("기사", 14, GOLD)
	id_box.add_child(character_job)
	character_level = _label("Lv. 1", 14, TEXT_DIM)
	id_box.add_child(character_level)

	var vital_box := VBoxContainer.new()
	vital_box.custom_minimum_size.x = 180.0
	vital_box.add_theme_constant_override("separation", 2)
	identity.add_child(vital_box)
	hp_label = _label("HP 0 / 0", 14)
	mp_label = _label("MP 0 / 0", 14)
	attack_label = _label("공격 0", 13, TEXT_DIM)
	defense_label = _label("방어 0", 13, TEXT_DIM)
	vital_box.add_child(hp_label)
	vital_box.add_child(mp_label)
	var combat_row := HBoxContainer.new()
	combat_row.add_child(attack_label)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 12.0
	combat_row.add_child(spacer)
	combat_row.add_child(defense_label)
	vital_box.add_child(combat_row)

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(pages)

	equipment_page = _build_equipment_page()
	equipment_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.add_child(equipment_page)

	stats_page = _build_stats_page()
	stats_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.add_child(stats_page)
	stats_page.visible = false

	var weight_box := VBoxContainer.new()
	weight_box.add_theme_constant_override("separation", 2)
	outer.add_child(weight_box)
	var weight_header := HBoxContainer.new()
	weight_box.add_child(weight_header)
	var weight_title := _label("무게", 14, GOLD)
	weight_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weight_header.add_child(weight_title)
	weight_label = _label("0 / 0  (0%)", 13, TEXT_DIM)
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weight_header.add_child(weight_label)
	weight_bar = ProgressBar.new()
	weight_bar.custom_minimum_size.y = 12.0
	weight_bar.show_percentage = false
	weight_bar.max_value = 100.0
	weight_bar.add_theme_stylebox_override("background", _style(Color(0.025,0.025,0.025,1), Color(0.14,0.14,0.13,1), 2, 1))
	weight_bar.add_theme_stylebox_override("fill", _style(Color(0.48,0.38,0.16,1), GOLD, 2, 0))
	weight_box.add_child(weight_bar)

func _build_equipment_page() -> Control:
	var root := Control.new()
	var left := VBoxContainer.new()
	left.anchor_left = 0.0
	left.anchor_top = 0.0
	left.anchor_right = 0.62
	left.anchor_bottom = 1.0
	left.offset_right = -4.0
	left.add_theme_constant_override("separation", 5)
	root.add_child(left)

	var equip_title := _label("장착 장비", 16, GOLD)
	equip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(equip_title)

	equipment_grid = GridContainer.new()
	equipment_grid.columns = 3
	equipment_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_grid.add_theme_constant_override("h_separation", 5)
	equipment_grid.add_theme_constant_override("v_separation", 5)
	left.add_child(equipment_grid)

	for slot_data: Array in EQUIPMENT_SLOTS:
		var slot_key := str(slot_data[0])
		var slot_label := str(slot_data[1])
		var button := Button.new()
		button.custom_minimum_size = Vector2(104, 70)
		button.text = "%s\n-" % slot_label
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_stylebox_override("normal", _button_style(SLOT_BG, Color(0.30, 0.26, 0.18, 1.0)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.10,0.09,0.065,0.98), GOLD_SOFT))
		button.disabled = true
		equipment_grid.add_child(button)
		equipment_buttons[slot_key] = button

	var set_row := HBoxContainer.new()
	set_row.alignment = BoxContainer.ALIGNMENT_CENTER
	set_row.add_theme_constant_override("separation", 6)
	left.add_child(set_row)
	for set_no: int in range(1, 4):
		var set_button := Button.new()
		set_button.text = "%d SET" % set_no
		set_button.custom_minimum_size = Vector2(76, 30)
		set_button.add_theme_font_size_override("font_size", 11)
		set_button.add_theme_stylebox_override("normal", _button_style(Color(0.06,0.06,0.055,1), GOLD_SOFT))
		set_button.disabled = set_no != 1
		set_row.add_child(set_button)

	var right := VBoxContainer.new()
	right.anchor_left = 0.62
	right.anchor_top = 0.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = 4.0
	right.add_theme_constant_override("separation", 5)
	root.add_child(right)
	var stat_title := _label("전투 정보", 16, GOLD)
	stat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(stat_title)
	stat_summary = RichTextLabel.new()
	stat_summary.bbcode_enabled = true
	stat_summary.fit_content = false
	stat_summary.scroll_active = true
	stat_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_summary.add_theme_font_size_override("normal_font_size", 13)
	stat_summary.add_theme_color_override("default_color", TEXT)
	right.add_child(stat_summary)
	return root

func _build_stats_page() -> Control:
	var root := Control.new()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)

	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var title := _label("기본 스테이터스", 17, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	stat_points_label = _label("남은 포인트 0", 13, TEXT_DIM)
	title_row.add_child(stat_points_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 7)
	box.add_child(grid)

	for stat_name: String in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 48)
		row.add_theme_constant_override("separation", 5)
		var name_label := _label(stat_name, 16, GOLD)
		name_label.custom_minimum_size.x = 44.0
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		var value := Label.new()
		value.name = stat_name + "Value"
		value.text = "0"
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 19)
		value.add_theme_color_override("font_color", TEXT)
		row.add_child(value)
		var plus := Button.new()
		plus.name = stat_name + "Plus"
		plus.text = "+"
		plus.custom_minimum_size = Vector2(42, 38)
		plus.add_theme_font_size_override("font_size", 20)
		plus.add_theme_stylebox_override("normal", _button_style(Color(0.09,0.075,0.045,1), GOLD_SOFT))
		plus.pressed.connect(_emit_stat_increase.bind(stat_name))
		row.add_child(plus)
		grid.add_child(row)

	var hint := _label("스탯 포인트는 캐릭터 성장에 따라 획득합니다.", 12, TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	return root

func _emit_stat_increase(stat_name: String) -> void:
	stat_increase_requested.emit(stat_name)

func _build_menu_panel() -> void:
	menu_panel = _panel_base()
	menu_panel.name = "RightMenuPanel"
	menu_panel.anchor_left = 0.62
	menu_panel.anchor_top = 0.0
	menu_panel.anchor_right = 1.0
	menu_panel.anchor_bottom = 1.0
	menu_panel.offset_left = 4.0
	menu_panel.offset_top = 8.0
	menu_panel.offset_right = -8.0
	menu_panel.offset_bottom = -8.0
	menu_panel.add_theme_stylebox_override("panel", _style(Color(0.018,0.020,0.023,0.97), GOLD_SOFT, 4, 1))
	add_child(menu_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	menu_panel.add_child(outer)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 52.0
	outer.add_child(header)
	var title := _label("메뉴", 23, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var subtitle := _label("황혼의 기사", 12, TEXT_DIM)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(subtitle)

	outer.add_child(_separator())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	outer.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	for menu_data: Array in MENU_ITEMS:
		var action_id := str(menu_data[0])
		var label_text := str(menu_data[1])
		var glyph := str(menu_data[2])
		var button := Button.new()
		button.custom_minimum_size = Vector2(102, 90)
		button.text = "%s\n%s" % [glyph, label_text]
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _button_style(Color(0.052,0.052,0.048,0.96), Color(0.29,0.25,0.17,1)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.12,0.10,0.06,0.98), GOLD))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.17,0.13,0.07,1), GOLD))
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(_on_menu_pressed.bind(action_id))
		grid.add_child(button)

	var footer := _label("메뉴를 선택하면 해당 기능 창이 열립니다.", 12, TEXT_DIM)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(footer)

func _on_menu_pressed(action_id: String) -> void:
	if action_id == "close":
		menu_panel.visible = false
		return
	action_requested.emit(action_id)

func hide_all() -> void:
	if character_panel != null:
		character_panel.visible = false
	if menu_panel != null:
		menu_panel.visible = false

func toggle_menu() -> void:
	if menu_panel == null:
		return
	var target := not menu_panel.visible
	character_panel.visible = false
	menu_panel.visible = target

func show_menu() -> void:
	if character_panel != null:
		character_panel.visible = false
	if menu_panel != null:
		menu_panel.visible = true

func show_character(state: Dictionary = {}) -> void:
	if not state.is_empty():
		set_character_state(state)
	if menu_panel != null:
		menu_panel.visible = false
	if character_panel != null:
		character_panel.visible = true

func _show_equipment_page() -> void:
	equipment_page.visible = true
	stats_page.visible = false
	tab_equipment.disabled = true
	tab_stats.disabled = false

func _show_stats_page() -> void:
	equipment_page.visible = false
	stats_page.visible = true
	tab_equipment.disabled = false
	tab_stats.disabled = true

func set_character_state(state: Dictionary) -> void:
	character_state = state.duplicate(true)
	_refresh_character()

func _refresh_character() -> void:
	if character_panel == null:
		return
	var current_job := str(character_state.get("job_class", "기사"))
	var level := int(character_state.get("level", 1))
	character_name.text = str(character_state.get("character_name", "황혼의 기사"))
	character_job.text = current_job
	character_level.text = "Lv. %d" % level
	hp_label.text = "HP %d / %d" % [int(character_state.get("hp", 0)), int(character_state.get("max_hp", 0))]
	mp_label.text = "MP %d / %d" % [int(character_state.get("mp", 0)), int(character_state.get("max_mp", 0))]
	attack_label.text = "공격 %d" % int(character_state.get("attack", character_state.get("melee_damage", 0)))
	defense_label.text = "방어 %d" % int(character_state.get("defense", character_state.get("ac", 0)))

	var image_path := str(character_state.get("job_image_path", ""))
	if image_path != "" and ResourceLoader.exists(image_path):
		character_preview.texture = load(image_path) as Texture2D

	var equipped_items: Dictionary = character_state.get("equipped_items", {}) as Dictionary
	for slot_data: Array in EQUIPMENT_SLOTS:
		var key := str(slot_data[0])
		var slot_label := str(slot_data[1])
		var button_variant: Variant = equipment_buttons.get(key)
		if not (button_variant is Button):
			continue
		var button := button_variant as Button
		var record_variant: Variant = equipped_items.get(key, {})
		var item_name := "-"
		if record_variant is Dictionary:
			var record := record_variant as Dictionary
			if not record.is_empty():
				item_name = str(record.get("name", "-"))
		if item_name.length() > 9:
			item_name = item_name.left(8) + "…"
		button.text = "%s\n%s" % [slot_label, item_name]

	var stat_lines := PackedStringArray()
	stat_lines.append("[color=#d5b56a][b]공격 능력[/b][/color]")
	stat_lines.append("근거리 대미지  %d" % int(character_state.get("melee_damage", 0)))
	stat_lines.append("근거리 명중    %d" % int(character_state.get("melee_accuracy", 0)))
	stat_lines.append("원거리 대미지  %d" % int(character_state.get("ranged_damage", 0)))
	stat_lines.append("마법 대미지    %d" % int(character_state.get("magic_damage", 0)))
	stat_lines.append("")
	stat_lines.append("[color=#d5b56a][b]방어 능력[/b][/color]")
	stat_lines.append("AC  %d    MR  %d" % [int(character_state.get("ac", 0)), int(character_state.get("mr", 0))])
	stat_lines.append("DG  %d    ER  %d" % [int(character_state.get("dg", 0)), int(character_state.get("er", 0))])
	stat_lines.append("대미지 리덕션  %d" % int(character_state.get("damage_reduction", 0)))
	stat_lines.append("")
	stat_lines.append("[color=#d5b56a][b]속도[/b][/color]")
	stat_lines.append("공격 속도 +%.1f%%" % float(character_state.get("attack_speed_bonus", 0.0)))
	stat_lines.append("이동 속도 +%.1f%%" % float(character_state.get("move_speed_bonus", 0.0)))
	stat_summary.text = "\n".join(stat_lines)

	var stat_points := int(character_state.get("stat_points", 0))
	stat_points_label.text = "남은 포인트 %d" % stat_points
	for stat_name: String in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		var value_label := stats_page.find_child(stat_name + "Value", true, false) as Label
		if value_label != null:
			value_label.text = str(int(character_state.get(stat_name.to_lower(), 0)))
		var plus_button := stats_page.find_child(stat_name + "Plus", true, false) as Button
		if plus_button != null:
			plus_button.disabled = stat_points <= 0

	var current_weight := float(character_state.get("current_weight", 0.0))
	var max_weight := float(character_state.get("max_weight", 0.0))
	var ratio := 0.0
	if max_weight > 0.0:
		ratio = clampf(current_weight / max_weight * 100.0, 0.0, 100.0)
	weight_bar.value = ratio
	if max_weight > 0.0:
		weight_label.text = "%d / %d  (%.0f%%)" % [int(current_weight), int(max_weight), ratio]
	else:
		weight_label.text = "무게 시스템 연결 대기"
