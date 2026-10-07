extends CanvasLayer
class_name TwilightHUD

signal move_vector_changed(value: Vector2)
signal attack_pressed
signal bleed_skill_pressed
signal combat_skill_pressed(skill_id: String)
signal target_pressed
signal auto_pressed
signal potion_pressed
signal quick_item_pressed(item_name: String)
signal return_pressed
signal inventory_pressed
signal menu_pressed
signal map_pressed
signal map_selected(map_id: String)
signal save_pressed
signal load_pressed
signal catalog_equip_requested(category: String, record: Dictionary)
signal class_selected(index: int)
signal stat_increase_requested(stat_name: String)
signal job_class_selected(job_name: String)
signal job_skill_pressed(skill_name: String)
signal shop_buy_requested(item_name: String, price: int)
signal inventory_item_activated(item_name: String)
signal enhancement_requested(scroll_name: String, target_name: String)
signal quickslot_pressed(slot_index: int)
signal quickslot_assignment_requested(slot_index: int, entry_kind: String, entry_id: String)
signal self_mode_changed(enabled: bool)

@onready var hp_bar: ProgressBar = $Root/TopLeft/HPBar
@onready var mp_bar: ProgressBar = $Root/TopLeft/MPBar
@onready var exp_bar: ProgressBar = $Root/ExpBar
@onready var player_label: Label = $Root/TopLeft/Stats/PlayerLabel
@onready var gold_label: Label = $Root/TopLeft/GoldLabel
@onready var map_label: Label = $Root/MapLabel
@onready var target_panel: PanelContainer = $Root/TargetPanel
@onready var target_label: Label = $Root/TargetPanel/TargetVBox/TargetLabel
@onready var target_hp: ProgressBar = $Root/TargetPanel/TargetVBox/TargetHP
@onready var auto_button: Button = $Root/RightControls/AutoButton
@onready var message_label: Label = $Root/MessageLabel
@onready var log_label: RichTextLabel = $Root/LogPanel/LogLabel
@onready var inventory_panel: PanelContainer = $Root/InventoryPanel
@onready var inventory_list: VBoxContainer = $Root/InventoryPanel/InventoryMargin/InventoryVBox/InventoryScroll/InventoryList
@onready var map_panel: PanelContainer = $Root/MapPanel
@onready var map_list: VBoxContainer = $Root/MapPanel/MapMargin/MapVBox/MapScroll/MapList
@onready var menu_panel: PanelContainer = $Root/MenuPanel
@onready var joystick: TwilightVirtualJoystick = $Root/VirtualJoystick

var message_time: float = 0.0
var catalog_data: Dictionary = {}
var item_image_index: Dictionary = {}
var catalog_panel: PanelContainer
var catalog_title: Label
var catalog_search: LineEdit
var catalog_count: Label
var catalog_list: ItemList
var catalog_preview: TextureRect
var catalog_detail: RichTextLabel
var catalog_equip_button: Button
var catalog_category: String = "변신"
var catalog_results: Array = []
var catalog_filtered_results: Array = []
var selected_catalog_record: Dictionary = {}
var catalog_page: int = 0
var catalog_page_size: int = 40
var catalog_page_label: Label
var catalog_first_button: Button
var catalog_prev_button: Button
var catalog_next_button: Button
var catalog_last_button: Button
var item_filter_panel: VBoxContainer
var item_slot_buttons: Dictionary = {}
var item_grade_buttons: Dictionary = {}
var item_slot_filter: String = "weapon"
var item_grade_filter: String = "전체"

const ITEM_SLOT_FILTERS: Array = [
	["weapon", "무기"],
	["armor", "방어구"],
	["accessory", "악세사리"],
	["consumable", "소모품"],
	["material", "재료"],
	["other", "기타"]
]
const ITEM_GRADE_ORDER: Array[String] = ["전체", "일반", "고급", "희귀", "영웅", "전설", "신화", "유일"]
var character_panel: PanelContainer
var character_preview: TextureRect
var character_info: RichTextLabel
var stat_buttons: Dictionary = {}
var character_state: Dictionary = {}
var utility_panel: PanelContainer
var utility_title: Label
var utility_body: VBoxContainer
var last_inventory_tap_item: String = ""
var last_inventory_tap_ms: int = 0
var enhancement_scroll_name: String = ""
var enhancement_candidates: Array = []
var enhancement_selected_index: int = -1
var quickslot_entries: Array = []
var job_classes: Array = []
var job_skills: Array = []
var job_class_buttons: Dictionary = {}

const CLASS_NAMES: Array[String] = ["전사", "마법사", "궁수", "암살자"]
const CLASS_SHEETS: Array[String] = [
	"res://assets/sprites/classes/warrior.png",
	"res://assets/sprites/classes/mage.png",
	"res://assets/sprites/classes/archer.png",
	"res://assets/sprites/classes/assassin.png"
]

func _ready() -> void:
	joystick.vector_changed.connect(_on_joystick_vector)
	$Root/RightControls/AttackButton.pressed.connect(func() -> void: attack_pressed.emit())
	auto_button.pressed.connect(func() -> void: auto_pressed.emit())
	$Root/RightControls/PotionButton.pressed.connect(func() -> void: potion_pressed.emit())
	$Root/TopRight/InventoryButton.pressed.connect(func() -> void: inventory_pressed.emit())
	$Root/TopRight/MenuButton.pressed.connect(func() -> void: menu_pressed.emit())
	$Root/MenuPanel/MenuMargin/MenuVBox/CharacterButton.pressed.connect(open_character)
	$Root/MenuPanel/MenuMargin/MenuVBox/TransformButton.pressed.connect(func() -> void: open_catalog("변신"))
	$Root/MenuPanel/MenuMargin/MenuVBox/DollButton.pressed.connect(func() -> void: open_catalog("마법인형"))
	$Root/MenuPanel/MenuMargin/MenuVBox/RelicButton.pressed.connect(func() -> void: open_catalog("성물"))
	$Root/MenuPanel/MenuMargin/MenuVBox/ItemDBButton.pressed.connect(func() -> void: open_catalog("아이템"))
	$Root/MenuPanel/MenuMargin/MenuVBox/WorldMapButton.pressed.connect(func() -> void: map_pressed.emit())
	$Root/MenuPanel/MenuMargin/MenuVBox/SaveButton.pressed.connect(func() -> void: save_pressed.emit())
	$Root/MenuPanel/MenuMargin/MenuVBox/LoadButton.pressed.connect(func() -> void: load_pressed.emit())
	$Root/MenuPanel/MenuMargin/MenuVBox/CloseButton.pressed.connect(toggle_menu)
	$Root/InventoryPanel/InventoryMargin/InventoryVBox/CloseInventory.pressed.connect(toggle_inventory)
	$Root/MapPanel/MapMargin/MapVBox/CloseMap.pressed.connect(toggle_map)
	_build_catalog_panel()
	_build_character_panel()
	_build_utility_panel()
	target_panel.visible = false
	inventory_panel.visible = false
	map_panel.visible = false
	menu_panel.visible = false
	catalog_panel.visible = false
	character_panel.visible = false
	utility_panel.visible = false
	_apply_theme()

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.text = ""

func _apply_theme() -> void:
	var buttons: Array[Node] = get_tree().get_nodes_in_group("hud_button")
	for node: Node in buttons:
		if node is Button:
			var button: Button = node
			button.add_theme_color_override("font_color", Color("f3e8ce"))
			button.add_theme_font_size_override("font_size", 17)
	for bar: ProgressBar in [hp_bar, mp_bar, exp_bar, target_hp]:
		bar.show_percentage = false

func _on_joystick_vector(value: Vector2) -> void:
	move_vector_changed.emit(value)

func set_catalog_data(value: Dictionary, image_index: Dictionary) -> void:
	catalog_data = value
	item_image_index = image_index

func set_character_state(value: Dictionary) -> void:
	character_state = value
	if character_panel != null and character_panel.visible:
		_refresh_character_panel()

func set_job_data(classes_value: Array, skills_value: Array) -> void:
	job_classes = classes_value.duplicate(true)
	job_skills = skills_value.duplicate(true)
	_rebuild_job_class_buttons()

func _rebuild_job_class_buttons() -> void:
	if character_panel == null:
		return
	var grid: GridContainer = character_panel.find_child("JobClassGrid", true, false) as GridContainer
	if grid == null:
		return
	_clear_children(grid)
	job_class_buttons.clear()
	for value: Variant in job_classes:
		if not (value is Dictionary):
			continue
		var profile: Dictionary = value as Dictionary
		var job_name: String = str(profile.get("name", ""))
		if job_name == "":
			continue
		var button: Button = Button.new()
		button.text = job_name
		button.custom_minimum_size = Vector2(98, 36)
		button.toggle_mode = true
		button.tooltip_text = "%s · 주무기 %s · 주스탯 %s" % [
			str(profile.get("role", "")),
			str(profile.get("weapon", "")),
			str(profile.get("primary_stat", ""))
		]
		button.pressed.connect(_emit_job_class.bind(job_name))
		grid.add_child(button)
		job_class_buttons[job_name] = button
	_refresh_job_class_selection()

func _refresh_job_class_selection() -> void:
	var current_job: String = str(character_state.get("job_class", "기사"))
	for key: Variant in job_class_buttons.keys():
		var value: Variant = job_class_buttons.get(key)
		if value is Button:
			(value as Button).button_pressed = str(key) == current_job

func _emit_job_class(job_name: String) -> void:
	job_class_selected.emit(job_name)

func _emit_job_skill(skill_name: String) -> void:
	job_skill_pressed.emit(skill_name)

func set_quickslot_entries(entries: Array) -> void:
	quickslot_entries = entries.duplicate(true)

func _open_quickslot_picker(entry_kind: String, entry_id: String, display_name: String) -> void:
	_open_utility_panel("퀵슬롯 등록")
	_utility_add_text("[font_size=20][b]%s[/b][/font_size]\n등록할 슬롯을 선택하세요. 기존 내용은 교체됩니다." % display_name)
	for index: int in range(8):
		var current_text: String = "비어 있음"
		if index < quickslot_entries.size() and quickslot_entries[index] is Dictionary:
			var current: Dictionary = quickslot_entries[index] as Dictionary
			if not current.is_empty():
				current_text = str(current.get("id", current.get("name", "등록됨")))
		var button: Button = Button.new()
		button.text = "%d번 슬롯  ·  %s" % [index + 1, current_text]
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_emit_quickslot_assignment.bind(index, entry_kind, entry_id))
		utility_body.add_child(button)

func _emit_quickslot_assignment(slot_index: int, entry_kind: String, entry_id: String) -> void:
	quickslot_assignment_requested.emit(slot_index, entry_kind, entry_id)
	utility_panel.visible = false
	show_message("퀵슬롯 %d번에 등록" % (slot_index + 1))

func _job_profile(job_name: String) -> Dictionary:
	for value: Variant in job_classes:
		if value is Dictionary:
			var profile: Dictionary = value as Dictionary
			if str(profile.get("name", "")) == job_name:
				return profile
	return {}

func update_player(level: int, hp: int, max_hp: int, mp: int, max_mp: int, experience_value: int, exp_need: int, gold: int) -> void:
	player_label.text = "황혼의 기사  Lv.%d" % level
	hp_bar.max_value = maxi(1, max_hp)
	hp_bar.value = hp
	mp_bar.max_value = maxi(1, max_mp)
	mp_bar.value = mp
	exp_bar.max_value = maxi(1, exp_need)
	exp_bar.value = experience_value
	gold_label.text = "HP %d/%d   MP %d/%d   아데나 %d" % [hp, max_hp, mp, max_mp, gold]

func set_map_name(value: String) -> void:
	map_label.text = value

func set_auto(enabled: bool) -> void:
	auto_button.text = "AUTO ON" if enabled else "AUTO"

func show_target(monster_name: String, hp: int, max_hp: int) -> void:
	target_panel.visible = true
	target_label.text = monster_name
	target_hp.max_value = maxi(1, max_hp)
	target_hp.value = hp

func clear_target() -> void:
	target_panel.visible = false

func show_enhancement_result(result_type: String, item_name: String, from_level: int, to_level: int) -> void:
	var overlay: Label = Label.new()
	overlay.z_index = 400
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_theme_font_size_override("font_size", 34)
	overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	overlay.add_theme_constant_override("outline_size", 8)
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.offset_left = -360.0
	overlay.offset_top = -70.0
	overlay.offset_right = 360.0
	overlay.offset_bottom = 70.0
	match result_type:
		"success":
			overlay.text = "강화 성공!\n+%d %s" % [to_level, item_name]
			overlay.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35, 1.0))
		"destroy":
			overlay.text = "강화 실패\n%s 소실" % item_name
			overlay.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18, 1.0))
		"decrease":
			overlay.text = "강화 하락\n+%d → +%d" % [from_level, to_level]
			overlay.add_theme_color_override("font_color", Color(0.75, 0.60, 1.0, 1.0))
		_:
			overlay.text = "강화 실패\n수치 유지"
			overlay.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 1.0))
	$Root.add_child(overlay)
	overlay.scale = Vector2(0.82, 0.82)
	overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.12)
	tween.tween_property(overlay, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.75)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.30)
	tween.tween_callback(overlay.queue_free)

func show_message(text: String) -> void:
	message_label.text = text
	message_time = 2.6

func append_log(text: String) -> void:
	log_label.append_text(text + "\n")
	if log_label.get_line_count() > 8:
		log_label.clear()
		log_label.append_text(text + "\n")

func _hide_aux_panels() -> void:
	inventory_panel.visible = false
	map_panel.visible = false
	menu_panel.visible = false
	if catalog_panel != null:
		catalog_panel.visible = false
	if character_panel != null:
		character_panel.visible = false
	if utility_panel != null:
		utility_panel.visible = false

func toggle_inventory() -> void:
	var target: bool = not inventory_panel.visible
	_hide_aux_panels()
	inventory_panel.visible = target

func toggle_menu() -> void:
	var target: bool = not menu_panel.visible
	_hide_aux_panels()
	menu_panel.visible = target

func toggle_map() -> void:
	var target: bool = not map_panel.visible
	_hide_aux_panels()
	map_panel.visible = target

func refresh_inventory(inventory: Dictionary) -> void:
	_clear_children(inventory_list)
	var names: Array = inventory.keys()
	names.sort()
	var images: Dictionary = item_image_index.get("아이템", {}) as Dictionary
	for item_value: Variant in names:
		var item_name: String = str(item_value)
		var amount: int = int(inventory.get(item_name, 0))
		if amount <= 0:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 46)
		row.add_theme_constant_override("separation", 6)

		var use_button: Button = Button.new()
		use_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		use_button.text = "%s   x%d" % [item_name, amount]
		use_button.tooltip_text = "빠르게 두 번 누르면 사용 / 강화"
		use_button.add_theme_font_size_override("font_size", 17)
		use_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var path: String = str(images.get(item_name, ""))
		if path != "" and ResourceLoader.exists(path):
			use_button.icon = load(path) as Texture2D
			use_button.expand_icon = false
			use_button.icon_max_width = 36
			use_button.add_theme_constant_override("icon_max_width", 36)
		use_button.pressed.connect(_on_inventory_item_tapped.bind(item_name))
		row.add_child(use_button)

		var quick_button: Button = Button.new()
		quick_button.text = "Q등록"
		quick_button.custom_minimum_size = Vector2(72, 42)
		quick_button.tooltip_text = "소모품을 퀵슬롯에 등록"
		quick_button.pressed.connect(_open_quickslot_picker.bind("item", item_name, item_name))
		row.add_child(quick_button)
		inventory_list.add_child(row)

func _on_inventory_item_tapped(item_name: String) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if last_inventory_tap_item == item_name and now_ms - last_inventory_tap_ms <= 450:
		last_inventory_tap_item = ""
		last_inventory_tap_ms = 0
		inventory_item_activated.emit(item_name)
		return
	last_inventory_tap_item = item_name
	last_inventory_tap_ms = now_ms

func refresh_maps(maps: Array) -> void:
	_clear_children(map_list)
	for map_value: Variant in maps:
		if not (map_value is Dictionary):
			continue
		var map_data: Dictionary = map_value as Dictionary
		var map_id: String = str(map_data.get("id", ""))
		var map_name: String = str(map_data.get("name", map_id))
		var button: Button = Button.new()
		button.text = map_name
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_emit_map_selected.bind(map_id))
		map_list.add_child(button)

func open_catalog(category: String) -> void:
	_hide_aux_panels()
	catalog_category = category
	catalog_title.text = "%s 도감" % category
	catalog_search.text = ""
	if category == "아이템":
		item_slot_filter = "weapon"
		item_grade_filter = "전체"
		item_filter_panel.visible = true
		_refresh_item_filter_controls()
	else:
		item_filter_panel.visible = false
	catalog_panel.visible = true
	_refresh_catalog_list("")

func _build_catalog_panel() -> void:
	catalog_panel = PanelContainer.new()
	catalog_panel.name = "CatalogPanel"
	catalog_panel.set_anchors_preset(Control.PRESET_CENTER)
	catalog_panel.offset_left = -485.0
	catalog_panel.offset_top = -300.0
	catalog_panel.offset_right = 485.0
	catalog_panel.offset_bottom = 300.0
	catalog_panel.z_index = 120
	catalog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	$Root.add_child(catalog_panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	catalog_panel.add_child(root)
	catalog_title = Label.new()
	catalog_title.text = "도감"
	catalog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catalog_title.add_theme_font_size_override("font_size", 24)
	root.add_child(catalog_title)
	var top: HBoxContainer = HBoxContainer.new()
	catalog_search = LineEdit.new()
	catalog_search.placeholder_text = "이름 / 등급 검색"
	catalog_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_search.text_changed.connect(_refresh_catalog_list)
	top.add_child(catalog_search)
	catalog_count = Label.new()
	catalog_count.custom_minimum_size = Vector2(170, 0)
	top.add_child(catalog_count)
	root.add_child(top)

	item_filter_panel = VBoxContainer.new()
	item_filter_panel.add_theme_constant_override("separation", 6)
	root.add_child(item_filter_panel)

	var slot_row: HBoxContainer = HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 6)
	item_filter_panel.add_child(slot_row)
	for slot_data: Array in ITEM_SLOT_FILTERS:
		var slot_id: String = str(slot_data[0])
		var slot_label: String = str(slot_data[1])
		var slot_button: Button = Button.new()
		slot_button.text = slot_label
		slot_button.custom_minimum_size = Vector2(150, 40)
		slot_button.toggle_mode = true
		slot_button.pressed.connect(_set_item_slot_filter.bind(slot_id))
		slot_row.add_child(slot_button)
		item_slot_buttons[slot_id] = slot_button

	var grade_row: HBoxContainer = HBoxContainer.new()
	grade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grade_row.add_theme_constant_override("separation", 4)
	item_filter_panel.add_child(grade_row)
	for grade_name: String in ITEM_GRADE_ORDER:
		var grade_button: Button = Button.new()
		grade_button.text = grade_name
		grade_button.custom_minimum_size = Vector2(90, 36)
		grade_button.toggle_mode = true
		grade_button.pressed.connect(_set_item_grade_filter.bind(grade_name))
		grade_row.add_child(grade_button)
		item_grade_buttons[grade_name] = grade_button

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 465)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	catalog_list = ItemList.new()
	catalog_list.custom_minimum_size = Vector2(430, 410)
	catalog_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_list.select_mode = ItemList.SELECT_SINGLE
	catalog_list.allow_reselect = true
	catalog_list.mouse_filter = Control.MOUSE_FILTER_STOP
	catalog_list.item_selected.connect(_on_catalog_item_selected)
	catalog_list.item_clicked.connect(_on_catalog_item_clicked)
	catalog_list.gui_input.connect(_on_catalog_list_gui_input)
	left.add_child(catalog_list)
	var pager: HBoxContainer = HBoxContainer.new()
	pager.custom_minimum_size = Vector2(430, 46)
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 6)
	left.add_child(pager)
	catalog_first_button = Button.new()
	catalog_first_button.text = "처음"
	catalog_first_button.custom_minimum_size = Vector2(66, 40)
	catalog_first_button.pressed.connect(_catalog_first_page)
	pager.add_child(catalog_first_button)
	catalog_prev_button = Button.new()
	catalog_prev_button.text = "◀"
	catalog_prev_button.custom_minimum_size = Vector2(52, 40)
	catalog_prev_button.pressed.connect(_catalog_prev_page)
	pager.add_child(catalog_prev_button)
	catalog_page_label = Label.new()
	catalog_page_label.text = "1 / 1"
	catalog_page_label.custom_minimum_size = Vector2(100, 40)
	catalog_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catalog_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catalog_page_label.add_theme_font_size_override("font_size", 17)
	pager.add_child(catalog_page_label)
	catalog_next_button = Button.new()
	catalog_next_button.text = "▶"
	catalog_next_button.custom_minimum_size = Vector2(52, 40)
	catalog_next_button.pressed.connect(_catalog_next_page)
	pager.add_child(catalog_next_button)
	catalog_last_button = Button.new()
	catalog_last_button.text = "끝"
	catalog_last_button.custom_minimum_size = Vector2(66, 40)
	catalog_last_button.pressed.connect(_catalog_last_page)
	pager.add_child(catalog_last_button)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(500, 465)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	catalog_preview = TextureRect.new()
	catalog_preview.custom_minimum_size = Vector2(0, 230)
	catalog_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	catalog_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(catalog_preview)
	catalog_detail = RichTextLabel.new()
	catalog_detail.bbcode_enabled = true
	catalog_detail.fit_content = false
	catalog_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_detail.custom_minimum_size = Vector2(0, 180)
	right.add_child(catalog_detail)
	catalog_equip_button = Button.new()
	catalog_equip_button.text = "장착"
	catalog_equip_button.custom_minimum_size = Vector2(0, 46)
	catalog_equip_button.pressed.connect(_equip_selected_catalog)
	right.add_child(catalog_equip_button)
	var close: Button = Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 42)
	close.pressed.connect(func() -> void: catalog_panel.visible = false)
	right.add_child(close)

func _refresh_catalog_list(filter_text: String) -> void:
	catalog_filtered_results.clear()
	selected_catalog_record = {}
	catalog_preview.texture = null
	catalog_detail.text = ""
	var source: Array = catalog_data.get(catalog_category, []) as Array
	var query: String = filter_text.strip_edges().to_lower()
	for value: Variant in source:
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		if catalog_category == "아이템":
			if _item_filter_group(record) != item_slot_filter:
				continue
			if item_grade_filter != "전체" and str(record.get("grade", "")) != item_grade_filter:
				continue
		var search_text: String = (str(record.get("name", "")) + " " + str(record.get("grade", "")) + " " + str(record.get("type", ""))).to_lower()
		if query != "" and search_text.find(query) < 0:
			continue
		catalog_filtered_results.append(record)
	catalog_page = 0
	_apply_catalog_page()

func _set_item_slot_filter(slot_id: String) -> void:
	if item_slot_filter == slot_id:
		_refresh_item_filter_controls()
		return
	item_slot_filter = slot_id
	item_grade_filter = "전체"
	_refresh_item_filter_controls()
	_refresh_catalog_list(catalog_search.text)

func _set_item_grade_filter(grade_name: String) -> void:
	item_grade_filter = grade_name
	_refresh_item_filter_controls()
	_refresh_catalog_list(catalog_search.text)

func _refresh_item_filter_controls() -> void:
	for slot_key: Variant in item_slot_buttons.keys():
		var slot_button_value: Variant = item_slot_buttons.get(slot_key)
		if slot_button_value is Button:
			var slot_button: Button = slot_button_value as Button
			slot_button.button_pressed = str(slot_key) == item_slot_filter

	var available_grades: Dictionary = {}
	var source: Array = catalog_data.get("아이템", []) as Array
	for value: Variant in source:
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		if _item_filter_group(record) != item_slot_filter:
			continue
		available_grades[str(record.get("grade", ""))] = true

	if item_grade_filter != "전체" and not available_grades.has(item_grade_filter):
		item_grade_filter = "전체"
	for grade_key: Variant in item_grade_buttons.keys():
		var grade_button_value: Variant = item_grade_buttons.get(grade_key)
		if grade_button_value is Button:
			var grade_button: Button = grade_button_value as Button
			var grade_name: String = str(grade_key)
			grade_button.visible = grade_name == "전체" or available_grades.has(grade_name)
			grade_button.button_pressed = grade_name == item_grade_filter

func _catalog_page_count() -> int:
	if catalog_filtered_results.is_empty():
		return 1
	return int(ceil(float(catalog_filtered_results.size()) / float(catalog_page_size)))

func _apply_catalog_page() -> void:
	catalog_list.clear()
	catalog_results.clear()
	selected_catalog_record = {}
	catalog_preview.texture = null
	catalog_detail.text = ""
	var page_count: int = _catalog_page_count()
	catalog_page = clampi(catalog_page, 0, page_count - 1)
	var start_index: int = catalog_page * catalog_page_size
	var end_index: int = mini(start_index + catalog_page_size, catalog_filtered_results.size())
	for source_index: int in range(start_index, end_index):
		var record: Dictionary = catalog_filtered_results[source_index] as Dictionary
		catalog_results.append(record)
		catalog_list.add_item("[%s] %s" % [str(record.get("grade", "")), str(record.get("name", ""))])
	var visible_start: int = 0 if catalog_filtered_results.is_empty() else start_index + 1
	var visible_end: int = 0 if catalog_filtered_results.is_empty() else end_index
	var filter_label: String = ""
	if catalog_category == "아이템":
		var slot_label: String = _item_slot_label(item_slot_filter)
		filter_label = "%s · %s · " % [slot_label, item_grade_filter]
	catalog_count.text = "%s%d개 · %d-%d" % [filter_label, catalog_filtered_results.size(), visible_start, visible_end]
	catalog_page_label.text = "%d / %d" % [catalog_page + 1, page_count]
	catalog_first_button.disabled = catalog_page <= 0
	catalog_prev_button.disabled = catalog_page <= 0
	catalog_next_button.disabled = catalog_page >= page_count - 1
	catalog_last_button.disabled = catalog_page >= page_count - 1
	catalog_equip_button.visible = true
	catalog_equip_button.text = "획득 / 장착" if catalog_category == "아이템" else "장착"
	catalog_equip_button.disabled = catalog_results.is_empty()
	if catalog_results.size() > 0:
		catalog_list.select(0)
		_on_catalog_item_selected(0)

func _catalog_first_page() -> void:
	if catalog_page == 0:
		return
	catalog_page = 0
	_apply_catalog_page()

func _catalog_prev_page() -> void:
	if catalog_page <= 0:
		return
	catalog_page -= 1
	_apply_catalog_page()

func _catalog_next_page() -> void:
	var page_count: int = _catalog_page_count()
	if catalog_page >= page_count - 1:
		return
	catalog_page += 1
	_apply_catalog_page()

func _catalog_last_page() -> void:
	var last_page: int = _catalog_page_count() - 1
	if catalog_page == last_page:
		return
	catalog_page = last_page
	_apply_catalog_page()

func _on_catalog_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_select_catalog_index(index)

func _on_catalog_list_gui_input(event: InputEvent) -> void:
	# Android does not always emit ItemList.item_selected when mouse emulation is disabled.
	# Handle native touch explicitly so every visible row can be selected.
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			var touch_index: int = catalog_list.get_item_at_position(touch_event.position, true)
			if touch_index >= 0:
				_select_catalog_index(touch_index)
				catalog_list.accept_event()
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_index: int = catalog_list.get_item_at_position(mouse_event.position, true)
			if mouse_index >= 0:
				_select_catalog_index(mouse_index)

func _select_catalog_index(index: int) -> void:
	if index < 0 or index >= catalog_results.size():
		return
	catalog_list.select(index)
	catalog_list.ensure_current_is_visible()
	_on_catalog_item_selected(index)

func _on_catalog_item_selected(index: int) -> void:
	if index < 0 or index >= catalog_results.size():
		return
	selected_catalog_record = catalog_results[index] as Dictionary
	var path: String = str(selected_catalog_record.get("image_path", ""))
	catalog_preview.texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	var title: String = str(selected_catalog_record.get("name", ""))
	var grade: String = str(selected_catalog_record.get("grade", ""))
	var type_name: String = str(selected_catalog_record.get("type", ""))
	var options: Array = selected_catalog_record.get("sourceOptions", []) as Array
	var option_text: String = ""
	for value: Variant in options.slice(0, 16):
		option_text += "• %s\n" % str(value)
	catalog_detail.text = "[font_size=22][b]%s[/b][/font_size]\n등급: %s   종류: %s\nID: %s\n\n%s" % [title, grade, type_name, str(selected_catalog_record.get("sourceId", "")), option_text]

func _equip_selected_catalog() -> void:
	if selected_catalog_record.is_empty():
		return
	catalog_equip_requested.emit(catalog_category, selected_catalog_record.duplicate(true))
	catalog_equip_button.text = "적용 완료 ✓"
	var timer: SceneTreeTimer = get_tree().create_timer(0.7)
	timer.timeout.connect(_restore_catalog_action_text)

func _restore_catalog_action_text() -> void:
	if catalog_equip_button == null:
		return
	catalog_equip_button.text = "획득 / 장착" if catalog_category == "아이템" else "장착"

func _build_character_panel() -> void:
	character_panel = PanelContainer.new()
	character_panel.name = "CharacterPanel"
	character_panel.set_anchors_preset(Control.PRESET_CENTER)
	character_panel.offset_left = -430.0
	character_panel.offset_top = -300.0
	character_panel.offset_right = 430.0
	character_panel.offset_bottom = 300.0
	character_panel.z_index = 110
	character_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	$Root.add_child(character_panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	character_panel.add_child(root)

	var title: Label = Label.new()
	title.text = "캐릭터 / 스테이터스 / 장비"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(325, 0)
	left.add_theme_constant_override("separation", 7)
	body.add_child(left)

	character_preview = TextureRect.new()
	character_preview.custom_minimum_size = Vector2(315, 200)
	character_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(character_preview)

	var job_title: Label = Label.new()
	job_title.text = "신화 변신 기반 직업"
	job_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	job_title.add_theme_font_size_override("font_size", 16)
	left.add_child(job_title)

	var class_scroll: ScrollContainer = ScrollContainer.new()
	class_scroll.custom_minimum_size = Vector2(315, 166)
	class_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(class_scroll)
	var class_grid: GridContainer = GridContainer.new()
	class_grid.name = "JobClassGrid"
	class_grid.columns = 3
	class_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_grid.add_theme_constant_override("h_separation", 4)
	class_grid.add_theme_constant_override("v_separation", 4)
	class_scroll.add_child(class_grid)

	var stat_title: Label = Label.new()
	stat_title.text = "스탯 포인트 투자"
	stat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_title.add_theme_font_size_override("font_size", 17)
	left.add_child(stat_title)

	var stat_grid: GridContainer = GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 6)
	stat_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(stat_grid)
	for stat_name: String in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		var stat_button: Button = Button.new()
		stat_button.text = stat_name + " +"
		stat_button.custom_minimum_size = Vector2(152, 40)
		stat_button.pressed.connect(_emit_stat_increase.bind(stat_name))
		stat_grid.add_child(stat_button)
		stat_buttons[stat_name] = stat_button

	character_info = RichTextLabel.new()
	character_info.bbcode_enabled = true
	character_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(character_info)

	var close: Button = Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func() -> void: character_panel.visible = false)
	root.add_child(close)

func open_character() -> void:
	_hide_aux_panels()
	character_panel.visible = true
	_refresh_character_panel()

func _build_utility_panel() -> void:
	utility_panel = PanelContainer.new()
	utility_panel.name = "UtilityPanel"
	utility_panel.set_anchors_preset(Control.PRESET_CENTER)
	utility_panel.offset_left = -330.0
	utility_panel.offset_top = -285.0
	utility_panel.offset_right = 330.0
	utility_panel.offset_bottom = 285.0
	utility_panel.z_index = 135
	utility_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	$Root.add_child(utility_panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	utility_panel.add_child(root)

	utility_title = Label.new()
	utility_title.text = "기능"
	utility_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	utility_title.add_theme_font_size_override("font_size", 24)
	root.add_child(utility_title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 460)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	utility_body = VBoxContainer.new()
	utility_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utility_body.add_theme_constant_override("separation", 8)
	scroll.add_child(utility_body)

	var close: Button = Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func() -> void: utility_panel.visible = false)
	root.add_child(close)

func _open_utility_panel(title_text: String) -> void:
	_hide_aux_panels()
	utility_title.text = title_text
	_clear_children(utility_body)
	utility_panel.visible = true

func _utility_add_text(text_value: String) -> void:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(590, 0)
	label.add_theme_font_size_override("normal_font_size", 17)
	label.text = text_value
	utility_body.add_child(label)

func _utility_add_action(label_text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(action)
	utility_body.add_child(button)

func open_enhancement(scroll_name: String, candidates: Array) -> void:
	enhancement_scroll_name = scroll_name
	enhancement_candidates = candidates.duplicate(true)
	enhancement_selected_index = 0 if enhancement_candidates.size() > 0 else -1
	_open_utility_panel("장비 강화")
	_render_enhancement_panel()

func _render_enhancement_panel() -> void:
	_clear_children(utility_body)
	_utility_add_text("[font_size=20][b]%s[/b][/font_size]\n강화할 장비를 선택하세요. 강화 주문서는 시도 시 1장 소모됩니다." % enhancement_scroll_name)
	if enhancement_candidates.is_empty():
		_utility_add_text("[color=#d98b72]강화 가능한 장비가 없습니다.[/color]\n인벤토리 또는 장착 장비를 확인하세요.")
		return

	for index: int in range(enhancement_candidates.size()):
		var data: Dictionary = enhancement_candidates[index] as Dictionary
		var selected_mark: String = "▶ " if index == enhancement_selected_index else ""
		var equipped_mark: String = " [장착]" if bool(data.get("equipped", false)) else ""
		var button: Button = Button.new()
		button.text = "%s%s%s  +%d" % [selected_mark, str(data.get("name", "")), equipped_mark, int(data.get("level", 0))]
		button.custom_minimum_size = Vector2(0, 42)
		button.pressed.connect(_select_enhancement_candidate.bind(index))
		utility_body.add_child(button)

	if enhancement_selected_index < 0 or enhancement_selected_index >= enhancement_candidates.size():
		return
	var selected: Dictionary = enhancement_candidates[enhancement_selected_index] as Dictionary
	var safe_text: String = "안전강화 +%d" % int(selected.get("safe_level", 0))
	if int(selected.get("safe_level", 0)) <= 0:
		safe_text = "안전강화 없음"
	var decrease_chance: float = float(selected.get("decrease_chance", 0.0))
	var gain_text: String = str(selected.get("gain_text", "+1"))
	var detail: String = "[b]%s +%d[/b]\n%s\n성공 [color=#7edb83]%.1f%%[/color]   유지 %.1f%%   하락 %.1f%%   소실 [color=#e86f61]%.1f%%[/color]\n성공 강화폭: [color=#9ad7ff]%s[/color]\n성공 시: [color=#f2c66d]%s[/color]" % [
		str(selected.get("name", "")),
		int(selected.get("level", 0)),
		safe_text,
		float(selected.get("success_chance", 0.0)),
		float(selected.get("no_change_chance", 0.0)),
		decrease_chance,
		float(selected.get("destroy_chance", 0.0)),
		gain_text,
		str(selected.get("bonus_text", "능력치 상승"))
	]
	_utility_add_text(detail)
	var enhance_button: Button = Button.new()
	enhance_button.text = "강화 시도"
	enhance_button.custom_minimum_size = Vector2(0, 52)
	enhance_button.pressed.connect(_emit_enhancement_requested.bind(str(selected.get("name", ""))))
	utility_body.add_child(enhance_button)

func _select_enhancement_candidate(index: int) -> void:
	if index < 0 or index >= enhancement_candidates.size():
		return
	enhancement_selected_index = index
	_render_enhancement_panel()

func _emit_enhancement_requested(target_name: String) -> void:
	enhancement_requested.emit(enhancement_scroll_name, target_name)

func open_shop() -> void:
	_open_utility_panel("상점")
	_utility_add_text("[font_size=20][b]잡화 상점[/b][/font_size]\n보유 아데나: [color=#f2c66d]%d[/color]\n필요한 소모품을 구매할 수 있습니다." % int(character_state.get("gold", 0)))
	for shop_data: Array in [
		["HP 물약", 50],
		["강력 HP 물약", 180],
		["축복받은 HP 물약", 450],
		["초록 잎", 100],
		["무기 마법 주문서 (각인)", 25000],
		["갑옷 마법 주문서 (각인)", 18000],
		["장신구 마법 주문서 (각인)", 35000],
		["축복받은 무기 마법 주문서 (각인)", 120000],
		["축복받은 갑옷 마법 주문서 (각인)", 90000],
		["장인의 무기 마법 주문서 (각인)", 350000],
		["장인의 갑옷 마법 주문서 (각인)", 300000],
		["오림의 장신구 마법 주문서 (각인)", 150000],
		["축복받은 오림의 장신구 마법 주문서 (각인)", 450000]
	]:
		var item_name: String = str(shop_data[0])
		var price: int = int(shop_data[1])
		_utility_add_action("%s  ·  %d 아데나  [구매]" % [item_name, price], _emit_shop_buy.bind(item_name, price))

func _emit_shop_buy(item_name: String, price: int) -> void:
	shop_buy_requested.emit(item_name, price)

func open_skills() -> void:
	_open_utility_panel("스킬")
	var current_job: String = str(character_state.get("job_class", "기사"))
	_utility_add_text("[font_size=22][b]%s 스킬[/b][/font_size]\n공용 스킬 + %s 전용 스킬만 표시합니다." % [current_job, current_job])
	var visible_skills: Array = []
	for value: Variant in job_skills:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		var skill_class: String = str(skill.get("class", "공용"))
		if skill_class == "공용" or skill_class == current_job:
			visible_skills.append(skill)
	visible_skills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var grade_order: Dictionary = {"일반":0, "고급":1, "희귀":2, "영웅":3, "전설":4, "신화":5}
		var ag: int = int(grade_order.get(str(a.get("grade", "일반")), 0))
		var bg: int = int(grade_order.get(str(b.get("grade", "일반")), 0))
		if ag == bg:
			return str(a.get("name", "")) < str(b.get("name", ""))
		return ag < bg
	)
	for value: Variant in visible_skills:
		var skill: Dictionary = value as Dictionary
		var skill_name: String = str(skill.get("name", "스킬"))
		var grade: String = str(skill.get("grade", "일반"))
		var type_text: String = str(skill.get("type", ""))
		var mp_cost: int = int(skill.get("mp", 0))
		var desc: String = str(skill.get("desc", ""))

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var button: Button = Button.new()
		button.text = "[%s] %s · %s · MP %d\n%s" % [grade, skill_name, type_text, mp_cost, desc]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_emit_job_skill.bind(skill_name))
		row.add_child(button)

		var quick_button: Button = Button.new()
		quick_button.text = "Q등록"
		quick_button.custom_minimum_size = Vector2(72, 60)
		quick_button.tooltip_text = "스킬을 퀵슬롯에 등록"
		quick_button.pressed.connect(_open_quickslot_picker.bind("skill", skill_name, skill_name))
		row.add_child(quick_button)
		utility_body.add_child(row)

func open_quest_info() -> void:
	_open_utility_panel("퀘스트")
	var current: int = int(character_state.get("quest_kills", 0))
	var goal: int = maxi(1, int(character_state.get("quest_goal", 9)))
	_utility_add_text("[font_size=20][b]메인 퀘스트[/b][/font_size]\n몬스터의 세력 다툼\n\n몬스터 처치: [color=#f2c66d]%d / %d[/color]\n\n사냥으로 목표 수량을 채우면 진행도가 갱신됩니다." % [current, goal])

func open_macro_info() -> void:
	_open_utility_panel("매크로 / 자동사냥")
	_utility_add_text("현재 로컬 자동사냥 기능을 제어합니다.\nAUTO를 켜면 도달 가능한 몬스터를 찾아 이동하고 공격합니다.")
	_utility_add_action("AUTO 전환", func() -> void: auto_pressed.emit())

func open_chat_info() -> void:
	_open_utility_panel("채팅 / 기록")
	_utility_add_text("이 프로젝트는 서버 없는 로컬 싱글플레이 게임입니다.\n외부 채팅 서버 대신 화면 전투 로그와 시스템 메시지를 사용합니다.")

func open_settings_info() -> void:
	_open_utility_panel("설정 / 관리")
	_utility_add_text("게임 데이터 관리와 주요 화면을 바로 열 수 있습니다.")
	_utility_add_action("게임 저장", func() -> void: save_pressed.emit())
	_utility_add_action("게임 불러오기", func() -> void: load_pressed.emit())
	_utility_add_action("월드맵 열기", func() -> void: map_pressed.emit())
	_utility_add_action("캐릭터 / 스탯 열기", open_character)

func _refresh_character_panel() -> void:
	var available_points: int = maxi(0, int(character_state.get("stat_points", 0)))
	for stat_key: Variant in stat_buttons.keys():
		var stat_button_value: Variant = stat_buttons.get(stat_key)
		if stat_button_value is Button:
			var stat_button: Button = stat_button_value as Button
			stat_button.disabled = available_points <= 0
			stat_button.tooltip_text = "남은 스탯 포인트 %d" % available_points

	var current_job: String = str(character_state.get("job_class", "기사"))
	_refresh_job_class_selection()
	var profile: Dictionary = _job_profile(current_job)
	var portrait_path: String = str(profile.get("image_path", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		character_preview.texture = load(portrait_path) as Texture2D
	else:
		var class_index: int = clampi(int(character_state.get("class_index", 0)), 0, 3)
		var fallback_path: String = CLASS_SHEETS[class_index]
		if ResourceLoader.exists(fallback_path):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = load(fallback_path) as Texture2D
			atlas.region = Rect2(0, 0, 148, 116)
			character_preview.texture = atlas

	var equipped: Dictionary = character_state.get("equipped", {}) as Dictionary
	var equipped_items: Dictionary = character_state.get("equipped_items", {}) as Dictionary
	var transform_name: String = _equipped_name(equipped.get("변신", {}))
	var doll_name: String = _equipped_name(equipped.get("마법인형", {}))
	var relic_name: String = _equipped_name(equipped.get("성물", {}))
	var weapon_name: String = _equipped_detail(equipped_items.get("weapon", {}))
	var armor_name: String = _equipped_detail(equipped_items.get("armor", {}))
	var accessory_name: String = _equipped_detail(equipped_items.get("accessory", {}))
	var core_stats: String = "STR %d   DEX %d   CON %d\nINT %d   WIS %d   CHA %d" % [
		int(character_state.get("str", 0)), int(character_state.get("dex", 0)), int(character_state.get("con", 0)),
		int(character_state.get("int", 0)), int(character_state.get("wis", 0)), int(character_state.get("cha", 0))
	]
	var combat_stats: String = "근거리 대미지 %d   명중 %d   치명타 %d%%\n원거리 대미지 %d   명중 %d   치명타 %d%%\n마법 대미지 %d   명중 %d   치명타 %d%%\nAC %d   DG %d   ER %d   MR %d\n대미지 리덕션 %d   치명타 저항 %d%%\n스턴 적중 %d   스턴 내성 %d\n침묵 적중 %d   침묵 내성 %d\n홀드 적중 %d   홀드 내성 %d\n공포 적중 %d   공포 내성 %d\n독 적중 %d   독 내성 %d\n출혈 적중 %d   출혈 내성 %d" % [
		int(character_state.get("melee_damage", 0)), int(character_state.get("melee_accuracy", 0)), int(character_state.get("melee_critical", 0)),
		int(character_state.get("ranged_damage", 0)), int(character_state.get("ranged_accuracy", 0)), int(character_state.get("ranged_critical", 0)),
		int(character_state.get("magic_damage", 0)), int(character_state.get("magic_accuracy", 0)), int(character_state.get("magic_critical", 0)),
		int(character_state.get("ac", 0)), int(character_state.get("dg", 0)),
		int(character_state.get("er", 0)), int(character_state.get("mr", 0)),
		int(character_state.get("damage_reduction", 0)), int(character_state.get("critical_resistance", 0)),
		int(character_state.get("stun_accuracy", 0)), int(character_state.get("stun_resistance", 0)),
		int(character_state.get("silence_accuracy", 0)), int(character_state.get("silence_resistance", 0)),
		int(character_state.get("hold_accuracy", 0)), int(character_state.get("hold_resistance", 0)),
		int(character_state.get("fear_accuracy", 0)), int(character_state.get("fear_resistance", 0)),
		int(character_state.get("poison_accuracy", 0)), int(character_state.get("poison_resistance", 0)),
		int(character_state.get("bleed_accuracy", 0)), int(character_state.get("bleed_resistance", 0))
	]
	var profile_text: String = "역할 %s · 주무기 %s · 주스탯 %s\n대표 신화 변신: %s" % [
		str(profile.get("role", "")),
		str(profile.get("weapon", "")),
		str(profile.get("primary_stat", "")),
		str(profile.get("transform_name", ""))
	]
	character_info.text = "[font_size=22][b]%s[/b][/font_size]\n%s\nLv.%d   [color=#f2c66d]남은 스탯 %d[/color]\n\nHP %d / %d   MP %d / %d\n\n[b]기본 스테이터스[/b]\n%s\n\n[b]전투 스테이터스[/b]\n%s\n\n[b]현재 장착[/b]\n변신: %s\n마법인형: %s\n성물: %s\n무기: %s\n방어구: %s\n장신구: %s" % [
		current_job, profile_text, int(character_state.get("level", 1)), int(character_state.get("stat_points", 0)),
		int(character_state.get("hp", 0)), int(character_state.get("max_hp", 0)),
		int(character_state.get("mp", 0)), int(character_state.get("max_mp", 0)),
		core_stats, combat_stats, transform_name, doll_name, relic_name, weapon_name, armor_name, accessory_name
	]

func _equipped_name(value: Variant) -> String:
	if value is Dictionary:
		var record: Dictionary = value as Dictionary
		if not record.is_empty():
			return str(record.get("name", "없음"))
	return "없음"

func _equipped_detail(value: Variant) -> String:
	if not (value is Dictionary):
		return "없음"
	var record: Dictionary = value as Dictionary
	if record.is_empty():
		return "없음"
	var parts: PackedStringArray = PackedStringArray()
	var enhance_level: int = int(record.get("enhance_level", 0))
	var display_name: String = str(record.get("name", "장비"))
	if enhance_level > 0:
		display_name = "+%d %s" % [enhance_level, display_name]
	parts.append(display_name)
	var grade: String = str(record.get("grade", "")).strip_edges()
	if grade != "":
		parts.append(grade)
	var atk_value: int = int(record.get("atk", 0))
	var def_value: int = int(record.get("def", 0))
	var hit_value: int = int(record.get("hit", 0))
	var hp_value: int = int(record.get("hpFlat", 0))
	if atk_value != 0:
		parts.append("공격 %+d" % atk_value)
	if def_value != 0:
		parts.append("방어 %+d" % def_value)
	if hit_value != 0:
		parts.append("명중 %+d" % hit_value)
	if hp_value != 0:
		parts.append("HP %+d" % hp_value)
	return " · ".join(parts)

func _item_filter_group(record: Dictionary) -> String:
	var slot: String = str(record.get("slot", "")).strip_edges().to_lower()
	var item_type: String = str(record.get("type", "")).strip_edges()
	var item_name: String = str(record.get("name", "")).strip_edges()

	if slot == "weapon" or slot == "armor" or slot == "accessory":
		return slot
	if slot == "consumable":
		return "consumable"
	if slot == "material":
		if item_type == "이동주문서":
			return "consumable"
		if item_type in ["재료", "지배석", "마안", "성배"]:
			return "material"
		if item_type == "상자":
			return "other"
		# Future catalog imports sometimes normalize usable items as material.
		if item_name.find("물약") >= 0 or item_name.find("이동 주문서") >= 0 or item_name.find("순간이동 주문서") >= 0:
			return "consumable"
		return "material"
	if slot == "currency":
		return "other"

	# Fallbacks for future item sources that do not provide a normalized slot.
	if item_type == "소모품" or item_type == "이동주문서":
		return "consumable"
	if item_type in ["재료", "지배석", "마안", "성배"]:
		return "material"
	return "other"

func _item_slot_label(slot_id: String) -> String:
	for slot_data: Array in ITEM_SLOT_FILTERS:
		if str(slot_data[0]) == slot_id:
			return str(slot_data[1])
	return slot_id

func _emit_map_selected(map_id: String) -> void:
	map_selected.emit(map_id)

func _emit_class_selected(index: int) -> void:
	class_selected.emit(index)

func _emit_stat_increase(stat_name: String) -> void:
	stat_increase_requested.emit(stat_name)

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
