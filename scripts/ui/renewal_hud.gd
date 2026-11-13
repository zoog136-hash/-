extends "res://scripts/hud_v20.gd"
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const MENU_MEMORY_TRACE = preload("res://scripts/boot/menu_memory_trace.gd")

signal equipment523_open_requested
signal equipment523_preview_requested(action: Dictionary)
signal equipment523_commit_requested(action: Dictionary)
signal equipment523_install_requested(path: String, sha256: String)
var equipment523_view: Control
# Source gives priority1/2 positions but no routing for this local show_message
# API. Source/official lookup did not establish a rule. This numeric connection
# policy is a TWILIGHT estimate under the user's source/search/estimate order.
const LOCAL_SYSTEM_MESSAGE_PRIORITY_ESTIMATE=2

# Debug-build tools. Requests are also checked by the authoritative world.
signal weapon_mastery_requested
signal card_pack_draw_requested(category: String)
signal card_fusion_requested(category: String, grade: String, count: int)
signal blessing_target_requested(scroll_name: String, target_reference: String)
signal secondary_doll_requested(identity: String)
signal secondary_relic_requested(identity: String)
signal option_awakening_open_requested(category: String, target_id: String)
signal option_awakening_feed_requested(category: String, target_id: String, materials: Dictionary)
signal option_awakening_attempt_requested(category: String, target_id: String)
signal playtest_catalog_grant_requested(item_name: String, amount: int)
signal playtest_catalog_variant_grant_requested(source_id: String, amount: int)
signal playtest_aden_grant_requested
signal quickslot_edit_requested(action: String, source_index: int, target: int)
signal original_world_map_image_clicked(payload: Dictionary)
signal consumable_auto_settings_changed(settings: Dictionary)
signal consumable_auto_settings_updated(settings: Dictionary)

signal shop_bulk_buy_requested(item_name: String, quantity: int)
signal reviewed_shop_buy_requested(vendor_id: String, item_name: String, quantity: int)
signal warehouse_transfer_requested(item_name: String, quantity: int, direction: String, instance_id: String)
signal npc_teleport_requested(map_id: String)
signal craft_requested(recipe_id: String, batch: int)
signal totem_conversion_requested(recipe_id: int)
signal totem_action_requested(action: String, totem_id: int, material_id: int, revision: int)
signal shop_sell_requested(item_name: String, quantity: int, instance_id: String)
signal npc_dialogue_action_requested(npc_id: String, node_id: String, action: String)
signal quest_complete_requested(quest_id: String)

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
var screen_backdrop: ColorRect

const CardSourcePresentation=preload("res://scripts/cards/source_card_operation_presentation.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const ReferenceSurfaces=preload("res://scripts/ui/reference_surfaces.gd")
const CARD_RULES = preload("res://scripts/card_draw_fusion.gd")
const SourceCardPresentation = preload("res://scripts/ui/source_card_presentation.gd")
const CardOwnership = preload("res://scripts/ui/catalog_card_ownership.gd")
const CARD_REVEAL = preload("res://scripts/ui/card_reveal_stage.gd")
const CardFusionView = preload("res://scripts/ui/card_fusion_view.gd")
var card_reveal_stage: Control
var card_fusion_view: Control
var card_fusion_tab: Button
var card_awakening_tab: Button
var card_fusion_return_category: String = "변신"
const OptionAwakeningView = preload("res://scripts/ui/option_awakening_view.gd")
const OptionAwakeningBorder = preload("res://scripts/ui/option_awakening_border.gd")
const OptionAwakeningReveal = preload("res://scripts/ui/option_awakening_reveal.gd")
const OptionAwakeningTouchButton = preload("res://scripts/ui/native_touch_button.gd")
var option_awakening_state: Dictionary = {}
var option_awakening_snapshot: Dictionary = {}
var option_awakening_view: Control
var option_awakening_button: Button
var halphas_star_enchant_button: Button
const HalphasStarEnchant = preload("res://scripts/cards/native_halphas_star_enchant.gd")
var option_awakening_catalog_status: Label
var option_awakening_catalog_border: Control
var option_awakening_reveal: Control
var option_awakening_source_detail: bool = false
var relic_reference_view: Control
var catalog_card_chrome: Node
var companion_detail_view: Node
const RenewalWindowScript = preload("res://scripts/ui/renewal_window.gd")
const Inventory = preload("res://scripts/ui/renewal_inventory.gd")
const CharacterUI = preload("res://scripts/ui/renewal_character.gd")
const SkillsUI = preload("res://scripts/ui/renewal_skills.gd")
const Source523SkillImages = preload("res://scripts/ui/source523_skill_buff_images.gd")
var _source523_buff_signature: Dictionary = {}
var _source523_buff_views: Dictionary = {}
const QuestUI = preload("res://scripts/ui/renewal_quests.gd")
const ClassSelectUI = preload("res://scripts/ui/renewal_class_select.gd")
const ShopUI = preload("res://scripts/ui/renewal_shop.gd")
const DialogueUI = preload("res://scripts/ui/renewal_dialogue.gd")
const WarehouseUI = preload("res://scripts/ui/renewal_warehouse.gd")
const TeleportUI = preload("res://scripts/ui/renewal_teleport.gd")
const AutoHuntingDestinationsUI = preload("res://scripts/ui/auto_hunting_destinations.gd")
const SourceDungeonUI = preload("res://scripts/dungeons/source_dungeon_view.gd")
var dungeon_progress_refresh_pending: bool = false
const CraftUI = preload("res://scripts/ui/renewal_crafting.gd")
const Patch523EquipmentInfo = preload("res://scripts/ui/patch523_equipment_info.gd")
const SellUI = preload("res://scripts/ui/renewal_sell.gd")
const EquipmentCollectionsUI = preload("res://scripts/collections/equipment_collection_view.gd")
const Growth96UI = preload("res://scripts/progression/growth96_view.gd")
var growth96_view: Control
var equipment_collection_button: Button
const ForgeUI = preload("res://scripts/ui/renewal_forge.gd")
const EnhancementReveal = preload("res://scripts/ui/enhancement_reveal.gd")
var enhancement_reveal: Control
const SettingsUI = preload("res://scripts/ui/renewal_settings.gd")
const RegionMapUI = preload("res://scripts/ui/renewal_map.gd")
const Ornament = preload("res://scripts/ui/renewal_ornament.gd")
var quest_view: Control
var quest_refresh_pending: bool = false
var quest_refresh_generation: int = 0
var card_skill_awakening_view: Control
var workspace: PanelContainer
var menu_page: VBoxContainer
var menu_scroll_view: ScrollContainer
var menu_category_filter: OptionButton
var menu_tiles: Array[Control] = []
var active_section: String = ""
var totem_view: Control
var buff_row: HBoxContainer
var exp_readout: Label
var currency_readout: Label
var currency_balances: Dictionary = {}
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
var catalog_browser_active: bool = false
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
var card_collection_state: Dictionary = {}
var normal_card_collection_view: Control
var normal_card_collection_category: String="변신"
var normal_card_collection_focus: String=""
var card_controls: VBoxContainer
var card_draw_button: Button
var card_reveal_preview: Button
var card_fusion_grade_select: OptionButton
var card_fusion_button: Button
var card_owned_label: Label
var card_result_label: Label

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
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_combat()
	if v20_auto_button != null:
		v20_auto_button.text = "AUTO\nON" if enabled else "AUTO"
		v20_auto_button.add_theme_stylebox_override("normal",_round_button_style(.88,42,Color("69c49b") if enabled else UI.BRONZE))

func _build_v20_target() -> void:
	# Keep the map title; do not construct the removed target readout.
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


func show_target(_monster_name: String, _hp: int, _max_hp: int) -> void:
	pass

func clear_target() -> void:
	if is_instance_valid(target_panel): target_panel.hide()

func set_map_name(value: String) -> void:
	super.set_map_name(value)
	_original_main_map_value=value
	_original_main_has_map_name=true
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.update_map_name(value)

func _ready() -> void:
	super._ready()
	preload("res://scripts/ui/source523_image_assets.gd").bind_native_original_icon_scenes(self)
	call_deferred("_bind_selected_original_main_ui")
	if is_instance_valid(target_panel):
		target_panel.get_parent().remove_child(target_panel)
		target_panel.queue_free()
	target_panel = null
	target_label = null
	target_hp = null
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
	screen_backdrop=ColorRect.new()
	screen_backdrop.name="ScreenFocusBackdrop"
	screen_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_backdrop.z_index=145
	screen_backdrop.hide()
	$Root.add_child(screen_backdrop)
	workspace = RenewalWindowScript.new()
	$Root.add_child(workspace)
	workspace.navigate.connect(_navigate)
	workspace.back_requested.connect(_go_back)
	workspace.closed.connect(_close_workspace)
	workspace.visibility_changed.connect(_sync_screen_focus)
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
		_place(v20_map_name.get_parent(),746,16,930,48)
		v20_map_name.add_theme_font_size_override("font_size",13)
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
	lineage_side_ui.connect("original_page_requested",_on_original_character_page_requested)
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
	if is_instance_valid(lineage_inventory_ui): lineage_inventory_ui.set_character_state(value)
	if is_instance_valid(lineage_side_ui):
		if lineage_side_ui.character_panel.is_visible_in_tree(): lineage_side_ui.set_character_state(value)
		else: lineage_side_ui.character_state = value
	if is_instance_valid(status_view): status_view.refresh(value)
	if is_instance_valid(companion_detail_view):companion_detail_view.refresh()
	if is_instance_valid(relic_reference_view):relic_reference_view.refresh_state()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_menu_state()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_primary_stats()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_character_stats()

func blocks_keyboard_input() -> bool:
	return blocks_keyboard_input_except_source_editor(null)

func blocks_keyboard_input_except_source_editor(editor: Control) -> bool:
	if get_parent().has_method("_resume_death523") and get_parent().death_recovery.blocked(): return true
	if is_enhancement_presenting() or is_option_awakening_busy(): return true
	if active_section == "option_awakening" and is_instance_valid(option_awakening_view): return true
	var focused: Control = get_viewport().gui_get_focus_owner()
	if (focused is LineEdit or focused is TextEdit) and focused!=editor: return true
	if pointer_transfer != null and pointer_transfer.pointer != -2: return true
	for dialog: Node in $Root.get_children():
		if dialog.name == "TwilightConfirmation" and dialog.visible: return true
	return false

func blocks_world_input(point: Vector2) -> bool:
	if is_enhancement_presenting() or is_option_awakening_busy(): return true
	# Native ScreenTouch may reach _unhandled_input on passive panel areas.
	# Use the same canvas and clipping coordinates as the real controls so
	# responsive shelves and dragged windows cannot issue a world destination.
	return _control_blocks_world_input($Root,point)

func _control_blocks_world_input(node: Node, point: Vector2) -> bool:
	if node is Control:
		var control: Control = node
		if not control.is_visible_in_tree() or control.is_queued_for_deletion(): return false
		var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse()*point
		var inside: bool = Rect2(Vector2.ZERO,control.size).has_point(local)
		if control.clip_contents and not inside: return false
		if inside and control.mouse_filter != Control.MOUSE_FILTER_IGNORE: return true
	for child: Node in node.get_children():
		# SubViewport content is rendered into a parent Control; its internal
		# coordinates do not belong to the world viewport.
		if child is Viewport: continue
		if _control_blocks_world_input(child,point): return true
	return false

func playtest_tools_enabled() -> bool:
	return OS.is_debug_build()

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
	_place(panel,950,10,1268,83)
	panel.add_theme_stylebox_override("panel",UI.chrome_panel(Color(.07,.06,.045,.80),UI.BRONZE,4))
	v20_layer.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",4)
	panel.add_child(row)
	for spec: Array in [["shop","상점","shop.png"],["inventory","가방","bag.png"],["skills","스킬","skill.png"],["map","지도","quest.png"],["menu","메뉴","menu.png"]]:
		var id := str(spec[0])
		var b := UI.button("",_navigate.bind(id),Vector2(58,60))
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
		artwork.position = Vector2(11,2)
		artwork.size = Vector2(36,36)
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(artwork)
		var label := UI.label(str(spec[1]),12,UI.TEXT)
		label.position = Vector2(0,40)
		label.size = Vector2(59,16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(label)

func _build_v20_right_controls() -> void:
	v20_self_button = UI.button("SELF",_toggle_self_mode,Vector2(68,44))
	v20_self_button.name = "SelfMode"
	v20_self_button.toggle_mode = true
	v20_self_button.tooltip_text = "SELF OFF: 퀵슬롯 버프 자동 재사용 · ON: 수동 사용"
	_place(v20_self_button,1070.5,438,1138.5,494)
	v20_self_button.add_theme_stylebox_override("normal",_round_button_style(.78,28,UI.BRONZE))
	v20_self_button.add_theme_font_size_override("font_size",11)
	v20_layer.add_child(v20_self_button)
	var target := UI.button("",func() -> void: target_pressed.emit())
	target.name = "SelectTarget"
	target.icon = UI.icon("target")
	target.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(target,1183.5,437,1241.5,495)
	target.add_theme_stylebox_override("normal",_round_button_style(.78,29,UI.BRONZE))
	target.tooltip_text="대상 선택"
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
	attack.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack.expand_icon = true
	attack.add_theme_constant_override("icon_max_width",86)
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
	log_label.add_theme_font_size_override("normal_font_size",12)
	log_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
	log_label.add_theme_constant_override("shadow_offset_x",1)
	log_label.add_theme_constant_override("shadow_offset_y",1)
	log_label.modulate.a = 1.0

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
		if base.y >= 449 or control.name in ["SelfMode","SelectTarget"]: control.position.y += extra_y
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
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_process_step(delta)
	FRAME_HITCH.add_self("hud", hitch_started, hitch_nested)

func _process_step(delta: float) -> void:
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
	refresh_card_skill_awakening_growth()
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
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_quickslots()
	if workspace != null and workspace.visible:
		workspace.footer.text = "아데나  %s  ·  Lv.%d  ·  %s  ·  Esc로 닫기" % [lineage_inventory_ui._format_number(int(character_state.get("gold",0))),int(character_state.get("level",1)),v20_map_name.text]

func update_player(level: int,hp: int,max_hp: int,mp: int,max_mp: int,experience_value: int,exp_need: int,gold: int) -> void:
	super.update_player(level,hp,max_hp,mp,max_mp,experience_value,exp_need,gold)
	_original_main_player_values=[level,hp,max_hp,mp,max_mp,experience_value,exp_need,gold]
	# Preserve latest main's HP-only combat refresh (PR #43).
	var vitals: Dictionary = {"hp":hp,"max_hp":max_hp,"mp":mp,"max_mp":max_mp,"level":level,"gold":gold}
	character_state.merge(vitals, true)
	if is_instance_valid(lineage_side_ui):
		lineage_side_ui.update_vitals(hp,max_hp,mp,max_mp)
	if is_instance_valid(lineage_inventory_ui):
		lineage_inventory_ui.character_state.merge(vitals,true)
		# The lightweight kill refresh must also update the bag's wallet, without
		# invoking set_character_state and rebuilding its item slots.
		lineage_inventory_ui.gold_label.text = "아데나  "+lineage_inventory_ui._format_number(gold)
	if exp_readout != null:
		exp_readout.text = "Lv.%d  ·  EXP %.2f%%" % [level,float(experience_value)*100/maxi(1,exp_need)]
	_refresh_currency_readout()
	if is_instance_valid(original_main_ui_controller):
		original_main_ui_status=original_main_ui_controller.update_player(level,hp,max_hp,mp,max_mp,experience_value,exp_need,gold)

func update_currency_balances(items: Dictionary) -> void:
	for currency_name: String in ["다이아", "명예 코인", "변신 제작 코인", "마법인형 제작 코인", "성물 제작 코인"]:
		currency_balances[currency_name] = maxi(0, int(items.get(currency_name, 0)))
	_refresh_currency_readout()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.update_currency_balances(currency_balances)

func _refresh_currency_readout() -> void:
	if currency_readout == null or not is_instance_valid(lineage_inventory_ui):
		return
	var funds: String = lineage_inventory_ui._format_number(int(character_state.get("gold", 0)))
	var diamonds: String = lineage_inventory_ui._format_number(int(currency_balances.get("다이아", 0)))
	currency_readout.text = "아데나 %s · 다이아 %s" % [funds, diamonds]
	currency_readout.tooltip_text = "재화 보유량"
	for currency_name: String in ["명예 코인", "변신 제작 코인", "마법인형 제작 코인", "성물 제작 코인"]:
		currency_readout.tooltip_text += "\n%s  %s" % [currency_name, lineage_inventory_ui._format_number(int(currency_balances.get(currency_name, 0)))]

func set_quickslot_state(entries: Array,inventory: Dictionary,buffs: Dictionary,self_enabled: bool) -> void:
	super.set_quickslot_state(entries,inventory,buffs,self_enabled)
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_combat()
	update_currency_balances(inventory)
	# Main supplies its inventory here even on a fresh game without a save file.
	lineage_inventory_ui.set_inventory(inventory)
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_menu_state()
	var presentation: Dictionary={}
	var source_images_selected: bool = Source523SkillImages.selected()
	if source_images_selected:
		var image_pack: RefCounted = preload("res://scripts/ui/source523_image_assets.gd").active()
		presentation["__source523_pack"] = image_pack.get_instance_id() if image_pack != null else -1
	for key: Variant in buffs:
		var effect: Variant=buffs[key]
		presentation[key]=int(ceil(float(effect.get("remaining",0)))) if effect is Dictionary else 0
		if source_images_selected and effect is Dictionary:
			var native_buff: Variant = effect.get("source_buff_class")
			presentation[key] = [presentation[key],effect.get("skill_id",""),effect.get("source_snapshot",""),native_buff.get("ID",-1) if native_buff is Dictionary else -1]
	if active_buffs_view == presentation:
		return
	active_buffs_view = presentation
	var visible_keys: Array=buffs.keys().slice(0,8)
	var source_signature: Dictionary={}
	if source_images_selected:
		var identities: Dictionary={}
		for key: Variant in buffs:
			var effect: Variant=buffs[key]
			if effect is Dictionary:
				var identity: Dictionary=effect.duplicate(true)
				identity.erase("remaining")
				identities[key]=identity
		var images=preload("res://scripts/ui/source523_image_assets.gd")
		source_signature={"pack":presentation.get("__source523_pack",-1),"ui_revision":images.original_ui_revision(),"keys":visible_keys,"effects":identities}
		if source_signature==_source523_buff_signature:
			var reusable: bool=true
			for key: Variant in visible_keys:
				var row: Dictionary=_source523_buff_views.get(key,{})
				if not is_instance_valid(row.get("button")) or not is_instance_valid(row.get("remaining")):
					reusable=false
					break
			if reusable:
				for key: Variant in visible_keys:
					var effect: Variant=buffs[key]
					var time: int=int(ceil(float(effect.get("remaining",0)))) if effect is Dictionary else 0
					var row: Dictionary=_source523_buff_views[key]
					(row.remaining as Label).text="%ds" % time
					(row.button as Button).tooltip_text=str(key)+" · %d초" % time+str(row.get("missing_hint",""))
				return
	_source523_buff_views.clear()
	_source523_buff_signature=source_signature
	_clear_children(buff_row)
	if buffs.is_empty():
		buff_row.add_child(UI.label("활성 효과 없음",11,UI.MUTED))
	for key: Variant in visible_keys:
		var effect: Variant = buffs[key]
		var time: int = int(ceil(float(effect.get("remaining",0)))) if effect is Dictionary else 0
		var b := UI.button("",open_character,Vector2(36,42))
		var icon := TextureRect.new()
		var source_image: Dictionary = _source523_buff_image(effect if effect is Dictionary else {})
		if source_image.handled:
			source_image=Source523SkillImages.apply(icon,source_image,"active_buff_row")
			b.set_meta("source523_buff_image",Source523SkillImages.evidence(source_image))
		else:
			icon.texture=_load_texture("res://assets/ui/rune.png")
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
		var missing_hint: String=""
		if source_image.handled and icon.texture == null and not source_image.get("scene_result",{}).get("ok",false):
			missing_hint=" · 원본 아이콘 " + Source523SkillImages.missing_label(source_image)
			b.tooltip_text += missing_hint
		buff_row.add_child(b)
		if source_images_selected: _source523_buff_views[key]={"button":b,"remaining":remaining,"missing_hint":missing_hint}
	if source_images_selected:
		_source523_buff_signature["ui_revision"]=preload("res://scripts/ui/source523_image_assets.gd").original_ui_revision()

func _source523_buff_image(effect: Dictionary) -> Dictionary:
	var service: RefCounted = get_parent().get("original_skills")
	var source: RefCounted
	var record: Dictionary = {}
	if service != null and service.get("catalog") != null:
		var catalog: RefCounted = service.get("catalog")
		source = catalog.get("source523")
		if get_parent().has_method("_skill_record"):
			record = get_parent()._skill_record(str(effect.get("skill_id","")))
	return Source523SkillImages.describe_buff(effect,"OnIconID",source,record)

func _render_quickslots(inventory: Dictionary,_buffs: Dictionary) -> void:
	for index: int in range(quickslot_icons.size()):
		var button: Button = v20_quickslot_buttons[index]
		var absolute: int = quickslot_index(index)
		var valid_entry: bool=absolute<quickslot_entries.size() and quickslot_entries[absolute] is Dictionary and not quickslot_entries[absolute].is_empty()
		var visual_kind: String=("item" if quickslot_entries[absolute].get("kind","")=="item" else "skill") if valid_entry else "empty"
		if visual_kind=="empty" or quickslot_icons[index].get_meta("source523_quickslot_kind","")!=visual_kind:
			UI.clear_item_visual(quickslot_icons[index])
			Source523SkillImages.clear(quickslot_icons[index])
		quickslot_icons[index].set_meta("source523_quickslot_kind",visual_kind)
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
			var source_image: Dictionary = Source523SkillImages.describe_guardian_skill(skill,get_parent().get("growth")) if skill.get("origin") == "TWILIGHT_GUARDIAN523" else Source523SkillImages.describe_skill(skill)
			if source_image.handled:
				source_image=Source523SkillImages.apply(quickslot_icons[index],source_image,"skill_quickslot")
				if quickslot_icons[index].texture == null and not source_image.get("scene_result",{}).get("ok",false):
					quickslot_captions[index].text = Source523SkillImages.missing_label(source_image)
			else:
				Source523SkillImages.clear(quickslot_icons[index])
				quickslot_icons[index].texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else _skill_icon(str(skill.get("effect","")),str(skill.get("type","")))
			quickslot_icons[index].modulate = Color.WHITE
		if bool(entry.get("auto",false)):
			quickslot_auto_badges[index].text = "AUTO"
			button.add_theme_stylebox_override("normal",UI.slot_frame(Color("4db3d5"),true))
	var pages: Array = get_parent()._quickslot_pages()
	if is_instance_valid(quickslot_picker_hint): quickslot_picker_hint.text = "왼쪽 %d페이지 · 오른쪽 %d페이지" % [int(pages[0])+1,int(pages[1])+1]
	for i: int in range(quick_page_buttons.size()):
		quick_page_buttons[i].add_theme_stylebox_override("normal",UI.tab_frame(i%5 == int(pages[i/5])))
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_quickslots()

func append_log(value: String) -> void:
	log_history.append(value)
	if log_history.size()>120:
		log_history.pop_front()
	super.append_log(value)
	if active_section == "log" and is_instance_valid(combat_log_view) and not combat_log_view.is_queued_for_deletion():
		combat_log_view.text = "\n".join(log_history)

func show_message(text: String) -> void:
	super.show_message(text)
	_original_system_message_priority=LOCAL_SYSTEM_MESSAGE_PRIORITY_ESTIMATE
	_original_system_message_routing={"kind":"TWILIGHT_ESTIMATE","field":"local_show_message_priority","value":2,"original_rule_confirmed":false}
	if is_instance_valid(original_main_ui_controller):
		original_main_ui_status["system_message"]=original_main_ui_controller.set_system_message_priority(_original_system_message_priority,_original_system_message_routing)

func show_source_system_message(text: String, explicit_priority: int) -> Dictionary:
	if explicit_priority not in [1,2]:return {"ok":false,"code":"source_system_message_explicit_priority_1_or_2_required"}
	super.show_message(text)
	_original_system_message_priority=explicit_priority
	_original_system_message_routing={"kind":"explicit_caller_priority","value":explicit_priority,"original_rule_confirmed":false}
	if not is_instance_valid(original_main_ui_controller):return {"ok":false,"code":"source_system_message_original_controller_unavailable","existing_message_retained":true}
	var result: Dictionary=original_main_ui_controller.set_system_message_priority(_original_system_message_priority,_original_system_message_routing)
	original_main_ui_status["system_message"]=result
	return result

func _unhandled_key_input(event: InputEvent) -> void:
	if get_parent().has_method("_resume_death523") and get_parent().death_recovery.blocked(): return
	if is_enhancement_presenting() or is_option_awakening_busy():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.crafting_search_is_open():
			original_main_ui_controller.close_crafting_search()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.inventory_search_is_open():
			original_main_ui_controller.close_inventory_search()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(original_main_ui_controller) and ((original_main_ui_controller.has_method("domination_window_is_open") and original_main_ui_controller.domination_window_is_open()) or (original_main_ui_controller.has_method("status_board_is_open") and original_main_ui_controller.status_board_is_open()) or (original_main_ui_controller.has_method("emblem_window_is_open") and original_main_ui_controller.emblem_window_is_open()) or (original_main_ui_controller.has_method("refine_window_is_open") and original_main_ui_controller.refine_window_is_open()) or (original_main_ui_controller.has_method("enchant_window_is_open") and original_main_ui_controller.enchant_window_is_open()) or (original_main_ui_controller.has_method("death_window_is_open") and original_main_ui_controller.death_window_is_open()) or (original_main_ui_controller.has_method("skill_window_is_open") and original_main_ui_controller.skill_window_is_open())):
			_close_workspace()
			get_viewport().set_input_as_handled()
			return
		if original_inventory_is_open():
			original_main_ui_controller.close_inventory()
			_close_workspace()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("shop_window_is_open") and original_main_ui_controller.shop_window_is_open():
			original_main_ui_controller.close_shop_window()
			_close_workspace()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("change_window_is_open") and original_main_ui_controller.change_window_is_open():
			original_main_ui_controller.close_change_window()
			_close_workspace()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("quest_window_is_open") and original_main_ui_controller.quest_window_is_open():
			original_main_ui_controller.close_quest_window()
			_close_workspace()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.world_map_is_open():
			original_main_ui_controller.close_world_map()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(detail_window) and detail_window.visible:
			detail_window.hide()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.character_is_open():
			_close_workspace()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.npc_dialogue_is_open():
			_close_workspace()
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
	quest_refresh_generation += 1
	quest_refresh_pending = false
	if original_inventory_is_open():original_main_ui_controller.close_inventory()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.close_character()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.close_npc_dialogue()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.close_enhance_action()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.close_quest_controls()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_quest_window"):original_main_ui_controller.close_quest_window()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_shop_window"):original_main_ui_controller.close_shop_window()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_change_window"):original_main_ui_controller.close_change_window()
	if is_instance_valid(companion_detail_view):companion_detail_view.deactivate()
	if is_instance_valid(catalog_card_chrome):catalog_card_chrome.deactivate()
	if is_instance_valid(relic_reference_view):relic_reference_view.deactivate()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_domination_window"):original_main_ui_controller.close_domination_window()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_status_board"):original_main_ui_controller.close_status_board()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_death_window"):original_main_ui_controller.close_death_window()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_skill_window"):original_main_ui_controller.close_skill_window()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_emblem_window"):original_main_ui_controller.close_emblem_window()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_refine_window"):original_main_ui_controller.close_refine_window()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_enchant_window"):original_main_ui_controller.close_enchant_window()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_dissolve_confirm"):original_main_ui_controller.close_dissolve_confirm()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_acquisition"):original_main_ui_controller.close_acquisition()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_feature_windows"):original_main_ui_controller.close_feature_windows()
	_retire_original_menu_status()
	if active_section == "emblems": get_parent().growth.rerolls.clear()
	if class_picker_initial:
		return
	catalog_icon_generation += 1
	if workspace != null and workspace.visible:
		if not switching_workspace: _presentation_transition()
		navigation_memory.capture(active_section,workspace.content)
	if not switching_workspace:
		navigation_memory.clear_history()
	combat_log_view = null
	pending_quickslot_binding.clear()
	if catalog_browser_active and active_section in ["아이템","변신","마법인형","성물"] and catalog_list != null:
		catalog_view_state[active_section] = {"query":catalog_search.text,"grade":catalog_grade_filter,"page":catalog_page,"id":str(selected_catalog_record.get("sourceId",selected_catalog_record.get("name",""))),"scroll":catalog_list.get_v_scroll_bar().value}
	if pointer_transfer != null: pointer_transfer.cancel()
	for dialog: Node in $Root.get_children():
		if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion(): dialog.dismiss()
	if is_instance_valid(detail_window): detail_window.hide()
	if is_instance_valid(companion_window): companion_window.hide()
	if workspace != null:
		workspace.hide()
	active_section = ""
	catalog_browser_active = false
	if lineage_inventory_ui != null:
		lineage_inventory_ui.hide_inventory()
	if lineage_side_ui != null:
		lineage_side_ui.hide_all()

func _hide_aux_panels() -> void:
	super._hide_aux_panels()
	_close_workspace()

func _park_shared_panels() -> void:
	var shared: Array[Control] = [lineage_inventory_ui,lineage_side_ui.character_panel,utility_panel,map_panel,catalog_panel]
	if is_instance_valid(menu_page): shared.append(menu_page)
	for panel: Control in shared:
		if panel.get_parent() != $Root:
			panel.reparent($Root)
		panel.hide()

func _open_window(section: String,title: String,description: String) -> void:
	if original_inventory_is_open():original_main_ui_controller.close_inventory()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.close_character()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.close_npc_dialogue()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.close_enhance_action()
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.close_quest_controls()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.world_map_is_open():original_main_ui_controller.close_world_map()
	_presentation_transition()
	if active_section=="emblems" and section!="emblems": get_parent().growth.rerolls.clear()
	navigation_memory.enter(active_section,section)
	switching_workspace = true
	_hide_aux_panels()
	switching_workspace = false
	_park_shared_panels()
	workspace.clear()
	workspace.open(section,title,description)
	active_section = section
	_sync_screen_focus()
	workspace.set_back_available(navigation_memory.has_history())
	call_deferred("_restore_navigation",section)

func _sync_screen_focus() -> void:
	if not is_instance_valid(screen_backdrop):return
	var shown: bool=is_instance_valid(workspace) and workspace.visible
	screen_backdrop.visible=shown
	if not shown:return
	var browsing: bool=workspace.current_section not in ["inventory","quickbind","character","stats","warehouse","sell","dialogue"]
	screen_backdrop.color=Color(.015,.013,.01,.54 if browsing else .17)
	screen_backdrop.mouse_filter=Control.MOUSE_FILTER_STOP if browsing else Control.MOUSE_FILTER_IGNORE

func _presentation_transition() -> void:
	var audio: Node = get_tree().get_first_node_in_group("presentation_audio")
	if audio != null: audio.play_ui("transition")

func _restore_navigation(section: String) -> void:
	if workspace != null and workspace.visible and active_section == section:
		navigation_memory.restore(section,workspace.content)

func _go_back() -> void:
	if class_picker_initial: return
	if is_instance_valid(companion_detail_view) and companion_detail_view.active and companion_detail_view.active_tab==1:
		companion_detail_view.select_tab(0)
		return
	if active_section == "option_awakening" and is_instance_valid(option_awakening_view) and option_awakening_view.cancel_review():
		return
	if active_section == "growth96" and is_instance_valid(growth96_view) and growth96_view.cancel_review():
		return
	var restore_card_details: bool = active_section == "option_awakening" and option_awakening_source_detail
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
	if restore_card_details and CARD_RULES.CATEGORIES.has(previous):
		_set_catalog_detail_view(true)
	navigation_memory.returning = false
	if workspace != null:
		workspace.set_back_available(navigation_memory.has_history())

func open_class_selection(initial: bool = false) -> void:
	var account = preload("res://scripts/characters/account_store.gd")
	if not account.session.is_empty():
		var world: Node = get_parent()
		if world.has_method("return_to_character_lobby"): world.call("return_to_character_lobby")
		return
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
		"card_fusion": open_card_fusion(card_fusion_return_category)
		"option_awakening":
			if not option_awakening_snapshot.is_empty():
				option_awakening_open_requested.emit(str(option_awakening_snapshot.get("category", "")), str(option_awakening_snapshot.get("target_id", "")))
		"weapon_mastery": weapon_mastery_requested.emit()
		"protection523": open_protection523()
		"equipment_collections": open_equipment_collections()
		"growth96": open_growth96()
		"combinations": open_combinations()
		"totems": open_totems()
		"card_collections": open_normal_card_collections(normal_card_collection_category,normal_card_collection_focus)
		"monsterbook523": open_monsterbook523()
		"emblems", "guardians": open_growth(section)
		"half_elixir": open_half_elixir()
		"domination_stone": open_domination_stone()
		"status_board": open_status_board()
		"clan_emblem523": open_clan_emblem523()
		"clan523": open_clan523()
		"content523": open_content523()
		"titles": open_titles523()
		"expedition": open_expedition()
		"class_select": open_class_selection()
		"inventory": inventory_pressed.emit()
		"character": open_character()
		"skills": open_skills()
		"spell_groups":
			_open_window("spell_groups","스킬 계열 전환", "")
			var view=load("res://scripts/ui/spell_group_conversion_view.gd").new()
			view.configure(get_parent());workspace.mount(view)
		"tj_coupons": open_tj_coupons()
		"promo_code": open_promo_code()
		"quests": open_quests()
		"shop": open_shop()
		"exchange": open_frozen_exchange()
		"npc_shop": open_npc_shop()
		"teleport": open_npc_teleport()
		"source_dungeons": open_source_dungeons()
		"map": toggle_map()
		"menu": toggle_menu()
		"death523": get_parent().death_recovery.open_ui()
		"settings": open_settings_info()
		"auto": open_macro_info()
		"log": open_combat_log()
		"enhance": _open_enhance_chooser()
		"warehouse": open_warehouse()
		"crafting": open_crafting()
		"equipment523": equipment523_open_requested.emit()
		"bless_refine523": open_bless_refine523()
		"refine523": open_refine523()
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

func _on_lineage_side_action(action_id: String) -> void:
	if action_id == "tj_coupons":
		if is_instance_valid(lineage_side_ui):lineage_side_ui.hide_all()
		open_tj_coupons()
		return
	if action_id == "promo_code":
		if is_instance_valid(lineage_side_ui):lineage_side_ui.hide_all()
		open_promo_code()
		return
	if action_id == "quests":
		if is_instance_valid(lineage_side_ui):
			lineage_side_ui.hide_all()
		open_quests()
		return
	super._on_lineage_side_action(action_id)


func open_tj_coupons() -> void:
	_open_window("tj_coupons", "TJ 쿠폰", "소유 쿠폰 · 실제 실패 기록 · 확인 · 저장")
	var view = preload("res://scripts/tj/view.gd").new()
	workspace.mount(view)
	view.configure(get_parent())

func open_promo_code() -> void:
	_open_window("promo_code", "쿠폰 코드", "코드 입력 · 보상 지급")
	var view = preload("res://scripts/ui/promo_code_view.gd").new()
	workspace.mount(view)
	view.configure(get_parent())

func open_quests() -> void:
	# The requested quest UI is a text list. Repeated opens reuse it instead
	# of building original CSB trees, reward pictures or hidden fallback views.
	if active_section=="quests" and is_instance_valid(quest_view) and not quest_view.is_queued_for_deletion() and workspace.visible:
		quest_view.refresh()
		return
	var trace_token: int=MENU_MEMORY_TRACE.begin("quests")
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("close_quest_window"):
		original_main_ui_controller.close_quest_window()
	_open_window("quests", "퀘스트", "목록 · 수락 · 완료")
	quest_view = null
	_open_quest_browser()
	MENU_MEMORY_TRACE.end(trace_token)

func _open_quest_browser() -> void:
	var view := QuestUI.new()
	workspace.mount(view)
	view.configure(get_parent())
	view.claim_requested.connect(func(quest_id: String) -> void:
		quest_complete_requested.emit(quest_id))
	quest_view = view

func refresh_quests() -> void:
	# Cheap on kills/pickups. Rebuild only the currently open quest page,
	# at most once per frame regardless of the number of events.
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("quest_window_is_open") and original_main_ui_controller.quest_window_is_open():
		if not quest_refresh_pending:
			quest_refresh_pending=true
			call_deferred("_refresh_quests_deferred",quest_refresh_generation)
		return
	if active_section != "quests" or not is_instance_valid(quest_view) or quest_view.is_queued_for_deletion():
		return
	if quest_refresh_pending:
		return
	quest_refresh_pending = true
	call_deferred("_refresh_quests_deferred",quest_refresh_generation)

func _refresh_quests_deferred(generation: int = -1) -> void:
	if generation >= 0 and generation != quest_refresh_generation:return
	quest_refresh_pending = false
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("quest_window_is_open") and original_main_ui_controller.quest_window_is_open():
		original_main_ui_status["quest_window"]=original_main_ui_controller.refresh_quest_window()
		return
	if active_section == "quests" and is_instance_valid(quest_view) and not quest_view.is_queued_for_deletion():
		quest_view.call("refresh")


func open_shop() -> void:
	_open_window("shop","상점","")
	var shop := ShopUI.new()
	workspace.mount(shop)
	shop.configure(self)
	shop_view = shop
	# The original 523 shop window shows the market; the existing panel keeps
	# quotes, confirmation, payment and the order box.
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("can_open_shop_window") and original_main_ui_controller.can_open_shop_window() and shop.has_method("_open_source523"):
		shop.call("_open_source523")
		var panel: Variant=shop.get("source523_panel")
		if panel is Control and is_instance_valid(panel):
			var native: Dictionary=original_main_ui_controller.try_open_shop_window(panel)
			original_main_ui_status["shop_window"]=native
			if native.get("handled",false):
				if pointer_transfer!=null:pointer_transfer.cancel()
				workspace.hide()
				_sync_screen_focus()

func open_frozen_exchange() -> void:
	_open_window("exchange","거래소 · 초기 실측 고정","")
	var panel = preload("res://scripts/ui/frozen_exchange_panel.gd").new()
	workspace.mount(panel)
	panel.configure(self)

func open_npc_shop() -> void:
	_open_window("npc_shop","잡화 상인","")
	var shop := ShopUI.new()
	workspace.mount(shop)
	shop.configure(self,true)
	shop_view = shop

func refresh_shop() -> void:
	if active_section in ["shop","npc_shop"] and is_instance_valid(shop_view): shop_view.refresh_balances()

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
	var source_note: String = " / 원본523 확정 제작" if not get_parent().patch523_equipment.data.is_empty() else ""
	_open_window("crafting","제작 장인","재료·비용 검사 · 자체 제작식" + source_note)
	var screen := CraftUI.new()
	workspace.mount(screen)
	screen.configure(self)

func open_patch523_equipment_info() -> void:
	_open_window("patch523_equipment", "원본 장비 강화 정보", "원본523 확률·재료 조회 · 현재 강화 정책 보존")
	var screen := Patch523EquipmentInfo.new()
	workspace.mount(screen)
	screen.configure(self)

func open_item_sell() -> void:
	_open_window("sell","아이템 매입","아이템 검색 · 강화 장비 ID 확인 · 판매")
	var screen := SellUI.new()
	workspace.mount(screen)
	screen.configure(self)
	transaction_view = screen
	show_companion_bag()

func open_inventory_automation_settings(mode: String) -> void:
	_open_window("inventory_automation","원본 자동 대상·로컬 정비","원본/자체 매입값 · 기존 이동진 이용 전 한 번 정비")
	var screen := preload("res://scripts/ui/inventory_automation_settings.gd").new()
	workspace.mount(screen)
	screen.configure(self,mode)
	transaction_view = screen

func open_equipment_category_settings(selector_id: int = 45011) -> void:
	_open_window("equipment_category","TWILIGHT 자체 범주 장비 선택","현재 소지한 정확한 ID만 · 미리보기 후 확인")
	var screen := preload("res://scripts/ui/equipment_category_settings.gd").new()
	workspace.mount(screen)
	screen.configure(self,selector_id)
	transaction_view = screen

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
	lineage_side_ui.bind_item_art(self)
	lineage_side_ui.show_character(character_state)
	lineage_side_ui.mount_window_header(window)

func open_npc_dialogue(npc_id: String) -> void:
	_open_window("dialogue","","")
	var screen := DialogueUI.new()
	workspace.mount(screen)
	screen.source_dialogue_resolved.connect(_on_source_npc_dialogue_resolved.bind(screen))
	screen.configure(self,npc_id)

func _on_source_npc_dialogue_resolved(resolved: Dictionary, owner: Control) -> void:
	if active_section!="dialogue" or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not workspace.content.is_ancestor_of(owner):return
	_original_npc_dialogue_owner=weakref(owner)
	# Only the original NpcDialogue_All window presents NPC talk.
	var native: Dictionary={"ok":false,"handled":false,"code":"source_npc_dialogue_original_view_not_available"}
	if not resolved.get("ok",false):native={"ok":false,"handled":false,"code":"source_npc_dialogue_not_resolved","reason":str(resolved.get("reason",""))}
	elif is_instance_valid(original_main_ui_controller):native=original_main_ui_controller.try_open_npc_dialogue(owner,resolved)
	original_main_ui_status["npc_dialogue"]=native
	if native.get("handled",false):
		if pointer_transfer!=null:pointer_transfer.cancel()
		workspace.hide()
	else:
		show_message(str(resolved.get("reason","")) if not resolved.get("ok",false) else "원본 NPC 대화창을 열 수 없습니다 · "+str(native.get("code","")))
		_close_workspace()
	_sync_screen_focus()

## Heavy settings sections are foldouts built on first open; tests and tools
## that inspect them pass expand_all = true.
func open_settings_info(expand_all: bool = false) -> void:
	_open_window("settings","설정","오디오 · HUD · 로컬 저장 및 불러오기")
	var options := SettingsUI.new()
	workspace.mount(options)
	options.configure(self)
	if expand_all: options.expand_all()

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
	var destinations := AutoHuntingDestinationsUI.new()
	col.add_child(destinations)
	destinations.configure(get_parent())
	for pair: Array in [["목표 탐색","주변 몬스터 탐색 및 이동"],["전투","현재 장비와 스킬 · 등록된 자동 사용"],["습득","바닥 드랍을 통한 자동 아이템 습득"]]:
		col.add_child(HSeparator.new())
		col.add_child(UI.section(str(pair[0]),14))
		col.add_child(UI.section(str(pair[1]),12))
	var routes := HBoxContainer.new()
	col.add_child(routes)
	var maintenance_route := UI.button("자동 정비 · 대상/비용 확인",func() -> void:
		if not workspace.was_scroll_dragged(scroll): open_inventory_automation_settings("deposit"))
	maintenance_route.name = "AutoMaintenanceSettings"
	col.add_child(maintenance_route)
	workspace.register_scroll_drag(scroll,maintenance_route)
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
	if original_inventory_is_open():
		original_main_ui_controller.close_inventory()
		_close_workspace()
		return
	if active_section=="inventory" and workspace.visible:
		_close_workspace()
		return
	_open_window("inventory","가방","")
	workspace.mount(lineage_inventory_ui)
	lineage_inventory_ui.show()
	lineage_inventory_ui.show_inventory()
	if is_instance_valid(original_main_ui_controller):
		var native: Dictionary=original_main_ui_controller.try_open_inventory()
		original_main_ui_status["inventory"]=native
		if native.get("handled",false):
			if pointer_transfer!=null:pointer_transfer.cancel()
			workspace.hide()
		else:_report_original_fallback("가방",native)
	else:_report_original_fallback("가방",original_main_ui_bind_problem)

func open_character() -> void:
	_open_window("character","캐릭터 정보","")
	var panel: PanelContainer = lineage_side_ui.character_panel
	panel.custom_minimum_size = Vector2.ZERO
	workspace.mount(panel)
	panel.show()
	lineage_side_ui.bind_item_art(self)
	lineage_side_ui.show_character(character_state)
	lineage_side_ui.mount_window_header(workspace)
	if lineage_side_ui.stats_page.visible:_on_original_character_page_requested("stats")
	elif is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("try_open_character_equipment"):
		var native: Dictionary=original_main_ui_controller.try_open_character_equipment()
		original_main_ui_status["character_equipment"]=native
		if native.get("handled",false):
			if pointer_transfer!=null:pointer_transfer.cancel()
			workspace.hide()
			_sync_screen_focus()

func _on_original_character_page_requested(page: String) -> void:
	if not is_instance_valid(original_main_ui_controller):return
	if page!="stats":
		original_main_ui_controller.close_character()
		return
	# The existing tab handler has already selected stats. No source page is
	# picked from a class ID, alphabetical equipment member or default mode.
	if active_section!="character" or not workspace.visible:return
	var native: Dictionary=original_main_ui_controller.try_open_character_stats()
	original_main_ui_status["character_stats"]=native
	if native.get("handled",false):
		if pointer_transfer!=null:pointer_transfer.cancel()
		workspace.hide()
		_sync_screen_focus()

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
	_open_window("menu","전체 메뉴","")
	# Build the menu tiles once and re-mount them; _park_shared_panels moves the
	# page out of the workspace before it is cleared, so it is never freed.
	if not is_instance_valid(menu_page): _build_menu_page()
	workspace.mount(menu_page)
	menu_page.show()
	# A freshly opened menu always starts on "전체" at the top, as before.
	menu_category_filter.select(0)
	for tile: Control in menu_tiles: tile.visible = true
	menu_scroll_view.scroll_vertical = 0

func _build_menu_page() -> void:
	var col := VBoxContainer.new()
	col.name = "MenuPage"
	menu_page = col
	var categories:=OptionButton.new()
	menu_category_filter = categories
	categories.name="MenuCategoryFilter"
	categories.custom_minimum_size.y=32
	col.add_child(categories)
	var menu_scroll:=ScrollContainer.new()
	menu_scroll_view = menu_scroll
	menu_scroll.name="MenuContentScroll"
	menu_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	menu_scroll.scroll_deadzone=8
	col.add_child(menu_scroll)
	var grid:=GridContainer.new()
	grid.name="MenuGrid"
	grid.columns=4
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	menu_scroll.add_child(grid)
	menu_scroll.resized.connect(func() -> void: grid.columns = clampi(floori(menu_scroll.size.x/99.0),2,4))
	var tiles: Array[Control] = []
	menu_tiles = tiles
	var category_names: Array[String] = ["전체","캐릭터·성장","사냥·모험","상점·생활"]
	for category: String in category_names: categories.add_item(category)
	categories.item_selected.connect(func(index: int) -> void:
		var category: String = category_names[index]
		for tile: Control in tiles: tile.visible = category == "전체" or tile.get_meta("menu_category") == category
		menu_scroll.scroll_vertical = 0)
	for pair: Array in [["character","캐릭터·장비"],["class_select","클래스 선택"],["inventory","인벤토리"],["skills","스킬"],["spell_groups","스킬 계열 전환"],["변신","변신"],["마법인형","마법인형"],["성물","성물"],["아이템","아이템 도감"],["equipment_collections","장비 컬렉션"],["protection523","불멸·파멸 가호"],["combinations","조합"],["growth96","96레벨 보상·증표"],["emblems","문양"],["clan523","혈맹"],["clan_emblem523","혈맹 문장"],["guardians","수호성"],["half_elixir","하프 엘릭서"],["domination_stone","지배석"],["titles","작위"],["totems","토템"],["weapon_mastery","무기 숙련"],["expedition","인형 탐험"],["map","월드맵"],["monsterbook523","몬스터 도감"],["quests","퀘스트"],["status_board","현황판"],["source_dungeons","던전"],["content523","에스카로스·요정 숲"],["shop","잡화 상점"],["exchange","거래소"],["enhance","장비 강화"],["auto","자동사냥"],["warehouse","창고"],["crafting","제작"],["bless_refine523","용해·질서의 연금"],["refine523","질서의 연금"],["sell","판매"],["death523","사망 복구"],["settings","설정"],["log","전투 기록"]]:
		var section_id: String = str(pair[0])
		var button: Button = UI.button("",func() -> void:
			if not workspace.was_scroll_dragged(menu_scroll):
				_navigate(section_id),Vector2(92,88))
		if section_id in ["emblems","guardians","growth96","combinations","titles","totems","monsterbook523"]:
			button.set_script(preload("res://scripts/growth/growth_touch_button.gd"))
			button.scroll_host = workspace
			button.scroll_area = menu_scroll
		button.name = "MenuTile_"+section_id
		button.set_meta("menu_category", "캐릭터·성장" if section_id in ["character","class_select","변신","마법인형","성물","equipment_collections","emblems","clan523","clan_emblem523","guardians","growth96","combinations","half_elixir","domination_stone","titles","totems"] else ("사냥·모험" if section_id in ["inventory","skills","map","monsterbook523","quests","status_board","source_dungeons","content523","auto","enhance","아이템"] else "상점·생활"))
		button.add_theme_stylebox_override("normal",UI.slot_frame())
		button.add_theme_stylebox_override("hover",UI.slot_frame(UI.GOLD,true))
		button.add_theme_stylebox_override("pressed",UI.slot_frame(UI.GOLD,true))
		var artwork := TextureRect.new()
		artwork.texture = UI.icon("character" if section_id == "growth96" else ("log" if section_id == "death523" else ("map" if section_id == "source_dungeons" else ("quest" if section_id in ["quests","monsterbook523"] else ("inventory" if section_id in ["equipment_collections","totems"] else section_id)))))
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.position = Vector2(26,8)
		artwork.size = Vector2(40,40)
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(artwork)
		var caption:=UI.label(str(pair[1]),12,UI.TEXT)
		caption.anchor_right=1
		caption.offset_left=2;caption.offset_right=-2
		caption.offset_top=58;caption.offset_bottom=78
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if section_id == "growth96":
			caption.add_theme_font_size_override("font_size",11)
			caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caption.offset_top=50;caption.offset_bottom=86
		button.add_child(caption)
		if section_id == "domination_stone": _mount_domination_menu_tile(button,artwork,caption)
		grid.add_child(button)
		tiles.append(button)
		workspace.register_scroll_drag(menu_scroll,button)

## The original MainMenu_DominationStone tile replaces the tile picture and
## caption when the original UI pack is bound (no picture otherwise).
func _mount_domination_menu_tile(button: Button, artwork: TextureRect, caption: Label) -> void:
	artwork.texture = null
	if not is_instance_valid(original_main_ui_controller) or not original_main_ui_controller.has_method("domination_menu_tile"): return
	var tile: Dictionary = original_main_ui_controller.domination_menu_tile(func() -> void: _navigate("domination_stone"))
	if not tile.get("ok",false): return
	var scene: Node2D = tile.scene
	# MainMenu_DominationStone's 70x67 panel is anchored at its centre.
	scene.position = Vector2(46,40)
	button.add_child(scene)
	caption.hide()

## The original 523 콘텐츠 현황판 (StatusBoard_All, world.routines).
func open_status_board() -> void:
	_open_window("status_board","현황판","")
	var native: Dictionary = {"ok":false,"code":"source_status_board_controller_unavailable"}
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("try_open_status_board"):
		native = original_main_ui_controller.try_open_status_board(get_parent())
	original_main_ui_status["status_board"] = native
	if native.get("handled",false):
		if pointer_transfer != null: pointer_transfer.cancel()
		workspace.hide()
		_sync_screen_focus()
		return
	var note := UI.label("현황판은 원본 523 UI 팩(StatusBoard_All)이 필요합니다.\n"+str(native.get("code",native.get("error",""))),14,UI.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace.mount(note)

## The local 523 혈맹 (world.clan523): creation, level, donation, weekly
## reward, level buffs. The original Clan_All window CSBs are not in the 523
## UI add-on (only the emblem popup is), so this panel uses plain controls.
func open_clan523() -> void:
	_open_window("clan523","혈맹","원본 523 혈맹 표 · 로컬 1인 혈맹")
	var scroll := ScrollContainer.new()
	scroll.name = "Clan523Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.mount(scroll)
	var view := preload("res://scripts/clan523/clan523_panel.gd").new()
	scroll.add_child(view)
	view.configure(self, scroll)

## 에스카로스 · 요정 숲 방어전 · 영지 퀘스트 (world.content523). No original
## window CSB for these contents is in the 523 UI add-on: plain controls.
func open_content523() -> void:
	_open_window("content523","에스카로스·요정 숲·영지 퀘스트","원본 523 표 · 오프라인 1인")
	var scroll := ScrollContainer.new()
	scroll.name = "Content523Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.mount(scroll)
	var view := preload("res://scripts/content523/content523_panel.gd").new()
	scroll.add_child(view)
	view.configure(self, scroll)

## The original 523 혈맹 문장 선택 popup (Clan_Popup_Symbol, world.emblem523).
func open_clan_emblem523() -> void:
	_open_window("clan_emblem523","혈맹 문장","")
	var native: Dictionary = {"ok":false,"code":"source_emblem_window_controller_unavailable"}
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("try_open_emblem_window"):
		native = original_main_ui_controller.try_open_emblem_window(get_parent())
	original_main_ui_status["emblem_window"] = native
	if native.get("handled",false):
		if pointer_transfer != null: pointer_transfer.cancel()
		workspace.hide()
		_sync_screen_focus()
		return
	var note := UI.label("혈맹 문장은 원본 523 UI 팩(Clan_Popup_Symbol)과 원본 정의 ZIP이 필요합니다.\n"+str(native.get("problem",native.get("code",""))),14,UI.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace.mount(note)

## The original 523 재료 아이템 출처 popup over the current screen.
func open_item_acquisition523(item_class_id: int, item_name: String = "") -> Dictionary:
	var native: Dictionary = {"ok":false,"code":"source_acquisition_popup_controller_unavailable"}
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("try_open_acquisition"):
		native = original_main_ui_controller.try_open_acquisition(get_parent(),item_class_id,item_name)
	original_main_ui_status["acquisition_popup"] = native
	return native

## Opens the original 523 feature window `key` (source_main_hud
## try_open_feature_window) over the workspace; false keeps the TWILIGHT view.
func _open_original_feature(key: String, args: Array=[]) -> bool:
	if not is_instance_valid(original_main_ui_controller) or not original_main_ui_controller.has_method("try_open_feature_window"):return false
	var native: Dictionary=original_main_ui_controller.try_open_feature_window(key,args)
	original_main_ui_status[key+"_window"]=native
	if not native.get("handled",false):return false
	if pointer_transfer != null: pointer_transfer.cancel()
	workspace.hide()
	_sync_screen_focus()
	return true

## The original 523 domination stone window (source_main_domination_stone_window).
func open_domination_stone() -> void:
	_open_window("domination_stone","지배석","")
	var native: Dictionary = {"ok":false,"code":"source_domination_window_controller_unavailable"}
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("try_open_domination_window"):
		native = original_main_ui_controller.try_open_domination_window(get_parent())
	original_main_ui_status["domination_window"] = native
	if native.get("handled",false):
		if pointer_transfer != null: pointer_transfer.cancel()
		workspace.hide()
		_sync_screen_focus()
		return
	var note := UI.label("지배석 창은 원본 523 UI 팩(DominationStoneScene)이 필요합니다.\n"+str(native.get("code",native.get("error",""))),14,UI.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace.mount(note)

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

func open_card_fusion(category: String) -> void:
	if not CARD_RULES.CATEGORIES.has(category): return
	card_fusion_return_category = category
	_open_window("card_fusion", category + " 카드 합성", "")
	if _open_original_feature("card_fusion",[category]):return
	var view: Control = CardFusionView.new()
	card_fusion_view = view
	workspace.mount(view)
	view.configure(catalog_data, card_collection_state, category)
	view.fuse_requested.connect(_confirm_card_fusion_request)

func open_catalog(category: String) -> void:
	var started: int = FRAME_HITCH.now()
	_open_catalog_impl(category)
	FRAME_HITCH.detail("ui.catalog_open", started)

func _open_catalog_impl(category: String) -> void:
	_reset_catalog_drag()
	_open_window(category,category,"")
	catalog_category = category
	# The native window owns its selected card and scroll position. Preparing
	# the other browser first loads the same card pictures before hiding it.
	if category in ["변신","마법인형"] and _open_original_change_window(category):
		return
	_open_catalog_browser(category)

func _open_catalog_browser(category: String) -> void:
	catalog_browser_active = true
	workspace.mount(catalog_panel)
	catalog_panel.show()
	catalog_category = category
	if equipment_collection_button != null:
		equipment_collection_button.disabled = false
		equipment_collection_button.text = "장비 컬렉션"
		equipment_collection_button.tooltip_text = "장비 등록 컬렉션 열기 · 각인 구분 없음"
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
	catalog_test_toggle.visible = category == "아이템" and playtest_tools_enabled()
	if is_instance_valid(card_fusion_tab):
		card_fusion_tab.visible = CARD_RULES.CATEGORIES.has(category)
		card_awakening_tab.visible = CARD_RULES.CATEGORIES.has(category)
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
		if CARD_RULES.CATEGORIES.has(category):
			for index: int in range(catalog_filtered_results.size()):
				var record: Dictionary=catalog_filtered_results[index]
				if str(record.get("sourceId",record.get("name","")))==str(saved.get("id","")):
					catalog_page=index/catalog_page_size
					break
		_apply_catalog_page()
		for i: int in range(catalog_results.size()):
			if str(catalog_results[i].get("sourceId",catalog_results[i].get("name",""))) == str(saved.get("id","")): _select_catalog_index(i)
		catalog_list.get_v_scroll_bar().set_deferred("value",float(saved.get("scroll",0)))
		for grade_name: String in catalog_grade_buttons: catalog_grade_buttons[grade_name].button_pressed = grade_name == catalog_grade_filter
	catalog_details_active = false
	_fit_catalog_browser_layout()
	if card_result_label != null:
		card_result_label.text = "뽑기·합성 결과가 이곳에 표시됩니다"
	_refresh_card_controls()
	if category=="성물":
		if not is_instance_valid(relic_reference_view):
			relic_reference_view=preload("res://scripts/ui/relic_reference_view.gd").new()
			catalog_panel.add_child(relic_reference_view)
			relic_reference_view.configure(self)
		relic_reference_view.activate()
	if category in ["변신","마법인형"]:
		if not is_instance_valid(companion_detail_view):
			companion_detail_view=preload("res://scripts/ui/companion_detail_view.gd").new()
			add_child(companion_detail_view)
			companion_detail_view.configure(self)
		companion_detail_view.activate(category)
	if CARD_RULES.CATEGORIES.has(category):
		if not is_instance_valid(catalog_card_chrome):
			catalog_card_chrome=preload("res://scripts/ui/catalog_card_chrome.gd").new()
			add_child(catalog_card_chrome)
			catalog_card_chrome.configure(self)
		catalog_card_chrome.activate()
	if not catalog_results.is_empty() and SourceCardPresentation.native(catalog_results[0]):
		_restore_native_catalog_scroll(category, float(saved.get("scroll", 0)), catalog_icon_generation)

## The original 523 Change_WinTotal shows the owned cards; applying a card
## still goes through catalog_equip_requested (World._equip_catalog).
func _open_original_change_window(category: String) -> bool:
	if not is_instance_valid(original_main_ui_controller) or not original_main_ui_controller.has_method("try_open_change_window"):return false
	var native: Dictionary=original_main_ui_controller.try_open_change_window(category)
	original_main_ui_status["change_window"]=native
	if not native.get("handled",false):return false
	_reset_catalog_drag()
	if is_instance_valid(companion_detail_view):companion_detail_view.deactivate()
	if is_instance_valid(catalog_card_chrome):catalog_card_chrome.deactivate()
	if pointer_transfer!=null:pointer_transfer.cancel()
	workspace.hide()
	_sync_screen_focus()
	return true

func _restore_native_catalog_scroll(category: String, scroll: float, generation: int) -> void:
	# Container reparenting and icon-size changes settle after the first frame.
	# Restore the category view after that reflow, including zero for a new view.
	await get_tree().process_frame
	await get_tree().process_frame
	if catalog_category != category or catalog_icon_generation != generation or not catalog_panel.is_visible_in_tree(): return
	catalog_list.force_update_list_size()
	catalog_list.get_v_scroll_bar().value = scroll

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
	card_fusion_tab = UI.button("합성", func() -> void: open_card_fusion(catalog_category), Vector2(85, 36))
	card_fusion_tab.name = "OpenCardFusion"
	card_awakening_tab = UI.button("각성", _request_option_awakening_open, Vector2(85, 36))
	card_awakening_tab.name = "OpenCardAwakening"
	catalog_view_tabs.add_child(card_fusion_tab)
	catalog_view_tabs.add_child(card_awakening_tab)
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
	# Keep the implemented equipment route visible when the compact layout hides
	# the grade sidebar. Its label never promises an unimplemented card collection.
	equipment_collection_button = UI.button("장비 컬렉션",open_equipment_collections,Vector2(124,40))
	equipment_collection_button.name = "EquipmentCollectionShortcut"
	equipment_collection_button.tooltip_text = "장비 등록 컬렉션 열기 · 각인 구분 없음"
	top.add_child(equipment_collection_button)
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
	ReferenceSurfaces.catalog(self)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(500,0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	var preview_row := HBoxContainer.new()
	preview_row.name = "CatalogPreviewRow"
	# Keep art and description visible while the action column scrolls on phones.
	preview_row.custom_minimum_size.y = 190
	preview_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview_row)
	catalog_preview.reparent(preview_row)
	catalog_preview.custom_minimum_size = Vector2(180,0)
	catalog_preview.size_flags_horizontal = Control.SIZE_FILL
	catalog_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_awakening_catalog_border = OptionAwakeningBorder.new()
	catalog_preview.add_child(option_awakening_catalog_border)
	option_awakening_catalog_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	option_awakening_catalog_border.configure("", false, _option_awakening_settings())
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
	option_awakening_catalog_status = UI.label("", 12, UI.MUTED)
	option_awakening_catalog_status.name = "CatalogOptionAwakeningStatus"
	option_awakening_catalog_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(option_awakening_catalog_status)
	option_awakening_button = OptionAwakeningTouchButton.new()
	option_awakening_button.name = "OpenOptionAwakening"
	option_awakening_button.text = "옵션 각성"
	option_awakening_button.custom_minimum_size.y = 48
	option_awakening_button.pressed.connect(_request_option_awakening_open)
	right.add_child(option_awakening_button)
	halphas_star_enchant_button = UI.button("성급 강화", _request_halphas_star_enchant, Vector2(0, 48))
	halphas_star_enchant_button.name = "OpenHalphasStarEnchant"
	halphas_star_enchant_button.hide()
	right.add_child(halphas_star_enchant_button)
	# Card ownership is a new sidecar state; existing catalog/equip behavior is
	# preserved to avoid invalidating old playtest saves. No paid/free packs
	# exist yet: only debug builds can generate 11-card top-tier samples.
	card_controls = VBoxContainer.new()
	card_controls.name = "CardDrawFusionControls"
	right.add_child(card_controls)
	card_owned_label = UI.label("", 12, UI.MUTED)
	card_owned_label.name = "CardOwnershipSummary"
	card_owned_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_controls.add_child(card_owned_label)
	card_draw_button = UI.button("최상급팩 11회 뽑기 (검수 전용)", _request_card_pack_draw, Vector2(0, 42))
	card_draw_button.name = "CardTopPackDraw"
	card_controls.add_child(card_draw_button)
	var reveal_preview := UI.button("5개 등급 연출 비교 · 보상 없음", _preview_card_reveal_grades, Vector2(0,42))
	card_reveal_preview=reveal_preview
	card_controls.add_child(reveal_preview)
	card_fusion_grade_select = OptionButton.new()
	card_fusion_grade_select.name = "CardFusionGrade"
	card_fusion_grade_select.custom_minimum_size.y = 40
	for grade_name: String in ["일반", "고급", "희귀", "영웅", "전설", "신화"]:
		var target: String = str(CARD_RULES.FUSION_NEXT[grade_name])
		var percent: int = int(CARD_RULES.FUSION_WEIGHTS[grade_name]) / 100
		card_fusion_grade_select.add_item("%s → %s (%d%%)" % [grade_name, target, percent])
	card_fusion_grade_select.item_selected.connect(func(_index: int) -> void: _refresh_card_controls())
	card_controls.add_child(card_fusion_grade_select)
	card_fusion_button = UI.button("중복 카드 합성", _request_card_fusion, Vector2(0, 42))
	card_fusion_button.name = "CardFuseDuplicates"
	card_controls.add_child(card_fusion_button)
	card_result_label = UI.label("뽑기·합성 결과가 이곳에 표시됩니다", 12, UI.GOLD)
	card_result_label.name = "CardDrawFusionResult"
	card_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_controls.add_child(card_result_label)
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
	card_draw_button.reparent(catalog_test_tools)
	reveal_preview.reparent(catalog_test_tools)
	catalog_test_toggle.toggled.connect(func(enabled: bool) -> void: catalog_test_tools.visible = enabled and playtest_tools_enabled())
	catalog_test_tools.add_child(UI.label("개발 빌드 전용 지급 도구",11,UI.GOLD))
	playtest_grant_button = UI.button("선택 아이템 1개 임시 지급",_request_playtest_catalog_grant,Vector2(0,42))
	playtest_grant_button.name = "PlaytestGrantSelected"
	catalog_test_tools.add_child(playtest_grant_button)
	playtest_aden_button = UI.button("아데나 1억 맞추기",_request_playtest_aden,Vector2(0,42))
	playtest_aden_button.name = "PlaytestAden"
	catalog_test_tools.add_child(playtest_aden_button)
	for scroll: String in ["무기 마법 주문서 (각인)","갑옷 마법 주문서 (각인)","장신구 마법 주문서 (각인)"]:
		var grant_name: String = scroll
		var grant := UI.button("테스트 " + grant_name.replace(" (각인)","") + " ×10",func() -> void:
			if playtest_tools_enabled(): playtest_catalog_grant_requested.emit(grant_name,10),Vector2(0,39))
		grant.name = "PlaytestScroll" + str(playtest_scroll_buttons.size())
		catalog_test_tools.add_child(grant)
		playtest_scroll_buttons.append(grant)
	for pack_name: String in ["최상급 변신 뽑기권", "최상급 변신 뽑기권 11회 팩", "최상급 마법인형 뽑기권", "최상급 마법인형 뽑기권 11회 팩", "최상급 성물 뽑기권", "최상급 성물 뽑기권 11회 팩"]:
		var grant_pack_name: String = pack_name
		var ticket_button := UI.button("테스트 " + grant_pack_name + " ×1", func() -> void:
			if playtest_tools_enabled():
				playtest_catalog_grant_requested.emit(grant_pack_name, 1), Vector2(0, 39))
		catalog_test_tools.add_child(ticket_button)
	old.queue_free()

func set_card_collection_state(value: Dictionary) -> void:
	if card_collection_state == value: return
	var previous_owned: Dictionary=card_collection_state.get("owned",{}).get(catalog_category,{})
	var next_owned: Dictionary=value.get("owned",{}).get(catalog_category,{})
	var reorder: bool=previous_owned!=next_owned
	card_collection_state = value.duplicate(true)
	var browser_visible: bool=is_instance_valid(catalog_panel) and catalog_panel.is_visible_in_tree()
	if reorder and browser_visible and active_section==catalog_category and CARD_RULES.CATEGORIES.has(catalog_category) and catalog_list!=null:
		_refresh_catalog_owned_order()
	if browser_visible:
		_refresh_card_controls()
		_refresh_option_awakening_markers()
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("refresh_feature_window"):original_main_ui_controller.refresh_feature_window("card_fusion")
	if active_section == "card_fusion" and is_instance_valid(card_fusion_view) and not card_fusion_view.is_queued_for_deletion():
		card_fusion_view.set_collection_state(card_collection_state)
	elif browser_visible and active_section == catalog_category and CARD_RULES.CATEGORIES.has(catalog_category) and catalog_list != null:
		var selected_indices: PackedInt32Array = catalog_list.get_selected_items()
		if not selected_indices.is_empty() and selected_indices[0] < catalog_results.size():
			_on_catalog_item_selected(selected_indices[0])

func set_option_awakening_state(value: Dictionary) -> void:
	if option_awakening_state == value:
		return
	option_awakening_state = value.duplicate(true)
	_refresh_option_awakening_markers()
	_refresh_option_awakening_entry()

func set_option_awakening_view(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("ok", false)):
		if active_section == "option_awakening" and is_instance_valid(option_awakening_view):
			option_awakening_view.set_snapshot(snapshot)
		show_message(str(snapshot.get("error", "각성 정보를 확인할 수 없습니다.")))
		return
	var category: String = str(snapshot.get("category", ""))
	var target_id: String = str(snapshot.get("target_id", ""))
	var same_target: bool = category == str(option_awakening_snapshot.get("category", "")) and target_id == str(option_awakening_snapshot.get("target_id", ""))
	option_awakening_snapshot = snapshot.duplicate(true)
	if active_section == "option_awakening" and is_instance_valid(option_awakening_view) and not option_awakening_view.is_queued_for_deletion() and same_target:
		option_awakening_view.collection_catalog=catalog_data
		option_awakening_view.collection_ownership=card_collection_state
		option_awakening_view.set_snapshot(snapshot)
		option_awakening_view.apply_settings(_option_awakening_settings())
		return
	if CARD_RULES.CATEGORIES.has(active_section):
		option_awakening_source_detail = catalog_details_active
	_open_window("option_awakening", category + " 옵션 각성", "")
	var view: Control = OptionAwakeningView.new()
	view.collection_catalog=catalog_data;view.collection_ownership=card_collection_state;view.collection_scroll_host=workspace
	option_awakening_view = view
	workspace.mount(view)
	view.configure(snapshot, _option_awakening_settings())
	view.feed_requested.connect(func(materials: Dictionary) -> void:
		option_awakening_feed_requested.emit(category, target_id, materials))
	view.attempt_requested.connect(func() -> void:
		option_awakening_attempt_requested.emit(category, target_id))
	for scroll_name: String in ["AwakeningContentScroll", "AwakeningInfoScroll", "AwakeningConfirmationScroll"]:
		var scroll: ScrollContainer = view.find_child(scroll_name, true, false) as ScrollContainer
		if scroll != null:
			workspace.register_scroll_drag(scroll, scroll)

func is_option_awakening_busy() -> bool:
	# The form locks its own submission before emitting. Do not include that
	# lock here: World's transaction guard must accept the request just emitted.
	return is_instance_valid(option_awakening_reveal) and not option_awakening_reveal.is_queued_for_deletion()

func present_option_awakening_result(record: Dictionary, result: Dictionary, settings: Dictionary = {}) -> void:
	if is_option_awakening_busy() or not bool(result.get("ok", false)) or not result.get("success") is bool:
		return
	# A saved result is supplied by World. This view never rolls or consumes.
	var outcome: Dictionary = result.duplicate(true)
	var snapshot: Dictionary = outcome.get("snapshot", option_awakening_snapshot) as Dictionary
	outcome["category"] = str(outcome.get("category", snapshot.get("category", record.get("category", ""))))
	if not outcome.has("bonus_lines") and bool(outcome.get("success", false)):
		outcome["bonus_lines"] = snapshot.get("applied_options", [])
	if not outcome.has("message"):
		outcome["message"] = "옵션 각성이 완료되었습니다." if bool(outcome.get("success", false)) else "각성에 실패했습니다. 경험치 %d가 남았습니다." % int(snapshot.get("experience", 0))
	var layer := CanvasLayer.new()
	layer.name = "OptionAwakeningRevealLayer"
	layer.layer = 112
	add_child(layer)
	var stage: Control = OptionAwakeningReveal.new()
	option_awakening_reveal = stage
	layer.add_child(stage)
	stage.finished.connect(func() -> void:
		option_awakening_reveal = null
		layer.queue_free()
		_refresh_option_awakening_entry())
	stage.present(record, outcome, _option_awakening_settings() if settings.is_empty() else settings)
	_refresh_option_awakening_entry()

func _option_awakening_settings() -> Dictionary:
	var value: Variant = get_parent().get("presentation_settings") if get_parent() != null else {}
	return value as Dictionary if value is Dictionary else {}

func apply_option_awakening_settings(settings: Dictionary) -> void:
	if is_instance_valid(option_awakening_catalog_border):
		option_awakening_catalog_border.apply_settings(settings)
	if is_instance_valid(option_awakening_view) and not option_awakening_view.is_queued_for_deletion():
		option_awakening_view.apply_settings(settings)

func _option_awakening_card_state(category: String, record: Dictionary) -> Dictionary:
	var categories: Dictionary = option_awakening_state.get("cards", {}) as Dictionary
	var cards: Dictionary = categories.get(category, {}) as Dictionary
	return cards.get(CARD_RULES.card_id(record), {}) as Dictionary

func _refresh_option_awakening_markers() -> void:
	if not is_instance_valid(catalog_panel) or not catalog_panel.is_visible_in_tree():return
	if catalog_list == null or not CARD_RULES.CATEGORIES.has(catalog_category): return
	var owned: Dictionary = (card_collection_state.get("owned", {}) as Dictionary).get(catalog_category, {}) as Dictionary
	var spare: Dictionary = (card_collection_state.get("spare", {}) as Dictionary).get(catalog_category, {}) as Dictionary
	var background_alpha: float=.17 if catalog_category=="성물" else .08
	for index: int in range(mini(catalog_results.size(), catalog_list.item_count)):
		var record: Dictionary = catalog_results[index]
		var identity: String = CARD_RULES.card_id(record)
		var acquired: bool=owned.has(identity)
		catalog_list.set_item_metadata(index,identity)
		catalog_list.set_item_icon(index,CardOwnership.icon_for(record,acquired))
		catalog_list.set_item_icon_modulate(index,Color.WHITE if acquired or CardOwnership.original_current(record) else CardOwnership.UNOWNED_ICON_TINT)
		catalog_list.set_item_custom_bg_color(index,Color(UI.grade(str(record.get("grade","일반"))),background_alpha) if acquired else Color(.2,.2,.2,.04))
		var duplicates: int = maxi(0, int(spare.get(identity, 0)))
		var copies: int = (1 if owned.has(identity) else 0) + duplicates
		var awakened: bool = bool(_option_awakening_card_state(catalog_category, record).get("awakened", false))
		var title: String = str(record.get("name", ""))
		catalog_list.set_item_text(index, ("%s%s\n보유 %d장 · 중복 %d" % ["[각성] " if awakened else "", title, copies, duplicates]) if copies > 0 else title + "\n미보유")
		catalog_list.set_item_tooltip(index, "%s · %s · 총 %d장 · 합성/각성 재료 %d장" % [str(record.get("grade", "")), title, copies, duplicates])
	if is_instance_valid(companion_detail_view) and companion_detail_view.active:
		companion_detail_view.decorate_roster(true)
	if is_instance_valid(catalog_card_chrome):catalog_card_chrome.refresh()

func _refresh_option_awakening_entry() -> void:
	if is_instance_valid(halphas_star_enchant_button):
		halphas_star_enchant_button.visible = HalphasStarEnchant.is_target(catalog_category, selected_catalog_record)
	if not is_instance_valid(option_awakening_button):
		return
	var category_valid: bool = CARD_RULES.CATEGORIES.has(catalog_category)
	option_awakening_button.visible = category_valid
	option_awakening_catalog_status.visible = category_valid
	var record: Dictionary = selected_catalog_record
	var grade_name: String = str(record.get("grade", ""))
	var eligible: bool = category_valid and not record.is_empty() and grade_name in ["영웅", "전설", "신화", "유일"]
	var owned: Dictionary = (card_collection_state.get("owned", {}) as Dictionary).get(catalog_category, {}) as Dictionary
	var acquired: bool = owned.has(CARD_RULES.card_id(record)) if not record.is_empty() else false
	var progress: Dictionary = _option_awakening_card_state(catalog_category, record)
	var awakened: bool = category_valid and bool(progress.get("awakened", false))
	option_awakening_catalog_border.configure(grade_name, awakened, _option_awakening_settings())
	option_awakening_button.disabled = not eligible or not acquired or is_option_awakening_busy() or is_card_reveal_busy() or is_enhancement_presenting()
	option_awakening_button.text = "[각성] 옵션 확인" if awakened else "옵션 각성"
	if not eligible:
		option_awakening_catalog_status.text = "영웅 이상 카드부터 옵션 각성을 진행할 수 있습니다."
	elif not acquired:
		option_awakening_catalog_status.text = "카드를 획득하면 옵션 각성을 진행할 수 있습니다."
	elif awakened:
		option_awakening_catalog_status.text = "[각성] 완료 · 지원 옵션과 각성 표식 적용"
	else:
		option_awakening_catalog_status.text = "각성 경험치 %d / 100 · 중복 카드로 충전" % int(progress.get("experience", 0))
	option_awakening_button.tooltip_text = option_awakening_catalog_status.text

func _request_option_awakening_open() -> void:
	_refresh_option_awakening_entry()
	if not CARD_RULES.CATEGORIES.has(catalog_category): return
	if selected_catalog_record.is_empty():
		show_message("각성할 카드를 도감에서 먼저 선택해 주세요.")
		return
	if option_awakening_button.disabled:
		show_message(option_awakening_catalog_status.text)
		return
	option_awakening_open_requested.emit(catalog_category, CARD_RULES.card_id(selected_catalog_record))

func set_card_draw_fusion_result(category: String, result_text: String) -> void:
	if category == catalog_category and card_result_label != null:
		card_result_label.text = result_text
	if active_section == "card_fusion" and is_instance_valid(card_fusion_view):
		card_fusion_view.set_result(category, result_text)

func is_card_reveal_busy() -> bool:
	return is_instance_valid(card_reveal_stage)

func _new_card_reveal_stage() -> Control:
	var layer := CanvasLayer.new()
	layer.name = "CardRevealLayer"
	layer.layer = 100
	add_child(layer)
	var stage: Control = CARD_REVEAL.new()
	var settings: Dictionary = get_parent().presentation_settings
	stage.reduced_motion = bool(settings.get("reduced_motion",false))
	stage.intensity_scale = clampf(float(settings.get("impact_intensity",0.85)),0.0,1.5)
	stage.detail_scale = 0.6 if str(settings.get("effect_detail","full")) == "low" else 1.0
	card_reveal_stage = stage
	layer.add_child(stage)
	stage.finished.connect(func() -> void:
		card_reveal_stage = null
		layer.queue_free()
		_refresh_card_controls())
	return stage

func _preview_card_reveal_grades() -> void:
	if not playtest_tools_enabled() or is_card_reveal_busy():
		return
	_new_card_reveal_stage().present_showcase()

func present_card_reveal(category: String, awarded: Dictionary, is_fusion: bool) -> void:
	if is_card_reveal_busy() or not bool(awarded.get("ok",false)):
		return
	# Resolve stable IDs against the current game's catalog. No preview rerolls,
	# catalog writes, material consumption or inventory awards occur here.
	var catalog: Array = catalog_data.get(category,[]) as Array
	var by_id: Dictionary = {}
	var candidates: Array[Texture2D] = []
	var candidate_paths: Array[String] = []
	var source_candidate_records: Array = []
	for raw: Variant in catalog:
		if not raw is Dictionary:
			continue
		var record: Dictionary = raw as Dictionary
		by_id[CARD_RULES.card_id(record)] = record
		if SourceCardPresentation.native(record):
			# Native reel images resolve from their original record identities.
			source_candidate_records.append(record)
			continue
		var path: String = str(record.get("image_path",""))
		if not path.is_empty():
			candidate_paths.append(path)
	# The reel used to show the first 8 catalog cards every time, and every card
	# shared the same order, so "모두 뒤집기" spun identical candidates in sync.
	# Sample a random subset; each card shuffles its own copy in the stage.
	candidate_paths.shuffle()
	source_candidate_records.shuffle()
	if source_candidate_records.size() > 16:
		source_candidate_records.resize(16)
	for path: String in candidate_paths:
		if candidates.size() >= 16:
			break
		if ResourceLoader.exists(path):
			var texture: Texture2D = load(path) as Texture2D
			if texture != null:
				candidates.append(texture)
	var raw_awards: Array = (awarded.get("results",[]) as Array).duplicate() if (not is_fusion or bool(awarded.get("batch",false))) else [awarded.get("result",{})]
	var bonus: Dictionary = awarded.get("pity_reward",{}) as Dictionary
	if not bonus.is_empty():
		raw_awards.append(bonus.merged({"pity_reward":true}))
	var views: Array[Dictionary] = []
	for raw: Variant in raw_awards:
		if raw is Dictionary and not (raw as Dictionary).is_empty():
			var result: Dictionary = raw as Dictionary
			views.append((by_id.get(str(result.get("id","")),{}) as Dictionary).merged(result,true).duplicate(true))
	if views.is_empty():
		return
	var stage: Control = _new_card_reveal_stage()
	stage.present(views,candidates,category,is_fusion,bool(awarded.get("success",false)),source_candidate_records.duplicate(true))

func _refresh_card_controls() -> void:
	if not is_instance_valid(catalog_panel) or not catalog_panel.is_visible_in_tree():return
	if is_instance_valid(companion_detail_view):companion_detail_view.refresh()
	if is_instance_valid(relic_reference_view):relic_reference_view.refresh_state()
	ReferenceSurfaces.refresh_grade_counts(self)
	_refresh_option_awakening_entry()
	if card_controls == null or card_fusion_grade_select == null:
		return
	var category: String = catalog_category
	card_controls.visible = CARD_RULES.CATEGORIES.has(category)
	card_draw_button.visible=card_controls.visible and playtest_tools_enabled()
	card_reveal_preview.visible=card_controls.visible and playtest_tools_enabled()
	if not card_controls.visible:
		return
	var all_owned: Dictionary = card_collection_state.get("owned", {}) as Dictionary
	var category_owned: Dictionary = all_owned.get(category, {}) as Dictionary
	var all_spare: Dictionary = card_collection_state.get("spare", {}) as Dictionary
	var category_spare: Dictionary = all_spare.get(category, {}) as Dictionary
	var total_spares: int = 0
	for identity: String in category_spare:
		total_spares += maxi(0, int(category_spare[identity]))
	var all_pity: Dictionary = card_collection_state.get("pity", {}) as Dictionary
	var category_pity: Dictionary = all_pity.get(category, {}) as Dictionary
	card_owned_label.text = "보유 총 %d장 (%d종) · 합성 중복 %d장 · 희귀→영웅 실패 %d/20 · 영웅→전설 실패 %d/20" % [
		category_owned.size() + total_spares, category_owned.size(), total_spares,
		int(category_pity.get("희귀", 0)), int(category_pity.get("영웅", 0))
	]
	var grade_index: int = card_fusion_grade_select.selected
	if grade_index < 0:
		card_fusion_button.disabled = true
		return
	var source_grades: Array[String] = ["일반", "고급", "희귀", "영웅", "전설", "신화"]
	var grade_name: String = source_grades[clampi(grade_index, 0, source_grades.size() - 1)]
	var available: int = 0
	var seen: Dictionary = {}
	for raw: Variant in catalog_data.get(category, []) as Array:
		if not (raw is Dictionary):
			continue
		var record: Dictionary = raw as Dictionary
		if str(record.get("grade", "")) != grade_name:
			continue
		var identity: String = CARD_RULES.card_id(record)
		if identity.is_empty() or seen.has(identity):
			continue
		seen[identity] = true
		available += maxi(0, int(category_spare.get(identity, 0)))
	var required: int = int(CARD_RULES.FUSION_MATERIALS[grade_name])
	card_fusion_button.text = "%s 중복 %d/%d장 합성" % [grade_name, available, required]
	card_fusion_button.disabled = available < required

func _request_card_pack_draw() -> void:
	if playtest_tools_enabled() and CARD_RULES.CATEGORIES.has(catalog_category):
		card_pack_draw_requested.emit(catalog_category)

func _request_card_fusion() -> void:
	if card_fusion_grade_select == null or not CARD_RULES.CATEGORIES.has(catalog_category): return
	if card_fusion_button.disabled: return
	var grades: Array[String] = ["일반", "고급", "희귀", "영웅", "전설", "신화"]
	var grade_name: String = grades[clampi(card_fusion_grade_select.selected, 0, grades.size() - 1)]
	_confirm_card_fusion_request(catalog_category, grade_name)

func _confirm_card_fusion_request(category: String, grade_name: String) -> void:
	if not CARD_RULES.CATEGORIES.has(category) or not CARD_RULES.FUSION_MATERIALS.has(grade_name) or is_card_reveal_busy(): return
	var required: int = int(CARD_RULES.FUSION_MATERIALS[grade_name])
	# Like the 11-card draw, several fusions can run at once (up to 10).
	var available: int = 0
	var seen: Dictionary = {}
	var category_spare: Dictionary = (card_collection_state.get("spare",{}) as Dictionary).get(category,{}) as Dictionary
	for raw: Variant in catalog_data.get(category,[]) as Array:
		if not raw is Dictionary or str((raw as Dictionary).get("grade","")) != grade_name: continue
		var identity: String = CARD_RULES.card_id(raw as Dictionary)
		if identity.is_empty() or seen.has(identity): continue
		seen[identity] = true
		available += maxi(0,int(category_spare.get(identity,0)))
	var batch_limit: int = clampi(available / maxi(1,required),1,10)
	var body: String = "%s %s 중복 카드 %d장을 소모하시겠습니까? 최초 획득 1장은 보존됩니다. 실패하면 같은 등급 카드 1장을 획득합니다." % [
		category, grade_name, required
	]
	if batch_limit > 1:
		body += "\n합성 횟수를 선택하세요 (최대 %d회 · 1회당 %d장)." % [batch_limit, required]
	confirm_action("카드 합성", body, "합성", func(count: int) -> void: card_fusion_requested.emit(category, grade_name, clampi(count,1,10)), batch_limit if batch_limit > 1 else 0)

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
		if SourceCardPresentation.native(record):
			art=CardOwnership.icon_for(record,card_collection_state.get("owned",{}).get(catalog_category,{}).get(CARD_RULES.card_id(record),false)==true)
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
	if is_instance_valid(relic_reference_view) and relic_reference_view.active:
		relic_reference_view.fit_layout()
		return
	if workspace == null or catalog_body_left == null or catalog_body_actions == null: return
	var compact: bool = workspace.content.size.x < 1040
	var short: bool = workspace.content.size.y < 430
	collection_status.visible = not short
	catalog_count.visible = not short
	catalog_preview.custom_minimum_size = Vector2(150 if compact else 180,0)
	catalog_list.fixed_icon_size = Vector2i(78,92) if short else Vector2i(94,116)
	catalog_list.add_theme_constant_override("v_separation",10)
	catalog_search.custom_minimum_size.y = 34
	catalog_view_tabs.visible = (compact or CARD_RULES.CATEGORIES.has(active_section)) and active_section in ["아이템","변신","마법인형","성물"]
	catalog_grade_column.visible = not compact
	rarity_filter.visible = compact
	catalog_body_left.visible = not compact or not catalog_details_active
	catalog_body_actions.visible = not compact or catalog_details_active
	catalog_list.custom_minimum_size.x = 0
	catalog_list.max_columns = 4
	catalog_list.fixed_column_width = 116
	catalog_body_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	catalog_body_actions.custom_minimum_size.x = 0 if compact else 520
	var actions_content: Control = catalog_body_actions.get_child(0)
	actions_content.custom_minimum_size.x = 0 if compact else 500
	catalog_list_tab.disabled = compact and not catalog_details_active
	catalog_details_tab.disabled = compact and catalog_details_active
	if is_instance_valid(companion_detail_view):companion_detail_view.fit_layout()

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
	_filter_catalog_results(filter_text)
	catalog_page=0
	_apply_catalog_page()

func _filter_catalog_results(filter_text: String) -> void:
	ReferenceSurfaces.refresh_grade_counts(self)
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
		if catalog_category=="아이템" and record.get("source_preserved_legacy_catalog",false): continue
		if catalog_category=="아이템" and item_slot_filter!="all" and _item_filter_group(record)!=item_slot_filter: continue
		if catalog_grade_filter!="전체" and str(record.get("grade",""))!=catalog_grade_filter: continue
		var searchable := "%s %s %s %s %s" % [record.get("name",""),record.get("grade",""),record.get("type",""),record.get("sourceId",""),record.get("desc","")]
		if query!="" and not searchable.to_lower().contains(query): continue
		if catalog_category=="성물" and is_instance_valid(relic_reference_view) and not relic_reference_view.matches_type(record):continue
		catalog_filtered_results.append(record)
	if CARD_RULES.CATEGORIES.has(catalog_category):
		catalog_filtered_results.assign(CardOwnership.owned_first(catalog_filtered_results,card_collection_state.get("owned",{}).get(catalog_category,{})))

func _refresh_catalog_owned_order() -> void:
	var identity: String=CARD_RULES.card_id(selected_catalog_record)
	var scroll: float=catalog_list.get_v_scroll_bar().value
	var selected_index: int=-1
	_filter_catalog_results(catalog_search.text)
	for index: int in range(catalog_filtered_results.size()):
		if CARD_RULES.card_id(catalog_filtered_results[index])==identity:
			selected_index=index
			catalog_page=index/catalog_page_size
			break
	_apply_catalog_page()
	if selected_index>=0:_select_catalog_index(selected_index%catalog_page_size)
	catalog_list.get_v_scroll_bar().set_deferred("value",scroll)

func _apply_catalog_page() -> void:
	UI.clear_item_visual(catalog_preview)
	catalog_icon_generation += 1
	var request_id: int = catalog_icon_generation
	super._apply_catalog_page()
	# A fresh relic page starts at its first row; open_catalog restores saved views afterwards.
	if catalog_category=="성물":catalog_list.get_v_scroll_bar().value=0
	var source_card_images: Dictionary = {}
	var owned_cards: Dictionary = card_collection_state.get("owned",{}).get(catalog_category,{})
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
			if SourceCardPresentation.native(record):
				var acquired: bool = owned_cards.get(CARD_RULES.card_id(record),false) == true
				var original: Dictionary = SourceCardPresentation.detail(record,acquired,false)
				catalog_list.set_item_icon(index,original.get("texture") as Texture2D)
				var evidence: Dictionary = original.duplicate(true)
				evidence.erase("texture")
				source_card_images[index] = evidence
			else:
				var path := str(record.get("image_path", ""))
				if path != "" and ResourceLoader.exists(path):
					catalog_list.set_item_icon(index, load(path) as Texture2D)
		catalog_list.set_item_tooltip(index,"%s · %s · 원본 ID: %s" % [grade_name,record.get("name",""),record.get("sourceId","")])
	catalog_list.set_meta("source523_card_images",source_card_images)
	_refresh_option_awakening_markers()
	_refresh_option_awakening_entry()
	if catalog_results.is_empty():
		catalog_detail.text="검색 조건에 맞는 기록이 없습니다."
		catalog_equip_button.disabled=true
	(catalog_panel.find_child("ClearCatalog",true,false) as Button).visible=catalog_category!="아이템"
	if is_instance_valid(relic_reference_view):relic_reference_view.refresh_state(true)
	if is_instance_valid(catalog_card_chrome):catalog_card_chrome.refresh()
	if is_instance_valid(companion_detail_view):companion_detail_view.refresh()
	SourceCardPresentation.apply(self)
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
	if not playtest_tools_enabled() or catalog_category != "아이템" or selected_catalog_record.is_empty():
		return
	var source_id: String = str(selected_catalog_record.get("sourceId", ""))
	if source_id != "":
		playtest_catalog_variant_grant_requested.emit(source_id, 1)
	else:
		playtest_catalog_grant_requested.emit(str(selected_catalog_record.get("name", "")), 1)

func _request_playtest_aden() -> void:
	if playtest_tools_enabled(): playtest_aden_grant_requested.emit()

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
		_refresh_option_awakening_entry()
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
		var native_details: String = preload("res://scripts/loot/patch523_monster_drops.gd").item_details(selected_catalog_record)
		if not native_details.is_empty(): catalog_detail.text += "\n\n" + UI.safe(native_details)
		catalog_detail.text += "\n\n" + UI.safe(preload("res://scripts/loot/patch523_monster_drops.gd").source_text(selected_catalog_record))
		match str(selected_catalog_record.get("grade_evidence","")):
			"inven_item_quality":
				catalog_detail.text+="\n등급 판정: 원본 아이템 DB 등급 확인"
			"inven_original_artwork_filename":
				catalog_detail.text+="\n등급 판정: 원본 이미지 파일명 기반 (검증 필요)"
			"inven_item_quality_unmapped":
				catalog_detail.text+="\n등급 판정: 원본 특수 분류 · 표준 등급 미확인"
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
		var unlocks: Dictionary = card_collection_state.get("owned", {}) as Dictionary
		var category_unlocks: Dictionary = unlocks.get(catalog_category, {}) as Dictionary
		var extras: Dictionary = card_collection_state.get("spare", {}) as Dictionary
		var category_extras: Dictionary = extras.get(catalog_category, {}) as Dictionary
		var identity: String = CARD_RULES.card_id(selected_catalog_record)
		var duplicates: int = maxi(0, int(category_extras.get(identity, 0)))
		var copies: int = (1 if category_unlocks.has(identity) else 0) + duplicates
		catalog_detail.text += "\n카드 보유: %d장 · 합성/각성 재료: 중복 %d장" % [copies, duplicates]
		if copies > 0: catalog_detail.text += "\n첫 획득 1장은 영구 보유하며 소모되지 않습니다."
	_refresh_option_awakening_entry()
	if is_instance_valid(relic_reference_view):relic_reference_view.refresh_state()
	if is_instance_valid(catalog_card_chrome):catalog_card_chrome.refresh()
	if is_instance_valid(companion_detail_view):companion_detail_view.refresh()
	SourceCardPresentation.apply(self)

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
				if SourceCardPresentation.native(record):SourceCardPresentation.apply(self)
				else:
					catalog_equip_button.text="현재 적용 중"
					catalog_equip_button.disabled=true)

func toggle_map() -> void:
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_world_map_binding():
		if not original_main_ui_controller.world_map_is_open():_close_workspace()
		original_main_ui_status["world_map"]=original_main_ui_controller.toggle_world_map()
		if not original_main_ui_status.world_map.get("ok",false):show_message("원본 지도 데이터를 사용할 수 없습니다.")
		return
	if active_section=="map" and workspace.visible:
		_close_workspace()
		return
	_open_window("map","월드맵","지역을 선택하면 기존 이동 기능으로 해당 지역에 진입합니다.")
	var col: VBoxContainer=workspace.column()
	col.add_child(UI.label("WORLD OF ADEN",20,UI.GOLD))
	col.add_child(UI.button("포탈·출현 정보", func() -> void: preload("res://scripts/ui/patch523_world_panel.gd").open(self), Vector2(180,36)))
	col.get_child(col.get_child_count()-1).name = "OpenWorldLinks"
	var row := HBoxContainer.new()
	row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var regions := VBoxContainer.new()
	regions.custom_minimum_size.x=270
	row.add_child(regions)
	var region_count: Label = UI.label("지역 선택  ·  %d개 지역" % map_records.size(),15)
	region_count.name = "RegionCount"
	regions.add_child(region_count)
	region_selection=preload("res://scripts/ui/native_touch_list.gd").new()
	region_selection.name="RegionSelection"
	region_selection.size_flags_vertical=Control.SIZE_EXPAND_FILL
	regions.add_child(region_selection)
	for record: Dictionary in map_records:
		var index: int = region_selection.add_item(str(record.get("name",record.get("id",""))))
		region_selection.set_item_metadata(index,str(record.id))
	_add_original_map_controls(regions)
	var enter := preload("res://scripts/ui/native_touch_button.gd").new()
	enter.text = "선택 지역으로 이동"
	enter.custom_minimum_size.y = 44
	enter.pressed.connect(func() -> void:
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

## The original 523 skill window (Skill_All, source_main_skill_window) first;
## the existing skills window otherwise and for a skill's details.
func open_skills() -> void:
	_open_window("skills","스킬","")
	var native: Dictionary={"ok":false,"code":"source_skill_window_controller_unavailable"}
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("try_open_skill_window"):
		native=original_main_ui_controller.try_open_skill_window()
	original_main_ui_status["skill_window"]=native
	if native.get("handled",false):
		if pointer_transfer!=null:pointer_transfer.cancel()
		workspace.hide()
		_sync_screen_focus()
		return
	if is_instance_valid(original_main_ui_controller):_report_original_fallback("스킬",native)
	open_skills_workspace()

func open_skills_workspace(focus: String="") -> void:
	_open_window("skills","스킬","")
	skills_view=SkillsUI.new()
	workspace.mount(skills_view)
	skills_view.configure(self)
	if not focus.is_empty() and skills_view.has_method("focus_skill"):skills_view.call("focus_skill",focus)

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
	if _open_original_enchant("",[]): return
	var forge := ForgeUI.new()
	workspace.mount(forge)
	forge.configure_scrolls(self)

func is_enhancement_presenting() -> bool:
	return is_instance_valid(enhancement_reveal) and not enhancement_reveal.is_queued_for_deletion()

func show_enhancement_result(result_type: String, item_name: String, from_level: int, to_level: int) -> void:
	# The authoritative transaction has already rolled. This screen only presents it.
	if is_enhancement_presenting(): return
	var layer := CanvasLayer.new()
	layer.name = "EnhancementRevealLayer"
	layer.layer = 110
	add_child(layer)
	var stage: Control = EnhancementReveal.new()
	var settings: Dictionary = get_parent().presentation_settings
	stage.reduced_motion = bool(settings.get("reduced_motion",false))
	stage.intensity = clampf(float(settings.get("impact_intensity",0.85)),0.0,1.5)
	stage.low_detail = str(settings.get("effect_detail","full")) == "low"
	enhancement_reveal = stage
	layer.add_child(stage)
	var record: Dictionary = get_parent()._find_catalog_item_record(item_name)
	stage.present(result_type,item_name,from_level,to_level,UI.item_icon(record,item_name,item_image_index.get("아이템",{})))
	stage.finished.connect(func() -> void:
		enhancement_reveal = null
		layer.queue_free())

func open_blessing_targets(scroll_name: String, candidates: Array) -> void:
	_open_window("enhance", "장비 축복 부여", scroll_name + " · 장비 개체별 축복")
	var forge := ForgeUI.new()
	workspace.mount(forge)
	forge.configure_blessing(self, scroll_name, candidates)
	enhancement_forge=forge

var enhancement_forge: Control

## The original 523 EnchantScene (source_main_enchant_window) over the same
## candidates; false -> the caller opens the TWILIGHT forge (reported).
func _open_original_enchant(scroll_name: String, candidates: Array) -> bool:
	if not is_instance_valid(original_main_ui_controller) or not original_main_ui_controller.has_method("try_open_enchant_window"): return false
	var native: Dictionary = original_main_ui_controller.try_open_enchant_window(scroll_name,candidates)
	original_main_ui_status["enchant_window"] = native
	if native.get("handled",false):
		if pointer_transfer != null: pointer_transfer.cancel()
		workspace.hide()
		_sync_screen_focus()
		return true
	_report_original_fallback("장비 강화",native)
	return false

func open_enhancement(scroll_name: String, candidates: Array) -> void:
	if active_section == "enhance" and is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("enchant_window_is_open") and original_main_ui_controller.enchant_window_is_open():
		enhancement_scroll_name = scroll_name
		enhancement_candidates = candidates.duplicate(true)
		if _open_original_enchant(scroll_name,candidates): return
	# Same scroll, window still open (the usual "강화 → 결과 → 다시 강화"
	# loop): update the rows in place instead of rebuilding the whole window.
	if active_section == "enhance" and is_instance_valid(enhancement_forge) and enhancement_forge.is_inside_tree() \
			and str(enhancement_forge.get("mode")) == "target" and enhancement_scroll_name == scroll_name:
		enhancement_candidates = candidates.duplicate(true)
		enhancement_forge.call("refresh_targets", candidates)
		_bind_original_enhance_action(enhancement_forge)
		return
	enhancement_scroll_name = scroll_name
	enhancement_candidates = candidates.duplicate(true)
	_open_window("enhance","장비 강화",scroll_name+" · 실제 게임 강화 확률")
	if _open_original_enchant(scroll_name,candidates): return
	var forge := ForgeUI.new()
	workspace.mount(forge)
	forge.configure_targets(self,scroll_name,candidates)
	enhancement_forge = forge
	_bind_original_enhance_action(forge)

func _bind_original_enhance_action(forge: Control) -> void:
	if is_instance_valid(original_main_ui_controller):original_main_ui_status["enhance_action"]=original_main_ui_controller.bind_enhance_action(forge)

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
	if get_parent().field_map is OriginalPlayableField and get_parent().field_map.uses_original_gameplay_rules():
		selector.select(1)
		populate.call()
	regions.add_child(UI.label("본토: 자체 제작 타일 v1 · 기타: 이미지 미확보",11,UI.MUTED))
	regions.add_child(UI.label("NPC 서비스·본토 보스: TWILIGHT 임시 연결",11,UI.MUTED))


func open_normal_card_collections(category: String,identity: String="") -> void:
	if not CARD_RULES.CATEGORIES.has(category):return
	normal_card_collection_category=category;normal_card_collection_focus=identity
	_open_window("card_collections",category+" 컬렉션","")
	if _open_original_feature("card_collection",[category,identity]):return
	normal_card_collection_view=preload("res://scripts/cards/collection_view.gd").new()
	workspace.mount(normal_card_collection_view)
	normal_card_collection_view.configure(self,category,identity)

func refresh_normal_card_collections() -> void:
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("refresh_feature_window"):original_main_ui_controller.refresh_feature_window("card_collection")
	if active_section=="card_collections" and is_instance_valid(normal_card_collection_view) and not normal_card_collection_view.is_queued_for_deletion():
		normal_card_collection_view.refresh()


func open_equipment_collections() -> void:
	_open_window("equipment_collections","장비 컬렉션","등록 장비 소모 · 요구 강화 일치 · 각인 구분 없음")
	var screen := EquipmentCollectionsUI.new()
	workspace.mount(screen)
	screen.configure(self)

func open_growth(section: String) -> void:
	_open_window(section,"문양" if section == "emblems" else "수호성","")
	var screen := preload("res://scripts/growth/growth_view.gd").new()
	workspace.mount(screen)
	screen.configure(self,section)

func open_growth96() -> void:
	_open_window("growth96","96레벨 보상·증표","")
	growth96_view = Growth96UI.new()
	workspace.mount(growth96_view)
	growth96_view.configure(self,get_parent().growth96)

func open_expedition() -> void:
	var world: Node = get_parent()
	_open_window("expedition", "인형 탐험·변신 파견·성령 수집", "원본 조건·비용·시간 · 이벤트·정산 대기")
	var screen := preload("res://scripts/expedition/source_view.gd").new()
	workspace.mount(screen)
	screen.configure(world.get_expedition_catalog(), world.expedition_owned_cards(), world.expedition_local, self)

func refresh_card_skill_awakening_growth() -> void:
	if active_section=="card_skill_awakening" and is_instance_valid(card_skill_awakening_view) and not card_skill_awakening_view.is_queued_for_deletion():card_skill_awakening_view.refresh_growth()

func _unregistered_card_source_operation(operation: String) -> Dictionary:
	var result: Dictionary=CardSourcePresentation.request(operation)
	show_message(str(result.error))
	return result

func open_native_card_craft() -> Dictionary:
	return _unregistered_card_source_operation(CardSourcePresentation.CRAFT)

func open_card_skill_growth(_category: String,_identity: String) -> Dictionary:
	return _unregistered_card_source_operation(CardSourcePresentation.GROWTH)

func open_card_skill_awakening(category: String, identity: String) -> void:
	if not CardSourcePresentation.available(CardSourcePresentation.AWAKENING):
		_unregistered_card_source_operation(CardSourcePresentation.AWAKENING);return
	var runtime: Variant=get_parent().get("skill_awakening")
	if runtime==null:show_message("스킬 각성 런타임 연결 없음");return
	_open_window("card_skill_awakening",category+" 스킬 각성","")
	if _open_original_feature("card_awakening",[category,identity]):return
	var scroll:=ScrollContainer.new()
	scroll.name="CardSkillAwakeningScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	workspace.mount(scroll)
	var view: Control=preload("res://scripts/ui/card_skill_awakening_view.gd").new()
	card_skill_awakening_view=view
	scroll.add_child(view)
	view.configure(runtime,identity)
	workspace.register_scroll_drag(scroll,view)


func open_source_dungeons() -> void:
	_open_window("source_dungeons","던전","입장 조건 · 목표 · 보상 · 등장 계획")
	var view := SourceDungeonUI.new()
	view.name = "SourceDungeonView"
	workspace.mount(view)
	view.configure(get_parent())
	# The dungeon model is released again when this window closes.
	view.tree_exiting.connect(func() -> void:
		var world: Node = get_parent()
		if is_instance_valid(world) and world.has_method("_release_idle_original_models"): world._release_idle_original_models())


func refresh_source_dungeon_progress() -> void:
	if active_section != "source_dungeons" or dungeon_progress_refresh_pending: return
	dungeon_progress_refresh_pending = true
	call_deferred("_refresh_source_dungeon_progress_deferred")

func _refresh_source_dungeon_progress_deferred() -> void:
	dungeon_progress_refresh_pending = false
	if active_section != "source_dungeons" or not is_instance_valid(workspace): return
	var view: Node = workspace.find_child("SourceDungeonView",true,false)
	if is_instance_valid(view) and not view.is_queued_for_deletion(): view._select(int(view.selected))

func _request_halphas_star_enchant() -> void:
	open_halphas_star_enchant(catalog_category, CARD_RULES.card_id(selected_catalog_record))

func open_halphas_star_enchant(category: String, identity: String) -> void:
	var snapshot: Dictionary = HalphasStarEnchant.from_world(get_parent(), category, identity)
	if not snapshot.ok:
		show_message(str(snapshot.get("error", "성급 강화 대상이 아닙니다")))
		return
	_open_window("halphas_star_enchant", "해방된 할파스 성급 강화", "")
	var scroll := ScrollContainer.new()
	scroll.name = "HalphasStarEnchantScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.mount(scroll)
	var view := preload("res://scripts/ui/halphas_star_enchant_view.gd").new()
	scroll.add_child(view)
	view.configure(get_parent(), category, identity)
	workspace.register_scroll_drag(scroll, view)

func open_combinations() -> void:
	_open_window("combinations","변신·인형·장비 조합","")
	var scroll:=ScrollContainer.new();scroll.name="CombinationScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	workspace.mount(scroll)
	var view: Control=preload("res://scripts/combinations/view.gd").new();scroll.add_child(view);view.configure(self)
	workspace.register_scroll_drag(scroll,view)

func open_half_elixir(item_name: String = "") -> void:
	_open_window("half_elixir", "하프 엘릭서", "사용 포인트 충전과 능력치 투자·확장·초기화를 구분합니다.")
	if item_name.is_empty() and _open_original_feature("half_elixir"):return
	var view = preload("res://scripts/growth/half_elixir_view.gd").new()
	workspace.mount(view)
	view.configure(self)
	if not item_name.is_empty(): view.offer_item(item_name)


func open_titles523() -> void:
	_open_window("titles","작위 심사","")
	if _open_original_feature("titles"):return
	var screen := preload("res://scripts/titles/title_view523.gd").new()
	workspace.mount(screen)
	screen.configure(self)
## original=false (the original window's totem tap) opens the TWILIGHT
## totem view for 성장/제작/설정 on `totem_id`.
func open_totems(original: bool = true, totem_id: int = 0) -> void:
	_open_window("totems","토템","활성화 진행도 · 성장 정보 · 공명")
	if original and _open_original_feature("totems"):return
	totem_view = preload("res://scripts/progression/totem_view.gd").new()
	if totem_id > 0: totem_view.selected_id = totem_id
	workspace.mount(totem_view)
	totem_view.configure(self)

func refresh_totems() -> void:
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("refresh_feature_window"):original_main_ui_controller.refresh_feature_window("totems")
	if active_section == "totems" and is_instance_valid(totem_view) and not totem_view.is_queued_for_deletion() and totem_view.content != null:
		totem_view._refresh()
func open_monsterbook523() -> void:
	_open_window("monsterbook523", "몬스터 도감", "처치 누적 · 단계 등록 · 옵션 · 보상 기록")
	if _open_original_feature("monsterbook"):return
	var screen := preload("res://scripts/monsterbook/monsterbook523_panel.gd").new()
	workspace.mount(screen)
	screen.configure(get_parent())
func open_protection523() -> void:
	_open_window("protection523","불멸·파멸의 가호","보유 · 명예 코인 사용 · 제작과 영구 호칭")
	var scroll := ScrollContainer.new()
	scroll.name = "ProtectionFullScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.mount(scroll)
	var view := preload("res://scripts/protection/protection523_panel.gd").new()
	scroll.add_child(view)
	view.configure(self)


## The original 523 질서의 연금 window (RefineScene, source_main_refine_window).
## Without the UI pack (or the definition ZIP) the 용해·질서의 연금 panel opens.
func open_refine523() -> void:
	_open_window("refine523","질서의 연금","")
	var native: Dictionary = {"ok":false,"code":"source_refine_window_controller_unavailable"}
	if is_instance_valid(original_main_ui_controller) and original_main_ui_controller.has_method("try_open_refine_window"):
		native = original_main_ui_controller.try_open_refine_window(get_parent())
	original_main_ui_status["refine_window"] = native
	if native.get("handled",false):
		if pointer_transfer != null: pointer_transfer.cancel()
		workspace.hide()
		_sync_screen_focus()
		return
	if is_instance_valid(original_main_ui_controller): _report_original_fallback("질서의 연금",native)
	open_bless_refine523()

func open_bless_refine523() -> void:
	_open_window("bless_refine523","용해 · 질서의 연금","원본523 축복의 가루 용해 · 상급 축복의 가루 질서의 연금")
	var scroll := ScrollContainer.new()
	scroll.name = "BlessRefine523Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.mount(scroll)
	var view := preload("res://scripts/refine523/bless_refine523_panel.gd").new()
	scroll.add_child(view)
	view.configure(self)

func open_equipment523(_snapshot: Dictionary) -> void:
	show_message("원본 장비 가공 UI 연결 대기 · 거래 데이터와 소유 상태 보존")

func equipment523_refresh(snapshot: Dictionary) -> void:
	if is_instance_valid(equipment523_view): equipment523_view.call("set_snapshot",snapshot)

func equipment523_quote_result(result: Dictionary) -> void:
	if is_instance_valid(equipment523_view): equipment523_view.call("show_quote",result)

func equipment523_action_result(result: Dictionary) -> void:
	if is_instance_valid(equipment523_view): equipment523_view.call("show_result",result)
# Original CSB presentation is supplied by the UI owner. These adapters do not
# create forms, select content from filenames, or implement service operations.
var original_ui_runtime_presenter: Node
var original_main_ui_controller: Node
var _original_npc_dialogue_owner: WeakRef
var _original_system_message_priority: int=LOCAL_SYSTEM_MESSAGE_PRIORITY_ESTIMATE
var _original_system_message_routing: Dictionary={"kind":"TWILIGHT_ESTIMATE","field":"local_show_message_priority","value":2,"original_rule_confirmed":false}
var original_main_ui_status: Dictionary={}
var _original_main_player_values: Array=[]
var _original_main_map_value: String=""
var _original_main_has_map_name: bool=false
var _original_world_map_inputs: Dictionary={}
var _original_icon_scene_provider: Callable
var _original_npc_portrait_inputs: Dictionary={}

func bind_original_npc_dialogue_portrait(context_provider: Callable, image_provider: Callable) -> Dictionary:
	if not context_provider.is_valid() or not image_provider.is_valid():return {"ok":false,"code":"source_npc_portrait_context_and_image_providers_required"}
	_original_npc_portrait_inputs={"context_provider":context_provider,"image_provider":image_provider}
	if not is_instance_valid(original_main_ui_controller):return {"ok":true,"registered":true,"source_controller_pending":true,"authoritative_mobile_npc_class_context_required":true}
	var result: Dictionary=original_main_ui_controller.bind_npc_dialogue_portrait(context_provider,image_provider)
	original_main_ui_status["npc_portrait_registration"]=result
	if result.get("ok",false) and original_main_ui_controller.npc_dialogue_is_open():
		var owner: Object=_original_npc_dialogue_owner.get_ref() if _original_npc_dialogue_owner!=null else null
		if owner is Control and owner.get("source_dialogue_model") is Dictionary:_on_source_npc_dialogue_resolved(owner.get("source_dialogue_model"),owner)
	return result

func bind_original_icon_scene_provider(provider: Callable) -> Dictionary:
	if not provider.is_valid():return {"ok":false,"code":"source_native_icon_scene_provider_required"}
	_original_icon_scene_provider=provider
	if is_instance_valid(original_main_ui_controller):original_main_ui_controller.refresh_source_icons()
	return {"ok":true,"registered":true,"original_scene_registration_and_playback_required":true,"game_state_written":false}

func original_quickslot_hit_at(viewport_point: Vector2) -> Dictionary:
	return original_main_ui_controller.quickslot_hit_at(viewport_point) if is_instance_valid(original_main_ui_controller) else {}

func original_quickslot_control(visible_index: int) -> Control:
	if is_instance_valid(original_main_ui_controller):
		var native: Control=original_main_ui_controller.quickslot_control(visible_index)
		if is_instance_valid(native):return native
	return v20_quickslot_buttons[visible_index] if visible_index>=0 and visible_index<v20_quickslot_buttons.size() else null

func original_inventory_is_open() -> bool:
	return is_instance_valid(original_main_ui_controller) and original_main_ui_controller.inventory_is_open()

func original_inventory_name_hint_context(reference: String) -> Dictionary:
	return original_main_ui_controller.inventory_name_hint_context(reference) if original_inventory_is_open() else {}

func original_inventory_hit_at(viewport_point: Vector2) -> Dictionary:
	if not original_inventory_is_open():return {}
	var hit: Dictionary=original_main_ui_controller.inventory_hit_at(viewport_point)
	if not hit.is_empty():hit["source_native"]=true
	return hit

func original_source_pointer_capture_blocked(viewport_point: Vector2) -> bool:
	if not is_instance_valid(original_main_ui_controller):return false
	if original_main_ui_controller.world_map_is_open():return true
	if original_main_ui_controller.npc_dialogue_is_open():return true
	if original_main_ui_controller.inventory_search_is_open():return true
	if original_main_ui_controller.crafting_search_is_open():return true
	if original_main_ui_controller.inventory_lock_blocks_point(viewport_point):return true
	if original_main_ui_controller.character_blocks_point(viewport_point):return true
	if original_main_ui_controller.dungeon_blocks_point(viewport_point):return true
	if original_main_ui_controller.workspace_controls_block_point(viewport_point):return true
	return original_main_ui_controller.inventory_blocks_point(viewport_point)

func original_inventory_gesture_bounds() -> Control:
	return original_main_ui_controller.inventory_gesture_bounds() if original_inventory_is_open() else null

func original_inventory_select(reference: String) -> Dictionary:
	if not original_inventory_is_open():return {"ok":false,"code":"source_inventory_not_open"}
	return original_main_ui_controller.inventory_select(reference)

func original_inventory_activate_selected(reference: String) -> Dictionary:
	if not original_inventory_is_open():return {"ok":false,"code":"source_inventory_not_open"}
	return original_main_ui_controller.inventory_activate_selected(reference)

func _restore_current_inventory_view(reason: Dictionary) -> void:
	# Diagnostics must not keep a retired native scene's textures/controls.
	original_main_ui_status["inventory"]=_inventory_status_summary(reason)
	if active_section!="inventory":return
	_report_original_fallback("가방",reason)
	# Restore the same current bag after an unsupported native state. This
	# adds no alternate form, asset lookup, selection, ownership or save logic.
	if pointer_transfer!=null:pointer_transfer.cancel()
	if workspace!=null:workspace.show()
	lineage_inventory_ui.show()
	lineage_inventory_ui.show_inventory()

func _original_inventory_closed() -> void:
	original_main_ui_status["inventory"]={"ok":true,"closed":true,"handled":false}
	if pointer_transfer!=null:pointer_transfer.cancel()
	if active_section=="inventory" and workspace!=null and not workspace.visible:active_section=""

func _inventory_status_summary(reason: Dictionary) -> Dictionary:
	var summary: Dictionary={}
	for key: String in ["ok","handled","closed","code","error","status","member","reference"]:
		var value: Variant=reason.get(key)
		if value is String or value is bool or value is int or value is float:summary[key]=value
	return summary

func _retire_original_menu_status() -> void:
	for section: String in ["inventory","character_equipment","character_stats","quest_window","shop_window","change_window","npc_dialogue","enhance_action","quest_controls","emblem_window","domination_window","status_board","acquisition_popup"]:
		if not original_main_ui_status.has(section):continue
		var previous: Variant=original_main_ui_status[section]
		var summary: Dictionary=_inventory_status_summary(previous) if previous is Dictionary else {}
		summary.merge({"closed":true,"handled":false},true)
		original_main_ui_status[section]=summary

func bind_original_world_map(image_adapter: RefCounted, context_provider: Callable, input_handler: Callable) -> Dictionary:
	if image_adapter==null or not context_provider.is_valid() or not input_handler.is_valid():return {"ok":false,"code":"source_world_map_existing_owner_inputs_required"}
	if not is_instance_valid(original_main_ui_controller):
		_original_world_map_inputs={"image_adapter":image_adapter,"context_provider":context_provider,"input_handler":input_handler}
		return {"ok":true,"registered":true,"waiting_for_main_ui":true,"complete_screen_contract":false}
	var result: Dictionary=original_main_ui_controller.bind_world_map(image_adapter,context_provider,input_handler)
	if result.get("ok",false):_original_world_map_inputs={"image_adapter":image_adapter,"context_provider":context_provider,"input_handler":input_handler}
	return result

func _bind_selected_original_main_ui() -> void:
	var selected: Dictionary=preload("res://scripts/ui/original_ui/source_main_selection.gd").selected_pack()
	if not selected.get("selected",false):
		original_main_ui_bind_problem={"ok":false,"code":"source_ui_addon_not_selected"}
		print("ORIGINAL_UI_BIND ",JSON.stringify(original_main_ui_bind_problem))
		return
	if not selected.get("ok",false):
		original_main_ui_status=selected
		original_main_ui_bind_problem=_inventory_status_summary(selected)
		print("ORIGINAL_UI_BIND ",JSON.stringify(original_main_ui_bind_problem))
		return
	original_main_ui_status=bind_original_main_ui(selected.pack)
	original_main_ui_bind_problem={} if original_main_ui_status.get("ok",false) else _inventory_status_summary(original_main_ui_status)
	print("ORIGINAL_UI_BIND ",JSON.stringify(original_main_ui_bind_problem if not original_main_ui_bind_problem.is_empty() else {"ok":true}))

## Why the original UI did not bind at all (empty once it did).
var original_main_ui_bind_problem: Dictionary={"ok":false,"code":"source_ui_not_bound_yet"}

## A window that opened as the TWILIGHT window instead of its original one:
## the reason goes to the log (logcat) and a short line to the player.
func _report_original_fallback(window: String, reason: Dictionary) -> void:
	var code: String=str(reason.get("code",reason.get("error","")))
	print("ORIGINAL_UI_FALLBACK ",JSON.stringify({"window":window,"reason":_inventory_status_summary(reason),"ui_addon_sha256":OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")}))
	show_message("%s: 원본 창 대신 TWILIGHT 창 · %s" % [window,_original_fallback_text(code)])

## An older UI add-on lacks the window's CSB members (or carries a different
## Inventory_All): the player is told to update it.
const OUTDATED_UI_ADDON_TEXT: String="UI 추가 리소스가 오래되었습니다 → 설정에서 UI 추가 리소스를 업데이트하세요"

static func _original_fallback_text(code: String) -> String:
	if code.ends_with("_member_missing") or code.ends_with("_identity_mismatch") or code=="source_inventory_original_pack_scope_unavailable":return OUTDATED_UI_ADDON_TEXT
	var known: Dictionary={
		"source_ui_addon_not_selected":"원작 메인 화면(UI) 추가 리소스가 설치·선택되지 않음",
		"source_ui_selection_pair_required":"UI 추가 리소스 경로·SHA가 함께 지정되지 않음",
		"source_ui_not_bound_yet":"원본 UI가 아직 연결되지 않음",
		"source_main_not_configured":"원본 메인 화면이 준비되지 않음",
		"source_inventory_view_detail_not_supported":"아이템 상세 화면이 열린 상태",
	}
	return str(known.get(code,code if not code.is_empty() else "사유 미상"))

func bind_original_main_ui(source_pack: RefCounted) -> Dictionary:
	var reopen_character: bool=is_instance_valid(original_main_ui_controller) and original_main_ui_controller.character_is_open()
	var reopen_dialogue: bool=is_instance_valid(original_main_ui_controller) and original_main_ui_controller.npc_dialogue_is_open()
	var candidate=preload("res://scripts/ui/original_ui/source_main_hud.gd").new()
	candidate.name="OriginalMainGameHUD"
	add_child(candidate)
	var configured: Dictionary=candidate.configure(source_pack,self,$Root)
	if not configured.get("ok",false):
		candidate.release(true)
		candidate.queue_free()
		if is_instance_valid(original_main_ui_controller):original_main_ui_controller.sync_legacy_visibility()
		return configured
	candidate.update_currency_balances(currency_balances)
	if _original_main_has_map_name:candidate.update_map_name(_original_main_map_value)
	if not _original_main_player_values.is_empty():
		var mounted: Dictionary=candidate.callv("update_player",_original_main_player_values)
		if not mounted.get("ok",false):
			candidate.release(true)
			candidate.queue_free()
			if is_instance_valid(original_main_ui_controller):original_main_ui_controller.sync_legacy_visibility()
			return mounted
	if is_instance_valid(original_main_ui_controller):
		original_main_ui_controller.release(false)
		original_main_ui_controller.queue_free()
	original_main_ui_controller=candidate
	candidate.inventory_return_to_current_requested.connect(_restore_current_inventory_view)
	candidate.inventory_closed.connect(_original_inventory_closed)
	candidate.world_image_clicked.connect(func(payload: Dictionary) -> void: original_world_map_image_clicked.emit(payload))
	var map_registration: Dictionary={}
	if not _original_world_map_inputs.is_empty():
		map_registration=candidate.bind_world_map(_original_world_map_inputs.image_adapter,_original_world_map_inputs.context_provider,_original_world_map_inputs.input_handler)
	var npc_portrait_registration: Dictionary={}
	if not _original_npc_portrait_inputs.is_empty():npc_portrait_registration=candidate.bind_npc_dialogue_portrait(_original_npc_portrait_inputs.context_provider,_original_npc_portrait_inputs.image_provider)
	candidate.sync_legacy_visibility()
	candidate.refresh_quickslots()
	var system_message: Dictionary=candidate.set_system_message_priority(_original_system_message_priority,_original_system_message_routing)
	if reopen_character:open_character()
	if reopen_dialogue:
		var owner: Object=_original_npc_dialogue_owner.get_ref() if _original_npc_dialogue_owner!=null else null
		if owner is Control and owner.get("source_dialogue_model") is Dictionary:_on_source_npc_dialogue_resolved(owner.get("source_dialogue_model"),owner)
	if active_section=="enhance" and is_instance_valid(enhancement_forge) and enhancement_forge.is_visible_in_tree():_bind_original_enhance_action(enhancement_forge)
	if active_section=="quests" and is_instance_valid(quest_view) and quest_view.is_visible_in_tree():original_main_ui_status["quest_controls"]=original_main_ui_controller.bind_quest_controls(quest_view)
	return {"ok":true,"main_ui_bound":true,"player_values_pending":_original_main_player_values.is_empty(),"world_map_registration":map_registration,"npc_portrait_registration":npc_portrait_registration,"system_message":system_message,"complete_screen_contract":false,"game_state_written":false}

func bind_original_ui_runtime(runtime: Object, source_pack: RefCounted) -> Dictionary:
	if not is_instance_valid(original_ui_runtime_presenter):
		original_ui_runtime_presenter=preload("res://scripts/ui/original_ui/source_runtime_presenter.gd").new()
		original_ui_runtime_presenter.name="OriginalUISourceRuntime"
		add_child(original_ui_runtime_presenter)
	return original_ui_runtime_presenter.attach(runtime,source_pack)

func register_original_ui_content(section: String, focus_kind: String, member: String, source_sha256: String, mount: Node2D, binding_factory: Callable) -> Dictionary:
	if not is_instance_valid(original_ui_runtime_presenter):return {"ok":false,"code":"source_runtime_not_bound"}
	return original_ui_runtime_presenter.register_content(section,focus_kind,member,source_sha256,mount,binding_factory)

func register_original_event_content(kind: String, mount: Node2D, remaining_factory: Callable) -> Dictionary:
	if not is_instance_valid(original_ui_runtime_presenter):return {"ok":false,"code":"source_runtime_not_bound"}
	return original_ui_runtime_presenter.register_event_content(kind,mount,remaining_factory)

func close_original_ui_content() -> Dictionary:
	if not is_instance_valid(original_ui_runtime_presenter):return {"ok":true,"closed":true}
	return original_ui_runtime_presenter.close_content()

func mount_original_ui_menu(button_id: int, mount: Node2D) -> Dictionary:
	if not is_instance_valid(original_ui_runtime_presenter):return {"ok":false,"code":"source_runtime_not_bound"}
	return original_ui_runtime_presenter.mount_menu(button_id,mount)

var original_equipment_ui_adapter: Node

func bind_original_equipment_callbacks(preview_handler: Callable, commit_handler: Callable) -> Dictionary:
	if not preview_handler.is_valid() or not commit_handler.is_valid():return {"ok":false,"code":"source_equipment_handlers_unavailable"}
	if is_instance_valid(original_equipment_ui_adapter):
		original_equipment_ui_adapter.cancel()
		original_equipment_ui_adapter.queue_free()
	original_equipment_ui_adapter=preload("res://scripts/ui/original_ui/source_equipment_adapter.gd").new()
	original_equipment_ui_adapter.name="OriginalEquipmentSourceCallbacks"
	add_child(original_equipment_ui_adapter)
	original_equipment_ui_adapter.preview_requested.connect(preview_handler)
	original_equipment_ui_adapter.commit_requested.connect(commit_handler)
	return {"ok":true,"adapter":original_equipment_ui_adapter,"transaction_performed":false}

func present_original_alchemy(source_pack: RefCounted, mount: Node2D, remaining_bindings: Dictionary, selected_action: Dictionary) -> Dictionary:
	# PR265's existing host has already attached its preview/commit handlers.
	# Mount the actual source root and connect those handlers' endpoint, rather
	# than instantiating the old generic equipment form in this game path.
	if not is_instance_valid(original_equipment_ui_adapter):return {"ok":false,"code":"source_equipment_handlers_unavailable"}
	if not is_instance_valid(mount) or not mount.is_inside_tree():return {"ok":false,"code":"source_mount_unavailable"}
	if selected_action.get("kind")!="alchemy":return {"ok":false,"code":"source_operation_mismatch"}
	var source_bindings: Dictionary=preload("res://scripts/ui/original_ui/source_alchemy_bindings.gd").build(source_pack,original_equipment_ui_adapter,remaining_bindings)
	if not source_bindings.get("ok",false):return source_bindings
	var source_scene=preload("res://scripts/ui/original_ui/sprite_scene.gd").new()
	var configured: Dictionary=source_scene.configure(source_pack,source_bindings.member,false,source_bindings.bindings)
	if not configured.get("ok",false):
		source_scene.free()
		return configured
	# Preserve the previous presentation until the full new source contract
	# is accepted. Opening/replacing it performs no equipment transaction.
	original_equipment_ui_adapter.close()
	original_equipment_ui_adapter.select_action(selected_action)
	mount.add_child(source_scene)
	var bound: Dictionary=original_equipment_ui_adapter.bind_source_scene(source_scene)
	if not bound.get("ok",false):
		source_scene.visible=false
		source_scene.process_mode=Node.PROCESS_MODE_DISABLED
		source_scene.queue_free()
		return bound
	return {"ok":true,"source":source_bindings.member,"scene":source_scene,"adapter":original_equipment_ui_adapter,"transaction_performed":false}
