extends "res://scripts/hud_v20.gd"

# ISOLATED PLAYTEST BUILD ONLY: remove these debug signals before production.
signal playtest_catalog_grant_requested(item_name: String, amount: int)
signal playtest_catalog_variant_grant_requested(source_id: String, amount: int)
signal playtest_aden_grant_requested
signal shop_bulk_buy_requested(item_name: String, quantity: int)
signal reviewed_shop_buy_requested(vendor_id: String, item_name: String, quantity: int)
signal warehouse_transfer_requested(item_name: String, quantity: int, direction: String, instance_id: String)
signal npc_teleport_requested(map_id: String)
signal craft_requested(recipe_id: String, batch: int)
signal shop_sell_requested(item_name: String, quantity: int, instance_id: String)
signal npc_dialogue_action_requested(npc_id: String, node_id: String, action: String)
signal quickslot_edit_requested(index: int, action: String, other: int)
signal equipment_unequip_requested(reference: String)
signal item_lock_requested(reference: String)
signal pickup_requested

const MENU = preload("res://scripts/ui/menu_registry.gd")
const Router = preload("res://scripts/ui/menu_router.gd")
const QuickController = preload("res://scripts/ui/quickslot_controller.gd")
const SlotButton = preload("res://scripts/ui/quickslot_button.gd")
const DialogUI = preload("res://scripts/ui/renewal_dialog.gd")
const SafeArea = preload("res://scripts/ui/safe_area.gd")
var router := Router.new()
var quick_controller := QuickController.new()
var opening_window: bool = false
var window_backdrop: ColorRect
var modal: Control
var page_buttons: Array[Button] = []
var menu_group: int = 0
var tracker_party: bool = false
var tracker_collapsed: bool = false
var tracker_body: VBoxContainer
var tracker_party_label: Label
var buff_expanded: bool = true
var buff_detail: RichTextLabel
var move_readout: Label
var chat_messages: Array[String] = []
var quick_picker_kind: String = ""
var quick_picker_id: String = ""
var selected_quickslot: int = 0

# UI-only adapter: existing HUD signals remain the sole write interface.
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
const QuestUI = preload("res://scripts/ui/renewal_quest.gd")
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
var quest_view: Control
var class_picker_initial: bool = false
var class_picker_backdrop: ColorRect
var minimap_mounted: bool = false
var cooldown_shades: Array[ColorRect] = []
var catalog_test_tools: VBoxContainer
var catalog_test_toggle: Button
var catalog_clear_button: Button

func _build_v20_status() -> void:
	super._build_v20_status()
	var panel: PanelContainer = v20_layer.get_node("StatusPanel")
	_place(panel,10,8,337,97)
	var content: Control = panel.get_child(0)
	content.custom_minimum_size = Vector2(327,89)
	_place(content.get_child(0),6,5,70,72)
	_place(content.get_node("CharacterShortcut"),6,5,70,72)
	_place(v20_level_badge,58,56,86,80)
	_place(v20_status_name,78,3,318,24)
	v20_status_name.add_theme_font_size_override("font_size",13)
	_place(hp_bar,78,26,318,42)
	_place(v20_hp_text,78,25,318,43)
	_place(mp_bar,78,46,318,62)
	_place(v20_mp_text,78,45,318,63)
	_place(v20_stat_text,78,66,318,85)
	v20_stat_text.add_theme_font_size_override("font_size",11)
	for child: Node in v20_layer.get_children():
		if child is Button and is_equal_approx(child.position.x,380.0):
			_place(child,348,8,397,65)
		elif child is Button and is_equal_approx(child.position.x,442.0):
			_place(child,403,8,452,65)
	_place(v20_potion_count,348,47,396,69)
	_place(v20_leaf_count,403,47,451,69)

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
	window_backdrop = ColorRect.new()
	window_backdrop.name = "MenuBackdrop"
	window_backdrop.color = Color(0,0,0,.18)
	window_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window_backdrop.offset_bottom = -88
	window_backdrop.z_index = 140
	window_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	window_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_close_workspace()
			get_viewport().set_input_as_handled())
	$Root.add_child(window_backdrop)
	window_backdrop.hide()
	workspace.navigate.connect(_navigate)
	workspace.back_requested.connect(go_back)
	workspace.visibility_changed.connect(_sync_input_block)
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
	var preferences := ConfigFile.new()
	if preferences.load(SettingsUI.SETTINGS_PATH) == OK:
		tracker_collapsed = bool(preferences.get_value("interface", "tracker_collapsed", false))
		_refresh_tracker()
		buff_expanded = bool(preferences.get_value("interface", "buff_expanded", true))
		buff_row.visible = buff_expanded
	_build_integration_shortcuts()

func _polish_hud_chrome() -> void:
	# The old canvas still owns all HP, MP, combat and touch signals.
	# Restrict the pass to StyleBoxes; never duplicate gameplay state.
	var status: PanelContainer = v20_layer.get_node_or_null("StatusPanel") as PanelContainer
	if status != null:
		status.add_theme_stylebox_override("panel",UI.chrome_panel(Color(.028,.029,.034,.89),UI.BRONZE,0))
	var mini_map: PanelContainer = v20_layer.get_node_or_null("QuestTracker") as PanelContainer
	if mini_map != null:
		mini_map.add_theme_stylebox_override("panel",UI.chrome_panel(Color(.024,.024,.028,.87),UI.BRONZE,7))
	if v20_target_panel != null:
		v20_target_panel.add_theme_stylebox_override("panel",UI.chrome_panel(Color(.045,.024,.025,.88),Color("9d6751"),5))
		_place(v20_target_panel,468,86,812,136)
		v20_target_panel.set_meta("renewal_base_position",v20_target_panel.position)
	if v20_map_name != null:
		v20_map_name.add_theme_color_override("font_color",UI.GOLD)
		_place(v20_map_name.get_parent(),468,46,932,72)
		v20_map_name.get_parent().set_meta("renewal_base_position",v20_map_name.get_parent().position)
		v20_map_name.add_theme_font_size_override("font_size",11)
		v20_map_name.clip_text = true

func _build_lineage_inventory_ui() -> void:
	lineage_inventory_ui = Inventory.new() as TwilightInventoryUI
	lineage_inventory_ui.name = "LineageInventoryUI"
	lineage_inventory_ui.item_activate_requested.connect(func(item_name: String) -> void: inventory_item_activated.emit(item_name))
	lineage_inventory_ui.quickslot_requested.connect(_register_inventory_quickslot)
	lineage_inventory_ui.connect("unequip_requested", func(reference: String) -> void: equipment_unequip_requested.emit(reference))
	lineage_inventory_ui.connect("lock_requested", func(reference: String) -> void: item_lock_requested.emit(reference))
	$Root.add_child(lineage_inventory_ui)
	lineage_inventory_ui.set_catalog_data(catalog_data,item_image_index)
	lineage_inventory_ui.set_character_state(character_state)

func _build_lineage_side_ui() -> void:
	lineage_side_ui=CharacterUI.new() as TwilightSideUI
	lineage_side_ui.name="LineageSideUI"
	lineage_side_ui.action_requested.connect(_on_lineage_side_action)
	lineage_side_ui.stat_increase_requested.connect(func(value: String) -> void: stat_increase_requested.emit(value))
	lineage_side_ui.connect("class_selection_requested",func() -> void: open_class_selection())
	lineage_side_ui.equipment_requested.connect(func(item: String) -> void:
		if active_section=="inventory": _close_workspace()
		toggle_inventory()
		lineage_inventory_ui._select_item(item))
	$Root.add_child(lineage_side_ui)
	lineage_side_ui.set_character_state(character_state)

func set_character_state(value: Dictionary) -> void:
	super.set_character_state(value)
	if is_instance_valid(quest_view):
		quest_view.call("refresh", value)
	# hud_v20 already forwards this authoritative snapshot to both adapters.

func _panel_style(alpha: float = .9, radius: int = 3, border: Color = UI.BRONZE) -> StyleBoxFlat:
	var s := UI.box(Color(.035,.045,.055,alpha),border,7)
	s.set_corner_radius_all(radius)
	return s

func _build_v20_buffs() -> void:
	buff_row = HBoxContainer.new()
	buff_row.name = "ActiveEffects"
	buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(buff_row,12,102,430,146)
	v20_layer.add_child(buff_row)

func _build_v20_quest() -> void:
	var panel := PanelContainer.new()
	panel.name = "QuestTracker"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel,12,171,298,291)
	panel.add_theme_stylebox_override("panel",_panel_style(.82))
	v20_layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",4)
	panel.add_child(v)
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	for pair: Array in [["퀘스트",false],["파티",true]]:
		var party_tab: bool = pair[1]
		var tab := UI.button(pair[0],func() -> void:
			tracker_party = party_tab
			_refresh_tracker(),Vector2(85,32))
		tab.name = "TrackerParty" if party_tab else "TrackerQuest"
		tabs.add_child(tab)
	var collapse := UI.button("접기",func() -> void:
		tracker_collapsed = not tracker_collapsed
		_refresh_tracker()
		_store_preference("tracker_collapsed", tracker_collapsed),Vector2(60,32))
	collapse.name = "TrackerCollapse"
	tabs.add_child(collapse)
	tracker_body = VBoxContainer.new()
	tracker_body.add_theme_constant_override("separation",4)
	v.add_child(tracker_body)
	var quest := UI.button("몬스터의 세력 다툼  ›",open_quest_info,Vector2(0,32))
	quest.name = "TrackedQuest"
	tracker_body.add_child(quest)
	for button: Button in tabs.get_children()+[quest]:
		button.add_theme_font_size_override("font_size",12)
		for state: String in ["normal","hover","pressed","focus"]:
			button.add_theme_stylebox_override(state,UI.box(Color("17171b"),UI.BRONZE,4))
	v20_quest_text = UI.rich("")
	v20_quest_text.fit_content = false
	v20_quest_text.custom_minimum_size.y = 32
	v20_quest_text.add_theme_font_size_override("normal_font_size",12)
	v20_quest_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker_body.add_child(v20_quest_text)
	tracker_party_label = UI.label("로컬 플레이 · 파티 미지원",12,UI.MUTED)
	tracker_body.add_child(tracker_party_label)
	_refresh_tracker()

func _build_v20_top_menu() -> void:
	var panel := PanelContainer.new()
	panel.name = "MainShortcuts"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel,943,9,1268,78)
	panel.add_theme_stylebox_override("panel",_panel_style(.9))
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
		b.add_theme_stylebox_override("normal",UI.slot_frame())
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
	var panel := PanelContainer.new()
	panel.name = "Quickslots"
	panel.add_theme_stylebox_override("panel",UI.box(Color(0,0,0,0),Color(0,0,0,0),0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel,350,638,1268,712)
	v20_layer.add_child(panel)
	v20_skill_container = HBoxContainer.new()
	v20_skill_container.add_theme_constant_override("separation",5)
	v20_skill_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v20_skill_container)
	for index: int in range(8):
		if index == 4:
			var gap := Control.new()
			gap.name = "QuickBankGap"
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v20_skill_container.add_child(gap)
		if index % 4 == 0:
			var bank: int = index / 4
			var page := UI.button("",_change_quick_page.bind(bank,1),Vector2(36,58))
			page.name = "QuickPage_%d" % bank
			page.add_theme_font_size_override("font_size",11)
			page.tooltip_text = "그룹 전환 · 좌우 각각 3페이지"
			v20_skill_container.add_child(page)
			page_buttons.append(page)
		var b := SlotButton.new()
		b.custom_minimum_size = Vector2(74,58)
		b.activated.connect(_activate_visible_slot.bind(index))
		b.edit_requested.connect(func() -> void: _open_slot_editor(quick_controller.index_for(index)))
		b.auto_requested.connect(func() -> void: quickslot_edit_requested.emit(quick_controller.index_for(index),"auto",-1))
		b.page_requested.connect(func(direction: int) -> void: _change_quick_page(index / 4,direction))
		b.entry_dropped.connect(func(data: Dictionary) -> void: _drop_quickslot(quick_controller.index_for(index),data))
		b.name = "Quickslot_%d" % index
		b.add_theme_font_size_override("font_size",10)
		b.add_theme_constant_override("icon_max_width",24)
		b.add_theme_stylebox_override("normal",UI.slot_frame())
		b.add_theme_stylebox_override("hover",UI.slot_frame(UI.GOLD,true))
		b.add_theme_stylebox_override("pressed",UI.slot_frame(UI.GOLD,true))
		v20_skill_container.add_child(b)
		v20_quickslot_buttons.append(b)
		var icon := TextureRect.new()
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position=Vector2(13,4)
		icon.size=Vector2(50,44)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		quickslot_icons.append(icon)
		var caption := UI.label("",10)
		caption.position=Vector2(4,46)
		caption.size=Vector2(68,18)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(caption)
		quickslot_captions.append(caption)
		var number := UI.label(str(index+1),10,UI.MUTED)
		number.position=Vector2(5,2)
		b.add_child(number)
		var badge := UI.label("",9,UI.GOLD)
		badge.position=Vector2(42,1)
		b.add_child(badge)
		quickslot_auto_badges.append(badge)
		var shade := ColorRect.new()
		shade.color = Color(0,0,0,.68)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.hide()
		b.add_child(shade)
		cooldown_shades.append(shade)
		var cooldown := UI.label("",14,Color.WHITE)
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cooldown.add_theme_color_override("font_outline_color",Color.BLACK)
		cooldown.add_theme_constant_override("outline_size",3)
		b.add_child(cooldown)
		quickslot_cooldown_labels.append(cooldown)
	exp_readout = UI.label("EXP",12,UI.GOLD)
	_place(exp_readout,12,686,314,710)
	v20_layer.add_child(exp_readout)
	exp_bar = ProgressBar.new()
	exp_bar.show_percentage = false
	exp_bar.add_theme_stylebox_override("background",_bar_background())
	exp_bar.add_theme_stylebox_override("fill",_bar_fill(UI.GOLD))
	exp_bar.name = "ExperienceGauge"
	_place(exp_bar,0,715,1280,720)
	v20_layer.add_child(exp_bar)
	var sys := HBoxContainer.new()
	_place(sys,12,638,330,679)
	v20_layer.add_child(sys)
	for pair: Array in [["chat","채팅"],["quickslots","슬롯 설정"],["settings","설정"]]:
		var system_button := UI.button(str(pair[1]),_navigate.bind(str(pair[0])),Vector2(92,36))
		system_button.icon = UI.icon(str(pair[0]))
		system_button.add_theme_constant_override("icon_max_width",16)
		system_button.add_theme_font_size_override("font_size",11)
		sys.add_child(system_button)
	currency_readout = UI.label("아데나  0",14,UI.GOLD)
	_place(currency_readout,468,12,748,40)
	v20_layer.add_child(currency_readout)
	coordinates_readout = UI.label("",11,UI.MUTED)
	_place(coordinates_readout,1038,277,1268,298)
	coordinates_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v20_layer.add_child(coordinates_readout)
	var home := UI.button("귀환",func() -> void: return_pressed.emit(),Vector2(88,44))
	home.name = "ReturnToSpawn"
	home.icon = UI.icon("return")
	_place(home,1080,649,1268,704)
	v20_layer.add_child(home)

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
	var available: Rect2 = SafeArea.available(get_viewport())
	var view: Vector2 = available.size
	var factor: float = minf(view.x/1280.0,view.y/720.0)
	var logical: Vector2 = view/maxf(.01,factor)
	v20_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	v20_layer.position = available.position
	v20_layer.size = logical
	v20_layer.scale = Vector2.ONE*factor
	var controls: Control = $Root/RightControls
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls.position = available.position
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
		elif control.name == "Quickslots":
			control.position.x += extra_x * .5
			control.size.x = 918 + extra_x * .5
		elif control == v20_target_panel:
			control.position.x += extra_x*.5
	exp_bar.size.x = logical.x
	joystick.scale = Vector2.ONE*factor
	joystick.set_anchors_preset(Control.PRESET_TOP_LEFT)
	joystick.position = available.position+Vector2(20,logical.y-244)*factor
	joystick.size = Vector2(160,160)
	_fit_tracker()
	if workspace != null: workspace.fit_viewport()

func _process(delta: float) -> void:
	super._process(delta)
	if not minimap_mounted:
		var minimap: Control = $Root.get_node_or_null("FieldMinimap")
		if minimap != null:
			minimap.reparent(v20_layer)
			_place(minimap,1042,86,1264,277)
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
	_render_quickslots(lineage_inventory_ui.inventory,world._combined_active_buffs())
	if move_readout != null:
		move_readout.text = "이동 중" if actor != null and actor.velocity.length() > 1 else "대기"
	if buff_detail != null and is_instance_valid(buff_detail) and buff_detail.is_visible_in_tree(): _refresh_buff_detail()
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
		var b := UI.button("",_open_buffs,Vector2(36,42))
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

func _render_quickslots(inventory: Dictionary,buffs: Dictionary) -> void:
	var world: Node = get_parent()
	if lineage_inventory_ui == null or world == null: return
	for bank: int in range(page_buttons.size()):
		page_buttons[bank].text = "%s\n%d/3" % ["L" if bank == 0 else "R",quick_controller.pages[bank]+1]
	for visible_index: int in range(quickslot_icons.size()):
		var index: int = quick_controller.index_for(visible_index)
		var button: Button = v20_quickslot_buttons[visible_index]
		var entry: Dictionary = quickslot_entries[index] if index < quickslot_entries.size() and quickslot_entries[index] is Dictionary else {}
		button.icon = null
		button.text = ""
		button.set("payload", {"kind":"slot","index":index,"id":entry.get("id","")} if not entry.is_empty() else {})
		quickslot_icons[visible_index].texture = null
		quickslot_captions[visible_index].text = "비어 있음"
		quickslot_auto_badges[visible_index].text = ""
		quickslot_cooldown_labels[visible_index].text = ""
		cooldown_shades[visible_index].hide()
		button.tooltip_text = QuickController.label_for(index)+" · 우클릭/길게 누르기: 편집"
		if entry.is_empty(): continue
		var id := str(entry.get("id",""))
		var is_item: bool = entry.get("kind") == "item"
		var skill: Dictionary = world._skill_record(id) if not is_item else {}
		var remain: float = float(world.item_use_cooldowns.get(id,0)) if is_item else float(world.skill_cooldowns.get(id,0))
		var unavailable := ""
		if is_item:
			quickslot_icons[visible_index].texture = UI.item_icon(lineage_inventory_ui._find_item_record(id),id,item_image_index.get("아이템",{}))
			quickslot_captions[visible_index].text = id.left(3)+" ×%d" % int(inventory.get(id,0))
			if int(inventory.get(id,0)) <= 0: unavailable = "없음"
		elif not skill.is_empty():
			quickslot_icons[visible_index].texture = _skill_icon(str(skill.get("effect","")),str(skill.get("type","")))
			quickslot_captions[visible_index].text = id.left(6)
			if int(character_state.get("mp",0)) < int(skill.get("mp",0)): unavailable = "MP 부족"
			if not world._skill_owned_for_current_job(skill): unavailable = "사용 불가"
		else: unavailable = "사용 불가"
		quickslot_auto_badges[visible_index].text = "AUTO" if bool(entry.get("auto",false)) else ("효과" if buffs.has(id) else "")
		quickslot_cooldown_labels[visible_index].text = "%.1f" % remain if remain > 0 else unavailable
		var duration: float = maxf(remain,1.0) if is_item else maxf(0.01,preload("res://scripts/skill_rules.gd").cooldown_seconds(skill))
		cooldown_shades[visible_index].anchor_top = 0.0 if unavailable != "" else 1.0-clampf(remain/duration,0,1)
		cooldown_shades[visible_index].offset_top = 0
		cooldown_shades[visible_index].visible = remain > 0 or unavailable != ""
		button.tooltip_text += "\n"+id+(" · 자동 ON" if bool(entry.get("auto",false)) else " · 자동 OFF")
		if not skill.is_empty(): button.tooltip_text += " · MP %d · 스킬 레벨 데이터 없음" % int(skill.get("mp",0))

func append_log(value: String) -> void:
	log_history.append(value)
	if log_history.size()>120:
		log_history.pop_front()
	super.append_log(value)
	if active_section == "chat" and workspace != null and workspace.visible:
		var channel: OptionButton = workspace.content.find_child("ChatChannel",true,false) as OptionButton
		var history: RichTextLabel = workspace.content.find_child("ChatHistory",true,false) as RichTextLabel
		if channel != null and history != null and channel.selected == 1:
			history.text = "\n".join(log_history)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		go_back()
		get_viewport().set_input_as_handled()
		return
	if blocks_keyboard_input(): return
	if event.keycode >= KEY_1 and event.keycode <= KEY_8:
		_activate_visible_slot(event.keycode-KEY_1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_BRACKETLEFT: _change_quick_page(0,1)
	elif event.keycode == KEY_BRACKETRIGHT: _change_quick_page(1,1)
	elif event.keycode == KEY_K: open_skills()
	elif event.keycode == KEY_C: open_character()
	elif event.keycode == KEY_ENTER: _open_chat()
	elif event.keycode == KEY_F: pickup_requested.emit()

func _close_workspace() -> void:
	if class_picker_initial:
		return
	if workspace != null:
		router.capture(active_section, workspace.content)
		workspace.hide()
	if window_backdrop != null: window_backdrop.hide()
	if not opening_window: router.clear()
	active_section = ""
	_sync_input_block()
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
	router.enter(active_section, section)
	opening_window = true
	_hide_aux_panels()
	opening_window = false
	_park_shared_panels()
	workspace.clear()
	workspace.open(section,title,description)
	active_section = section
	window_backdrop.show()
	# Godot GUI hit testing follows tree order, not CanvasItem.z_index.
	workspace.move_to_front()
	_sync_input_block()
	call_deferred("_restore_window_state", section)

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
		"quest": open_quest_info()
		"map": toggle_map()
		"menu": toggle_menu()
		"settings": open_settings_info()
		"auto": open_macro_info()
		"log": open_chat_info()
		"chat": _open_chat()
		"quickslots": _open_quickslot_settings()
		"teleport": open_npc_teleport()
		"crafting": open_crafting()
		"warehouse": open_warehouse()
		"sell": open_item_sell()
		"dungeon", "special_dungeon": _open_dungeons(section)
		"party", "clan", "friends", "mail", "ranking", "events", "exchange", "collection", "growth": _open_capability(section)
		"controls", "info": _open_information(section)
		"buffs": _open_buffs()
		"exit": _confirm_exit()
		"enhance": _open_enhance_chooser()
		"변신", "마법인형", "성물", "아이템": open_catalog(section)
		_: _open_capability(section)

func open_shop() -> void:
	_open_window("shop","잡화 상점","보유 아데나 · 아이템 검색 · 구매")
	var shop := ShopUI.new()
	workspace.mount(shop)
	shop.configure(self)

func open_warehouse() -> void:
	_open_window("warehouse","창고지기","아이템 보관/찾기 · 개별 강화 상태 보존")
	var screen := WarehouseUI.new()
	workspace.mount(screen)
	screen.configure(self)

func open_npc_teleport(destination: String = "") -> void:
	_open_window("teleport","텔레포트 안내인","기존 25개 맵으로 이동 · 기존 충돌/좌표 보존")
	var screen := TeleportUI.new()
	workspace.mount(screen)
	screen.configure(self,destination)

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

func open_npc_dialogue(npc_id: String) -> void:
	_open_window("dialogue","NPC 대화","레벨 · 직업 · 퀘스트 · 아이템 보유 분기")
	var screen := DialogueUI.new()
	workspace.mount(screen)
	screen.configure(self,npc_id)

func open_quest_info() -> void:
	_open_window("quest","퀘스트","기존 게임의 사냥 퀘스트 진행도")
	quest_view = QuestUI.new()
	workspace.mount(quest_view)
	quest_view.call("configure",self)

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

func open_chat_info() -> void:
	_open_window("log","전투 기록","오프라인 시스템 · 최근 120건")
	var col: VBoxContainer = workspace.column()
	col.add_child(UI.label("전투 / 시스템 로그",21,UI.GOLD))
	var history := UI.rich("")
	history.fit_content = false
	history.scroll_active = true
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.text = "\n".join(log_history) if not log_history.is_empty() else "아직 기록이 없습니다."
	col.add_child(history)

func toggle_inventory() -> void:
	if active_section=="inventory" and workspace.visible:
		_close_workspace()
		return
	_open_window("inventory","인벤토리","아이템 선택 · 상세 옵션 · 장착 · 사용 · 퀵슬롯 등록")
	workspace.mount(lineage_inventory_ui)
	lineage_inventory_ui.show()
	lineage_inventory_ui.show_inventory()

func open_character() -> void:
	_open_window("character","캐릭터 · 장비","현재 능력치와 착용 장비 · 남은 포인트로 능력치 증가")
	var panel: PanelContainer = lineage_side_ui.character_panel
	if workspace.content.size.y < 460 or workspace.content.size.x < 630:
		var scroll := ScrollContainer.new()
		scroll.name = "CharacterCompactScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		workspace.mount(scroll)
		panel.reparent(scroll)
		panel.custom_minimum_size = Vector2(0,490)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		panel.custom_minimum_size = Vector2.ZERO
		workspace.mount(panel)
	panel.show()
	lineage_side_ui.show_character(character_state)

func toggle_menu() -> void:
	if active_section == "menu" and workspace.visible:
		_close_workspace()
		return
	_open_window("menu","전체 메뉴","캐릭터 · 게임 플레이 · 커뮤니티 · 시스템")
	var col: VBoxContainer = workspace.column()
	var tabs := HBoxContainer.new()
	col.add_child(tabs)
	for group: int in MENU.GROUPS.size():
		var tab := UI.button(MENU.GROUPS[group],func() -> void:
			menu_group = group
			active_section = ""
			toggle_menu(),Vector2(112,40))
		tab.name = "MenuGroup_%d" % group
		tab.toggle_mode = true
		tab.button_pressed = menu_group == group
		tabs.add_child(tab)
	var menu_scroll := ScrollContainer.new()
	menu_scroll.name = "MenuContentScroll"
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(menu_scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(grid)
	menu_scroll.resized.connect(func() -> void: grid.columns = clampi(floori(menu_scroll.size.x/118.0),2,4))
	for record: Array in MENU.ENTRIES:
		if int(record[2]) != menu_group: continue
		var id := str(record[0])
		var title := str(record[1])
		var button := UI.button(title+("\n미지원" if record[3] == "unavailable" else ""),func() -> void:
			if not workspace.was_scroll_dragged(menu_scroll): _navigate(id),Vector2(116,86))
		button.name = "MenuTile_"+id
		button.add_theme_font_size_override("font_size",12)
		button.icon = UI.icon(id)
		button.add_theme_constant_override("icon_max_width",28)
		grid.add_child(button)
		workspace.register_scroll_drag(menu_scroll,button)

func _open_utility_panel(title: String) -> void:
	var section := "utility"
	if title.contains("상점"): section="shop"
	elif title.contains("스킬"): section="skills"
	elif title.contains("퀘스트"): section="quest"
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
	_open_window(category,category+" 도감","등급 · 이름으로 검색 / 로컬 도감 데이터")
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
	collection_status.text = "아이콘 오른쪽 드래그로 장착/사용 · 보유 아이템만 적용" if category=="아이템" else "아이콘을 오른쪽으로 끌면 적용 · 선택 후 장착 버튼도 사용 가능"
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
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var left := VBoxContainer.new()
	catalog_body_left = left
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	catalog_list.reparent(left)
	catalog_list.custom_minimum_size = Vector2(530,0)
	catalog_list.max_columns = 4
	catalog_list.fixed_column_width = 126
	catalog_list.fixed_icon_size = Vector2i(78,78)
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
	right_scroll.custom_minimum_size.x = 315
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 300
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	catalog_preview.reparent(right)
	catalog_preview.custom_minimum_size = Vector2(0,190)
	catalog_detail.reparent(right)
	catalog_detail.custom_minimum_size = Vector2(0,0)
	catalog_detail.fit_content = true
	catalog_detail.scroll_active = false
	catalog_detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	catalog_detail.add_theme_font_size_override("normal_font_size",14)
	catalog_equip_button.reparent(right)
	catalog_equip_button.name = "ApplyCatalog"
	catalog_clear_button = UI.button("현재 적용 해제",func() -> void:
		if catalog_category != "아이템": catalog_equip_requested.emit(catalog_category,{}))
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
	var can_apply: bool = catalog_drag_ready and (delta.x >= 96.0 and delta.x > absf(delta.y) * 1.15 or _inside_catalog_control(catalog_equip_button, point))
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
	if workspace == null or catalog_body_left == null or catalog_body_actions == null:
		return
	# A fixed 530px grid + 315px preview used to spill outside portrait/small
	# windows. On narrow viewports show either full-width grid or full-width detail.
	var compact: bool = get_window().size.x < 1180 or workspace.content.size.x < 840
	var short: bool = workspace.content.size.y < 430
	collection_status.visible = not short
	catalog_count.visible = not short
	catalog_preview.custom_minimum_size.y = 120 if short else 190
	catalog_list.fixed_icon_size = Vector2i(60,60) if short else Vector2i(78,78)
	catalog_list.add_theme_constant_override("v_separation",8 if short else 12)
	catalog_search.custom_minimum_size.y = 32 if short else 40
	var pager: HBoxContainer = catalog_page_label.get_parent()
	pager.custom_minimum_size.y = 28 if short else 40
	for button: Control in [catalog_first_button,catalog_prev_button,catalog_next_button,catalog_last_button]:
		button.custom_minimum_size.y = 28 if short else 34
	catalog_page_label.custom_minimum_size.y = 28 if short else 34
	catalog_list_tab.custom_minimum_size.y = 28 if short else 34
	catalog_details_tab.custom_minimum_size.y = 28 if short else 34
	catalog_view_tabs.visible = compact and active_section in ["아이템", "변신", "마법인형", "성물"]
	catalog_body_left.visible = not compact or not catalog_details_active
	catalog_body_actions.visible = not compact or catalog_details_active
	catalog_list.custom_minimum_size.x = 0.0 if compact else 530.0
	catalog_list.max_columns = 2 if compact else 4
	catalog_list.fixed_column_width = 115 if compact else 126
	catalog_body_actions.custom_minimum_size.x = 0.0 if compact else 315.0
	var actions_content: Control = catalog_body_actions.get_child(0) as Control
	if actions_content != null:
		actions_content.custom_minimum_size.x = 0.0 if compact else 300.0
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
	super._on_catalog_item_selected(index)
	if selected_catalog_record.is_empty():
		if playtest_grant_button != null: playtest_grant_button.disabled = true
		return
	if playtest_grant_button != null:
		playtest_grant_button.disabled = catalog_category != "아이템"
	var item_name := str(selected_catalog_record.get("name",""))
	var grade_name := str(selected_catalog_record.get("grade","일반"))
	if catalog_category == "아이템":
		var selected_texture: Texture2D = UI.item_icon(selected_catalog_record, item_name, item_image_index.get("아이템", {}))
		if selected_texture != null:
			catalog_preview.texture = selected_texture
	catalog_detail.text="[color=#%s]%s[/color]\n%s" % [UI.grade(grade_name).to_html(false),UI.safe(grade_name),catalog_detail.text]
	if catalog_category=="아이템":
		var owned := int(lineage_inventory_ui.inventory.get(item_name,0)) if lineage_inventory_ui!=null else 0
		catalog_detail.text+="\n보유 수량: %d\n테스트 지급 버튼으로 임시 획득 가능" % owned
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
		catalog_equip_button.text="현재 적용 중" if applied else "로컬 적용"
		catalog_equip_button.disabled=applied

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
		catalog_equip_requested.emit(catalog_category,selected_catalog_record.duplicate(true))
		catalog_equip_button.text="현재 적용 중"
		catalog_equip_button.disabled=true

func toggle_map() -> void:
	if active_section == "map" and workspace.visible:
		_close_workspace()
		return
	_open_window("map","월드맵","현재 지역 상세 지도 · 지역 검색과 이동")
	var col: VBoxContainer = workspace.column()
	col.add_child(UI.label("WORLD OF ADEN",20,UI.GOLD))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var regions := VBoxContainer.new()
	regions.custom_minimum_size.x = 270
	row.add_child(regions)
	var search := LineEdit.new()
	search.name = "RegionSearch"
	search.placeholder_text = "지역 이름 검색"
	regions.add_child(search)
	region_selection = ItemList.new()
	region_selection.name = "RegionSelection"
	region_selection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	regions.add_child(region_selection)
	var detail := UI.label("",12,UI.MUTED)
	detail.name = "RegionDetails"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regions.add_child(detail)
	var enter := UI.button("선택 지역으로 이동",func() -> void:
		var indices: PackedInt32Array = region_selection.get_selected_items()
		if not indices.is_empty(): map_selected.emit(str(region_selection.get_item_metadata(indices[0]))))
	enter.name = "EnterRegion"
	regions.add_child(enter)
	region_selection.item_selected.connect(func(index: int) -> void:
		var id := str(region_selection.get_item_metadata(index))
		var record: Dictionary = get_parent().maps_by_id.get(id,{})
		var blocked: bool = get_parent().player.is_stunned() or get_parent().player.is_feared() or get_parent().player.is_held()
		detail.text = str(record.get("name",id))+"\n"+("현재 지역" if id == str(get_parent().active_map_id) else "로컬 월드맵 이동 가능")
		if blocked: detail.text += "\n현재 상태에서는 이동 불가"
		enter.disabled = record.is_empty() or blocked)
	search.text_changed.connect(func(query: String) -> void:
		region_selection.clear()
		for record: Dictionary in map_records:
			var id := str(record.get("id",""))
			var title := str(record.get("name",id))
			if query != "" and not title.to_lower().contains(query.to_lower()): continue
			var index: int = region_selection.add_item(title)
			region_selection.set_item_metadata(index,id)
			if id == str(get_parent().active_map_id): region_selection.select(index)
		if region_selection.item_count > 0:
			if region_selection.get_selected_items().is_empty(): region_selection.select(0)
			region_selection.item_selected.emit(region_selection.get_selected_items()[0])
		else:
			enter.disabled = true
			detail.text = "검색 결과가 없습니다")
	search.text_changed.emit("")
	var map_view := RegionMapUI.new()
	map_view.name = "RegionMap"
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(map_view)
	map_view.configure(get_parent(),get_parent().field_map)
	col.add_child(UI.label("금색: NPC · 청록: 이동석 · 붉은색: 몬스터 · 십자: 내 위치",12,UI.MUTED))

func refresh_maps(value: Array) -> void:
	map_records=value.duplicate(true)
	super.refresh_maps(value)

func open_skills() -> void:
	_open_window("skills","스킬 · 성장","직업별 스킬 · 패시브 · 퀵슬롯 · 자동사용")
	skills_view=SkillsUI.new()
	workspace.mount(skills_view)
	skills_view.configure(self)

func _emit_quickslot_assignment(slot_index: int,entry_kind: String,entry_id: String) -> void:
	quickslot_assignment_requested.emit(slot_index,entry_kind,entry_id)
	if slot_index < quickslot_entries.size() and str(quickslot_entries[slot_index].get("id","")) == entry_id:
		show_message(QuickController.label_for(slot_index)+" 등록 완료")
		go_back()

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

func blocks_world_input() -> bool:
	return class_picker_initial or (workspace != null and workspace.visible) or is_instance_valid(modal)

func blocks_keyboard_input() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return blocks_world_input() or focus is LineEdit or focus is TextEdit

func _sync_input_block() -> void:
	var actor: Node = get_parent().get_node_or_null("Player")
	if actor != null:
		actor.set("interface_input_blocked", blocks_keyboard_input())
		if blocks_world_input():
			joystick._release_pointer()
			if not actor.auto_enabled: actor.clear_click_path()

func _restore_window_state(section: String) -> void:
	if section == active_section and workspace.visible:
		router.restore(section,workspace.content)

func go_back() -> void:
	if class_picker_initial: return
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
		_sync_input_block()
		return
	var previous: String = router.previous()
	if previous == "":
		_close_workspace()
		return
	router.returning = true
	_navigate(previous)
	router.returning = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: go_back()

func confirm_action(title: String, message: String, action: Callable) -> void:
	if is_instance_valid(modal): return
	modal = DialogUI.new()
	modal.title_text = title
	modal.message_text = message
	$Root.add_child(modal)
	if action.is_valid(): modal.confirmed.connect(action)
	modal.tree_exited.connect(func() -> void: modal = null; _sync_input_block())
	_sync_input_block()

func _store_preference(key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SettingsUI.SETTINGS_PATH)
	cfg.set_value("interface",key,value)
	if cfg.save(SettingsUI.SETTINGS_PATH) != OK: show_message("UI 설정 저장 실패")

func _refresh_tracker() -> void:
	if tracker_body == null: return
	tracker_body.visible = not tracker_collapsed
	tracker_body.get_node("TrackedQuest").visible = not tracker_party
	v20_quest_text.visible = not tracker_party
	tracker_party_label.visible = tracker_party
	call_deferred("_fit_tracker")

func _fit_tracker() -> void:
	var tracker: Control = v20_layer.get_node_or_null("QuestTracker")
	if tracker != null: tracker.size.y = 46 if tracker_collapsed else 120

func _build_integration_shortcuts() -> void:
	var services := HBoxContainer.new()
	services.name = "ServiceShortcuts"
	_place(services,764,8,928,50)
	v20_layer.add_child(services)
	for pair: Array in [["crafting","제작"],["mail","우편"],["events","알림"]]:
		var b := UI.button(pair[1],_navigate.bind(pair[0]),Vector2(50,36))
		b.add_theme_font_size_override("font_size",11)
		services.add_child(b)
	var buff_toggle := UI.button("효과",func() -> void:
		buff_expanded = not buff_expanded
		buff_row.visible = buff_expanded
		_store_preference("buff_expanded",buff_expanded),Vector2(52,32))
	buff_toggle.name = "BuffCollapse"
	_place(buff_toggle,12,105,64,137)
	v20_layer.add_child(buff_toggle)
	buff_row.position.x = 70
	buff_row.set_meta("renewal_base_position",buff_row.position)
	var detail := UI.button("효과 상세",_open_buffs,Vector2(88,28))
	detail.add_theme_font_size_override("font_size",11)
	_place(detail,12,141,108,169)
	v20_layer.add_child(detail)
	var pickup := UI.button("줍기",func() -> void: pickup_requested.emit(),Vector2(82,42))
	pickup.name = "PickupLoot"
	_place(pickup,979,553,1055,601)
	v20_layer.add_child(pickup)
	var auto_skills := UI.button("자동 스킬",_open_quickslot_settings,Vector2(88,36))
	auto_skills.name = "AutoSkills"
	_place(auto_skills,967,486,1065,528)
	v20_layer.add_child(auto_skills)
	var home: Control = v20_layer.get_node("ReturnToSpawn")
	_place(home,1078,401,1268,441)
	home.set_meta("renewal_base_position",home.position)
	move_readout = UI.label("대기",11,UI.MUTED)
	_place(move_readout,66,443,158,467)
	v20_layer.add_child(move_readout)
	_fit_hud()

func _activate_visible_slot(visible_index: int) -> void:
	if blocks_world_input(): return
	quickslot_pressed.emit(quick_controller.index_for(visible_index))

func _change_quick_page(bank: int, direction: int) -> void:
	quick_controller.change_page(bank,direction)
	_render_quickslots(lineage_inventory_ui.inventory,get_parent()._combined_active_buffs())

func _drop_quickslot(index: int, data: Dictionary) -> void:
	if data.get("kind") == "slot":
		quickslot_edit_requested.emit(index,"swap",int(data.get("index",-1)))
	else:
		quickslot_assignment_requested.emit(index,str(data.get("kind","")),str(data.get("id","")))

func _open_quickslot_picker(entry_kind: String, entry_id: String, _display_name: String) -> void:
	quick_picker_kind = entry_kind
	quick_picker_id = entry_id
	_open_quickslot_settings(true)

func _open_quickslot_settings(registering: bool = false) -> void:
	_open_window("quickslots","퀵슬롯", "좌우 4칸 · 각각 3그룹 · 길게 누르기/우클릭: 편집")
	var col: VBoxContainer = workspace.column()
	col.add_child(UI.section("등록할 위치: "+quick_picker_id if registering else "24칸 퀵슬롯 관리",16))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for page: int in 3:
		rows.add_child(UI.label("그룹 %d" % (page+1),14,UI.GOLD))
		var banks := HBoxContainer.new()
		rows.add_child(banks)
		for bank: int in 2:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			banks.add_child(grid)
			for slot: int in 4:
				var index: int = page * 8 + bank * 4 + slot
				var entry: Dictionary = quickslot_entries[index] if index < quickslot_entries.size() else {}
				var caption := QuickController.label_for(index)+"\n"+str(entry.get("id","비어 있음"))
				var b := UI.button(caption,func() -> void:
					if workspace.was_scroll_dragged(scroll): return
					if registering: _emit_quickslot_assignment(index,quick_picker_kind,quick_picker_id)
					else: _open_slot_editor(index),Vector2(146,62))
				b.name = "AssignQuickslot_%d" % index
				b.add_theme_font_size_override("font_size",11)
				grid.add_child(b)
				workspace.register_scroll_drag(scroll,b)
	col.add_child(UI.section("PC: 1–8 사용 · [ / ] 그룹 전환 · 드래그로 자리 교환\n터치: 슬롯 좌우 밀기 그룹 전환 · 아래로 밀기 자동사용 · 길게 누르기 편집",12))

func _open_slot_editor(index: int) -> void:
	selected_quickslot = index
	_open_window("quickslots","슬롯 편집",QuickController.label_for(index))
	var entry: Dictionary = quickslot_entries[index] if index < quickslot_entries.size() else {}
	var col: VBoxContainer = workspace.column()
	col.add_child(UI.section(str(entry.get("id","비어 있는 슬롯")),22))
	var state := UI.section("자동사용 ON" if bool(entry.get("auto",false)) else "자동사용 OFF",14)
	col.add_child(state)
	var toggle := UI.button("자동사용 전환",func() -> void:
		quickslot_edit_requested.emit(index,"auto",-1)
		_open_slot_editor(index))
	toggle.name = "ToggleSlotAuto"
	toggle.disabled = entry.is_empty() or (not bool(entry.get("auto",false)) and not get_parent()._quickslot_can_auto(entry))
	col.add_child(toggle)
	col.add_child(UI.section("공격/회복 스킬과 소모품은 AUTO 사냥 중 사용합니다. 버프 자동사용은 SELF OFF에서 실행됩니다.",12))
	var clear := UI.button("슬롯 해제",func() -> void:
		quickslot_edit_requested.emit(index,"clear",-1)
		_open_quickslot_settings())
	clear.name = "ClearQuickslot"
	clear.disabled = entry.is_empty()
	col.add_child(clear)
	col.add_child(UI.button("스킬에서 변경",open_skills))
	col.add_child(UI.button("인벤토리에서 변경",func() -> void: _navigate("inventory")))
	col.add_child(UI.button("전체 퀵슬롯",_open_quickslot_settings))

func _open_capability(section: String) -> void:
	var record: Array = MENU.entry(section)
	_open_window(section,str(record[1]),"현재 로컬 버전에서 미지원")
	var col: VBoxContainer = workspace.column()
	col.add_child(UI.section(str(record[1]),24))
	col.add_child(UI.section(MENU.requirement(section),16))
	col.add_child(UI.section("TWILIGHT는 서버에 연결되지 않은 로컬 게임입니다.",13))
	if section in ["collection","growth"]:
		col.add_child(UI.button("아이템 도감",func() -> void: _navigate("아이템")))
	elif section in ["party","clan","friends"]:
		col.add_child(UI.button("채팅 · 로컬 기록",_open_chat))
	elif section == "exchange":
		col.add_child(UI.button("로컬 상점",open_shop))
		col.add_child(UI.button("아이템 매입",open_item_sell))
	col.add_child(UI.button("전체 메뉴",toggle_menu))

func _open_chat() -> void:
	_open_window("chat","채팅","로컬 기록 · 서버 채널 미연결")
	var col: VBoxContainer = workspace.column()
	var channels := OptionButton.new()
	channels.name = "ChatChannel"
	for channel: String in ["로컬 기록", "시스템", "일반 · 미연결", "월드 · 미연결", "파티 · 미연결", "혈맹 · 미연결"]:
		channels.add_item(channel)
	col.add_child(channels)
	var history := UI.rich("")
	history.name = "ChatHistory"
	history.bbcode_enabled = false
	history.fit_content = false
	history.scroll_active = true
	history.scroll_following = true
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(history)
	var row := HBoxContainer.new()
	col.add_child(row)
	var input := LineEdit.new()
	input.name = "ChatInput"
	input.max_length = 240
	input.placeholder_text = "이번 플레이의 로컬 기록"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	var send := UI.button("기록",func() -> void: _submit_chat(input,history,channels))
	send.name = "ChatSend"
	row.add_child(send)
	input.text_submitted.connect(func(_value: String) -> void: _submit_chat(input,history,channels))
	channels.item_selected.connect(func(index: int) -> void:
		input.editable = index == 0
		send.disabled = index != 0
		history.text = "\n".join(chat_messages) if index == 0 else ("\n".join(log_history) if index == 1 else "서버 채널이 연결되지 않았습니다. 메시지를 전송할 수 없습니다."))
	channels.item_selected.emit(0)

func _submit_chat(input: LineEdit, history: RichTextLabel, channel: OptionButton) -> void:
	if channel.selected != 0 or input.text.strip_edges().is_empty(): return
	chat_messages.append("[로컬] "+input.text.strip_edges())
	if chat_messages.size() > 120: chat_messages.pop_front()
	history.text = "\n".join(chat_messages)
	input.clear()

func _open_dungeons(section: String) -> void:
	_open_window(section,"특수 던전" if section == "special_dungeon" else "던전","현재 월드 데이터의 지역 · 이동 안내")
	var col: VBoxContainer = workspace.column()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for record: Dictionary in map_records:
		var id := str(record.get("id",""))
		var title := str(record.get("name",id))
		if id == "aden_world": continue
		var special: bool = not (id.begins_with("oman") or id.begins_with("faith") or title.contains("탑"))
		if special != (section == "special_dungeon"): continue
		var b := UI.button(title,func() -> void:
			if not workspace.was_scroll_dragged(scroll): open_npc_teleport(id))
		list.add_child(b)
		workspace.register_scroll_drag(scroll,b)
	col.add_child(UI.section("지역 선택과 비용·레벨 조건은 이동 안내에서 확인할 수 있습니다.",12))
	col.add_child(UI.button("이동 안내",open_npc_teleport))

func _open_information(section: String) -> void:
	_open_window(section,"조작 · 단축키" if section == "controls" else "게임 정보","TWILIGHT")
	var col: VBoxContainer = workspace.column()
	if section == "controls":
		col.add_child(UI.section("WASD / 방향키: 이동 · Space: 공격 · T: 자동사냥\nI: 인벤토리 · K: 스킬 · C: 캐릭터 · M: 메뉴 · Tab: 지도\n1–8: 퀵슬롯 · [ / ]: 좌우 그룹 · F: 줍기 · Enter: 채팅\nEsc / 모바일 뒤로가기: 이전 화면 · 창 바깥: 닫기\nF5: 저장 · F9: 불러오기\n슬롯 길게 누르기/우클릭: 편집 · 아래로 밀기: 자동사용",16))
	else:
		col.add_child(UI.section("TWILIGHT · 로컬 RPG\n현재 저장과 전투는 이 기기에서 처리됩니다.\n온라인 거래·파티·혈맹·우편 서비스는 연결되지 않았습니다.\n변신·인형·성물 도감의 적용은 기존 로컬 시험 기능입니다.",16))
	col.add_child(UI.button("환경 설정",open_settings_info))

func _confirm_exit() -> void:
	confirm_action("저장 후 종료","현재 진행도를 저장하고 게임을 종료합니다.",func() -> void:
		if get_parent()._save_game(false): get_tree().quit())

func _open_buffs() -> void:
	_open_window("buffs","현재 효과","남은 시간 · 버프와 상태이상")
	var col: VBoxContainer = workspace.column()
	buff_detail = UI.rich("")
	buff_detail.fit_content = false
	buff_detail.scroll_active = true
	buff_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(buff_detail)
	_refresh_buff_detail()

func _refresh_buff_detail() -> void:
	if not is_instance_valid(buff_detail): return
	var lines: Array[String] = []
	for key: String in get_parent()._combined_active_buffs():
		var effect: Dictionary = get_parent()._combined_active_buffs()[key]
		lines.append("%s · %d초\n%s" % [UI.safe(key),ceili(float(effect.get("remaining",0))),UI.safe(effect.get("desc",""))])
	var actor: Node = get_parent().player
	for pair: Array in [["is_stunned","기절"],["is_silenced","침묵"],["is_held","속박"],["is_feared","공포"]]:
		if actor.call(pair[0]): lines.append("[color=#e97772]"+pair[1]+"[/color]")
	buff_detail.text = "\n\n".join(lines) if not lines.is_empty() else "활성 효과가 없습니다."
