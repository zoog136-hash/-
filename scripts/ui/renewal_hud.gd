extends "res://scripts/hud_v20.gd"

# ISOLATED PLAYTEST BUILD ONLY: remove these debug signals before production.
signal playtest_catalog_grant_requested(item_name: String, amount: int)
signal playtest_aden_grant_requested

# UI-only adapter: existing HUD signals remain the sole write interface.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const RenewalWindowScript = preload("res://scripts/ui/renewal_window.gd")
const Inventory = preload("res://scripts/ui/renewal_inventory.gd")
const CharacterUI = preload("res://scripts/ui/renewal_character.gd")
const SkillsUI = preload("res://scripts/ui/renewal_skills.gd")
const ClassSelectUI = preload("res://scripts/ui/renewal_class_select.gd")
const ShopUI = preload("res://scripts/ui/renewal_shop.gd")
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
var playtest_grant_button: Button
var playtest_aden_button: Button
var playtest_scroll_buttons: Array[Button] = []
var skills_view: VBoxContainer
var region_selection: ItemList
var quest_view: Control
var class_picker_initial: bool = false
var class_picker_backdrop: ColorRect

func _ready() -> void:
	super._ready()
	$Root.theme = UI.make_theme()
	workspace = RenewalWindowScript.new()
	$Root.add_child(workspace)
	workspace.navigate.connect(_navigate)
	workspace.closed.connect(_close_workspace)
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
	_fit_hud()
	SettingsUI.apply_saved(self)

func _build_lineage_inventory_ui() -> void:
	lineage_inventory_ui = Inventory.new() as TwilightInventoryUI
	lineage_inventory_ui.name = "LineageInventoryUI"
	lineage_inventory_ui.item_activate_requested.connect(func(item_name: String) -> void: inventory_item_activated.emit(item_name))
	lineage_inventory_ui.quickslot_requested.connect(_register_inventory_quickslot)
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
	if lineage_inventory_ui != null and lineage_side_ui != null:
		# The world is authoritative for weight, encumbrance, item IDs and buffs.
		# Do not recompute per-name weight or overwrite the per-instance snapshot.
		lineage_side_ui.set_character_state(value.duplicate(true))

func _panel_style(alpha: float = .9, radius: int = 3, border: Color = UI.BRONZE) -> StyleBoxFlat:
	var s := UI.box(Color(.035,.045,.055,alpha),border,7)
	s.set_corner_radius_all(radius)
	return s

func _build_v20_buffs() -> void:
	buff_row = HBoxContainer.new()
	buff_row.name = "ActiveEffects"
	buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(buff_row,12,123,430,160)
	v20_layer.add_child(buff_row)

func _build_v20_quest() -> void:
	var panel := PanelContainer.new()
	panel.name = "QuestTracker"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel,1038,300,1268,409)
	panel.add_theme_stylebox_override("panel",_panel_style(.86))
	v20_layer.add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var head := UI.button("퀘스트  ›",open_quest_info,Vector2(0,28))
	head.flat = true
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(head)
	v20_quest_text = UI.rich("")
	v20_quest_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v20_quest_text.add_theme_font_size_override("normal_font_size",12)
	v.add_child(v20_quest_text)

func _build_v20_top_menu() -> void:
	var panel := PanelContainer.new()
	panel.name = "MainShortcuts"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel,870,10,1268,78)
	panel.add_theme_stylebox_override("panel",_panel_style(.9))
	v20_layer.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",4)
	panel.add_child(row)
	for spec: Array in [["shop","상점","shop.png"],["inventory","가방","bag.png"],["skills","스킬","skill.png"],["map","지도","quest.png"],["menu","메뉴","menu.png"]]:
		var id := str(spec[0])
		var b := UI.button(str(spec[1]),_navigate.bind(id),Vector2(72,52))
		b.name = "Shortcut_"+id
		b.icon = _load_texture("res://assets/ui/"+str(spec[2]))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",22)
		b.add_theme_font_size_override("font_size",12)
		row.add_child(b)

func _build_v20_right_controls() -> void:
	v20_self_button = UI.button("SELF",_toggle_self_mode,Vector2(68,44))
	v20_self_button.name = "SelfMode"
	v20_self_button.toggle_mode = true
	v20_self_button.tooltip_text = "SELF OFF: 퀵슬롯 버프 자동 재사용 · ON: 수동 사용"
	_place(v20_self_button,1078,449,1154,491)
	v20_layer.add_child(v20_self_button)
	var target := UI.button("대상",func() -> void: target_pressed.emit())
	target.name = "SelectTarget"
	target.icon = _load_texture("res://assets/ui/eye.png")
	_place(target,1162,449,1268,491)
	v20_layer.add_child(target)
	v20_auto_button = UI.button("AUTO",func() -> void: auto_pressed.emit())
	v20_auto_button.name = "AutoHunt"
	_place(v20_auto_button,1062,532,1147,611)
	v20_auto_button.add_theme_stylebox_override("normal",_round_button_style(.9,40,UI.BRONZE))
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
	attack.icon = _load_texture("res://assets/ui/attack.png")
	attack.expand_icon = true
	attack.add_theme_constant_override("icon_max_width",42)
	_place(attack,1157,514,1268,625)
	attack.add_theme_stylebox_override("normal",_round_button_style(.9,56,UI.GOLD))
	attack.add_theme_stylebox_override("hover",_round_button_style(.98,56,UI.GOLD))

func _build_v20_bottom_bar() -> void:
	var panel := PanelContainer.new()
	panel.name = "Quickslots"
	panel.add_theme_stylebox_override("panel",_panel_style(.94))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel,360,638,1038,712)
	v20_layer.add_child(panel)
	v20_skill_container = HBoxContainer.new()
	v20_skill_container.add_theme_constant_override("separation",5)
	panel.add_child(v20_skill_container)
	for index: int in range(8):
		var b := UI.button(str(index+1),_emit_quickslot.bind(index),Vector2(76,58))
		b.name = "Quickslot_%d" % index
		b.add_theme_font_size_override("font_size",10)
		b.add_theme_constant_override("icon_max_width",24)
		v20_skill_container.add_child(b)
		v20_quickslot_buttons.append(b)
		var icon := TextureRect.new()
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position=Vector2(22,4)
		icon.size=Vector2(32,32)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		quickslot_icons.append(icon)
		var caption := UI.label("",10)
		caption.position=Vector2(4,38)
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
	_place(exp_bar,12,709,330,716)
	v20_layer.add_child(exp_bar)
	var sys := HBoxContainer.new()
	_place(sys,12,638,330,679)
	v20_layer.add_child(sys)
	for pair: Array in [["auto","사냥 설정"],["log","기록"],["settings","설정"]]:
		sys.add_child(UI.button(str(pair[1]),_navigate.bind(str(pair[0])),Vector2(94,36)))
	currency_readout = UI.label("아데나  0",14,UI.GOLD)
	_place(currency_readout,420,113,748,139)
	v20_layer.add_child(currency_readout)
	coordinates_readout = UI.label("",11,UI.MUTED)
	_place(coordinates_readout,1038,277,1268,298)
	coordinates_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v20_layer.add_child(coordinates_readout)
	var home := UI.button("귀환",func() -> void: return_pressed.emit(),Vector2(88,44))
	home.name = "ReturnToSpawn"
	home.icon = _load_texture("res://assets/ui/return.png")
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

func _fit_hud() -> void:
	# Project canvas_items/keep scales the 1280x720 logical canvas exactly.
	if workspace != null:
		workspace.fit_viewport()

func _process(delta: float) -> void:
	super._process(delta)
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
	var cds: Dictionary = world.get("skill_cooldowns")
	for index: int in range(quickslot_cooldown_labels.size()):
		var remain: float = 0
		if index<quickslot_entries.size() and quickslot_entries[index] is Dictionary:
			remain = float(cds.get(str(quickslot_entries[index].get("id","")),0))
		quickslot_cooldown_labels[index].text = "%.1f" % remain if remain>0 else ""
	if workspace != null and workspace.visible:
		workspace.footer.text = "아데나  %s  ·  Lv.%d  ·  %s  ·  Esc로 닫기" % [lineage_inventory_ui._format_number(int(character_state.get("gold",0))),int(character_state.get("level",1)),v20_map_name.text]
	if v20_target_panel.visible:
		var selected: Node = world.get("selected_monster")
		if is_instance_valid(selected):
			v20_target_name.text = "Lv.%d %s  ·  HP %d / %d" % [int(selected.get("monster_level")),str(selected.get("monster_name")),int(selected.get("hp")),int(selected.get("max_hp"))]

func update_player(level: int,hp: int,max_hp: int,mp: int,max_mp: int,experience_value: int,exp_need: int,gold: int) -> void:
	super.update_player(level,hp,max_hp,mp,max_mp,experience_value,exp_need,gold)
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
		var b := UI.button("%ds" % time,open_character,Vector2(44,32))
		b.icon = _load_texture("res://assets/ui/rune.png")
		b.add_theme_font_size_override("font_size",10)
		b.tooltip_text = str(key)+" · %d초" % time
		buff_row.add_child(b)

func _render_quickslots(inventory: Dictionary,buffs: Dictionary) -> void:
	super._render_quickslots(inventory,buffs)
	for index: int in range(quickslot_icons.size()):
		var button: Button=v20_quickslot_buttons[index]
		quickslot_icons[index].texture=button.icon
		button.icon=null
		button.text=""
		quickslot_captions[index].text="비어 있음"
		quickslot_auto_badges[index].text=""
		if index>=quickslot_entries.size(): continue
		var entry: Dictionary=quickslot_entries[index]
		if entry.is_empty(): continue
		var entry_id := str(entry.get("id",""))
		quickslot_captions[index].text=entry_id.left(6)
		if str(entry.get("kind",""))=="item":
			quickslot_icons[index].texture=UI.item_icon(lineage_inventory_ui._find_item_record(entry_id),entry_id,item_image_index.get("아이템",{}))
			quickslot_captions[index].text=entry_id.left(3)+" ×%d" % int(inventory.get(entry_id,0))
		quickslot_auto_badges[index].text="AUTO" if bool(entry.get("auto",false)) else ""

func append_log(value: String) -> void:
	log_history.append(value)
	if log_history.size()>120:
		log_history.pop_front()
	super.append_log(value)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if workspace != null and workspace.visible:
			_close_workspace()
			get_viewport().set_input_as_handled()

func _close_workspace() -> void:
	if class_picker_initial:
		return
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
	_hide_aux_panels()
	_park_shared_panels()
	workspace.clear()
	workspace.open(section,title,description)
	active_section = section

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
	# The backdrop is below the workspace but above gameplay HUD.
	if initial:
		workspace.move_to_front()

func complete_class_selection() -> void:
	class_picker_initial = false
	class_picker_backdrop.hide()
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
		"enhance": _open_enhance_chooser()
		_: open_catalog(section)

func open_shop() -> void:
	_open_window("shop","잡화 상점","보유 아데나 · 아이템 검색 · 구매")
	var shop := ShopUI.new()
	workspace.mount(shop)
	shop.configure(self)

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
	_open_window("auto","자동사냥","기존 게임의 AUTO 상태를 제어합니다.")
	var col: VBoxContainer = workspace.column()
	var player: Node = get_parent().get("player")
	var enabled := bool(player.get("auto_enabled")) if player != null else false
	col.add_child(UI.label("AUTO 현재 상태: "+"켜짐" if enabled else "AUTO 현재 상태: 꺼짐",22,UI.GOLD))
	col.add_child(UI.label("근처의 목표를 찾고 이동·공격하는 기존 자동사냥을 사용합니다.",13,UI.MUTED))
	col.add_child(UI.button("AUTO 끄기" if enabled else "AUTO 켜기",func() -> void:
		auto_pressed.emit()
		open_macro_info(),Vector2(220,52)))

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
	panel.reparent(workspace.content)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.show()
	lineage_side_ui.show_character(character_state)

func toggle_menu() -> void:
	if active_section=="menu" and workspace.visible:
		_close_workspace()
		return
	_open_window("menu","황혼의 기록","TWILIGHT  /  ADEN CHRONICLES")
	var col: VBoxContainer = workspace.column()
	col.add_child(UI.label("모험의 모든 기록",28,UI.GOLD))
	col.add_child(UI.label("장비를 정비하고, 새로운 전투를 준비하세요.",14,UI.MUTED))
	var menu_scroll := ScrollContainer.new()
	menu_scroll.name = "MenuContentScroll"
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	menu_scroll.scroll_deadzone = 8
	col.add_child(menu_scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	menu_scroll.add_child(grid)
	for pair: Array in [["character","캐릭터 · 장비"],["class_select","클래스 선택"],["inventory","인벤토리"],["skills","스킬 · 성장"],["변신","변신"],["마법인형","마법인형"],["성물","성물"],["map","월드맵"],["quest","퀘스트"],["shop","잡화 상점"],["enhance","장비 강화"],["auto","자동사냥"],["settings","설정"]]:
		var section_id: String = str(pair[0])
		var button: Button = UI.button(str(pair[1]),func() -> void:
			if not workspace.was_scroll_dragged(menu_scroll):
				_navigate(section_id),Vector2(238,74))
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
	_open_window(category,category+" 도감","등급 · 이름으로 검색 / 로컬 도감 데이터")
	workspace.mount(catalog_panel)
	catalog_panel.show()
	catalog_category = category
	catalog_grade_filter = "전체"
	item_grade_filter = "전체"
	item_slot_filter = "weapon"
	rarity_filter.select(0)
	collection_slot_filter.visible = category=="아이템"
	collection_slot_filter.select(0)
	catalog_search.set_text("")
	collection_status.text = "테스트 모드 · 도감에서 선택 아이템 지급 / 강화 주문서 ×10 / 아데나 1억" if category=="아이템" else "보유·획득 시스템 미연결 · 기존 로컬 도감 적용 기능"
	playtest_grant_button.visible = category == "아이템"
	playtest_grant_button.disabled = true
	playtest_aden_button.visible = category == "아이템"
	for grant: Button in playtest_scroll_buttons:
		grant.visible = category == "아이템"
	_refresh_catalog_list("")

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
	for pair: Array in ITEM_SLOT_FILTERS:
		collection_slot_filter.add_item(str(pair[1]))
	collection_slot_filter.item_selected.connect(func(index: int) -> void: _set_item_slot_filter(str(ITEM_SLOT_FILTERS[index][0])))
	top.add_child(collection_slot_filter)
	collection_status = UI.label("",12,UI.MUTED)
	col.add_child(collection_status)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	catalog_list.reparent(left)
	catalog_list.custom_minimum_size = Vector2(530,0)
	catalog_list.max_columns = 4
	catalog_list.fixed_column_width = 126
	catalog_list.fixed_icon_size = Vector2i(94,94)
	catalog_list.icon_mode = ItemList.ICON_MODE_TOP
	catalog_list.max_text_lines = 2
	catalog_list.same_column_width = true
	catalog_list.add_theme_constant_override("v_separation",12)
	catalog_list.add_theme_constant_override("h_separation",8)
	catalog_list.add_theme_font_size_override("font_size",13)
	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(pager)
	for control: Control in [catalog_first_button,catalog_prev_button,catalog_page_label,catalog_next_button,catalog_last_button]:
		control.reparent(pager)
		control.custom_minimum_size.y = 34
	catalog_count.reparent(left)
	catalog_count.add_theme_font_size_override("font_size",11)
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "CatalogActionsScroll"
	right_scroll.custom_minimum_size.x = 315
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 300
	right_scroll.add_child(right)
	catalog_preview.reparent(right)
	catalog_preview.custom_minimum_size = Vector2(0,160)
	catalog_detail.reparent(right)
	catalog_detail.custom_minimum_size = Vector2(0,0)
	catalog_detail.add_theme_font_size_override("normal_font_size",14)
	catalog_equip_button.reparent(right)
	catalog_equip_button.name = "ApplyCatalog"
	var remove := UI.button("현재 적용 해제",func() -> void:
		if catalog_category != "아이템": catalog_equip_requested.emit(catalog_category,{}))
	remove.name = "ClearCatalog"
	right.add_child(remove)
	# Clearly marked playtest grants. Runtime inventory and item-ID logic remain
	# world-owned; the UI only emits requests and never writes inventory itself.
	var test_notice := UI.label("테스트 전용 · 정식 게임에서는 제거",12,UI.GOLD)
	right.add_child(test_notice)
	playtest_grant_button = UI.button("선택 아이템 1개 임시 지급",_request_playtest_catalog_grant,Vector2(0,42))
	playtest_grant_button.name = "PlaytestGrantSelected"
	right.add_child(playtest_grant_button)
	playtest_aden_button = UI.button("아데나 1억 맞추기",func() -> void: playtest_aden_grant_requested.emit(),Vector2(0,42))
	playtest_aden_button.name = "PlaytestAden"
	right.add_child(playtest_aden_button)
	for scroll: String in ["무기 마법 주문서 (각인)","갑옷 마법 주문서 (각인)","장신구 마법 주문서 (각인)"]:
		var grant_name: String = scroll
		var grant := UI.button("테스트 " + grant_name.replace(" (각인)","") + " ×10",func() -> void:
			playtest_catalog_grant_requested.emit(grant_name,10),Vector2(0,39))
		grant.name = "PlaytestScroll" + str(playtest_scroll_buttons.size())
		right.add_child(grant)
		playtest_scroll_buttons.append(grant)
	old.queue_free()

func _refresh_item_filter_controls() -> void:
	if rarity_filter != null:
		rarity_filter.select(maxi(0,["전체","일반","고급","희귀","영웅","전설","신화","유일"].find(item_grade_filter)))

func _refresh_catalog_list(filter_text: String) -> void:
	# The original paging, selection and native touch handler remain in use.
	catalog_filtered_results.clear()
	var query := filter_text.strip_edges().to_lower()
	for value: Variant in catalog_data.get(catalog_category,[]):
		if not value is Dictionary: continue
		var record: Dictionary = value
		if catalog_category=="아이템" and _item_filter_group(record)!=item_slot_filter: continue
		if catalog_grade_filter!="전체" and str(record.get("grade",""))!=catalog_grade_filter: continue
		var searchable := "%s %s %s" % [record.get("name",""),record.get("grade",""),record.get("type","")]
		if query!="" and not searchable.to_lower().contains(query): continue
		catalog_filtered_results.append(record)
	catalog_page=0
	_apply_catalog_page()

func _apply_catalog_page() -> void:
	super._apply_catalog_page()
	for index: int in range(catalog_results.size()):
		var record: Dictionary = catalog_results[index]
		var grade_name := str(record.get("grade","일반"))
		var color: Color = UI.grade(grade_name)
		catalog_list.set_item_text(index,str(record.get("name","")))
		catalog_list.set_item_custom_fg_color(index,color)
		catalog_list.set_item_custom_bg_color(index,Color(color,.08))
		var path := str(record.get("image_path",""))
		if path!="" and ResourceLoader.exists(path): catalog_list.set_item_icon(index,load(path) as Texture2D)
		catalog_list.set_item_tooltip(index,"%s · %s" % [grade_name,record.get("name","")])
	if catalog_results.is_empty():
		catalog_detail.text="검색 조건에 맞는 기록이 없습니다."
		catalog_equip_button.disabled=true
	(catalog_panel.find_child("ClearCatalog",true,false) as Button).visible=catalog_category!="아이템"

func _request_playtest_catalog_grant() -> void:
	if catalog_category != "아이템" or selected_catalog_record.is_empty():
		return
	playtest_catalog_grant_requested.emit(str(selected_catalog_record.get("name","")),1)

func _on_catalog_item_selected(index: int) -> void:
	super._on_catalog_item_selected(index)
	if selected_catalog_record.is_empty():
		if playtest_grant_button != null: playtest_grant_button.disabled = true
		return
	if playtest_grant_button != null:
		playtest_grant_button.disabled = catalog_category != "아이템"
	var item_name := str(selected_catalog_record.get("name",""))
	var grade_name := str(selected_catalog_record.get("grade","일반"))
	catalog_detail.text="[color=#%s]%s[/color]\n%s" % [UI.grade(grade_name).to_html(false),UI.safe(grade_name),catalog_detail.text]
	if catalog_category=="아이템":
		var owned := int(lineage_inventory_ui.inventory.get(item_name,0)) if lineage_inventory_ui!=null else 0
		catalog_detail.text+="\n보유 수량: %d\n테스트 지급 버튼으로 임시 획득 가능" % owned
		catalog_equip_button.text="보유 아이템 장착 / 사용" if owned>0 else "미보유 · 조회 전용"
		catalog_equip_button.disabled=owned<=0
	else:
		var equipped: Dictionary = character_state.get("equipped",{}).get(catalog_category,{})
		var applied := str(equipped.get("name",""))==item_name
		catalog_equip_button.text="현재 적용 중" if applied else "로컬 적용"
		catalog_equip_button.disabled=applied

func _equip_selected_catalog() -> void:
	if selected_catalog_record.is_empty(): return
	if catalog_category=="아이템":
		var item_name := str(selected_catalog_record.get("name",""))
		if int(lineage_inventory_ui.inventory.get(item_name,0))>0: inventory_item_activated.emit(item_name)
	else:
		catalog_equip_requested.emit(catalog_category,selected_catalog_record.duplicate(true))
		catalog_equip_button.text="현재 적용 중"
		catalog_equip_button.disabled=true

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
	regions.add_child(UI.label("지역 선택  ·  %d개 지역" % map_records.size(),15))
	region_selection=ItemList.new()
	region_selection.name="RegionSelection"
	region_selection.size_flags_vertical=Control.SIZE_EXPAND_FILL
	regions.add_child(region_selection)
	for record: Dictionary in map_records:
		region_selection.add_item(str(record.get("name",record.get("id",""))))
	var enter := UI.button("선택 지역으로 이동",func() -> void:
		var indices: PackedInt32Array=region_selection.get_selected_items()
		if not indices.is_empty(): map_selected.emit(str(map_records[indices[0]].get("id",""))))
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
	_open_window("skills","스킬 · 성장","직업별 스킬 · 패시브 · 퀵슬롯 · 자동사용")
	skills_view=SkillsUI.new()
	workspace.mount(skills_view)
	skills_view.configure(self)

func _emit_quickslot_assignment(slot_index: int,entry_kind: String,entry_id: String) -> void:
	super._emit_quickslot_assignment(slot_index,entry_kind,entry_id)
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
