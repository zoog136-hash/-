extends PanelContainer

signal navigate(section: String)
signal closed
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Ornament = preload("res://scripts/ui/renewal_ornament.gd")
var heading: Label
var subtitle: Label
var footer: Label
var content: Control
var navigation: Dictionary = {}

func _ready() -> void:
	name = "RenewalWindow"
	theme = UI.make_theme()
	z_index = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",UI.box(Color(0.03,0.04,0.05,.98),UI.GOLD,16))
	var layout := VBoxContainer.new()
	add_child(layout)
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation",0)
	title_row.add_child(titles)
	heading = UI.label("TWILIGHT",24,UI.GOLD)
	titles.add_child(heading)
	subtitle = UI.label("황혼의 기록",12,UI.MUTED)
	titles.add_child(subtitle)
	var close := UI.button("닫기  Esc",func() -> void: closed.emit(),Vector2(106,42))
	close.name = "CloseWindow"
	title_row.add_child(close)
	layout.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.custom_minimum_size.x = 132
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(nav_scroll)
	var nav := VBoxContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.add_child(nav)
	for pair: Array in [["character","캐릭터 · 장비"],["inventory","인벤토리"],["skills","스킬 · 성장"],["변신","변신"],["마법인형","마법인형"],["성물","성물"],["아이템","아이템 도감"],["map","월드맵"],["quest","퀘스트"],["shop","잡화 상점"],["enhance","장비 강화"],["auto","자동사냥"],["settings","설정"],["log","전투 기록"]]:
		var id := str(pair[0])
		var b := UI.button(str(pair[1]),func() -> void: navigate.emit(id),Vector2(124,36))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size",12)
		b.name = "Nav_"+id
		nav.add_child(b)
		navigation[id] = b
	body.add_child(VSeparator.new())
	content = Control.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(content)
	layout.add_child(HSeparator.new())
	footer = UI.label("TWILIGHT  ·  황혼의 기사",11,UI.MUTED)
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(footer)
	var ornament := Ornament.new()
	add_child(ornament)
	get_viewport().size_changed.connect(fit_viewport)
	fit_viewport()
	hide()

func fit_viewport() -> void:
	var viewport := get_viewport_rect().size
	var extent := Vector2(minf(1160,viewport.x-48),minf(642,viewport.y-48))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = (viewport-extent)*.5
	size = extent

func open(section: String, title: String, description: String) -> void:
	heading.text = title
	subtitle.text = description
	for key: String in navigation:
		(navigation[key] as Button).button_pressed = key == section
	show()
	fit_viewport()

func clear() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()

func mount(control: Control) -> void:
	if control.get_parent() != null:
		control.reparent(content)
	else:
		content.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func column() -> VBoxContainer:
	var v := VBoxContainer.new()
	mount(v)
	return v
