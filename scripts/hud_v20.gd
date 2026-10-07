extends "res://scripts/hud.gd"

# V20 gameplay HUD overlay inspired by classic mobile MMORPG layouts.
# Keeps the V19 catalog/inventory/map panels and replaces only the always-visible combat HUD.

var v20_layer: Control
var v20_portrait: TextureRect
var v20_level_badge: Label
var v20_hp_text: Label
var v20_mp_text: Label
var v20_stat_text: Label
var v20_map_name: Label
var v20_quest_text: RichTextLabel
var v20_potion_count: Label
var v20_leaf_count: Label
var v20_auto_button: Button
var v20_target_name: Label
var v20_target_hp: ProgressBar
var v20_target_panel: PanelContainer
var v20_status_name: Label

const V20_CLASS_SHEETS: Array[String] = [
	"res://assets/sprites/classes/warrior.png",
	"res://assets/sprites/classes/mage.png",
	"res://assets/sprites/classes/archer.png",
	"res://assets/sprites/classes/assassin.png"
]

func _ready() -> void:
	super._ready()
	_build_v20_gameplay_hud()

func _build_v20_gameplay_hud() -> void:
	# Hide only the old always-visible HUD. The modal panels remain intact.
	$Root/TopLeft.visible = false
	$Root/TopRight.visible = false
	$Root/MapLabel.visible = false
	$Root/TargetPanel.visible = false
	$Root/RightControls.visible = false
	$Root/ExpBar.visible = false
	$Root/MessageLabel.visible = false
	$Root/LogPanel.visible = false

	# Joystick is still the real input control, just moved to match the reference layout.
	joystick.offset_left = 30.0
	joystick.offset_top = -198.0
	joystick.offset_right = 198.0
	joystick.offset_bottom = -30.0
	joystick.z_index = 40
	inventory_panel.z_index = 120
	map_panel.z_index = 120
	menu_panel.z_index = 120

	v20_layer = Control.new()
	v20_layer.name = "V20GameplayHUD"
	v20_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	v20_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v20_layer.z_index = 35
	$Root.add_child(v20_layer)
	$Root.move_child(v20_layer, 0)

	_build_v20_status()
	_build_v20_buffs()
	_build_v20_quest()
	_build_v20_top_menu()
	_build_v20_target()
	_build_v20_right_controls()
	_build_v20_bottom_bar()
	_build_v20_message_and_log()

	_update_v20_portrait(0)
	set_quick_items({"HP 물약": 100, "초록 잎": 200})
	set_quest_progress(0, 9)

func _panel_style(alpha: float = 0.88, radius: int = 6, border: Color = Color(0.52, 0.40, 0.22, 0.95)) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.022, alpha)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _button_style(alpha: float = 0.84, radius: int = 7) -> StyleBoxFlat:
	var style: StyleBoxFlat = _panel_style(alpha, radius, Color(0.45, 0.36, 0.22, 0.9))
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _round_button_style(alpha: float, radius: int, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.025, alpha)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _bar_background() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.035, 0.035, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.12, 0.12, 0.12, 1.0)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _bar_fill(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

func _place(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom

func _load_texture(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _make_icon_button(parent: Control, path: String, text_value: String, rect: Rect2, font_size: int = 13) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.icon = _load_texture(path)
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.94, 0.87, 0.72, 1.0))
	button.add_theme_stylebox_override("normal", _button_style())
	button.add_theme_stylebox_override("hover", _button_style(0.96))
	button.add_theme_stylebox_override("pressed", _button_style(1.0))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(button, rect.position.x, rect.position.y, rect.end.x, rect.end.y)
	parent.add_child(button)
	return button

func _build_v20_status() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "StatusPanel"
	panel.add_theme_stylebox_override("panel", _panel_style(0.91, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, 10.0, 8.0, 370.0, 114.0)
	v20_layer.add_child(panel)

	var content: Control = Control.new()
	content.custom_minimum_size = Vector2(360.0, 106.0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var portrait_frame: PanelContainer = PanelContainer.new()
	portrait_frame.add_theme_stylebox_override("panel", _round_button_style(0.96, 42, Color(0.62, 0.48, 0.24, 1.0)))
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(portrait_frame, 6.0, 5.0, 92.0, 99.0)
	content.add_child(portrait_frame)

	v20_portrait = TextureRect.new()
	v20_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v20_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v20_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(v20_portrait)

	v20_level_badge = Label.new()
	v20_level_badge.text = "35"
	v20_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v20_level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v20_level_badge.add_theme_font_size_override("font_size", 15)
	v20_level_badge.add_theme_color_override("font_color", Color(1.0, 0.90, 0.68, 1.0))
	v20_level_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	v20_level_badge.add_theme_constant_override("outline_size", 3)
	_place(v20_level_badge, 66.0, 72.0, 96.0, 100.0)
	content.add_child(v20_level_badge)

	v20_status_name = Label.new()
	v20_status_name.text = "황혼의 기사"
	v20_status_name.add_theme_font_size_override("font_size", 18)
	v20_status_name.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80, 1.0))
	v20_status_name.add_theme_color_override("font_outline_color", Color.BLACK)
	v20_status_name.add_theme_constant_override("outline_size", 3)
	_place(v20_status_name, 101.0, 7.0, 349.0, 31.0)
	content.add_child(v20_status_name)
	player_label = v20_status_name

	var hp: ProgressBar = ProgressBar.new()
	hp.show_percentage = false
	hp.add_theme_stylebox_override("background", _bar_background())
	hp.add_theme_stylebox_override("fill", _bar_fill(Color(0.72, 0.04, 0.035, 1.0)))
	_place(hp, 101.0, 33.0, 347.0, 51.0)
	content.add_child(hp)
	hp_bar = hp

	v20_hp_text = Label.new()
	v20_hp_text.text = "1832 / 1832"
	v20_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v20_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v20_hp_text.add_theme_font_size_override("font_size", 13)
	v20_hp_text.add_theme_color_override("font_color", Color.WHITE)
	v20_hp_text.add_theme_color_override("font_outline_color", Color.BLACK)
	v20_hp_text.add_theme_constant_override("outline_size", 2)
	_place(v20_hp_text, 101.0, 32.0, 347.0, 52.0)
	content.add_child(v20_hp_text)

	var mp: ProgressBar = ProgressBar.new()
	mp.show_percentage = false
	mp.add_theme_stylebox_override("background", _bar_background())
	mp.add_theme_stylebox_override("fill", _bar_fill(Color(0.04, 0.26, 0.72, 1.0)))
	_place(mp, 101.0, 55.0, 347.0, 72.0)
	content.add_child(mp)
	mp_bar = mp

	v20_mp_text = Label.new()
	v20_mp_text.text = "315 / 375"
	v20_mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v20_mp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v20_mp_text.add_theme_font_size_override("font_size", 12)
	v20_mp_text.add_theme_color_override("font_color", Color.WHITE)
	v20_mp_text.add_theme_color_override("font_outline_color", Color.BLACK)
	v20_mp_text.add_theme_constant_override("outline_size", 2)
	_place(v20_mp_text, 101.0, 54.0, 347.0, 73.0)
	content.add_child(v20_mp_text)

	v20_stat_text = Label.new()
	v20_stat_text.text = "⚔ 42    ◈ 19    ✦ 24    ⚡ 5"
	v20_stat_text.add_theme_font_size_override("font_size", 14)
	v20_stat_text.add_theme_color_override("font_color", Color(0.90, 0.83, 0.67, 1.0))
	_place(v20_stat_text, 101.0, 78.0, 349.0, 100.0)
	content.add_child(v20_stat_text)

	gold_label = Label.new()
	gold_label.visible = false
	content.add_child(gold_label)

	# Two immediate-use item slots next to the status block.
	var red: Button = _make_icon_button(v20_layer, "res://assets/ui/potionRed.png", "", Rect2(380.0, 15.0, 58.0, 66.0), 12)
	red.pressed.connect(func() -> void: potion_pressed.emit())
	v20_potion_count = Label.new()
	v20_potion_count.text = "100"
	v20_potion_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v20_potion_count.add_theme_font_size_override("font_size", 14)
	v20_potion_count.add_theme_color_override("font_color", Color(0.98, 0.90, 0.72, 1.0))
	v20_potion_count.add_theme_color_override("font_outline_color", Color.BLACK)
	v20_potion_count.add_theme_constant_override("outline_size", 3)
	_place(v20_potion_count, 380.0, 61.0, 436.0, 82.0)
	v20_layer.add_child(v20_potion_count)

	var leaf: Button = _make_icon_button(v20_layer, "res://assets/ui/leaf.png", "", Rect2(442.0, 15.0, 58.0, 66.0), 12)
	leaf.pressed.connect(func() -> void: show_message("가속 아이템 사용 준비중"))
	v20_leaf_count = Label.new()
	v20_leaf_count.text = "200"
	v20_leaf_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v20_leaf_count.add_theme_font_size_override("font_size", 14)
	v20_leaf_count.add_theme_color_override("font_color", Color(0.98, 0.90, 0.72, 1.0))
	v20_leaf_count.add_theme_color_override("font_outline_color", Color.BLACK)
	v20_leaf_count.add_theme_constant_override("outline_size", 3)
	_place(v20_leaf_count, 442.0, 61.0, 498.0, 82.0)
	v20_layer.add_child(v20_leaf_count)

func _build_v20_buffs() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.80, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, 10.0, 121.0, 305.0, 166.0)
	v20_layer.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	var title: Label = Label.new()
	title.text = "Buff"
	title.custom_minimum_size = Vector2(52.0, 38.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.84, 0.80, 0.70, 1.0))
	row.add_child(title)
	for path: String in ["res://assets/ui/wind.png", "res://assets/ui/energy.png", "res://assets/ui/fire.png", "res://assets/ui/shield.png"]:
		var slot: TextureRect = TextureRect.new()
		slot.custom_minimum_size = Vector2(48.0, 38.0)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture = _load_texture(path)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)

func _build_v20_quest() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.84, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, 10.0, 174.0, 340.0, 288.0)
	v20_layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var tabs: Label = Label.new()
	tabs.text = "▣ 퀘스트        파티        선택 대상"
	tabs.add_theme_font_size_override("font_size", 14)
	tabs.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70, 1.0))
	box.add_child(tabs)
	var line: HSeparator = HSeparator.new()
	box.add_child(line)
	v20_quest_text = RichTextLabel.new()
	v20_quest_text.bbcode_enabled = true
	v20_quest_text.fit_content = true
	v20_quest_text.scroll_active = false
	v20_quest_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v20_quest_text.add_theme_font_size_override("normal_font_size", 15)
	v20_quest_text.text = "[color=#d7b564][메인][/color] 몬스터의 세력 다툼\n몬스터 처치 (0/9)"
	box.add_child(v20_quest_text)

func _build_v20_top_menu() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.89, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, 826.0, 8.0, 1272.0, 90.0)
	v20_layer.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var shop: Button = _top_menu_button("res://assets/ui/shop.png", "상점")
	shop.pressed.connect(func() -> void: show_message("상점 기능은 준비중"))
	row.add_child(shop)
	var bag: Button = _top_menu_button("res://assets/ui/bag.png", "가방")
	bag.pressed.connect(func() -> void: inventory_pressed.emit())
	row.add_child(bag)
	var skill: Button = _top_menu_button("res://assets/ui/skill.png", "스킬")
	skill.pressed.connect(func() -> void: show_message("스킬 창은 다음 단계에서 확장"))
	row.add_child(skill)
	var quest: Button = _top_menu_button("res://assets/ui/quest.png", "퀘스트")
	quest.pressed.connect(func() -> void: show_message("메인 퀘스트 추적 중"))
	row.add_child(quest)
	var menu: Button = _top_menu_button("res://assets/ui/menu.png", "메뉴")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	row.add_child(menu)

func _top_menu_button(path: String, label_text: String) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(82.0, 72.0)
	button.text = label_text
	button.icon = _load_texture(path)
	button.expand_icon = true
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.92, 0.84, 0.69, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(0.25, 3))
	button.add_theme_stylebox_override("hover", _button_style(0.55, 3))
	button.add_theme_stylebox_override("pressed", _button_style(0.75, 3))
	return button

func _build_v20_target() -> void:
	v20_target_panel = PanelContainer.new()
	v20_target_panel.add_theme_stylebox_override("panel", _panel_style(0.84, 4, Color(0.55, 0.28, 0.19, 0.95)))
	v20_target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(v20_target_panel, 468.0, 58.0, 812.0, 108.0)
	v20_layer.add_child(v20_target_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	v20_target_panel.add_child(box)
	v20_target_name = Label.new()
	v20_target_name.text = "대상"
	v20_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v20_target_name.add_theme_font_size_override("font_size", 15)
	v20_target_name.add_theme_color_override("font_color", Color(0.96, 0.86, 0.72, 1.0))
	box.add_child(v20_target_name)
	v20_target_hp = ProgressBar.new()
	v20_target_hp.custom_minimum_size = Vector2(330.0, 12.0)
	v20_target_hp.show_percentage = false
	v20_target_hp.add_theme_stylebox_override("background", _bar_background())
	v20_target_hp.add_theme_stylebox_override("fill", _bar_fill(Color(0.70, 0.05, 0.04, 1.0)))
	box.add_child(v20_target_hp)
	v20_target_panel.visible = false
	target_panel = v20_target_panel
	target_label = v20_target_name
	target_hp = v20_target_hp

	var map_panel_small: PanelContainer = PanelContainer.new()
	map_panel_small.add_theme_stylebox_override("panel", _panel_style(0.68, 4))
	map_panel_small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(map_panel_small, 510.0, 10.0, 770.0, 44.0)
	v20_layer.add_child(map_panel_small)
	v20_map_name = Label.new()
	v20_map_name.text = "아덴 월드"
	v20_map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v20_map_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v20_map_name.add_theme_font_size_override("font_size", 15)
	v20_map_name.add_theme_color_override("font_color", Color(0.94, 0.87, 0.72, 1.0))
	map_panel_small.add_child(v20_map_name)

func _build_v20_right_controls() -> void:
	var self_button: Button = Button.new()
	self_button.text = "SELF"
	self_button.add_theme_font_size_override("font_size", 16)
	self_button.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82, 1.0))
	self_button.add_theme_stylebox_override("normal", _round_button_style(0.68, 38, Color(0.75, 0.72, 0.61, 0.9)))
	self_button.add_theme_stylebox_override("pressed", _round_button_style(0.92, 38, Color(0.96, 0.82, 0.45, 1.0)))
	_place(self_button, 1035.0, 367.0, 1109.0, 441.0)
	self_button.mouse_filter = Control.MOUSE_FILTER_STOP
	self_button.pressed.connect(func() -> void: show_message("SELF 대상"))
	v20_layer.add_child(self_button)

	var target_button: Button = Button.new()
	target_button.text = "대상"
	target_button.icon = _load_texture("res://assets/ui/eye.png")
	target_button.expand_icon = true
	target_button.add_theme_font_size_override("font_size", 13)
	target_button.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82, 1.0))
	target_button.add_theme_stylebox_override("normal", _round_button_style(0.68, 38, Color(0.75, 0.72, 0.61, 0.9)))
	target_button.add_theme_stylebox_override("pressed", _round_button_style(0.92, 38, Color(0.96, 0.82, 0.45, 1.0)))
	_place(target_button, 1148.0, 390.0, 1222.0, 464.0)
	target_button.mouse_filter = Control.MOUSE_FILTER_STOP
	target_button.pressed.connect(func() -> void: show_message("가까운 몬스터를 공격 버튼으로 선택"))
	v20_layer.add_child(target_button)

	v20_auto_button = Button.new()
	v20_auto_button.text = "AUTO"
	v20_auto_button.add_theme_font_size_override("font_size", 16)
	v20_auto_button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.70, 1.0))
	v20_auto_button.add_theme_stylebox_override("normal", _round_button_style(0.70, 43, Color(0.65, 0.58, 0.42, 0.95)))
	v20_auto_button.add_theme_stylebox_override("pressed", _round_button_style(0.96, 43, Color(0.95, 0.76, 0.29, 1.0)))
	_place(v20_auto_button, 1012.0, 492.0, 1098.0, 578.0)
	v20_auto_button.mouse_filter = Control.MOUSE_FILTER_STOP
	v20_auto_button.pressed.connect(func() -> void: auto_pressed.emit())
	v20_layer.add_child(v20_auto_button)
	auto_button = v20_auto_button

	var attack: Button = Button.new()
	attack.text = "공격"
	attack.icon = _load_texture("res://assets/ui/attack.png")
	attack.expand_icon = true
	attack.add_theme_font_size_override("font_size", 15)
	attack.add_theme_color_override("font_color", Color(1.0, 0.91, 0.76, 1.0))
	attack.add_theme_stylebox_override("normal", _round_button_style(0.76, 55, Color(0.72, 0.62, 0.45, 0.98)))
	attack.add_theme_stylebox_override("pressed", _round_button_style(1.0, 55, Color(1.0, 0.74, 0.26, 1.0)))
	_place(attack, 1112.0, 485.0, 1224.0, 597.0)
	attack.mouse_filter = Control.MOUSE_FILTER_STOP
	attack.pressed.connect(func() -> void: attack_pressed.emit())
	v20_layer.add_child(attack)

func _build_v20_bottom_bar() -> void:
	# EXP panel bottom-left.
	var exp_panel: PanelContainer = PanelContainer.new()
	exp_panel.add_theme_stylebox_override("panel", _panel_style(0.82, 6))
	exp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(exp_panel, 8.0, 674.0, 248.0, 716.0)
	v20_layer.add_child(exp_panel)
	var exp_box: VBoxContainer = VBoxContainer.new()
	exp_box.add_theme_constant_override("separation", 1)
	exp_panel.add_child(exp_box)
	var exp_title: Label = Label.new()
	exp_title.text = "EXP"
	exp_title.add_theme_font_size_override("font_size", 13)
	exp_title.add_theme_color_override("font_color", Color(0.90, 0.84, 0.71, 1.0))
	exp_box.add_child(exp_title)
	var experience_bar: ProgressBar = ProgressBar.new()
	experience_bar.custom_minimum_size = Vector2(226.0, 11.0)
	experience_bar.show_percentage = false
	experience_bar.add_theme_stylebox_override("background", _bar_background())
	experience_bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.95, 0.60, 0.12, 1.0)))
	exp_box.add_child(experience_bar)
	exp_bar = experience_bar

	# System buttons.
	var sys_panel: PanelContainer = PanelContainer.new()
	sys_panel.add_theme_stylebox_override("panel", _panel_style(0.82, 5))
	sys_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(sys_panel, 257.0, 650.0, 430.0, 716.0)
	v20_layer.add_child(sys_panel)
	var sys: HBoxContainer = HBoxContainer.new()
	sys.add_theme_constant_override("separation", 4)
	sys_panel.add_child(sys)
	for data: Array in [
		["res://assets/ui/macro.png", "매크로"],
		["res://assets/ui/chat.png", "채팅"],
		["res://assets/ui/settings.png", "설정"]
	]:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(52.0, 58.0)
		button.text = str(data[1])
		button.icon = _load_texture(str(data[0]))
		button.expand_icon = true
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_stylebox_override("normal", _button_style(0.20, 3))
		button.add_theme_stylebox_override("pressed", _button_style(0.65, 3))
		button.pressed.connect(func() -> void: show_message("%s 기능" % str(data[1])))
		sys.add_child(button)

	# Skill quick slots. Keep combat skills here; potion/AUTO already have
	# dedicated controls elsewhere in the HUD.
	var skill_panel: PanelContainer = PanelContainer.new()
	skill_panel.add_theme_stylebox_override("panel", _panel_style(0.86, 5))
	skill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(skill_panel, 446.0, 637.0, 892.0, 716.0)
	v20_layer.add_child(skill_panel)
	var skills: HBoxContainer = HBoxContainer.new()
	skills.add_theme_constant_override("separation", 5)
	skill_panel.add_child(skills)
	var skill_defs: Array = [
		["res://assets/ui/attack.png", "공격", "attack"],
		["res://assets/ui/fire.png", "출혈", "bleed"],
		["res://assets/ui/energy.png", "스턴", "stun"],
		["res://assets/ui/rune.png", "독", "poison"],
		["res://assets/ui/wind.png", "침묵", "silence"],
		["res://assets/ui/heal.png", "홀드", "hold"],
		["res://assets/ui/eye.png", "공포", "fear"],
		["res://assets/ui/skill.png", "마법", "magic"]
	]
	for skill_data: Array in skill_defs:
		var slot: Button = Button.new()
		var skill_id: String = str(skill_data[2])
		slot.custom_minimum_size = Vector2(50.0, 66.0)
		slot.text = str(skill_data[1])
		slot.tooltip_text = str(skill_data[1])
		slot.icon = _load_texture(str(skill_data[0]))
		slot.expand_icon = true
		slot.add_theme_font_size_override("font_size", 10)
		slot.add_theme_stylebox_override("normal", _button_style(0.92, 4))
		slot.add_theme_stylebox_override("pressed", _button_style(1.0, 4))
		slot.pressed.connect(func() -> void: combat_skill_pressed.emit(skill_id))
		skills.add_child(slot)

	# Consumable quick slots bottom-right.
	var item_panel: PanelContainer = PanelContainer.new()
	item_panel.add_theme_stylebox_override("panel", _panel_style(0.86, 5))
	item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(item_panel, 902.0, 638.0, 1268.0, 716.0)
	v20_layer.add_child(item_panel)
	var items: HBoxContainer = HBoxContainer.new()
	items.add_theme_constant_override("separation", 5)
	item_panel.add_child(items)
	var item_defs: Array = [
		["res://assets/ui/potionRed.png", "100"],
		["res://assets/ui/potionGreen.png", "14"],
		["res://assets/ui/potionPurple.png", "10"],
		["res://assets/ui/return.png", "귀환"]
	]
	for item_index: int in range(item_defs.size()):
		var data: Array = item_defs[item_index] as Array
		var slot: Button = Button.new()
		slot.custom_minimum_size = Vector2(82.0, 66.0)
		slot.text = str(data[1])
		slot.icon = _load_texture(str(data[0]))
		slot.expand_icon = true
		slot.add_theme_font_size_override("font_size", 11)
		slot.add_theme_stylebox_override("normal", _button_style(0.92, 4))
		slot.add_theme_stylebox_override("pressed", _button_style(1.0, 4))
		if item_index == 0:
			slot.pressed.connect(func() -> void: potion_pressed.emit())
		elif item_index == 3:
			slot.pressed.connect(func() -> void: map_pressed.emit())
		else:
			slot.pressed.connect(func() -> void: show_message("퀵 아이템 사용"))
		items.add_child(slot)

func _build_v20_message_and_log() -> void:
	var message: Label = Label.new()
	message.text = ""
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58, 1.0))
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.add_theme_constant_override("outline_size", 4)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(message, 330.0, 552.0, 930.0, 582.0)
	v20_layer.add_child(message)
	message_label = message

	var log_panel_new: PanelContainer = PanelContainer.new()
	log_panel_new.add_theme_stylebox_override("panel", _panel_style(0.54, 3, Color(0.20, 0.18, 0.14, 0.62)))
	log_panel_new.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(log_panel_new, 350.0, 585.0, 690.0, 635.0)
	v20_layer.add_child(log_panel_new)
	var log_new: RichTextLabel = RichTextLabel.new()
	log_new.bbcode_enabled = true
	log_new.scroll_active = false
	log_new.fit_content = true
	log_new.add_theme_font_size_override("normal_font_size", 11)
	log_new.add_theme_color_override("default_color", Color(0.94, 0.92, 0.85, 0.92))
	log_panel_new.add_child(log_new)
	log_label = log_new

func update_player(level: int, hp: int, max_hp: int, mp: int, max_mp: int, experience_value: int, exp_need: int, gold: int) -> void:
	super.update_player(level, hp, max_hp, mp, max_mp, experience_value, exp_need, gold)
	if v20_level_badge != null:
		v20_level_badge.text = str(level)
	if v20_hp_text != null:
		v20_hp_text.text = "%d / %d" % [hp, max_hp]
	if v20_mp_text != null:
		v20_mp_text.text = "%d / %d" % [mp, max_mp]
	if v20_status_name != null:
		v20_status_name.text = "황혼의 기사"

func set_map_name(value: String) -> void:
	super.set_map_name(value)
	if v20_map_name != null:
		v20_map_name.text = value

func set_auto(enabled: bool) -> void:
	super.set_auto(enabled)
	if v20_auto_button != null:
		v20_auto_button.text = "AUTO ON" if enabled else "AUTO"
		v20_auto_button.add_theme_color_override("font_color", Color(1.0, 0.73, 0.25, 1.0) if enabled else Color(0.95, 0.88, 0.70, 1.0))

func show_target(monster_name: String, hp: int, max_hp: int) -> void:
	super.show_target(monster_name, hp, max_hp)
	if v20_target_panel != null:
		v20_target_panel.visible = true

func clear_target() -> void:
	super.clear_target()
	if v20_target_panel != null:
		v20_target_panel.visible = false

func set_character_state(value: Dictionary) -> void:
	super.set_character_state(value)
	var class_index_value: int = clampi(int(value.get("class_index", 0)), 0, 3)
	_update_v20_portrait(class_index_value)
	if v20_stat_text != null:
		v20_stat_text.text = "⚔ %d   ◎ %d   AC %d   MR %d" % [
			int(value.get("melee_damage", value.get("attack", 0))),
			int(value.get("melee_accuracy", 0)),
			int(value.get("ac", -int(value.get("defense", 0)))),
			int(value.get("mr", 0))
		]

func _update_v20_portrait(class_index_value: int) -> void:
	if v20_portrait == null:
		return
	var path: String = V20_CLASS_SHEETS[clampi(class_index_value, 0, V20_CLASS_SHEETS.size() - 1)]
	if not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0.0, 0.0, 148.0, 116.0)
	v20_portrait.texture = atlas

func set_quick_items(inventory: Dictionary) -> void:
	if v20_potion_count != null:
		v20_potion_count.text = str(int(inventory.get("HP 물약", 0)))
	if v20_leaf_count != null:
		v20_leaf_count.text = str(int(inventory.get("초록 잎", 0)))

func set_quest_progress(current: int, goal: int) -> void:
	if v20_quest_text == null:
		return
	v20_quest_text.text = "[color=#d7b564][메인][/color] 몬스터의 세력 다툼\n몬스터 처치 (%d/%d)" % [current, goal]
