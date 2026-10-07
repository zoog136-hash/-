extends CanvasLayer
class_name TwilightHUD

signal move_vector_changed(value: Vector2)
signal attack_pressed
signal bleed_skill_pressed
signal combat_skill_pressed(skill_id: String)
signal auto_pressed
signal potion_pressed
signal inventory_pressed
signal menu_pressed
signal map_pressed
signal map_selected(map_id: String)
signal save_pressed
signal load_pressed
signal catalog_equip_requested(category: String, record: Dictionary)
signal class_selected(index: int)
signal stat_increase_requested(stat_name: String)

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
var character_panel: PanelContainer
var character_preview: TextureRect
var character_info: RichTextLabel
var stat_buttons: Dictionary = {}
var character_state: Dictionary = {}

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
	target_panel.visible = false
	inventory_panel.visible = false
	map_panel.visible = false
	menu_panel.visible = false
	catalog_panel.visible = false
	character_panel.visible = false
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
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 42)
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path: String = str(images.get(item_name, ""))
		if path != "" and ResourceLoader.exists(path):
			icon.texture = load(path) as Texture2D
		row.add_child(icon)
		var label: Label = Label.new()
		label.text = "%s   x%d" % [item_name, int(inventory.get(item_name, 0))]
		label.add_theme_font_size_override("font_size", 17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		inventory_list.add_child(row)

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
		button.pressed.connect(func() -> void: map_selected.emit(map_id))
		map_list.add_child(button)

func open_catalog(category: String) -> void:
	_hide_aux_panels()
	catalog_category = category
	catalog_title.text = "%s 도감" % category
	catalog_search.text = ""
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
		var search_text: String = (str(record.get("name", "")) + " " + str(record.get("grade", "")) + " " + str(record.get("type", ""))).to_lower()
		if query != "" and search_text.find(query) < 0:
			continue
		catalog_filtered_results.append(record)
	catalog_page = 0
	_apply_catalog_page()

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
	catalog_count.text = "%d개 · %d-%d" % [catalog_filtered_results.size(), visible_start, visible_end]
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

	var class_grid: GridContainer = GridContainer.new()
	class_grid.columns = 2
	left.add_child(class_grid)
	for index: int in range(4):
		var class_button: Button = Button.new()
		class_button.text = CLASS_NAMES[index]
		class_button.custom_minimum_size = Vector2(152, 42)
		class_button.pressed.connect(func() -> void: class_selected.emit(index))
		class_grid.add_child(class_button)

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
		stat_button.pressed.connect(func() -> void: stat_increase_requested.emit(stat_name))
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

func _refresh_character_panel() -> void:
	var available_points: int = maxi(0, int(character_state.get("stat_points", 0)))
	for stat_key: Variant in stat_buttons.keys():
		var stat_button_value: Variant = stat_buttons.get(stat_key)
		if stat_button_value is Button:
			var stat_button: Button = stat_button_value as Button
			stat_button.disabled = available_points <= 0
			stat_button.tooltip_text = "남은 스탯 포인트 %d" % available_points
	var class_index: int = clampi(int(character_state.get("class_index", 0)), 0, 3)
	var path: String = CLASS_SHEETS[class_index]
	if ResourceLoader.exists(path):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = load(path) as Texture2D
		atlas.region = Rect2(0, 0, 148, 116)
		character_preview.texture = atlas
	var equipped: Dictionary = character_state.get("equipped", {}) as Dictionary
	var equipped_items: Dictionary = character_state.get("equipped_items", {}) as Dictionary
	var transform_name: String = _equipped_name(equipped.get("변신", {}))
	var doll_name: String = _equipped_name(equipped.get("마법인형", {}))
	var relic_name: String = _equipped_name(equipped.get("성물", {}))
	var weapon_name: String = _equipped_name(equipped_items.get("weapon", {}))
	var armor_name: String = _equipped_name(equipped_items.get("armor", {}))
	var accessory_name: String = _equipped_name(equipped_items.get("accessory", {}))
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
	character_info.text = "[font_size=22][b]%s[/b][/font_size]\nLv.%d   [color=#f2c66d]남은 스탯 %d[/color]\n\nHP %d / %d   MP %d / %d\n\n[b]기본 스테이터스[/b]\n%s\n\n[b]전투 스테이터스[/b]\n%s\n\n[b]현재 장착[/b]\n변신: %s\n마법인형: %s\n성물: %s\n무기: %s\n방어구: %s\n장신구: %s" % [
		CLASS_NAMES[class_index], int(character_state.get("level", 1)), int(character_state.get("stat_points", 0)),
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

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()
