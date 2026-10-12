extends "res://scripts/hud_v20.gd"

# ISOLATED PLAYTEST BUILD ONLY: remove these debug signals before production.
signal playtest_catalog_grant_requested(item_name: String, amount: int)
signal playtest_catalog_variant_grant_requested(source_id: String, amount: int)
signal playtest_aden_grant_requested
signal quickslot_edit_requested(action: String, source_index: int, target: int)

signal shop_bulk_buy_requested(item_name: String, quantity: int)
signal reviewed_shop_buy_requested(vendor_id: String, item_name: String, quantity: int)
signal warehouse_transfer_requested(item_name: String, quantity: int, direction: String, instance_id: String)
signal npc_teleport_requested(map_id: String)
signal craft_requested(recipe_id: String, batch: int)
signal shop_sell_requested(item_name: String, quantity: int, instance_id: String)
signal npc_dialogue_action_requested(npc_id: String, node_id: String, action: String)

# UI-only adapter: existing HUD signals remain the sole write interface.
const Layout = preload("res://scripts/ui/reference_layout.gd")
const PointerTransfer = preload("res://scripts/ui/pointer_transfer.gd")
const NavigationMemory = preload("res://scripts/ui/navigation_memory.gd")
var navigation_memory = NavigationMemory.new()
var switching_workspace: bool = false
var combat_log_view: RichTextLabel
var detail_window: PanelContainer
var status_view: Control
var pointer_transfer: Node
var quick_page_buttons: Array[Button] = []

const UI = preload("res://scripts/ui/renewal_theme.gd")
const RenewalWindowScript = preload("res://scripts/ui/renewal_window.gd")
const Inventory = preload("res://scripts/ui/renewal_inventory.gd")
const CharacterUI = preload("res://scripts/ui/renewal_character.gd")
const SkillsUI = preload("res://scripts/ui/renewal_skills.gd")
const ClassSelectUI = preload("res://scripts/ui/renewal_class_select.gd")
const ShopUI = preload("res://scripts/ui/renewal_shop.gd")
const DialogueUI = preload("res://scripts/ui/renewal_dialogue.gd")
const WarehouseUI = preload("res://scripts/ui/renewal_warehouse.gd")
const TeleportUI = preload("res://scripts/ui/renewal_teleport.gd")
const CraftUI = preload("res://scripts/ui/renewal_crafting.gd")
const SellUI = preload("res://scripts/ui/renewal_sell.gd")
const ForgeUI = preload("res://scripts/ui/renewal_forge.gd")
const SettingsUI = preload("res://scripts/ui/renewal_settings.gd")
const RegionMapUI = preload("res://scripts/ui/renewal_map.gd")
const Ornament = preload("res://scripts/ui/renewal_ornament.gd")
var workspace: PanelContainer
var active_section: String = ""
var buff_row: HBoxContainer
var exp_readout: Label
var currency_readout: Label
var coordinates_readout: Label
var quickslot_cooldown_labels: Array[Label] = []
var quickslot_icons: Array[TextureRect] = []
var quickslot_captions: Array[Label] = []
var quickslot_auto_badges: Array[Label] = []
var refresh_clock: float = 0
var active_buffs_view: Dictionary = {}
var log_history: Array[String] = []
var map_records: Array = []
var catalog_grade_filter: String = "전체"
var rarity_filter: OptionButton
var collection_slot_filter: OptionButton
var collection_status: Label
var catalog_drag_icon: TextureRect
var catalog_drag_touch: int = -1
var catalog_drag_mouse: bool = false
var catalog_drag_index: int = -1
var catalog_drag_origin: Vector2 = Vector2.ZERO
var catalog_drag_position: Vector2 = Vector2.ZERO
var catalog_drag_ready: bool = false
var playtest_grant_button: Button
var playtest_aden_button: Button
var playtest_scroll_buttons: Array[Button] = []
var catalog_body_left: VBoxContainer
var catalog_body_actions: ScrollContainer
var catalog_view_tabs: HBoxContainer
var catalog_list_tab: Button
var catalog_details_tab: Button
var catalog_details_active: bool = false
var catalog_icon_generation: int = 0
var catalog_variant_counts: Dictionary = {}
var skills_view: VBoxContainer
var region_selection: ItemList
var class_picker_initial: bool = false
var class_picker_backdrop: ColorRect
var minimap_mounted: bool = false
var cooldown_shades: Array[ColorRect] = []
var catalog_test_tools: VBoxContainer
var companion_window: PanelContainer
var transaction_view: Control
var shop_view: Control
var catalog_view_state: Dictionary = {}
var pending_quickslot_binding: Dictionary = {}
var quickslot_picker_hint: Label
var catalog_test_toggle: Button
var catalog_clear_button: Button
var catalog_grade_column: VBoxContainer
var catalog_grade_buttons: Dictionary = {}

func _build_v20_status() -> void:
	super._build_v20_status()
	var panel: PanelContainer = v20_layer.get_node("StatusPanel")
	_place(panel,8,8,307,76)
	panel.add_theme_stylebox_override("panel",UI.box(Color(0,0,0,.2),Color(0,0,0,0),0))
	var content: Control = panel.get_child(0)
	content.custom_minimum_size = Vector2(299,68)
	(content.get_child(0) as Control).hide()
	_place(content.get_node("CharacterShortcut"),0,0,44,52)
	_place(v20_level_badge,2,14,43,48)
	v20_level_badge.add_theme_font_size_override("font_size",24)
	_place(v20_status_name,48,0,291,18)
	v20_status_name.add_theme_font_size_override("font_size",11)
	_place(hp_bar,48,20,291,35)
	_place(v20_hp_text,48,18,291,37)
	_place(mp_bar,48,39,291,49)
	_place(v20_mp_text,48,36,291,53)
	_place(v20_stat_text,48,51,291,68)
	v20_stat_text.add_theme_font_size_override("font_size",11)
	for child: Node in v20_layer.get_children():
		if child is Button and is_equal_approx(child.position.x,380.0):
			_place(child,318,8,365,62)
		elif child is Button and is_equal_approx(child.position.x,442.0):
			_place(child,373,8,420,62)
	_place(v20_potion_count,318,43,365,64)
	_place(v20_leaf_count,373,43,420,64)

func set_auto(enabled: bool) -> void:
	super.set_auto(enabled)
	if v20_auto_button != null:
		v20_auto_button.text = "AUTO\nON" if enabled else "AUTO"
		v20_auto_button.add_theme_stylebox_override("normal",_round_button_style(.88,42,Color("69c49b") if enabled else UI.BRONZE))

func _ready() -> void:
	super._ready()
	$Root.theme = UI.make_theme()
	catalog_drag_icon = TextureRect.new()
	catalog_drag_icon.name = "CatalogDragPreview"
	catalog_drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catalog_drag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	catalog_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	catalog_drag_icon.custom_minimum_size = Vector2(76, 76)
	catalog_drag_icon.size = Vector2(76, 76)
	catalog_drag_icon.modulate = Color(1,1,1,.86)
	catalog_drag_icon.z_index = 250
	$Root.add_child(catalog_drag_icon)
	catalog_drag_icon.hide()
	workspace = RenewalWindowScript.new()
	$Root.add_child(workspace)
	workspace.navigate.connect(_navigate)
	workspace.back_requested.connect(_go_back)
	workspace.closed.connect(_close_workspace)
	workspace.resized.connect(_fit_catalog_browser_layout)
	workspace.content.resized.connect(_fit_catalog_browser_layout)
	get_window().size_changed.connect(_fit_catalog_browser_layout)
	# Starting-character selection is a genuine modal on PC and Android.
	class_picker_backdrop = ColorRect.new()
	class_picker_backdrop.name = "ClassSelectionBackdrop"
	class_picker_backdrop.color = Color(0.0,0.0,0.0,0.78)
	class_picker_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	class_picker_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	class_picker_backdrop.z_index = 149
	$Root.add_child(class_picker_backdrop)
	class_picker_backdrop.hide()
	joystick.offset_left = 20
	joystick.offset_right = 180
	joystick.offset_top = -244
	joystick.offset_bottom = -84
	get_viewport().size_changed.connect(_fit_hud)
	_polish_hud_chrome()
	_fit_hud()
	SettingsUI.apply_saved(self)
	pointer_transfer = PointerTransfer.new()
	$Root.add_child(pointer_transfer)
	pointer_transfer.configure(self)

func _polish_hud_chrome() -> void:
	# The old canvas still owns all HP, MP, combat and touch signals.
	# Restrict the pass to StyleBoxes; never duplicate gameplay state.
	var status: PanelContainer = v20_layer.get_node_or_null("StatusPanel") as PanelContainer
	if status != null:
		status.add_theme_stylebox_override("panel",UI.box(Color(0,0,0,.22),Color(0,0,0,0),0))
	if v20_target_panel != null:
		v20_target_panel.add_theme_stylebox_override("panel",UI.chrome_panel(Color(.045,.024,.025,.88),Color("9d6751"),5))
	if v20_map_name != null:
		v20_map_name.add_theme_color_override("font_color",UI.GOLD)
		_place(v20_map_name.get_parent(),755,10,933,44)
		v20_map_name.add_theme_font_size_override("font_size",11)
		v20_map_name.clip_text = true

func _build_lineage_inventory_ui() -> void:
	lineage_inventory_ui = Inventory.new() as TwilightInventoryUI
	lineage_inventory_ui.name = "LineageInventoryUI"
	lineage_inventory_ui.set("controller",self)
	lineage_inventory_ui.item_activate_requested.connect(func(item_name: String) -> void: inventory_item_activated.emit(item_name))
	lineage_inventory_ui.quickslot_requested.connect(_register_inventory_quickslot)
	$Root.add_child(lineage_inventory_ui)
	lineage_inventory_ui.set_catalog_data(catalog_data,item_image_index)
	lineage_inventory_ui.set_character_state(character_state)

func _build_lineage_side_ui() -> void:
	lineage_side_ui=CharacterUI.new() as TwilightSideUI
	lineage_side_ui.name="LineageSideUI"
	lineage_side_ui.detailed_stats_requested.connect(open_detailed_status)
	lineage_side_ui.action_requested.connect(_on_lineage_side_action)
	lineage_side_ui.stat_increase_requested.connect(func(value: String) -> void: stat_increase_requested.emit(value))
	lineage_side_ui.connect("class_selection_requested",func() -> void: open_class_selection())
	lineage_side_ui.equipment_requested.connect(func(item: String) -> void:
		if not lineage_inventory_ui.is_visible_in_tree(): show_companion_bag()
		lineage_inventory_ui._select_item(item)
		lineage_inventory_ui.open_detail())
	$Root.add_child(lineage_side_ui)
	lineage_side_ui.set_character_state(character_state)

func set_character_state(value: Dictionary) -> void:
	super.set_character_state(value)
	if is_instance_valid(status_view): status_view.refresh(value)

func blocks_keyboard_input() -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return true
	if pointer_transfer != null and pointer_transfer.pointer != -2: return true
	for dialog: Node in $Root.get_children():
		if dialog.name == "TwilightConfirmation" and dialog.visible: return true
	return false

func _panel_style(alpha: float = .9, radius: int = 3, border: Color = UI.BRONZE) -> StyleBoxFlat:
	var s := UI.box(Color(.035,.045,.055,alpha),border,7)
	s.set_corner_radius_all(radius)
	return s

func _build_v20_buffs() -> void:
	buff_row = HBoxContainer.new()
	buff_row.name = "ActiveEffects"
	buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(buff_row,12,84,430,128)
	v20_layer.add_child(buff_row)

func _build_v20_top_menu() -> void:
	var panel := PanelContainer.new()
	panel.name = "MainShortcuts"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel,943,9,1268,78)
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	v20_layer.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",4)
	panel.add_child(row)
	for spec: Array in [["shop","상점","shop.png"],["inventory","가방","bag.png"],["skills","스킬","skill.png"],["map","지도","quest.png"],["menu","메뉴","menu.png"]]:
		var id := str(spec[0])
		var b := UI.button("",_navigate.bind(id),Vector2(59,53))
		b.name = "Shortcut_"+id
		b.tooltip_text = str(spec[1])
		b.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover",UI.slot_frame(UI.GOLD,true))
		b.add_theme_stylebox_override("pressed",UI.slot_frame(UI.GOLD,true))
		row.add_child(b)
		var artwork := TextureRect.new()
		artwork.texture = UI.icon(id)
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.position = Vector2(14,3)
		artwork.size = Vector2(28,28)
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(artwork)
		var label := UI.label(str(spec[1]),11,UI.TEXT)
		label.position = Vector2(0,34)
		label.size = Vector2(59,16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(label)

func _build_v20_right_controls() -> void:
	v20_self_button = UI.button("SELF",_toggle_self_mode,Vector2(68,44))
	v20_self_button.name = "SelfMode"
	v20_self_button.toggle_mode = true
	v20_self_button.tooltip_text = "SELF OFF: 퀵슬롯 버프 자동 재사용 · ON: 수동 사용"
	_place(v20_self_button,1078,449,1154,491)
	v20_layer.add_child(v20_self_button)
	var target := UI.button("대상",func() -> void: target_pressed.emit())
	target.name = "SelectTarget"
	target.icon = UI.icon("target")
	_place(target,1162,449,1268,491)
	v20_layer.add_child(target)
	v20_auto_button = UI.button("AUTO",func() -> void: auto_pressed.emit())
	v20_auto_button.name = "AutoHunt"
	_place(v20_auto_button,1062,532,1147,611)
	v20_auto_button.add_theme_stylebox_override("normal",_round_button_style(.92,40,UI.BRONZE))
	v20_auto_button.add_theme_stylebox_override("hover",_round_button_style(.98,40,UI.GOLD))
	v20_auto_button.add_theme_stylebox_override("pressed",_round_button_style(.98,40,UI.GOLD))
	v20_auto_button.add_theme_font_size_override("font_size",15)
	v20_layer.add_child(v20_auto_button)
	auto_button = v20_auto_button
	# Keep the existing wired button and input path used by touch regressions.
	var controls: Control = $Root/RightControls
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.z_index = 35
	controls.show()
	$Root/RightControls/AutoButton.hide()
	$Root/RightControls/PotionButton.hide()
	var attack: Button = $Root/RightControls/AttackButton
	attack.custom_minimum_size = Vector2.ZERO
	attack.add_theme_font_size_override("font_size",14)
	attack.text = ""
	attack.icon = UI.icon("attack")
	attack.expand_icon = true
	attack.add_theme_constant_override("icon_max_width",66)
	_place(attack,1157,514,1268,625)
	attack.add_theme_stylebox_override("normal",_round_button_style(.9,56,UI.GOLD))
	attack.add_theme_stylebox_override("hover",_round_button_style(.98,56,UI.GOLD))
	attack.add_theme_stylebox_override("pressed",_round_button_style(1.0,56,Color("f2d29a")))

func _build_v20_bottom_bar() -> void:
	var panel := Control.new()
	panel.name = "Quickslots"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel,0,0,1280,720)
	v20_layer.add_child(panel)
	v20_skill_container = HBoxContainer.new()
	v20_skill_container.hide()
	panel.add_child(v20_skill_container)
	for index: int in range(10):
		var b := UI.button("",_emit_quickslot.bind(index),Vector2(62,62))
		b.name = "Quickslot_%d" % index
		b.position = Vector2(Layout.quick_x(index),Layout.QUICK_Y)
		b.size = Vector2(62,62)
		b.add_theme_stylebox_override("normal",UI.slot_frame())
		b.add_theme_stylebox_override("hover",UI.slot_frame(UI.GOLD,true))
		b.add_theme_stylebox_override("pressed",UI.slot_frame(UI.GOLD,true))
		panel.add_child(b)
		v20_quickslot_buttons.append(b)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(4,4)
		icon.size = Vector2(54,54)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		quickslot_icons.append(icon)
		var caption := UI.label("",12,UI.GOLD)
		caption.position = Vector2(3,40)
		caption.size = Vector2(54,20)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(caption)
		quickslot_captions.append(caption)
		var number := UI.label(str(index+1),9,UI.MUTED)
		number.position = Vector2(4,1)
		b.add_child(number)
		var badge := UI.label("",10,Color("5bd5f5"))
		badge.position = Vector2(14,60)
		b.add_child(badge)
		quickslot_auto_badges.append(badge)
		var shade := ColorRect.new()
		shade.color = Color(0,0,0,.65)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.hide()
		b.add_child(shade)
		cooldown_shades.append(shade)
		var cooldown := UI.label("",19,Color.WHITE)
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(cooldown)
		quickslot_cooldown_labels.append(cooldown)
	for group: int in range(2):
		for page: int in range(5):
			var dot := UI.button(str(page+1),func() -> void:
				if pointer_transfer != null: pointer_transfer.cancel()
				quickslot_edit_requested.emit("page",group,page),Vector2(24,24))
			dot.name = "QuickPage_%d_%d" % [group,page]
			dot.add_theme_font_size_override("font_size",10)
			dot.position = Vector2((550 if group == 0 else 1017)+page*26,690)
			panel.add_child(dot)
			quick_page_buttons.append(dot)
	exp_readout = UI.label("EXP",12,UI.TEXT)
	_place(exp_readout,12,686,314,710)
	v20_layer.add_child(exp_readout)
	exp_bar = ProgressBar.new()
	exp_bar.show_percentage = false
	exp_bar.add_theme_stylebox_override("background",_bar_background())
	exp_bar.add_theme_stylebox_override("fill",_bar_fill(UI.GOLD))
	exp_bar.name = "ExperienceGauge"
	_place(exp_bar,0,717,1280,720)
	v20_layer.add_child(exp_bar)
	var sys := HBoxContainer.new()
	_place(sys,238,662,432,698)
	v20_layer.add_child(sys)
	for pair: Array in [["auto","사냥"],["log","기록"],["settings","설정"]]:
		var button := UI.button("",_navigate.bind(str(pair[0])),Vector2(40,36))
		button.icon = UI.icon(str(pair[0]))
		button.tooltip_text = str(pair[1])
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		sys.add_child(button)
	currency_readout = UI.label("",13,UI.GOLD)
	_place(currency_readout,470,10,733,36)
	v20_layer.add_child(currency_readout)
	coordinates_readout = UI.label("",10,UI.MUTED)
	_place(coordinates_readout,1038,238,1268,258)
	coordinates_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v20_layer.add_child(coordinates_readout)

func quickslot_index(visible_index: int) -> int:
	return Layout.quick_index(visible_index,get_parent()._quickslot_pages())

func _emit_quickslot(index: int) -> void:
	if pointer_transfer != null and pointer_transfer.suppress_click: return
	quickslot_pressed.emit(quickslot_index(index))

func _build_v20_message_and_log() -> void:
	message_label = UI.label("",16,UI.GOLD)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_outline_color",Color.BLACK)
	message_label.add_theme_constant_override("outline_size",3)
	_place(message_label,335,170,975,210)
	v20_layer.add_child(message_label)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.scroll_following = true
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.add_theme_font_size_override("normal_font_size",11)
	log_label.add_theme_color_override("default_color",UI.MUTED)
	_place(log_label,197,536,595,625)
	v20_layer.add_child(log_label)

	# Combat history must not cover the playable world with an opaque panel.
	# Full logs remain accessible in the workspace's 전투 기록 tab.
	var clear_panel := StyleBoxEmpty.new()
	log_label.add_theme_stylebox_override("normal",clear_panel)
	log_label.add_theme_stylebox_override("focus",clear_panel)
	log_label.add_theme_color_override("default_color",Color("ebdcbd"))
	log_label.add_theme_font_size_override("normal_font_size",11)
	log_label.modulate.a = .82

func _fit_hud() -> void:
	if v20_layer == null: return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x/1280.0,view.y/720.0)
	var logical: Vector2 = view/maxf(.01,factor)
	v20_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	v20_layer.position = Vector2.ZERO
	v20_layer.size = logical
	v20_layer.scale = Vector2.ONE*factor
	var controls: Control = $Root/RightControls
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls.position = Vector2.ZERO
	controls.size = logical
	controls.scale = Vector2.ONE*factor
	var extra_y: float = logical.y-720
	var extra_x: float = logical.x-1280
	for node: Node in v20_layer.get_children()+controls.get_children():
		if not node is Control: continue
		var control: Control = node
		if not control.has_meta("renewal_base_position"):
			control.set_meta("renewal_base_position",control.position)
		var base: Vector2 = control.get_meta("renewal_base_position")
		control.position = base
		if base.y >= 449: control.position.y += extra_y
		if base.x >= 943: control.position.x += extra_x
		elif control.name == "Quickslots" or control == v20_target_panel:
			control.position.x += extra_x*.5
	var quick_panel: Control = v20_layer.get_node("Quickslots")
	quick_panel.position = Vector2.ZERO
	quick_panel.size = logical
	for i: int in range(v20_quickslot_buttons.size()):
		v20_quickslot_buttons[i].position = Vector2(Layout.quick_x(i)+(extra_x*.5 if i < 5 else extra_x),Layout.QUICK_Y+extra_y)
	for i: int in range(quick_page_buttons.size()):
		quick_page_buttons[i].position = Vector2((550 if i < 5 else 1017)+(i%5)*26+(extra_x*.5 if i < 5 else extra_x),690+extra_y)
	exp_bar.size.x = logical.x
	joystick.scale = Vector2.ONE*factor
	if workspace != null: workspace.fit_viewport()

func _process(delta: float) -> void:
	super._process(delta)
	if not minimap_mounted:
		var minimap: Control = $Root.get_node_or_null("FieldMinimap")
		if minimap != null:
			minimap.reparent(v20_layer)
			_place(minimap,1096,88,1264,236)
			minimap_mounted = true
			_fit_hud()
	refresh_clock -= delta
	if refresh_clock>0:
		return
	refresh_clock = .15
	var world: Node = get_parent()
	if world == null or not world.has_method("_update_hud"):
		return
	var actor: Node = world.get("player")
	if actor != null and coordinates_readout != null:
		coordinates_readout.text = "좌표  %d, %d" % [int(actor.global_position.x),int(actor.global_position.y)]
		var current_field = get_parent().field_map
		if current_field is OriginalPlayableField:
			var source_cell: Vector2i = current_field.world_to_cell(actor.global_position) + current_field.coordinates.origin
			coordinates_readout.text = "원본 좌표  %d, %d" % [source_cell.x,source_cell.y]
	var cds: Dictionary = world.get("skill_cooldowns")
	for index: int in range(quickslot_cooldown_labels.size()):
		var remain: float = 0
		var absolute: int = quickslot_index(index)
		if absolute<quickslot_entries.size() and quickslot_entries[absolute] is Dictionary:
			var entry: Dictionary = quickslot_entries[absolute]
			var cooldowns: Dictionary = world.item_use_cooldowns if entry.get("kind","") == "item" else cds
			remain = float(cooldowns.get(str(entry.get("id","")),0))
		quickslot_cooldown_labels[index].text = "%.1f" % remain if remain>0 else ""
		if index < cooldown_shades.size(): cooldown_shades[index].visible = remain > 0
	if workspace != null and workspace.visible:
		workspace.footer.text = "아데나  %s  ·  Lv.%d  ·  %s  ·  Esc로 닫기" % [lineage_inventory_ui._format_number(int(character_state.get("gold",0))),int(character_state.get("level",1)),v20_map_name.text]
	if v20_target_panel.visible:
		var selected: Node = world.get("selected_monster")
		if is_instance_valid(selected):
			v20_target_name.text = "Lv.%d %s  ·  HP %d / %d" % [int(selected.get("monster_level")),str(selected.get("monster_name")),int(selected.get("hp")),int(selected.get("max_hp"))]

func update_player(level: int,hp: int,max_hp: int,mp: int,max_mp: int,experience_value: int,exp_need: int,gold: int) -> void:
	super.update_player(level,hp,max_hp,mp,max_mp,experience_value,exp_need,gold)
	# Preserve latest main's HP-only combat refresh (PR #43).
	var vitals: Dictionary = {"hp":hp,"max_hp":max_hp,"mp":mp,"max_mp":max_mp}
	character_state.merge(vitals, true)
	if is_instance_valid(lineage_side_ui):
		lineage_side_ui.update_vitals(hp,max_hp,mp,max_mp)
	if is_instance_valid(lineage_inventory_ui):
		lineage_inventory_ui.character_state.merge(vitals,true)
	if exp_readout != null:
		exp_readout.text = "Lv.%d  ·  EXP %.2f%%" % [level,float(experience_value)*100/maxi(1,exp_need)]
	if currency_readout != null:
		currency_readout.text = "아데나  "+lineage_inventory_ui._format_number(gold)

func set_quickslot_state(entries: Array,inventory: Dictionary,buffs: Dictionary,self_enabled: bool) -> void:
	super.set_quickslot_state(entries,inventory,buffs,self_enabled)
	# Main supplies its inventory here even on a fresh game without a save file.
	lineage_inventory_ui.set_inventory(inventory)
	var presentation: Dictionary={}
	for key: Variant in buffs:
		var effect: Variant=buffs[key]
		presentation[key]=int(ceil(float(effect.get("remaining",0)))) if effect is Dictionary else 0
	if active_buffs_view == presentation:
		return
	active_buffs_view = presentation
	_clear_children(buff_row)
	if buffs.is_empty():
		buff_row.add_child(UI.label("활성 효과 없음",11,UI.MUTED))
	for key: Variant in buffs.keys().slice(0,8):
		var effect: Variant = buffs[key]
		var time: int = int(ceil(float(effect.get("remaining",0)))) if effect is Dictionary else 0
		var b := UI.button("",open_character,Vector2(36,42))
		var icon := TextureRect.new()
		icon.texture = _load_texture("res://assets/ui/rune.png")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(5,2)
		icon.size = Vector2(26,25)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var remaining := UI.label("%ds" % time,10,UI.GOLD)
		remaining.position = Vector2(0,27)
		remaining.size = Vector2(36,15)
		remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(remaining)
		b.add_theme_font_size_override("font_size",10)
		b.tooltip_text = str(key)+" · %d초" % time
		buff_row.add_child(b)

func _render_quickslots(inventory: Dictionary,_buffs: Dictionary) -> void:
	for index: int in range(quickslot_icons.size()):
		var button: Button = v20_quickslot_buttons[index]
		var absolute: int = quickslot_index(index)
		UI.clear_item_visual(quickslot_icons[index])
		quickslot_icons[index].texture = null
		quickslot_captions[index].text = ""
		quickslot_auto_badges[index].text = ""
		button.text = ""
		button.icon = null
		button.tooltip_text = "빈 퀵슬롯 · 아이템/스킬을 끌어 등록"
		button.add_theme_stylebox_override("normal",UI.slot_frame())
		if absolute >= quickslot_entries.size() or not quickslot_entries[absolute] is Dictionary: continue
		var entry: Dictionary = quickslot_entries[absolute]
		if entry.is_empty(): continue
		var id: String = str(entry.get("id",""))
		button.tooltip_text = id+" · 아래로 끌기: AUTO / 위로 끌기: 해제"
		if entry.get("kind","") == "item":
			UI.apply_item_visual(quickslot_icons[index],lineage_inventory_ui._find_item_record(id),id,item_image_index.get("아이템",{}),"quickslot")
			quickslot_captions[index].text = str(int(inventory.get(id,0)))
			quickslot_icons[index].modulate = Color.WHITE if int(inventory.get(id,0)) > 0 else Color(.4,.4,.4)
		else:
			var skill: Dictionary = get_parent()._skill_record(str(entry.get("skill_id",id)))
			var path: String = str(skill.get("icon",""))
			quickslot_icons[index].texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else _skill_icon(str(skill.get("effect","")),str(skill.get("type","")))
			quickslot_icons[index].modulate = Color.WHITE
		if bool(entry.get("auto",false)):
			quickslot_auto_badges[index].text = "AUTO"
			button.add_theme_stylebox_override("normal",UI.slot_frame(Color("4db3d5"),true))
	var pages: Array = get_parent()._quickslot_pages()
	if is_instance_valid(quickslot_picker_hint): quickslot_picker_hint.text = "왼쪽 %d페이지 · 오른쪽 %d페이지" % [int(pages[0])+1,int(pages[1])+1]
	for i: int in range(quick_page_buttons.size()):
		quick_page_buttons[i].add_theme_stylebox_override("normal",UI.tab_frame(i%5 == int(pages[i/5])))

func append_log(value: String) -> void:
	log_history.append(value)
	if log_history.size()>120:
		log_history.pop_front()
	super.append_log(value)
	if active_section == "log" and is_instance_valid(combat_log_view) and not combat_log_view.is_queued_for_deletion():
		combat_log_view.text = "\n".join(log_history)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(detail_window) and detail_window.visible:
			detail_window.hide()
			get_viewport().set_input_as_handled()
			return
		if lineage_inventory_ui.detail_active and lineage_inventory_ui.is_visible_in_tree():
			lineage_inventory_ui.detail_active = false
			lineage_inventory_ui._reflow()
			get_viewport().set_input_as_handled()
			return
		if active_section == "skills" and is_instance_valid(skills_view):
			var browser: Control = skills_view.cards.get_parent().get_parent()
			if browser.detail_active:
				browser.detail_active = false
				browser.reflow()
				get_viewport().set_input_as_handled()
				return
		if workspace != null and workspace.visible:
			_go_back()
			get_viewport().set_input_as_handled()

func _close_workspace() -> void:
	if class_picker_initial:
		return
	if workspace != null and workspace.visible:
		navigation_memory.capture(active_section,workspace.content)
	if not switching_workspace:
		navigation_memory.clear_history()
	combat_log_view = null
	pending_quickslot_binding.clear()
	if active_section in ["아이템","변신","마법인형","성물"] and catalog_list != null:
		catalog_view_state[active_section] = {"query":catalog_search.text,"grade":catalog_grade_filter,"page":catalog_page,"id":str(selected_catalog_record.get("sourceId",selected_catalog_record.get("name",""))),"scroll":catalog_list.get_v_scroll_bar().value}
	if pointer_transfer != null: pointer_transfer.cancel()
	for dialog: Node in $Root.get_children():
		if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion(): dialog.dismiss()
	if is_instance_valid(detail_window): detail_window.hide()
	if is_instance_valid(companion_window): companion_window.hide()
	if workspace != null:
		workspace.hide()
	active_section = ""
	if lineage_inventory_ui != null:
		lineage_inventory_ui.hide_inventory()
	if lineage_side_ui != null:
		lineage_side_ui.hide_all()

func _hide_aux_panels() -> void:
	super._hide_aux_panels()
	_close_workspace()

func _park_shared_panels() -> void:
	for panel: Control in [lineage_inventory_ui,lineage_side_ui.character_panel,utility_panel,map_panel,catalog_panel]:
		if panel.get_parent() != $Root:
			panel.reparent($Root)
		panel.hide()

func _open_window(section: String,title: String,description: String) -> void:
	navigation_memory.enter(active_section,section)
	switching_workspace = true
	_hide_aux_panels()
	switching_workspace = false
	_park_shared_panels()
	workspace.clear()
	workspace.open(section,title,description)
	active_section = section
	workspace.set_back_available(navigation_memory.has_history())
	call_deferred("_restore_navigation",section)

func _restore_navigation(section: String) -> void:
	if workspace != null and workspace.visible and active_section == section:
		navigation_memory.restore(section,workspace.content)

func _go_back() -> void:
	if class_picker_initial: return
	if active_section == "inventory" and lineage_inventory_ui.detail_active:
		lineage_inventory_ui.detail_active = false
		lineage_inventory_ui._reflow()
		return
	if active_section == "skills" and is_instance_valid(skills_view):
		var browser: Control = skills_view.cards.get_parent().get_parent()
		if browser.detail_active:
			browser.detail_active = false
			browser.reflow()
			return
	if active_section in ["변신","마법인형","성물","아이템"] and catalog_details_active:
		_set_catalog_detail_view(false)
		return
	var previous: String = navigation_memory.back()
	if previous.is_empty() or previous == "dialogue":
		_close_workspace()
		return
	navigation_memory.returning = true
	_navigate(previous)
	navigation_memory.returning = false
	if workspace != null:
		workspace.set_back_available(navigation_memory.has_history())

func open_class_selection(initial: bool = false) -> void:
	# In the first session there is no class decision until the user confirms.
	if class_picker_initial:
		return
	_open_window("class_select","클래스 선택","13개 직업 · 주무기 · 스탯 · 대표 변신")
	var picker := ClassSelectUI.new()
	workspace.mount(picker)
	picker.configure(self,initial)
	class_picker_initial = initial
	class_picker_backdrop.visible = initial
	# Prevent moving or attacking before a starter class is committed.
	if initial:
		var actor: Node = get_parent().get_node_or_null("Player")
		if actor != null:
			actor.set_physics_process(false)
		workspace.move_to_front()

func complete_class_selection() -> void:
	class_picker_initial = false
	class_picker_backdrop.hide()
	var actor: Node = get_parent().get_node_or_null("Player")
	if actor != null:
		actor.set_physics_process(true)
	_close_workspace()

func _navigate(section: String) -> void:
	if class_picker_initial:
		return
	match section:
		"class_select": open_class_selection()
		"inventory": inventory_pressed.emit()
		"character": open_character()
		"skills": open_skills()
		"shop": open_shop()
		"npc_shop": open_npc_shop()
		"teleport": open_npc_teleport()
		"map": toggle_map()
		"menu": toggle_menu()
		"settings": open_settings_info()
		"auto": open_macro_info()
		"log": open_combat_log()
		"enhance": _open_enhance_chooser()
		"warehouse": open_warehouse()
		"crafting": open_crafting()
		"sell": open_item_sell()
		_: open_catalog(section)

func confirm_action(title: String, body: String, action: String, callback: Callable, maximum: int = 0) -> Control:
	for dialog: Node in $Root.get_children():
		if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion(): return dialog
	if pointer_transfer != null: pointer_transfer.cancel()
	var dialog := preload("res://scripts/ui/renewal_confirmation.gd").new()
	$Root.add_child(dialog)
	dialog.configure(title,body,action,callback,maximum)
	return dialog

func open_shop() -> void:
	_open_window("shop","상점","")
	var shop := ShopUI.new()
	workspace.mount(shop)
	shop.configure(self)
	shop_view = shop

func open_npc_shop() -> void:
	_open_window("npc_shop","잡화 상인","")
	var shop := ShopUI.new()
	workspace.mount(shop)
	shop.configure(self,true)
	shop_view = shop

func refresh_shop() -> void:
	if active_section in ["shop","npc_shop"] and is_instance_valid(shop_view): shop_view._refresh()

func refresh_service() -> void:
	if active_section in ["warehouse","sell"] and is_instance_valid(transaction_view): transaction_view._refresh()

func open_warehouse() -> void:
	_open_window("warehouse","창고지기","아이템 보관/찾기 · 개별 강화 상태 보존")
	var screen := WarehouseUI.new()
	workspace.mount(screen)
	screen.configure(self)
	transaction_view = screen
	show_companion_bag()

func open_npc_teleport() -> void:
	_open_window("teleport","텔레포트 안내인","기존 25개 맵으로 이동 · 기존 충돌/좌표 보존")
	var screen := TeleportUI.new()
	workspace.mount(screen)
	screen.configure(self)

func open_crafting() -> void:
	_open_window("crafting","제작 장인","재료·비용 검사 · TWILIGHT 자체 제작식")
	var screen := CraftUI.new()
	workspace.mount(screen)
	screen.configure(self)

func open_item_sell() -> void:
	_open_window("sell","아이템 매입","아이템 검색 · 강화 장비 ID 확인 · 판매")
	var screen := SellUI.new()
	workspace.mount(screen)
	screen.configure(self)
	transaction_view = screen
	show_companion_bag()

func _companion(section: String,title: String) -> PanelContainer:
	if not is_instance_valid(companion_window):
		companion_window = RenewalWindowScript.new()
		$Root.add_child(companion_window)
		companion_window.z_index = 155
		companion_window.closed.connect(func() -> void:
			pointer_transfer.cancel()
			companion_window.hide())
	# Return reusable panels to Root before clearing a previous companion view.
	for panel: Control in [lineage_inventory_ui,lineage_side_ui.character_panel]:
		if companion_window.content.is_ancestor_of(panel): panel.reparent($Root); panel.hide()
	companion_window.clear()
	companion_window.open(section,title,"")
	return companion_window

func show_companion_bag() -> void:
	var window: PanelContainer = _companion("inventory","가방")
	window.mount(lineage_inventory_ui)
	lineage_inventory_ui.show()
	lineage_inventory_ui.show_inventory()

func show_companion_equipment() -> void:
	var window: PanelContainer = _companion("character","장비")
	window.mount(lineage_side_ui.character_panel)
	lineage_side_ui.show_character(character_state)

func open_npc_dialogue(npc_id: String) -> void:
	_open_window("dialogue","NPC 대화","레벨 · 직업 · 아이템 보유 조건")
	var screen := DialogueUI.new()
	workspace.mount(screen)
	screen.configure(self,npc_id)

func open_settings_info() -> void:
	_open_window("settings","설정","오디오 · HUD · 로컬 저장 및 불러오기")
	var options := SettingsUI.new()
	workspace.mount(options)
	options.configure(self)

func open_macro_info() -> void:
	_open_window("auto","자동사냥","사냥 상태 · 전투와 습득")
	var scroll := ScrollContainer.new()
	scroll.name = "AutoSettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.mount(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var player: Node = get_parent().get("player")
	var enabled := bool(player.get("auto_enabled")) if player != null else false
	var banner := PanelContainer.new()
	banner.name = "AutoStatusBanner"
	banner.add_theme_stylebox_override("panel",UI.chrome_panel(Color("151b1b"),UI.BRONZE,18))
	col.add_child(banner)
	var row := HBoxContainer.new()
	banner.add_child(row)
	var emblem := TextureRect.new()
	emblem.texture = UI.icon("auto")
	emblem.custom_minimum_size = Vector2(64,64)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(emblem)
	var status := UI.section("AUTO  ·  사냥 중" if enabled else "AUTO  ·  대기 중",22)
	status.name = "AutoStatusTitle"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(status)
	var toggle := UI.button("AUTO 끄기" if enabled else "AUTO 켜기",func() -> void:
		if workspace.was_scroll_dragged(scroll): return
		auto_pressed.emit()
		open_macro_info(),Vector2(220,48))
	toggle.name = "AutoSettingToggle"
	col.add_child(toggle)
	workspace.register_scroll_drag(scroll,toggle)
	for pair: Array in [["목표 탐색","주변 몬스터 탐색 및 이동"],["전투","현재 장비와 스킬 · 등록된 자동 사용"],["습득","바닥 드랍을 통한 자동 아이템 습득"]]:
		col.add_child(HSeparator.new())
		col.add_child(UI.section(str(pair[0]),14))
		col.add_child(UI.section(str(pair[1]),12))
	var routes := HBoxContainer.new()
	col.add_child(routes)
	for target: Array in [["skills","스킬 · 자동 사용"],["inventory","인벤토리"]]:
		var id: String = str(target[0])
		var route := UI.button(str(target[1]),func() -> void:
			if not workspace.was_scroll_dragged(scroll): _navigate(id))
		routes.add_child(route)
		workspace.register_scroll_drag(scroll,route)

func open_combat_log() -> void:
	_open_window("log","전투 기록","오프라인 시스템 · 최근 120건")
	var col: VBoxContainer = workspace.column()
	col.add_child(UI.label("전투 / 시스템 로그",21,UI.GOLD))
	var history := UI.rich("")
	history.fit_content = false
	history.scroll_active = true
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.name = "CombatLogHistory"
	history.text = "\n".join(log_history) if not log_history.is_empty() else "아직 기록이 없습니다."
	col.add_child(history)
	combat_log_view = history

func toggle_inventory() -> void:
	if active_section=="inventory" and workspace.visible:
		_close_workspace()
		return
	_open_window("inventory","가방","")
	workspace.mount(lineage_inventory_ui)
	lineage_inventory_ui.show()
	lineage_inventory_ui.show_inventory()

func open_character() -> void:
	_open_window("character","캐릭터 정보","")
	var panel: PanelContainer = lineage_side_ui.character_panel
	panel.custom_minimum_size = Vector2.ZERO
	workspace.mount(panel)
	panel.show()
	lineage_side_ui.show_character(character_state)

func open_detailed_status() -> void:
	if not is_instance_valid(detail_window):
		detail_window = RenewalWindowScript.new()
		$Root.add_child(detail_window)
		detail_window.z_index = 220
		detail_window.closed.connect(func() -> void: detail_window.hide())
	detail_window.clear()
	detail_window.open("detailed_status","상세 스테이터스","")
	status_view = preload("res://scripts/ui/renewal_status.gd").new()
	detail_window.mount(status_view)
	status_view.configure(character_state)

func toggle_menu() -> void:
	if active_section=="menu" and workspace.visible:
		_close_workspace()
		return
	_open_window("menu","메뉴","")
	var col: VBoxContainer = workspace.column()
	var menu_scroll := ScrollContainer.new()
	menu_scroll.name = "MenuContentScroll"
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	menu_scroll.scroll_deadzone = 8
	col.add_child(menu_scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	menu_scroll.add_child(grid)
	menu_scroll.resized.connect(func() -> void: grid.columns = clampi(floori(menu_scroll.size.x/99.0),2,4))
	for pair: Array in [["character","캐릭터·장비"],["class_select","클래스 선택"],["inventory","인벤토리"],["skills","스킬"],["변신","변신"],["마법인형","마법인형"],["성물","성물"],["아이템","아이템 도감"],["map","월드맵"],["shop","잡화 상점"],["enhance","장비 강화"],["auto","자동사냥"],["warehouse","창고"],["crafting","제작"],["sell","판매"],["settings","설정"],["log","전투 기록"]]:
		var section_id: String = str(pair[0])
		var button: Button = UI.button("",func() -> void:
			if not workspace.was_scroll_dragged(menu_scroll):
				_navigate(section_id),Vector2(92,88))
		button.name = "MenuTile_"+section_id
		button.add_theme_stylebox_override("normal",UI.slot_frame())
		button.add_theme_stylebox_override("hover",UI.slot_frame(UI.GOLD,true))
		button.add_theme_stylebox_override("pressed",UI.slot_frame(UI.GOLD,true))
		var artwork := TextureRect.new()
		artwork.texture = UI.icon(section_id)
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.position = Vector2(26,8)
		artwork.size = Vector2(40,40)
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(artwork)
		var caption := UI.label(str(pair[1]),11)
		caption.position = Vector2(0,58)
		caption.size = Vector2(92,20)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(caption)
		grid.add_child(button)
		workspace.register_scroll_drag(menu_scroll,button)

func _open_utility_panel(title: String) -> void:
	var section := "utility"
	if title.contains("상점"): section="shop"
	elif title.contains("스킬"): section="skills"
	elif title.contains("강화"): section="enhance"
	elif title.contains("설정"): section="settings"
	elif title.contains("자동사냥"): section="auto"
	_open_window(section,title,"TWILIGHT · 현재 게임 데이터와 연결된 기능")
	workspace.mount(utility_panel)
	utility_panel.show()
	utility_panel.add_theme_stylebox_override("panel",UI.box(Color("11171d"),UI.BRONZE,10))
	_clear_children(utility_body)
	utility_title.hide()
	utility_scroll.custom_minimum_size = Vector2.ZERO
	var box: VBoxContainer = utility_panel.get_child(0)
	(box.get_child(box.get_child_count()-1) as Control).hide()

func open_catalog(category: String) -> void:
	_reset_catalog_drag()
	_open_window(category,category,"")
	workspace.mount(catalog_panel)
	catalog_panel.show()
	catalog_category = category
	catalog_grade_filter = "전체"
	item_grade_filter = "전체"
	item_slot_filter = "all"
	rarity_filter.select(0)
	collection_slot_filter.visible = category=="아이템"
	collection_slot_filter.select(0)
	catalog_search.set_text("")
	collection_status.text = "아이템 정보" if category=="아이템" else "현재 적용: "+str(character_state.get("equipped",{}).get(category,{}).get("name","없음"))
	for grade_name: String in catalog_grade_buttons:
		catalog_grade_buttons[grade_name].button_pressed = grade_name == "전체"
	playtest_grant_button.visible = category == "아이템"
	playtest_grant_button.disabled = true
	playtest_aden_button.visible = category == "아이템"
	for grant: Button in playtest_scroll_buttons:
		grant.visible = category == "아이템"
	catalog_clear_button.visible = category != "아이템"
	catalog_test_toggle.visible = category == "아이템"
	catalog_test_tools.hide()
	catalog_test_toggle.button_pressed = false
	_refresh_catalog_list("")
	var saved: Dictionary = catalog_view_state.get(category,{})
	if not saved.is_empty():
		catalog_grade_filter = str(saved.get("grade","전체"))
		item_grade_filter = catalog_grade_filter
		catalog_search.text = str(saved.get("query",""))
		_refresh_catalog_list(catalog_search.text)
		catalog_page = clampi(int(saved.get("page",0)),0,maxi(0,_catalog_page_count()-1))
		_apply_catalog_page()
		for i: int in range(catalog_results.size()):
			if str(catalog_results[i].get("sourceId",catalog_results[i].get("name",""))) == str(saved.get("id","")): _select_catalog_index(i)
		catalog_list.get_v_scroll_bar().set_deferred("value",float(saved.get("scroll",0)))
		for grade_name: String in catalog_grade_buttons: catalog_grade_buttons[grade_name].button_pressed = grade_name == catalog_grade_filter
	catalog_details_active = false
	_fit_catalog_browser_layout()

func _build_catalog_panel() -> void:
	super._build_catalog_panel()
	var old: Node = catalog_panel.get_child(0)
	var col := VBoxContainer.new()
	catalog_panel.add_child(col)
	catalog_title.reparent(col)
	catalog_title.hide()
	item_filter_panel.reparent(col)
	item_filter_panel.hide()
	var top := HBoxContainer.new()
	col.add_child(top)
	catalog_search.reparent(top)
	catalog_search.placeholder_text = "이름 · 종류 검색"
	catalog_search.custom_minimum_size.y = 40
	rarity_filter = OptionButton.new()
	rarity_filter.name = "RarityFilter"
	for value: String in ["전체","일반","고급","희귀","영웅","전설","신화","유일"]:
		rarity_filter.add_item(value)
	rarity_filter.item_selected.connect(func(index: int) -> void:
		catalog_grade_filter=rarity_filter.get_item_text(index)
		item_grade_filter=catalog_grade_filter
		_refresh_catalog_list(catalog_search.text))
	top.add_child(rarity_filter)
	rarity_filter.hide()
	collection_slot_filter = OptionButton.new()
	collection_slot_filter.name = "EquipmentTypeFilter"
	collection_slot_filter.add_item("전체")
	for pair: Array in ITEM_SLOT_FILTERS:
		collection_slot_filter.add_item(str(pair[1]))
	collection_slot_filter.item_selected.connect(_select_catalog_group_index)
	top.add_child(collection_slot_filter)
	collection_status = UI.label("",12,UI.MUTED)
	collection_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(collection_status)
	catalog_view_tabs = HBoxContainer.new()
	catalog_view_tabs.name = "CatalogCompactTabs"
	catalog_list_tab = UI.button("아이템 목록", func() -> void: _set_catalog_detail_view(false), Vector2(115, 34))
	catalog_details_tab = UI.button("선택 상세", func() -> void: _set_catalog_detail_view(true), Vector2(115, 34))
	catalog_view_tabs.add_child(catalog_list_tab)
	catalog_view_tabs.add_child(catalog_details_tab)
	col.add_child(catalog_view_tabs)
	catalog_view_tabs.hide()
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	catalog_grade_column = VBoxContainer.new()
	catalog_grade_column.name = "CatalogGrades"
	catalog_grade_column.custom_minimum_size.x = 132
	body.add_child(catalog_grade_column)
	for grade_name: String in ["전체","유일","신화","전설","영웅","희귀","고급","일반"]:
		var grade_button := UI.button(grade_name,func() -> void:
			catalog_grade_filter = grade_name
			item_grade_filter = grade_name
			rarity_filter.select(["전체","일반","고급","희귀","영웅","전설","신화","유일"].find(grade_name))
			for key: String in catalog_grade_buttons: catalog_grade_buttons[key].button_pressed = key == grade_name
			_refresh_catalog_list(catalog_search.text),Vector2(124,44))
		grade_button.toggle_mode = true
		grade_button.add_theme_color_override("font_color",UI.grade(grade_name))
		catalog_grade_column.add_child(grade_button)
		catalog_grade_buttons[grade_name] = grade_button
	for title: String in ["합성","컬렉션"]:
		var unavailable := UI.button(title,Callable(),Vector2(124,36))
		unavailable.disabled = true
		unavailable.tooltip_text = "현재 게임에 카드 보유·중복 재료 및 "+title+" 시스템이 없어 사용할 수 없습니다"
		catalog_grade_column.add_child(unavailable)
	var left := VBoxContainer.new()
	catalog_body_left = left
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	catalog_list.reparent(left)
	catalog_list.custom_minimum_size = Vector2(0,0)
	catalog_list.max_columns = 4
	catalog_list.fixed_column_width = 120
	catalog_list.fixed_icon_size = Vector2i(94,116)
	catalog_list.icon_mode = ItemList.ICON_MODE_TOP
	catalog_list.max_text_lines = 2
	catalog_list.same_column_width = true
	catalog_list.add_theme_constant_override("v_separation",12)
	catalog_list.add_theme_constant_override("h_separation",8)
	catalog_list.add_theme_font_size_override("font_size",13)
	var pager := HBoxContainer.new()
	pager.custom_minimum_size = Vector2(0, 40)
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(pager)
	for control: Control in [catalog_first_button,catalog_prev_button,catalog_page_label,catalog_next_button,catalog_last_button]:
		control.reparent(pager)
		control.custom_minimum_size.y = 34
	catalog_first_button.custom_minimum_size.x = 46
	catalog_prev_button.custom_minimum_size.x = 38
	catalog_page_label.custom_minimum_size.x = 64
	catalog_next_button.custom_minimum_size.x = 38
	catalog_last_button.custom_minimum_size.x = 46
	catalog_count.reparent(left)
	catalog_count.add_theme_font_size_override("font_size",11)
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "CatalogActionsScroll"
	catalog_body_actions = right_scroll
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.custom_minimum_size.x = 520
	right_scroll.size_flags_horizontal = Control.SIZE_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(500,0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	var preview_row := HBoxContainer.new()
	preview_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview_row)
	catalog_preview.reparent(preview_row)
	catalog_preview.custom_minimum_size = Vector2(180,0)
	catalog_preview.size_flags_horizontal = Control.SIZE_FILL
	catalog_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_detail.reparent(preview_row)
	catalog_detail.custom_minimum_size = Vector2(0,0)
	catalog_detail.fit_content = false
	catalog_detail.scroll_active = true
	catalog_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_detail.add_theme_font_size_override("normal_font_size",13)
	catalog_equip_button.reparent(right)
	catalog_equip_button.custom_minimum_size.y = 46
	catalog_equip_button.name = "ApplyCatalog"
	catalog_clear_button = UI.button("현재 적용 해제",func() -> void:
		if catalog_category != "아이템":
			var category: String = catalog_category
			confirm_action("적용 해제",category+" 적용을 해제하시겠습니까?","해제",func(_count: int) -> void: catalog_equip_requested.emit(category,{})))
	catalog_clear_button.name = "ClearCatalog"
	right.add_child(catalog_clear_button)
	# Clearly marked playtest grants. Runtime inventory and item-ID logic remain
	# world-owned; the UI only emits requests and never writes inventory itself.
	catalog_test_toggle = UI.button("검수용 지급 도구",Callable(),Vector2(0,32))
	catalog_test_toggle.name = "CatalogTestToolsToggle"
	catalog_test_toggle.toggle_mode = true
	catalog_test_toggle.add_theme_font_size_override("font_size",11)
	right.add_child(catalog_test_toggle)
	catalog_test_tools = VBoxContainer.new()
	catalog_test_tools.name = "CatalogTestTools"
	right.add_child(catalog_test_tools)
	catalog_test_tools.hide()
	catalog_test_toggle.toggled.connect(func(enabled: bool) -> void: catalog_test_tools.visible = enabled)
	catalog_test_tools.add_child(UI.label("테스트 전용 · 정식 게임에서는 제거",11,UI.GOLD))
	playtest_grant_button = UI.button("선택 아이템 1개 임시 지급",_request_playtest_catalog_grant,Vector2(0,42))
	playtest_grant_button.name = "PlaytestGrantSelected"
	catalog_test_tools.add_child(playtest_grant_button)
	playtest_aden_button = UI.button("아데나 1억 맞추기",func() -> void: playtest_aden_grant_requested.emit(),Vector2(0,42))
	playtest_aden_button.name = "PlaytestAden"
	catalog_test_tools.add_child(playtest_aden_button)
	for scroll: String in ["무기 마법 주문서 (각인)","갑옷 마법 주문서 (각인)","장신구 마법 주문서 (각인)"]:
		var grant_name: String = scroll
		var grant := UI.button("테스트 " + grant_name.replace(" (각인)","") + " ×10",func() -> void:
			playtest_catalog_grant_requested.emit(grant_name,10),Vector2(0,39))
		grant.name = "PlaytestScroll" + str(playtest_scroll_buttons.size())
		catalog_test_tools.add_child(grant)
		playtest_scroll_buttons.append(grant)
	old.queue_free()

func _reset_catalog_drag() -> void:
	catalog_drag_touch = -1
	catalog_drag_mouse = false
	catalog_drag_index = -1
	catalog_drag_ready = false
	if is_instance_valid(catalog_drag_icon): catalog_drag_icon.hide()

func _inside_catalog_control(control: Control, canvas_point: Vector2) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return false
	var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * canvas_point
	return Rect2(Vector2.ZERO, control.size).has_point(local)

func _begin_catalog_drag(point: Vector2, touch_index: int, is_mouse: bool) -> void:
	if catalog_list == null or not _inside_catalog_control(catalog_list, point): return
	var local: Vector2 = catalog_list.get_global_transform_with_canvas().affine_inverse() * point
	var index: int = catalog_list.get_item_at_position(local, true)
	if index < 0 or index >= catalog_results.size(): return
	catalog_drag_touch = touch_index
	catalog_drag_mouse = is_mouse
	catalog_drag_index = index
	catalog_drag_origin = point
	catalog_drag_position = point
	catalog_drag_ready = false

func _continue_catalog_drag(point: Vector2) -> void:
	if catalog_drag_index < 0: return
	catalog_drag_position = point
	var delta: Vector2 = point - catalog_drag_origin
	if not catalog_drag_ready and delta.length() > 22.0 and delta.x > absf(delta.y) * 1.15:
		catalog_drag_ready = true
		var record: Dictionary = catalog_results[catalog_drag_index] as Dictionary
		var path: String = str(record.get("image_path", ""))
		var art: Texture2D = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
		if catalog_category == "아이템":
			art = UI.item_icon(record, str(record.get("name", "")), item_image_index.get("아이템", {}))
		catalog_drag_icon.texture = art
		catalog_drag_icon.show()
	if catalog_drag_ready:
		catalog_drag_icon.position = point - Vector2(38, 38)

func _end_catalog_drag(point: Vector2) -> void:
	var index: int = catalog_drag_index
	var delta: Vector2 = point - catalog_drag_origin
	var can_apply: bool = catalog_drag_ready and _inside_catalog_control(catalog_equip_button, point)
	_reset_catalog_drag()
	if can_apply and index >= 0 and index < catalog_results.size():
		_select_catalog_index(index)
		if not catalog_equip_button.disabled:
			_equip_selected_catalog()
		if catalog_view_tabs.visible:
			_set_catalog_detail_view(true)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Preserve normal left/right swipe scrolling, taps, input focus and all World actions.
	if not is_instance_valid(workspace) or not workspace.visible or catalog_list == null or not catalog_list.is_visible_in_tree():
		if catalog_drag_index >= 0: _reset_catalog_drag()
		return
	if active_section not in ["변신","마법인형","성물","아이템"]:
		if catalog_drag_index >= 0: _reset_catalog_drag()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.device == InputEvent.DEVICE_ID_EMULATION: return
		if touch.pressed and not touch.canceled and catalog_drag_index == -1:
			_begin_catalog_drag(touch.position,touch.index,false)
		elif touch.index == catalog_drag_touch and (not touch.pressed or touch.canceled):
			if not touch.canceled: _end_catalog_drag(touch.position)
			else: _reset_catalog_drag()
	elif event is InputEventScreenDrag and event.index == catalog_drag_touch and catalog_drag_index >= 0:
		_continue_catalog_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and catalog_drag_index == -1:
			_begin_catalog_drag(event.position,-1,true)
		elif not event.pressed and catalog_drag_mouse: _end_catalog_drag(event.position)
	elif event is InputEventMouseMotion and catalog_drag_mouse and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_continue_catalog_drag(event.position)

func _set_catalog_detail_view(show_details: bool) -> void:
	catalog_details_active = show_details
	_fit_catalog_browser_layout()

func _fit_catalog_browser_layout() -> void:
	if workspace == null or catalog_body_left == null or catalog_body_actions == null: return
	var compact: bool = workspace.content.size.x < 1040
	var short: bool = workspace.content.size.y < 430
	collection_status.visible = not short
	catalog_count.visible = not short
	catalog_preview.custom_minimum_size = Vector2(150 if compact else 180,0)
	catalog_list.fixed_icon_size = Vector2i(78,92) if short else Vector2i(94,116)
	catalog_list.add_theme_constant_override("v_separation",10)
	catalog_search.custom_minimum_size.y = 34
	catalog_view_tabs.visible = compact and active_section in ["아이템","변신","마법인형","성물"]
	catalog_grade_column.visible = not compact
	rarity_filter.visible = compact
	catalog_body_left.visible = not compact or not catalog_details_active
	catalog_body_actions.visible = not compact or catalog_details_active
	catalog_list.custom_minimum_size.x = 0
	catalog_list.max_columns = 4
	catalog_list.fixed_column_width = 116
	catalog_body_actions.custom_minimum_size.x = 0 if compact else 520
	var actions_content: Control = catalog_body_actions.get_child(0)
	actions_content.custom_minimum_size.x = 0 if compact else 500
	catalog_list_tab.disabled = compact and not catalog_details_active
	catalog_details_tab.disabled = compact and catalog_details_active

func _select_catalog_group_index(index: int) -> void:
	item_slot_filter = "all" if index == 0 else str(ITEM_SLOT_FILTERS[index - 1][0])
	item_grade_filter = "전체"
	catalog_grade_filter = "전체"
	rarity_filter.select(0)
	_refresh_catalog_list(catalog_search.text)

func _item_slot_label(slot_id: String) -> String:
	if slot_id == "all":
		return "전체"
	return super._item_slot_label(slot_id)

func _refresh_item_filter_controls() -> void:
	if rarity_filter != null:
		rarity_filter.select(maxi(0,["전체","일반","고급","희귀","영웅","전설","신화","유일"].find(item_grade_filter)))

func _refresh_catalog_list(filter_text: String) -> void:
	# The original paging, selection and native touch handler remain in use.
	catalog_filtered_results.clear()
	catalog_variant_counts.clear()
	if catalog_category == "아이템":
		for raw: Variant in catalog_data.get("아이템", []) as Array:
			if raw is Dictionary:
				var name_value: String = str((raw as Dictionary).get("name", ""))
				catalog_variant_counts[name_value] = int(catalog_variant_counts.get(name_value, 0)) + 1
	var query := filter_text.strip_edges().to_lower()
	for value: Variant in catalog_data.get(catalog_category,[]):
		if not value is Dictionary: continue
		var record: Dictionary = value
		if catalog_category=="아이템" and item_slot_filter!="all" and _item_filter_group(record)!=item_slot_filter: continue
		if catalog_grade_filter!="전체" and str(record.get("grade",""))!=catalog_grade_filter: continue
		var searchable := "%s %s %s %s %s" % [record.get("name",""),record.get("grade",""),record.get("type",""),record.get("sourceId",""),record.get("desc","")]
		if query!="" and not searchable.to_lower().contains(query): continue
		catalog_filtered_results.append(record)
	catalog_page=0
	_apply_catalog_page()

func _apply_catalog_page() -> void:
	UI.clear_item_visual(catalog_preview)
	catalog_icon_generation += 1
	var request_id: int = catalog_icon_generation
	super._apply_catalog_page()
	for index: int in range(catalog_results.size()):
		var record: Dictionary = catalog_results[index]
		var grade_name := str(record.get("grade","일반"))
		var color: Color = UI.grade(grade_name)
		var item_label: String = str(record.get("name", ""))
		if catalog_category == "아이템" and _catalog_variant_count(item_label) > 1:
			item_label += "\nID " + str(record.get("sourceId", ""))
		catalog_list.set_item_text(index,item_label)
		catalog_list.set_item_custom_fg_color(index,color)
		catalog_list.set_item_custom_bg_color(index,Color(color,.08))
		if catalog_category != "아이템":
			var path := str(record.get("image_path", ""))
			if path != "" and ResourceLoader.exists(path):
				catalog_list.set_item_icon(index, load(path) as Texture2D)
		catalog_list.set_item_tooltip(index,"%s · %s · 원본 ID: %s" % [grade_name,record.get("name",""),record.get("sourceId","")])
	if catalog_results.is_empty():
		catalog_detail.text="검색 조건에 맞는 기록이 없습니다."
		catalog_equip_button.disabled=true
	(catalog_panel.find_child("ClearCatalog",true,false) as Button).visible=catalog_category!="아이템"
	# Render the original source-ID icons in small batches so all item names
	# appear immediately instead of the browser blocking during 40 image effects.
	if catalog_category == "아이템" and not catalog_results.is_empty():
		call_deferred("_fill_catalog_page_icons", request_id)

func _fill_catalog_page_icons(request_id: int) -> void:
	for index: int in range(catalog_results.size()):
		if request_id != catalog_icon_generation or catalog_category != "아이템":
			return
		var record: Dictionary = catalog_results[index]
		var icon_texture: Texture2D = UI.item_icon(record, str(record.get("name", "")), item_image_index.get("아이템", {}))
		if icon_texture != null and index < catalog_list.item_count:
			catalog_list.set_item_icon(index, icon_texture)
		if index % 3 == 2:
			await get_tree().process_frame

func _request_playtest_catalog_grant() -> void:
	if catalog_category != "아이템" or selected_catalog_record.is_empty():
		return
	var source_id: String = str(selected_catalog_record.get("sourceId", ""))
	if source_id != "":
		playtest_catalog_variant_grant_requested.emit(source_id, 1)
	else:
		playtest_catalog_grant_requested.emit(str(selected_catalog_record.get("name", "")), 1)

func _catalog_variant_count(item_name: String) -> int:
	return int(catalog_variant_counts.get(item_name, 0))

func _catalog_pinned_instance_id(record: Dictionary) -> String:
	var source_id: String = str(record.get("sourceId", ""))
	var name_value: String = str(record.get("name", ""))
	var state: Variant = character_state.get("item_instances", {})
	if not (state is Dictionary):
		return ""
	for raw_id: Variant in (state as Dictionary).keys():
		var raw_entry: Variant = (state as Dictionary)[raw_id]
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if str(entry.get("name", "")) != name_value:
			continue
		if str(entry.get("sourceId", "")) == source_id:
			return str(raw_id)
		var pinned: Variant = entry.get("record", {})
		if pinned is Dictionary and str((pinned as Dictionary).get("sourceId", "")) == source_id:
			return str(raw_id)
	return ""

func _on_catalog_item_selected(index: int) -> void:
	UI.clear_item_visual(catalog_preview)
	super._on_catalog_item_selected(index)
	if selected_catalog_record.is_empty():
		if playtest_grant_button != null: playtest_grant_button.disabled = true
		return
	if playtest_grant_button != null:
		playtest_grant_button.disabled = catalog_category != "아이템"
	var item_name := str(selected_catalog_record.get("name",""))
	var grade_name := str(selected_catalog_record.get("grade","일반"))
	var option_lines := PackedStringArray()
	for value: Variant in selected_catalog_record.get("sourceOptions",[]):
		var option: String = str(value).replace("PVP","PVE").replace("PvP","PvE")
		if option.contains("손상") or option.contains("저주"): continue
		option_lines.append("• "+UI.safe(option)+CARD_OPTION_VISIBILITY.suffix(catalog_category,option,selected_catalog_record))
	catalog_detail.text = "[font_size=18][b]%s[/b][/font_size]\n%s\n\n%s" % [UI.safe(item_name),UI.safe(selected_catalog_record.get("type","")),"\n".join(option_lines) if not option_lines.is_empty() else UI.safe(selected_catalog_record.get("desc",""))]
	if catalog_category == "아이템":
		UI.apply_item_visual(catalog_preview,selected_catalog_record,item_name,item_image_index.get("아이템",{}),"detail")
		if catalog_preview.get_meta("item_visual",{}).get("status","") == "self_authored_substitute":
			catalog_detail.text += "\n대체 아이콘 ◇"
	catalog_detail.text="[color=#%s]%s[/color]\n%s" % [UI.grade(grade_name).to_html(false),UI.safe(grade_name),catalog_detail.text]
	if catalog_category=="아이템":
		var owned := int(lineage_inventory_ui.inventory.get(item_name,0)) if lineage_inventory_ui!=null else 0
		catalog_detail.text+="\n보유 수량: %d" % owned
		if selected_catalog_record.has("grade_evidence"):
			catalog_detail.text+="\n등급 판정: 원본 이미지 파일명 기반 (검증 필요)"
		var variants: int = _catalog_variant_count(item_name)
		var pinned_id: String = _catalog_pinned_instance_id(selected_catalog_record) if variants > 1 else ""
		if variants > 1:
			catalog_detail.text+="\n동일 이름 %d종 · 원본 ID %s · 다른 ID와 구별" % [variants,selected_catalog_record.get("sourceId","")]
			if owned > 0 and pinned_id.is_empty():
				catalog_detail.text+="\n이 원본 ID로 지급한 장비 없음 · 이름만 같은 장비를 대신 장착하지 않습니다"
		catalog_equip_button.text="보유 아이템 장착 / 사용" if owned>0 else "미보유 · 조회 전용"
		catalog_equip_button.disabled=owned<=0 or (variants>1 and pinned_id.is_empty())
	else:
		var equipped: Dictionary = character_state.get("equipped",{}).get(catalog_category,{})
		var applied := str(equipped.get("name",""))==item_name
		catalog_equip_button.text="현재 적용 중" if applied else {"변신":"변신","마법인형":"소환","성물":"성물 적용"}.get(catalog_category,"적용")
		catalog_equip_button.disabled=applied
		catalog_detail.text += "\n\n현재 적용: "+UI.safe(equipped.get("name","없음"))

func _equip_selected_catalog() -> void:
	if selected_catalog_record.is_empty(): return
	if catalog_category=="아이템":
		var item_name := str(selected_catalog_record.get("name",""))
		if int(lineage_inventory_ui.inventory.get(item_name,0))>0:
			var variants: int = _catalog_variant_count(item_name)
			if variants > 1:
				var pinned_id: String = _catalog_pinned_instance_id(selected_catalog_record)
				if pinned_id != "":
					inventory_item_activated.emit(item_name + "@@@" + pinned_id)
			else:
				inventory_item_activated.emit(item_name)
	else:
		var category: String = catalog_category
		var record: Dictionary = selected_catalog_record.duplicate(true)
		confirm_action({"변신":"변신 확인","마법인형":"소환 확인","성물":"성물 적용"}.get(category,"적용 확인"),str(record.get("name",""))+"을(를) 적용하시겠습니까?","적용",func(_count: int) -> void:
			catalog_equip_requested.emit(category,record)
			if catalog_category == category and selected_catalog_record == record:
				catalog_equip_button.text="현재 적용 중"
				catalog_equip_button.disabled=true)

func toggle_map() -> void:
	if active_section=="map" and workspace.visible:
		_close_workspace()
		return
	_open_window("map","월드맵","지역을 선택하면 기존 이동 기능으로 해당 지역에 진입합니다.")
	var col: VBoxContainer=workspace.column()
	col.add_child(UI.label("WORLD OF ADEN",20,UI.GOLD))
	var row := HBoxContainer.new()
	row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var regions := VBoxContainer.new()
	regions.custom_minimum_size.x=270
	row.add_child(regions)
	var region_count: Label = UI.label("지역 선택  ·  %d개 지역" % map_records.size(),15)
	region_count.name = "RegionCount"
	regions.add_child(region_count)
	region_selection=ItemList.new()
	region_selection.name="RegionSelection"
	region_selection.size_flags_vertical=Control.SIZE_EXPAND_FILL
	regions.add_child(region_selection)
	for record: Dictionary in map_records:
		var index: int = region_selection.add_item(str(record.get("name",record.get("id",""))))
		region_selection.set_item_metadata(index,str(record.id))
	_add_original_map_controls(regions)
	var enter := UI.button("선택 지역으로 이동",func() -> void:
		var indices: PackedInt32Array=region_selection.get_selected_items()
		if not indices.is_empty(): map_selected.emit(str(region_selection.get_item_metadata(indices[0]))))
	enter.name="EnterRegion"
	regions.add_child(enter)
	for index: int in range(map_records.size()):
		if str(map_records[index].get("id",""))==str(get_parent().active_map_id): region_selection.select(index)
	if region_selection.get_selected_items().is_empty() and region_selection.item_count>0: region_selection.select(0)
	var map_view := RegionMapUI.new()
	map_view.name="RegionMap"
	map_view.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(map_view)
	map_view.configure(get_parent(),get_parent().field_map)
	col.add_child(UI.label("금색: NPC · 청록: 이동석 · 붉은색: 몬스터 · 십자: 내 위치",12,UI.MUTED))

func refresh_maps(value: Array) -> void:
	map_records=value.duplicate(true)
	super.refresh_maps(value)

func open_skills() -> void:
	_open_window("skills","스킬","")
	skills_view=SkillsUI.new()
	workspace.mount(skills_view)
	skills_view.configure(self)

func _open_quickslot_picker(entry_kind: String,entry_id: String,display_name: String) -> void:
	var reason: String = get_parent()._quickslot_registration_error(entry_kind,entry_id)
	if not reason.is_empty(): show_message(reason); return
	_open_window("quickbind","퀵슬롯 등록","")
	pending_quickslot_binding = {"kind":entry_kind,"id":entry_id}
	var column: VBoxContainer = workspace.column()
	column.add_child(UI.section(display_name,17))
	column.add_child(UI.section("하단 퀵슬롯 또는 아래 위치를 누르세요.\n페이지 버튼으로 등록할 페이지를 바꿀 수 있습니다.",13))
	quickslot_picker_hint = UI.label("",12,UI.GOLD)
	column.add_child(quickslot_picker_hint)
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for slot: int in range(5):
		for group: int in range(2):
			var visible_index: int = group*5+slot
			var button := UI.button(("왼쪽" if group == 0 else "오른쪽")+" %d" % (slot+1),func() -> void:
				_emit_quickslot_assignment(quickslot_index(visible_index),entry_kind,entry_id),Vector2(162,40))
			grid.add_child(button)
	column.add_child(UI.button("취소",_close_workspace))
	_render_quickslots(lineage_inventory_ui.inventory,{})

func _emit_quickslot_assignment(slot_index: int,entry_kind: String,entry_id: String) -> void:
	var reason: String = get_parent()._quickslot_registration_error(entry_kind,entry_id)
	if not reason.is_empty(): show_message(reason); return
	quickslot_assignment_requested.emit(slot_index,entry_kind,entry_id)
	_close_workspace()

func _open_enhance_chooser() -> void:
	_open_window("enhance","장비 강화","기존 인벤토리 주문서 · 실제 게임 강화 확률")
	var forge := ForgeUI.new()
	workspace.mount(forge)
	forge.configure_scrolls(self)

func open_enhancement(scroll_name: String, candidates: Array) -> void:
	enhancement_scroll_name = scroll_name
	enhancement_candidates = candidates.duplicate(true)
	_open_window("enhance","장비 강화",scroll_name+" · 실제 게임 강화 확률")
	var forge := ForgeUI.new()
	workspace.mount(forge)
	forge.configure_targets(self,scroll_name,candidates)

func _add_original_map_controls(regions: VBoxContainer) -> void:
	var original: Array = get_parent().original_maps
	if original.is_empty(): return
	var selector := OptionButton.new()
	selector.name = "MapEdition"
	selector.add_item("기존 TWILIGHT 지역")
	selector.add_item("우선 지역 · 아덴 / 오만 / 지배")
	selector.add_item("원본 통행 지역 · %d" % original.size())
	regions.add_child(selector)
	regions.move_child(selector,1)
	var search := LineEdit.new()
	search.name = "OriginalMapSearch"
	search.placeholder_text = "지역 이름 또는 원본 ID"
	regions.add_child(search)
	regions.move_child(search,2)
	var populate := func() -> void:
		region_selection.clear()
		var records: Array = map_records if selector.selected == 0 else original
		for record: Dictionary in records:
			var mid: int = int(record.get("source_map_id",-1))
			if selector.selected == 1 and mid != 4 and not (mid >= 101 and mid <= 111) and not (mid >= 12852 and mid <= 12862): continue
			var title: String = str(record.name)
			if mid == 4: title = "아덴 월드 · 본토"
			if mid >= 0: title += " [%d]" % mid
			if not search.text.is_empty() and not title.contains(search.text): continue
			var index: int = region_selection.add_item(title)
			region_selection.set_item_metadata(index,str(record.id))
			if str(record.id) == str(get_parent().active_map_id): region_selection.select(index)
		if region_selection.get_selected_items().is_empty() and region_selection.item_count > 0: region_selection.select(0)
		(regions.get_node("RegionCount") as Label).text = "지역 선택  ·  %d개 지역" % region_selection.item_count
	selector.item_selected.connect(func(_index: int) -> void: populate.call())
	search.text_changed.connect(func(_text: String) -> void: populate.call())
	if get_parent().field_map is OriginalPlayableField:
		selector.select(1)
		populate.call()
	regions.add_child(UI.label("본토: 자체 제작 타일 v1 · 기타: 이미지 미확보",11,UI.MUTED))
	regions.add_child(UI.label("NPC 서비스·본토 보스: TWILIGHT 임시 연결",11,UI.MUTED))
