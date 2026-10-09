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
var title_dragging: bool = false
var title_dragged: bool = false
var viewport_fitted: bool = false
var navigation_scroll: ScrollContainer
var scroll_gestures: Dictionary = {}

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
	# Grab only the title area. Close/nav controls keep their own pointer events.
	titles.mouse_filter = Control.MOUSE_FILTER_STOP
	titles.gui_input.connect(_on_title_drag_input)
	titles.add_theme_constant_override("separation",0)
	title_row.add_child(titles)
	heading = UI.label("TWILIGHT",24,UI.GOLD)
	titles.add_child(heading)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle = UI.label("황혼의 기록",12,UI.MUTED)
	titles.add_child(subtitle)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var close := UI.button("닫기  Esc",func() -> void: closed.emit(),Vector2(106,42))
	close.name = "CloseWindow"
	title_row.add_child(close)
	layout.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	navigation_scroll = ScrollContainer.new()
	navigation_scroll.name = "WorkspaceNavigationScroll"
	navigation_scroll.custom_minimum_size.x = 132
	navigation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	navigation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	navigation_scroll.scroll_deadzone = 8
	body.add_child(navigation_scroll)
	var nav := VBoxContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.mouse_filter = Control.MOUSE_FILTER_PASS
	navigation_scroll.add_child(nav)
	for pair: Array in [["character","캐릭터 · 장비"],["class_select","클래스 선택"],["inventory","인벤토리"],["skills","스킬 · 성장"],["변신","변신"],["마법인형","마법인형"],["성물","성물"],["아이템","아이템 도감"],["map","월드맵"],["quest","퀘스트"],["shop","잡화 상점"],["enhance","장비 강화"],["auto","자동사냥"],["settings","설정"],["log","전투 기록"]]:
		var id := str(pair[0])
		var b := UI.button(str(pair[1]),func() -> void:
			if not was_scroll_dragged(navigation_scroll):
				navigate.emit(id),Vector2(124,36))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size",12)
		b.name = "Nav_"+id
		nav.add_child(b)
		register_scroll_drag(navigation_scroll,b)
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

# A drag starting on a Button is normally swallowed before ScrollContainer
# sees it. Forward native finger and mouse gestures from the button itself.
# Mouse wheel / scrollbar and ordinary taps remain handled by Godot.
func register_scroll_drag(scroll: ScrollContainer, target: Control) -> void:
	target.mouse_filter = Control.MOUSE_FILTER_PASS
	target.gui_input.connect(_on_scroll_drag_input.bind(scroll,target))

func was_scroll_dragged(scroll: ScrollContainer) -> bool:
	return bool((scroll_gestures.get(scroll.get_instance_id(), {}) as Dictionary).get("dragged", false))

func _on_scroll_drag_input(event: InputEvent, scroll: ScrollContainer, target: Control) -> void:
	var key: int = scroll.get_instance_id()
	var gesture: Dictionary = scroll_gestures.get(key, {"touch":-1,"mouse":false,"distance":0.0,"dragged":false})
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and not touch.canceled and int(gesture.get("touch",-1)) == -1:
			gesture = {"touch":touch.index,"mouse":false,"distance":0.0,"dragged":false}
		elif (not touch.pressed or touch.canceled) and touch.index == int(gesture.get("touch",-1)):
			gesture["touch"] = -1
	elif event is InputEventScreenDrag and event.index == int(gesture.get("touch",-1)):
		var drag: InputEventScreenDrag = event
		gesture["distance"] = float(gesture.get("distance",0.0)) + absf(drag.relative.y)
		if float(gesture["distance"]) > 8.0:
			gesture["dragged"] = true
			_scroll_by_drag(scroll,drag.relative.y)
			target.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			gesture = {"touch":-1,"mouse":true,"distance":0.0,"dragged":false}
		else:
			gesture["mouse"] = false
	elif event is InputEventMouseMotion and bool(gesture.get("mouse",false)) and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		gesture["distance"] = float(gesture.get("distance",0.0)) + absf(event.relative.y)
		if float(gesture["distance"]) > 8.0:
			gesture["dragged"] = true
			_scroll_by_drag(scroll,event.relative.y)
			target.accept_event()
	scroll_gestures[key] = gesture

func _scroll_by_drag(scroll: ScrollContainer, delta_y: float) -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var max_scroll: int = maxi(0,ceili(bar.max_value-bar.page))
	scroll.scroll_vertical = clampi(scroll.scroll_vertical-roundi(delta_y),0,max_scroll)

func fit_viewport() -> void:
	var viewport := get_viewport_rect().size
	var extent := Vector2(maxf(200.0,minf(1160.0,viewport.x-48.0)),maxf(140.0,minf(642.0,viewport.y-48.0)))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = extent
	if not viewport_fitted or not title_dragged:
		position = (viewport-extent)*0.5
	else:
		_keep_title_visible()
	viewport_fitted = true

func _keep_title_visible() -> void:
	var view: Vector2 = get_viewport_rect().size
	# Keep a usable title/grab area visible even when a large desktop window
	# is intentionally dragged partially outside the viewport.
	position.x = clampf(position.x, minf(0.0,140.0-size.x),maxf(0.0,view.x-140.0))
	position.y = clampf(position.y, 0.0,maxf(0.0,view.y-64.0))

func _on_title_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		title_dragging = (event as InputEventMouseButton).pressed
		if title_dragging:
			title_dragged = true
		accept_event()
	elif event is InputEventMouseMotion and title_dragging:
		position += (event as InputEventMouseMotion).relative
		_keep_title_visible()
		accept_event()
	elif event is InputEventScreenTouch:
		title_dragging = (event as InputEventScreenTouch).pressed
		if title_dragging:
			title_dragged = true
		accept_event()
	elif event is InputEventScreenDrag and title_dragging:
		position += (event as InputEventScreenDrag).relative
		_keep_title_visible()
		accept_event()

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
